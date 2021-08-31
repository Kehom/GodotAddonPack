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
extends Control


#######################################################################################################################
### Signals and definitions
signal title_entered(oldt, newt)

signal value_entered(col, row, nval)

signal request_move_left(from)
signal request_move_right(from)


enum FlagSettings {
	AllowTitleEdit =       0b000000001,
	AllowMenu =            0b000000010,
	AllowResize =          0b000000100,
	LockIndex =            0b000001000,
	AllowTypeChange =      0b000010000,
	AllowSorting =         0b000100000,
	ValueChangeSignal =    0b001000000,
	# Default = AllowTitleEdit | AllowMenu | AllowResize | AllowTypeChange | AllowSorting
	_Default =             0b000110111,
}


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# If the derived class uses an editing cell Control that is not a LineEdit then this function *must* be overridden
func set_row_value(cell: Control, value) -> void:
	var le: LineEdit = cell as LineEdit
	if (!le):
		return
	
	if (value is String):
		le.text = value
	elif (value != null):
		le.text = str(value)
	else:
		le.text = ""



# By default cells will be represented by LineEdit controls. Obviously this function needs to be overridden in order
# to use other types of Controls if those are required on custom columns.
# Ideally the control should be "fully transparent" as the actual cell will be drawn in here (TabularColumnBase)
func create_cell() -> Control:
	var ncell: LineEdit = LineEdit.new()
	ncell.text = ""
	ncell.add_constant_override("minimum_spaces", 1)
	ncell.context_menu_enabled = false
	ncell.caret_blink = true
	
	ncell.add_stylebox_override("normal", _styler.get_empty_stylebox())
	ncell.add_stylebox_override("focus", _styler.get_empty_stylebox())
	ncell.add_font_override("font", _styler.get_cell_font())
	
	return ncell



# If a custom column require more height for its rows then override this function
func get_min_row_height() -> float:
	var orow: StyleBox = _styler.get_oddrow_box()
	var erow: StyleBox = _styler.get_evenrow_box()
	var font: Font = _styler.get_cell_font()
	
	# Calculate the internal vertical margin for both possible cell styles
	var oh: float = orow.get_margin(MARGIN_TOP) + orow.get_margin(MARGIN_BOTTOM)
	var eh: float = erow.get_margin(MARGIN_TOP) + erow.get_margin(MARGIN_BOTTOM)
	
	# Return the biggest internal vertical margin plus the font height
	return (max(oh, eh) + font.get_height())


func check_style() -> void:
	pass




### Functions bellow here are not meant to be overridden
# This function can be used be derived classes to easily apply the button styling into the provided button instance
func style_button(bt: Button) -> void:
	bt.add_stylebox_override("normal", _styler.get_normal_button())
	bt.add_stylebox_override("hover", _styler.get_hovered_button())
	bt.add_stylebox_override("pressed", _styler.get_pressed_button())
	bt.add_stylebox_override("focus", _styler.get_empty_stylebox())
	
	bt.add_font_override("font", _styler.get_cell_font())
	bt.add_color_override("font_color", _styler.get_cell_text_color())
	bt.add_color_override("font_color_hover", _styler.get_cell_text_color())
	bt.add_color_override("font_color_pressed", _styler.get_cell_text_color())
	
	bt.mouse_filter = MOUSE_FILTER_PASS
	bt.clip_text = true
	
	if (bt is CenterIconButton):
		bt.color = _styler.get_header_text_color()




