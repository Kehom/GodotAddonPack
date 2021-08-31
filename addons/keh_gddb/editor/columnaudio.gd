# Copyright (c) 2021 Yuri Sarudiansky
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

tool
extends "res://addons/keh_ui/tabular/columnbase.gd"

# This column is designed specifically for audio resources. Unfortunatelly there is no easy easy way to create a
# waveform preview with pure GDScript. The preview shown within the editor (audio_stream_editor_plugin/cpp) uses
# the AudioStreamPreviewGenerator class, which is not exposed to GDScript.
# For a .wav file the generate resource is of AudioStreamPlayback, which does provide data that can be "converted"
# into the waveform view. However .ogg files (AudioStreamOGGVorbis) do not provide data that is as straightforward.
# Because of that each cell in here will just provide a few buttons to allow playback as well as a bar that allows
# seeking over the assigned audio.
#
# NOTE: There is a bug (fixed in 3.3) related to audio seeking (https://github.com/godotengine/godot/issues/41389)
# Basically this affects the capabilities of pausing then resuming. Again, this bug has been fixed on Godot 3.3
# Normal playback still works fine so it should not be that problematic if the project is on a previous version
# of Godot.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
class SizesCache:
	var font_height: float = 0.0


class AudioCell extends Control:
	const CBase: Script = preload("res://addons/keh_ui/tabular/columnbase.gd")
	const CIconBT: Script = CBase.CenterIconButton
	
	var idx: int = -1
	var astream: AudioStream = null
	
	var prog: HSlider = HSlider.new()
	
	var btplay: CIconBT = CIconBT.new()
	var btpause: CIconBT = CIconBT.new()
	var btstop: CIconBT = CIconBT.new()
	
	var btval: Button = Button.new()
	var btclear: Button = Button.new()
	
	# This is not meant to actually change the player status, rather to update the button display based
	# on what is going on with the player
	func play() -> void:
		btplay.visible = false
		btpause.visible = true
	
	func pause() -> void:
		btplay.visible = true
		btpause.visible = false
	
	func stop() -> void:
		btplay.visible = true
		btpause.visible = false
		prog.value = 0
	
	
	func set_audio(data: Dictionary) -> void:
		astream = data.audio
		btval.text = data.label
		btval.hint_tooltip = data.tooltip
		btclear.visible = data.clearv
		
		prog.visible = astream != null
		btplay.visible = astream != null
		btstop.visible = astream != null
		
		if (astream):
			prog.hint_tooltip = str(astream.get_length())
			prog.max_value = astream.get_length()
	
	
	func _init() -> void:
		add_child(prog)
		add_child(btplay)
		add_child(btpause)
		add_child(btstop)
		add_child(btval)
		add_child(btclear)
		
		btval.text = "..."
		btval.clip_text = true
		btval.align = Button.ALIGN_LEFT
		
		btclear.hint_tooltip = "Clear"
		btclear.expand_icon = true
		btclear.visible = false
		
		prog.anchor_left = 0
		prog.anchor_right = 1
		prog.mouse_filter = Control.MOUSE_FILTER_PASS
		prog.step = 0.01
		prog.visible = false
		
		btplay.cicon = preload("btplay_16x16.png")
		btplay.expand_icon = true
		btplay.anchor_left = 0
		btplay.anchor_top = 0
		btplay.anchor_right = 0
		btplay.anchor_bottom = 0
		btplay.visible = false
		
		btpause.cicon = preload("btpause_16x16.png")
		btpause.expand_icon = true
		btpause.anchor_left = 0
		btpause.anchor_top = 0
		btpause.anchor_right = 0
		btpause.anchor_bottom = 0
		btpause.visible = false
		
		btstop.cicon = preload("btstop_16x16.png")
		btstop.expand_icon = true
		btstop.anchor_left = 0
		btstop.anchor_top = 0
		btstop.anchor_right = 0
		btstop.anchor_bottom = 0
		btstop.visible = false
		
		btval.anchor_left = 0
		btval.anchor_top = 1
		btval.anchor_right = 1
		btval.anchor_bottom = 1
		
		btclear.anchor_left = 1
		btclear.anchor_top = 1
		btclear.anchor_right = 1
		btclear.anchor_bottom = 1

