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

# TODO:
# - FIX: when reordering columns, must verify if the target index is of a column with "locked index".
# - FIX: when sorting rows, must deal with "row selection".
# - Optimization: there are certain "set_" within the _calculate_layout() that are not needed at that point. Values can
#   be cached when new data is added or something is removed.
# - When resizing last column auto-scroll if necessary so its right side remain visible
# - When a cell is clicked for editing, auto-scroll if its left side is clipped
# - A value validation system that can be given to each column (from the data source) so the column can give some
#   visual feedback if the value is not valid. Similar system can be used when editing column title (those must be unique)



tool
extends CustomControlBase
class_name TabularBox

const CNAME: String = "TabularBox"

#######################################################################################################################
### Signals and definitions
signal insert_column_request(at_index)
signal insert_row_request(at_index)

signal column_remove_request(column_index)
signal column_rename_requested(column_index, new_title)
signal column_move_requested(from_index, to_index)
signal column_type_change_requested(column_index, to_type)

signal column_resized(column_title, new_width)

# This will be given only if the column has a flag indicating that it should notify external code. Otherwise
# this Control will automatically deal with the data source
signal value_change_request(column_index, row_index, value)

signal row_remove_request(index_list)
signal row_move_request(from_index, to_index)
signal row_sort_request(column_index, ascending)



enum FlagSettings {
	AutoEditNextRow =           0b0000000000000001,    # If enabled, comitting a cell change will move the cursor (focus) to the next row
	AutoHandleRemRow =          0b0000000000000010,    # If not set then remove_row_request signal will be emitted when attempting to remove a row
	AutoHandleRemColumn =       0b0000000000000100,    # If not set then remove_column_request signal will be emitted when attempting to remove a column
	ShowRowNumbers =            0b0000000000001000,    # Display row numbers
	ShowCheckboxes =            0b0000000000010000,    # Display row checkboxes to allow multiple selection
	AutosaveSource =            0b0000000000100000,    # If set and the provided data source is a file, then it will be automatically saved when modified
	AutoHandleColInsertion =    0b0000000001000000,    # If not set then insert_column_request signal will be emitted when selecting "insert column" on UI
	AutoHandleRowInsertion =    0b0000000010000000,    # If not set then insert_row_request signal will be emitted when selecting "insert row" on UI
	AutoHandleColRename =       0b0000000100000000,    # If not set then column_rename_request will be emitted when attempting to change a column title
	AutoHandleColMove =         0b0000001000000000,    # If not set then column_move_requested will be emitted when attempting to reorder a column
	AutoHandleColTpChange =     0b0000010000000000,    # If not set then column_type_change_requested will be emitted when attempting to change a column value type
	AutoHandleRowMove =         0b0000100000000000,    # If not set then row_move_request signal will be emitted when attempting to reorder a row
	AutoHandleRowSort =         0b0001000000000000,    # If not set then row_sort_request will be emitted when attempting to sort rows by a column
	
	HideMoveColumnButtons =     0b1000000000000000,    # If set then the move left/right buttons will be shown only when mouse is over corresponding column
	
	Default =                   0b0001111111111111,
	# By default: AutoEditNextRow | AutoHandleRemRow | AutoHandleRemColumn | ShowRowNumbers | ShowCheckboxes | AutosaveSource |
	# AutoHandleColInsertion | AutoHandleRowInsertion | AutoHandleColRename | AutoHandleColMove | AutoHandleColTpChange |
	# AutoHandleRowMove | AutoHandleRowSort
}


# To avoid exposing the column base class (defined in columnbas.gd) to the "create new node" window, manually load the
# script from its path
const _ColumnBaseT: Script = preload("columnbase.gd")

# And if a class is not specified when requesting its type from the data source, a default column must be used. In this
# case always fall back to the string column
const _ColumnStringT: Script = preload("default_columns/columnstring.gd")

# The rownum.gd implements a Control that is not meant for direct usage. Because of that it doesn't have a class_name.
# So manually load the script here.
const _RowNumT: Script = preload("rownum.gd")

#######################################################################################################################
### "Public" properties
export var data_source: Resource = null setget set_data_source



#######################################################################################################################
### "Public" functions
func set_data_source(ds: TabularDataSourceBase) -> void:
	if (data_source == ds):
		return
	
	_clear()
	
	# First disconnect from events if there is currently a data source set
	_check_datasource_signals(true)
	
	_subvaltype.clear()
	_subvaltype.rect_size = Vector2()
	
	data_source = ds
	
	# Set the signals on the new data source
	_check_datasource_signals(false)
	
	if (data_source):
		var types: Dictionary = data_source.get_type_list()
		for t in types:
			_subvaltype.add_radio_check_item(types[t], t)
	
	
	# Without the defer some columns are not properly updated resulting in incorrect heights
	call_deferred("_refresh")


# The returned Dictionary holds column name as key and its width as value
func get_column_widths() -> Dictionary:
	var ret: Dictionary = {}
	
	for ci in _column:
		var col: _ColumnBaseT = _column[ci].column
		
		ret[col.get_title()] = col.rect_size.x
	
	return ret


# Set the widths of the columns
func set_column_widths(wdata: Dictionary) -> void:
	var changed: bool = false
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		
		var w: int = wdata.get(col.get_title(), -1)
		
		if (w != -1):
			col.rect_size.x = w
			changed = true
	
	if (changed):
		_refresh()



func get_selected_rows() -> Array:
	return _lpanel.get_selected()


func get_autoedit_next_row() -> bool:
	return _get_is_set(FlagSettings.AutoEditNextRow)

func set_autoedit_next_row(e: bool) -> void:
	_set_flag(FlagSettings.AutoEditNextRow, e)
	
	# Update existing columns (if there is any)
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		col.set_autoedit(e)


func get_autohandle_rem_col() -> bool:
	return _get_is_set(FlagSettings.AutoHandleRemColumn)

func set_autohandle_rem_col(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleRemColumn, e)


func get_autohandle_rem_row() -> bool:
	return _get_is_set(FlagSettings.AutoHandleRemRow)

func set_autohandle_rem_row(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleRemRow, e)


func set_show_row_numbers(e: bool) -> void:
	_set_flag(FlagSettings.ShowRowNumbers, e)
	_check_style()
	_refresh()

