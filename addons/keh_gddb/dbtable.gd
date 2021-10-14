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
class_name DBTable


#######################################################################################################################
### Signals and definitions

# For organization purposes some entries are skpping values. This is certainly not necessary but well....
enum ValueType {
	VT_UniqueString,
	VT_UniqueInteger,
	
	# Those are meant for special usage.
	VT_ExternalString = 500,
	VT_ExternalInteger,
	
	VT_RandomWeight = 600,
	
	# For "normal" usage. Columns of types bellow here will be able to change to other types as long as the
	# target type is not one of the above options
	VT_String = 1000,
	VT_Bool,
	VT_Integer,
	VT_Float,
	VT_Texture,
	VT_Audio,
	VT_GenericRes,
	VT_Color
}

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func get_table_name() -> String:
	return _table_name



# Either TYPE_STRING or TYPE_INT. This determine what type is used as key to identify rows in this table
func get_id_type() -> int:
	return _id_type


# Obtain number of columns in this table
func get_column_count() -> int:
	return _column_arr.size()


# If this table references another table or is referenced by another one, please avoid directly calling this function.
# Instead use the database's insert_column() function.
func add_column(cname: String, settings: Dictionary = {}) -> int:
	if (cname.empty() || _column_index.has(cname)):
		return -1
	
	var vtype: int = settings.get("value_type", ValueType.VT_String)
	
	if (vtype == ValueType.VT_RandomWeight && has_random_weight_column()):
		# Only one random weight column per table is allowed
		return -1
	
	var ext: String = ""
	if (vtype == ValueType.VT_ExternalString || vtype == ValueType.VT_ExternalInteger):
		ext = settings.external
		
		# Update the referencing list
		_reftable[ext] = cname
	
	
	var index: int = settings.get("index", -1)
	
	if (index < 0 || index >= _column_arr.size()):
		index = _column_arr.size()
	
	var column: Dictionary = {
		"name": cname,
		"value_type": vtype,
	}
	
	# No need to add the "extid" entry if the column is not referencing an external table
	if (!ext.empty()):
		column["extid"] = ext
	
	if (index < _column_arr.size()):
		_column_arr.insert(index, column)
	else:
		_column_arr.append(column)
	
	_column_index[cname] = column
	
	for row in _rowlist:
		var dval = _get_default_val(column)
		row[cname] = dval
		
		if (_require_unique_vals(column)):
			_set_used(column, dval)
	
	if (vtype == ValueType.VT_RandomWeight):
		_set_auto_weight(cname, true)
	
	return index


func has_column(t: String) -> bool:
	return _column_index.has(t)


func has_random_weight_column() -> bool:
	return !_randweight.empty()


# Obtain a Dictionary with info about the column within the given index. If index is invalid an empty Dictionary
# is returned. The returned Dictionary contains the following entries: name (String), value_type (int)
func get_column_by_index(index: int) -> Dictionary:
	if (index < 0 || index >= _column_arr.size()):
		return {}
	
	return _column_arr[index]


# Given a column index, obtain its title
func get_column_title(index: int) -> String:
	if (index < 0 || index >= _column_arr.size()):
		return ""
	
	return _column_arr[index].name


# Delete the given column from the resource. Be careful with this because it can't be undone
func remove_column(cindex: int) -> bool:
	if (cindex < 0 || cindex >= _column_arr.size()):
		return false
	
	var col: Dictionary = _column_arr[cindex]
	
	_column_arr.remove(cindex)
	
	# warning-ignore:return_value_discarded
	_column_index.erase(col.name)
	
	for row in _rowlist:
		row.erase(col.name)
	
	if (_require_unique_vals(col)):
		# warning-ignore:return_value_discarded
		_uindex.erase(col.name)
	
	var ext: String = col.get("extid", "")
	if (!ext.empty()):
		# warning-ignore:return_value_discarded
		_reftable.erase(ext)
	
	if (_randweight.size() > 0):
		var rt: String = _randweight.column
		if (rt == col.name):
			_set_auto_weight("", false)
	
	return true


