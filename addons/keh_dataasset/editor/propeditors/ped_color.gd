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
var _cp: ColorPickerButton = ColorPickerButton.new()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _cpchanged(ncol: Color) -> void:
	set_value(ncol)


func _changed_r(nval: float) -> Color:
	_cp.color.r = nval
	return _cp.color

func _changed_g(nval: float) -> Color:
	_cp.color.g = nval
	return _cp.color

func _changed_b(nval: float) -> Color:
	_cp.color.b = nval
	return _cp.color

func _changed_a(nval: float) -> Color:
	_cp.color.a = nval
	return _cp.color

#######################################################################################################################
### Overrides
func set_value(value) -> void:
	if (_cp.color != value):
		_cp.color = value
	
	update_component(0, _cp.color.r)
	update_component(1, _cp.color.g)
	update_component(2, _cp.color.b)
	update_component(3, _cp.color.a)


func _init() -> void:
	_cp.rect_min_size.x = 40
	add_to_row(_cp)
	
	
	create_component("r", "r", 0, "_changed_r")
	create_component("g", "g", 1, "_changed_g")
	create_component("b", "b", 2, "_changed_b")
	create_component("a", "a", 3, "_changed_a")
	
	force_step(0.01)
	force_min_val(0.0)
	
	# warning-ignore:return_value_discarded
	_cp.connect("color_changed", self, "_cpchanged")