func get_show_row_numbers() -> bool:
	return _get_is_set(FlagSettings.ShowRowNumbers)

func set_show_row_checkboxes(e: bool) -> void:
	_set_flag(FlagSettings.ShowCheckboxes, e)
	_check_style()
	_refresh()

func get_show_row_checkboxes() -> bool:
	return _get_is_set(FlagSettings.ShowCheckboxes)



func set_autosave_source(e: bool) -> void:
	_set_flag(FlagSettings.AutosaveSource, e)

func get_autosave_source() -> bool:
	return _get_is_set(FlagSettings.AutosaveSource)


func set_autohandle_column_insertion(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleColInsertion, e)

func get_autohandle_column_insertion() -> bool:
	return _get_is_set(FlagSettings.AutoHandleColInsertion)


func set_autohandle_row_insertion(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleRowInsertion, e)

func get_autohandle_row_insertion() -> bool:
	return _get_is_set(FlagSettings.AutoHandleRowInsertion)


func set_autohandle_col_rename(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleColRename, e)

func get_autohandle_col_rename() -> bool:
	return _get_is_set(FlagSettings.AutoHandleColRename)


func set_autohandle_col_move(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleColMove, e)

func get_autohandle_col_move() -> bool:
	return _get_is_set(FlagSettings.AutoHandleColMove)


func set_autohandle_col_type_change(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleColTpChange, e)

func get_autohandle_col_type_change() -> bool:
	return _get_is_set(FlagSettings.AutoHandleColTpChange)


func set_autohandle_row_move(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleRowMove, e)

func get_autohandle_row_move() -> bool:
	return _get_is_set(FlagSettings.AutoHandleRowMove)


func set_autohandle_row_sort(e: bool) -> void:
	_set_flag(FlagSettings.AutoHandleRowSort, e)

func get_autohandle_row_sort() -> bool:
	return _get_is_set(FlagSettings.AutoHandleRowSort)


func set_hide_move_col_buttons(e: bool) -> void:
	_set_flag(FlagSettings.HideMoveColumnButtons, e)
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		col.set_hide_buttons(e)

func get_hide_move_col_buttons() -> bool:
	return _get_is_set(FlagSettings.HideMoveColumnButtons)

#######################################################################################################################
### "Private" definitions
enum _CtxMenuEntry {
	AppendColumn,
	RemoveColumn,
	InsertColBefore,
	InsertColAfter,
	MoveColLeft,
	MoveColRight,
	SortAscending,
	SortDescending,
	
	AppendRow,
	ToggleSelected,
	RemoveRow,
	InsertRowAbove,
	InsertRowBellow,
	MoveRowUp,
	MoveRowDown
}



class _InnerPanel extends Control:
	const _ColumnBaseT: Script = preload("columnbase.gd")
	
	func _clips_input() -> bool:
		return true
	
	func _init() -> void:
		rect_clip_content = true
	
	# Although an instance of the _InnerPanel will also be created for the column resizers, this function
	# should not be a problem.
	func get_column_under_mouse() -> _ColumnBaseT:
		var mpos: Vector2 = get_local_mouse_position()
		
		for ctrl in get_children():
			var px1: float = ctrl.rect_position.x
			var px2: float = px1 + ctrl.rect_size.x
			
			if (mpos.x >= px1 && mpos.x <= px2 && ctrl is _ColumnBaseT):
				return ctrl
		
		
		return null


class _CResizer extends Control:
	var column_index: int = -1


# Keep track of internal state, normally changed by some input events
class _State:
	var scrolled: Vector2
	
	var cells_size: Vector2
	
	# Cache the four internal margins - of the main box
	var mleft: float = 0.0
	var mtop: float = 0.0
	var mright: float = 0.0
	var mbottom: float = 0.0
	
	# Cache the header height
	var header_height: float = 0.0
	
	# Cache row height
	var row_height: float = 0.0
	
	# Cache column reorder button dimension (those are meant to be "square")
	var reorder_size: float = 0.0
	
	# Holds which resizer is bellow the mouse. If none then this will be null
	var hresizer: _CResizer = null
	
	# Will be set to true if a column is being resized
	var is_col_resizing: bool = false


# When attempting to delete selected rows, the list must be sorted in order to avoid errors. Moreover, the ideal is
# to iterate from the bigger indices to the smaller ones. Since the sorting must happen anyway, just make it in descending
# order which should make things even easier to iterate later.
class _SelSorter:
	static func comp(a: int, b: int) -> bool:
		return b < a



#######################################################################################################################
### "Private" properties
# The cell containers
var _lpanel: _RowNumT = null
var _rpanel: _InnerPanel = null

# The original idea was to have each column resizer to be a direct child of the corresponding column itself.
# However the correct column ordering would have to be placed on the tree in the reverse just so the resizer
# would not be covered. To avoid having to deal with this upkeep (specially when column reordering is a feature
# of this node), place all column resizers within this node, which will ensure those will be placed above any
# control later added as a direct child of the box.
var _resizer_panel: _InnerPanel = null

# Make things a lot easier to deal with the theme system
var _styler: TabularStyler = TabularStyler.new(self)

# Hold dictionaries with the following entries:
# - column -> An instance of the something derived from TabularColumnBase.
# - resizer -> The Control node used to help resize the column
var _column: Array = []


# Scrollbars
var _hbar: HScrollBar = null
var _vbar: VScrollBar = null

# Hold overal state
var _state: _State = null

# Context menu when right clicking
var _ctxmenu: PopupMenu = null

# Submenu holding possible value types
var _subvaltype: PopupMenu = null

# Boolean settings as a flag set
var _flags: int = FlagSettings.Default