# Change the title of a column. Return true if something changed
func rename_column(cindex: int, to: String) -> bool:
	if (cindex < 0 || cindex >= _column_arr.size()):
		return false
	
	var col: Dictionary = _column_arr[cindex]
	
	if (col.name == to):
		# The new provided name is the exact same of the one that already is set. Nothing to do here
		return false
	
	var oname: String = col.name
	
	# Create the correct entry within the indexing
	_column_index[to] = col
	
	# Remove the old entry from the indexing
	# warning-ignore:return_value_discarded
	_column_index.erase(oname)
	
	# Update the entry itself
	col.name = to
	
	for row in _rowlist:
		row[to] = row[oname]
		row.erase(oname)
	
	# Check if this column references another table. If so, must update the _reftable list
	var ext: String = col.get("extid", "")
	if (!ext.empty()):
		# Remembering. The _reftable holds the referenced table as key and the referencing column as value
		_reftable[ext] = to
	
	# If this column is the auto random weight, then must update the internal data related to it
	_set_auto_weight(to, false)
	
	return true



# Moves a column from index into index. Returns true if something changed
func move_column(from: int, to: int) -> bool:
	if (from == to):
		return false
	
	if (from < 0 || from >= _column_arr.size()):
		return false
	if (to < 0 || to >= _column_arr.size()):
		return false
	
	var centry: Dictionary = _column_arr[from]
	_column_arr.remove(from)
	
	if (to == _column_arr.size()):
		# Because the "from" was temporarily removed from the array it is possible the "to" is now pointing past
		# the array boundaries. In this case just append the column back
		_column_arr.append(centry)
	
	else:
		# Otherwise just insert the column back into the desired index
		_column_arr.insert(to, centry)
	
	# No need to update indexing because the dictionary deal with the column title pointing into the Dictionary
	# that remains unchanged
	return true



# Change the value type of a given column
func change_column_vtype(cindex: int, vtype: int) -> bool:
	if (cindex < 0 || cindex >= _column_arr.size()):
		return false
	
	var col: Dictionary = _column_arr[cindex]
	
	if (col.value_type < 1000):
		# 1000 is the first "ID" of value types that can be changed. Don't change anything that is bellow it.
		return false
	
	col.value_type = vtype
	
	_convert_value_type(col.name, vtype)
	
	return true


# Obtain an array containing the list of column names in the "display order".
func get_column_order() -> Array:
	var ret: Array = []
	
	for c in _column_arr:
		ret.append(c.name)
	
	
	return ret


# Return number of rows within this table
func get_row_count() -> int:
	return _rowlist.size()




# This is meant to add a new row into the table. A valid ID will be generated automatically. It can be changed
# at a later time
func add_row(values: Dictionary, at: int) -> int:
	if (at < 0 || at > _rowlist.size()):
		# Desired insertion index is out of bounds. Set the value so row is appended
		at = _rowlist.size()
	
	var id
	if (_id_type == TYPE_INT):
		id = _generate_int_id()
	elif (_id_type == TYPE_STRING):
		id = _generate_str_id()
	else:
		return -1
	
	var nrow: Dictionary = {
		# It's safe to use "id" as field because a custom column cannot be named as "id"
		"id": id,
	}
	
	for ci in _column_arr.size():
		var cinfo: Dictionary = _column_arr[ci]
		var ctitle: String = cinfo.name
		
		var val = values.get(ctitle)
		
		if (val == null):
			val = _get_default_val(cinfo)
		else:
			if (_require_unique_vals(cinfo) && !_is_unique(cinfo, val)):
				# NOTE: Should this section error out instead of silently generating a valid unique value?
				val = _get_default_val(cinfo)
		
		nrow[ctitle] = val
	
	
	if (at < _rowlist.size()):
		_rowlist.insert(at, nrow)
		
		# Because the row is being inserted, better to just recalculate the weights
		_calculate_weights()
		
	else:
		_rowlist.append(nrow)
		
		# Row is being appended. Updating the weights is simpler in this case - if there is any weight column that is
		if (_randweight.size() > 0):
			var w: float = _randweight.total + 1.0
			
			_accweight.append(w)
			
			_randweight.total = w
	
	_rindex[id] = nrow
	
	return at



