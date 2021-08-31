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
extends TabularDataSourceBase
class_name TabularSimpleDataSource


#######################################################################################################################
### Signals and definitions
enum ValueType {
	VT_String,
	VT_Bool,
	VT_Integer,
	VT_Float,
	VT_Texture,
}

const CStringT: Script = preload("default_columns/columnstring.gd")
const CBoolT: Script = preload("default_columns/columnbool.gd")
const CIntT: Script = preload("default_columns/columnint.gd")
const CFloatT: Script = preload("default_columns/columnfloat.gd")
const CTextureT: Script = preload("default_columns/columntexture.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func get_free_column_title() -> String:
	var base: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	
	# Attempt to find a title 100 times
	for it in 100:
		for ib in base.length():
			var attempt: String = "%s%s" % [base[ib], str(it) if it > 0 else ""]
			if (!has_column(attempt)):
				return attempt
	
	return ""


func get_default_value_for_type(tp: int):
	match tp:
		ValueType.VT_String:
			return ""
		
		ValueType.VT_Bool:
			return false
		
		ValueType.VT_Integer:
			return 0
		
		ValueType.VT_Float:
			return 0.0
		
		ValueType.VT_Texture:
			return ""
	
	return null

func get_class_for_type(tp: int) -> Script:
	match tp:
		ValueType.VT_String:
			return CStringT
		ValueType.VT_Bool:
			return CBoolT
		ValueType.VT_Integer:
			return CIntT
		ValueType.VT_Float:
			return CFloatT
		ValueType.VT_Texture:
			return CTextureT
	
	return null

#######################################################################################################################
### "Private" definitions
class _RowSorter:
	var col: String
	
	func ascending(a: Dictionary, b: Dictionary) -> bool:
		return a[col] < b[col]
	
	func descending(a: Dictionary, b: Dictionary) -> bool:
		return b[col] < a[col]



#######################################################################################################################
### "Private" properties
var _column_list: Array = []
var _column_index: Dictionary = {}

# Each entry is a dictionary that contains the column title as key
var _row_list: Array = []

#######################################################################################################################
### "Private" functions
func _check_indices() -> void:
	_column_index.clear()
	for ci in _column_list.size():
		var col: Dictionary = _column_list[ci]
		_column_index[col.title] = col


#######################################################################################################################
### Overrides
func get_type_list() -> Dictionary:
	return {
		ValueType.VT_String: "String",
		ValueType.VT_Bool: "Bool",
		ValueType.VT_Integer: "Integer",
		ValueType.VT_Float: "Float",
		ValueType.VT_Texture: "Texture",
	}

func has_column(title: String) -> bool:
	return _column_index.has(title)


func get_column_count() -> int:
	return _column_list.size()


func get_column_info(index: int) -> Dictionary:
	assert(index >= 0 && index < _column_list.size())
	
	var cinfo: Dictionary = _column_list[index]
	
	return {
		"title": cinfo.title,
		"type_code": cinfo.type,
		"column_class": get_class_for_type(cinfo.type)
	}



func insert_column(title: String, type: int, index: int, _extra: Dictionary = {}) -> void:
	if (title.empty()):
		title = get_free_column_title()
		if (title.empty()):
			return
	
	else:
		if (has_column(title)):
			return
	
	if (type < 0):
		type = ValueType.VT_String
	
	if (index < 0 || index > _column_list.size()):
		# If the index is outside of the boundaries, set the value to be the last one, which will
		# effectively append the new column into the data
		index = _column_list.size()
	
	var ncol: Dictionary = {
		"title": title,
		"type": type,
	}
	
	
	if (index < _column_list.size()):
		_column_list.insert(index, ncol)
	
	else:
		_column_list.append(ncol)
	
	# Must add the cells of each row for this new column
	for ri in _row_list.size():
		var row: Dictionary = _row_list[ri]
		row[title] = get_default_value_for_type(type)
	
	_check_indices()
	_notify_new_column(index)


func remove_column(index: int) -> void:
	assert(index >= 0 && index < _column_list.size())
	
	var cinfo: Dictionary = _column_list[index]
	# warning-ignore:return_value_discarded
	_column_index.erase(cinfo.title)
	_column_list.remove(index)
	
	for ri in _row_list.size():
		var r: Dictionary = _row_list[ri]
		# warning-ignore:return_value_discarded
		r.erase(cinfo.title)
	
	_notify_column_removed(index)


func rename_column(cindex: int, to_title: String) -> void:
	if (cindex < 0 || cindex >= _column_list.size()):
		return
	
	var centry: Dictionary = _column_list[cindex]
	var otitle: String = centry.title
	centry.title = to_title
	
	# Update the index. First by adding the entry with the new title
	_column_index[to_title] = centry
	
	# Then removing the entry with the old title
	# warning-ignore:return_value_discarded
	_column_index.erase(otitle)
	
	# Row must be update too
	for ri in _row_list.size():
		var row: Dictionary = _row_list[ri]
		
		# Retrieve the value - no static typing here because it is meant to be variant
		var row_val = row.get(otitle)
		
		# Create the entry with the new title
		row[to_title] = row_val
		
		# And remove the entry with the old title
		# warning-ignore:return_value_discarded
		row.erase(otitle)


func change_column_value_type(cindex: int, to_type: int) -> void:
	if (cindex < 0 || cindex >= _column_list.size()):
		return
	
	var centry: Dictionary = _column_list[cindex]
	if (centry.type == to_type):
		return
	
	if (!get_class_for_type(to_type)):
		return
	
	var title: String = centry.title
	centry.type = to_type
	
	# Go through each row converting the value type of the column
	for row in _row_list:
		var val = row[title]
		
		match to_type:
			ValueType.VT_String:
				if (!(val is String)):
					row[title] = str(val)
			
			ValueType.VT_Bool:
				if (val is bool):
					# Do nothing as the value is already boolean - although, it should not be here.
					pass
				elif (val is String):
					val = val.to_lower()
					row[title] = true if (val == "true" || val == "yes" || val == "enabled") else false
				elif (val is int):
					row[title] = val > 0
				else:
					row[title] = false
			
			ValueType.VT_Integer:
				if (val is int):
					# Do nothing as the value is already integer - although, it should not be here
					pass
				elif (val is float):
					row[title] = int(val)
				elif (val is String):
					if (val.is_valid_integer()):
						row[title] = int(val)
					elif (val.is_valid_float()):
						row[title] = int(float(val))
					else:
						row[title] = 0
				elif (val is bool):
					row[title] = 1 if val == true else 0
				else:
					row[title] = 0
			
			ValueType.VT_Float:
				if (val is float):
					# Do nothing as the value is already integer - although it should not be here.
					pass
				elif (val is int):
					row[title] = float(val)
				elif (val is String):
					if (val.is_valid_float()):
						row[title] = val.to_float()
					elif (val.is_valid_integer()):
						# Probably never reaching here - but, just to ensure...
						row[title] = float(int(val))
					else:
						row[title] = 0.0
				else:
					row[title] = 0.0
			
			ValueType.VT_Texture:
				if (val is String && val.is_abs_path()):
					# Do nothing as the value is a String and a path. It may not point to something correct, but still is a path
					pass
				
				else:
					row[title] = ""
	
	_notify_type_changed(cindex)


func move_column(from: int, to: int) -> void:
	if (from == to):
		return
	
	if (from < 0 || from >= _column_list.size()):
		return
	if (to < 0 || to >= _column_list.size()):
		return
	
	var centry: Dictionary = _column_list[from]
	_column_list.remove(from)
	
	if (to == _column_list.size()):
		# Because the "from" was temporarily removed from the list it is possible the "to" is pointing past the
		# array size. In this case just append the column back
		_column_list.append(centry)
	else:
		# Otherwise just insert the column back into the desired index
		_column_list.insert(to, centry)
	
	# There is no need to update indexing because those deal with column title pointing to the dictionary (which remains unchanged)
	
	_notify_column_moved(from, to)



func get_row_count() -> int:
	return _row_list.size()


func insert_row(values: Dictionary, index: int) -> void:
	if (index < 0 || index > _row_list.size()):
		index = _row_list.size()
	
	var nrow: Dictionary = {}
	
	for ci in _column_list.size():
		var ct: String = _column_list[ci].title
		
		var val = values.get(ct)
		if (!val):
			val = get_default_value_for_type(_column_list[ci].type)
		
		nrow[ct] = val
	
	
	if (index < _row_list.size()):
		_row_list.insert(index, nrow)
	else:
		_row_list.append(nrow)
	
	_notify_new_row(index)


func remove_row(index: int) -> void:
	if (index < 0 || index >= _row_list.size()):
		return
	
	_row_list.remove(index)
	_notify_row_removed(index)


func move_row(from: int, to: int) -> void:
	if (from == to):
		return
	
	if (from < 0 || from >= _row_list.size()):
		return
	if (to < 0 || to >= _row_list.size()):
		return
	
	var row: Dictionary = _row_list[from]
	_row_list.remove(from)
	_row_list.insert(to, row)
	
	_notify_row_moved(from, to)


func get_row(index: int) -> Dictionary:
	if (index < 0 || index >= _row_list.size()):
		return {}
	
	return _row_list[index]


# Because the stored value can be of any type, relying on Variant return (thus, no static type here)
func get_value(col_index: int, row_index: int):
	if (col_index < 0 || col_index >= _column_index.size()):
		return ""
	if (row_index < 0 || row_index >= _row_list.size()):
		return ""
	
	var cinfo: Dictionary = _column_list[col_index]
	return _row_list[row_index].get(cinfo.title, "")


# Relying on the variant to deal with the value to be stored, so no static typing here.
func set_value(col_index: int, row_index: int, val) -> void:
	if (col_index < 0 || col_index >= _column_index.size()):
		return
	if (row_index < 0 || row_index >= _row_list.size()):
		return
	
	var title: String = _column_list[col_index].title
	_row_list[row_index][title] = val
	
	_notify_value_changed(col_index, row_index, val)


func sort_by_col(col_index: int, ascending: bool) -> void:
	if (col_index < 0 || col_index >= _column_list.size()):
		return
	
	var rsorter: _RowSorter = _RowSorter.new()
	rsorter.col = _column_list[col_index].title
	
	_row_list.sort_custom(rsorter, "ascending" if ascending else "descending")
	
	_notify_sorted()



# _column_list and _row_list are meant to be serialized but not exposed to the Inspector.
# So, using _get_property_list() + _get() + _set()
func _get_property_list() -> Array:
	var ret: Array = []
	
	ret.append({
		"name": "column_list",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_STORAGE,
	})
	
	ret.append({
		"name": "row_list",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_STORAGE,
	})
	
	return ret

func _set(prop: String, val) -> bool:
	var ret: bool = false
	match prop:
		"column_list":
			_column_list = val
			_check_indices()
			ret = true
		
		"row_list":
			_row_list = val
			ret = true
	
	return ret

func _get(prop: String):
	match prop:
		"column_list":
			return _column_list
		"row_list":
			return _row_list
	
	return null

