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

# This will bridge the DB tables with the TabularBox

tool
extends TabularDataSourceBase


#######################################################################################################################
### Signals and definitions
#const CBaseT: Script = preload("res://addons/keh_ui/tabular/columnbase.gd")
const CStringT: Script = preload("res://addons/keh_ui/tabular/default_columns/columnstring.gd")
const CBoolT: Script = preload("res://addons/keh_ui/tabular/default_columns/columnbool.gd")
const CIntT: Script = preload("res://addons/keh_ui/tabular/default_columns/columnint.gd")
const CFloatT: Script = preload("res://addons/keh_ui/tabular/default_columns/columnfloat.gd")
const CTextureT: Script = preload("res://addons/keh_ui/tabular/default_columns/columntexture.gd")


const CExternalT: Script = preload("columnexttable.gd")
const CAudioT: Script = preload("columnaudio.gd")
const CRWeightT: Script = preload("columnrweight.gd")
const CGenResT: Script = preload("columngres.gd")
const CColorT: Script = preload("columncolor.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func setup(db: GDDatabase, table: DBTable) -> void:
	_db = db
	_dbtable = table


func get_table() -> DBTable:
	return _dbtable

func get_table_name() -> String:
	return _dbtable.get_table_name() if _dbtable != null else ""



func get_class_for_type(tp: int) -> Script:
	match tp:
		DBTable.ValueType.VT_UniqueString, DBTable.ValueType.VT_String:
			return CStringT
		
		DBTable.ValueType.VT_Bool:
			return CBoolT
		
		DBTable.ValueType.VT_UniqueInteger, DBTable.ValueType.VT_Integer:
			return CIntT
		
		DBTable.ValueType.VT_Float:
			return CFloatT
		
		DBTable.ValueType.VT_Texture:
			return CTextureT
		
		DBTable.ValueType.VT_Audio:
			return CAudioT
		
		
		DBTable.ValueType.VT_ExternalString, DBTable.ValueType.VT_ExternalInteger:
			return CExternalT
		
		DBTable.ValueType.VT_RandomWeight:
			return CRWeightT
		
		DBTable.ValueType.VT_GenericRes:
			return CGenResT
		
		DBTable.ValueType.VT_Color:
			return CColorT
	
	return null


func get_flags_for_type(tp: int) -> int:
	var fs: Dictionary = ColumnBaseT.FlagSettings
	
	# For much better control over value changes, request a signal to be given by the TabularBox (fs.ValueChangeSignal is set)
	var ret: int = fs.AllowSorting | fs.AllowResize | fs.AllowTitleEdit | fs.AllowMenu | fs.ValueChangeSignal
	
	if (tp >= 1000):
		ret |= fs.AllowTypeChange
	
	return ret



#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _type_list: Dictionary = DBHelpers.generate_ui_non_unique_types()

var _dbtable: DBTable = null

# After many (failed) attempts to avoid having the database itself here, just adding it. Passing external tables to
# the UI becomes a lot easier with this
var _db: GDDatabase = null

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
# This must return a Dictionary containing the list of available value types. The format should be:
# key = integer, value type code
# value = string, which will be used to identify this type within the UI.
# Note that the associated column class is not part of this Dictionary, mostly because it is retrieved at a different
# stage, through the get_column_info() function.
func get_type_list() -> Dictionary:
	return _type_list

func has_column(title: String) -> bool:
	if (title == "ID"):
		return true
	
	return _dbtable.has_column(title)

# This must return the number of columns within this data object
func get_column_count() -> int:
	# Add one for the "id" column.
	return _dbtable.get_column_count() + 1

# Given the column index this function must return a Dictionary containing information related to the column.
# With the exception of "title", entries are optional and if not provided will default to the value shown bellow:
# - title: String -> must match the title of the column
# - type_code: int -> internal custom value type code. Will default to 0 if not given
# - column_class: Script -> must specify which TabularColumn* will be used when instancing a column. Defaults to TabularColumnString
# - flags: int -> flag settings based on the enum TabularColumnBase.FlagSettings. Will default to FlagSettings._Default
func get_column_info(index: int) -> Dictionary:
	var ret: Dictionary
	var fs: Dictionary = ColumnBaseT.FlagSettings
	
	if (index == 0):
		var idtype: int = _dbtable.get_id_type()
		var tp: int = DBTable.ValueType.VT_UniqueString if idtype == TYPE_STRING else DBTable.ValueType.VT_UniqueInteger
		
		ret = {
			"title": "ID",
			"type_code": tp,
			"column_class": CStringT if idtype == TYPE_STRING else CIntT,
			"flags": fs.AllowSorting | fs.AllowResize | fs.LockIndex | fs.ValueChangeSignal
		}
	
	else:
		var cinfo: Dictionary = _dbtable.get_column_by_index(index-1)
		
		ret = {
			"title": cinfo.name,
			"type_code": cinfo.value_type,
			"column_class": get_class_for_type(cinfo.value_type),
			"flags": get_flags_for_type(cinfo.value_type)
		}
	
	
	return ret



# The editor plugin takes over the process of adding columns into the TabularBox. Because of that there is no need
# to override the insert_column() function from the data source base. Yet, it's still necessary to notify the
# TabularBox that a column has been inserted. This function is meant to perform that notifying
func column_added(at: int) -> void:
	# Add one to the index because "0" is a "fake column" for the ID, which is not a real column within the DBTable
	_notify_new_column(at + 1)


# The editor plugin takes over the column removal (by disabling the Auto Handle Remove Column flag) from the TabularBox.
# Because of that there is no need to override the remove_column() function from the data source base. Yet, it's still
# necesary to notify the TabularBox that a column has been removed. This function is meant to perform that.
func column_removed(index: int) -> void:
	# The plugin (DBEMain) is already dealing with the index correction, so no need to add or subtract here
	_notify_column_removed(index)


# Some columns in this system require additional setup after creation, because of this it's necessary to override this
# function.
# Namelly:
# - Columns pointing into a different table require information related to the other table.
# - The automatic random weight system require the table data to display some additional information
func column_ui_created(col: ColumnBaseT) -> void:
	if (col is CExternalT):
		var referenced: String = _dbtable.get_referenced_by_column(col.get_title())
		var reftable: DBTable = _db.get_table(referenced)
		
		col.set_other_table(reftable)
	
	if (col is CRWeightT):
		col.extra_setup(_dbtable)




# The editor plugin takes over the column renaming (by disabling the AutoHandleColumnRename flag) from the TabularBox.
# Because of this there is no need to override rename_column() from the data source base. Yet, it's still necessary
# to notify the TabularBox control about the change so it can update the rendering, which is done through this function
func column_renamed(index: int, rejected: bool) -> void:
	if (rejected):
		_notify_column_rename_rejected(index)
	else:
		_notify_column_renamed(index)


# The dbemain plugin takes over the column reordering (by disabling the AutoHandleColumnReorder flag) from the TabularBox.
# Because of this there is no need to override move_column() from the data source base. Yet, it's still necessary to
# notify the TabularBox control when a column is moved so it can update the rendering. This is done through this function
func column_moved(from: int, to: int) -> void:
	_notify_column_moved(from, to)


# The dbemain plugin takes over the column value type changing (by disabling the AutoHandleColumnTypeChange flag) from the TabularBox.
# Because of this there is no need to override change_column_value_type() fomr the data source base. yet, it's still necessary
# to notify the TabularBox control when a type change occurs so it can update the rendering. This is done through this function.
func column_type_changed(column_index: int) -> void:
	_notify_type_changed(column_index)




func get_row_count() -> int:
	return _dbtable.get_row_count()


# The editor plugin takes over row insertion so there is no need to override insert_row() from
# the data source base. Still, it's necessary to notify the TabularBox that a change occurred
# in order for the rendering to update. This function is meant to do that
func row_added(at: int) -> void:
	_notify_new_row(at)


# The editor plugin takes over row removal so there is no need to override remove_row() from the
# data source base. Still, it's necessary to notify the TabularBox that a change occurred, which
# is done through this function. This assumes the index list within the incoming array is in
# decreasing order
func row_removed(list: Array) -> void:
	for i in list:
		_notify_row_removed(i)


# The editor plugin takes over row reordering by disabling the AutoHandleRowMove flag in the TabularBox.
# Because of that it's not necessary to override the move_row() function from the data source base.
# However it's still necesary to notify the TabularBox that a change occurred, which is done with this
# function
func row_moved(from: int, to: int) -> void:
	_notify_row_moved(from, to)





# The TabularBox doesn't exactly use this but the base function is given mostly for practical use. The recommended here
# is that the returned dictionary contains the column titles as key with their respective values for the given row index.
func get_row(index: int) -> Dictionary:
	return _dbtable.get_row_by_index(index)

# Because the stored value can be of any type, relying on Variant return (thus, no static type here)
func get_value(col_index: int, row_index: int):
	if (col_index == 0):
		if (_dbtable.get_id_type() == TYPE_STRING):
			return _dbtable.get_row_str_id(row_index)
		else:
			return _dbtable.get_row_int_id(row_index)
	
	else:
		# Again, this data source is adding a "fake column" for the ID, so must compensate the index to obtain the correct
		# stored data within the table
		col_index -= 1
		var col: Dictionary = _dbtable.get_column_by_index(col_index)
		var title: String = col.name
		
		return _dbtable.get_row_by_index(row_index)[title]


# All columns created by the plugin contain the flag ValueChangeSignal set, meaning that it somewhat
# "takes over" the value changing through signal. Still, the data source must notify about the
# change (or rejection) in order for the TabularBox to update its rendering.
# Nevertheless, there is no need to override the set_value() function because the dbemain.gd is taking
# care of the signal and requesting the change within the database.
func value_changed(col_index: int, row_index: int, value, rejected: bool) -> void:
	if (rejected):
		_notify_value_change_rejected(col_index, row_index)
	else:
		_notify_value_changed(col_index, row_index, value)



# The editor plugin takes over the row sorting from TabularBox by disabling the AutoHandleRowSort flag.
# Because of that it's not necessary to override the sort_by_col() function from the data source base.
# However notifying the TabularBox about the change is necessary in order to update its rendering.
func rows_sorted() -> void:
	_notify_sorted()