# Obtain a row data given its ID
# The id is either integer or string. Because of that not static typing the argument.
func get_row(id) -> Dictionary:
	assert(typeof(id) == _id_type)
	
	return _rindex.get(id, {})


# Obtain a row data given its index within the internal array
func get_row_by_index(index: int) -> Dictionary:
	if (index < 0 || index >= _rowlist.size()):
		return {}
	
	return _rowlist[index]

# Given a row ID and a column title, retrieve the value of a single cell
# NOTE: the stored value can be of any type so no static typing it (in other words, the return is a Variant)
func get_cell_value(rid: int, ctitle: String):
	assert(typeof(rid) == _id_type)
	
	var r: Dictionary = _rindex.get(rid, {})
	if (r.empty()):
		return null
	
	return r.get(ctitle, null)


# Randomly choose a row and return it. If this table contains a "Random Weight" column then
# it will use the weighted selection system, otherwise a simple "randi()" will be used to pick
# a row index
func get_random_row() -> Dictionary:
	var ret: Dictionary = {}
	
	if (_randweight.empty()):
		var index: int = randi() % _rowlist.size()
		ret = _rowlist[index]
	
	else:
		var total: float = _randweight.total
		var roll: float = rand_range(0.0, total)
		
		for ri in _rowlist.size():
			var acc: float = _accweight[ri]
			if (acc > roll):
				ret = _rowlist[ri]
				break
	
	return ret


# Remove a row from the table given its index
func remove_row_by_index(index: int) -> void:
	if (index < 0 || index >= _rowlist.size()):
		return
	
	var rinfo: Dictionary = _rowlist[index]
	
	_rowlist.remove(index)
	
	# warning-ignore:return_value_discarded
	_rindex.erase(rinfo.id)
	
	for ucol in _uindex:
		var vset: Dictionary = _uindex[ucol]
		var val = rinfo[ucol]
		# warning-ignore:return_value_discarded
		vset.erase(val)
	
	_calculate_weights()


# Reorder a row from its index into the given position
func move_row(from: int, to: int) -> bool:
	if (from == to):
		return false
	
	if (from < 0 || from >= _rowlist.size()):
		return false
	if (to < 0 || to >= _rowlist.size()):
		return false
	
	var rinfo: Dictionary = _rowlist[from]
	_rowlist.remove(from)
	_rowlist.insert(to, rinfo)
	
	_calculate_weights()
	
	return true


# Retrieve the ID of a row given its index
func get_row_id(index: int):
	if (_id_type == TYPE_INT):
		return get_row_int_id(index)
	elif (_id_type == TYPE_STRING):
		return get_row_str_id(index)
	
	return null


func get_row_int_id(index: int) -> int:
	assert(_id_type == TYPE_INT)
	if (index < 0 || index >= _rowlist.size()):
		return -1
	
	return _rowlist[index].id


func get_row_str_id(index: int) -> String:
	assert(_id_type == TYPE_STRING)
	if (index < 0 || index >= _rowlist.size()):
		return ""
	
	return _rowlist[index].id


# Change the ID of a row given its index
func set_id_by_index(rindex: int, newid) -> bool:
	assert(typeof(newid) == _id_type)
	
	if (rindex < 0 || rindex >= _rowlist.size()):
		return false
	
	var rinfo: Dictionary = _rowlist[rindex]
	if (rinfo.id == newid):
		return false
	
	if (_rindex.has(newid)):
		return false
	
	var oldid = rinfo.id
	
	# Create the entry within the index dictionary
	_rindex[newid] = rinfo
	
	# Remove the old one
	# warning-ignore:return_value_discarded
	_rindex.erase(oldid)
	
	# Update the row info
	rinfo.id = newid
	
	return true


