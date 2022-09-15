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


extends Spatial


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
# Sound effects are small enought to be preloaded. Store the AudioStream resources within an array for easier random
# playback of those SFX
const _sfx_list: Array = [
	preload("res://shared/sfx/impactMining_000.wav"),
	preload("res://shared/sfx/impactMining_001.wav"),
	preload("res://shared/sfx/impactMining_002.wav"),
	preload("res://shared/sfx/impactMining_003.wav"),
	preload("res://shared/sfx/impactMining_004.wav"),
]

#######################################################################################################################
### "Private" properties
onready var _spin_master: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_master/spin")
onready var _spin_music: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_music/spin")
onready var _spin_sfxnormal: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_sfx/spin")
onready var _spin_sfx2d: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_sfx2d/spin")
onready var _spin_sfx3d: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_sfx3d/spin")
onready var _spin_ui: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_ui/spin")

onready var _spin_fade: SpinSlider = get_node_or_null("ui/pnl1/vbox/hbox_fade/spin")

onready var _lbl_debuginfo: Label = get_node_or_null("ui/expandable/DebugInfo/info")

# Originally was using a HSlider Control, however each time I manually set its value, the audio playback stutters. I
# didn't test it in newer version of Godot as the main intention of this project is to work with 3.2 and newer. So, in
# order to still have a playback bar that also allows seeking, using the progress bar with manual input handling
onready var _pb_playbackpos: ProgressBar = get_node_or_null("ui/pnl1/vbox/pb_pbackpos")

# Index of currently active music stream player. If -1 then there is no music playing
var _currently_active: int = -1

var _active_duration: float = 0.0

var _seeking: bool = false

#######################################################################################################################
### "Private" functions
func _populate_device_list() -> void:
	var opt: OptionButton = get_node_or_null("ui/pnl1/vbox/hbox1/opt_device")
	if (!opt):
		return
	
	var devlist: Array = AudioServer.get_device_list()
	for dev in devlist:
		opt.add_item(dev)


func _populate_sfx_types() -> void:
	var opt: OptionButton = get_node_or_null("ui/top/hbox/opt_sfxtype")
	if (!opt):
		return
	
	opt.add_item("Normal")
	opt.add_item("2D")
	opt.add_item("3D")


func _update_volumes() -> void:
	_spin_master.value = AudioMaster.get_bus_volume_percent("Master")
	_spin_music.value = AudioMaster.get_bus_volume_percent("Music")
	_spin_sfxnormal.value = AudioMaster.get_bus_volume_percent("SFX")
	_spin_sfx2d.value = AudioMaster.get_bus_volume_percent("SFX2D")
	_spin_sfx3d.value = AudioMaster.get_bus_volume_percent("SFX3D")
	_spin_ui.value = AudioMaster.get_bus_volume_percent("UI")


func _play_music(audio: AudioStream) -> void:
	_currently_active = AudioMaster.get_available_player_index("Music")
	AudioMaster.play_audio("Music", audio, _currently_active, _spin_fade.value)
	_active_duration = audio.get_length()
	
	_on_updater_timeout()


func _cross_fade(to_audio: AudioStream) -> void:
	AudioMaster.stop("Music", _currently_active, _spin_fade.value)
	
	_play_music(to_audio)



#######################################################################################################################
### Event handlers
func _on_updater_timeout() -> void:
	var dbginfo: Array = AudioMaster.get_debug_info()
	
	var txt: String = ""
	for ainfo in dbginfo:
		if (!txt.empty()):
			txt += "\n"
		
		txt += "- %s (%s)\n   Player count: %d\n   Available: %d\n   Playing: %d" % [ainfo.bus, ainfo.type, ainfo.player_count, ainfo.available, ainfo.playing]
	
	_lbl_debuginfo.text = txt
	
	
	if (_currently_active != -1):
		var cpos: float = AudioMaster.get_playback_position("Music", _currently_active)
		var percent: float = cpos / _active_duration
		_pb_playbackpos.value = percent
		#_sl_playbackpos.value = percent
	
	else:
		_pb_playbackpos.value = 0.0



func _on_opt_device_item_selected(index: int) -> void:
	var opt: OptionButton = get_node_or_null("ui/pnl1/vbox/hbox1/opt_device")
	if (!opt):
		return
	
	var devn: String = opt.get_item_text(index)
	AudioServer.set_device(devn)


