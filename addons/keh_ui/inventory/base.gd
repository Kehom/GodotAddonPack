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
class_name InventoryBase

#######################################################################################################################
### Signals and definitions
signal mouse_over_item(inv_mouse_event)
signal mouse_out_item(inv_mouse_event)

signal item_mouse_down(inv_mouse_event)
signal item_mouse_up(inv_mouse_event)

signal item_clicked(inv_mouse_event)

signal item_picked(inv_container_event)
signal item_dropped(inv_container_event)
signal item_drop_denied(inv_containter_event)
signal drag_ended()

signal item_added(inv_container_event)             # This will not be called when item is added through drag&drop
signal item_removed(inv_container_event)           # This will not be called when item is removed through drag&drop

signal item_socketed(inv_socket_event)
signal item_unsocketed(inv_socket_event)
signal item_socketing_denied(inv_socket_event)

# These two events are not given if the socket is not empty
signal mouse_over_socket(inv_socket_mouse_event)
signal mouse_out_socket(inv_socket_mouse_event)

signal mouse_down_on_socket(inv_socket_mouse_event)

const CNAME: String = "Inventory"

#######################################################################################################################
### "Public" properties
# Cell drawing size, in pixels
export var cell_width: int = 32 setget set_cell_width
export var cell_height: int = 32 setget set_cell_height


#######################################################################################################################
### "Public" functions

### Must be overridden by derived classes
# This function is meant to calculate the drawing sizes
func _calculate_layout() -> void:
	pass

# This function must return how much of the stack has been added.
func _add_item(_idata: Dictionary) -> int:
	return 0

# Each Control may have different operations to remove an item from it. So, derived classes must override this
func _remove_item(_item: Control, _amount: int) -> void:
	pass

# Whenever an item is being dragged over this Control, this function will be called
func _dragging_over(_item: Control, _mouse_pos: Vector2) -> void:
	pass

# IF the derived control offers means to override the maximum stack, this function should be overridden giving that value
func _get_override_max_stack() -> int:
	return 0

# If the derived control contains multiple slots, it may contain some indexing. This function can be overridden to
# convert a "flat index" into "column/row" if the derived class uses that kind of distribution. By default it
# returns row 0 and column equal to the given index.
func _get_column_row(sloti: int) -> Dictionary:
	return {
		"column": sloti,
		"row": 0
	}


func _post_drop(_item: Control) -> void:
	pass

# Derived classes will most likely have to override this as those will be holding items that also must have the
# update() call. Nevertheless, this function will be called whenever a setting that is meant to affect how things
# are rendered is changed.
func _on_setting_changed() -> void:
	update()



### Other functions
func is_dragging_item() -> bool:
	if (!_shared_data):
		return false
	
	return _shared_data.is_dragging()


func get_dragged_item_data() -> Dictionary:
	var ret: Dictionary = {}
	
	if (!_shared_data):
		return ret
	
	var dragged: Control = _shared_data.get_dragged_item()
	if (dragged):
		ret = InventoryCore.item_to_dictionary(dragged, _shared_data.use_respath_on_signals())
	
	return ret


func set_cell_width(v: int) -> void:
	cell_width = v if v > 0 else 1
	_calculate_layout()


func set_cell_height(v: int) -> void:
	cell_height = v if v > 0 else 1
	_calculate_layout()


func set_dragged_item_material(mat: Material) -> void:
	if (!_shared_data.is_dragging()):
		return
	
	var ditem: Control = _shared_data.get_dragged_item()
	ditem.material = mat



func set_pick_item_mouse_button(bt: int) -> void:
	if (_shared_data):
		_set_pick_item_mouse_button(bt)
	
	else:
		call_deferred("_set_pick_item_mouse_button", bt)

func get_pick_item_mouse_button() -> int:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Pick Item Mouse Button", "get_pick_item_mouse_button", BUTTON_LEFT))
		return BUTTON_LEFT
	
	return _shared_data.pick_item_mouse_button()


func set_unsocket_item_mouse_button(bt: bool) -> void:
	if (_shared_data):
		_set_unsocket_item_mouse_button(bt)
	else:
		call_deferred("_set_unsocket_item_mouse_button", bt)

func get_unsocket_item_mouse_button() -> int:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Unsocket Item Mouse Button", "get_unsocket_item_mouse_button", BUTTON_RIGHT))
		return BUTTON_RIGHT
	
	return _shared_data.unsocket_item_mouse_button()


func set_stack_vertical_align(va: int) -> void:
	if (_shared_data):
		_set_stack_valign(va)
	else:
		call_deferred("_set_stack_valign", va)

