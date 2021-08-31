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

# This is a special "column" that is meant to show the row numbers / checkboxes to select/deselect them.
# Because it's not meant to be directly used it does not have a class_name

tool
extends Control

#######################################################################################################################
### Signals and definitions
signal row_selection_changed(index, selected)

signal delete_selected()

enum _RMenu {
	SelectAll,
	DeselectAll,
	InvertSelection,
	DeleteSelected,
}

#######################################################################################################################
### "Public" properties

#######################################################################################################################
### "Public" functions
func setup(s: TabularStyler) -> void:
	_styler = s
	var hstyle: StyleBox = _styler.get_header_box()
	
	_ccontainer = Control.new()
	_ccontainer.set_name("_ccontainer")
	_ccontainer.rect_clip_content = true
	_ccontainer.mouse_filter = Control.MOUSE_FILTER_PASS
	_ccontainer.set_anchor_and_margin(MARGIN_LEFT, 0, 0)
	_ccontainer.set_anchor_and_margin(MARGIN_RIGHT, 1, 0)
	add_child(_ccontainer)
	
	
	_btarea = Control.new()
	_btarea.set_name("_btarea")
	_btarea.set_anchor_and_margin(MARGIN_LEFT, 0, 0)
	_btarea.set_anchor_and_margin(MARGIN_RIGHT, 1, 0)
	add_child(_btarea)
	
	_btrowmenu = _CenterIconMenuButton.new(s)
	_btrowmenu.set_name("_btrowmenu")
	_btrowmenu.set_anchor_and_margin(MARGIN_LEFT, 0, hstyle.get_margin(MARGIN_LEFT))
	_btrowmenu.set_anchor_and_margin(MARGIN_TOP, 0, hstyle.get_margin(MARGIN_TOP))
	_btrowmenu.set_anchor_and_margin(MARGIN_RIGHT, 1, -hstyle.get_margin(MARGIN_RIGHT))
	_btrowmenu.set_anchor_and_margin(MARGIN_BOTTOM, 1, -hstyle.get_margin(MARGIN_BOTTOM))
	_btrowmenu.flat = false
	_btrowmenu.visible = false
	_btarea.add_child(_btrowmenu)
	
	_btrowmenu.get_popup().add_item("Select all", _RMenu.SelectAll)
	_btrowmenu.get_popup().add_item("Deselect all", _RMenu.DeselectAll)
	_btrowmenu.get_popup().add_item("Invert selection", _RMenu.InvertSelection)
	_btrowmenu.get_popup().add_separator()
	_btrowmenu.get_popup().add_item("Delete selected", _RMenu.DeleteSelected)
	
	
	# warning-ignore:return_value_discarded
	_ccontainer.connect("draw", self, "_on_draw_rnums")
	
	# warning-ignore:return_value_discarded
	_btarea.connect("draw", self, "_on_draw_btarea")
	
	
	# warning-ignore:return_value_discarded
	_btrowmenu.connect("about_to_show", self, "_on_rmenu_popup")
	
	# warning-ignore:return_value_discarded
	_btrowmenu.get_popup().connect("id_pressed", self, "_on_rmenu_id_pressed")



func clear() -> void:
	_row_count = 0
	_selected.clear()
	_btrowmenu.visible = false
	
	_ccontainer.update()


func get_selected() -> Array:
	return _selected.keys()


func is_selected(index: int) -> bool:
	return _selected.has(index)

func toggle_selected(index: int, emit: bool = false) -> void:
	if (index < 0 || index >= _row_count):
		return
	
	var nstate: bool = false
	if (_selected.has(index)):
		# warning-ignore:return_value_discarded
		_selected.erase(index)
	else:
		# Again, the _selected Dicionary is used as a set so it doesn't matter which value each entry is holding
		_selected[index] = 0
		nstate = true
	
	_ccontainer.update()
	
	if (emit):
		emit_signal("row_selection_changed", index, nstate)