# To help with the property list (the flags), this dictionary will hold the exposed flags - this will sort of automate
# the property list
var _fprops: Dictionary = {
	# AutosaveSource
	"autosave_data_source": {
		"getter": "get_autosave_source",
		"setter": "set_autosave_source"
	},
	
	# AutoEditNextRow
	"auto_edit_next_row": {
		"getter": "get_autoedit_next_row",
		"setter": "set_autoedit_next_row"
	},
	
	# AutoHandleRemRow
	"auto_handle_remove_row": {
		"getter": "get_autohandle_rem_row",
		"setter": "set_autohandle_rem_row",
	},

	# AutoHandleRemColumn
	"auto_handle_remove_column": {
		"getter": "get_autohandle_rem_col",
		"setter": "set_autohandle_rem_col",
	},
	
	# AutoHandleColInsertion
	"auto_handle_column_insertion": {
		"getter": "get_autohandle_column_insertion",
		"setter": "set_autohandle_column_insertion"
	},
	
	# AutoHandleColRename
	"auto_handle_column_rename": {
		"getter": "get_autohandle_col_rename",
		"setter": "set_autohandle_col_rename",
	},
	
	# AutoHandleColMove
	"auto_handle_column_reorder": {
		"getter": "get_autohandle_col_move",
		"setter": "set_autohandle_col_move",
	},
	
	# AutoHandleColTpChange
	"auto_handle_column_type_change": {
		"getter": "get_autohandle_col_type_change",
		"setter": "set_autohandle_col_type_change",
	},
	
	
	# AutoHandleRowInsertion
	"auto_handle_row_insertion": {
		"getter": "get_autohandle_row_insertion",
		"setter": "set_autohandle_row_insertion"
	},
	
	# AutoHandleRowMove
	"auto_handle_row_move": {
		"getter": "get_autohandle_row_move",
		"setter": "set_autohandle_row_move",
	},
	
	# AutoHandleRowSort
	"auto_handle_row_sort": {
		"getter": "get_autohandle_row_sort",
		"setter": "set_autohandle_row_sort",
	},
	
	
	# ShowRowNumbers
	"show_row_numbers": {
		"getter": "get_show_row_numbers",
		"setter": "set_show_row_numbers"
	},
	
	# ShowCheckboxes
	"show_row_checkboxes": {
		"getter": "get_show_row_checkboxes",
		"setter": "set_show_row_checkboxes"
	},
	
	# HideMoveColumnButtons
	"hide_move_column_buttons": {
		"getter": "get_hide_move_col_buttons",
		"setter": "set_hide_move_col_buttons",
	}
}



#######################################################################################################################
### "Private" functions
func _set_flag(f: int, enabled: bool) -> void:
	if (enabled):
		_flags = _flags | f
	else:
		_flags = _flags & ~f

func _get_is_set(f: int) -> bool:
	return (_flags & f) == f


func _check_datasource_signals(disc: bool) -> void:
	if (!data_source):
		return
	
	var fname: String = "_unconnect" if disc else "_connect"
	
	call(fname, data_source, "column_inserted", "_on_column_inserted")
	call(fname, data_source, "column_removed", "_on_column_removed")
	call(fname, data_source, "column_moved", "_on_column_moved")
	call(fname, data_source, "column_renamed", "_on_column_title_changed")
	call(fname, data_source, "column_rename_rejected", "_on_column_title_change_rejected")
	
	call(fname, data_source, "row_inserted", "_on_row_inserted")
	call(fname, data_source, "row_removed", "_on_row_removed")
	call(fname, data_source, "row_moved", "_on_row_moved")
	
	call(fname, data_source, "value_changed", "_on_data_value_changed")
	call(fname, data_source, "value_change_rejected", "_on_value_change_rejected")
	
	call(fname, data_source, "type_changed", "_on_type_changed")
	call(fname, data_source, "data_sorting_changed", "_on_sorted")



# This will connect the given event if it's not.
func _connect(obj: Object, evt: String, handler: String, binds: Array = []) -> void:
	if (!obj.is_connected(evt, self, handler)):
		# warning-ignore:return_value_discarded
		obj.connect(evt, self, handler, binds)

func _unconnect(obj: Object, evt: String, handler: String) -> void:
	if (obj.is_connected(evt, self, handler)):
		# warning-ignore:return_value_discarded
		obj.disconnect(evt, self, handler)


func _save_datasource() -> void:
	if (!get_autosave_source()):
		return
	
	var rpath: String = data_source.resource_path
	
	if (rpath.begins_with("res://") && rpath.find("::") == -1):
		# warning-ignore:return_value_discarded
		ResourceSaver.save(rpath, data_source)


func _clear() -> void:
	for c in _column:
		c.column.queue_free()
		c.resizer.queue_free()
	
	_state.row_height = 0.0
	_state.hresizer = null
	
	_column.clear()
	_lpanel.clear()


# This function is meant to insert a visual representation of a column that already exists within the data source.
func _insert_column(index: int) -> void:
	assert(data_source != null)
	assert(index >= 0 && index < data_source.get_column_count())
	
	var cinfo: Dictionary = data_source.get_column_info(index)
	var cclass: Script = cinfo.get("column_class", _ColumnStringT)
	var flags: int = cinfo.get("flags", _ColumnBaseT.FlagSettings._Default)
	
	var col: _ColumnBaseT = cclass.new()
	col.setup(_styler, {
		"hide_buttons": get_hide_move_col_buttons(),
		"autoedit": get_autoedit_next_row(),
	})
	
	col.set_title(cinfo.title)
	col.set_flags(flags)
	col.set_value_type(cinfo.get("type_code", 0))
	col.style_changed(_state.header_height, _state.reorder_size)
	
	_rpanel.add_child(col)
	
	# Cache the desired row height
	_state.row_height = max(_state.row_height, col.get_min_row_height())
	
	data_source.column_ui_created(col)
	
	# Insert the existing rows
	for ri in data_source.get_row_count():
		col.add_row()
		col.set_rvalue(ri, data_source.get_value(index, ri))
	
	# Create the resizer
	var rs: _CResizer = _CResizer.new()
	rs.set_name("_resizer")
	rs.mouse_filter = Control.MOUSE_FILTER_PASS
	rs.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	rs.column_index = index
	_resizer_panel.add_child(rs)
	
	var ncol: Dictionary = {
		"column": col,
		"resizer": rs,
	}
	
	if (index >= _column.size()):
		_column.append(ncol)
	else:
		_column.insert(index, ncol)
	
	
	# Connect events
	_connect(col, "title_entered", "_on_column_title_entered")
	_connect(col, "value_entered", "_on_cell_value_entered")
	
	_connect(col, "request_move_left", "_on_move_left")
	_connect(col, "request_move_right", "_on_move_right")
	
	_connect(rs, "mouse_entered", "_on_mouse_enter_resizer", [rs])
	_connect(rs, "mouse_exited", "_on_mouse_leave_resizer")
	
	# This is meant for debugging only. Do not remove the commented line
