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
var _value: Basis = Basis()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _changed_xx(nval: float) -> Basis:
	_value.x.x = nval
	return _value

func _changed_xy(nval: float) -> Basis:
	_value.x.y = nval
	return _value

func _changed_xz(nval: float) -> Basis:
	_value.x.z = nval
	return _value


func _changed_yx(nval: float) -> Basis:
	_value.y.x = nval
	return _value

func _changed_yy(nval: float) -> Basis:
	_value.y.y = nval
	return _value

func _changed_yz(nval: float) -> Basis:
	_value.y.z = nval
	return _value


func _changed_zx(nval: float) -> Basis:
	_value.z.x = nval
	return _value

func _changed_zy(nval: float) -> Basis:
	_value.z.y = nval
	return _value

func _changed_zz(nval: float) -> Basis:
	_value.z.z = nval
	return _value

#######################################################################################################################
### Overrides
# Set value must be implemented in the "final class"
func set_value(value) -> void:
	if (_value != value):
		_value = value
	
	update_component(0, _value.x.x)
	update_component(1, _value.x.y)
	update_component(2, _value.x.z)
	
	update_component(3, _value.y.x)
	update_component(4, _value.y.y)
	update_component(5, _value.y.z)
	
	update_component(6, _value.z.x)
	update_component(7, _value.z.y)
	update_component(8, _value.z.z)


func _init() -> void:
	create_row("X", 10)
	create_component("x", "x", 0, "_changed_xx")
	create_component("y", "y", 1, "_changed_xy")
	create_component("z", "z", 2, "_changed_xz")
	
	create_row("Y", 10)
	create_component("x", "x", 0, "_changed_yx")
	create_component("y", "y", 1, "_changed_yy")
	create_component("z", "z", 2, "_changed_yz")
	
	create_row("Z", 10)
	create_component("x", "x", 0, "_changed_zx")
	create_component("y", "y", 1, "_changed_zy")
	create_component("z", "z", 2, "_changed_zz")