# Set the value of a cell given its column and row indices.
# Returns true if the value was set
func set_value_by_index(col: int, row: int, val) -> bool:
	if (col < 0 || col >= _column_arr.size()):
		return false
	if (row < 0 || row >= _rowlist.size()):
		return false
	
	var cinfo: Dictionary = _column_arr[col]
	var ctitle: String = cinfo.name
	
	var rinfo: Dictionary = _rowlist[row]
	
	if (_require_unique_vals(cinfo)):
		var oval = rinfo[ctitle]
		if (oval != val):
			if (!_is_unique(cinfo, val)):
				return false
			
			# Update the unique indexing
			_unique_changed(cinfo, oval, val)
	
	rinfo[ctitle] = val
	
	if (_randweight.size() > 0 && _randweight.column == ctitle):
		_calculate_weights()
	
	return true


func sort_by_id(ascending: bool) -> void:
	var rsorter: _RowSorter = _RowSorter.new()
	_rowlist.sort_custom(rsorter, "ascid" if ascending else "descid")


func sort_by_column(cindex: int, ascending: bool) -> bool:
	if (cindex < 0 || cindex >= _column_arr.size()):
		return false
	
	var rsorter: _RowSorter = _RowSorter.new()
	rsorter.col = _column_arr[cindex].name
	
	if (_column_arr[cindex].value_type == ValueType.VT_Color):
		_rowlist.sort_custom(rsorter, "asccol" if ascending else "desccol")
	
	else:
		_rowlist.sort_custom(rsorter, "asc" if ascending else "desc")
	
	return true


# Retrieve the title of the column holding the random weights
func get_random_weight_column_title() -> String:
	return _randweight.get("column", "")


# Obtain the accumulated weight of the given row index. While this can be used, normally this is more
# usefull when debugging
# Return -1 if there is no random system set for this table or if the given row index is out of range
func get_row_acc_weight(row_index: int) -> float:
	if (row_index < 0 || row_index > _rowlist.size() || _randweight.size() == 0):
		return -1.0
	
	return _accweight[row_index]


# Given a row index, return the probability of it being randomly picked
# -1 if there is no random system set for this table or if the given row index is out of range
func get_row_probability(row_index: int) -> float:
	if (row_index < 0 || row_index > _rowlist.size() || _randweight.size() == 0):
		return -1.0
	
	var rtitle: String = _randweight.column
	var rw: float = _rowlist[row_index][rtitle]
	
	return rw / _randweight.total


# Obtain the total accumulated weight sum for this table (-1.0 if the system is not set for this table)
func get_total_weight_sum() -> float:
	return _randweight.get("total", -1.0)



# Obtain the list of tables referenced by this one
func get_reference_list() -> Array:
	return _reftable.keys()


# Returns true if this table references the given other table name
func is_referencing(other_table: String) -> bool:
	return _reftable.has(other_table)


# Returns the name of the table referenced by the given column name
func get_referenced_by_column(col_title: String) -> String:
	var cinfo: Dictionary = _column_index.get(col_title, {})
	
	if (cinfo.empty()):
		return ""
	
	return cinfo.get("extid", "")

# The database will call this when a referenced table has been renamed.
func referenced_table_renamed(from: String, to: String) -> void:
	# Remembering: the _reftable holds referenced table name as key and the referencing column name as value
	if (!_reftable.has(from)):
		return
	
	# Take the column name as the column must be updated too. Also, take advantege to "rename" the entry within _reftable
	var cname: String = _reftable[from]
	
	_reftable[to] = cname
	
	# warning-ignore:return_value_discarded
	_reftable.erase(from)
	
	# Update the column so it correctly points to the renamed table
	_column_index[cname].extid = to




