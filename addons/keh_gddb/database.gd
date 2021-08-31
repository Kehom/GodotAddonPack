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
extends Resource
class_name GDDatabase



#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func save(path: String, include_tables: bool) -> bool:
	if (path.empty()):
		path = resource_path
	
	if (include_tables):
		for tn in _table:
			var tb: DBTable = _table[tn]
			
			var tpath: String = tb.resource_path
			if (tpath.begins_with("res://") && tpath.find("::") == -1):
				if (ResourceSaver.save(tpath, tb, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS) != OK):
					# Should this just error out?!
					pass
	
	
	if (!path.begins_with("res://") || path.find("::") != -1):
		return false
	
	return (ResourceSaver.save(path, self, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS) == OK)
	



func has_table(n: String) -> bool:
	return _table.has(n)


func add_table(t: DBTable) -> bool:
	var tname: String = t.get_table_name()
	
	if (has_table(tname)):
		return false
	
	_table[tname] = t
	
	if (t.get_id_type() == TYPE_INT):
		_intidlist.append(tname)
	elif (t.get_id_type() == TYPE_STRING):
		_stridlist.append(tname)
	
	return true


func rename_table(from: String, to: String) -> bool:
	if (from == to):
		return true
	
	if (_table.has(to)):
		return false
	
	var tbl: DBTable = _table.get(from, null)
	if (!tbl):
		return false
	
	_table[to] = tbl
	
	# warning-ignore:return_value_discarded
	_table.erase(from)
	
	# Update the resource's internal property. Use the generic "set()" as the table_name property is not meant to be
	# directly edited.
	tbl.set("table_name", to)
	
	# Update all tables referencing the renamed one
	var refs: Array = tbl.get_referenced_by_list()
	
	for rname in refs:
		var rtbl: DBTable = _table[rname]
		rtbl.referenced_table_renamed(from, to)
	
	_check_table_setup()
	
	return true



# Obtain an array containing the names of all tables within this database
func get_table_list() -> Array:
	return _table.keys()


# Obtain the "list" of tables in a Dictionary that is used as a Set, that means, values are irrelevant.
func get_table_set() -> Dictionary:
	var ret: Dictionary = {}
	
	for t in _table:
		ret[t] = 0
	
	return ret


# Retrieve a table instance given its name
func get_table(t: String) -> DBTable:
	return _table.get(t, null)


# Removes a table from the database
func remove_table(t: String) -> bool:
	var table: DBTable = _table.get(t, null)
	
	if (!table):
		return false
	
	if (table.get_referenced_by_list().size() > 0):
		# This table is referenced by other tables, so don't allow its removal
		return false
	
	if (table.get_id_type() == TYPE_INT):
		var idx: int = _intidlist.find(t)
		if (idx != -1):
			_intidlist.remove(idx)
		
	elif (table.get_id_type() == TYPE_STRING):
		var idx: int = _stridlist.find(t)
		if (idx != -1):
			_stridlist.remove(idx)
	
	# warning-ignore:return_value_discarded
	_table.erase(t)
	
	return true


# Build a list of possible tables that can be referenced by the given table name. This is meant mostly for UI
func get_external_candidates_for(type: int, table: String) -> Array:
	var ret: Array = []
	var list: Array = []
	
	if (type == DBTable.ValueType.VT_ExternalString):
		list = _stridlist
	
	elif (type == DBTable.ValueType.VT_ExternalInteger):
		list = _intidlist
	
	var srctable: DBTable = _table.get(table, null)
	
	if (!srctable):
		return ret
	
	for ctbl in list:
		if (ctbl == table):
			continue
		
		# Only add a candidate if it does not reference the "source table" itself and source table is not already
		# referencing the other table
		if (!srctable.is_referenced_by(ctbl) && !srctable.is_referencing(ctbl)):
			ret.append(ctbl)
	
	return ret



