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

tool
extends "res://addons/keh_dataasset/editor/propeditors/ped_base.gd"


#######################################################################################################################
### Signals and definitions
const DAHelperT: Script = preload("../dahelper.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
# The idea here is to allow drag & drop file/path from the *FileSystem* panel into the string editor. However it's not
# possible to detect drop attempts from a control underneath a LineEdit, even with a "mouse_ignore" filter. To that
# end this Control will contain a LineEdit within but will hide by default.
class InnerEditor extends Container:
	signal value_changed(nval)
	
	var ledit: LineEdit = LineEdit.new()
	# By default directory mode
	var is_file: bool = false
	
	func can_drop_data(_pos: Vector2, data) -> bool:
		if (!(data is Dictionary)):
			return false
		
		if (is_file):
			if (data.type != "files"):
				return false
			
			if (data.files.size() > 1):
				return false
			
			# TODO: check file extension
		
		else:
			if (data.type != "files_and_dirs"):
				return false
			
			if (data.files.size() > 1):
				return false
		
		
		return true
	
	
	func drop_data(_pos: Vector2, data) -> void:
		var files: Array = data.get("files", [])
		ledit.text = files[0]
		emit_signal("value_changed", ledit.text)
	
	
	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_SORT_CHILDREN:
				fit_child_in_rect(ledit, Rect2(Vector2(), rect_size))
	
	
	func _gui_input(evt: InputEvent) -> void:
		var mb: InputEventMouseButton = evt as InputEventMouseButton
		if (mb && mb.is_pressed() && mb.button_index == BUTTON_LEFT):
			ledit.visible = true
			ledit.grab_focus()
			yield(get_tree(), "idle_frame")
			ledit.select_all()
	
	
	func _draw() -> void:
		var font: Font = get_font("font", "LineEdit")
		var fcolor: Color = get_color("font_color", "LineEdit")
		
		var style: StyleBox = get_stylebox("normal", "LineEdit")
		draw_style_box(style, Rect2(Vector2(), rect_size))
		
		var x: int = int(style.get_margin(MARGIN_LEFT))
		var y: int = int((rect_size.y - font.get_height()) * 0.5 + font.get_ascent())
		
		draw_string(font, Vector2(x, y), ledit.text, fcolor)
	
	
	func _init() -> void:
		add_child(ledit)
		ledit.visible = false
		mouse_default_cursor_shape = Control.CURSOR_IBEAM




#######################################################################################################################
### "Private" properties
#var _ledit: LineEdit = LineEdit.new()
var _inneredit: InnerEditor = InnerEditor.new()

var _btedit: Button = Button.new()

var _fdlg: EditorFileDialog = EditorFileDialog.new()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _path_selected(path: String) -> void:
	_inneredit.ledit.text = path
	notify_value_changed(path)
	_inneredit.update()


func _text_entered(path: String) -> void:
	notify_value_changed(path)

func _edt_focus_exited() -> void:
	_inneredit.ledit.visible = false
	_inneredit.update()
	_text_entered(_inneredit.ledit.text)


func _on_btedit_pressed() -> void:
	if (_fdlg.mode == EditorFileDialog.MODE_OPEN_DIR):
		_fdlg.current_dir = _inneredit.ledit.text
	else:
		_fdlg.current_path = _inneredit.ledit.text
	
	_fdlg.popup_centered_ratio()


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_inneredit.ledit.text = value
	_inneredit.update()




func extra_setup(settings: Dictionary, _typeinfo: Dictionary) -> void:
	match settings.type:
		DAHelperT.CTYPE_STRING_DIR:
			_fdlg.mode = EditorFileDialog.MODE_OPEN_DIR
		
		DAHelperT.CTYPE_STRING_FILE:
			_inneredit.is_file = true
			_fdlg.mode = EditorFileDialog.MODE_OPEN_FILE
			
			var extl: PoolStringArray = settings.hint_string.split(",")
			for e in extl:
				var ext: String = e.strip_edges()
				if (!ext.empty()):
					_fdlg.add_filter(ext)




func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			_btedit.icon = get_icon("Folder", "EditorIcons")



func _init() -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	_right.add_child(hbox)
	
	hbox.add_child(_inneredit)
	_inneredit.size_flags_horizontal = SIZE_EXPAND_FILL
	
	# warning-ignore:return_value_discarded
	_inneredit.ledit.connect("text_entered", self, "_text_entered")
	# warning-ignore:return_value_discarded
	_inneredit.ledit.connect("focus_exited", self, "_edt_focus_exited")
	
	# warning-ignore:return_value_discarded
	_inneredit.connect("value_changed", self, "_path_selected")
	
	hbox.add_child(_btedit)
	# warning-ignore:return_value_discarded
	_btedit.connect("pressed", self, "_on_btedit_pressed")
	
	add_child(_fdlg)
	# warning-ignore:return_value_discarded
	_fdlg.connect("file_selected", self, "_path_selected")
	# warning-ignore:return_value_discarded
	_fdlg.connect("dir_selected", self, "_path_selected")