func setup(s: TabularStyler, c: Dictionary) -> void:
	_styler = s
	
	_hidebuttons = c.hide_buttons
	_autoedit = c.autoedit
	
	_margin = _MarginCache.new()
	_margin.cache(_styler.get_oddrow_box(), _styler.get_evenrow_box())
	
	# Create the inner container to hold cells
	_cellnodes = Control.new()
	_cellnodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cellnodes)
	
	# Create the header area - this was originally set as HBoxContainer, however it caused problems with sizing and
	# positioning. Namely, it didn't allow 0 height on internal controls, which was the base idea to help hide the buttons
	# without moving the LineEdit control from its position when setting the flag to only show the buttons when the mouse
	# is over the column. Using a Control forces manually setting the positioning but at least it becomes possible to
	# actually hide the buttons while still keeping the title editing control in place
	_hbox = Control.new()
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hbox)
	
	# Create the "move left" button
	_btmleft = CenterIconButton.new()
	_btmleft.set_name("_moveleft")
	_btmleft.add_stylebox_override("focus", _styler.get_empty_stylebox())
	_btmleft.visible = false
	_btmleft.mouse_filter = Control.MOUSE_FILTER_PASS
	_hbox.add_child(_btmleft)
	
	# Create the title editor, which will also render the string
	_title = LineEdit.new()
	_title.set_name("_title")
	_title.context_menu_enabled = false
	_title.add_constant_override("minimum_spaces", 1)
	_title.add_stylebox_override("normal", _styler.get_empty_stylebox())
	_title.add_stylebox_override("focus", _styler.get_empty_stylebox())
	_title.add_stylebox_override("read_only", _styler.get_empty_stylebox())
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_title.caret_blink = true
	
	_hbox.add_child(_title)
	
	
	# Create the "move right" button
	_btmright = CenterIconButton.new()
	_btmright.set_name("_moveright")
	_btmright.add_stylebox_override("focus", _styler.get_empty_stylebox())
	_btmright.visible = false
	_btmright.mouse_filter = Control.MOUSE_FILTER_PASS
	_hbox.add_child(_btmright)
	
	
	# warning-ignore:return_value_discarded
	_cellnodes.connect("draw", self, "_on_draw_cells")
	
	# warning-ignore:return_value_discarded
	_title.connect("focus_entered", self, "_on_title_focused")
	
	# warning-ignore:return_value_discarded
	_title.connect("focus_exited", self, "_on_title_unfocused")
	
	# warning-ignore:return_value_discarded
	_title.connect("text_entered", self, "_on_title_entered")
	
	# warning-ignore:return_value_discarded
	_btmleft.connect("pressed", self, "_on_move_left_clicked")
	
	# warning-ignore:return_value_discarded
	_btmright.connect("pressed", self, "_on_move_right_clicked")
	
	# warning-ignore:return_value_discarded
	_hbox.connect("draw", self, "_on_draw_hbox")




# This should be called when a cell editor changes its value
func notify_value_entered(row: int, value) -> void:
	var ctrl: Control = _cellnodes.get_child(row) as Control
	if (!ctrl):
		return
	
	# Check if the "new" value is actually different from the old one.
	var oval = ctrl.get_meta("value")
	if (oval == value):
		# Not really changed, so do nothing.
		return
	
	# OK, the value did change. Do not update the meta just yet. Just tell the value has been changed and the TabularBox
	# will relay this to the data source. At that moment the set_rvalue() function will be called, which will take care
	# of updating the meta (if it's the case).
	emit_signal("value_entered", self, row, value)


