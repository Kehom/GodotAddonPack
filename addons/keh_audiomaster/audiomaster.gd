# Copyright (c) 2022 Yuri Sarudiansky
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


extends Node


#######################################################################################################################
### Signals and definitions
signal playback_finished(bus_name, player_index)

enum PlayerType {
	PlayerNormal,
	Player2D,
	Player3D,
}

#######################################################################################################################
### "Public" properties
# Obtain the volume of the given audio bus, in percent (range [0..1]) rather than DB
func get_bus_volume_percent(bus: String) -> float:
	var bindex: int = _get_player_data(bus).get_bus_index()
	var db: float = AudioServer.get_bus_volume_db(bindex)
	return db2linear(db)


# Set the volume of the given audio bus by specifying a percent value (range [0..1]). It will be automatically converted
# into DB.
# TODO: Add an option to perform the change over time - this should create a "smooth" volume transition
func set_bus_volume_percent(bus: String, newvol: float) -> void:
	var bindex: int = _get_player_data(bus).get_bus_index()
	var db: float = linear2db(clamp(newvol, 0.0, 1.0))
	AudioServer.set_bus_volume_db(bindex, db)



# Sets the maximum amount of stream players for the specified bus name. If zero then this system will not limit the
# amount of stream player nodes that are created. If there isn't any one that is free, a new one will be created when
# attempting to playback an audio
func set_maximum_players(bus: String, val: int) -> void:
	_get_player_data(bus).set_max_players(val)


# Set the audio stream player type (normal, 2D or 3D) of node that will be created for the playback of audio associated
# with the given audio bus.
func set_player_type(bus: String, ptype: int) -> void:
	if (ptype < 0 || ptype > PlayerType.Player3D):
		ptype = PlayerType.PlayerNormal
	
	var pd: _PlayerDataT = _get_player_data(bus)
	if (pd.get_player_type() != ptype):
		# Store amount of existing stream player nodes
		var pcount: int = pd.get_player_count()
		
		# Remove all of them
		pd.clear_players()
		
		# Assign the new type
		pd.set_player_type(ptype)
		
		# Restore previous number of stream players, but now of the new type
		for i in pcount:
			pd.create(self)



# Pre generates num stream players for the specified bus. Note that the total amount of players will not be bigger than
# the maximum amount specified.
func allocate_players(bus: String, num: int) -> void:
	var pd: _PlayerDataT = _get_player_data(bus)
	
	# Assume all requested ones can be created
	var count: int = num
	
	if (pd.has_player_node_limit()):
		var mnew: int = pd.get_max_new()
		if (count > mnew):
			count = mnew
	
	for i in count:
		pd.create(self)


# Sets the "pause_mode" of all stream players associated with a given Bus. This might be useful for a bus dedicated to
# playing UI sounds, for example, where it would be interesting to still allow those nodes to play sound even when
# the game is paused.
func set_player_pause_mode(bus: String, mode: int) -> void:
	assert(mode == PAUSE_MODE_INHERIT || mode == PAUSE_MODE_PROCESS || mode == PAUSE_MODE_STOP)
	_get_player_data(bus).set_player_pause_mode(mode)



# Returns true if the audio stream player at *index* within the specified "bus" is currently playing
func is_playing(bus: String, player_index: int) -> bool:
	return _get_player_data(bus).is_playing(player_index)


# Plays an audio stream. Or at least attempts to. A bus name must be specified in order to find to appropriate player.
# If index is negative then the first (in queue) free audio stream player will be used. Explicitly picking a player
# (by specifying a positive index) will basically interrupt its playback if it's already playing something.
# If fade_time is bigger than 0 then a fade-in effect will be added into the playback of the requested audio stream.
# Note that if the player type is set to 3D then fade will not work. 
# The extra settings Dictionary can be used to change several properties that area available within the various
# AudioStreamPlayer* nodes.
# When the playback naturally finishes the signal 'playback_finished' will be emitted.
func play_audio(bus: String, audio: AudioStream, index: int = -1, fade_time: float = 0.0, extra: Dictionary = {}) -> void:
	if (!audio):
		return
	
	var pd: _PlayerDataT = _get_player_data(bus)
	
	if (!pd.has_available_player() && index < 0):
		# All created stream player nods are in used and it was requested to use any free one. Check if it's possible to
		# create a new node.
		if (!pd.can_create()):
			# The maximum amount of players has already been created. So, bail.
			return
		
		# A new one can be created. Do it
		pd.create(self)
	
	# The index of the stream player to be used for playback
	var pidx: int = pd.get_free_player_index() if index < 0 else index
	
	# Get the player and perform the required setup
	match pd.get_player_type():
		PlayerType.PlayerNormal:
			var player: AudioStreamPlayer = pd.get_stream_player(pidx, true) as AudioStreamPlayer
			player.stream = audio
			player.mix_target = extra.get("mix_target", 0)
			
			if (fade_time > 0):
				_setup_fader(bus, pidx, fade_time, player, true)
			
			else:
				# Ensure the correct volume is set
				player.volume_db = 0.0
			
			# Perform the playback
			player.play(extra.get("start_from", 0.0))
		
		PlayerType.Player2D:
			var player: AudioStreamPlayer2D = pd.get_stream_player(pidx, true) as AudioStreamPlayer2D
			player.stream = audio
			_setup_player2d(player, extra)
			
			if (fade_time > 0):
				_setup_fader(bus, pidx, fade_time, player, true)
			else:
				player.volume_db = 0.0
			
			# Start playback
			player.play(extra.get("start_from", 0.0))
		
		PlayerType.Player3D:
			if (fade_time > 0):
				var msg: String = "Requested to playback '%s' with a fade-in time. However players for bus '%s' are 3D, which doesn't cannot perform the fading."
				push_warning(msg % [audio.resource_path, bus])
			
			var player: AudioStreamPlayer3D = pd.get_stream_player(pidx, true) as AudioStreamPlayer3D
			player.stream = audio
			_setup_player3d(player, extra)
			
			player.play(extra.get("start_from", 0.0))