# Returns true if the given table name contains a column with the given title
func table_has_column(table: String, title: String) -> bool:
	var tbl: DBTable = _table.get(table, null)
	if (!tbl):
		return false
	
	return tbl.has_column(title)


# Insert a new column on the given table name.
func insert_column(on_table: String, title: String, value_type: int, index: int, external: String) -> int:
	var table: DBTable = _table.get(on_table, null)
	
	if (!table):
		return -1
	
	if (table.has_column(title)):
		return -1
	
	if (value_type == DBTable.ValueType.VT_ExternalString || value_type == DBTable.ValueType.VT_ExternalInteger):
		if (external.empty() || !_table.has(external)):
			return -1
		
		if (table.is_referenced_by(external)):
			return -1
	
	else:
		external = ""
	
	var csettings: Dictionary = {
		"value_type": value_type,
		"index": index,
		"external": external,
	}
	
	var ret: int = table.add_column(title, csettings)
	
	if (ret >= 0 && !external.empty()):
		# Rebuild internal table "linking"
		_check_table_setup()
	
	return ret


func rename_column(on_table: String, column_index: int, new_title: String) -> bool:
	var table: DBTable = _table.get(on_table, null)
	if (!table):
		return false
	
	if (table.has_column(new_title)):
		return false
	
	return table.rename_column(column_index, new_title)



# Get column info, col_index, from the given table name
func get_column_info(from_table: String, col_index: int) -> Dictionary:
	var tbl: DBTable = _table.get(from_table, null)
	if (!tbl):
		return {}
	
	return tbl.get_column_by_index(col_index)


# Remove the given column (at index) from the provided table name. Returns true if something changed
func remove_table_column(from_table: String, col_index: int) -> bool:
	var tbl: DBTable = _table.get(from_table, null)
	if (!tbl):
		return false
	
	var cinfo: Dictionary = tbl.get_column_by_index(col_index)
	if (cinfo.empty()):
		return false
	
	var external: String = cinfo.get("extid", "")
	
	var ret: bool = tbl.remove_column(col_index)
	
	if (ret && !external.empty()):
		# The removed column is referencing another table. Rebuild the internal "linking".
		_check_table_setup()
	
	return ret


# Move a column into a new index (reorder the column) within the specified table. Returns true if something
# changed
func move_table_column(on_table: String, from_index: int, to_index: int) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	return tbl.move_column(from_index, to_index)


# Change the value type of a column within the table name. Returns true if something changed.
func change_column_value_type(on_table: String, column_index: int, to_type: int) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	return tbl.change_column_vtype(column_index, to_type)


# Returns true if the given table name has the random weight system setup
func table_has_random_setup(table: String) -> bool:
	var tbl: DBTable = _table.get(table, null)
	if (!tbl):
		return false
	
	return tbl.has_random_weight_column()


# Given a table name and a row id, retrieve row data. If expand is set to true and the table
# contains columns referencing other tables, then the referenced data will be expanded and added
# as fields of an inner Dictionary with the same name of the column referencing the data.
func get_row_from(table: String, id, expand: bool = false) -> Dictionary:
	var tbl: DBTable = _table.get(table, null)
	if (!tbl):
		return {}
	
	if (typeof(id) != tbl.get_id_type()):
		return {}
	
	var ret = tbl.get_row(id)
	
	if (expand):
		# Key = name of referenced table
		# Value = column referencing 'key'
		var reflist: Dictionary = tbl._get_reference_data()
		
		for rt in reflist:
			# Name of the column referencing another table
			var refing: String = reflist[rt]
			
			# ID of the row within the other table. Because the value can be either String or Int, not static typing here
			var refid = ret[refing]
			
			# Do not expand even further to avoid problems if referencing tables are forming circles.
			ret[refing] = get_row_from(rt, refid, false)
	
	return ret


