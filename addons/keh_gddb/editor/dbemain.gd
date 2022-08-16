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
# - Allow each column to have a custom default value to be used when creating new rows (if the column is not for unique values)
# - Audio column type should display playback information (duration and current position - this requires a function to convert reported
#   value in seconds into min:sec:milli)
# - Custom file dialog (open/create database) that filters files by the script type instead of purely extension. It should replace the dlg_db
#   Alternatively check how easy it would be to just save the database with a custom extension
# - Export DB to JSON



tool
extends Control


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
# In C++ it is possible to obtain certain singletons that will help trigger layout saving. Unfortunately those are
# not available in scripting. Because of that, when this class is instanced from the dbeplugin.gd, this property will
# be set in order to help with the task of saving/loading the layout.
var layout_saver: FuncRef = null

#######################################################################################################################
### "Public" functions
# This function will be called by the plugin loader (dbeplugin.gd) which already filters out unsupported objects
# Or the "on file selected" event handler of the open/create database dialog
func edit(db: GDDatabase) -> void:
	if (_state.get_db() == db):
		return
	
	_state.set_db(db)
	
	# Clear the UI displaying the list of tables - or at least ensure it's empty
	DBHelpers.clear_children(_table_box)
	
	
	var table_list: Array = db.get_table_list() if db else []
	var select: bool = true
	
	for tname in table_list:
		# If the DB is null then the array will be empty and this inner loop will not actually run. So it's
		# safe to use the 'db' argument in here without doing extra checks.
		var table: DBTable = db.get_table(tname)
		_add_table(table, select)
		select = false
	
	if (select):
		# If here then the database does not contain any table. If there was a previous database open, must
		# ensure the data is cleared within the TabularBox
		_on_table_selection(null)
	
	if (layout_saver && layout_saver.is_valid()):
		# Although the dbeplugin.gd calls this edit() function when the layout is being loaded, there should
		# be no problem attempting to "save" the layout again as that script does have means to prevent the
		# process from occurring when the layout is being restored.
		layout_saver.call_func()
	
	_update_ui()


# Called when the plugin is loaded (actually when the layout is loaded) in order to open the last edited
# table
func open_table(tbname: String) -> void:
	for te in _table_box.get_children():
		if (te is TableEntryT):
			if (te.get_table_name() == tbname):
				_on_table_selection(te)
				return




func setup_cwidth_data(cwd: Dictionary) -> void:
	_cwidth_data = cwd


# When the layout is loaded, this will be called in order to restore the splitter offset
func set_hsplit_offset(off: int) -> void:
	var hs: HSplitContainer = $vbox/main_container/hsplit as HSplitContainer
	if (!hs):
		return
	
	hs.split_offset = off



### This is to provide data when saving the layout (within dbeplugin.gd)
func get_edited_db() -> String:
	return _state.get_db_path()

func get_selected_table() -> String:
	var tbl: TableEntryT = _state.get_selected()
	
	return tbl.get_table_name() if tbl else ""




func get_splitter_offset() -> int:
	var hs: HSplitContainer = $vbox/main_container/hsplit as HSplitContainer
	
	return hs.split_offset






#######################################################################################################################
### "Private" definitions
const TableEntryPS: PackedScene = preload("tbl_list_entry.tscn")
const TableEntryT: Script = preload("tbl_list_entry.gd")

const DialogDBInfoT: Script = preload("dlg_dbinfo.gd")

# Manually loading the tabular box (and cell) just so the UI plugin doesn't need to also be activated if the user so desires
const TabularBoxT: Script = preload("res://addons/keh_ui/tabular/tabularbox.gd")


# An "ID system" for the "multipurpose" confirmation dialog box.
enum _ConfirmationID {
	RemoveColumn,
	RemoveRow,
	RemoveTable,
}


class _State:
	const TableEntryT: Script = preload("tbl_list_entry.gd")
	
	var _db: GDDatabase = null
	var _selected: TableEntryT = null
	
	
	func set_db(db: GDDatabase) -> void:
		_db = db
		_selected = null
	
	func get_db() -> GDDatabase:
		return _db
	
	
	func has_db() -> bool:
		return _db != null
	
	func get_db_path() -> String:
		if (_db):
			return _db.resource_path
		
		return ""
	
	func get_db_base_dir() -> String:
		assert(_db != null)
		return _db.resource_path.get_base_dir()
	
	
	func set_selected(uipanel: TableEntryT) -> void:
		if (_selected == uipanel):
			return
		
		if (_selected):
			_selected.set_selected(false)
		
		_selected = uipanel
		
		if (_selected):
			_selected.set_selected(true)
	
	
	func get_selected() -> TableEntryT:
		return _selected
	
	
	func has_selected_table() -> bool:
		return _selected != null
	
	
	func table_exists(tname: String) -> bool:
		return _db.has_table(tname)
	
	
	func get_column_count() -> int:
		return _selected.get_column_count() if _selected != null else 0


