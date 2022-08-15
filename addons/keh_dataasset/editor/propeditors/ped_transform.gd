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
var _value: Transform = Transform()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _changed_xx(nval: float) -> Transform:
	_value.basis.x.x = nval
	return _value

func _changed_xy(nval: float) -> Transform:
	_value.basis.x.y = nval
	return _value

func _changed_xz(nval: float) -> Transform:
	_value.basis.x.z = nval
	return _value


func _changed_yx(nval: float) -> Transform:
	_value.basis.y.x = nval
	return _value

func _changed_yy(nval: float) -> Transform:
	_value.basis.y.y = nval
	return _value

func _changed_yz(nval: float) -> Transform:
	_value.basis.y.z = nval
	return _value


func _changed_zx(nval: float) -> Transform:
	_value.basis.z.x = nval
	return _value

func _changed_zy(nval: float) -> Transform:
	_value.basis.z.y = nval
	return _value

func _changed_zz(nval: float) -> Transform:
	_value.basis.z.z = nval
	return _value


func _changed_px(nval: float) -> Transform:
	_value.origin.x = nval
	return _value

func _changed_py(nval: float) -> Transform:
	_value.origin.y = nval
	return _value

func _changed_pz(nval: float) -> Transform:
	_value.origin.z = nval
	return _value

#######################################################################################################################
### Overrides
func set_value(value) -> void:
	if (_value != value):
		_value = value
	
	update_component(0, _value.basis.x.x)
	update_component(1, _value.basis.x.y)
	update_component(2, _value.basis.x.z)
	
	update_component(3, _value.basis.y.x)
	update_component(4, _value.basis.y.y)
	update_component(5, _value.basis.y.z)
	
	update_component(6, _value.basis.z.x)
	update_component(7, _value.basis.z.y)
	update_component(8, _value.basis.z.z)
	
	update_component(9, _value.origin.x)
	update_component(10, _value.origin.y)
	update_component(11, _value.origin.z)


func _init() -> void:
	create_row("basis.x", 90)
	create_component("x", "x", 0, "_changed_xx")
	create_component("y", "y", 1, "_changed_xy")
	create_component("z", "z", 2, "_changed_xz")
	
	create_row("basis.y", 90)
	create_component("x", "x", 0, "_changed_yx")
	create_component("y", "y", 1, "_changed_yy")
	create_component("z", "z", 2, "_changed_yz")
	
	create_row("basis.z", 90)
	create_component("x", "x", 0, "_changed_zx")
	create_component("y", "y", 1, "_changed_zy")
	create_component("z", "z", 2, "_changed_zz")
	
	create_row("origin", 90)
	create_component("x", "x", 0, "_changed_px")
	create_component("y", "y", 1, "_changed_py")
	create_component("z", "z", 2, "_changed_pz")
