###############################################################################
# Copyright (c) 2020 Yuri Sarudiansky
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
###############################################################################

extends Reference
class_name InventoryEvent

# Contains item data related to the main item related to this event
var item_data: Dictionary
# Container that triggered this event
var container: Control

func _init(idata: Dictionary, cont: Control) -> void:
	item_data = idata
	container = cont


### A bunch of functions to access item data from the item_data dictionary. Mostly to help know what is there

func get_item_id() -> String:
	return item_data.id

func get_item_type() -> int:
	return item_data.type

func get_item_datacode() -> String:
	return item_data.datacode

# NOTE: Depending on the setting, the "icon" may be a string (resource path) or a texture (the actual resource)
# Because of that, providing two different functions to obtain the desired data
func get_item_icon_texture() -> Texture:
	var retval: Texture = null
	if (item_data.icon is Texture):
		retval = item_data.icon
	elif (item_data.icon is String):
		retval = load(item_data.icon)
	
	return retval

func get_item_icon_path() -> String:
	var retval: String = ""
	if (item_data.icon is Texture):
		retval = item_data.icon.resource_path
	elif (item_data.icon is String):
		retval = item_data.icon
	
	return retval


# NOTE: Depending on the setting, the "background" may be a string (resource path) or a texture (the actual resource)
# Because of that, providing two different functions to obtain the desired data
func get_item_background_texture() -> Texture:
	if (item_data.empty()):
		return null
	
	var retval: Texture = null
	if (item_data.background is Texture):
		retval = item_data.background
	elif (item_data.background is String && !item_data.background.empty()):
		retval = load(item_data.background)
	return retval

func get_item_background_path() -> String:
	if (item_data.empty()):
		return ""
	
	var retval: String = ""
	if (item_data.background is Texture && item_data.background != null):
		retval = item_data.background.resource_path
	elif (item_data.backgroudn is String):
		retval = item_data.background
	
	return retval

func get_item_column_span() -> int:
	return item_data.get("column_span", 0)

func get_item_row_span() -> int:
	return item_data.get("row_span", 0)

func get_item_stack() -> int:
	return item_data.get("stack", 0)

func get_item_max_stack() -> int:
	return item_data.get("max_stack", 0)


func get_item_linked_use() -> int:
	return item_data.get("use_linked", 0)

func get_item_socket_mask() -> int:
	return item_data.get("socket_mask", 0)


func get_item_material() -> Material:
	return item_data.get("material", null)


func get_item_socket_columns() -> int:
	return item_data.get("socket_columns", 0)

# TODO: function to obtain socket data



func get_column() -> int:
	return item_data.get("column", 0)

func get_row() -> int:
	return item_data.get("row", 0)