func style_changed(hheight: float, btsz: float) -> void:
	var move_bt_size: Vector2 = Vector2(btsz, btsz)
	_header_height = hheight
	
	var hstyle: StyleBox = _styler.get_header_box()
	var btns: StyleBox = _styler.get_normal_button()
	var bths: StyleBox = _styler.get_hovered_button()
	var btps: StyleBox = _styler.get_pressed_button()
	
	var font: Font = _styler.get_header_font()
	
	var has_buttons: bool = !is_index_locked()
	
	_btmleft.add_stylebox_override("normal", btns)
	_btmleft.add_stylebox_override("hover", bths)
	_btmleft.add_stylebox_override("pressed", btps)
	_btmleft.cicon = _styler.get_left_arrow_icon()
	_btmleft.color = _styler.get_header_text_color()
	_btmleft.rect_min_size = move_bt_size
	_btmleft.rect_size = move_bt_size
	
	_btmright.add_stylebox_override("normal", btns)
	_btmright.add_stylebox_override("hover", bths)
	_btmright.add_stylebox_override("pressed", btps)
	_btmright.cicon = _styler.get_right_arrow_icon()
	_btmright.color = _styler.get_header_text_color()
	_btmright.rect_min_size = move_bt_size
	_btmright.rect_size = move_bt_size
	
	_title.align = _styler.get_header_align()
	_title.add_font_override("font", font)
	_title.add_color_override("font_color", _styler.get_header_text_color())
	_title.rect_size.y = hheight
	
	# Setup the box holding the buttons
	_hbox.set_anchor_and_margin(MARGIN_LEFT, 0, 0)
	_hbox.set_anchor_and_margin(MARGIN_TOP, 0, 0)
	_hbox.set_anchor_and_margin(MARGIN_RIGHT, 1, 0)
	_hbox.set_anchor_and_margin(MARGIN_BOTTOM, 0, hheight)
	
	# Height of the _cellnodes control will be determined by the row count (in other words, dynamically).
	_cellnodes.set_anchor_and_margin(MARGIN_LEFT, 0, 0)
	_cellnodes.set_anchor_and_margin(MARGIN_RIGHT, 1, 0)
	
	# Position the buttons and the title editor
	var mleft: float = hstyle.get_margin(MARGIN_LEFT)
	var mright: float = hstyle.get_margin(MARGIN_RIGHT)
	
	_title.set_anchor_and_margin(MARGIN_LEFT, 0, btsz + mleft + mleft if has_buttons else 0.0)
	_title.set_anchor_and_margin(MARGIN_TOP, 0, 0)
	_title.set_anchor_and_margin(MARGIN_RIGHT, 1, -(btsz + mleft + mright) if has_buttons else 0.0)
	_title.set_anchor_and_margin(MARGIN_BOTTOM, 1, 0)
	
	_btmleft.rect_size = Vector2(btsz, btsz)
	_btmright.rect_size = Vector2(btsz, btsz)
	_position_buttons()
	
	if (!has_buttons):
		_btmleft.visible = false
		_btmright.visible = false
	else:
		_btmleft.visible = !_hidebuttons
		_btmright.visible = !_hidebuttons
	
	# Calculate the minimum size required for this control (specially width) so at least one character can be rendered
	var minw: float = 0.0
	var ab: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for a in ab.length():
		minw = max(minw, font.get_string_size(ab[a]).x)
	
	if (has_buttons):
		# Take the two buttons into account for the min size
		minw += (2.0 * btsz) + (2.0 * hstyle.get_margin(MARGIN_LEFT))
	
	rect_min_size.x = (minw + hstyle.get_margin(MARGIN_LEFT) + hstyle.get_margin(MARGIN_RIGHT))
	
	# Derived classes may need something special with the styling. In that case the check_style() must
	# be overridden.
	check_style()


func get_cell_internal_margins() -> Dictionary:
	var orow: StyleBox = _styler.get_oddrow_box()
	var erow: StyleBox = _styler.get_evenrow_box()
	
	return {
		"left": max(orow.get_margin(MARGIN_LEFT), erow.get_margin(MARGIN_LEFT)),
		"top": max(orow.get_margin(MARGIN_TOP), erow.get_margin(MARGIN_TOP)),
		"right": max(orow.get_margin(MARGIN_RIGHT), erow.get_margin(MARGIN_RIGHT)),
		"bottom": max(orow.get_margin(MARGIN_BOTTOM), erow.get_margin(MARGIN_BOTTOM))
	}

func get_cell_font_height() -> float:
	var f: Font = _styler.get_cell_font()
	return f.get_height()


func get_button_min_height() -> float:
	var font: Font = _styler.get_cell_font()
	var btn: StyleBox = _styler.get_normal_button()
	var btp: StyleBox = _styler.get_pressed_button()
	var bth: StyleBox = _styler.get_hovered_button()
	
	var ret: float = font.get_height()
	
	var vmargin: float = btn.get_margin(MARGIN_TOP) + btn.get_margin(MARGIN_BOTTOM)
	vmargin = max(vmargin, btp.get_margin(MARGIN_TOP) + btp.get_margin(MARGIN_BOTTOM))
	vmargin = max(vmargin, bth.get_margin(MARGIN_TOP) + bth.get_margin(MARGIN_BOTTOM))
	
	ret += vmargin
	
	return ret


func get_button_margins() -> Dictionary:
	var btn: StyleBox = _styler.get_normal_button()
	var btp: StyleBox = _styler.get_pressed_button()
	var bth: StyleBox = _styler.get_hovered_button()
	
	return {
		"left": max(btn.get_margin(MARGIN_LEFT), max(btp.get_margin(MARGIN_LEFT), bth.get_margin(MARGIN_LEFT))),
		"top": max(btn.get_margin(MARGIN_TOP), max(btp.get_margin(MARGIN_TOP), bth.get_margin(MARGIN_TOP))),
		"right": max(btn.get_margin(MARGIN_RIGHT), max(btp.get_margin(MARGIN_RIGHT), bth.get_margin(MARGIN_RIGHT))),
		"bottom": max(btn.get_margin(MARGIN_BOTTOM), max(btp.get_margin(MARGIN_BOTTOM), bth.get_margin(MARGIN_BOTTOM))),
	}


