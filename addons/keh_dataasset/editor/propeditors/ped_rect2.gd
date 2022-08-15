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
extends "res://addons/keh_dataasset/editor/propeditors/ped_composite.gd"


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _value: Rect2 = Rect2()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _changed_x(nval: float) -> Rect2:
	_value.position.x = nval
	return _value

func _changed_y(nval: float) -> Rect2:
	_value.position.y = nval
	return _value

func _changed_w(nval: float) -> Rect2:
	_value.size.x = nval
	return _value

func _changed_h(nval: float) -> Rect2:
	_value.size.y = nval
	return _value

#######################################################################################################################
### Overrides
# Set value must be implemented in the "final class"
func set_value(value) -> void:
	if (_value != value):
		_value = value
	
	update_component(0, _value.position.x)
	update_component(1, _value.position.y)
	update_component(2, _value.size.x)
	update_component(3, _value.size.y)


# "Final class" MUST override this in order to create the instances within the "_component" array
func _init() -> void:
	create_component("position_x", "x", 0, "_changed_x")
	create_component("position_y", "y", 1, "_changed_y")
	create_component("width", "Width", 0, "_changed_w")
	create_component("height", "Height", 1, "_changed_h")



