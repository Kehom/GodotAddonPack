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
extends PanelContainer

#######################################################################################################################
### Signals and definitions
signal remove_requested(entry)
signal rename_requested(entry)
signal mouse_select(entry)


const DSourceT: Script = preload("dbdsrc.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func setup(db: GDDatabase, table: DBTable) -> void:
	# Update the UI
	$vbox/line1/bt_tblname.text = table.get_table_name()
	$vbox/line2/lbl_filename.hint_tooltip = table.resource_path
	
	if (DBHelpers.is_resource_file(table)):
		$vbox/line2/lbl_filename.text = table.resource_path.get_file()
	
	else:
		$vbox/line2/lbl_filename.text = "<Embedded>"
	
	# Create the data source that will display the given table within the TabularBox
	_datasource = DSourceT.new()
	_datasource.setup(db, table)




func get_table_name() -> String:
	return _datasource.get_table_name()


func get_data_source() -> DSourceT:
	return _datasource



# This will be called by the dbemain Control in order to notify that the corresponding table has been renamed. Just update the UI.
func table_renamed(to: String) -> void:
	$vbox/line1/bt_tblname.text = to


func set_selected(s: bool) -> void:
	_selected = s
	update()



func get_column_count() -> int:
	return _datasource.get_column_count()






func check_style() -> void:
	var stl: StyleBox = get_stylebox("tab_fg", "TabContainer").duplicate()
	stl.content_margin_left = 6
	stl.content_margin_top = 6
	stl.content_margin_right = 6
	stl.content_margin_bottom = 6
	add_stylebox_override("panel", stl)

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _datasource: DSourceT = null

# Without tracking if the mouse is actually over the entry clicking it is failing to properly select the table
var _is_mouse_over: bool = false

# Cache selected state. This will be used to prevent the rename button from popping the dialog when the table is
# not previously selected. In other words, if the table is not selected, clicking the button will actually select
# the table first. A second click will be necessary in order to bring the rename dialog.
var _selected: bool = false

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_bt_remove_pressed() -> void:
	emit_signal("remove_requested", self)


func _on_tbl_list_entry_mouse_entered() -> void:
	_is_mouse_over = true

func _on_tbl_list_entry_mouse_exited() -> void:
	_is_mouse_over = false


func _on_bt_tblname_pressed():
	if (_selected):
		emit_signal("rename_requested", self)
	else:
		emit_signal("mouse_select", self)




#######################################################################################################################
### Overrides
func _draw() -> void:
	if (_selected):
		var fstyle: StyleBox = get_stylebox("focus", "Button")
		draw_style_box(fstyle, Rect2(Vector2(), rect_size))



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			check_style()


func _input(evt: InputEvent) -> void:
	if (evt is InputEventMouseButton):
		if (_is_mouse_over && evt.is_pressed() && evt.button_index == BUTTON_LEFT):
			emit_signal("mouse_select", self)


