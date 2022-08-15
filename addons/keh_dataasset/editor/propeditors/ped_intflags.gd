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


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _value: int = 0

var _vbox: VBoxContainer = VBoxContainer.new()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_flag_toggled(pressed: bool, mask: int) -> void:
	if (pressed):
		_value = _value | mask
	
	else:
		_value = _value & ~mask
	
	notify_value_changed(_value)



#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_value = value
	
	var cmask: int = 1
	for i in _vbox.get_child_count():
		var chk: CheckBox = _vbox.get_child(i)
		if (!chk):
			continue
		
		chk.pressed = _value & cmask
		
		cmask = cmask << 1


func extra_setup(settings: Dictionary, _typeinfo: Dictionary) -> void:
	var hs: String = settings.hint_string
	var flist: PoolStringArray = hs.split(",")
	
	var cmask: int = 1
	for fname in flist:
		var fchk: CheckBox = CheckBox.new()
		fchk.text = fname
		_vbox.add_child(fchk)
		
		# warning-ignore:return_value_discarded
		fchk.connect("toggled", self, "_on_flag_toggled", [cmask])
		
		cmask = cmask << 1



func _ready() -> void:
	_right.add_child(_vbox)