#	_connect(rs, "draw", "_on_draw_resizer", [rs])


func _remove_column(index: int) -> void:
	assert(data_source != null)
	assert(index >= 0 && index < _column.size())
	
	var cinfo: Dictionary = _column[index]
	
	cinfo.resizer.queue_free()
	cinfo.column.queue_free()
	
	_column.remove(index)
	
	# Recalculate the row height
	_state.row_height = 0.0
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		_state.row_height = max(_state.row_height, col.get_min_row_height())


func _remove_row(ilist: Array) -> void:
	assert(data_source != null)
	
	for ri in ilist:
		data_source.remove_row(ri)


func _check_datasource() -> void:
	if (!data_source):
		return
	
	_lpanel.set_row_count(data_source.get_row_count())
	
	# FIXME: In here a better approach would be to first ensure number of columns match
	#        After that, see if each existing column matches the expected class and, if not, replace it
	if (_column.size() != data_source.get_column_count()):
		if (_column.size() > 0):
			_clear()
		
		for ci in data_source.get_column_count():
			_insert_column(ci)


# This will be called (deferred) whenever the style is changed. This should recalculate some values that can be
# cached and also propagate those to the children (columns and row number container)
func _check_style() -> void:
	### Calculate the main box internal margins
	var box: StyleBox = _styler.get_background_box()
	_state.mleft = box.get_margin(MARGIN_LEFT)
	_state.mtop = box.get_margin(MARGIN_TOP)
	_state.mright = box.get_margin(MARGIN_RIGHT)
	_state.mbottom = box.get_margin(MARGIN_BOTTOM)
	
	### Calculate the header sizing. This will also calculate the move arrow button sizes (both will be of the same
	### size and "square").
	var hstyle: StyleBox = _styler.get_header_box()
	var font: Font = _styler.get_header_font()
	
	var btn: StyleBox = _styler.get_normal_button()
	var bth: StyleBox = _styler.get_hovered_button()
	var btp: StyleBox = _styler.get_pressed_button()
	
	var larr: Texture = _styler.get_left_arrow_icon()
	var rarr: Texture = _styler.get_right_arrow_icon()
	
	# Obtain the largest internal margin of the buttons
	var btmvertm: float = btn.get_margin(MARGIN_TOP) + btn.get_margin(MARGIN_BOTTOM)
	btmvertm = max(btmvertm, bth.get_margin(MARGIN_TOP) + bth.get_margin(MARGIN_BOTTOM))
	btmvertm = max(btmvertm, btp.get_margin(MARGIN_TOP) + btp.get_margin(MARGIN_BOTTOM))
	
	var btmhortm: float = btn.get_margin(MARGIN_LEFT) + btn.get_margin(MARGIN_RIGHT)
	btmhortm = max(btmhortm, bth.get_margin(MARGIN_LEFT) + bth.get_margin(MARGIN_RIGHT))
	btmhortm = max(btmhortm, btp.get_margin(MARGIN_LEFT) + btp.get_margin(MARGIN_RIGHT))
	
	# Obtain the largest icon dimension
	var texlw: float = max(larr.get_width(), rarr.get_width())
	var texlh: float = max(larr.get_height(), rarr.get_height())
	
	# Maximum internal height (without margin) - this is between font and texture
	var iheight: float = max(texlh, font.get_height())
	
	# Minimum button size - taking the largest minimum dimension (again, for a "square button")
	var minbtsz: float = max(btmhortm + texlw, btmvertm + iheight)
	
	# Then, take the actual button size, which should be the largest between the text height and minbtsz
	var btsize: float = max(font.get_height(), minbtsz)
	
	# The header height is basically the internal header margins plus the btsize
	_state.header_height = hstyle.get_margin(MARGIN_TOP) + hstyle.get_margin(MARGIN_BOTTOM) + btsize
	_state.reorder_size = btsize
	
	
	### Notify the columns and rownumber container
	_lpanel.style_changed(_state.header_height)
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		col.style_changed(_state.header_height, btsize)
	
	
	_calculate_internal()
	_refresh()




# This is used to calculate the internal controls. Mostly anchors and margins. Because everything that is
# calculated here relies only on the style, this is only called when the style is changed.
func _calculate_internal() -> void:
	if (rect_size.x < 120 || rect_size.y < 85):
		return
	
	
	### Retrieve some styles from the theme, which will be necessary to calculate some positioning
	var hstyle: StyleBox = _styler.get_header_box()
	var hfont: Font = _styler.get_header_font()
	
	
	### Calculate rownumber width
	var rownum_width: float = hstyle.get_margin(MARGIN_LEFT) + hstyle.get_margin(MARGIN_RIGHT)
	
	if (get_show_row_numbers()):
		rownum_width += hfont.get_string_size("0000").x
	
	if (get_show_row_checkboxes()):
		rownum_width += max(_styler.get_checked_icon().get_width(), _styler.get_unchecked_icon().get_width())
	
	
	### Setup the two inner panels
	_lpanel.visible = (get_show_row_numbers() || get_show_row_checkboxes())
	_lpanel.set_anchor_and_margin(MARGIN_LEFT, 0, _state.mleft)
	_lpanel.set_anchor_and_margin(MARGIN_TOP, 0, _state.mtop)
	_lpanel.set_anchor_and_margin(MARGIN_RIGHT, 0, rownum_width + _state.mleft)
	_lpanel.set_anchor_and_margin(MARGIN_BOTTOM, 1, -(_state.mbottom))
	
	_rpanel.set_anchor_and_margin(MARGIN_LEFT, 0, _state.mleft + (rownum_width if _lpanel.visible else 0.0))
	_rpanel.set_anchor_and_margin(MARGIN_TOP, 0, _state.mtop)
	_rpanel.set_anchor_and_margin(MARGIN_RIGHT, 1, -(_state.mright))
	_rpanel.set_anchor_and_margin(MARGIN_BOTTOM, 1, -(_state.mbottom))
	
	_resizer_panel.rect_position = _rpanel.rect_position
	_resizer_panel.rect_size = _rpanel.rect_size