func get_stack_vertical_align() -> int:
	if (!_shared_data):
		var k: int = InventoryCore.VAlign.Top
		push_warning(_get_set_setting_warning("Stack Size Vertical Alignment", "get_stack_vertical_align", InventoryCore.VAlign.keys()[k]))
		return k
	
	return _shared_data.stack_valign()


func set_stack_horizontal_align(ha: int) -> void:
	if (_shared_data):
		_set_stack_halign(ha)
	else:
		call_deferred("_set_stack_halign", ha)

func get_stack_horizontal_align() -> int:
	if (!_shared_data):
		var k: int = InventoryCore.HAlign.Left
		push_warning(_get_set_setting_warning("Stack Size Horizontal Alignment", "get_stack_horizontal_align", InventoryCore.HAlign.keys()[k]))
		return k
	
	return _shared_data.stack_halign()


func set_stack_size_offset(off: Vector2) -> void:
	if (_shared_data):
		_set_stack_offset(off)
	else:
		call_deferred("_set_stack_offset", off)

func get_stack_size_offset() -> Vector2:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Stack Size Offset", "get_stack_size_offset", Vector2()))
		return Vector2()
	
	return _shared_data.stack_offset()


func set_slot_autohighlight(e: bool) -> void:
	if (_shared_data):
		_set_slot_autohighlight(e)
	else:
		call_deferred("_set_slot_autohighlight", e)

func get_slot_autohighlight() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Slot Auto Highlight", "get_slot_autohighlight", true))
		return true
	
	return _shared_data.slot_autohighlight()


func set_item_autohighlight(e: bool) -> void:
	if (_shared_data):
		_set_item_autohighlight(e)
	else:
		call_deferred("_set_item_autohighlight", e)

func get_item_autohighlight() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Item Auto Highlight", "get_item_autohighlight", true))
		return true
	
	return _shared_data.item_autohighlight()


func set_draw_item_background(e: bool) -> void:
	if (_shared_data):
		_set_draw_background(e)
	else:
		call_deferred("_set_draw_background", e)

func get_draw_item_background() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Draw Item Background", "get_draw_item_background", false))
		return false
	
	return _shared_data.draw_background()


func set_interactable_disabled_items(e: bool) -> void:
	if (_shared_data):
		_set_interactable_disabled_items(e)
	else:
		call_deferred("_set_interactable_disabled_items", e)

func get_interactable_disabled_items() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Interactable Disabled Items", "get_interactable_disabled_items", true))
		return true
	
	return _shared_data.interactable_disabled_items()


func set_disabled_slots_block_items(e: bool) -> void:
	if (_shared_data):
		_set_disabled_slots_occupied(e)
	else:
		call_deferred("_set_disabled_slots_occupied", e)

func get_disabled_slots_block_items() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Disabled Slots Block Items", "get_disabled_slots_block_items", true))
		return true
	
	return _shared_data.disabled_slots_occupied()


func set_always_draw_sockets(v: bool) -> void:
	if (_shared_data):
		_set_always_draw_sockets(v)
	else:
		call_deferred("_set_always_draw_sockets", v)

func get_always_draw_sockets() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Always Draw Sockets", "get_always_draw_sockets", true))
		return true
	
	return _shared_data.always_draw_sockets()


func set_socket_draw_ratio(r: float) -> void:
	if (_shared_data):
		_set_socket_draw_ratio(r)
	else:
		call_deferred("_set_socket_draw_ratio", r)

func get_socket_draw_ratio() -> float:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Socket Draw Ratio", "get_socket_draw_ratio", 0.7))
		return 0.7
	
	return _shared_data.socket_draw_ratio()


func set_socketed_item_emit_hovered_event(e: bool) -> void:
	if (_shared_data):
		_set_socketed_item_hovered(e)
	else:
		call_deferred("_set_socketed_item_hovered", e)

func get_socketed_item_emit_hovered() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Socketed Item Emit Hovered Event", "get_socketed_item_emit_hovered", true))
		return true
	
	return _shared_data.socketed_item_emit_hovered()


func set_auto_hide_mouse(e: bool) -> void:
	if (_shared_data):
		_set_autohide_cursor(e)
	else:
		call_deferred("_set_autohide_cursor", e)

func get_auto_hide_mouse() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Auto Hide Mouse", "get_auto_hide_mouse", true))
		return true
	
	return _shared_data.auto_hide_cursor()


func set_drop_on_existing_stack(m: int) -> void:
	if (_shared_data):
		_set_drop_mode(m)
	else:
		call_deferred("_set_drop_mode", m)