#######################################################################################################################
### "Private" properties
# Sizes to correctly position rendered data
var _sizes: SizesCache = SizesCache.new()

# Dialog used to load audio files
var _dlg_la: FileDialog = FileDialog.new()

# Node meant to help play sounds
var _player: AudioStreamPlayer = AudioStreamPlayer.new()

# If an audio is playing (through a cell), hold which cell triggered it
var _playing: AudioCell = null

#######################################################################################################################
### "Private" functions
func _apply_style(cell: AudioCell) -> void:
	style_button(cell.btval)
	# If the "as CenterIconButton" is not provided then the color will not be assigned, resulting in incorrect icon rendering
	style_button(cell.btplay as CenterIconButton)
	style_button(cell.btpause as CenterIconButton)
	style_button(cell.btstop as CenterIconButton)
	
	var bth: float = get_button_min_height()
	
	var tbin: Texture = _styler.get_trash_bin_icon()
	var sliderms: Vector2 = cell.prog.get_combined_minimum_size()
	
	var cmargins: Dictionary = get_cell_internal_margins()
	
	cell.btplay.margin_top = sliderms.y + cmargins.top
	cell.btplay.rect_size.x = cell.btplay.rect_size.y
	
	cell.btpause.margin_top = sliderms.y + cmargins.top
	cell.btpause.rect_size.x = cell.btpause.rect_size.y
	
	cell.btstop.margin_top = sliderms.y + cmargins.top
	cell.btstop.margin_left = cell.btplay.rect_size.x + cmargins.left
	cell.btstop.rect_size.x = cell.btstop.rect_size.y
	
	cell.btval.margin_top = -bth
	cell.btval.margin_right = -(bth + cmargins.left)
	
	cell.btclear.add_stylebox_override("normal", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("hover", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("pressed", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("focus", _styler.get_empty_stylebox())
	
	cell.btclear.icon = tbin
	
	cell.btclear.margin_left = -bth
	cell.btclear.margin_top = -bth
	cell.btclear.margin_right = 0
	cell.btclear.margin_bottom = 0




func _check_audio_path(path: String) -> Dictionary:
	var audio: AudioStream = null
	var label: String = ""
	var ttip: String = ""
	var cvisible: bool = false
	
	if (path.empty()):
		label = "..."
		ttip = "Load audio resource."
	
	elif (!ResourceLoader.exists(path)):
		label = "!" + path.get_file()
		ttip = "'%s' is not an Audio.\nClick to Load audio resource." % path
	
	else:
		label = path.get_file()
		ttip = path
		cvisible = true
		
		var res: Resource = load(path)
		if (res is AudioStream):
			audio = res
	
	
	return {
		"audio": audio,
		"label": label,
		"tooltip": ttip,
		"clearv": cvisible,
	}


func _set_audio(path: String, cell: AudioCell) -> void:
	assert(cell != null)
	
	cell.set_audio(_check_audio_path(path))
	notify_value_entered(cell.idx, path)

#######################################################################################################################
### Event handlers
func _on_load_clicked(index: int) -> void:
	_dlg_la.set_meta("index", index)
	_dlg_la.popup_centered()


func _on_file_selected(path: String) -> void:
	var index: int = _dlg_la.get_meta("index")
	_set_audio(path, get_cell_control(index) as AudioCell)


func _on_clear_clicked(cell: AudioCell) -> void:
	_set_audio("", cell)



func _on_seek(val: float) -> void:
	if (!_playing):
		return
	
	_player.seek(val)



func _on_play_clicked(cell: AudioCell) -> void:
	if (_playing):
		_player.stop()
		_playing.pause()
	
	_player.stream = cell.astream
	_player.play(cell.prog.value)
	_playing = cell
	cell.play()
	
	set_process(true)



func _on_pause_clicked() -> void:
	if (!_playing):
		return
	
	_playing.pause()
	_playing = null
	set_process(false)
	
	_player.stop()
	_player.stream = null


func _on_stop_clicked() -> void:
	if (!_playing):
		return
	
	_playing.stop()
	_playing = null
	
	_player.stop()
	_player.stream = null



func _on_audio_finished() -> void:
	if (!_playing):
		return
	
	_playing.stop()
	_playing = null
	
	set_process(false)

#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	if (!(cell is AudioCell)):
		return
	
	if (!(value is String)):
		return
	
	cell.set_audio(_check_audio_path(value))



func create_cell() -> Control:
	var index: int = get_row_count()
	var ret: AudioCell = AudioCell.new()
	ret.idx = index
	
	# warning-ignore:return_value_discarded
	ret.btval.connect("pressed", self, "_on_load_clicked", [index])
	
	# warning-ignore:return_value_discarded
	ret.btclear.connect("pressed", self, "_on_clear_clicked", [ret])
	
	# warning-ignore:return_value_discarded
	ret.btplay.connect("pressed", self, "_on_play_clicked", [ret])
	
	# warning-ignore:return_value_discarded
	ret.btpause.connect("pressed", self, "_on_pause_clicked")
	
	# warning-ignore:return_value_discarded
	ret.btstop.connect("pressed", self, "_on_stop_clicked")
	
	# warning-ignore:return_value_discarded
	ret.prog.connect("value_changed", self, "_on_seek")
	
	ret.set_drag_forwarding(self)
	
	_apply_style(ret)
	
	return ret



func get_min_row_height() -> float:
	var margins: Dictionary = get_cell_internal_margins()
	var btheight: float = get_button_min_height()
	
	var sstyle: StyleBox = get_stylebox("slider", "Slider")
	var grabber: Texture = get_icon("grabber", "Slider")
	
	var h: float = max(sstyle.get_minimum_size().y + sstyle.get_center_size().y, grabber.get_height())
	
	return ((margins.top * 4.0) + (btheight * 2.0) + h)



func check_style() -> void:
	var font: Font = _styler.get_cell_font()
	
	_sizes.font_height = font.get_height()
	
	for ci in get_row_count():
		var cell: AudioCell = get_cell_control(ci)
		_apply_style(cell)



# The created cells will forward the drag handling into the column itself.
func can_drop_data_fw(_pos: Vector2, data, from: Control) -> bool:
	if (!(from is AudioCell)):
		return false
	
	if (data.type != "files"):
		return false
	
	if (data.files.size() != 1):
		return false
	
	var p: String = data.files[0]
	var res: Resource = load(p)
	
	return (res is AudioStream)

func drop_data_fw(_pos: Vector2, data, from: Control) -> void:
	assert(data.type == "files" && data.files.size() == 1)
	
	if (!(from is AudioCell)):
		return
	
	var p: String = data.files[0]
	_set_audio(p, from)




func _process(_dt: float) -> void:
	if (!_playing):
		set_process(false)
	
	else:
		_playing.prog.value = _player.get_playback_position()


func _ready() -> void:
	# By default processing should be disabled. Only enable it when there is an audio being played.
	# Then disable it again when the playback ends
	set_process(false)


func _init() -> void:
	rect_size.x = 100
	add_child(_dlg_la)
	add_child(_player)
	
	_dlg_la.set_name("dlg_load_audio")
	_dlg_la.mode = FileDialog.MODE_OPEN_FILE
	_dlg_la.popup_exclusive = true
	_dlg_la.window_title = "Open texture"
	_dlg_la.resizable = true
	_dlg_la.rect_size = Vector2(600, 340)
	_dlg_la.access = FileDialog.ACCESS_RESOURCES
	
	
	_dlg_la.filters = PoolStringArray([
		"*.ogg; OGG",
		"*.oggstr; OGGSTR",
		"*.res; RES",
		"*.sample; SAMPLE",
		"*.tres; TRES",
		"*.wav; WAV"
	])
	
	# warning-ignore:return_value_discarded
	_dlg_la.connect("file_selected", self, "_on_file_selected")
	
	# warning-ignore:return_value_discarded
	_player.connect("finished", self, "_on_audio_finished")

