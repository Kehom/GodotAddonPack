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
extends "res://addons/keh_dataasset/editor/propeditors/ped_base.gd"


#######################################################################################################################
### Signals and definitions
const DAHelperT: Script = preload("../dahelper.gd")

const SpecializedResEd: Dictionary = {
	"Texture": preload("reseditors/red_texture.gd")
}



#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func make_root() -> void:
	_left.visible = false
	lock_instance()


func clear(include_red: bool) -> void:
	while (_pedbox.get_child_count() > 0):
		var c: Node = _pedbox.get_child(0)
		_pedbox.remove_child(c)
		c.free()
	
	if (include_red && _red != null):
		_slot.remove_child(_red)
		_red.free()
		_red = null


func lock_instance() -> void:
	if (_red):
		_red.lock_instance()

#######################################################################################################################
### "Private" definitions
const STR_INVALID_PROPERTY: String = """This property is marked as a resource but its exact type is not specified.
	Within the return value of the 'get_property_info()' add a Dictionary entry keyed by this property name containing a 'type' field.
	The value of this field should be a String with either the name of the resource or a path ('res://...') to the script implementing it."""

const _GENERIC_RED: Script = preload("reseditors/red_generic.gd")

const _DASSET_T: Script = preload("res://addons/keh_dataasset/dasset.gd")

# The "Resource.get_property_list()" will return 4 builtin properties that are irrelevant for this plugin. Place the
# names of those properties within this dictionary, which will be used as a Set. When iterating the properties, check
# if the name is within this container and, if so, skip the property.
const _IgnoreProperty: Dictionary = {
	"resource_local_to_scene": 1,
	"resource_path": 1,
	"resource_name": 1,
	"script": 1,
}

#######################################################################################################################
### "Private" properties
var _value: Resource = null

var _lblerr: Label = Label.new()

# The resource instance editor will go into this slot
var _slot: PanelContainer = PanelContainer.new()

# And this is the resource instance editor
var _red: _GENERIC_RED = null

# Property editors will come here
var _pedbox: VBoxContainer = VBoxContainer.new()


# Must hold the typeinfo so when building the property editor objects after setting the value, those editors can
# receive the typeinfo data
var _typeinfo: Dictionary = {}

# Hold the the expected resource type class name in here. If not a core resource type, the path to the script
var _restype: String = ""

# If the expected resource type is a scripted one, this property will cache the loaded script
var _scripted_type: Script = null

# If this is false then don't allow directly creating instances of the _restype, but only derived classes
var _allow_base: bool = true

#######################################################################################################################
### "Private" functions
# Property hints of interest:
# - PROPERTY_HINT_ENUM -> this comes when type = TYPE_INT or TYPE_STRING. Hint string contains comma separated entries
# - PROPERTY_HINT_FLAGS -> this comes when type = TYPE_INT. Hint string contains names of bit flags
# - PROPERTY_HINT_FILE -> this comes when type = TYPE_STRING. Hint string indicates extension wildcards
# - PROPERTY_HINT_DIR -> this comes when type = TYPE_STRING
func _get_property_type(t: int, hint: int) -> int:
	if (t == TYPE_INT):
		match hint:
			PROPERTY_HINT_ENUM:
				return DAHelperT.CTYPE_INT_ENUM
			
			PROPERTY_HINT_FLAGS:
				return DAHelperT.CTYPE_INT_FLAGS
	
	elif (t == TYPE_STRING):
		match hint:
			PROPERTY_HINT_FILE:
				return DAHelperT.CTYPE_STRING_FILE
			
			PROPERTY_HINT_DIR:
				return DAHelperT.CTYPE_STRING_DIR
			
			PROPERTY_HINT_ENUM:
				return DAHelperT.CTYPE_STRING_ENUM
	
	
	return t


# Because there is no easy way to obtain the information of the default values of each property of a resource, the
# strategy used here is based on creating a dummy instance of that resource type. Since it's a new instance the
# properties should be in their default values. So, basically, those are extracted from this dummy instance.
func _iterate_properties(res: Resource, proplist: Array, settings: Dictionary, dummy: Resource) -> void:
	for p in proplist:
		if (_IgnoreProperty.has(p.name)):
			# This property is of no interest for this plugin
			continue
		
		if (p.usage & PROPERTY_USAGE_EDITOR):
			var ptype: int = _get_property_type(p.type, p.hint)
			
			var ped_t: GDScript = _typeinfo.get(ptype, null)
			
			if (!ped_t):
				# This property does not have an editor - that is, not supported by this plugin
				continue
			
			# Get settings, if any, specific for this property
			var psettings: Dictionary = settings.get(p.name, {})
			
			if (p.type == TYPE_OBJECT):
				if (!psettings.has("type")):
					psettings["type"] = p["class_name"]
			
			if (ptype > TYPE_MAX):
				psettings["hint_string"] = p.get("hint_string", "")
				psettings["type"] = ptype
			
			psettings["__revert_to__"] = dummy.get(p.name)
			
			
			var ped: Control = ped_t.new()
			ped.call("setup", p.name, res.get(p.name), psettings, _typeinfo)
			_pedbox.add_child(ped)
			
			# warning-ignore:return_value_discarded
			ped.connect("value_changed", self, "_on_property_changed", [p.name])