func get_drop_on_existing_stack() -> int:
	if (!_shared_data):
		var k: int = InventoryCore.DropMode.FillOnly
		push_warning(_get_set_setting_warning("Drop On Existing Stack", "get_drop_on_existing_stack", InventoryCore.DropMode.keys()[k]))
		return k
	
	return _shared_data.drop_mode()


func set_inherit_preview_size(ps: bool) -> void:
	if (_shared_data):
		_set_inherit_preview_size(ps)
	else:
		call_deferred("_set_inherit_preview_size", ps)

func get_inherit_preview_size() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Inherit Preview Size", "get_inherit_preview_size", false))
		return false
	
	return _shared_data.inherit_preview_size()


func set_preview_cell_width(w: int) -> void:
	if (_shared_data):
		_set_preview_cell_width(w)
	else:
		call_deferred("_set_preview_cell_width", w)

func get_preview_cell_width() -> int:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Preview Cell Width", "get_preview_cell_width", 32))
		return 32
	
	return _shared_data.preview_cell_width()


func set_preview_cell_height(h: int) -> void:
	if (_shared_data):
		_set_preview_cell_height(h)
	else:
		call_deferred("_set_preview_cell_height", h)

func get_preview_cell_height() -> int:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Preview Cell Height", "get_preview_cell_height", 32))
		return 32
	
	return _shared_data.preview_cell_height()


func set_hide_sockets_on_drag_preview(e: bool) -> void:
	if (_shared_data):
		_set_hide_sockets_on_drag(e)
	else:
		call_deferred("_set_hide_sockets_on_drag", e)

func get_hide_sockets_on_drag_preview() -> bool:
	if (!_shared_data):
		push_warning(_get_set_setting_warning("Hide Sockets On Drag Preview", "get_hide_sockets_on_drag_preview", false))
		return false
	
	return _shared_data.hide_sockets_on_drag()


#######################################################################################################################
### "Private" definitions
class _DropData:
	var can_drop: bool = false
	var at_column: int = -1
	var at_row: int = -1
	var swap: Control = null
	var add: Control = null
	
	func clear() -> void:
		can_drop = false
		at_column = -1
		at_row = -1
		swap = null
		add = null

#######################################################################################################################
### "Private" properties

# "Static" property. This will be "shared" throughout the various inventory objects
var _shared_data: CanvasLayer = null

# Hold a reference to the theme
var _use_theme: Theme = null

# If the mouse button is pressed over and item, this will hold that item. It will then later be used to properly
# detect clicks and moves. 
var _picking: Control

# But if the mouse button does not correspond to the "pick item", then this will be set instead
var _downat: Control

var _drop_data: _DropData

#######################################################################################################################
### "Private" functions
func _init_static_data() -> void:
	# During the editor some checks done within the "get_static_data" will return true when they should not. So
	# just bail.
	if (Engine.is_editor_hint()):
		return
	
	_shared_data = InventoryCore.get_static_data(get_tree().get_root())
	
	_shared_data.register_item_holder(self)