func get_cell_control(index: int) -> Control:
	if (index < 0 || index >= _cellnodes.get_child_count()):
		return null
	
	return _cellnodes.get_child(index) as Control


func set_hide_buttons(e: bool) -> void:
	_hidebuttons = e
	_check_flags()



func set_autoedit(e: bool) -> void:
	_autoedit = e

func get_autoedit() -> bool:
	return _autoedit


func revert_value_change(row: int) -> void:
	var ctrl: Control = _cellnodes.get_child(row) as Control
	if (!ctrl):
		return
	
	set_row_value(ctrl, ctrl.get_meta("value"))
	# No need to notify anything here because in theory nothing has changed outside


func set_title(t: String) -> void:
	_title.text = t
	_ctitle = t

func get_title() -> String:
	return _ctitle

func confirm_title_change() -> void:
	_ctitle = _title.text

func revert_title_change() -> void:
	_title.text = _ctitle
	_title.grab_focus()
	_title.select_all()


func get_header_height() -> float:
	return _header_height

func get_data_height() -> float:
	return rect_size.y - _header_height


func get_row_count() -> int:
	return _cellnodes.get_child_count()


func add_row() -> void:
	var ncell: Control = create_cell()
	if (ncell):
		ncell.mouse_filter = Control.MOUSE_FILTER_PASS
		ncell.rect_clip_content = true
		
		var y: float = _row_height * _cellnodes.get_child_count()
		_cellnodes.add_child(ncell)
		_cellnodes.rect_size.y += _row_height
		rect_size.y += _row_height
		
		ncell.rect_size = Vector2(rect_size.x - (_margin.left + _margin.right), _row_height - (_margin.top + _margin.bottom))
		ncell.rect_position = Vector2(_margin.left, _margin.top + y)



func remove_row() -> void:
	var l: int = get_row_count() - 1
	
	var c: Control = _cellnodes.get_child(l)
	
	# Remove the child otherwise the row count will not be correctly updated
	_cellnodes.remove_child(c)
	
	# Then delete the node
	c.queue_free()
	
	rect_size.y -= _row_height
	
	_cellnodes.call_deferred("update")



func set_row_height(h: float) -> void:
	if (_row_height == h):
		return
	
	_row_height = h
	
	_check_sizes()
	
	_cellnodes.update()


func get_row_under_mouse() -> int:
	if (get_local_mouse_position().y < _header_height):
		return -1
	
	var ri: int = int(_cellnodes.get_local_mouse_position().y / _row_height)
	
	return ri if (ri >= 0 && ri < get_row_count()) else -1


func set_scroll(y: float) -> void:
	_cellnodes.rect_position.y = -y + _header_height


func set_flags(f: int) -> void:
	_flags = f
	_check_flags()


func can_edit_title() -> bool:
	return _is_set(FlagSettings.AllowTitleEdit)

func set_can_edit_title(e: bool) -> void:
	_change_flag(FlagSettings.AllowTitleEdit, e)
	_check_flags()


func allow_menu() -> bool:
	return _is_set(FlagSettings.AllowMenu)

func set_allow_menu(e: bool) -> void:
	_change_flag(FlagSettings.AllowMenu, e)


func allow_resize() -> bool:
	return _is_set(FlagSettings.AllowResize)

func set_allow_resize(e: bool) -> void:
	_change_flag(FlagSettings.AllowResize, e)


func is_index_locked() -> bool:
	return _is_set(FlagSettings.LockIndex)

func set_index_locked(e: bool) -> void:
	_change_flag(FlagSettings.LockIndex, e)


func can_change_type() -> bool:
	return _is_set(FlagSettings.AllowTypeChange)

func set_allow_type_change(e: bool) -> void:
	_change_flag(FlagSettings.AllowTypeChange, e)


func allow_sorting() -> bool:
	return _is_set(FlagSettings.AllowSorting)

func set_allow_sorting(e: bool) -> void:
	_change_flag(FlagSettings.AllowSorting, e)


func value_change_signal() -> bool:
	return _is_set(FlagSettings.ValueChangeSignal)

