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
extends MarginContainer


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# - Must verify if the provided asset script does have the "tool" keyword
func edit(asset: DataAsset) -> void:
	if (!asset):
		return
	
	_editing = asset
	_populate()
	
	if (!_rooteditor.is_connected("value_changed", self, "_on_value_changed")):
		# warning-ignore:return_value_discarded
		_rooteditor.connect("value_changed", self, "_on_value_changed")



#######################################################################################################################
### "Private" definitions
const PropEditorT: Script = preload("propeditors/ped_base.gd")

const ResEditorT: Script = preload("propeditors/ped_resource.gd")

const DAHelperT: Script = preload("dahelper.gd")

#######################################################################################################################
### "Private" properties
var _editing: DataAsset = null

onready var _rooteditor: ResEditorT = get_node_or_null("scroller/vbox/rootedt")


const _typeinfo: Dictionary = {
	TYPE_BOOL: preload("propeditors/ped_bool.gd"),
	TYPE_INT: preload("propeditors/ped_int.gd"),
	TYPE_REAL: preload("propeditors/ped_float.gd"),
	TYPE_STRING: preload("propeditors/ped_string.gd"),
	TYPE_VECTOR2: preload("propeditors/ped_vec2.gd"),
	TYPE_RECT2: preload("propeditors/ped_rect2.gd"),
	TYPE_VECTOR3: preload("propeditors/ped_vec3.gd"),
	# TYPE_TRANSFORM2D -> This can't be exported
	TYPE_PLANE: preload("propeditors/ped_plane.gd"),
	TYPE_QUAT: preload("propeditors/ped_quaternion.gd"),
	TYPE_AABB: preload("propeditors/ped_aabb.gd"),
	TYPE_BASIS: preload("propeditors/ped_basis.gd"),
	TYPE_TRANSFORM: preload("propeditors/ped_transform.gd"),
	TYPE_COLOR: preload("propeditors/ped_color.gd"),
	# TYPE_NODE_PATH -> I don't think node path makes sense outside of a scene
	# TYPE_RID -> There is no editor for RID
	# Directly exporting "Object" is not supported. However, exported "Resource" has its type as TYPE_OBJECT
	TYPE_OBJECT: ResEditorT,
	# TYPE_DICTIONARY -> Does it make sense to support Dictionaries? The entire goal of this plugin is to avoid using dictionaries!
	TYPE_ARRAY: preload("propeditors/ped_array.gd"),
	# Not supporting any of the Pool*Array. Reason for that is that dealing with them through GDScript is not exactly
	# as easy as with normal Arrays. More specifically moving the data around those. For reference, the types are bellow:
	# TYPE_RAW_ARRAY
	# TYPE_INT_ARRAY
	# TYPE_REAL_ARRAY
	# TYPE_STRING_ARRAY
	# TYPE_VECTOR2_ARRAY
	# TYPE_VECTOR3_ARRAY
	# TYPE_COLOR_ARRAY
	
	# Bellow some "custom" types - those are actually specialized editors for Integer or Strings
	DAHelperT.CTYPE_INT_ENUM: preload("propeditors/ped_intenum.gd"),
	DAHelperT.CTYPE_INT_FLAGS: preload("propeditors/ped_intflags.gd"),
	DAHelperT.CTYPE_STRING_ENUM: preload("propeditors/ped_stringenum.gd"),
	DAHelperT.CTYPE_STRING_DIR: preload("propeditors/ped_stringpath.gd"),
	DAHelperT.CTYPE_STRING_FILE: preload("propeditors/ped_stringpath.gd"),
}


#######################################################################################################################
### "Private" functions
func _populate() -> void:
	var settings: Dictionary = {
		"type": "res://addons/keh_dataasset/dasset.gd",
		"allow_base": false,
	}
	
	_rooteditor.clear(true)
	_rooteditor.setup("", _editing, settings, _typeinfo)
	_rooteditor.make_root()


#######################################################################################################################
### Event handlers
func _on_value_changed(_nval) -> void:
	# warning-ignore:return_value_discarded
	ResourceSaver.save(_editing.resource_path, _editing)


#######################################################################################################################
### Overrides
func _exit_tree() -> void:
	_rooteditor.clear(true)