# Load an audio stream from a given resource path then request playback
func load_and_play(bus: String, file_path: String, index: int = -1, fade_time: float = 0.0, extra: Dictionary = {}) -> void:
	# TODO: Check if the file exists
	var astream: AudioStream = load(file_path)
	if (astream):
		play_audio(bus, astream, index, fade_time, extra)


# Stops playback of the stream player at the specified index in the corresponding bus
func stop(bus: String, index: int, fade_time: float = 0.0) -> void:
	var pd: _PlayerDataT = _get_player_data(bus)
	
	if (index >= pd.get_player_count()):
		return
	
	if (fade_time > 0):
		var player: Node = pd.get_stream_player(index, false)
		_setup_fader(bus, index, fade_time, player, false)
	
	else:
		if (pd.is_playing(index)):
			pd.release_player(index)


# Stop playback of all stream players associated with the specified Bus. A fade-out effect can be used by providing the amount of
# seconds this effect should last, through the fade_time argument.
func stop_all_in_bus(bus: String, fade_time: float = 0.0) -> void:
	var pd: _PlayerDataT = _get_player_data(bus)
	
	var playing: Array = pd.get_playing_list()
	if (fade_time > 0):
		for i in playing:
			var player: Node = pd.get_stream_player(i, false)
			_setup_fader(bus, i, fade_time, player, false)
	
	else:
		for i in playing:
			pd.release_player(i)


# Stop playback of all stram players in all audio buses. A fade-out effect can be used by providing the amount of seconds
# this effect should last, through the fade_time argument
func stop_all(fade_time: float = 0.0) -> void:
	for bindex in AudioServer.bus_count:
		var bname: String = AudioServer.get_bus_name(bindex)
		stop_all_in_bus(bname, fade_time)


# Request the playback position (in seconds) of the specified audio stream player.
func get_playback_position(bus: String, player_index: int) -> float:
	return _get_player_data(bus).get_playback_position(player_index)


func set_playback_position(bus: String, player_index: int, new_position: float) -> void:
	_get_player_data(bus).set_playback_position(player_index, new_position)


# Obtain the index of an available audio stream player node. Returns -1 if there isn't any available.
func get_available_player_index(bus: String) -> int:
	return _get_player_data(bus).get_free_player_index()



# Automates the crossfade effect between two audio streams. Note that very few checks are performed here so ensure the
# fadeout_index points to an audio that is actually playing and that the fadein_index is different from the audio to be
# stopped.
#func cross_fade(bus: String, in_audio: AudioStream, fadein_index: int, fadeout_index: int, fade_time: float = 1.5, in_extra: Dictionary = {}) -> void:
#	play_audio(bus, in_audio, fadein_index, fade_time, in_extra)
#	stop(bus, fadeout_index, fade_time)


#func load_and_cross_fade(bus: String, in_file: String, fadein_index: int, fadeout_index: int, fade_time: float = 1.5, in_extra: Dictionary = {}) -> void:
#	load_and_play(bus, in_file, fadein_index, fade_time, in_extra)
#	stop(bus, fadeout_index, fade_time)





# This is mostly to help debug things. Each entry in the returned array is a Dictionary that corresponds to an existing
# audio bus.
func get_debug_info() -> Array:
	var ret: Array = []
	
	for i in AudioServer.bus_count:
		var bname: String = AudioServer.get_bus_name(i)
		var pd: _PlayerDataT = _get_player_data(bname)
		
		ret.append({
			"bus": bname,
			"player_count": pd.get_player_count(),
			"playing": pd.get_currently_playing_count(),
			"available": pd.get_available_player_count(),
			"type": pd.get_player_type_string(),
		})
	
	
	return ret


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
const _PlayerDataT: GDScript = preload("playerdata.gd")



class _Processor extends Reference:
	var bus: String = ""
	var player_index: int = -1
	
	func _init(bname: String, pindex: int) -> void:
		bus = bname
		player_index = pindex
	
	func tick(_dt: float) -> bool:
		return true
	
	func should_stop_on_end() -> bool:
		return false


