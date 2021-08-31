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

# This is a special column. Values will be any of the supported "Unique*" value types of the
# DBTable. Each value is meant to point into the ID of a different table of the same database.

# Desired features:
# - The displayed should be a section rendering the selected ID, a button that if clicked will clear the value and another
#   one that will display a preview window of that rows (sort of unwrapping the values)
# - Clicking the cell should drop down a menu containing a line edit to filter the optoins plus all non filtered rows
#   of the referenced table (for a this a custom control extending Popup should be created)
# - Perhaps make the preview window to also allow editing the values of the row of the external table (this may be extremely
#   convenient when editing the database!).
#
# To solve:
# - How (and when) to specify which table should be referenced? Because of how the value type works within the context menu
#   the external table itself it is very difficult to provide means to change (after creation) which table to reference.
# - How to gather (from this class) the necessary data to populate the drop down menu?


# For this to be implemented, the Database itself must have some extra funcionality specifically for this kind of usage.
# Something to keep in mind: The DB implementation must provide means to prevent two tables from referencing each other.

tool
extends "res://addons/keh_ui/tabular/columnbase.gd"


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func set_other_table(tb: DBTable) -> void:
	_reftable = tb
	
	_corder = tb.get_column_order() if tb else []

#######################################################################################################################
### "Private" definitions
class SizesCache:
	var margin_left: float = 0.0
	var margin_top: float = 0.0
	var margin_right: float = 0.0
	var margin_bottom: float = 0.0
	
	var font_height: float = 0.0


# Meant to display the row's columns in a "compact" way
class RowPreview extends Control:
	var _info: Array = []
	
	func clear() -> void:
		_info.clear()
		update()
	
	func copy_info(i: Array) -> void:
		_info.clear()
		_info = i.duplicate()
		update()
	
	func set_info(i: Array) -> void:
		_info = i
	
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		rect_clip_content = true



class PopRow extends Control:
	# Not static typing because the row ID may be either TYPE_INT or TYPE_STRING
	# Because this value will be persisted this should remain with the original type (String or Integer)
	var _rid
	
	# True if mouse is over this row
	var _mover: bool = false
	
	# Cache the row preview
	var _rprev: RowPreview = null
	
	func set_data(id, prev: RowPreview, margins: SizesCache) -> void:
		_rid = id
		_rprev = prev
		add_child(prev)
		
		# The set_anchor_and_margin() is not working correctly for this specific configuration.
		
		prev.anchor_left = 0
		prev.anchor_top = 1
		prev.anchor_right = 1
		prev.anchor_bottom = 1
		
		prev.margin_left = margins.margin_left
		prev.margin_top = -(margins.margin_bottom + margins.font_height * 2)
		prev.margin_right = -margins.margin_right
		prev.margin_bottom = -margins.margin_bottom
	
	
	func get_id():
		return _rid
	
	func get_rdata() -> Array:
		return _rprev._info
	
	
	func get_idstr() -> String:
		if (typeof(_rid) == TYPE_INT):
			return str(_rid)
		elif (typeof(_rid) == TYPE_STRING):
			return _rid
		
		return ""
	
	
	func apply_filter(f: String) -> void:
		if (f.empty()):
			visible = true
			return
		
		var idl: String = get_idstr().to_lower()
		if (idl.find(f) != -1):
			# The ID containing the filtering string is enough to keep the entry visible
			visible = true
			return
		else:
			# Must check the referenced column values.
			var rdata: Array = get_rdata()
			for d in rdata:
				var vlow: String = d.value.to_lower()
				if (vlow.find(f) != -1):
					visible = true
					return
			
			
			visible = false
	
	
	func is_mouse_over() -> bool:
		return _mover
	
	
	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_MOUSE_ENTER:
				_mover = true
				update()
			
			NOTIFICATION_MOUSE_EXIT:
				_mover = false
				update()



