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

tool
extends Reference
class_name InventorySlot

# The inventory bag will hold multiple instances of this class, mostly to cache the drawing position of each slot

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
# Drawing position
var posx: int
var posy: int

# If null then this slot does not contain any item or part of an item
# NOTE: static typing this to Control in order to avoid cyclic references
var item: Control

#######################################################################################################################
### "Public" functions
func set_pos(px: int, py: int) -> void:
	posx = px
	posy = py


func set_highlight(type: int, is_manual: bool) -> void:
	_highlight.set_highlight(type, is_manual)


func render(rid: RID, size: Vector2, theme: Theme, autohle: bool) -> void:
	var rd: Rect2 = Rect2(Vector2(posx, posy), size)
	
	var stl: StyleBox = theme.get_stylebox("slot", "Inventory")
	if (autohle || _highlight.is_manual()):
		match _highlight.get_type():
			InventoryCore.HighlightType.Normal:
				stl = theme.get_stylebox("slot_normal_highlight", "Inventory")
			
			InventoryCore.HighlightType.Allow:
				stl = theme.get_stylebox("slot_allow_highlight", "Inventory")
			
			InventoryCore.HighlightType.Deny:
				stl = theme.get_stylebox("slot_deny_highlight", "Inventory")
			
			InventoryCore.HighlightType.Disabled:
				stl = theme.get_stylebox("slot_disabled_highlight", "Inventory")
	
	if (stl):
		stl.draw(rid, rd)


func is_enabled() -> bool:
	return _highlight.get_type() != InventoryCore.HighlightType.Disabled


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _highlight: InventoryHighlight = InventoryHighlight.new()

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _init(px: int, py: int) -> void:
	set_pos(px, py)
	item = null

