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

extends InventoryEvent
class_name InventoryEventSocket

# Socket mask
var mask: int
# Socket index within the item
# warning-ignore:unused_class_variable
var index: int
var owner_data: Dictionary

func _init(idata: Dictionary, cont: Control, sowner: Dictionary).(idata, cont) -> void:
	owner_data = sowner
	mask = 0xFFFFFFFF

func get_socket_owner_id() -> String:
	return owner_data.id

func get_socket_owner_type() -> int:
	return owner_data.type

func get_socket_owner_datacode() -> String:
	return owner_data.datacode



func get_socket_owner_icon_texture() -> Texture:
	var retval: Texture = null
	if (owner_data.icon is Texture):
		retval = owner_data.icon
	elif (owner_data.icon is String):
		retval = load(owner_data.icon)
	
	return retval

func get_socket_owner_icon_path() -> String:
	var retval: String = ""
	if (owner_data.icon is Texture):
		retval = owner_data.icon.resource_path
	elif (owner_data.icon is String):
		retval = owner_data.icon
	
	return retval


func get_socket_owner_background_texture() -> Texture:
	var retval: Texture = null
	if (owner_data.background is Texture):
		retval = owner_data.background
	elif (owner_data.backgruond is String && !owner_data.background.empty()):
		retval = load(owner_data.background)
	
	return retval

func get_socket_owner_background_path() -> String:
	var retval: String = ""
	if (owner_data.background is Texture && owner_data.background != null):
		retval = owner_data.background.resource_path
	elif (owner_data.background is String):
		retval = owner_data.background
	
	return retval

func get_socket_owner_column_span() -> int:
	return owner_data.column_span

func get_socket_owner_row_span() -> int:
	return owner_data.row_span


func get_socket_owner_linked_use() -> int:
	return owner_data.use_linked

# Yes, this would in theory mean that an item with sockets could also be socketed into another item....
func get_socket_owner_socket_mask() -> int:
	return owner_data.socket_mask


func get_socket_owner_material() -> Material:
	return owner_data.material

func get_socket_owner_socket_columns() -> int:
	return owner_data.socket_columns