func style_changed(hheight: float) -> void:
	_btrowmenu.add_stylebox_override("normal", _styler.get_normal_button())
	_btrowmenu.add_stylebox_override("focus", _styler.get_empty_stylebox())
	_btrowmenu.add_stylebox_override("hover", _styler.get_hovered_button())
	_btrowmenu.add_stylebox_override("pressed", _styler.get_pressed_button())
	_btrowmenu.update()
	
	var hstyle: StyleBox = _styler.get_header_box()
	_btrowmenu.set_anchor_and_margin(MARGIN_LEFT, 0, hstyle.get_margin(MARGIN_LEFT))
	_btrowmenu.set_anchor_and_margin(MARGIN_TOP, 0, hstyle.get_margin(MARGIN_TOP))
	_btrowmenu.set_anchor_and_margin(MARGIN_RIGHT, 1, -hstyle.get_margin(MARGIN_RIGHT))
	_btrowmenu.set_anchor_and_margin(MARGIN_BOTTOM, 1, -hstyle.get_margin(MARGIN_BOTTOM))
	
	_btarea.rect_size.y = hheight
	
	_btarea.update()
	_ccontainer.update()



func get_row_under_mouse() -> int:
	if (get_local_mouse_position().y < _btarea.rect_size.y || _row_height <= 0):
		return -1
	
	var ri: int = int(_ccontainer.get_local_mouse_position().y / _row_height)
	
	return ri if (ri >= 0 && ri < _row_count) else -1


func row_inserted_at(index: int) -> void:
	_ccontainer.rect_size.y += _row_height
	
	if (index < _row_count && _selected.size() > 0):
		var sel: Array = _selected.keys()
		_selected.clear()
		
		for s in sel:
			if (s < index):
				_selected[s] = 0
			else:
				_selected[s+1] = 0
	
	_row_count += 1
	_check_rm_visibility()
	update()


func row_removed_from(index: int) -> void:
	if (index < 0 || index >= _row_count):
		return
	
	_ccontainer.rect_size.y -= _row_height
	
	if (_selected.size() > 0):
		var sel: Array = _selected.keys()
		_selected.clear()
		
		for s in sel:
			if (s < index):
				_selected[s] = 0
			elif (s > index):
				_selected[s-1] = 0
	
	_row_count -= 1
	_check_rm_visibility()


func set_row_count(c: int) -> void:
	if (_row_count == c):
		return
	
	_row_count = c
	_ccontainer.rect_size.y = _row_height * _row_count
	
	_check_rm_visibility()
	_selected.clear()
	update()
	_ccontainer.update()


func set_row_height(h: float) -> void:
	if (_row_height == h):
		return
	
	_row_height = h
	_ccontainer.rect_size.y = _row_height * _row_count
	update()
	_ccontainer.update()


func set_scroll(v: float) -> void:
	_ccontainer.rect_position.y = -v + _btarea.rect_size.y


func set_flags(rownum: bool, checkbox: bool) -> void:
	_show_rownum = rownum
	_show_checkbox = checkbox
	
	_check_rm_visibility()


#######################################################################################################################
### "Private" definitions
# This is mostly do draw the Icon centered within the MenuButton
class _CenterIconMenuButton extends MenuButton:
	var styler: TabularStyler = null
	
	func _draw() -> void:
		var darrow: Texture = styler.get_down_arrow_icon()
		var chcolor: Color = styler.get_header_text_color()
		
		var x: float = (rect_size.x - darrow.get_width()) * 0.5
		var y: float = (rect_size.y - darrow.get_height()) * 0.5
		
		draw_texture(styler.get_down_arrow_icon(), Vector2(x, y), chcolor)
	
	func _init(s: TabularStyler) -> void:
		styler = s


#######################################################################################################################
### "Private" properties
# Hold number of rows, which will determine how many "cells" will be rendered
var _row_count: int = 0

# Cache the row height
var _row_height: float = 0.0

# The styler gets some style values from the parent control
var _styler: TabularStyler = null

# This will be used to help clip the "row number cells" unerneath the header area
var _ccontainer: Control = null

