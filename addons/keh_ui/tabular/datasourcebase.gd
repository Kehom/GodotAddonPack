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
class_name TabularDataSourceBase


#######################################################################################################################
### Signals and definitions
signal column_inserted(at_index)
signal column_removed(index)
signal column_moved(from, to)
signal column_renamed(index)
signal column_rename_rejected(index)

signal row_inserted(at_index)
signal row_removed(index)
signal row_moved(from, to)

signal value_changed(col, row, newvalue)
signal value_change_rejected(col, row)

signal type_changed(col)

signal data_sorting_changed()


const ColumnBaseT: Script = preload("columnbase.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
### Functions that must be implemented in derived classes
# This must return a Dictionary containing the list of available value types. The format should be:
# key = integer, value type code
# value = string, which will be used to identify this type within the UI.
# Note that the associated column class is not part of this Dictionary, mostly because it is retrieved at a different
# stage, through the get_column_info() function.
func get_type_list() -> Dictionary:
	return {}

func has_column(_title: String) -> bool:
	return false

# This must return the number of columns within this data object
func get_column_count() -> int:
	return 0

# Given the column index this function must return a Dictionary containing information related to the column.
# With the exception of "title", entries are optional and if not provided will default to the value shown bellow:
# - title: String -> must match the title of the column
# - type_code: int -> internal custom value type code. Will default to 0 if not given
# - column_class: Script -> must specify which TabularColumn* will be used when instancing a column. Defaults to TabularColumnString
# - flags: int -> flag settings based on the enum TabularColumnBase.FlagSettings. Will default to FlagSettings._Default
func get_column_info(_index: int) -> Dictionary:
	return {}


# The TabularBox expects this function to be able to deal with default values. In that case, title will be empty,
# type will be set to -1.
# Also, when index is -1 it assumes the new column is meant to be appended into the list
# The extra Dictionary can be used to provide extra settings if the custom data source requires it.
func insert_column(_title: String, _type: int, _index: int, _extra: Dictionary = {}) -> void:
	pass


func remove_column(_index: int) -> void:
	pass


# Whenever a column instance (of class derived from columnbase.gd) is created, this function will be called. The idea is that
# some columns might require additional setup and/or data after creation.
func column_ui_created(_col: ColumnBaseT) -> void:
	pass


func rename_column(_cindex: int, _to_title: String) -> void:
	pass


func change_column_value_type(_cindex: int, _to_type: int) -> void:
	pass


func move_column(_from: int, _to: int) -> void:
	pass


func get_row_count() -> int:
	return 0

func insert_row(_values: Dictionary, _index: int) -> void:
	pass

func remove_row(_index: int) -> void:
	pass


func move_row(_from: int, _to: int) -> void:
	pass



# The TabularBox doesn't exactly use this but the base function is given mostly for practical use. The recommended here
# is that the returned dictionary contains the column titles as key with their respective values for the given row index.
func get_row(_index: int) -> Dictionary:
	return {}

# Because the stored value can be of any type, relying on Variant return (thus, no static type here)
func get_value(_col_index: int, _row_index: int):
	return ""

# Relying on the variant to deal with the value to be stored, so no static typing here.
func set_value(col_index: int, row_index: int, _val) -> void:
	_notify_value_change_rejected(col_index, row_index)


func sort_by_col(_col_index: int, _ascending: bool) -> void:
	pass


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions
func _notify_new_column(index: int) -> void:
	emit_signal("column_inserted", index)

func _notify_column_removed(index: int) -> void:
	emit_signal("column_removed", index)

func _notify_column_moved(from: int, to: int) -> void:
	emit_signal("column_moved", from, to)


func _notify_column_renamed(index: int) -> void:
	emit_signal("column_renamed", index)

func _notify_column_rename_rejected(index: int) -> void:
	emit_signal("column_rename_rejected", index)



func _notify_new_row(index: int) -> void:
	emit_signal("row_inserted", index)

func _notify_row_removed(index: int) -> void:
	emit_signal("row_removed", index)

func _notify_row_moved(from: int, to: int) -> void:
	emit_signal("row_moved", from, to)


func _notify_value_changed(cindex: int, rindex: int, nval) -> void:
	emit_signal("value_changed", cindex, rindex, nval)


func _notify_value_change_rejected(cindex: int, rindex: int) -> void:
	emit_signal("value_change_rejected", cindex, rindex)


func _notify_type_changed(cindex: int) -> void:
	emit_signal("type_changed", cindex)


func _notify_sorted() -> void:
	emit_signal("data_sorting_changed")

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