# Clears the "referencer" list. Please do not call this as this is meant to be used by the database
func clear_referencer() -> void:
	_referencer.clear()

# Returns true if the given table name has a column pointing to this table
func is_referenced_by(tbname: String) -> bool:
	return _referencer.has(tbname)

# Adds a referencer to the list
func add_referencer(tbname: String) -> void:
	# Value is irrelevant as the Dictionary is being used as a set
	_referencer[tbname] = 0

# Removes a referencer (normally when the other table's column referencing this table has been removed)
func remove_referencer(tbname: String) -> void:
	# warning-ignore:return_value_discarded
	_referencer.erase(tbname)

# Get list of tables referencing this one
func get_referenced_by_list() -> Array:
	return _referencer.keys()


# Called whenever a row ID of a referenced table is changed.
func referenced_row_id_changed(other_table: String, from, to) -> void:
	# Column referencing the other table is stored within the _reftable dictionary, keyed by the other table's name
	var cname: String = _reftable[other_table]
	
	# Go through all rows and update the cell pointing to the changed ID
	for row in _rowlist:
		if (row[cname] == from):
			row[cname] = to


# Called whenever rows from a referenced table are removed
func referenced_rows_removed(other_table: String, idlist: Dictionary) -> void:
	# Column referencing the other table is stored within the _reftable dictionary, keyed by the other table's name
	var cname: String = _reftable[other_table]
	
	var cinfo: Dictionary = _column_index[cname]
	var blank_val = _get_default_val(cinfo)
	
	for row in _rowlist:
		var val = row[cname]
		
		if (idlist.has(val)):
			row[cname] = blank_val



#######################################################################################################################
### "Private" definitions
class _RowSorter:
	var col: String
	
	func ascid(a: Dictionary, b: Dictionary) -> bool:
		return a.id < b.id
	
	func descid(a: Dictionary, b: Dictionary) -> bool:
		return b.id < a.id
	
	func asc(a: Dictionary, b: Dictionary) -> bool:
		return a[col] < b[col]
	
	func desc(a: Dictionary, b: Dictionary) -> bool:
		return b[col] < a[col]
	
	# Specialized for color sorting - In this case, the priority for the sorting is: Hue, Saturation then Lightness
	func asccol(a: Dictionary, b: Dictionary) -> bool:
		var ca: Color = a[col]
		var cb: Color = b[col]
		
		#return (ca.h < cb.h || (ca.h == cb.h && ca.s < cb.s) || (ca.h == cb.h && ))
		if (ca.h < cb.h):
			return true
		
		elif (ca.h == cb.h):
			if (ca.s < cb.s):
				return true
			
			elif (ca.s == cb.s):
				if (ca.v < cb.v):
					return true
		
		return false
	
	func desccol(a: Dictionary, b: Dictionary) -> bool:
		var ca: Color = a[col]
		var cb: Color = b[col]
		
		if (cb.h < ca.h):
			return true
		
		elif (ca.h == cb.h):
			if (cb.s < ca.s):
				return true
			
			elif (ca.s == cb.s):
				if (cb.v < ca.v):
					return true
		
		return true



#######################################################################################################################
### "Private" properties
# How the table is identified
var _table_name: String = ""

# The list of columns on this table. Each entry is a Dictionary with the following format:
# - name: column name
# - value_type: type code of values stored within cells of this column
# - unique_values: if true then values within this column should not repeat
var _column_arr: Array = []

# This property will be built "on the fly", thus not saved/serialized within the Resource file
# Key = column name
# Value = same dictionary that is stored within _column_arr
var _column_index: Dictionary = {}

# This can be only TYPE_INT or TYPE_STRING. This should not be changed after being created
var _id_type: int = TYPE_INT setget _noset

# This will be dynamically generated. The key is the row id and will directly point to the same corresponding row
# entry Dictionary that is held within the _rowlist array.
var _rindex: Dictionary = {}