class _UITableSorter:
	const TableEntryT: Script = preload("tbl_list_entry.gd")
	
	static func compare(a: TableEntryT, b: TableEntryT):
		return a.get_table_name() < b.get_table_name()


#######################################################################################################################
### "Private" properties
var _state: _State = null

# This is a copy of the Dictionary created within the dbeplugin.gd script, which is meant to hold data related to
# the column widths.
var _cwidth_data: Dictionary

# Cache the container that will hold the list of tables of the loaded database
onready var _table_box: VBoxContainer = $vbox/main_container/hsplit/vbleft/scrollc/table_list as VBoxContainer

# Cache the TabularBox that will display the edited table data
#onready var _tabular: TabularBoxT = $vbox/main_container/hsplit/vbright/tabularbox as TabularBoxT
var _tabular: TabularBoxT = TabularBoxT.new()

# Cache the open/create database dialog
onready var _dlg_ocdb: FileDialog = $dialogs/dlg_ocdb as FileDialog

#######################################################################################################################
### "Private" functions
func _update_ui() -> void:
	# Button to display info should be disabled if no database is loaded
	$vbox/top_container/hbox_tbar/bt_dbinfo.disabled = !_state.has_db()
	
	# Display the database resource file path + name
	$vbox/top_container/hbox_tbar/lbl_dbres.text = _state.get_db_path()
	
	# Button to add tables must be disabled if there is no valid database being edited
	$vbox/main_container/hsplit/vbleft/boxbuttons/bt_addtable.disabled = !_state.has_db()
	
	# The table list "control" will ignore the mouse if there is no valid database being edited. This is required in order to properly deal
	# with drag & drop of table resources
	$vbox/main_container/hsplit/vbleft/scrollc/table_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if !_state.has_db() else Control.MOUSE_FILTER_PASS
	
	
	# Buttons to add column or row must be disabled if there is no *table* being edited
	$vbox/main_container/hsplit/vbright/boxbuttons/bt_addcolumn.disabled = !_state.has_selected_table()
	# Disable the add row button if there is no column (the get_column_count() considers ID as a column but it should not be enough to
	# enable the button).
	$vbox/main_container/hsplit/vbright/boxbuttons/bt_addrow.disabled = !_state.has_selected_table() || _state.get_column_count() <= 1
	
	# Display the name of the table being edited
	$vbox/main_container/hsplit/vbright/boxbuttons/lbl_tblname.text = _state.get_selected().get_table_name() if _state.has_selected_table() else "-"


func _add_table(table: DBTable, select: bool) -> void:
	var te: TableEntryT = TableEntryPS.instance()
	
	te.setup(_state.get_db(), table)
	
	DBHelpers.connector(te, "remove_requested", self, "_on_remove_table")
	DBHelpers.connector(te, "rename_requested", self, "_on_rename_table")
	DBHelpers.connector(te, "mouse_select", self, "_on_table_selection")
	
	_table_box.add_child(te)
	
	var children: Array = _table_box.get_children()
	children.sort_custom(_UITableSorter, "compare")
	
	for i in children.size():
		var c = children[i]
		_table_box.move_child(c, i)
	
	if (select):
		_on_table_selection(te)


func _restore_column_widths() -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var cwd: Dictionary = _cwidth_data.get(db.resource_path, {})
	
	if (cwd.empty()):
		return
	
	var tws: Dictionary = cwd.get(selected.get_table_name(), {})
	
	if (tws.empty()):
		return
	
	_tabular.set_column_widths(tws)


func _show_message(msg: String) -> void:
	# Reset the dialog size just so it become as compact as possible
	$dialogs/dlg_message.rect_size = Vector2()
	
	# Assign the desired message
	$dialogs/dlg_message.dialog_text = msg
	
	# Finally show it
	$dialogs/dlg_message.popup_centered()