func _calculate_layout() -> void:
	if (!data_source):
		return
	
	# Initialize the data cells size
	_state.cells_size = Vector2()
	
	var cx: float = -_state.scrolled.x
	
	
	_lpanel.set_flags(get_show_row_numbers(), get_show_row_checkboxes())
	_lpanel.set_row_height(_state.row_height)
	_lpanel.set_scroll(_state.scrolled.y)
	_lpanel.set_row_count(data_source.get_row_count())
	
	_state.cells_size.y = data_source.get_row_count() * _state.row_height
	
	# Now correctly setup each column's row list
	for c in _column.size():
		var col: _ColumnBaseT = _column[c].column
		col.set_column_index(c)
		col.rect_position.x = cx
		col.set_row_height(_state.row_height)
		col.set_scroll(_state.scrolled.y)
		
		cx += col.rect_size.x
		_state.cells_size.x += col.rect_size.x
		
		var rs: _CResizer = _column[c].resizer
		rs.rect_position = Vector2(cx - 3, 0)
		rs.rect_size = Vector2(6, col.rect_size.y)
		rs.column_index = c




func _check_scrollbars() -> void:
	var hmin: Vector2 = _hbar.get_combined_minimum_size()
	var vmin: Vector2 = _vbar.get_combined_minimum_size()
	
	
	var size: Vector2 = rect_size
	size.x -= (_state.mleft + _state.mright + _lpanel.rect_size.x)
	var hheight: float = _state.header_height
	size.y -= (_state.mtop + _state.mbottom + hheight)
	
	if (_vbar.visible):
		size.x -= vmin.x
	if (_hbar.visible):
		size.y -= hmin.y
	
	if (_state.cells_size.y <= size.y):
		# Not enough data height to require the vertical scrollbar. Hide it
		_vbar.hide()
		
		# Perform minor adjustments to the inner container (_rpanel) as the scrollbar is not using the vertical
		# space anymore.
		_rpanel.margin_right = -_state.mright
		
		_vbar.set_max(0)
		_state.scrolled.y = 0
	
	else:
		# Vertical scrollbar is required. Show it
		_vbar.show()
		
		_rpanel.margin_right = -(_state.mright + vmin.x)
		
		_vbar.set_max(_state.cells_size.y)
		_vbar.set_page(size.y)
		_state.scrolled.y = _vbar.get_value()
	
	
	if (_state.cells_size.x <= size.x):
		_hbar.hide()
		
		_lpanel.margin_bottom = -_state.mbottom
		_rpanel.margin_bottom = -_state.mbottom
		
		_hbar.set_max(0)
		_state.scrolled.x = 0
	
	else:
		_hbar.show()
			
		_lpanel.margin_bottom = -(_state.mbottom + hmin.y)
		_rpanel.margin_bottom = -(_state.mbottom + hmin.y)
		
		_hbar.set_max(_state.cells_size.x)
		_hbar.set_page(size.x)
		_state.scrolled.x = _hbar.get_value()
	
	
	# Visibility for both bars is set so just calculate size and position for them
	if (_hbar.visible):
		_hbar.rect_size = Vector2(_rpanel.rect_size.x, hmin.y)
		_hbar.rect_position = Vector2(_rpanel.rect_position.x, rect_size.y - (hmin.y + _state.mbottom))
	
	if (_vbar.visible):
		_vbar.rect_size = Vector2(vmin.x, _rpanel.rect_size.y - hheight)
		_vbar.rect_position = Vector2(rect_size.x - (vmin.x + _state.mright), _state.mtop + hheight)


func _refresh() -> void:
	_check_datasource()
	_calculate_layout()
	_check_scrollbars()


func _right_click_on(col: _ColumnBaseT, row: int) -> void:
	_ctxmenu.clear()
	# PopupMenu grows when items are added but don't shrink back if those are removed.
	_ctxmenu.rect_size = Vector2()
	
	_ctxmenu.set_meta("column", col)
	_ctxmenu.set_meta("row", row)
	
	_ctxmenu.add_item("Append column", _CtxMenuEntry.AppendColumn)
	
	if (col):
		_ctxmenu.add_submenu_item("Sort", "sub_sortrows")
		_ctxmenu.set_item_disabled(_ctxmenu.get_item_count() - 1, !col.allow_sorting())
		
		if (col.allow_menu()):
			_ctxmenu.add_submenu_item("Move column", "sub_movecol")
			_ctxmenu.set_item_disabled(_ctxmenu.get_item_count() - 1, col.is_index_locked())
		
			# FIXME: if the column is index locked this submenu may break that condition 
			_ctxmenu.add_submenu_item("Insert column", "sub_insertcol")
		
		_ctxmenu.add_submenu_item("Value type", "sub_valuetype")
		_ctxmenu.set_item_disabled(_ctxmenu.get_item_count() - 1, !col.can_change_type())
		
		if (col.can_change_type()):
			var icount: int = _subvaltype.get_item_count()
			for i in icount:
				var id: int = _subvaltype.get_item_id(i)
				_subvaltype.set_item_checked(i, id == col.get_value_type())
		
		if (col.allow_menu()):
			_ctxmenu.add_item("Remove column", _CtxMenuEntry.RemoveColumn)
	
	_ctxmenu.add_separator()
	_ctxmenu.add_item("Append row", _CtxMenuEntry.AppendRow)
	
	if (row >= 0):
		_ctxmenu.add_item("Toggle selected", _CtxMenuEntry.ToggleSelected)
		
		_ctxmenu.add_submenu_item("Move row", "sub_moverow")
		_ctxmenu.add_submenu_item("Insert row", "sub_insertrow")
		
		_ctxmenu.add_item("Remove row", _CtxMenuEntry.RemoveRow)
	
	_ctxmenu.rect_position = get_global_mouse_position()
	_ctxmenu.popup()