class _Fader extends _Processor:
	# How much time
	var _time: float = 0.0
	# How much has elapsed
	var _elapsed: float = 0.0
	
	var _player: Node = null
	
	# If this is true, then volume will go from low to high. Otherwise from high to low
	# Also, if this is false (fade-out) then audio stream will be stopped when the effect ends
	var _fadein: bool = false
	
	# Hold initial and end volume so there wont be any need to use "if" at every single loop iteration
	var _fromvol: float = 1.0
	var _tovol: float = 0.0
	
	func should_stop_on_end() -> bool:
		return !_fadein
	
	func start(time: float, player: Node, fade_in: bool) -> void:
		assert(player is AudioStreamPlayer || player is AudioStreamPlayer2D)
		
		_fadein = fade_in
		_time = time
		_elapsed = 0.0
		_player = player
		_player.set("volume_db", linear2db(0.0))
		
		if (_fadein):
			_fromvol = 0.0
			_tovol = 1.0
	
	# Returns true if this fader has finished
	func tick(dt: float) -> bool:
		_elapsed += dt
		var alpha: float = clamp(_elapsed / _time, 0.0, 1.0)
		
		
		var nvol: float = lerp(_fromvol, _tovol, alpha)
		_player.set("volume_db", linear2db(nvol))
		
		return alpha >= 1.0
	
	func _init(bname: String, pindex: int).(bname, pindex) -> void:
		pass


#######################################################################################################################
### "Private" properties
# From bus name into instance of _PlayerData
var _player_map: Dictionary = {}

# Holds instance of _Processor inner class. Basically, this is to create changes over time
var _to_process: Array = []

#######################################################################################################################
### "Private" functions
func _check_internal_data() -> void:
	while (get_child_count() > 0):
		var c: Node = get_child(0)
		remove_child(c)
		c.free()
	
	for i in AudioServer.bus_count:
		var bname: String = AudioServer.get_bus_name(i)
		
		var pnode: Node = Node.new()
		pnode.name = bname
		var pd: _PlayerDataT = _PlayerDataT.new(pnode, i)
		add_child(pnode)
		
		_player_map[bname] = pd


func _get_player_data(bus: String) -> _PlayerDataT:
	assert(_player_map.has(bus))
	return _player_map.get(bus, null)


func _setup_fader(bus: String, player_index: int, time: float, player: Node, fade_in: bool) -> void:
	# Ensure volume begins at the lowest possible
	player.set("volume_db", linear2db(0.0))
	
	var fader: _Fader = _Fader.new(bus, player_index)
	fader.start(time, player, fade_in)
	_to_process.append(fader)
	set_process(true)


func _setup_player2d(player: AudioStreamPlayer2D, settings: Dictionary) -> void:
	player.global_position = settings.get("position", Vector2())
	player.pitch_scale = settings.get("pitch_scale", 1.0)
	player.max_distance = settings.get("max_distance", 2000.0)
	player.attenuation = settings.get("attenuation", 1.0)
	player.area_mask = settings.get("area_mask", 1)


func _setup_player3d(player: AudioStreamPlayer3D, settings: Dictionary) -> void:
	player.global_transform.origin = settings.get("position", Vector3())
	player.attenuation_model = settings.get("attenuation_model", 0)
	player.unit_db = settings.get("unit_db", 0.0)
	player.unit_size = settings.get("unit_size", 1.0)
	player.max_db = settings.get("max_db", 3.0)
	player.pitch_scale = settings.get("pitch_scale", 1.0)
	player.max_distance = settings.get("max_distance", 0.0)
	player.out_of_range_mode = settings.get("out_of_range_mode", 0)
	player.area_mask = settings.get("area_mask", 1)
	player.emission_angle_enabled = settings.get("emission_angle_enabled", false)
	player.emission_angle_degrees = settings.get("emission_angle_degrees", 45.0)
	player.emission_angle_filter_attenuation_db = settings.get("emission_angle_filter_attenuation_db", -12.0)
	player.attenuation_filter_cutoff_hz = settings.get("attenuation_filter_cutoff_hz", 5000.0)
	player.attenuation_filter_db = settings.get("attenuation_filter_db", -24.0)
	player.doppler_tracking = settings.get("doppler_tracking", 0)



#######################################################################################################################
### Event handlers
func _playback_finished(pdata: _PlayerDataT, index: int) -> void:
	pdata.release_player(index)
	
	var bname: String = AudioServer.get_bus_name(pdata.get_bus_index())
	emit_signal("playback_finished", bname, index)



#######################################################################################################################
### Overrides
func _process(dt: float) -> void:
	var i: int = 0
	while (i < _to_process.size()):
		var proc: _Processor = _to_process[i]
		
		if (proc.tick(dt)):
			var bp: _PlayerDataT = _get_player_data(proc.bus)
			
			if (proc.should_stop_on_end()):
				bp.release_player(proc.player_index)
				emit_signal("playback_finished", proc.bus, proc.player_index)
			
			_to_process.remove(i)
		
		
		else:
			i += 1
	
	if (_to_process.size() == 0):
		set_process(false)


func _init() -> void:
	_check_internal_data()


func _ready() -> void:
	# Process should be called only when there is something to be done. During initialization there isn't anything so
	# disable that function.
	set_process(false)