class TablePopup extends Popup:
	var _mvbox: VBoxContainer = VBoxContainer.new()
	var _rvbox: VBoxContainer = VBoxContainer.new()
	var _filter: LineEdit = LineEdit.new()
	
	
	func clear() -> void:
		for c in _rvbox.get_children():
			c.queue_free()
		
		rect_size = Vector2(0, _filter.rect_size.y)
	
	
	func add_row(r: PopRow) -> void:
		_rvbox.add_child(r)
		
		var sep: int = _rvbox.get_constant("separation")
		rect_size.y += r.rect_size.y + sep
	
	
	func _on_filtering(ntxt: String) -> void:
		var lower: String = ntxt.to_lower()
		for r in _rvbox.get_children():
			if (r is PopRow):
				r.apply_filter(lower)
	
	
	func _draw() -> void:
		var pnl: StyleBox = get_stylebox("panel", "PopupMenu")
		draw_style_box(pnl, Rect2(Vector2(), rect_size))
	
	
	func _init() -> void:
		var pnl: StyleBox = get_stylebox("panel", "PopupMenu")
		
		rect_min_size = Vector2(200 + pnl.get_margin(MARGIN_LEFT) + pnl.get_margin(MARGIN_RIGHT), 0)
		add_child(_mvbox)
		
		_mvbox.set_anchor_and_margin(MARGIN_LEFT, 0, pnl.get_margin(MARGIN_LEFT))
		_mvbox.set_anchor_and_margin(MARGIN_TOP, 0, pnl.get_margin(MARGIN_TOP))
		_mvbox.set_anchor_and_margin(MARGIN_RIGHT, 1, -pnl.get_margin(MARGIN_RIGHT))
		_mvbox.set_anchor_and_margin(MARGIN_BOTTOM, 1, -pnl.get_margin(MARGIN_BOTTOM))
		
		_mvbox.add_child(_filter)
		
		_filter.placeholder_text = "Filter..."
		_filter.clear_button_enabled = true
		# warning-ignore:return_value_discarded
		_filter.connect("text_changed", self, "_on_filtering")
		
		
		var scont: ScrollContainer = ScrollContainer.new()
		scont.size_flags_horizontal = SIZE_EXPAND_FILL
		scont.size_flags_vertical = SIZE_EXPAND_FILL
		_mvbox.add_child(scont)
		
		_rvbox.size_flags_horizontal = SIZE_EXPAND_FILL
		_rvbox.size_flags_vertical = SIZE_EXPAND_FILL
		scont.add_child(_rvbox)


class Cell extends Control:
	var btval: Button = Button.new()
	var rpreview: RowPreview = RowPreview.new()
	var btclear: Button = Button.new()
	
	var _index: int = -1
	
	func set_value(val, rdata: Array) -> void:
		if (val is int):
			btval.text = str(val)
		elif (val is String):
			btval.text = val
		else:
			clear()
			return
		
		btclear.visible = true
		
		if (rdata.size() > 0):
			rpreview.copy_info(rdata)
		
		var ttip: String = btval.text
		
		for d in rdata:
			ttip += "\n%s: %s" % [d.name, d.value]
		
		hint_tooltip = ttip
	
	
	func clear() -> void:
		btval.text = "..."
		rpreview.clear()
		btclear.visible = false
		hint_tooltip = ""
	
	
	func set_index(i: int) -> void:
		_index = i
	
	
	func get_index() -> int:
		return _index
	
	
	#func _draw() -> void:
	#	draw_rect(Rect2(Vector2(), rect_size), Color(0.2, 0.8, 0.2, 1.0))
	
	func _init() -> void:
		btval.text = "..."
		btval.align = Button.ALIGN_LEFT
		add_child(btval)
		btval.anchor_left = 0
		btval.anchor_top = 1
		btval.anchor_right = 1
		btval.anchor_bottom = 1
		
		btval.margin_left = 0
		btval.margin_bottom = 0
		
		add_child(rpreview)
		
		rpreview.anchor_left = 0
		rpreview.anchor_top = 0
		rpreview.anchor_right = 1
		rpreview.anchor_bottom = 0
		
		rpreview.margin_top = 0
		rpreview.margin_left = 0
		rpreview.margin_right = 0
		
		btclear.set_name("clear")
		btclear.hint_tooltip = "Clear"
		btclear.mouse_filter = Control.MOUSE_FILTER_PASS
		btclear.visible = false
		btclear.expand_icon = true
		add_child(btclear)
		
		btclear.anchor_left = 1
		btclear.anchor_top = 1
		btclear.anchor_right = 1
		btclear.anchor_bottom = 1