func get_row_by_index_from(table: String, index: int, expand: bool = false) -> Dictionary:
	var tbl: DBTable = _table.get(table, null)
	if (!tbl):
		return {}
	
	var ret = tbl.get_row_by_index(index)
	
	if (expand):
		var reflist: Dictionary = tbl._get_reference_data()
		
		for rt in reflist:
			var refing: String = reflist[rt]
			
			var refid = ret[refing]
			
			ret[refing] = get_row_from(rt, refid, false)
	
	return ret


func randomly_pick_from(table: String, expand: bool = false) -> Dictionary:
	var tbl: DBTable = _table.get(table, null)
	if (!tbl):
		return {}
	
	var ret = tbl.get_random_row()
	
	if (expand):
		var reflist: Dictionary = tbl._get_reference_data()
		
		for rt in reflist:
			var refing: String = reflist[rt]
			var refid = ret[refing]
			ret[refing] = get_row_from(rt, refid, false)
	
	return ret


# Inserts a row into the provided table name. The values can even be completely empty as the
# DBTable attempts to create default values to every existing column. The index is where the
# row should be inserted at. Returns the index where the row was inserted, -1 if error
func insert_row(on_table: String, values: Dictionary, at_index: int) -> int:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return - 1
	
	return tbl.add_row(values, at_index)


# Moves a row from its position (reorder) on the specified table. Returns true if something changed
func move_row(on_table: String, from: int, to: int) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	return tbl.move_row(from, to)


# Please make sure the index list of rows to be removed to be in reverse order. The algorithm here
# will not ensure this fact and if it's not in the correct order some rows that are not meant to
# be removed will be taken out of the database.
func remove_row(from_table: String, index_list: Array) -> bool:
	var tbl: DBTable = _table.get(from_table, null)
	if (!tbl):
		return false
	
	# If another table is referencing "from_table" then that other must be updated as some of its
	# cells may be pointing to the row being removed. The way this will happen here foolows:
	# - For each row to be removed, its ID will be stored within a Dictionary used as a Set
	# - Once every row is removed, use the list of tables referencing the "from_table" and
	#   "notify" it that the rows within the provided Dictionary have been removed
	# - The referencing table should then go through each cell in the corresponding column, checking
	#   if the value is within the provided Dictionary. If so, clear the stored value
	var reflist: Array = tbl.get_referenced_by_list()
	var remset: Dictionary = {}
	
	for ri in index_list:
		# There is no need to fill the remset if there is no referencing table
		if (reflist.size() > 0):
			remset[tbl.get_row_id(ri)] = 0
		
		tbl.remove_row_by_index(ri)
	
	if (!remset.empty()):
		for rname in reflist:
			var rtbl: DBTable = _table.get(rname)
			
			rtbl.referenced_rows_removed(from_table, remset)
	
	
	return true


# func set_id_by_index(rindex: int, newid) -> bool:
func set_row_id(on_table: String, row_index: int, new_id) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	# First take current ID as it may be necessary to update referencing tables (if any)
	# Relying on variant because this can be either a String or an Integer
	var oid = tbl.get_row_id(row_index)
	
	var ret: bool = tbl.set_id_by_index(row_index, new_id)
	
	if (ret):
		# A row_id has changed. Must verify if there is another table that references this row ID and
		# if so, update those references to the new value
		var rlist: Array = tbl.get_referenced_by_list()
		
		for rt in rlist:
			var ref: DBTable = _table.get(rt, null)
			
			if (!ref):
				push_warning("Table '%s' reports it's referenced by '%s', which was not found on the database." % [on_table, rt])
				continue
			
			ref.referenced_row_id_changed(on_table, oid, new_id)
		
	
	return ret


func sort_rows_by_id(on_table: String, ascending: bool) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	tbl.sort_by_id(ascending)
	return true


# Sort rows on the specified table by the given column index, either ascending or descending. Returns true if
# something has changed
func sort_rows(on_table: String, by_col: int, ascending: bool) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	return tbl.sort_by_column(by_col, ascending)



