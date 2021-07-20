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
extends CanvasLayer


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# NOTE: Static typing the argument to Control (item's base) to avoid cyclic references
func set_hovered(item: Control) -> void:
	if (_dragging && _dragging == item):
		return
	
	_hovered = item


func get_hovered() -> Control:
	return _hovered


func is_dragging() -> bool:
	return (_dragging != null)



func register_item_holder(ih: Control) -> void:
	# Assign whatever. Again, this dictionary is used as a set rather than map.
	_item_holder[ih] = 1

func unregister_item_holder(ih: Control) -> void:
	# warning-ignore:return_value_discarded
	_item_holder.erase(ih)



### Some functions to obtain the settings retrieved from ProjectSettings
func pick_item_mouse_button() -> int:
	return _settings.pick_item_mbutton

func set_pick_item_mouse_button(bt: int) -> void:
	_settings.pick_item_mbutton = bt


func unsocket_item_mouse_button() -> int:
	return _settings.unsocket_item_mbutton

func set_unsocket_item_mouse_button(bt: int) -> void:
	_settings.unsocket_item_mbutton = bt


func stack_valign() -> int:
	return _settings.stack_valign

func set_stack_valign(v: int) -> void:
	_notify_setting_changed()
	_settings.stack_valign = v


func stack_halign() -> int:
	return _settings.stack_halign

func set_stack_halign(v: int) -> void:
	_notify_setting_changed()
	_settings.stack_halign = v


func stack_offset() -> Vector2:
	return _settings.stack_offset

func set_stack_offset(v: Vector2) -> void:
	_notify_setting_changed()
	_settings.stack_offset = v


func slot_autohighlight() -> bool:
	return _settings.slot_autohighlight

func set_slot_autohighlight(v: bool) -> void:
	_notify_setting_changed()
	_settings.slot_autohighlight = v


func item_autohighlight() -> bool:
	return _settings.item_autohighlight

func set_item_autohighlight(v: bool) -> void:
	_notify_setting_changed()
	_settings.item_autohighlight = v


func draw_background() -> bool:
	return _settings.draw_background

func set_draw_background(v: bool) -> void:
	_notify_setting_changed()
	_settings.draw_background = v


func use_respath_on_signals() -> bool:
	return _settings.use_respath_on_events


func interactable_disabled_items() -> bool:
	return _settings.interactable_ditems

func set_interactable_disabled_items(v: bool) -> void:
	_settings.interactable_ditems = v


func disabled_slots_occupied() -> bool:
	return _settings.disabled_slots_occupied

func set_disabled_slots_occupied(v: bool) -> void:
	_settings.disabled_slots_occupied = v
	_notify_setting_changed()


func always_draw_sockets() -> bool:
	return _settings.always_draw_sockets

func set_always_draw_sockets(v: bool) -> void:
	_settings.always_draw_sockets = v
	_notify_setting_changed()


func socket_draw_ratio() -> float:
	return _settings.socket_draw_ratio

func set_socket_draw_ratio(v: float) -> void:
	_settings.socket_draw_ratio = v
	_notify_setting_changed()


func socketed_item_emit_hovered() -> bool:
	return _settings.socketed_item_hovered

func set_socketed_item_emit_hovered(v: bool) -> void:
	_settings.socketed_item_hovered = v


func auto_hide_cursor() -> bool:
	return _settings.auto_hide_cursor

func set_autohide_cursor(v: bool) -> void:
	_settings.auto_hide_cursor = v


func drop_mode() -> int:
	return _settings.drop_mode

func set_drop_mode(v: int) -> void:
	_settings.drop_mode = v


func inherit_preview_size() -> bool:
	return _settings.inherit_preview_size

func set_inherit_preview_size(v: bool) -> void:
	_settings.inherit_preview_size = v


func preview_cell_width() -> int:
	return _settings.cell_width

func set_preview_cell_width(v: int) -> void:
	_settings.cell_width = v


func preview_cell_height() -> int:
	return _settings.cell_height

func set_preview_cell_height(v: int) -> void:
	_settings.cell_height = v


