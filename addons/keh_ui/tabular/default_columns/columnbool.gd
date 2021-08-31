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
class Cell extends Control:
	var val: bool = false


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_draw_bool(cell: Cell) -> void:
	var tex: Texture = _styler.get_checked_icon() if cell.val else _styler.get_unchecked_icon()
	
	var x: float = (cell.rect_size.x - tex.get_width()) * 0.5
	var y: float = (cell.rect_size.y - tex.get_height()) * 0.5
	
	cell.draw_texture(tex, Vector2(x, y))


func _on_cell_input(evt: InputEvent, row: int, cell: Cell) -> void:
	if (evt is InputEventMouseButton && evt.is_pressed() && evt.button_index == BUTTON_LEFT):
		notify_value_entered(row, !cell.val)
		cell.update()


#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	var c: Cell = cell as Cell
	if (!c):
		return
	
	if (value is bool):
		c.val = value
	elif (value is String):
		var low: String = value.to_lower()
		c.val = true if (low == "true" || low == "enabled") else false
	elif (value is int):
		c.val = true if value > 0 else false
	else:
		c.val = false


func create_cell() -> Control:
	var index: int = get_row_count()
	
	var ret: Cell = Cell.new()
	
	# warning-ignore:return_value_discarded
	ret.connect("draw", self, "_on_draw_bool", [ret])
	
	# warning-ignore:return_value_discarded
	ret.connect("gui_input", self, "_on_cell_input", [index, ret])
	
	return ret


func get_min_row_height() -> float:
	var orow: StyleBox = _styler.get_oddrow_box()
	var erow: StyleBox = _styler.get_evenrow_box()
	var ctex: Texture = _styler.get_checked_icon()
	var utex: Texture = _styler.get_unchecked_icon()
	
	# Calculate the internal vertical margin for the two possible cell background styles
	var oh: float = orow.get_margin(MARGIN_TOP) + orow.get_margin(MARGIN_BOTTOM)
	var eh: float = erow.get_margin(MARGIN_TOP) + erow.get_margin(MARGIN_BOTTOM)
	
	
	return (max(oh, eh) + max(ctex.get_height(), utex.get_height()))