func _save() -> void:
	var db: GDDatabase = _state.get_db()
	if (!db):
		# It should not come here....
		return
	
	if (!db.save(db.resource_path, true)):
		_show_message("Failed to save database file\n%s" % db.resource_path)


#######################################################################################################################
### Event handlers
func _on_bt_openclose_pressed() -> void:
	_dlg_ocdb.mode = FileDialog.MODE_OPEN_FILE
	_dlg_ocdb.window_title = "Open database"
	_dlg_ocdb.popup_centered()



func _on_bt_create_pressed() -> void:
	_dlg_ocdb.mode = FileDialog.MODE_SAVE_FILE
	_dlg_ocdb.window_title = "Create database"
	_dlg_ocdb.popup_centered()


# A file has been selected in the open/create database dialog
func _on_dlg_ocdb_file_selected(path: String) -> void:
	var db: GDDatabase = null
	
	if (_dlg_ocdb.mode == FileDialog.MODE_OPEN_FILE):
		var res: Resource = load(path)
		if (res is GDDatabase):
			db = res
		else:
			_show_message("The provided file\n'%s'\nis not a database (database.gd)." % path)
	
	
	elif (_dlg_ocdb.mode == FileDialog.MODE_SAVE_FILE):
		var nres: GDDatabase = GDDatabase.new()
		if (ResourceSaver.save(path, nres) == OK):
			db = load(path)
		
		else:
			_show_message("Failed to create new database at\n%s" % path)
	
	if (db != null):
		edit(db)



func _on_dbemain_visibility_changed() -> void:
	if (visible):
		_update_ui()




func _on_bt_addtable_pressed() -> void:
	var db: GDDatabase = _state.get_db()
	if (!db):
		return
	
	$dialogs/dlg_newtable.show_dialog(db.get_table_set())


func _on_bt_addcolumn_pressed():
	var db: GDDatabase = _state.get_db()
	var tb: String = _state.get_selected().get_table_name()
	
	$dialogs/dlg_newcolumn.set_column_index(-1)
	$dialogs/dlg_newcolumn.show_dialog(db, tb, !db.table_has_random_setup(tb))


func _on_tabularbox_insert_column_request(at_index: int) -> void:
	var db: GDDatabase = _state.get_db()
	var tb: String = _state.get_selected().get_table_name()
	
	$dialogs/dlg_newcolumn.set_column_index(at_index)
	$dialogs/dlg_newcolumn.show_dialog(db, tb, !db.table_has_random_setup(tb))



func _on_dlg_newtable_ok_pressed(tbl_name: String, tbl_file: String, embed: bool, idtype: int) -> void:
	var db: GDDatabase = _state.get_db()
	if (!db):
		return
	
	if (db.has_table(tbl_name)):
		return
	
	var bdir: String = _state.get_db_base_dir()
	if (tbl_file.get_extension() != "tres"):
		tbl_file += ".tres"
	
	var nres: DBTable = DBTable.new(idtype, tbl_name)
	if (!embed):
		var p: String = "%s/%s" % [bdir, tbl_file]
		
		if (ResourceSaver.save(p, nres) != OK):
			_show_message("Unable to create new table (%s) at\n%s" % [tbl_name, p])
			return
		
		# Load the file into the resource that will be added into the database, otherwise the data will not be saved
		# on the newly created file.
		nres = load(p)
	
	if (!db.add_table(nres)):
		# It should not come here, but... displaying error message just in case
		_show_message("Failed to add new table (%s) into the database." % [tbl_name])
	
	# Create the table UI entry and automatically select it (true on the second argument)
	_add_table(nres, true)
	
	_save()




func _on_dlg_rnametbl_ok_pressed(new_name: String) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	if (db.has_table(new_name)):
		# In theory this signal should not be emitted if the desired table name already exists, however extra
		# checking on something that can completely break the database is never enough
		return
	
	if (db.rename_table(selected.get_table_name(), new_name)):
		selected.table_renamed(new_name)
		_update_ui()
		_save()



func _on_dlg_newcolumn_ok_pressed(settings: Dictionary) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		# Should a message be displayed from here?
		return
	
	var tbl_name: String = selected.get_table_name()
	
	if (db.table_has_column(tbl_name, settings.name)):
		return
	
	# The new column dialog has already filtered out columns that are referencing this column. Still, perform this
	# check again. Checking things that can completely break the database are never enough!
	var external: String = settings.external
	
	if (!external.empty()):
		if (db.is_table_referenced_by(tbl_name, external)):
			return
	
	# Subtract one from the Index beucase the TabularBox is displaying a "fake" column created by the data source in order
	# to display the row ID of the selected table.
	var index: int = $dialogs/dlg_newcolumn.get_column_index() - 1
	
	var at: int = db.insert_column(tbl_name, settings.name, settings.type, index, external)
	if (at >= 0):
		selected.get_data_source().column_added(at)
		_update_ui()
		_save()