#######################################################################################################################
### Event handlers
func _handle_mouse_button(evt: InputEventMouseButton) -> void:
	match evt.button_index:
		BUTTON_LEFT:
			if (evt.is_pressed()):
				if (_state.hresizer && !_state.is_col_resizing):
					_state.is_col_resizing = true
			
			else:
				_state.is_col_resizing = false
		
		BUTTON_RIGHT:
			if (evt.is_pressed() && data_source):
				var col: _ColumnBaseT = _rpanel.get_column_under_mouse()
				var row: int = _lpanel.get_row_under_mouse()
				
				_right_click_on(col, row)
		
		
		BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN:
			if (evt.is_pressed()):
				var sbar: ScrollBar = _hbar as ScrollBar if (_hbar.visible && !_vbar.visible) else _vbar as ScrollBar
				var delta: float = sbar.get_page() / 8.0 * evt.factor
				if (evt.button_index == BUTTON_WHEEL_UP):
					delta = -delta
				
				sbar.set_value(sbar.get_value() + delta)
		
		BUTTON_WHEEL_LEFT, BUTTON_WHEEL_RIGHT:
			if (evt.is_pressed()):
				if (_hbar.visible):
					var delta: float = _hbar.get_page() / 8.0 * evt.factor
					if(evt.button_index == BUTTON_WHEEL_LEFT):
						delta = -delta
					
					_hbar.set_value(_hbar.get_value() + delta)


func _handle_mouse_motion(evt: InputEventMouseMotion) -> void:
	if (_state.is_col_resizing && _state.hresizer.column_index >= 0):
		var mposx: float = evt.position.x - _rpanel.rect_position.x - 3
		
		var col: _ColumnBaseT = _column[_state.hresizer.column_index].column
		
		var diff: float = mposx - _state.hresizer.rect_position.x
		
		var nwidth: float = col.rect_size.x + diff
		
		if (nwidth < col.rect_min_size.x):
			nwidth = col.rect_min_size.x
		
		col.rect_size.x = nwidth
		_refresh()
		
		emit_signal("column_resized", col.get_title(), nwidth)



func _on_cmenu_selected(id: int) -> void:
	match id:
		_CtxMenuEntry.AppendColumn:
			if (get_autohandle_column_insertion()):
				data_source.insert_column("", -1, -1)
			else:
				emit_signal("insert_column_request", data_source.get_column_count())
		
		_CtxMenuEntry.RemoveColumn:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			if (get_autohandle_rem_col()):
				# The data source should emit a signal indicating if the column was removed or not. In that case
				# the "_on_column_removed()" here will deal with that case and update the rendering.
				data_source.remove_column(col.get_column_index())
			
			else:
				# Automatic column removal is disabled, emit a signal so outside code can deal with this request
				emit_signal("column_remove_request", col.get_column_index())
		
		
		_CtxMenuEntry.InsertColBefore:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			if (get_autohandle_column_insertion()):
				data_source.insert_column("", -1, col.get_column_index())
			else:
				emit_signal("insert_column_request", col.get_column_index())
		
		_CtxMenuEntry.InsertColAfter:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			if (get_autohandle_column_insertion()):
				data_source.insert_column("", -1, col.get_column_index() + 1)
			else:
				emit_signal("insert_column_request", col.get_column_index() + 1)
		
		_CtxMenuEntry.MoveColLeft:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			_on_move_left(col.get_column_index())
		
		_CtxMenuEntry.MoveColRight:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			_on_move_right(col.get_column_index())
		
		_CtxMenuEntry.SortAscending:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			
			if (get_autohandle_row_sort()):
				data_source.sort_by_col(col.get_column_index(), true)
			else:
				emit_signal("row_sort_request", col.get_column_index(), true)
		
		_CtxMenuEntry.SortDescending:
			var col: _ColumnBaseT = _ctxmenu.get_meta("column") as _ColumnBaseT
			assert(col != null)
			
			if (get_autohandle_row_sort()):
				data_source.sort_by_col(col.get_column_index(), false)
			else:
				emit_signal("row_sort_request", col.get_column_index(), false)
		
		_CtxMenuEntry.AppendRow:
			if (get_autohandle_row_insertion()):
				data_source.insert_row({}, -1)
			else:
				emit_signal("insert_row_request", data_source.get_row_count())
		
		_CtxMenuEntry.ToggleSelected:
			var row: int = _ctxmenu.get_meta("row") as int
			_lpanel.toggle_selected(row, false)
		
		_CtxMenuEntry.RemoveRow:
			var row: int = _ctxmenu.get_meta("row") as int
			if (get_autohandle_rem_row()):
				_remove_row([row])
			
			else:
				emit_signal("row_remove_request", [row])
		
		
		_CtxMenuEntry.InsertRowAbove:
			var row: int = _ctxmenu.get_meta("row") as int
			if (get_autohandle_row_insertion()):
				data_source.insert_row({}, row)
			else:
				emit_signal("insert_row_request", row)
		
		_CtxMenuEntry.InsertRowBellow:
			var row: int = _ctxmenu.get_meta("row") as int
			if (get_autohandle_row_insertion()):
				data_source.insert_row({}, row + 1)
			else:
				emit_signal("insert_row_request", row + 1)
		
		_CtxMenuEntry.MoveRowUp:
			var row: int = _ctxmenu.get_meta("row") as int
			_on_move_up(row)
		
		_CtxMenuEntry.MoveRowDown:
			var row: int = _ctxmenu.get_meta("row") as int
			_on_move_down(row)
	
	
	# A menu option has been used. Clear the metas to avoid any possible problem that may be caused
	# by incorrect setup when the menu is used again.
	_ctxmenu.set_meta("column", null)
	_ctxmenu.set_meta("row", null)


func _on_vtype_id_selected(id: int) -> void:
	assert(data_source != null)
	
	var col: _ColumnBaseT = _ctxmenu.get_meta("column")
	
	_ctxmenu.set_meta("column", null)
	_ctxmenu.set_meta("row", null)
	
	if (col.get_value_type() == id):
		return
	
	if (get_autohandle_col_type_change()):
		data_source.change_column_value_type(col.get_column_index(), id)
	
	else:
		emit_signal("column_type_change_requested", col.get_column_index(), id)






func _on_scroll_value_changed(_v: float) -> void:
	_state.scrolled.x = _hbar.get_value()
	_state.scrolled.y = _vbar.get_value()
	_refresh()