# Centralized place to check if the given item data contains the necessary fields and use default values
# when optional ones are not given. Returns a new dictionary in order to avoid problems with further
# manipulations as those are given as references
func _check_item_data(idata: Dictionary) -> Dictionary:
	# Item ID is required
	var iid: String = idata.get("id", "")
	if (iid.empty()):
		push_warning("Checking item data but its 'id' empty")
		return {}
	
	# If the type is not give, default it to 0
	var itype: int = idata.get("type", 0)
	
	# Datacode is optional although still used to identify the item if it's provided. Nevertheless, default
	# to empty string
	var dcode: String = idata.get("datacode", "")
	
	# Icon is required
	var icon: Texture = idata.get("icon", null)
	if (!icon):
		push_warning("Checking item data (type: %s | id: %s). Its icon is invalid." % [itype, iid])
		return {}
	
	# Item background is optional and will default to null
	var background: Texture = idata.get("background", null)
	
	# Obtain custom material. It is optional
	var mat: Material = idata.get("material", null)
	if (mat):
		if (mat is CanvasItemMaterial || mat is ShaderMaterial):
			# Was simply unable to perform a negated "is"...
			pass
		else:
			push_warning("The provided material must be either CanvasItemMaterial or ShaderMaterial. So, setting it to null")
			mat = null
	
	
	var cspan: int = idata.get("column_span", 1)
	var rspan: int = idata.get("row_span", 1)
	
	if (cspan < 1):
		push_warning("Checking item data (type: %s | id: %s). Its column span (%s) is invalid. Setting to 1" % [itype, iid, cspan])
		cspan = 1
	if (rspan < 1):
		push_warning("Checking item data (type: %s | id: %s). Its row span (%s) is invalid. Setting to 1" % [itype, iid, rspan])
		rspan = 1
	
	var stack: int = idata.get("stack", 1)
	var mstack: int = idata.get("max_stack", 1)
	
	if (stack < 1):
		push_warning("Checking item data (type: %s | id: %s). Its stack (%s) can't be zero or negative. Setting to 1" % [itype, iid, stack])
		stack = 1
	if (mstack < 1):
		push_warning("Checking item data (type: %s | id: %s). Its maximum stack (%s) can't be zero or negative. Setting to 1" % [itype, iid, mstack])
		mstack = 1
	
	# While this may not be useful for the inventory bag, it is necessary for the special slot when the slot linking system is used
	# But because it is optional, default to "None" (the linked slot is not used)
	var linked: int = idata.get("use_linked", InventoryCore.LinkedSlotUse.None)
	
	# Obtain the socket mask. If it's not provided, default to 0, which means non socketable item
	var smask: int = idata.get("socket_mask", 0)
	
	# Enabled state is optional and will default to true
	var enabled: bool = idata.get("enabled", true)
	
	# Desired number of "columns" to distribute the sockets is optional and will default to the same value of column span
	var socket_cols: int = idata.get("socket_columns", cspan)
	
	# Socket data is optional and will default to empty array, meaning no socket at all
	var sockets: Array = idata.get("socket_data", [])
	
	# Do not allow stackable items to also have sockets.
	if (mstack > 1 && sockets.size() > 0):
		push_warning("Item type %s, with id %s is set to be stackable. Because of that it cannot have sockets, so removing them." % [itype, iid])
		sockets.clear()
	
	# FIXME: If there is any socket data, must check if it contains the necessary information
	
	# Highlight is optional and if given then it will be considered as manual highlight. If not given, it will be set to "none"
	var highlight: int = idata.get("highlight", InventoryCore.HighlightType.None)
	var hlman: bool = highlight != InventoryCore.HighlightType.None
	
	return {
		"id": iid,
		"type": itype,
		"datacode": dcode,
		"icon": icon,
		"background": background,
		"column_span": cspan,
		"row_span": rspan,
		"stack": stack,
		"max_stack": mstack,
		
		"use_linked": linked,
		
		"socket_mask": smask,
		
		"enabled": enabled,
		
		"material": mat,
		
		"socket_columns": socket_cols,
		"socket_data": sockets,
		
		"highlight_type": highlight,
		"highlight_manual": hlman,
	}



# This function is meant to copy style box properties that are relevant to the
# default inventory bag theme
func _copy_stylebox(src: StyleBoxTexture) -> StyleBoxTexture:
	var retval: StyleBoxTexture = StyleBoxTexture.new()
	
	retval.content_margin_top = src.content_margin_top
	retval.content_margin_bottom = src.content_margin_bottom
	retval.content_margin_left = src.content_margin_left
	retval.content_margin_right = src.content_margin_right
	
	retval.texture = src.texture
	retval.region_rect = src.region_rect
	
	retval.margin_top = src.margin_top
	retval.margin_bottom = src.margin_bottom
	retval.margin_left = src.margin_left
	retval.margin_right = src.margin_right
	
	retval.draw_center = src.draw_center
	
	return retval


