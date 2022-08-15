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

# The "IntEnum" holds an integer, but shows the possible values through an enumerated series of strings. Those are
# shown in a drop down menu

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
var _optbutton: OptionButton = OptionButton.new()
var _value: int = 0

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_item_selected(index: int) -> void:
	_value = _optbutton.get_item_id(index)
	notify_value_changed(_value)


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_value = value
	
	var idx: int = _optbutton.get_item_index(_value)
	_optbutton.selected = idx



func extra_setup(settings: Dictionary, _typeinfo: Dictionary) -> void:
	var hs: String = settings.hint_string
	var vlist: PoolStringArray = hs.split(",")
	for cval in vlist:
		var fsplit: PoolStringArray = cval.split(":")
		
		_optbutton.add_item(fsplit[0], int(fsplit[1]))


func _ready() -> void:
	_right.add_child(_optbutton)
	
	# warning-ignore:return_value_discarded
	_optbutton.connect("item_selected", self, "_on_item_selected")