func _on_column_title_entered(column: _ColumnBaseT, new_title: String) -> void:
	assert(data_source != null)
	
	if (get_autohandle_col_rename()):
		data_source.rename_column(column.get_column_index(), new_title)
		column.confirm_title_change()
		_save_datasource()
	
	else:
		emit_signal("column_rename_requested", column.get_column_index(), new_title)


func _on_column_title_changed(index: int) -> void:
	assert(data_source != null)
	
	var ccol: _ColumnBaseT = _column[index].column
	ccol.confirm_title_change()
	_save_datasource()


func _on_column_title_change_rejected(index: int) -> void:
	var ccol: _ColumnBaseT = _column[index].column
	ccol.revert_title_change()




# This is triggered by changing a value within the TabularColumnBase's cell Control.
func _on_cell_value_entered(column: _ColumnBaseT, row: int, newval) -> void:
	assert(data_source != null)
	
	if (column.value_change_signal()):
		emit_signal("value_change_request", column.get_column_index(), row, newval)
	
	else:
		# This line is expected to trigger a "value_changed" within the data source, which will
		# effectivelly update the column's internal data *if* that signal is indeed triggered.
		# That signal is handled by _on_data_value_changed (bellow)
		data_source.set_value(column.get_column_index(), row, newval)


# This is triggered by the data source and if here either the column does not require external
# dealing with the new value or it was already confirmed
func _on_data_value_changed(col: int, row: int, value) -> void:
	assert(data_source != null)
	
	var ccol: _ColumnBaseT = _column[col].column
	ccol.set_rvalue(row, value)
	_save_datasource()


func _on_value_change_rejected(col: int, row: int) -> void:
	assert(data_source != null)
	
	var c: _ColumnBaseT = _column[col].column
	c.revert_value_change(row)



func _on_mouse_enter_resizer(r: Control) -> void:
	_state.hresizer = r

func _on_mouse_leave_resizer() -> void:
	_state.hresizer = null


func _on_move_left(col: int) -> void:
	if (!data_source):
		return
	
	if (col == 0):
		# Column is already the first one
		return
	
	if (get_autohandle_col_move()):
		data_source.move_column(col, col - 1)
	else:
		emit_signal("column_move_requested", col, col - 1)


func _on_move_right(col: int) -> void:
	if (!data_source):
		return
	
	if (col == _column.size() - 1):
		# Column is already the last one
		return
	
	if (get_autohandle_col_move()):
		data_source.move_column(col, col + 1)
	else:
		emit_signal("column_move_requested", col, col + 1)


func _on_move_up(row: int) -> void:
	if (!data_source):
		return
	
	if (row == 0):
		# This is already the first row. Nothing to do here
		return
	
	if (get_autohandle_row_move()):
		data_source.move_row(row, row - 1)
	else:
		emit_signal("row_move_request", row, row - 1)

func _on_move_down(row: int) -> void:
	if (!data_source):
		return
	
	if (row == data_source.get_row_count() - 1):
		# Row is already the last one. Nothing to do here
		return
	
	if (get_autohandle_row_move()):
		data_source.move_row(row, row + 1)
	else:
		emit_signal("row_move_request", row, row + 1)



### Specifically for data source signals
func _on_column_inserted(index: int) -> void:
	assert(data_source != null)
	_insert_column(index)
	_save_datasource()
	_refresh()


func _on_column_removed(index: int) -> void:
	assert(data_source != null)
	_remove_column(index)
	_save_datasource()
	_refresh()



func _on_column_moved(from: int, to: int) -> void:
	assert(data_source != null)
	var centry: Dictionary = _column[from]
	
	var col: _ColumnBaseT = centry.column
	_rpanel.move_child(col, to)
	
	_column.remove(from)
	_column.insert(to, centry)
	
	_save_datasource()
	_refresh()





func _on_row_inserted(index: int) -> void:
	assert(data_source != null)
	
	_lpanel.row_inserted_at(index)
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		col.add_row()
		
		for ri in range(index, data_source.get_row_count()):
			col.set_rvalue(ri, data_source.get_value(ci, ri))
	
	_save_datasource()
	_refresh()


func _on_row_removed(index: int) -> void:
	assert(data_source != null)
	
	_lpanel.row_removed_from(index)
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		col.remove_row()
		
		for ri in range(index, data_source.get_row_count()):
			col.set_rvalue(ri, data_source.get_value(ci, ri))
	
	_save_datasource()
	_refresh()



func _on_row_moved(from: int, to: int) -> void:
	assert(data_source != null)
	
	if (from < 0 || from >= data_source.get_row_count()):
		return
	if (to < 0 || to >= data_source.get_row_count()):
		return
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
	
		var fval = data_source.get_value(ci, from)
		var tval = data_source.get_value(ci, to)
		
		# By now the values have already been swapped on the data source. So assign those into the columns
		col.set_rvalue(from, fval)
		col.set_rvalue(to, tval)
	
	_save_datasource()




func _on_type_changed(col: int) -> void:
	assert(data_source != null)
	
	_remove_column(col)
	_insert_column(col)
	
	_save_datasource()
	_refresh()



func _on_sorted() -> void:
	assert(data_source != null)
	
	for ci in _column.size():
		var col: _ColumnBaseT = _column[ci].column
		
		for ri in data_source.get_row_count():
			col.set_rvalue(ri, data_source.get_value(ci, ri))



func _on_delete_selected() -> void:
	assert(data_source != null)
	
	var sel: Array = _lpanel.get_selected()
	
	# Ensure the list of selected indices is sorted in decreasing order, which will make easier to
	# remove row by row.
	sel.sort_custom(_SelSorter, "comp")
	
	if (get_autohandle_rem_row()):
		_remove_row(sel)
	
	else:
		emit_signal("row_remove_request", sel)



### Debug only - no need to comment the functions because those are connected only when necessary
# When debugging the left and right panels will connect this function to the _draw signal.
func _on_inner_panel_draw(c: Color, p: Control) -> void:
	var r: Rect2 = Rect2(Vector2(), p.rect_size)
	p.draw_rect(r, c)