func _check_theme() -> void:
	# Try to recursively obtain the first valid theme
	_use_theme = get_theme()
	var cparent: Control = get_parent_control()
	while (!_use_theme && cparent):
		_use_theme = cparent.get_theme()
		cparent = cparent.get_parent_control()
	
		# If still not valid, create a new one
	if (!_use_theme):
		_use_theme = Theme.new()
	
		# Obtain some "base" objects that will be used to build the default theme
	var font: Font = get_font("font", "LineEdit")
	var normal_box: StyleBoxTexture = get_stylebox("normal", "LineEdit")
	var ihl_box: StyleBoxTexture = StyleBoxTexture.new()
	ihl_box.margin_left = 4
	ihl_box.margin_right = 4
	ihl_box.margin_top = 4
	ihl_box.margin_bottom = 4
	ihl_box.texture = load("res://addons/keh_ui/inventory/ihighlight.png")
	ihl_box.region_rect = Rect2(0, 0, 16, 16)
	
	
	# This will be for the normal slot drawing style
	if (!_use_theme.has_stylebox("slot", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(normal_box)
		_use_theme.set_stylebox("slot", CNAME, defstyle)
	
	# If desired, a slot can receive the "normal" highlight. The auto highlight will not use it
	if (!_use_theme.has_stylebox("slot_normal_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(normal_box)
		defstyle.modulate_color = Color(0.85, 0.85, 0.85, 1.0)
		_use_theme.set_stylebox("slot_normal_highlight", CNAME, defstyle)
	
	# Slots can have "allow highlight". Basically thos are painted in a greenish color modulation
	if (!_use_theme.has_stylebox("slot_allow_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(normal_box)
		defstyle.modulate_color = Color(0.1, 0.95, 0.1, 1.0)
		_use_theme.set_stylebox("slot_allow_highlight", CNAME, defstyle)
	
	# Slots can have "deny highlight". Basically they are painted with a redish color modulation
	if (!_use_theme.has_stylebox("slot_deny_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(normal_box)
		defstyle.modulate_color = Color(0.95, 0.1, 0.1, 1.0)
		_use_theme.set_stylebox("slot_deny_highlight", CNAME, defstyle)
	
	if (!_use_theme.has_stylebox("slot_disabled_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(normal_box)
		defstyle.modulate_color = Color(0.75, 0.75, 0.75, 1.0)
		_use_theme.set_stylebox("slot_disabled_highlight", CNAME, defstyle)
	
	
	# Items can be individually highlighted, using the same enumerated types
	if (!_use_theme.has_stylebox("item_normal_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(ihl_box)
		defstyle.modulate_color = Color(0.7, 0.7, 0.7, 0.7)
		_use_theme.set_stylebox("item_normal_highlight", CNAME, defstyle)
	
	if (!_use_theme.has_stylebox("item_allow_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(ihl_box)
		defstyle.modulate_color = Color(0.2, 0.7, 0.2, 0.7)
		_use_theme.set_stylebox("item_allow_highlight", CNAME, defstyle)
	
	if (!_use_theme.has_stylebox("item_deny_highlight", CNAME)):
		var defstyle: StyleBoxTexture = _copy_stylebox(ihl_box)
		defstyle.modulate_color = Color(0.7, 0.2, 0.2, 0.7)
		_use_theme.set_stylebox("item_deny_highlight", CNAME, defstyle)
	
	if (!_use_theme.has_stylebox("item_disabled_highlight", CNAME)):
		_use_theme.set_stylebox("item_disabled_highlight", CNAME, null)
	
	# Stack size Font
	if (!_use_theme.has_font("stack_size", CNAME)):
		_use_theme.set_font("stack_size", CNAME, font)
	
	
	if (!_use_theme.has_color("item_normal", CNAME)):
		_use_theme.set_color("item_normal", CNAME, Color(1.0, 1.0, 1.0, 1.0))
	
	if (!_use_theme.has_color("item_hover", CNAME)):
		# When item is hovered by the mouse, slightly darken its color
		_use_theme.set_color("item_hover", CNAME, Color(0.75, 0.75, 0.75, 1.0))
	
	if (!_use_theme.has_color("item_ghost", CNAME)):
		_use_theme.set_color("item_ghost", CNAME, Color(1.0, 1.0, 1.0, 0.35))
	
	if (!_use_theme.has_color("item_disabled", CNAME)):
		_use_theme.set_color("item_disabled", CNAME, Color(0.75, 0.75, 0.75, 0.35))
	
	# Stack size Color
	if (!_use_theme.has_color("stack_size", CNAME)):
		_use_theme.set_color("stack_size", CNAME, Color(0.8, 0.8, 0.8, 1.0))


func _get_set_setting_warning(sname: String, fname: String, dval) -> String:
	var ret: String = "Trying to retrieve \"%s\" setting, but the system isn't fully initialized yet. Consider deferring any code that requires %s(). Returning default value: '%s'"
	return ret % [sname, fname, dval]

func _intclamp(v: int, vmin: int, vmax: int) -> int:
	return (vmin if v < vmin else (vmax if v > vmax else v))


func _build_idata(item: Control, on_socket: bool) -> Dictionary:
	assert(item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
	var retval: Dictionary = InventoryCore.item_to_dictionary(item, _shared_data.use_respath_on_signals())
	if (!on_socket):
		var crow: Dictionary = _get_column_row(item.get_slot())
		retval["column"] = crow.column
		retval["row"] = crow.row
	
	return retval


func _create_mouse_event(item: Control, on_socket: bool, mdata: Dictionary = {}) -> InventoryEventMouse:
	var evt: InventoryEventMouse = InventoryEventMouse.new(_build_idata(item, on_socket), self)
	
	evt.local_mouse_position = get_local_mouse_position()
	evt.global_mouse_position = get_global_mouse_position()
	evt.is_dragging = _shared_data.is_dragging()
	
	if (evt.is_dragging):
		var dragged: Control = _shared_data.get_dragged_item()
		evt.is_dragged_equal = dragged.is_equal(evt.item_data.id, evt.item_data.type, evt.item_data.datacode)
	
	evt.button_index = mdata.get("button", 0)
	evt.shift = mdata.get("shift", false)
	evt.control = mdata.get("control", false)
	evt.alt = mdata.get("alt", false)
	evt.command = mdata.get("command", false)
	
	return evt


func _create_container_event(item: Control, amount: int) -> InventoryEventContainer:
	var evt: InventoryEventContainer = InventoryEventContainer.new(_build_idata(item, false), self)
	evt.amount = amount
	
	return evt


func _create_socket_event(item: Control, sowner: Control, info: Dictionary) -> InventoryEventSocket:
	# For this kind of event the item is indeed on a socket and the "socket owner" obviously isn't.
	var idata: Dictionary = _build_idata(item, true)
	var odata: Dictionary = _build_idata(sowner, false)
	
	var evt: InventoryEventSocket = InventoryEventSocket.new(idata, self, odata)
	evt.mask = info.mask
	evt.index = info.index
	
	return evt


func _create_socket_mouse_event(item: Control, sowner: Control, info: Dictionary, mdata: Dictionary) -> InventoryEventSocketMouse:
	var idata: Dictionary = _build_idata(item, true) if item else {}
	var odata: Dictionary = _build_idata(sowner, false)
	
	var evt: InventoryEventSocketMouse = InventoryEventSocketMouse.new(idata, self, odata)
	evt.mask = info.mask
	evt.index = info.index
	
	evt.local_mouse_position = mdata.local_mouse_position
	evt.global_mouse_position = mdata.global_mouse_position
	evt.is_dragging = _shared_data.is_dragging()
	
	if (evt.is_dragging):
		var dragged: Control = _shared_data.get_dragged_item()
		evt.dragged_socket_mask = dragged.get_socket_mask()
	
	evt.button_index = mdata.get("button", 0)
	evt.shift = mdata.get("shift", false)
	evt.control = mdata.get("control", false)
	evt.alt = mdata.get("alt", false)
	evt.command = mdata.get("command", false)
	
	
	return evt



func _pick_item(amount: int) -> void:
	assert(_picking)
	
	var max_pick: int = _picking.get_max_stack()
	
	if (amount < 1):
		amount = _picking.get_current_stack()
	
	if (amount > max_pick):
		amount = InventoryCore.intmin(_picking.get_current_stack(), max_pick)
	
	var dragged: Control = _shared_data.get_dragged_item()
	if (dragged):
		if (!_picking.is_equal(dragged.get_id(), dragged.get_type(), dragged.get_datacode())):
			_picking = null
			return
		
		var remaining: int = dragged.remaining_stack()
		amount = InventoryCore.intmin(remaining, amount)
		amount = InventoryCore.intmin(amount, _picking.get_current_stack())
		
		_shared_data.delta_dragged_stack(amount)
	
	else:
		# Start the custom drag&drop operation
		_shared_data.start_drag(_picking, amount)
	
	if (amount > 0):
		# Item must be removed from the Control
		_remove_item(_picking, amount)
		
		_notify_item_picked(_shared_data.get_dragged_item(), amount)
		
		_drop_data.add = null
		_drop_data.swap = null
	
	# Because it was already picked, nullify the internal variable
	_picking = null



func _drop_item() -> void:
	assert(_shared_data.is_dragging())
	
	if (!_drop_data.can_drop):
		_notify_item_drop_denied(_shared_data.get_dragged_item())
		return
	
	var swap: Control = _drop_data.swap
	var add: Control = _drop_data.add
	var idata: Dictionary = InventoryCore.item_to_dictionary(_shared_data.get_dragged_item(), false)
	idata["column"] = _drop_data.at_column
	idata["row"] = _drop_data.at_row
	
	_drop_data.swap = null
	_drop_data.add = null
	
	var amount: int = 0
	
	if (swap):
		# NOTE: Static typing to Control rather than InventoryBase because it was leading to memory leak
		var inv: Control = swap.get_parent_control()
		if (!inv):
			return
		
		# If here the obtaining object is valid. Assert to catch errors during development
		assert(inv.get_script() == get_script())
		
		_shared_data.swap_drag(swap)
		inv._remove_item(swap, -1)
		
		amount = _add_item(idata)
	
	elif (add):
		var still_free: int = add.remaining_stack(_get_override_max_stack())
		if (still_free > 0):
			var dgstack: int = _shared_data.get_dragged_item().get_current_stack()
			var delta: int = dgstack if dgstack < still_free else still_free
			
			
			add.delta_stack(delta)
			# This will take care of ending the drag operation if dragged stack reaches 0
			_shared_data.delta_dragged_stack(-delta)
			amount = delta
			
			if (!_shared_data.is_dragging()):
				_post_drop(add)
	
	else:
		amount = idata.stack
		var remaining = _add_item(idata)
		# This will take care of ending the drag operation if dragged stack reaches 0
		_shared_data.delta_dragged_stack(-(amount - remaining))
	
	_notify_item_dropped(idata, amount)


func _handle_mouse_move(evt: InputEventMouseMotion) -> void:
	if (_shared_data.is_dragging()):
		_dragging_over(_shared_data.get_dragged_item(), evt.position)
	
	else:
		# Probably this situation will not be needed
		pass
	
	if (_picking):
		_pick_item(-1)


func _handle_mouse_button(evt: InputEventMouseButton) -> void:
	var shift: bool = evt.shift
	var ctrl: bool = evt.control
	var alt: bool = evt.alt
	var comm: bool = evt.command
	
	var has_modifier: bool = (shift || ctrl || alt || comm)
	
	var info: Dictionary = {
		"button": evt.button_index,
		"shift": shift,
		"control": ctrl,
		"alt": alt,
		"command": comm,
	}
	
	if (_shared_data.is_dragging()):
		if (evt.is_pressed()):
			if (evt.button_index == _shared_data.pick_item_mouse_button()):
				_drop_item()
				if (!_shared_data.is_dragging()):
					_notify_drag_ended()
			else:
				var hovered: Control = _shared_data.get_hovered()
				if (hovered && (_shared_data.interactable_disabled_items() || hovered.is_enabled())):
					_downat = hovered
					_notify_item_mouse_down(hovered, info)
		
		
		else:
			# This _downat value is only set if enabled state "matches" the project setting "interactable disabled items" so
			# there is no need to check that from here
			if (_downat):
				_notify_item_mouse_up(_downat, info)
				
				if (_downat == _shared_data.get_hovered()):
					var dragged: Control = _shared_data.get_dragged_item()
					info["dragging_same"] = dragged.is_equal(_downat.get_id(), _downat.get_type(), _downat.get_datacode())
					_notify_item_clicked(_downat, info)
			
			
			_downat = null
	
	else:
		# No item is being dragged
		if (evt.is_pressed()):
			var hovered: Control = _shared_data.get_hovered()
			if (hovered && !_shared_data.interactable_disabled_items() && !hovered.is_enabled()):
				hovered = null
			
			# Mouse button has been just pressed. Must check if it is over an item
			if (!has_modifier && evt.button_index == _shared_data.pick_item_mouse_button()):
				_picking = hovered
			else:
				_downat = hovered
				if (_downat):
					_notify_item_mouse_down(_downat, info)
			
		else:
			# Releasing mouse button.
			# picking and _downat are only set if correctly matching enabled state with project settings so no need
			# to check that fact in here.
			if (evt.button_index == _shared_data.pick_item_mouse_button() && _picking):
				_pick_item(-1)
			
			else:
				if (_downat):
					_notify_item_mouse_up(_downat, info)
					
					if (_downat == _shared_data.get_hovered()):
						_notify_item_clicked(_downat, info)
			
			_downat = null
			_picking = null

### "Intermediary" functions that are used to relay the call to change settings at runtime. The thing is, those
### require the _shared_data to be valid, which may not be the case depending on the moment the request is made.
### So, the "public" functions will defer the call in case the variable is still not initialized.
func _set_pick_item_mouse_button(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_pick_item_mouse_button(v)

func _set_unsocket_item_mouse_button(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_unsocket_item_mouse_button(v)

func _set_stack_valign(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_stack_valign(v)

func _set_stack_halign(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_stack_halign(v)

func _set_stack_offset(v: Vector2) -> void:
	assert(_shared_data)
	_shared_data.set_stack_offset(v)

func _set_slot_autohighlight(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_slot_autohighlight(v)

func _set_item_autohighlight(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_item_autohighlight(v)

func _set_draw_background(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_draw_background(v)

func _set_interactable_disabled_items(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_interactable_disabled_items(v)

func _set_disabled_slots_occupied(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_disabled_slots_occupied(v)

func _set_always_draw_sockets(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_always_draw_sockets(v)

func _set_socket_draw_ratio(v: float) -> void:
	assert(_shared_data)
	_shared_data.set_socket_draw_ratio(v)

func _set_socketed_item_hovered(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_socketed_item_emit_hovered(v)

func _set_autohide_cursor(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_autohide_cursor(v)

func _set_drop_mode(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_drop_mode(v)

func _set_inherit_preview_size(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_inherit_preview_size(v)

func _set_preview_cell_width(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_preview_cell_width(v)

func _set_preview_cell_height(v: int) -> void:
	assert(_shared_data)
	_shared_data.set_preview_cell_height(v)

func _set_hide_sockets_on_drag(v: bool) -> void:
	assert(_shared_data)
	_shared_data.set_hide_sockets_on_drag(v)


### Internal event notifiers
func _notify_item_hovered(item: Control, on_socket: bool) -> void:
	emit_signal("mouse_over_item", _create_mouse_event(item, on_socket))


func _notify_mouse_out_item(item: Control, on_socket: bool) -> void:
	emit_signal("mouse_out_item", _create_mouse_event(item, on_socket))


func _notify_item_mouse_down(item: Control, minfo: Dictionary) -> void:
	emit_signal("item_mouse_down", _create_mouse_event(item, false, minfo))


func _notify_item_mouse_up(item: Control, minfo: Dictionary) -> void:
	emit_signal("item_mouse_up", _create_mouse_event(item, false, minfo))


func _notify_item_clicked(item: Control, info: Dictionary) -> void:
	emit_signal("item_clicked", _create_mouse_event(item, false, info))



func _notify_item_picked(item: Control, amount: int) -> void:
	emit_signal("item_picked", _create_container_event(item, amount))


func _notify_item_dropped(idata: Dictionary, amount: int) -> void:
	var evt: InventoryEventContainer = InventoryEventContainer.new(idata, self)
	evt.amount = amount
	emit_signal("item_dropped", evt)

func _notify_item_drop_denied(item: Control) -> void:
	emit_signal("item_drop_denied", _create_container_event(item, 0))


func _notify_drag_ended() -> void:
	emit_signal("drag_ended")



func _notify_item_added(item: Control, amount: int) -> void:
	emit_signal("item_added", _create_container_event(item, amount))


func _notify_item_removed(item: Control, amount: int) -> void:
	emit_signal("item_removed", _create_container_event(item, amount))


func _notify_item_socketed(item: Control, sowner: Control, info: Dictionary) -> void:
	emit_signal("item_socketed", _create_socket_event(item, sowner, info))


func _notify_item_unsocketed(item: Control, sowner: Control, info: Dictionary) -> void:
	emit_signal("item_unsocketed", _create_socket_event(item, sowner, info))


func _notify_item_socketing_denied(item: Control, sowner: Control, info: Dictionary) -> void:
	emit_signal("item_socketing_denied", _create_socket_event(item, sowner, info))


func _notify_mouse_over_socket(item: Control, sowner: Control, info: Dictionary, mdata: Dictionary) -> void:
	emit_signal("mouse_over_socket", _create_socket_mouse_event(item, sowner, info, mdata))


func _notify_mouse_out_socket(item: Control, sowner: Control, info: Dictionary, mdata: Dictionary) -> void:
	emit_signal("mouse_out_socket", _create_socket_mouse_event(item, sowner, info, mdata))


func _notify_mouse_down_on_socket() -> void:
	emit_signal("mouse_down_on_socket")


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _gui_input(evt: InputEvent) -> void:
	# Give some time for the _shared_data to be initialized
	if (!_shared_data):
		return
	
	if (evt is InputEventMouseMotion):
		_handle_mouse_move(evt)
	
	if (evt is InputEventMouseButton):
		_handle_mouse_button(evt)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			var t: Theme = get_theme()
			if (t && t != _use_theme):
				_check_theme()
			update()


func _enter_tree() -> void:
	# The "static data" requires the tree to be complete in order to perform the initialization, so
	# deferring the call as most likely at this moment the tree is still being built
	call_deferred("_init_static_data")
	
	# Force derived classes to calculate the "layout". Mostly, things related to the drawing sizes.
	_calculate_layout()


func _exit_tree() -> void:
	if (_shared_data):
		_shared_data.unregister_item_holder(self)
	
	_shared_data = null


func _init() -> void:
	_check_theme()
	_drop_data = _DropData.new()

