# Copyright (c) 2021 Yuri Sarudiansky
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


extends Reference
class_name InventoryHighlight

# This rather simple class is primarily meant to deal with both slot and item highlighting

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func get_type() -> int:
	return _type

func is_manual() -> bool:
	return _manual


func set_highlight(tp: int, manual: bool) -> void:
	if (!manual && _manual):
		# Do not allow automatic highlight to overwrite manual highlight
		return
	
	_type = tp
	_manual = manual if tp != InventoryCore.HighlightType.None else false


# Not static typing here to avoid memory leak - but the type here should be the same of this class
func copy_to(h) -> void:
	h._type = _type
	h._manual = _manual


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# This should be a value of HighlightType enum
var _type: int = InventoryCore.HighlightType.None

# Indicate if the value in here is part of the automatic highlighting or was manually set. Manual highlight
# should not be overwritten by the automatic system
var _manual: bool = false

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
