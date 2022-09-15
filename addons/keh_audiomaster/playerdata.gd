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


extends Reference

# Each bus will have associated with it a number of audio stream player nodes. Internally, an instance of this class
# will be created for each bus.

#######################################################################################################################
### Signals and definitions
# Not particularly happy about duplicating this enum, but couldn't find a better way without creating yet another
# script file, which would hold only a single enum to be shared.
enum PlayerType {
	PlayerNormal,
	Player2D,
	Player3D,
}

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# Obtain the index of the corresponding Bus, as within the AudioServer
func get_bus_index() -> int:
	return _bus_index

func get_player_type() -> int:
	return _type

func set_player_type(t: int) -> void:
	_type = t

func get_player_type_string() -> String:
	match _type:
		PlayerType.PlayerNormal:
			return "Normal"
		PlayerType.Player2D:
			return "2D"
		PlayerType.Player3D:
			return "3D"
	
	return "Unknown Type"


func set_player_pause_mode(mode: int) -> void:
	_pause_mode = mode
	
	for p in _player:
		p.set("pause_mode", _pause_mode)


# Return number of created audio stream player nodes
func get_player_count() -> int:
	return _player.size()

# Obtain the number of players that are "marked" as playing.
func get_currently_playing_count() -> int:
	return _player.size() - _available.size()

# And how many stream players are available to be used
func get_available_player_count() -> int:
	return _available.size()


# Returns true if there is a maximum limit of stream player nodes
func has_player_node_limit() -> bool:
	return _max_players > 0


func set_max_players(val: int) -> void:
	_max_players = val
	
	var rindex: int = _player.size() - 1
	while (_player.size() > _max_players):
		var cn: Node = _parent_node.get_child(rindex)
		cn.queue_free()
		
		_player.remove(rindex)
		
		rindex -= 1


# Return how many new players can be created. This assumes there is a limit.
func get_max_new() -> int:
	return _max_players - _player.size()


# Returns true if a new player can be created
func can_create() -> bool:
	return _player.size() < _max_players if _max_players > 0 else true


# Create a new audio stream player, based on the type set for the bus.
# Incoming "object" is used to create the "finished" signal connection
func create(obj: Object) -> void:
	assert(_parent_node != null)
	assert(can_create())
	
	var splayer: Node = null
	match _type:
		PlayerType.PlayerNormal:
			splayer = AudioStreamPlayer.new()
		
		PlayerType.Player2D:
			splayer = AudioStreamPlayer2D.new()
		
		PlayerType.Player3D:
			splayer = AudioStreamPlayer3D.new()
	
	if (splayer):
		var index: int = _player.size()
		splayer.name = "Player_%d" % index
		splayer.set("bus", _parent_node.get_name())
		splayer.pause_mode = _pause_mode
		
		_player.append(splayer)
		
		# Value is irrelevant. Ideally this should be used as a set.
		_available[index] = 1
		
		_parent_node.add_child(splayer)
		
		# warning-ignore:return_value_discarded
		splayer.connect("finished", obj, "_playback_finished", [self, index])


func clear_players() -> void:
	while (_parent_node.get_child_count() > 0):
		var cn: Node = _parent_node.get_child(0)
		_parent_node.remove_child(cn)
		cn.free()
	
	_player.clear()
	_available.clear()


# Returns true if there is an available audio stream player to be used
func has_available_player() -> bool:
	return _available.size() > 0

# Obtain the index of a player that is available. -1 if none
func get_free_player_index() -> int:
	if (_available.empty()):
		return -1
	
	var keys: Array = _available.keys()
	
	return keys[0]


# Retrieve the stream player node. If the specific type is required, type-cast the returned value
func get_stream_player(index: int, mark_used: bool) -> Node:
	var ret: Node = _player[index]
	
	if (mark_used):
		# warning-ignore:return_value_discarded
		_available.erase(index)
	
	return ret


# Marks a player as available
func release_player(index: int) -> void:
	if (!_available.has(index)):
		# Again, the value is irrelevant. The dictionary is used as a set
		_available[index] = 0
	
	var splayer: Node = _player[index]
	splayer.set("stream", null)


# Returns true if the stream player at index is currently marked as "not free"
func is_playing(index: int) -> bool:
	return !_available.has(index)

# Returns the list of indices corresponding to stream players that are currently playing
func get_playing_list() -> Array:
	var ret: Array = []
	
	for i in _player.size():
		if (_player[i].get("playing")):
			ret.append(i)
	
	return ret


# Return the "position" (in seconds) of the playback in the specified stream player
func get_playback_position(index: int) -> float:
	if (index < 0 || index >= _player.size()):
		return 0.0
	
	return _player[index].call("get_playback_position")

func set_playback_position(index: int, new_pos: float) -> void:
	if (index < 0 || index >= _player.size()):
		return
	
	_player[index].call("seek", new_pos)


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# Indicates which type of StreamPlayer node will be generated
var _type: int = PlayerType.PlayerNormal

# Holds the index of the Bus corresponding to this "PlayerData", as found within the AudioServer singleton
var _bus_index: int = -1

# Holds instances of the relevant AudioStreamPlayer* nodes
var _player: Array = []

# This is the maximum amount of audio stream player nodes that can be created associated with the corresponding bus.
# If this is set to 0 then it's expected that nodes will be dynamically generated whenever necessary. without any
# imposed limit from this script.
var _max_players: int = 32

# Used as a set (that is, value is irrelevant), holds available players. If a key is in this, then the corresponding
# stream player (within the stream_player array) is free to be used. Originally this was intended to be an array to
# work as a queue, however a set (Dictionary) makes things easier to query the player itself, which becomes required
# in order to process some other stuff, like fade-in, fade-out...
var _available: Dictionary = {}

# Stream players nodes must be added into the tree. This holds the node that will be the parent for the stream
# players. More specifically, the one that will be used for the players for a single bus.
var _parent_node: Node = null

# Determines the pause_mode that will be assigned to all stream players. By default inherit, which is basically, stop
var _pause_mode: int = 0

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _init(parent: Node, index: int) -> void:
	_parent_node = parent
	_bus_index = index