# Each entry is a Dictionary containing:
# - id: The ID of the row, which is either a String or an Integer
# - [column_name]: Corresponding value. There will be one for each column
var _rowlist: Array = []

# Columns meant to hold unique values will generate sets (well, dictionaries with irrelevant values within the key entries)
# to make things a lot easier to detect if a new valuei s indeed unique. This will result in faster checking when adding
# new entries or when editing the values at the expense of using more memory and increasing the loading time a little
# bit. The indexing will not be stored and will be dynamically restored 
# Nevertheless, this Dictionary holds the column name as key and the "set" as value of that entry.
var _uindex: Dictionary = {}


# Each time a column meant to reference another table is created, an entry in this Dictionary will be created. The key
# is the name of the referenced table. The value is the name of the column referencing the table
var _reftable: Dictionary = {}


# This will be dynamically filled by the owning database. After filled, this will hold the list of tables referencing
# this one. Much like _reftable this will work as a Set rather than map so the value is irrelevant.
var _referencer: Dictionary = {}

# This will be set when loading the table (dynamically) thus not saved. Nevertheless this is meant to hold data related
# to the random weight system. More specifically:
# - column: title of the column assigned to hold the weights
# - total: the total weight sum
# The dictionary will be empty if no column has been assigned for (automatic) random weights
var _randweight: Dictionary = {}

# The random picking system requires a weight accumulation per row. Instead of adding an extra field within each row
# (which would result in an extra float being stored within the persisted file), hold a separated array for that.
var _accweight: PoolRealArray


#######################################################################################################################
### "Private" functions
# There some locations that require testing if the given column requires unique values or not. In order to simplify the
# testing, all of those locations will call this function that should return true if the provided column info Dictionary
# is for a column value type is "unique". This will also help in case of any new unique type being added at a later
# moment (although this possibility is not likely to happen - but, at least the code is ready for that *if*...).
func _require_unique_vals(col: Dictionary) -> bool:
	var vt: int = col.value_type
	return (vt == ValueType.VT_UniqueString || vt == ValueType.VT_UniqueInteger)


# This is a function to help verify if the given value exists within the provided column info. This basically to work as
# a shortcut when testing if the desired value is/will be unique or not.
# This function will return true if the provided value does not exist on any row within the specified column
func _is_unique(col: Dictionary, value) -> bool:
	assert(_require_unique_vals(col))
	
	var vset: Dictionary = _uindex[col.name]
	
	return (!vset.has(value))


# Columns that require unique values should use this function to help with the upkeep of used values "Set"
func _set_used(col: Dictionary, value) -> void:
	assert(_require_unique_vals(col))
	var vset: Dictionary = _uindex[col.name]
	vset[value] = 1


# When a value is changed on a column that require unique values this function should be used in order to help
# with internal upkeep
func _unique_changed(col: Dictionary, from, to) -> void:
	assert(_require_unique_vals(col))
	assert(from != to)
	assert(_is_unique(col, to))
	
	var vset: Dictionary = _uindex[col.name]
	
	# warning-ignore:return_value_discarded
	vset.erase(from)
	vset[to] = 1


# This can be used to either set or remove the column meant for the automatic random weight system.
# Basically if the provided value is empty then it will be cleared, otherwise it will take the initial
# setup and set the total to the default (which matches the number of rows)
func _set_auto_weight(title: String, is_new: bool) -> void:
	if (title.empty()):
		_randweight.clear()
		_accweight.resize(0)
	
	else:
		if (!_randweight.empty() && is_new):
			return
		
		_randweight["column"] = title
		
		if (is_new):
			_randweight["total"] = float(_rowlist.size())
			
			_accweight.resize(_rowlist.size())
			
			var acc: float = 1.0
			for i in _rowlist.size():
				_accweight[i] = acc
				acc += 1.0