# This Control is used mostly to help hide the row number cells when scrolling occur
var _btarea: Control = null

# If this is true the checkbox for each row will be drawn
var _show_checkbox: bool = true

# If this is true the row number will be shown on each row
var _show_rownum: bool = true

# Each selected row *index* will have an entry in this Dictionary that is used as a Set
var _selected: Dictionary = {}

# Row menu button
var _btrowmenu: _CenterIconMenuButton = null

#######################################################################################################################
### "Private" functions
func _check_rm_visibility() -> void:
	_btrowmenu.visible = (_show_checkbox && _row_count > 0)

#######################################################################################################################
### Event handlers
func _on_draw_rnums() -> void:
	var box: StyleBox = _styler.get_header_box()
	var font: Font = _styler.get_header_font()
	var chkc: Texture = _styler.get_checked_icon()
	var chku: Texture = _styler.get_unchecked_icon()
	
	var csize: Vector2 = Vector2(rect_size.x, _row_height)
	var chk_width: float = max(chkc.get_width(), chku.get_width()) if _show_checkbox else 0.0
	
	var mleft: float = box.get_margin(MARGIN_LEFT)
	
	var by: float = 0.0
	
	for i in _row_count:
		var pos: Vector2 = Vector2(0, by)
		
		_ccontainer.draw_style_box(box, Rect2(pos, csize))
		
		if (_show_checkbox):
			var ctex: Texture = chkc if _selected.has(i) else chku
			var chkx: float = mleft
			var chky: float = (csize.y - ctex.get_height()) * 0.5
			
			_ccontainer.draw_texture(ctex, Vector2(chkx, chky) + pos)
		
		if (_show_rownum):
			var dstr: String = str(i + 1)
			var strsize: Vector2 = font.get_string_size(dstr)
			
			var strx: float = 0.0
			
			# FIXME: check header text alignment - the two lines bellow are for centered
			var rwidth: float = rect_size.x - chk_width
			strx = (rwidth - strsize.x) * 0.5 + chk_width
			
			var stry: float = UIHelper.get_text_vertical_center(font, csize.y)
			_ccontainer.draw_string(font, Vector2(strx, stry) + pos, dstr, _styler.get_header_text_color())
		
		
		by += _row_height


func _on_draw_btarea() -> void:
	var box: StyleBox = _styler.get_header_box()
	_btarea.draw_style_box(box, Rect2(_btarea.rect_position, _btarea.rect_size))



func _on_rmenu_popup() -> void:
	var idx: int = _btrowmenu.get_popup().get_item_index(_RMenu.DeleteSelected)
	_btrowmenu.get_popup().set_item_disabled(idx, _selected.size() == 0)


func _on_rmenu_id_pressed(id: int) -> void:
	match id:
		_RMenu.SelectAll:
			for i in _row_count:
				_selected[i] = 0
			
			_ccontainer.update()
		
		_RMenu.DeselectAll:
			_selected.clear()
			_ccontainer.update()
		
		_RMenu.InvertSelection:
			for i in _row_count:
				if (_selected.has(i)):
					# warning-ignore:return_value_discarded
					_selected.erase(i)
				else:
					_selected[i] = 0
			
			_ccontainer.update()
		
		_RMenu.DeleteSelected:
			# The DeleteSelected option is disabled when _selected.size() is 0, so there is no need to check that fact here.
			emit_signal("delete_selected")

#######################################################################################################################
### Overrides
#func _draw() -> void:
#	draw_rect(Rect2(Vector2(), rect_size), Color(0.1, 0.9, 0.1, 1.0))


func _gui_input(evt: InputEvent) -> void:
	if (evt is InputEventMouseButton):
		if (evt.is_pressed() && evt.button_index == BUTTON_LEFT && _show_checkbox):
			toggle_selected(get_row_under_mouse(), true)




func _init() -> void:
	rect_clip_content = true
	mouse_filter = Control.MOUSE_FILTER_PASS