#######################################################################################################################
### "Private" properties
var _tbpop: TablePopup = TablePopup.new()

# Hold the referenced table. This will be necessary in order to properly populate the drop down menu
var _reftable: DBTable = null

## Cache some data to make things easier when drawing
# The correct column order of the referenced table
var _corder: Array = []

# Sizes to correctly position rendered data
var _sizes: SizesCache = SizesCache.new()

# Load the "vlines" texture box (it's set as a resource - stl_vlines.tres)
var _vlines: Texture = preload("vlines_6x6.png")


#######################################################################################################################
### "Private" functions
func _apply_style(cell: Cell) -> void:
	style_button(cell.btval)
	
	var tbin: Texture = _styler.get_trash_bin_icon()
	var tbh: float = get_button_min_height()
	var cmargins: Dictionary = get_cell_internal_margins()
	
	cell.btval.margin_top = -tbh
	cell.btval.margin_right = -(tbin.get_width() + _sizes.margin_left + cmargins.left)
	cell.rpreview.margin_bottom = _sizes.font_height * 2.0 + _sizes.margin_top
	
	cell.btclear.add_stylebox_override("normal", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("hover", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("pressed", _styler.get_empty_stylebox())
	cell.btclear.add_stylebox_override("focus", _styler.get_empty_stylebox())
	
	cell.btclear.icon = tbin
	
	cell.btclear.margin_left = -tbh
	cell.btclear.margin_top = -tbh
	cell.btclear.margin_right = 0
	cell.btclear.margin_bottom = 0


func _generate_row_data(row: Dictionary, font: Font) -> Array:
	var ret: Array = []
	
	if (row.size() > 0):
		for cname in _corder:
			var val = row[cname]
			var sval: String = val if val is String else str(val)
			
			ret.append({
				"name": cname,
				"value": sval,
				"width": max(font.get_string_size(cname).x, font.get_string_size(sval).x)
			})
	
	return ret



#######################################################################################################################
### Event handlers
func _on_btval_clicked(cell: Cell) -> void:
	if (!_reftable):
		return
	
	var font: Font = _styler.get_cell_font()
	var btheight: = (_sizes.margin_top + 6) + (_sizes.margin_bottom + 6) + _sizes.font_height
	
	var rheight: float = btheight * 2
	
	var ppos: Vector2 = cell.rect_global_position
	ppos.y += cell.btval.rect_size.y
	
	_tbpop.clear()
	
	for ri in _reftable.get_row_count():
		var row: Dictionary = _reftable.get_row_by_index(ri)
		var prow: PopRow = PopRow.new()
		var prev: RowPreview = RowPreview.new()
		
		prow.rect_min_size = Vector2(90, rheight)
		prow.rect_size = Vector2(90, rheight)
		
		prev.set_info(_generate_row_data(row, font))
		
		prow.set_data(row.id, prev, _sizes)
		
		_tbpop.add_row(prow)
		
		
		# warning-ignore:return_value_discarded
		prow.connect("draw", self, "_on_draw_pop_row", [prow])
		
		# warning-ignore:return_value_discarded
		prow.connect("gui_input", self, "_on_poprow_input", [prow, cell])
		
		# warning-ignore:return_value_discarded
		prev.connect("draw", self, "_on_draw_row_preview", [prev])
	
	
	_tbpop.rect_global_position = ppos
	_tbpop.popup()


func _on_btclear_clicked(cell: Cell) -> void:
	var val
	if (_reftable.get_id_type() == TYPE_INT):
		val = -1
	elif (_reftable.get_id_type() == TYPE_STRING):
		val = ""
	else:
		return
	
	cell.clear()
	notify_value_entered(cell.get_index(), val)




func _on_poprow_input(evt: InputEvent, row: PopRow, cell: Cell) -> void:
	if (evt is InputEventMouseButton && evt.is_pressed() && evt.button_index == BUTTON_LEFT):
		cell.set_value(row.get_id(), row.get_rdata())
		_tbpop.hide()
		
		notify_value_entered(cell.get_index(), row.get_id())





func _on_draw_pop_row(row: PopRow) -> void:
	var font: Font = _styler.get_cell_font()
	var fcolor: Color = _styler.get_cell_text_color()
	
	
	if (row.is_mouse_over()):
		var stl: StyleBox = _styler.get_hovered_button()
		row.draw_style_box(stl, Rect2(Vector2(), row.rect_size))
	
	var x: float = _sizes.margin_left + 6
	var y: float = font.get_ascent() + (_sizes.margin_top + 6)
	
	row.draw_string(font, Vector2(x, y), row.get_idstr(), fcolor)




func _on_draw_row_preview(rp: RowPreview) -> void:
	var font: Font = _styler.get_cell_font()
	var fcolor: Color = _styler.get_cell_text_color()
	
	var y0: float = font.get_ascent()
	var y1: float = y0 + font.get_height()
	
	var x: float = 0.0
	
	for i in rp._info:
		if (x > 0):
			rp.draw_texture_rect(_vlines, Rect2(Vector2(x, 0), Vector2(_vlines.get_width(), rp.rect_size.y)), true, fcolor)
			
			x += _vlines.get_width()
		
		rp.draw_string(font, Vector2(x, y0), i.name, fcolor)
		rp.draw_string(font, Vector2(x, y1), i.value, fcolor)
		
		x += i.width


#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	if (!(cell is Cell)):
		return
	
	var row: Dictionary = _reftable.get_row(value) if _reftable else {}
	if (row.empty()):
		cell.clear()
	
	else:
		var font: Font = _styler.get_cell_font()
		cell.set_value(value, _generate_row_data(row, font))



func create_cell() -> Control:
	var index: int = get_row_count()
	var ret: Cell = Cell.new()
	ret.set_index(index)
	
	ret.btval.hint_tooltip = "Select row ID from '%s' table" % (_reftable.get_table_name() if _reftable else "Invalid Table")
	
	# warning-ignore:return_value_discarded
	ret.btval.connect("pressed", self, "_on_btval_clicked", [ret])
	
	# warning-ignore:return_value_discarded
	ret.btclear.connect("pressed", self, "_on_btclear_clicked", [ret])
	
	# warning-ignore:return_value_discarded
	ret.rpreview.connect("draw", self, "_on_draw_row_preview", [ret.rpreview])
	
	_apply_style(ret)
	
	return ret


func get_min_row_height() -> float:
	var margins: Dictionary = get_cell_internal_margins()
	var btheight: float = get_button_min_height()
	
	return ((margins.top * 2.0) + (btheight * 3.0))



func check_style() -> void:
	var font: Font = _styler.get_cell_font()
	
	_sizes.font_height = font.get_height()
	
	var btmargins: Dictionary = get_button_margins()
	
	_sizes.margin_left = btmargins.left
	_sizes.margin_top = btmargins.top
	_sizes.margin_right = btmargins.right
	_sizes.margin_bottom = btmargins.bottom
	
	for ci in get_row_count():
		var cell: Cell = get_cell_control(ci)
		_apply_style(cell)



func _init() -> void:
	rect_size.x = 120
	
	
	add_child(_tbpop)