# This function should be called whenever a change occurs in a way that affects the random weight system
# Basically, reordering rows, new rows, chaging the weight of a cell and so on.
func _calculate_weights() -> void:
	if (_randweight.empty()):
		# Well, there is no random weight column in this table. Nothing to do here
		return
	
	var acc: float = 0.0
	var rcol: String = _randweight.column
	
	if (_accweight.size() != _rowlist.size()):
		_accweight.resize(_rowlist.size())
	
	for i in _rowlist.size():
		var w: float = _rowlist[i][rcol]
		acc += w
		
		_accweight[i] = acc
	
	_randweight.total = acc



# Create column indexing (Dictionary pointing into each column based on the title)
func _check_index() -> void:
	# This is meant to keep the column index pointing to the correct entries within the array
	_column_index.clear()
	for c in _column_arr:
		_column_index[c.name] = c
		
		if (c.value_type == ValueType.VT_RandomWeight):
			_set_auto_weight(c.name, true)


# Generate the internal upkeep related to columns requiring unique values
func _check_uindex() -> void:
	for c in _column_arr:
		if (!_require_unique_vals(c)):
			continue
		
		var ctitle: String = c.name
		var ui: Dictionary = {}
		_uindex[ctitle] = ui
		
		for r in _rowlist:
			# The value is irrelevant
			ui[r[ctitle]] = 1


# Create row indexing (row id to row data)
func _check_row_index() -> void:
	_rindex.clear()
	for rinfo in _rowlist:
		_rindex[rinfo.id] = rinfo


# Create a new valid (not used) integer ID
func _generate_int_id() -> int:
	var ret: int = randi()
	while (_rindex.has(ret)):
		ret = randi()
	
	return ret


# Create a new valid (not used) String ID
func _generate_str_id() -> String:
	var ret: String = "id_" + str(randi())
	while (_rindex.has(ret)):
		ret = "id_" + str(randi())
	
	return ret


# The return value is indeed meant to be a Variant, so not adding an explicit type here
# IMPORTANT: Do not allow a default value to be *null* as it will disrupt part of the internal system that
# relies on setting meta on each cell. However, if the value is null the meta is actually removed and it will
# cause errors
func _get_default_val(col: Dictionary):
	match col.value_type:
		ValueType.VT_UniqueInteger:
			# NOTE: *Not* using the "shortcut" function _is_unique() in here to avoid multiple lookups in the _uindex
			# dictionary, which *may* hit performance way more than necessary.
			# Just seek an available value by incrementing. A random number is probably more efficient when the amount
			# of rows is big.
			var ctitle: String = col.name
			var vset: Dictionary = _uindex.get(ctitle, {})
			if (vset.empty()):
				_uindex[ctitle] = vset
			
			var attempt: int = 0
			
			# NOTE: In here relying on the fact that row count will never reach the 32 bit integer limit.
			while (vset.has(attempt)):
				attempt += 1
			
			return attempt
		
		ValueType.VT_UniqueString:
			var ctitle: String = col.name
			var vset: Dictionary = _uindex.get(ctitle, {})
			if (vset.empty()):
				_uindex[ctitle] = vset
			
			var i: int = 0
			var attempt: String = "%s_%d" % [ctitle, i]
			
			while (vset.has(attempt)):
				i += 1
				attempt = "%s_%d" % [ctitle, i]
			
			return attempt
		
		
		ValueType.VT_ExternalString:
			return ""
		
		ValueType.VT_ExternalInteger:
			return -1
		
		ValueType.VT_RandomWeight:
			return 1.0
		
		
		ValueType.VT_String:
			return ""
		
		ValueType.VT_Bool:
			return false
		
		ValueType.VT_Integer:
			return 0
		
		ValueType.VT_Float:
			return 0.0
		
		ValueType.VT_Texture:
			# The texture is stored as a path to the file
			return ""
		
		ValueType.VT_Audio:
			# The audio is stored as a path to the resource file
			return ""
		
		ValueType.VT_GenericRes:
			# Generic resource is stored as a path to it
			return ""
		
		ValueType.VT_Color:
			return Color(0.0, 0.0, 0.0, 1.0)
	
	# Return empty string to avoid "storing null"
	return ""


