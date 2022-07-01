# Copyright (c) 2021-2022 Yuri Sarudiansky
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

# Dealing with themes on Custom controls is just... not fun! What happens is this. Each control instance contains
# a "theme" property which is, by default, null. If it is set on a node, it notifies all children about this change
# but the value is not exactly assigned within any of them.
# When any style is required typically the get_[some_style]() function is used. Those functions first check if there
# is any style override for the given name. If there isn't then the code tries to locate, recursively, a parent that
# contains a valid "theme" property. If found then that theme's style is returned, otherwise the code will retrieve
# the default theme and return something from it. And here comes the problem, from scripting there is no way to access
# this specific default theme resource in order to incorporate styles for custom controls.
# And then comes the style overrides. Those are meant to be "confined" to the instance that received the override so
# it shouldn't be that problematic. Except there is a limitation (2 actually) that forces this little class to also
# take over the override system. The first one is that color overrides can't be cleared. The second is that constant
# overrides are cleared if 0 is assigned, meaning that we can't use 0 as an actual override value.
# One of the features that comes with this base class is the fact that custom style entries will be exposed to the
# inspector as "overrides". This means that a style can be easily overridden through the inspector very much like
# any other core control that offers their own styles.
#
# All that said, this base class will basically deal with the theme/custom styles code and only that, allowing it to
# be used as a base class for custom controls. Things to know when writing custom controls using this as a base:
#
# - When a style is added, it is inserted in an internal container (Dictionary) instead of being added into a
#   valid Theme object. This is meant to avoid "polluting" the Theme. Still, whenever retrieving a style the code
#   will first verify if there is a valid theme and, if so, will check if there is any entry to be used.
# - Whenever necessary this base class will call a function that must be overridden, which is the create_custom_theme().
#   In it all the custom style must be added (or registered if you will)
# - Styles must be added by calling the various add_theme_*() functions, preferably providing the correct class name
#   as the "type" parameter, which will somewhat help "categorize" the entries within the internal theme management.
# - To add overrides call the add_theme_*_override() functions.
# - To clear an override call the clear_theme_*_override() functions.
# - Instead of calling has_*_override() call the has_theme_*_override() in order to check if there is any style override.
# - When a style is required, instead of calling get_[some_style]() function, call get_theme_*(). Those will first
#   check if there is n override for the requested theme entry. If one does not exist then it will try to find a valid
#   theme object and check if there is one for that entry. Finally it will return what is stored within the internal
#   dictionary.
# - Adding a constant style has the option to also provide an "enum string" (please check PROPERTY_YINT_ENUM). If this
#   string is given then the exposed property will use that as a hint_string and overriding the style will be easily
#   done through a drop down menu.

tool
extends Control
class_name CustomControlBase

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# Override this function, which will be called in order to create custom theme entries within the _use_theme property.
func _create_custom_theme() -> void:
	pass

