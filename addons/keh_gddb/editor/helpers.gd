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

extends Reference
class_name DBHelpers


# Remove (and mark for freeing) all children nodes from the given node.
static func clear_children(from_node: Node) -> void:
	if (!from_node):
		return
	
	for child in from_node.get_children():
		# First remove the node itself so the nodes are not accessible when iterating right after calling this function
		from_node.remove_child(child)
		
		# Then mark the node to be deleted
		child.queue_free()



# The Resource class contains a function to check if it's a resource file or ebedded. Unfortunately it's not exposed to
# scripting! Luckily the implementation is simple enough to be done through script. This function is for that
static func is_resource_file(res: Resource) -> bool:
	return (res.resource_path.begins_with("res://") && res.resource_path.find("::") == -1)



# Very rarely the return value of the connect() function is used, which results in warnings being given. This function
# is used to help with the connecting without having to add the warning ignore mark at every connect() call
static func connector(obj: Object, event: String, handling_obj: Object, handling_func: String, payload: Array = []) -> void:
	# warning-ignore:return_value_discarded
	obj.connect(event, handling_obj, handling_func, payload)


# Generate a Dictionary with the list of column value types that are allowed to be changed. In other words, this will
# be used within the context menu when right clicking columns in the TabularBox
static func generate_ui_non_unique_types() -> Dictionary:
	return {
		DBTable.ValueType.VT_String: "String",
		DBTable.ValueType.VT_Bool: "Bool",
		DBTable.ValueType.VT_Integer: "Integer",
		DBTable.ValueType.VT_Float: "Float",
		DBTable.ValueType.VT_Texture: "Texture",
		DBTable.ValueType.VT_Audio: "Audio",
		DBTable.ValueType.VT_Color: "Color",
	}

# Generate a Dictionary with all available column value types. This is meant to be shown within the "new column" dialog.
static func generate_ui_types() -> Dictionary:
	return {
		DBTable.ValueType.VT_UniqueString: "Unique String",
		DBTable.ValueType.VT_UniqueInteger: "Unique Integer",
		
		DBTable.ValueType.VT_ExternalString: "External String ID",
		DBTable.ValueType.VT_ExternalInteger: "External Integer ID",
		
		DBTable.ValueType.VT_RandomWeight: "Random Weight",
		
		DBTable.ValueType.VT_String: "String",
		DBTable.ValueType.VT_Bool: "Bool",
		DBTable.ValueType.VT_Integer: "Integer",
		DBTable.ValueType.VT_Float: "Float",
		DBTable.ValueType.VT_Texture: "Texture",
		DBTable.ValueType.VT_Audio: "Audio",
		DBTable.ValueType.VT_GenericRes: "Generic Resource",
		DBTable.ValueType.VT_Color: "Color",
	}