func _get_instance_editor_for_core(restype: String) -> GDScript:
	var red: GDScript = SpecializedResEd.get(restype, null)
	if (red):
		return red
	
	var parent: String = ClassDB.get_parent_class(restype)
	while (!parent.empty()):
		red = SpecializedResEd.get(parent, null)
		if (red):
			return red
		
		parent = ClassDB.get_parent_class(parent)
	
	
	return _GENERIC_RED


# Separating this check without changing any internal control (error message and visibilities) mostly so it can be used
# by the drag and drop system without messing with anything that might already been set
func _is_scripted_resource_allowed(script: Script) -> bool:
	if (script == _scripted_type):
		return _allow_base
	
	# If here then incoming script is not exactly the "base" (as in _restype). Must check if it's at least derived from
	var b: Script = script.get_base_script()
	while (b):
		if (b == _scripted_type):
			return true
		
		b = b.get_base_script()
	
	return false


func _is_resource_allowed(res: Resource, check_only: bool = true) -> bool:
	var incoming_class: String = res.get_class()
	
	if (incoming_class == "Resource"):
		var script: Script = res.get_script()
		if (!_is_scripted_resource_allowed(script)):
			# FIXME: the error message should specify the error:
			# - non expected type should output what has come and what it should be
			# - if incoming is exactly the base type but _allow_base is false
			
			if (!check_only):
				_lblerr.text = "Incoming value type is not of the expected type."
				_show_error(true)
			
			return false
		
		# If here, incoming value is of expected type
		if (!check_only):
			var s: Dictionary = {}
			var as_da: _DASSET_T = res as _DASSET_T
			if (as_da):
				s = as_da.get_property_info()
			
			_iterate_properties(res, script.get_script_property_list(), s, (script as GDScript).new())
	
	else:
		# Assume incoming value type is not of expected type
		var allowed: bool = false
		
		if (incoming_class == _restype):
			allowed = _allow_base
		
		else:
			allowed = ClassDB.is_parent_class(incoming_class, _restype)
		
		
		if (allowed):
			if (!check_only):
				_iterate_properties(res, ClassDB.class_get_property_list(incoming_class), {}, ClassDB.instance(incoming_class))
		
		else:
			if (!check_only):
				_lblerr.text = "Incoming value type is not of the expected type."
				_show_error(true)
			return false
	
	return true



func _show_error(display: bool) -> void:
	_lblerr.visible = display
	_slot.visible = !display
	_pedbox.visible = !display


#######################################################################################################################
### Event handlers
func _on_new_instance(nval) -> void:
	set_value(nval)
	
	notify_value_changed(nval)


func _draw_box(b: Control) -> void:
	b.draw_rect(Rect2(Vector2(), b.rect_size), get_color("dark_color_3", "Editor"))


func _on_property_changed(newval, propname: String) -> void:
	_value.set(propname, newval)
	
	notify_value_changed(_value)


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	if (!_red):
		return
	
	if (_value != value):
		while (_pedbox.get_child_count() > 0):
			var c: Control = _pedbox.get_child(0)
			_pedbox.remove_child(c)
			c.free()
	
	var res: Resource = value if (value is Resource) else null
	
	if (res != null):
		if (!_is_resource_allowed(res, false)):
			return
	
	_value = res
	_red.set_instance(_value)
	_show_error(false)




func extra_setup(settings: Dictionary, typeinfo: Dictionary) -> void:
	# Must hold here the list of property editor classes associated with their types
	_typeinfo = typeinfo
	
	# Take the expected resource type from settings
	_restype = settings.get("type", "")
	
	if (!_restype.empty()):
		_lblerr.text = ""
		
		if (_restype.begins_with("res://")):
			var script: Script = load(_restype) as Script
			if (script):
				if (script.get_instance_base_type() == "Resource"):
					# Scripted resources will always use the "generic" instance editor
					_red = _GENERIC_RED.new()
					_slot.add_child(_red)
					
					# By default allow instancing the specified base class
					_allow_base = settings.get("allow_base", true)
					
					_red.setup_scripted(script, _allow_base)
					
					# Cache the expected resource base type
					_scripted_type = script
				
				else:
					_lblerr.text = "Script '%s' does not implement a resource." % _restype
					_show_error(true)
			
			else:
				_lblerr.text = "'%s' isn't a Script, much less one implementing a resource." % _restype
				_show_error(true)
		
		else:
			#var red_t: GDScript = SpecializedResEd.get(_restype, null)
			var red_t: GDScript = _get_instance_editor_for_core(_restype)
			if (!red_t):
				red_t = _GENERIC_RED
			
			_red = red_t.new()
			_red.setup_builtin(_restype)
			_slot.add_child(_red)
			
			_allow_base = ClassDB.can_instance(_restype)
	
	if (_red):
		_show_error(false)
		
		# warning-ignore:return_value_discarded
		_red.connect("new_instance", self, "_on_new_instance")
		
		_red.set_type_checker(funcref(self, "_is_resource_allowed"))



func _init() -> void:
	var mainbox: VBoxContainer = VBoxContainer.new()
	_right.add_child(mainbox)
	
	mainbox.add_child(_lblerr)
	_lblerr.autowrap = true
	_lblerr.text = STR_INVALID_PROPERTY
	
	mainbox.add_child(_slot)
	_slot.set_anchors_and_margins_preset(PRESET_WIDE)
	_slot.visible = false
	
	
	mainbox.add_child(_pedbox)
	_pedbox.set_anchors_and_margins_preset(PRESET_WIDE)
	_pedbox.visible = false
	
	# warning-ignore:return_value_discarded
	mainbox.connect("draw", self, "_draw_box", [mainbox])
