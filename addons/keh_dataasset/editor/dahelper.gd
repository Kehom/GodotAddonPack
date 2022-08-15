# Copyright (c) 2022 Yuri Sarudiansky
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
extends Reference

# This script is intended to work as a "library", containing constants and static functions. The editor scripts will
# use this to help build the UI

#######################################################################################################################
### Signals and definitions
const CTYPE_INT_ENUM:    int = 10000
const CTYPE_INT_FLAGS:   int = 10001
const CTYPE_STRING_ENUM: int = 10002
const CTYPE_STRING_FILE: int = 10003
const CTYPE_STRING_DIR:  int = 10004


# This is mostly to help output UI information
const typestrings: Dictionary = {
	TYPE_BOOL: {
		"type_string": "TYPE_BOOL",
		"type_name": "Boolean",
	},
	
	TYPE_INT: {
		"type_string": "TYPE_INT",
		"type_name": "Integer",
	},
	
	TYPE_REAL: {
		"type_string": "TYPE_REAL",
		"type_name": "Float",
	},
	
	TYPE_STRING: {
		"type_string": "TYPE_STRING",
		"type_name": "String",
	},
	
	TYPE_VECTOR2: {
		"type_string": "TYPE_VECTOR2",
		"type_name": "Vector2",
	},
	
	TYPE_RECT2: {
		"type_string": "TYPE_RECT2",
		"type_name": "Rect2",
	},
	
	TYPE_VECTOR3: {
		"type_string": "TYPE_VECTOR3",
		"type_name": "Vector3",
	},
	
	TYPE_TRANSFORM2D: {
		"type_string": "TYPE_TRANSFORM2D",
		"type_name": "Transform2D"
	},
	
	TYPE_PLANE: {
		"type_string": "TYPE_PLANE",
		"type_name": "Plane",
	},
	
	TYPE_QUAT: {
		"type_string": "TYPE_QUAT",
		"type_name": "Quaternion",
	},
	
	TYPE_AABB: {
		"type_string": "TYPE_AABB",
		"type_name": "Axis-Aligned Bounding Box",
	},
	
	TYPE_BASIS: {
		"type_string": "TYPE_BASIS",
		"type_name": "Basis",
	},
	
	TYPE_TRANSFORM: {
		"type_string": "TYPE_TRANSFORM",
		"type_name": "Transform",
	},
	
	TYPE_COLOR: {
		"type_string": "TYPE_COLOR",
		"type_name": "Color",
	},
	
	TYPE_NODE_PATH: {
		"type_string": "TYPE_NODE_PATH",
		"type_name": "NodePath"
	},
	
	TYPE_RID: {
		"type_string": "TYPE_RID",
		"type_name": "RID"
	},
	
	# While directly exporting as Object is not supported, marking the exported type as a resource makes its type to
	# be TYPE_OBJECT.
	TYPE_OBJECT: {
		"type_string": "TYPE_OBJECT",
		"type_name": "Resource",
	},
	
	TYPE_DICTIONARY: {
		"type_string": "TYPE_DICTIONARY",
		"type_name": "Dictionary",
	},
	
	TYPE_ARRAY: {
		"type_string": "TYPE_ARRAY",
		"type_name": "Array"
	},
	
	TYPE_RAW_ARRAY: {
		"type_string": "TYPE_RAW_ARRAY",
		"type_name": "PoolByteArray",
	},
	
	TYPE_INT_ARRAY: {
		"type_string": "TYPE_INT_ARRAY",
		"type_name": "PoolIntArray",
	},
	
	TYPE_REAL_ARRAY: {
		"type_string": "TYPE_REAL_ARRAY",
		"type_name": "PoolRealArray",
	},
	
	TYPE_STRING_ARRAY: {
		"type_string": "TYPE_STRING_ARRAY",
		"type_name": "PoolStringArray"
	},
	
	TYPE_VECTOR2_ARRAY: {
		"type_string": "TYPE_VECTOR2_ARRAY",
		"type_name": "PoolVector2Array",
	},
	
	TYPE_VECTOR3_ARRAY: {
		"type_string": "TYPE_VECTOR3_ARRAY",
		"type_name": "PoolVector3Array",
	},
	
	TYPE_COLOR_ARRAY: {
		"type_string": "TYPE_COLOR_ARRAY",
		"type_name": "PoolColorArray",
	}
	
	# Then there are some "specialized custom types". Integers can be used as flags, for example. So, there are a few
	# extra editors meant to deal with those special cases.
	
}

# Associate type with its default value. Only for non resource core types
const default_value: Dictionary = {
	TYPE_BOOL: false,
	TYPE_INT: int(0),
	TYPE_REAL: 0.0,
	TYPE_STRING: "",
	TYPE_VECTOR2: Vector2(),
	TYPE_RECT2: Rect2(),
	TYPE_VECTOR3: Vector3(),
	TYPE_PLANE: Plane(),
	TYPE_QUAT: Quat(),
	TYPE_AABB: AABB(),
	TYPE_BASIS: Basis(),
	TYPE_TRANSFORM: Transform(),
	TYPE_COLOR: Color(),
	TYPE_ARRAY: [],
}


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
static func is_script_derived_from(script: Script, base: Script) -> bool:
	var b: Script = script.get_base_script()
	while (b):
		if (b == base):
			return true
		
		b = b.get_base_script()
	
	return false


static func fill_core_class_popup(restype: String, pop: PopupMenu) -> void:
	if (ClassDB.can_instance(restype)):
		pop.add_item(restype)
	
	var dlist: Array = ClassDB.get_inheriters_from_class(restype)
	for d in dlist:
		if (ClassDB.can_instance(d)):
			pop.add_item(d)
	
	# Now take scripted classes that derive from 'restype' and fill the popup with those
	# Each of those entries will have additional meta data (holding the path to the script)
	var clist: Array = ProjectSettings.get_setting("_global_script_classes") if ProjectSettings.has_setting("_global_script_classes") else []
	for c in clist:
		if (c.base == restype):
			var nindex: int = pop.get_item_count()
			
			pop.add_item("%s (%s)" % [c.class, c.path.get_file()])
			pop.set_item_metadata(nindex, c.path)


static func fill_scripted_class_popup(base: Script, include_base: bool, pop: PopupMenu) -> void:
	var clist: Array = ProjectSettings.get_setting("_global_script_classes") if ProjectSettings.has_setting("_global_script_classes") else []
	for c in clist:
		var script: GDScript = load(c.path)
		
		if ((base == script && include_base) || is_script_derived_from(script, base)):
			var nindex: int = pop.get_item_count()
			
			pop.add_item("%s (%s)" % [c.class, c.path.get_file()])
			pop.set_item_metadata(nindex, c.path)


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