func _on_rename_table(entry: TableEntryT) -> void:
	$dialogs/dlg_rnametbl.showdlg(entry.get_table_name(), _state.get_db().get_table_set())


func _on_dialog_confirmed() -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	
	var id: int = $dialogs/dlg_confirm.get_action_code()
	var data: Dictionary = $dialogs/dlg_confirm.get_data()
	
	match id:
		_ConfirmationID.RemoveColumn:
			if (!db || !selected):
				return
			
			var col_index: int = data.column_index
			
			if (db.remove_table_column(selected.get_table_name(), col_index)):
				# Correct the index to take the ID "column" into account.
				selected.get_data_source().column_removed(col_index + 1)
				_save()
		
		_ConfirmationID.RemoveRow:
			if (!db || !selected):
				return
			
			var ilist: Array = data.index_list
			
			if (db.remove_row(selected.get_table_name(), ilist)):
				selected.get_data_source().row_removed(ilist)
				_save()
		
		_ConfirmationID.RemoveTable:
			if (!db):
				return
			
			var entry: TableEntryT = data.entry
			
			if (!db.remove_table(entry.get_table_name())):
				return
			
			_save()
			
			# Remove the table entry from the UI
			_table_box.remove_child(entry)
			
			# And mark the Control for removal
			entry.queue_free()
			
			# Since the entry is not on the tree anymore, it's safe to take the first remaining entry (fi any) and select it
			var nsel: TableEntryT = null
			if (_table_box.get_child_count() > 0):
				nsel = _table_box.get_child(0)
			
			if (!nsel):
				_tabular.set_data_source(null)
			
			_state.set_selected(nsel)
			_update_ui()




func _on_remove_table(entry: TableEntryT) -> void:
	var db: GDDatabase = _state.get_db()
	if (!db):
		return
	
	var table: DBTable = db.get_table(entry.get_table_name())
	var rlist: Array = table.get_referenced_by_list()
	
	if (rlist.size() > 0):
		var msg: String = "'%s' is referenced by the following table(s), thus can't be removed:" % entry.get_table_name()
		for t in rlist:
			msg += "\n- %s" % t
		
		_show_message(msg)
		
		return
	
	var txt: String = "Do you really want to remove '%s' table?" % entry.get_table_name()
	var data: Dictionary = {
		"entry": entry,
	}
	
	$dialogs/dlg_confirm.show_dialog(txt, _ConfirmationID.RemoveTable, data)




