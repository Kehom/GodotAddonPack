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
extends HBoxContainer

# The original idea was to have a base Scene containing roughly the same that this script creates. Then, for each
# supported property type, create an inherited scene with the specifics of that type. Because this plugin uses the
# SpinSlider, having the scene thing creates a hard dependency, that is, it requires the keh_ui to be activated within
# the plugin list. Having the system as pure script like this creates a "soft dependency", in the sense that the files
# must be present but there is no need to activate the plugin.
# This also brings another nice interesting thing. When porting the addon into GDExtension (for Godot 4), there wont be
# the possibility of implementing scenes from C++, so pure code is necessary (like in this script - which will be give
# a very solid foundation for the "translation")

#######################################################################################################################
### Signals and definitions
signal value_changed(new_value)

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func set_value(_value) -> void:
	pass


func extra_setup(_settings: Dictionary, _typeinfo: Dictionary) -> void:
	pass



func setup(propname: String, currentval, settings: Dictionary, typeinfo: Dictionary) -> void:
	#_revert_to = settings.get("default", get_default())
	_revert_to = settings.get("__revert_to__", null)
	_btreset.visible = currentval != _revert_to
	extra_setup(settings, typeinfo)
	
	set_value(currentval)
	
	_lblpname.text = propname
	
	# Property editor for arrays *might* not have names. So, hide the name Control in order to allow the editor to
	# properly fill the available width
	if (propname.empty()):
		var style: StyleBox = get_stylebox("panel", "Panel")
		
		_lblpname.visible = false
		_left.rect_min_size.x = _btreset.get_combined_minimum_size().x + style.get_minimum_size().x



func notify_value_changed(new_value) -> void:
	_btreset.visible = _revert_to != new_value
	emit_signal("value_changed", new_value)

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# Divide in "two" containers - one that will hold property name + revert value button. The other with the property
# editor itself. An important thing here is that PanelContainer does automatically calculate sizing, but does not
# have the desired visual appearance. Panel on the other hand has the visual but not the sizing. So what will happen
# here is that the used Control will be PanelContainer but the stylebox will be retrieved from the Panel and assigned
# into the created Controls
var _left: PanelContainer = PanelContainer.new()
var _right: PanelContainer = PanelContainer.new()

var _lblpname: Label = Label.new()
var _btreset: Button = Button.new()


# This is to hold the "default value". The one that will be used then the revert button is pressed
# Because this strongly relies on the Variant type, which unfortunately can't be explicitly told so, there is no type
# specification here
var _revert_to = null

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _reset() -> void:
	set_value(_revert_to)
	notify_value_changed(_revert_to)

#######################################################################################################################
### Overrides
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			var style: StyleBox = get_stylebox("panel", "Panel")
			
			_left.add_stylebox_override("panel", style)
			_right.add_stylebox_override("panel", style)
			
			_btreset.icon = get_icon("ReloadSmall", "EditorIcons")
			
			if (!_lblpname.visible):
				_left.rect_min_size.x = _btreset.get_combined_minimum_size().x + style.get_minimum_size().x




func _init() -> void:
	# When editing/saving this script, new dynamically created nodes are added again as children, but the old ones are
	# not removed. When in "production use" this is not a problem because the script is not changed. However during
	# development this interferes with the testing, so ensuring no stray nodes are left here
	while (get_child_count() > 0):
		var c: Node = get_child(0)
		remove_child(c)
		c.free()
	
	add_child(_left)
	add_child(_right)
	
	_left.rect_min_size.x = 250
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var inner: HBoxContainer = HBoxContainer.new()
	_left.add_child(inner)
	inner.add_child(_lblpname)
	inner.add_child(_btreset)
	
	_lblpname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lblpname.clip_text = true
	
	_btreset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# warning-ignore:return_value_discarded
	_btreset.connect("pressed", self, "_reset")

