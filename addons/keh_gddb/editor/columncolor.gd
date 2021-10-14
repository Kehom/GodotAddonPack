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
extends "res://addons/keh_ui/tabular/default_columns/columnfloat.gd"


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


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_color_changed(c: Color, index: int) -> void:
	notify_value_entered(index, c)


#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	if (!(cell is ColorPickerButton) || !(value is Color)):
		return
	
	cell.color = value



func create_cell() -> Control:
	# Ideally the entire column should share a single instance of hte ColorPicker Control. However, setting the cell
	# to be the ColorPickerButton makes things a lot easier here. *IF* this becomes a problem in terms of resource (RAM)
	# usage, then transition into an ordinary button that will popup the color picker. Note that this extra usage should
	# be limited only to the editor when the table containing the color type is opened.
	var ret: ColorPickerButton = ColorPickerButton.new()
	
	style_button(ret)
	
	#warning-ignore:return_value_discarded
	ret.connect("color_changed", self, "_on_color_changed", [get_row_count()])
	
	return ret



func check_style() -> void:
	for i in get_row_count():
		var c: ColorPickerButton = get_cell_control(i)
		style_button(c)