func _on_tabularbox_column_remove_request(column_index: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	if (column_index == 0):
		# This should not happen, but checking anyway. The thing is, the first column (ID) should not be
		# removed and it appears in the TabularBox as a "fake column". The data source (dbdsrc.gd) is creating
		# this column to display the row IDs.
		return
	
	# Subtract one from the column index because the database itself does not have the ID column
	column_index -= 1
	
	var cinfo: Dictionary = db.get_column_info(selected.get_table_name(), column_index)
	if (cinfo.empty()):
		_show_message("Attempting to remove '%s' column but the database doesn't\nseem to have any data for it.")
		return
	
	var txt: String = "Do you really want to remove '%s' column?" % cinfo.name
	var data: Dictionary = {
		"column_index": column_index,
	}
	
	$dialogs/dlg_confirm.show_dialog(txt, _ConfirmationID.RemoveColumn, data)


func _on_tabularbox_row_remove_request(index_list: Array) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var txt: String = ""
	if (index_list.size() > 1):
		txt = "Do you really want the selected rows (listed bellow) removed from the database?\n%s" % (str(index_list))
	
	elif (index_list.size() == 1):
		txt = "Do you really want to remove row %d from the database?" % index_list[0]
	
	if (txt.empty()):
		return
	
	var data: Dictionary = {
		"index_list": index_list,
	}
	
	$dialogs/dlg_confirm.show_dialog(txt, _ConfirmationID.RemoveRow, data)



func _on_tabularbox_column_rename_requested(column_index: int, new_title: String) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var rejected: bool = false
	
	if (column_index == 0 || selected.get_data_source().has_column(new_title)):
		# Reject the change because "id" cannot be renamed
		rejected = true
	
	else:
		# Subtracting one from the column index to take the "ID" into account, which is a "fake" column created
		# by the data source in order to display the row IDs.
		rejected = !db.rename_column(selected.get_table_name(), column_index - 1, new_title)
	
	
	if (!rejected):
		_save()
	
	selected.get_data_source().column_renamed(column_index, rejected)


func _on_tabularbox_column_move_requested(from_index: int, to_index: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	if (to_index == 0):
		# Do not allow any column to occupy the "row ID" spot
		return
	
	# Subtracting one from both indices to take the "row ID column" into account, which is a "fake column" created by
	# the data source to show the row ids
	if (db.move_table_column(selected.get_table_name(), from_index - 1, to_index - 1)):
		selected.get_data_source().column_moved(from_index, to_index)
		_save()



# Value is meant to be a Variant so no static typing for that argument
func _on_tabularbox_value_change_request(column_index: int, row_index: int, value) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var tname: String = selected.get_table_name()
	var changed: bool = false
	
	if (column_index == 0):
		# In here trying to update the row ID
		changed = db.set_row_id(tname, row_index, value)
	
	else:
		# Subtracting one from the requested column index in order to take the ID column into account,
		# which is not a real column within the database
		changed = db.set_cell_value(tname, column_index - 1, row_index, value)
	
	if (changed):
		_save()
	
	# Use the UI to relay the change (or rejection) into the data source
	selected.get_data_source().value_changed(column_index, row_index, value, !changed)


func _on_tabularbox_column_type_change_requested(column_index: int, to_type: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	# Subtracting one from the column index given to the database to take the ID column into account, which is
	# not a real column. It's created by the database to display the row ids.
	if (db.change_column_value_type(selected.get_table_name(), column_index - 1, to_type)):
		selected.get_data_source().column_type_changed(column_index)
		_save()



func _on_tabularbox_row_move_request(from_index: int, to_index: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	if (db.move_row(selected.get_table_name(), from_index, to_index)):
		selected.get_data_source().row_moved(from_index, to_index)
		_save()


func _on_tabularbox_row_sort_request(column_index: int, ascending: bool) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var changed: bool = false
	
	if (column_index == 0):
		changed = db.sort_rows_by_id(selected.get_table_name(), ascending)
	
	else:
		# Subtract 1 from the column index to take row ID column into account, which is a "fake column" created by the
		# data source in order to display the row ids.
		changed = db.sort_rows(selected.get_table_name(), column_index - 1, ascending)
	
	if (changed):
		selected.get_data_source().rows_sorted()
		_save()





func _on_table_selection(entry: TableEntryT) -> void:
	_state.set_selected(entry)
	
	if (entry):
		_tabular.set_data_source(entry.get_data_source())
		_update_ui()
		
		if (layout_saver && layout_saver.is_valid()):
			layout_saver.call_func()
		
		call_deferred("_restore_column_widths")
	
	else:
		_tabular.set_data_source(null)





func _on_table_list_table_resource_dropped(res: DBTable) -> void:
	if (_state.table_exists(res.get_table_name())):
		# NOTE: should a message be displayed here telling that a table with that name alrady exists?
		return
	
	var db: GDDatabase = _state.get_db()
	if (!db.add_table(res)):
		_show_message("Failed to add existing table (%s) into the database." % res.resource_path)
		return
	
	_add_table(res, true)
	
	# Ensure the resource is saved otherwise external tables won't be actually added into the DB unless further
	# changes to the main database are performed.
	_save()




func _on_bt_addrow_pressed() -> void:
	_on_tabularbox_insert_row_request(-1)



func _on_tabularbox_insert_row_request(at_index: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	if (!db || !selected):
		return
	
	var idx: int = db.insert_row(selected.get_table_name(), {}, at_index)
	
	if (idx > -1):
		selected.get_data_source().row_added(idx)
		_save()
	
	else:
		# It should not come here but displaying error message just in case
		_show_message("Failed to insert new row")


func _on_tabularbox_column_resized(column_title: String, new_width: int) -> void:
	var db: GDDatabase = _state.get_db()
	var selected: TableEntryT = _state.get_selected()
	
	if (!db || !selected):
		# This should not happen
		return
	
	var dbws: Dictionary = _cwidth_data.get(db.resource_path, {})
	
	if (dbws.empty()):
		_cwidth_data[db.resource_path] = dbws
	
	var tbws: Dictionary = dbws.get(selected.get_table_name(), {})
	
	if (tbws.empty()):
		dbws[selected.get_table_name()] = tbws
	
	tbws[column_title] = new_width
	
	if (layout_saver && layout_saver.is_valid()):
		layout_saver.call_func()



func _on_bt_dbinfo_pressed() -> void:
	var dlg: DialogDBInfoT = $dialogs/dlg_dbinfo
	dlg.show_dialog(_state.get_db().get_db_info())


func _on_hsplit_dragged(_offset: int) -> void:
	# Layout has changed so request the plugin script to save it
	if (layout_saver && layout_saver.is_valid()):
		layout_saver.call_func()




#######################################################################################################################
### Overrides
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_ENTER_TREE:
			var pnl_style: StyleBox = get_stylebox("panel", "Panel").duplicate()
			pnl_style.content_margin_left = 2
			pnl_style.content_margin_top = 2
			pnl_style.content_margin_right = 2
			pnl_style.content_margin_bottom = 2
			$vbox/main_container/hsplit/vbleft/scrollc.add_stylebox_override("bg", pnl_style)


func _enter_tree() -> void:
	var vbright: VBoxContainer = get_node_or_null("vbox/main_container/hsplit/vbright")
	if (vbright):
		var ci: int = 0
		var done: bool = false
		
		while (!done):
			var c: Node = vbright.get_child(ci)
			
			if (c is TabularBoxT):
				vbright.remove_child(c)
				c.free()
			
			else:
				ci += 1
			
			done = ci >= vbright.get_child_count()
		
		vbright.add_child(_tabular)
		_tabular.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabular.size_flags_vertical = Control.SIZE_EXPAND_FILL



func _init() -> void:
	_state = _State.new()
	
	_tabular.set_autosave_source(false)
	_tabular.set_autoedit_next_row(true)
	_tabular.set_autohandle_rem_row(false)
	_tabular.set_autohandle_rem_col(false)
	_tabular.set_autohandle_column_insertion(false)
	_tabular.set_autohandle_col_rename(false)
	_tabular.set_autohandle_col_move(false)
	_tabular.set_autohandle_col_type_change(false)
	_tabular.set_autohandle_row_insertion(false)
	_tabular.set_autohandle_row_move(false)
	_tabular.set_autohandle_row_sort(false)
	_tabular.set_show_row_numbers(true)
	_tabular.set_show_row_checkboxes(true)
	_tabular.set_hide_move_col_buttons(true)
	
	
	DBHelpers.connector(_tabular, "column_move_requested", self, "_on_tabularbox_column_move_requested")
	DBHelpers.connector(_tabular, "column_remove_request", self, "_on_tabularbox_column_remove_request")
	DBHelpers.connector(_tabular, "column_rename_requested", self, "_on_tabularbox_column_rename_requested")
	DBHelpers.connector(_tabular, "column_resized", self, "_on_tabularbox_column_resized")
	DBHelpers.connector(_tabular, "column_type_change_requested", self, "_on_tabularbox_column_type_change_requested")
	DBHelpers.connector(_tabular, "insert_column_request", self, "_on_tabularbox_insert_column_request")
	DBHelpers.connector(_tabular, "insert_row_request", self, "_on_tabularbox_insert_row_request")
	DBHelpers.connector(_tabular, "row_move_request", self, "_on_tabularbox_row_move_request")
	DBHelpers.connector(_tabular, "row_remove_request", self, "_on_tabularbox_row_remove_request")
	DBHelpers.connector(_tabular, "row_sort_request", self, "_on_tabularbox_row_sort_request")
	DBHelpers.connector(_tabular, "value_change_request", self, "_on_tabularbox_value_change_request")

### Those are the settings of the original version - which directly used the TabularBox.
#autosave_data_source = false
#auto_edit_next_row = true
#auto_handle_remove_row = false
#auto_handle_remove_column = false
#auto_handle_column_insertion = false
#auto_handle_column_rename = false
#auto_handle_column_reorder = false
#auto_handle_column_type_change = false
#auto_handle_row_insertion = false
#auto_handle_row_move = false
#auto_handle_row_sort = false
#show_row_numbers = true
#show_row_checkboxes = true
#hide_move_column_buttons = true
