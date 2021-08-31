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

# This column is meant to hold any kind of resource that can be found within the "res://" path.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
class Cell extends Control:
	var btval: Button = Button.new()
	var btc: Button = Button.new()
	
	var idx: int = -1
	
	
	func _init() -> void:
		add_child(btval)
		add_child(btc)
		
		btval.align = Button.ALIGN_LEFT
		btval.text = "..."
		
		btc.expand_icon = true
		
		btval.anchor_top = 0.5
		btval.anchor_bottom = 0.5
		btval.anchor_right = 1
		
		btc.anchor_top = 0.5
		btc.anchor_bottom = 0.5
		btc.anchor_left = 1
		btc.anchor_right = 1
		
		btc.margin_right = 0
		
		btc.hint_tooltip = "Clear value"
		btc.mouse_filter = Control.MOUSE_FILTER_PASS
		
		btc.visible = false

#######################################################################################################################
### "Private" properties
var _dlg_lt: FileDialog = FileDialog.new()

#######################################################################################################################
### "Private" functions
func _apply_style(cell: Cell) -> void:
	var bth: float = get_button_min_height()
	var bth_h: float = bth * 0.5
	var margins: Dictionary = get_cell_internal_margins()
	
	style_button(cell.btval)
	
	cell.btc.icon = _styler.get_trash_bin_icon()
	
	cell.btval.margin_top = -bth_h
	cell.btval.margin_bottom = bth_h
	cell.btval.margin_right = -(bth + margins.left)
	
	cell.btc.margin_top = -bth_h
	cell.btc.margin_bottom = bth_h
	cell.btc.margin_left = -bth

#######################################################################################################################
### Event handlers
func _on_load_clicked(index: int) -> void:
	_dlg_lt.set_meta("index", index)
	_dlg_lt.popup_centered()


func _on_clear_clicked(index: int) -> void:
	set_row_value(get_cell_control(index), "")
	notify_value_entered(index, "")


func _on_file_selected(path: String) -> void:
	var index: int = _dlg_lt.get_meta("index")
	set_row_value(get_cell_control(index), path)
	notify_value_entered(index, path)



#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	if (!(cell is Cell) || !(value is String)):
		return
	
	cell.btval.text = "..." if value.empty() else value
	
	cell.btc.visible = !value.empty()



func create_cell() -> Control:
	var index: int = get_row_count()
	
	var ret: Cell = Cell.new()
	ret.idx = index
	
	_apply_style(ret)
	
	ret.btc.add_stylebox_override("normal", _styler.get_empty_stylebox())
	ret.btc.add_stylebox_override("hover", _styler.get_empty_stylebox())
	ret.btc.add_stylebox_override("pressed", _styler.get_empty_stylebox())
	ret.btc.add_stylebox_override("focus", _styler.get_empty_stylebox())
	
	# warning-ignore:return_value_discarded
	ret.btval.connect("pressed", self, "_on_load_clicked", [index])
	
	# warning-ignore:return_value_discarded
	ret.btc.connect("pressed", self, "_on_clear_clicked", [index])
	
	ret.set_drag_forwarding(self)
	
	return ret




func get_min_row_height() -> float:
	var margins: Dictionary = get_cell_internal_margins()
	return get_button_min_height() + margins.top + margins.bottom


func check_style() -> void:
	for i in get_row_count():
		var c: Cell = get_cell_control(i)
		_apply_style(c)



func can_drop_data_fw(_pos: Vector2, data, from: Control) -> bool:
	if (!(from is Cell)):
		return false
	
	if (data.type != "files"):
		return false
	
	if (data.files.size() != 1):
		return false
	
	return true


func drop_data_fw(_pos: Vector2, data, from: Control) -> void:
	assert(data.type == "files" && data.files.size() == 1)
	
	if (!(from is Cell)):
		return
	
	set_row_value(from, data.files[0])
	notify_value_entered(from.idx, data.files[0])



func _init() -> void:
	rect_size.x = 70
	
	_dlg_lt.set_name("dlg_load_res")
	_dlg_lt.mode = FileDialog.MODE_OPEN_FILE
	_dlg_lt.popup_exclusive = true
	_dlg_lt.window_title = "Open resource"
	_dlg_lt.resizable = true
	_dlg_lt.rect_size = Vector2(600, 340)
	_dlg_lt.access = FileDialog.ACCESS_RESOURCES
	add_child(_dlg_lt)
	
	# warning-ignore:return_value_discarded
	_dlg_lt.connect("file_selected", self, "_on_file_selected")
