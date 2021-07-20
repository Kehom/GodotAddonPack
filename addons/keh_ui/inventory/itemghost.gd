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
extends Control

# Special slots may be linked and allow items to occupy both ones. In that case, a ghosted item will be
# created. It is a much simplified version of the item itself, just enough to correctly render it.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func init_rects(bpos: Vector2, bsize: Vector2, ipos: Vector2, isize: Vector2) -> void:
	rect_position = bpos
	rect_size = bsize
	rect_min_size = bsize
	
	_item_rect = Rect2(ipos, isize)


func set_highlight(hltype: int, is_manual: bool) -> void:
		_highlight.set_highlight(hltype, is_manual)
		
		update()


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _img: Texture = null

# This is meant to be Item (item.gd), however static typing to Control in order to avoid cyclic references
var _main: Control = null

var _item_rect: Rect2 = Rect2()

var _highlight: InventoryHighlight = null

var _theme: Theme = null

var _shared: CanvasLayer = null

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _draw() -> void:
	# If there is a background and it is enabled, draw it
	if (_shared.draw_background() && _main._background):
		draw_texture_rect(_main._background, Rect2(Vector2(), rect_size), false, Color(1.0, 1.0, 1.0, 1.0))
	
	if (_shared.item_autohighlight() || _highlight.manual):
		var hlbox: StyleBox = null
		match _highlight.get_type():
			InventoryCore.HighlightType.Normal:
				hlbox = _theme.get_stylebox("item_normal_highlight", "Inventory")
			
			InventoryCore.HighlightType.Allow:
				hlbox = _theme.get_stylebox("item_allow_highlight", "Inventory")
			
			InventoryCore.HighlightType.Deny:
				hlbox = _theme.get_stylebox("item_deny_highlight", "Inventory")
			
			InventoryCore.HighlightType.Disabled:
				hlbox = _theme.get_stylebox("item_disabled_highlight", "Inventory")
		
		if (hlbox):
			draw_style_box(hlbox, Rect2(Vector2(), rect_size))
	
	draw_texture_rect(_img, _item_rect, false, _theme.get_color("item_ghost", "Inventory"))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_main._set_mouse_over()
			update()
		
		NOTIFICATION_MOUSE_EXIT:
			_main._set_mouse_out()
			update()


func _enter_tree() -> void:
	if (!_shared):
		_shared = InventoryCore.get_static_data(get_tree().get_root())
	
	if (mouse_filter != MOUSE_FILTER_IGNORE):
		# rect.has_point() is failing all the time so manually performing the test
		var mpos: Vector2 = get_local_mouse_position()
		
		if (mpos.x >= 0 && mpos.x <= rect_size.x && mpos.y >= 0 && mpos.y <= rect_size.y):
			_main.set_highlight(InventoryCore.HighlightType.Normal, false)
			_shared.set_hovered(_main)


func _init(main_item: Control) -> void:
	assert(main_item && main_item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
	mouse_filter = Control.MOUSE_FILTER_PASS
	_highlight = main_item._highlight
	main_item._ghost = self
	
	_main = main_item
	_img = main_item.get_image()
	material = main_item.material