# Change the value of the cell in the specified table. Returns true if there was a change
# Because the value can be of any type, relying on Variant (no static typing)
func set_cell_value(on_table: String, column_index: int, row_index: int, value) -> bool:
	var tbl: DBTable = _table.get(on_table, null)
	if (!tbl):
		return false
	
	return tbl.set_value_by_index(column_index, row_index, value)



# Returns true if the given table name is referenced by the other table name
func is_table_referenced_by(table: String, other_table: String) -> bool:
	assert(_table.has(table) && _table.has(other_table))
	
	var tbl: DBTable = _table.get(table, null)
	
	return tbl.is_referenced_by(other_table)



# Build a Dictionary containing information related to the database. This might be useful for debugging.
func get_db_info() -> Dictionary:
	var tbdata: Array = []
	
	for tbname in _table:
		var tbl: DBTable = _table[tbname]
		var path: String = tbl.resource_path
		
		if (!(path.begins_with("res://") && path.find("::") == -1)):
			path = "embedded"
		
		
		tbdata.append({
			"name": tbname,
			"path": path,
			"id_type": "Integer" if tbl.get_id_type() == TYPE_INT else "String",
			"column_count": tbl.get_column_count(),
			"row_count": tbl.get_row_count(),
			"references": tbl.get_reference_list(),
			"referenced_by": tbl.get_referenced_by_list(),
		})
	
	
	return {
		"database": resource_path,
		"table_count": _table.size(),
		"table_data": tbdata,
	}

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# From table name into instance of DBTable
var _table: Dictionary = {}

# Hold some "meta data" that will be dynamically generated (in other words, not stored). Those are meant mostly to help
# keep the internal structure of the DB consistent (as well as to provide some data to external code)

# Hold list of table names that use String as unique ID
var _stridlist: Array = []

# Hold list of table names that use Integer as Unique ID
var _intidlist: Array = []


#######################################################################################################################
### "Private" functions
func _check_table_setup() -> void:
	# First go through all tables and clear the "referenced by list" in all of them.
	for tb in _table.values():
		tb.clear_referencer()
	
	for tbname in _table:
		var table: DBTable = _table[tbname]
		
		
		if (table.get_id_type() == TYPE_INT):
			_intidlist.append(tbname)
		elif (table.get_id_type() == TYPE_STRING):
			_stridlist.append(tbname)
		else:
			# NOTE: It should not come here and if so, there is a big error with the data generation (or some manually altered
			#       data caused this). Should an error message be displayed?
			pass
		
		var reflist: Array = table.get_reference_list()
		
		for refname in reflist:
			var referenced: DBTable = _table.get(refname, null)
			
			# NOTE: for some reason, after the app/editor closes, the resources are not fully updated and renamed referenced
			#       tables will incorrectly report as missing when running this portion of the code. Yet, the saved resources
			#       are indeed in the correct state. Debugging shown that the state is indeed as expected. So, unfortunatelly
			#       can't display a warning message here if the referenced table is not found because it may give false warning
			#       when tables are renamed.
			
			if (referenced):
				referenced.add_referencer(tbname)





#######################################################################################################################
### Event handlers
func _on_reference_added(src_table: String, to_table: String) -> void:
	var referenced: DBTable = _table.get(to_table, null)
	if (!referenced):
		return
	
	referenced.add_referencer(src_table)

func _on_reference_removed(src_table: String, to_table: String) -> void:
	var referenced: DBTable = _table.get(to_table, null)
	if (!referenced):
		return
	
	referenced.remove_referencer(src_table)







#######################################################################################################################
### Overrides

func _get_property_list() -> Array:
	return [
		{
			"name": "table",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		}
	]



func _set(prop: String, value) -> bool:
	match (prop):
		"table":
			_table = value
			_check_table_setup()
			return true
	
	return false


func _get(prop: String):
	match prop:
		"table":
			return _table
	
	return null