func set_value_change_signal(e: bool) -> void:
	_change_flag(FlagSettings.ValueChangeSignal, e)


func set_value_type(t: int) -> void:
	_type = t

func get_value_type() -> int:
	return _type


func set_column_index(i: int) -> void:
	_cindex = i

func get_column_index() -> int:
	return _cindex


# The TabularBox will call this when setting a cell value (normally when loading a data source - or adding new data).
func set_rvalue(rindex: int, val) -> void:
	# Use the meta feature to save the value. The thing is, depending on how the Control works there will be no automatic
	# way to check the old vs new value. Instead of creating subfields within a Dictionary or something, just use the
	# meta to store the "old value". Indeed, this means the actual value of the cell will probably be stored on multiple
	# locations within RAM
	if (rindex < 0 || rindex >= _cellnodes.get_child_count()):
		return
	
	var cell: Control = _cellnodes.get_child(rindex) as Control
	cell.set_meta("value", val)
	
	set_row_value(cell, val)
	_cellnodes.update()



#######################################################################################################################
### "Private" definitions
# A single instance of this will be used to cache the four internal margins of the cell's style
class _MarginCache:
	var left: float
	var top: float
	var right: float
	var bottom: float
	
	func cache(odd: StyleBox, even: StyleBox) -> void:
		left = max(odd.get_margin(MARGIN_LEFT), even.get_margin(MARGIN_LEFT))
		top = max(odd.get_margin(MARGIN_TOP), even.get_margin(MARGIN_TOP))
		right = max(odd.get_margin(MARGIN_RIGHT), even.get_margin(MARGIN_RIGHT))
		bottom = max(odd.get_margin(MARGIN_BOTTOM), even.get_margin(MARGIN_BOTTOM))


# A "common" button but draws the given icon centered within its rect. The 'icon' property that is part of the
# BaseButton cannot be used because it does get drawn always on the left
class CenterIconButton extends Button:
	# Custom icon - this one will be centered within the button's rect
	var cicon: Texture = null
	
	# Modulation color (if icon is fully white it should work very well)
	var color: Color = Color()
	
	func _draw() -> void:
		if (!cicon):
			return
		
		if (expand_icon):
			# Add 2 pixels as margin on each side, even if the button does not have any
			var dim: float = min(rect_size.x, rect_size.y) - 4
			var x: float = (rect_size.x - dim) * 0.5
			var y: float = (rect_size.y - dim) * 0.5
			
			draw_texture_rect(cicon, Rect2(Vector2(x, y), Vector2(dim, dim)), false, color)
		
		else:
			var x: float = (rect_size.x - cicon.get_width()) * 0.5
			var y: float = (rect_size.y - cicon.get_height()) * 0.5
		
			draw_texture(cicon, Vector2(x, y), color)



#######################################################################################################################
### "Private" properties
# Header area - holds title and move left/right buttons
var _hbox: Control = null

# Not only displays the title, it allows editing
var _title: LineEdit = null

# Buttons to "move" (reorder) the column to the left or to the right
var _btmleft: CenterIconButton = null
var _btmright: CenterIconButton = null

# If this is enabled then move column buttons will be hidden by default and shown only when the mouse is over the column
var _hidebuttons: bool = false

# If this is enabled then when a cell finishes editing the next row will automatically receive focus
var _autoedit: bool = true

# To properly validate new titles, the "current one" must be cached
var _ctitle: String = ""

# Hold the value type here. Holding this value because a data source implementation may have its own coding
var _type: int = 0

# Cache header height
var _header_height: float = 0.0

# Cache the height of the row.
var _row_height: float = 0.0

# Cells will be added into this node. This is meant to help clip them underneath the header cell when scrolling
var _cellnodes: Control = null

# Cache the internal margins here
var _margin: _MarginCache = null

# The styler gets some style values from the parent control
var _styler: TabularStyler = null

# Flag settings
var _flags: int = FlagSettings._Default

# This will be "automatically" set by the TabularBox and will be the column index.
var _cindex: int = -1

#######################################################################################################################
### "Private" functions
func _check_sizes() -> void:
	var cy: float = 0
	for cell in _cellnodes.get_children():
		cell.rect_size = Vector2(rect_size.x - (_margin.left + _margin.right), _row_height - (_margin.top + _margin.bottom))
		cell.rect_position = Vector2(_margin.left, _margin.top + cy)
		
		cy += _row_height
	
	_cellnodes.rect_size.y = _row_height * _cellnodes.get_child_count()
	_cellnodes.update()
	
	rect_size.y = _hbox.rect_size.y + _cellnodes.rect_size.y



