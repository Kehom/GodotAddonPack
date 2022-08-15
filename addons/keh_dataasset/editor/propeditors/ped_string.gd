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
var _txtedit: TextEdit = TextEdit.new()

var _lheight: int = 0

var _styleheight: int = 0

var _emptystyle: StyleBoxEmpty = StyleBoxEmpty.new()

#######################################################################################################################
### "Private" functions
func _check_size() -> void:
	var lcount = _txtedit.get_line_count()
	
	if (lcount == 0):
		lcount = 1
	
	_txtedit.rect_min_size.y = (lcount * _lheight) + _styleheight


#######################################################################################################################
### Event handlers
func _text_changed() -> void:
	_check_size()
	
	notify_value_changed(_txtedit.text)


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_txtedit.text = value
	_check_size()



func extra_setup(_settings: Dictionary, _typeinfo: Dictionary) -> void:
	
	pass


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			var style: StyleBox = get_stylebox("normal", "TextEdit")
			var font: Font = get_font("font", "TextEdit")
			var spacing: int = get_constant("line_spacing", "TextEdit")
			_lheight = int(font.get_height() + spacing)
			_styleheight = int(style.get_minimum_size().y)
			_check_size()



func _ready() -> void:
	_right.add_child(_txtedit)
	
	# warning-ignore:return_value_discarded
	_txtedit.connect("text_changed", self, "_text_changed")
	
	_txtedit.add_stylebox_override("focus", _emptystyle)