func _on_volume_changed(value: float, busname: String) -> void:
	AudioMaster.set_bus_volume_percent(busname, value)



func _on_audio_playback_finished(bus_name: String, index: int) -> void:
	if (bus_name == "Music" && _currently_active == index):
		_currently_active = -1



func _on_bt_music1_pressed() -> void:
	var audio: AudioStream = load("res://shared/music/action_strike.ogg")
	if (_currently_active == -1):
		_play_music(audio)
	
	else:
		_cross_fade(audio)



func _on_bt_music2_pressed():
	var audio: AudioStream = load("res://shared/music/dreams_of_vain.ogg")
	if (_currently_active == -1):
		_play_music(audio)
	
	else:
		_cross_fade(audio)


func _on_bt_music3_pressed():
	var audio: AudioStream = load("res://shared/music/epic_boss_battle.ogg")
	if (_currently_active == -1):
		_play_music(audio)
	
	else:
		_cross_fade(audio)


func _on_bt_stopmusic_pressed() -> void:
	if (_currently_active == -1):
		return
	
	AudioMaster.stop("Music", _currently_active, _spin_fade.value)
	_currently_active = -1
	_on_updater_timeout()


func _on_pb_pbackpos_gui_input(evt: InputEvent) -> void:
	var seekp: float = -1.0
	
	var mb: InputEventMouseButton = evt as InputEventMouseButton
	if (mb):
		if (mb.button_index == BUTTON_LEFT):
			if (mb.pressed):
				seekp = clamp(mb.position.x / _pb_playbackpos.rect_size.x, 0.0, 1.0)
				_seeking = true
			
			else:
				_seeking = false
	
	var mm: InputEventMouseMotion = evt as InputEventMouseMotion
	if (mm && _seeking):
		seekp = clamp(mm.position.x / _pb_playbackpos.rect_size.x, 0.0, 1.0)
	
	if (seekp >= 0.0 && _currently_active != -1):
		AudioMaster.set_playback_position("Music", _currently_active, seekp * _active_duration)


func _on_button_mouse_over() -> void:
	AudioMaster.load_and_play("UI", "res://shared/sfx/rollover2.wav")


func _on_SFXHelper_source_chosen(relative_pos: Vector2, scale: float) -> void:
	var opttype: OptionButton = get_node_or_null("ui/top/hbox/opt_sfxtype")
	if (!opttype):
		return
	
	var which: int = randi() % _sfx_list.size()
	
	match (opttype.selected):
		0:
			# Normal
			AudioMaster.play_audio("SFX", _sfx_list[which])
		
		1:
			# 2D
			# In 2D, the "listener" is always at screen center. The incoming relative position is scaled to work best with
			# the 3D node. However it's too small for the 2D attenuation system to work. So undo the scale
			var scr_center: Vector2 = opttype.get_viewport_rect().size * 0.5
			var pos2d: Vector2 = scr_center + (relative_pos / scale)
			
			AudioMaster.play_audio("SFX2D", _sfx_list[which], -1, 0.0, { "position": pos2d })
		
		2:
			# 3D
			var pos3d: Vector3 = Vector3(relative_pos.x, 1.0, relative_pos.y)
			AudioMaster.play_audio("SFX3D", _sfx_list[which], -1, 0.0, { "position": pos3d })



func _on_bt_return_pressed() -> void:
	AudioMaster.stop_all(1.5)
	
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")



#######################################################################################################################
### Overrides
func _enter_tree() -> void:
	OverlayDebugInfo.set_visibility(false)



func _exit_tree() -> void:
	OverlayDebugInfo.set_visibility(true)



func _ready() -> void:
	_populate_device_list()
	_populate_sfx_types()
	_update_volumes()
	
	
	SharedUtils.connector(_spin_master, "value_changed", self, "_on_volume_changed", ["Master"])
	SharedUtils.connector(_spin_music, "value_changed", self, "_on_volume_changed", ["Music"])
	SharedUtils.connector(_spin_sfxnormal, "value_changed", self, "_on_volume_changed", ["SFX"])
	SharedUtils.connector(_spin_sfx2d, "value_changed", self, "_on_volume_changed", ["SFX2D"])
	SharedUtils.connector(_spin_sfx3d, "value_changed", self, "_on_volume_changed", ["SFX3D"])
	SharedUtils.connector(_spin_ui, "value_changed", self, "_on_volume_changed", ["UI"])