### Icon
# Add an icon entry into the theme.
func add_theme_icon(name: String, texture: Texture, expose: bool = true) -> void:
	__add_entry(name, texture, expose, TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Texture", __reg_icon)

# Add an icon override
func add_theme_icon_override(name: String, icon: Texture) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomIcons/" + name, icon)

# Remove an icon override
func clear_theme_icon_override(name: String) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomIcons/" + name, null)

# Returns true if the icon entry exists within the theme
func has_theme_icon(name: String, type: String = "") -> bool:
	return has_icon(name, type) || __reg_icon.has(name)

# Returns true if the icon has an override
func has_theme_icon_override(name: String) -> bool:
	return __has_override(name, __reg_icon)

# Retrieve an icon from the theme. If there is an icon override then it will be returned instead
func get_theme_icon(name: String, type: String) -> Texture:
	return __get_entry(name, type, __reg_icon, "has_icon", "get_icon")


### Stylebox
# Add a stylebox into the theme.
func add_theme_stylebox(name: String, style: StyleBox, expose: bool = true) -> void:
	__add_entry(name, style, expose, TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "StyleBox", __reg_stylebox)

# Add a stylebox override
func add_theme_stylebox_override(name: String, style: StyleBox) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomStyles" + name, style)

# Clear a stylebox override
func clear_theme_stylebox_override(name: String) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomStyles/" + name, null)

# Returns true if the stylebox entry exists within the theme
func has_theme_stylebox(name: String, type: String = "") -> bool:
	return has_stylebox(name, type) || __reg_stylebox.has(name)

# Returns true if the stylebox entry has an override
func has_theme_stylebox_override(name: String) -> bool:
	return __has_override(name, __reg_stylebox)

# Retrieve a stylebox from the theme. If there is a stylebox override then it will be returned instead
func get_theme_stylebox(name: String, type: String = "") -> StyleBox:
	return __get_entry(name, type, __reg_stylebox, "has_stylebox", "get_stylebox")


### Font
# Add a font entry into the theme.
func add_theme_font(name: String, font: Font, expose: bool = true) -> void:
	__add_entry(name, font, expose, TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Font", __reg_font)

# Add a font override
func add_theme_font_override(name: String, font: Font) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomFonts/" + name, font)

# Clear a font override
func clear_theme_font_override(name: String) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomFonts/" + name, null)

# Returns true if the font entry exists within the theme
func has_theme_font(name: String, type: String = "") -> bool:
	return has_font(name, type) || __reg_font.has(name)

# Returns true if the given font name has an override
func has_theme_font_override(name: String) -> bool:
	return __has_override(name, __reg_font)

# Retrieve a font from the theme. If there is a font override then it will be returned instead
func get_theme_font(name: String, type: String = "") -> Font:
	return __get_entry(name, type, __reg_font, "has_font", "get_font")


### Color
# Add a color entry into the theme.
func add_theme_color(name: String, color: Color, expose: bool = true) -> void:
	__add_entry(name, color, expose, TYPE_COLOR, 0, "", __reg_color)

# Add a color override
func add_theme_color_override(name: String, value: Color) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomColors/" + name, value)

# Clear a color override
func clear_theme_color_override(name: String) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomColors/" + name, null)

# Returns true if the color entry exists within the theme
func has_theme_color(name: String, type: String = "") -> bool:
	return has_color(name, type) || __reg_color.has(name)

# Returns true if there is a color override
func has_theme_color_override(name: String) -> bool:
	return __has_override(name, __reg_color)

# Retrieve a color from the theme. If there is a color_override then it will be returned instead.
func get_theme_color(name:String, type: String = "") -> Color:
	return __get_entry(name, type, __reg_color, "has_color", "get_color")


### Constant
# Add a constant entry into the theme.
func add_theme_constant(name: String, constant: int, expose: bool = true, enum_string: String = "") -> void:
	__add_entry(name, constant, expose, TYPE_INT, PROPERTY_HINT_ENUM if !enum_string.empty() else 0, enum_string, __reg_constant)

# Add a constant entry with a defined range. In this case there is no point in not exposing this constant so this will
# always be exposed
func add_theme_constant_range(name: String, constant: int, minval: int, maxval: int, allowlesser: bool = false, allowgreater: bool = false) -> void:
	var hstr: String = "%d,%d%s%s"  % [minval, maxval, ",or_lesser" if allowlesser else "", ",or_greater" if allowgreater else ""]
	__add_entry(name, constant, true, TYPE_INT, PROPERTY_HINT_RANGE, hstr, __reg_constant)


# Add a constant override
func add_theme_constant_override(name: String, value: int) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomConstants/" + name, value)

# Clear a constant override
func clear_theme_constant_override(name: String) -> void:
	# warning-ignore:return_value_discarded
	_set("CustomConstants/" + name, null)

# Returns true if the constant entry exists within the theme
func has_theme_constant(name: String, type: String = "") -> bool:
	return has_constant(name, type) || __reg_constant.has(name)

# Returns true if there is a constant override
func has_theme_constant_override(name: String) -> bool:
	return __has_override(name, __reg_constant)

# Retrieve a constant from the theme. If there is a constant_override then it will be returned instead
func get_theme_constant(name: String, type: String = "") -> int:
	return __get_entry(name, type, __reg_constant, "has_constant", "get_constant")


#######################################################################################################################
### "Private" definitions
# As mentioned, when a custom theme is required it will be added into an internal Dictionary. To help hold the necessary
# data this inner class is used. The Dictionary will hold instances of this class
class _ThemeEntry:
	# This is the actual style. This should be a variant simply because it can be any of the possible theme types
	var style = null
	
	# If this is set to false then the style entry will not be shown within the override list
	var expose: bool = true
	
	# This is meant to be a variant defaulting to null. When an override is added then this property will receive that
	# value
	var override = null
	
	# Integer representing the style type. This will also help build the Inspector entry
	var type: int = -1
	
	# How this style is meant to be used when in the inspector
	var hint: int = 0
	
	# Helper for the inspector to generate the proper editing control
	var hint_string: String = ""
	
	### The properties that are meant to be Variants (style and override) are resulting in a bunch of "unsafe access" warnings,
	### telling the _ThemeEntry class does not have those properties. To remedy this, use the functions to intermediate access
	### to those properties
	func set_style(s) -> void:
		style = s
	
	func get_style():
		return style
	
	func set_override(o) -> void:
		override = o
	
	func get_override():
		return override

#######################################################################################################################
### "Private" properties
# In each dictionary, the key is the name of the theme entry and the value is an instance of _ThemeEntry
var __reg_icon: Dictionary = {}
var __reg_stylebox: Dictionary = {}
var __reg_font: Dictionary = {}
var __reg_color: Dictionary = {}
var __reg_constant: Dictionary = {}


#######################################################################################################################
### "Private" functions
func __cleanup() -> void:
	
	__reg_stylebox.clear()


func __add_entry(n: String, s, e: bool, tp: int, h: int, hs: String, cont: Dictionary) -> void:
	var entry: _ThemeEntry = cont.get(n, null)
	
	if (!entry):
		entry = _ThemeEntry.new()
		cont[n] = entry
	
	#entry.style = s
	entry.set_style(s)
	entry.expose = e
	entry.type = tp
	entry.hint = h
	entry.hint_string = hs


func __get_entry(name: String, type: String, cont: Dictionary, checker: String, getter: String):
	var entry: _ThemeEntry = cont.get(name, null)
	if (entry && entry.get_override() != null):
		return entry.get_override()
	
	if (type.empty()):
		type = "CustomControl"
	
	if (call(checker, name, type)):
		return call(getter, name, type)
	
	return entry.get_style() if entry else null



func __has_override(name: String, cont: Dictionary) -> bool:
	var entry: _ThemeEntry = cont.get(name, null)
	if (!entry):
		return false
	
	return (entry.get_override() != null)


func __build_props(prefix: String, cont: Dictionary, outarr: Array) -> void:
	for n in cont:
		var entry: _ThemeEntry = cont[n]
		if (entry.expose):
			var out: Dictionary = {
				"name": "%s/%s" % [prefix, n],
				"type": entry.type,
				"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE,
			}
			
			if (entry.get_override() != null):
				out.usage |= PROPERTY_USAGE_CHECKED
			
			if (entry.hint != 0):
				out["hint"] = entry.hint
			
			if (!entry.hint_string.empty()):
				out["hint_string"] = entry.hint_string
			
			outarr.append(out)



#######################################################################################################################
### Event handlers
func ___on_res_changed() -> void:
	notification(NOTIFICATION_THEME_CHANGED)

#######################################################################################################################
### Overrides
func _get_property_list() -> Array:
	var ret: Array = []
	
	__build_props("CustomIcons", __reg_icon, ret)
	__build_props("CustomStyles", __reg_stylebox, ret)
	__build_props("CustomFonts", __reg_font, ret)
	__build_props("CustomColors", __reg_color, ret)
	__build_props("CustomConstants", __reg_constant, ret)
	
	return ret


func _set(prop: String, val) -> bool:
	var split: Array = prop.split("/", false, 1)
	var entry: _ThemeEntry = null
	var ret: bool = true
	
	match split[0]:
		"CustomIcons":
			entry = __reg_icon.get(split[1], null)
			if (entry):
				entry.set_override(val if (val != null && val is Texture) else null)
		
		"CustomStyles":
			entry = __reg_stylebox.get(split[1], null)
			if (entry):
				var oldval: StyleBox = entry.get_override()
				if (oldval):
					oldval.disconnect("changed", self, "notification")
				
				var nval: StyleBox = val
				entry.set_override(nval)
				
				if (nval && !nval.is_connected("changed", self, "notification")):
					# warning-ignore:return_value_discarded
					nval.connect("changed", self, "notification", [NOTIFICATION_THEME_CHANGED])
		
		"CustomFonts":
			entry = __reg_font.get(split[1], null)
			if (entry):
				entry.set_override(val if (val != null && val is Font) else null)
		
		"CustomColors":
			entry = __reg_color.get(split[1], null)
			if (entry):
				entry.set_override(val if (val != null && val is Color) else null)
		
		"CustomConstants":
			entry = __reg_constant.get(split[1], null)
			if (entry):
				entry.set_override(val if (val != null && val is int) else null)
		
		_:
			ret = false
	
	if (ret):
		call_deferred("notification", NOTIFICATION_THEME_CHANGED)
	
	return ret


func _get(prop: String):
	var split: Array = prop.split("/", false, 1)
	var entry: _ThemeEntry = null
	
	match split[0]:
		"CustomIcons":
			entry = __reg_icon.get(split[1], null)
		
		"CustomStyles":
			entry = __reg_stylebox.get(split[1], null)
		
		"CustomFonts":
			entry = __reg_font.get(split[1], null)
		
		"CustomColors":
			entry = __reg_color.get(split[1], null)
		
		"CustomConstants":
			entry = __reg_constant.get(split[1], null)
	
	
	return entry.get_override() if entry else null



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			_create_custom_theme()
	
		NOTIFICATION_EXIT_TREE:
			__cleanup()




func _init() -> void:
	_create_custom_theme()