func _position_buttons() -> void:
	# Because the anchor and margins for the buttons are not working properly (sometimes the buttons get stretched over the
	# entire width - and rarely height), manually positioning those (the sizes were already set)
	
	if (!_styler):
		return
	
	var hstyle: StyleBox = _styler.get_header_box()
	
	# Doesn't matter which size is taken as both buttons should be of the same size and "square"
	var sz: float = _btmleft.rect_size.x
	var y: float = (_hbox.rect_size.y - sz) * 0.5
	
	_btmleft.rect_position.x = hstyle.get_margin(MARGIN_LEFT)
	_btmleft.rect_position.y = y
	
	_btmright.rect_position.x = _hbox.rect_size.x - (hstyle.get_margin(MARGIN_RIGHT) + sz)
	_btmright.rect_position.y = y


func _check_flags() -> void:
	# Title "editor" must be set based on a flag
	if (can_edit_title()):
		_title.mouse_default_cursor_shape = CURSOR_IBEAM
	
	else:
		_title.mouse_default_cursor_shape = CURSOR_ARROW
	
	
	# Check the reorder buttons visibility
	var has_buttons: bool = !is_index_locked()
	
	if (has_buttons):
		_btmleft.visible = false
		_btmright.visible = false
	else:
		_btmleft.visible = !_hidebuttons
		_btmright.visible = !_hidebuttons



func _change_flag(f: int, e: bool) -> void:
	if (e):
		_flags = _flags | f
	else:
		_flags = _flags & ~f


func _is_set(f: int) -> bool:
	return (_flags & f) == f

#######################################################################################################################
### Event handlers
func _on_draw_cells() -> void:
	var orow: StyleBox = _styler.get_oddrow_box()
	var erow: StyleBox = _styler.get_evenrow_box()
	
	var fsize: Vector2 = Vector2(rect_size.x, _row_height)
	var fpos: Vector2 = Vector2(0, 0)
	
	# Considering the row number (*not row index*), draw the odd rows.
	for _i in range(0, _cellnodes.get_child_count(), 2):
		_cellnodes.draw_style_box(orow, Rect2(fpos, fsize))
		fpos.y += (2 * _row_height)
	
	# Draw the even rows (again, not row index)
	fpos.y = _row_height
	for _i in range(1, _cellnodes.get_child_count(), 2):
		_cellnodes.draw_style_box(erow, Rect2(fpos, fsize))
		fpos.y += (2 * _row_height)


func _on_draw_hbox() -> void:
	var hstyle: StyleBox = _styler.get_header_box()
	_hbox.draw_style_box(hstyle, Rect2(Vector2(), _hbox.rect_size))


func _on_title_input(evt: InputEvent) -> void:
	if (evt is InputEventKey && evt.is_pressed() && evt.scancode == KEY_ESCAPE):
		pass
	pass


func _on_title_focused() -> void:
	if (can_edit_title()):
		_title.call_deferred("select_all")
	else:
		_title.call_deferred("release_focus")

func _on_title_unfocused() -> void:
	_title.select(0, 0)

func _on_title_entered(nt: String) -> void:
	_title.release_focus()
	emit_signal("title_entered", self, nt)


func _on_move_left_clicked() -> void:
	emit_signal("request_move_left", get_column_index())

func _on_move_right_clicked() -> void:
	emit_signal("request_move_right", get_column_index())





#######################################################################################################################
### Overrides
# Drawing used for debugging
#func _draw() -> void:
#	draw_rect(Rect2(Vector2(0, 0), rect_size), Color(1, 0, 0, 1))


func _clips_input() -> bool:
	return true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_check_sizes()
			# Directly calling the _position_buttons sometimes result in the wrong positioning because the reported hbox.rect_size
			# seems to be incorrect. Deferring the call fixes this.
			call_deferred("_position_buttons")
		
		NOTIFICATION_MOUSE_ENTER:
			if (!is_index_locked()):
				_btmleft.visible = true
				_btmright.visible = true
		
		NOTIFICATION_MOUSE_EXIT:
			if (!is_index_locked() && _hidebuttons):
				_btmleft.visible = false
				_btmright.visible = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS



