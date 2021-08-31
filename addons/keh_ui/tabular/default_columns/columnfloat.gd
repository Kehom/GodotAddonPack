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
extends "../columnbase.gd"


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# Unfortunately there isn't a way to block characters from being entered. Validating values from the LineEdit require
# a bit more upkeep because the "old valid value" has to be stored. So, if an invalid character is entered the new
# text can be reverted. This property holds the "old valid value".
var _editing_valid: String = ""

#######################################################################################################################
### "Private" functions
func _apply_fstyle(cell: LineEdit) -> void:
	cell.add_font_override("font", _styler.get_cell_font())
	cell.add_color_override("font_color", _styler.get_cell_text_color())

#######################################################################################################################
### Event handlers
func _on_text_entered(nval: String, row: int) -> void:
	# The notifier will take care of verifying if the value actually changed
	notify_value_entered(row, nval.to_float())
	
	if (get_autoedit() && row + 1 < get_row_count()):
		row += 1
		var le: LineEdit = get_cell_control(row)
		le.grab_focus()
	
	else:
		var le: LineEdit = get_cell_control(row)
		le.release_focus()


func _on_text_changed(nval: String, cell: LineEdit) -> void:
	if (nval.empty() || nval.is_valid_float()):
		_editing_valid = nval
	else:
		cell.text = _editing_valid
		cell.set_cursor_position(_editing_valid.length())


func _on_cell_focus(cell: LineEdit) -> void:
	_editing_valid = cell.text
	
	cell.call_deferred("select_all")


func _on_cell_unfocus(row: int, cell: LineEdit) -> void:
	# Deselect the contents
	cell.select(0, 0)
	
	_editing_valid = ""
	
	# The notifier will take care of verifying if the value actually changed
	notify_value_entered(row, cell.text.to_float())


func _on_cell_input(evt: InputEvent, ledit: LineEdit, rindex: int) -> void:
	if (evt is InputEventKey && evt.is_pressed() && evt.scancode == KEY_ESCAPE):
		revert_value_change(rindex)
		ledit.release_focus()

#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	var le: LineEdit = cell as LineEdit
	if (!le):
		return
	
	if (value is int):
		le.text = str(float(value))
	elif (value is float):
		le.text = str(value)
	elif (value is String && value.is_valid_float()):
		le.text = value
	else:
		le.text = "0"


func create_cell() -> Control:
	# The default LineEdit is fine for the Integer cell
	var ret: LineEdit = .create_cell()
	
	var index: int = get_row_count()
	
	_apply_fstyle(ret)
	
	# warning-ignore:return_value_discarded
	ret.connect("text_entered", self, "_on_text_entered", [index])
	
	# warning-ignore:return_value_discarded
	ret.connect("text_changed", self, "_on_text_changed", [ret])
	
	# warning-ignore:return_value_discarded
	ret.connect("focus_entered", self, "_on_cell_focus", [ret])
	
	# warning-ignore:return_value_discarded
	ret.connect("focus_exited", self, "_on_cell_unfocus", [index, ret])
	
	# warning-ignore:return_value_discarded
	ret.connect("gui_input", self, "_on_cell_input", [ret, index])
	
	
	return ret


func check_style() -> void:
	for ri in get_row_count():
		var cell: LineEdit = get_cell_control(ri) as LineEdit
		if (cell):
			_apply_fstyle(cell)


func _init() -> void:
	rect_size.x = 60