# This function will be connected only when development in order to help debugging.
func _on_draw_resizer(r: Control) -> void:
	r.draw_rect(Rect2(Vector2(), r.rect_size), Color(1.0, 0.0, 0.0, 0.5))


#######################################################################################################################
### Overrides
# The CustomControlBase call this in order to create entries within the Theme object
func _create_custom_theme() -> void:
	if (!_styler):
		_styler = TabularStyler.new(self)
	
	_styler.generate_theme()
	call_deferred("_check_style")


func _get_property_list() -> Array:
	var ret: Array = []
	
	for p in _fprops:
		ret.append({
			"name": p,
			"type": TYPE_BOOL
		})
	
	return ret

func _get(prop: String):
	var p: Dictionary = _fprops.get(prop, {})
	if (!p.empty()):
		return call(p.getter)
	
	return null

func _set(prop: String, val) -> bool:
	var p: Dictionary = _fprops.get(prop, {})
	if (!p.empty()):
		return call(p.setter, val)
	
	return false


# Override this just so input is clipped - this only works when "running"
func _clips_input() -> bool:
	return true


func _gui_input(evt: InputEvent) -> void:
	if (evt is InputEventMouseButton):
		_handle_mouse_button(evt)
	
	if (evt is InputEventMouseMotion):
		_handle_mouse_motion(evt)


func _unhandled_input(evt: InputEvent) -> void:
	if (evt is InputEventKey):
		pass


func _get_minimum_size() -> Vector2:
	return Vector2(120, 85)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_RESIZED:
			call_deferred("_check_style")
		
		NOTIFICATION_EXIT_TREE:
			_clear()



func _draw() -> void:
	draw_style_box(_styler.get_background_box(), Rect2(Vector2(), rect_size))


func _init() -> void:
	# Ensure nothing will be drawn outside of the control boundaries
	set_clip_contents(true)
	
	### Setup objects
	if (!_styler):
		_styler = TabularStyler.new(self)
	
	if (!_state):
		_state = _State.new()
	
	# When the script is rebuilt, this _init() function is called but children are not removed. This can be a problem
	# during development as those remain in their states and are drawn, which can cause some undesireable effects.
	# Because of that, cleaning everything
	if (Engine.is_editor_hint()):
		for c in get_children():
			c.queue_free()
	
	### Setup children
	_rpanel = _InnerPanel.new()
	_rpanel.set_name("_right")
	_rpanel.rect_clip_content = true
	_rpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rpanel)
	
	_resizer_panel = _InnerPanel.new()
	_resizer_panel.set_name("_resizerpnl")
	_resizer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_resizer_panel)
	
	
	# Left panel must be above the right panel so create it (or rather add to the tree) after
	_lpanel = _RowNumT.new()
	_lpanel.setup(_styler)
	_lpanel.set_name("_left")
	add_child(_lpanel)
	
	
	_hbar = HScrollBar.new()
	_hbar.set_name("_horbar")
	_hbar.visible = false
	add_child(_hbar)
	
	_vbar = VScrollBar.new()
	_vbar.set_name("_verbar")
	_vbar.visible = false
	add_child(_vbar)
	
	_ctxmenu = PopupMenu.new()
	_ctxmenu.set_name("_contextmenu")
	add_child(_ctxmenu)
	
	
	### Create submenus
	var submovecol: PopupMenu = PopupMenu.new()
	submovecol.set_name("sub_movecol")
	submovecol.add_item("Left", _CtxMenuEntry.MoveColLeft)
	submovecol.add_item("Right", _CtxMenuEntry.MoveColRight)
	_ctxmenu.add_child(submovecol)
	
	var subinsertcol: PopupMenu = PopupMenu.new()
	subinsertcol.set_name("sub_insertcol")
	subinsertcol.add_item("Before", _CtxMenuEntry.InsertColBefore)
	subinsertcol.add_item("After", _CtxMenuEntry.InsertColAfter)
	_ctxmenu.add_child(subinsertcol)
	
	var subsortrows: PopupMenu = PopupMenu.new()
	subsortrows.set_name("sub_sortrows")
	subsortrows.add_item("Ascending", _CtxMenuEntry.SortAscending)
	subsortrows.add_item("Descending", _CtxMenuEntry.SortDescending)
	_ctxmenu.add_child(subsortrows)
	
	var submoverow: PopupMenu = PopupMenu.new()
	submoverow.set_name("sub_moverow")
	submoverow.add_item("Up", _CtxMenuEntry.MoveRowUp)
	submoverow.add_item("Down", _CtxMenuEntry.MoveRowDown)
	_ctxmenu.add_child(submoverow)
	
	var subinsertrow: PopupMenu = PopupMenu.new()
	subinsertrow.set_name("sub_insertrow")
	subinsertrow.add_item("Above", _CtxMenuEntry.InsertRowAbove)
	subinsertrow.add_item("Bellow", _CtxMenuEntry.InsertRowBellow)
	_ctxmenu.add_child(subinsertrow)
	
	
	_subvaltype = PopupMenu.new()
	_subvaltype.set_name("sub_valuetype")
	_ctxmenu.add_child(_subvaltype)
	
	### Connect the event handlers
	_connect(_ctxmenu, "id_pressed", "_on_cmenu_selected")
	_connect(submovecol, "id_pressed", "_on_cmenu_selected")
	_connect(subinsertcol, "id_pressed", "_on_cmenu_selected")
	_connect(subsortrows, "id_pressed", "_on_cmenu_selected")
	_connect(submoverow, "id_pressed", "_on_cmenu_selected")
	_connect(subinsertrow, "id_pressed", "_on_cmenu_selected")
	
	_connect(_subvaltype, "id_pressed", "_on_vtype_id_selected")
	
	_connect(_hbar, "value_changed", "_on_scroll_value_changed")
	_connect(_vbar, "value_changed", "_on_scroll_value_changed")
	
	_connect(_lpanel, "delete_selected", "_on_delete_selected")
	
	call_deferred("_check_style")
	
	
	### This is for debugging
	#_connect(_rpanel, "draw", "_on_inner_panel_draw", [Color(0.1, 0.1, 0.7), _rpanel])
	#_connect(_lpanel, "draw", "_on_inner_panel_draw", [Color(0.1, 0.7, 0.1), _lpanel])