func _convert_value_type(ctitle: String, to_type: int) -> void:
	# NOTE: in here not using any of the Unique* types because those are not meant to be changed after creation.
	
	for rinfo in _rowlist:
		var val = rinfo[ctitle]
		if (val == null):
			continue
		
		match to_type:
			ValueType.VT_String:
				if (!(val is String)):
					rinfo[ctitle] = str(val)
			
			ValueType.VT_Bool:
				var nval: bool = false
				
				if (val is bool):
					nval = val
				
				elif (val is String):
					val = val.to_lower()
					nval = true if (val == "true" || val == "yes" || val == "enabled") else false
				
				elif (val is int):
					nval = val > 0
				
				rinfo[ctitle] = nval
			
			ValueType.VT_Integer:
				var nval: int = 0
				
				if (val is int):
					nval = val
				
				elif (val is float):
					nval = int(val)
				
				elif (val is String):
					if (val.is_valid_integer()):
						nval = int(val)
					elif (val.is_valid_float()):
						nval = int(float(val))
				
				rinfo[ctitle] = nval
			
			ValueType.VT_Float:
				var nval: float = 0.0
				
				if (val is float):
					nval = val
				
				elif (val is int):
					nval = float(val)
				
				elif (val is String):
					if (val.is_valid_float()):
						nval = val.to_float()
					elif (val.is_valid_integer()):
						# Probably will never reach this, but just to ensure...
						nval = float(int(val))
				
				rinfo[ctitle] = nval
			
			ValueType.VT_Texture:
				if (val is String && val.is_abs_path()):
					# Nothing to do here as value is a String and a path. It may not be pointing to something correct, but still a path.
					pass
				
				else:
					rinfo[ctitle] = ""
			
			ValueType.VT_Audio:
				if (val is String && val.is_abs_path()):
					pass
				
				else:
					rinfo[ctitle] = ""
			
			ValueType.VT_GenericRes:
				if (val is String && val.is_abs_path()):
					pass
				
				else:
					rinfo[ctitle] = ""
			
			ValueType.VT_Color:
				if (val is String):
					rinfo[ctitle] = Color(val)
				else:
					rinfo[ctitle] = Color(0.0, 0.0, 0.0, 1.0)



# Obtain the dictionary containing information about tables referenced by this one (keys) as well as the column titles
# doing the reference. Please to not modify the returned dictionary because it may cause undesirable behavior.
func _get_reference_data() -> Dictionary:
	return _reftable


func _noset(_v) -> void:
	pass

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides

func _get_property_list() -> Array:
	return [
		{
			"name": "table_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		
		{
			"name": "id_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		
		{
			"name": "column",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		
		{
			"name": "ref_table",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		
		{
			"name": "rowlist",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE,
		},
	]


func _set(prop: String, val) -> bool:
	match prop:
		"table_name":
			_table_name = val
			return true
		
		"id_type":
			_id_type = val
			return true
		
		"column":
			_column_arr = val
			_check_index()
			return true
		
		"ref_table":
			_reftable = val
			return true
		
		"rowlist":
			_rowlist = val
			_check_uindex()
			_check_row_index()
			_calculate_weights()
			return true
	
	return false

func _get(prop: String):
	match prop:
		"table_name":
			return _table_name
		
		"id_type":
			return _id_type
		
		"column":
			return _column_arr
		
		"ref_table":
			return _reftable
		
		"rowlist":
			return _rowlist
	
	return null


func _init(idtype: int = TYPE_INT, tname: String = "") -> void:
	if (idtype != TYPE_INT && idtype != TYPE_STRING):
		idtype = TYPE_INT
	
	_id_type = idtype
	_table_name = tname