func hide_sockets_on_drag() -> bool:
	return _settings.hide_sockets

func set_hide_sockets_on_drag(v: bool) -> void:
	_settings.hide_sockets = v


### Other operations.....
func set_mouse_on_socket(v: bool) -> void:
	_mouse_on_socket = v

func is_mouse_on_socket() -> bool:
	return _mouse_on_socket


# NOTE: Static typing the item to Control to avoid cyclic references
func start_drag(item: Control, amount: int) -> void:
	assert(_dragnode)
	assert(!_dragging)
	assert(item && item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
	_dragging = item.copy(amount)
	_dragging.set_ignore_mouse(true)
	_dragging.set_highlight(InventoryCore.HighlightType.None, false)
	
	var dsize: Vector2 = item.rect_size
	if (!inherit_preview_size()):
		dsize = Vector2(item.get_column_span() * preview_cell_width(), item.get_row_span() * preview_cell_height())
	
	_dragging.init_rects(Vector2(), dsize, Vector2(), dsize)
	_dragnode.set_item_offset(-dsize * 0.5)
	
	_dragnode.add_child(_dragging)
	_dragnode.follow_mouse(true)
	
	if (hide_sockets_on_drag()):
		_dragging.set_show_sockets(false)
	
	else:
		_dragging.set_socket_ignore_mouse(true)
	
	if (auto_hide_cursor()):
		_prev_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func end_drag() -> void:
	assert(_dragging)
	_dragging.queue_free()
	_dragging = null
	
	_dragnode.follow_mouse(false)
	
	if (auto_hide_cursor()):
		Input.set_mouse_mode(_prev_mouse_mode)
		_prev_mouse_mode = -1


# NOTE: Static typing item to Control in order to avoid cyclic references
func swap_drag(item: Control) -> void:
	assert(_dragging)
	assert(_dragnode)
	assert(item && item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
	_dragging.queue_free()
	_dragging = item.copy(-1)
	_dragging.set_ignore_mouse(true)
	_dragging.set_highlight(InventoryCore.HighlightType.None, false)
	
	var dsize: Vector2 = item.rect_size
	if (!inherit_preview_size()):
		dsize = Vector2(item.get_column_span() * preview_cell_width(), item.get_row_span() * preview_cell_height())
	
	_dragging.init_rects(Vector2(), dsize, Vector2(), dsize)
	_dragnode.set_item_offset(-dsize * 0.5)
	_dragnode.add_child(_dragging)
	
	if (hide_sockets_on_drag()):
		_dragging.set_show_sockets(false)
	
	else:
		_dragging.set_socket_ignore_mouse(true)


func get_dragged_item() -> Control:
	return _dragging



func get_drag_icon_offset() -> Vector2:
	assert(is_dragging())
	
	return _dragnode._item_offset

func delta_dragged_stack(dt: int) -> void:
	_dragging.delta_stack(dt)
	
	if (_dragging.get_current_stack() == 0):
		end_drag()


func _notify_setting_changed() -> void:
	for ih in _item_holder:
		if (ih is Control and ih.has_method("_on_setting_changed")):
			ih.call("_on_setting_changed")


#######################################################################################################################
### "Private" definitions

const BASE_SETTING: String = "keh_addons/inventory/"
const BASE_GSETTING: String = "keh_addons/inventory/general/"
const BASE_SOCKSETTING: String = "keh_addons/inventory/socket/"
const BASE_DDSETTING: String = "keh_addons/inventory/custom_drag_&_drop/"

# When the _StaticData class initializes, it will create an instance of this node. The sole
# purpose of this node is to be "attached to the mouse". When a custom drag operation begins,
# this node will receive an Item child, which will end up indirectly following the mouse cursor
class _DragNode extends Node2D:
	var _item_offset: Vector2
	
	func _process(_dt: float) -> void:
		global_position = get_global_mouse_position() + _item_offset
	
	func follow_mouse(e: bool) -> void:
		set_process(e)
	
	func set_item_offset(v: Vector2) -> void:
		_item_offset = v


#######################################################################################################################
### "Private" properties
# This is the node that will follow the mouse when custom drag&drop operation is happening
var _dragnode: _DragNode = null

# And this is the item that should follow the mouse, which will be attached to the _dragnode
# NOTE: Static typing to Control (item's base) in order to avoid cyclic references
var _dragging: Control = null

# If auto hide is enabled, must store the original mouse mode so it can be restored when the drag operation ends
var _prev_mouse_mode: int = -1

# Just a single item can be hovered by the mouse at the same time
# NOTE: Static typing to Control (item's base) in order to avoid cyclic references
var _hovered: Control = null

# If mouse is over a socket, this will be set to true
var _mouse_on_socket: bool

# Store here everything all the ProjectSettings data
var _settings: Dictionary= {}

# This dictionary is used as a set rather than map. Nevertheless, each container (derived from InventoryBase) will
# register itself within this static class when entering the tree. This will be used mostly to perform updates as
# soon as settings are changed
var _item_holder: Dictionary = {}


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _enter_tree() -> void:
	_dragnode = _DragNode.new()
	add_child(_dragnode)


func _exit_tree() -> void:
	if (_dragging):
		_dragging.queue_free()
	
	_hovered = null
	
	_item_holder.clear()


func _init() -> void:
	layer = 99999
	_settings = {
		# General Settings
		"pick_item_mbutton": InventoryCore.get_int_setting(BASE_GSETTING + "pick_item_mouse_button", BUTTON_LEFT),
		"stack_valign": InventoryCore.get_int_setting(BASE_GSETTING + "stack_size_vertical_alignment", 0),
		"stack_halign": InventoryCore.get_int_setting(BASE_GSETTING + "stack_size_horizontal_alignment", 0),
		"stack_offset": InventoryCore.get_vec2_setting(BASE_GSETTING + "stack_size_offset", Vector2()),
		"slot_autohighlight": InventoryCore.get_bool_setting(BASE_GSETTING + "slot_auto_highlight", true),
		"item_autohighlight": InventoryCore.get_bool_setting(BASE_GSETTING + "item_auto_highlight", true),
		"draw_background": InventoryCore.get_bool_setting(BASE_GSETTING + "draw_item_background", false),
		"use_respath_on_events": InventoryCore.get_bool_setting(BASE_GSETTING + "use_resource_paths_on_signals", false),
		"interactable_ditems": InventoryCore.get_bool_setting(BASE_GSETTING + "interactable_disabled_items", true),
		"disabled_slots_occupied": InventoryCore.get_bool_setting(BASE_GSETTING + "disabled_slots_block_items", true),
		
		# Socket settings
		"unsocket_item_mbutton": InventoryCore.get_int_setting(BASE_SOCKSETTING + "unsocket_item_mouse_button", BUTTON_RIGHT),
		"always_draw_sockets": InventoryCore.get_bool_setting(BASE_SOCKSETTING + "always_draw_sockets", true),
		"socket_draw_ratio": InventoryCore.get_float_setting(BASE_SOCKSETTING + "socket_draw_ratio", 0.7),
		"socketed_item_hovered": InventoryCore.get_bool_setting(BASE_SOCKSETTING + "socketed_item_emit_hovered_event", true),
		
		
		# Drag and Drop Settings
		"auto_hide_cursor": InventoryCore.get_bool_setting(BASE_DDSETTING + "auto_hide_mouse", true),
		"drop_mode": InventoryCore.get_int_setting(BASE_DDSETTING + "drop_on_existing_stack", InventoryCore.DropMode.FillOnly),
		"inherit_preview_size": InventoryCore.get_bool_setting(BASE_DDSETTING + "inherit_preview_size", false),
		"cell_width": InventoryCore.get_int_setting(BASE_DDSETTING + "preview_cell_width", 32),
		"cell_height": InventoryCore.get_int_setting(BASE_DDSETTING + "preview_cell_height", 32),
		"hide_sockets": InventoryCore.get_bool_setting(BASE_DDSETTING + "hide_sockets_on_drag_preview", false),
	}




