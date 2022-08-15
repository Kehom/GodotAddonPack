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

# While it would be possible to have a single "numeric editor", there are a few small differences between int and float
# It becomes rather easier to just deal with them in different files. If the requirements become too big, then create
# a base numerical type and extend even further for int and float.

#######################################################################################################################
### Signals and definitions
const SpinSliderT: Script = preload("res://addons/keh_ui/spin_slider/spin_slider.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _spin: SpinSliderT = SpinSliderT.new()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_spin.value = value



func extra_setup(settings: Dictionary, _typeinfo: Dictionary) -> void:
	if (settings.has("range_min")):
		_spin.use_min_value = true
		_spin.min_value = round(settings.range_min)
	
	if (settings.has("range_max")):
		_spin.use_max_value = true
		_spin.max_value = round(settings.range_max)
	
	_spin.step = round(settings.get("step", 1))

func _ready() -> void:
	_spin.flat = true
	_right.add_child(_spin)
	
	# warning-ignore:return_value_discarded
	_spin.connect("value_changed", self, "notify_value_changed")
