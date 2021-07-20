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
extends InventoryBase
class_name InventorySpecialSlot, "specialslot.png"

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
# These two are necessary in order to correctly draw placed items, specially when those
# are smaller than the slot. As an example, consider an slot for weapons that uses 2 columns
# and 3 rows. The the player equips a weapon that only uses one column but all three rows.
export var column_span: int = 2 setget set_column_span
export var row_span: int = 2 setget set_row_span

# If this is set to false then actual drawing size will be calculated based on the column/row
# span and the provided cell width/height values. If set to true then cell_width and cell_height
# will be completely ignored
export var free_size: bool = false setget set_free_size

# If this is set to true then items bigger than the specified column/row span will be blocked when trying to
# add them into the slot. If false, items will be allowed but their icons will be shrinked to fit. Aspect
# ratio will be maintained but the result may not be desired.
export var block_bigger_items: bool = false

# How the filter list will work
export(InventoryCore.FilterMode) var filter_type_mode: int = InventoryCore.FilterMode.AllowListed


# A special slot can be set to be primary or secondary to another special slot. This can be used to allow
# items to occupy both linked slots. Think about a two handed weapon as an example. When the secondary
# slot is set, the primary of that other slot will be automatically set while also clearing that one's
# secondary. In other words, if a slot is set to be primary, it cannot be set as secondary to any other.
export var link_primary: NodePath = "" setget set_link_primary
export var link_secondary: NodePath = "" setget set_link_secondary

# If this value is bigger than 0 then items placed on this slot will use it as the maximum stack size
# rather than the one specified in the item. This is useful for specialized stash slots where the player
# could store much bigger stacks of a specific item.
export var override_max_stack: int = 0

#######################################################################################################################
### "Public" functions
func get_item_data(res_as_path: bool = true) -> Dictionary:
	var retval: Dictionary = {}
	
	var item: Control = _get_item()
	if (item):
		retval = InventoryCore.item_to_dictionary(item, res_as_path)
	
	return retval


func add_to_filter(itype: int) -> void:
	# Again, the value is irrelevant since the dictionary is used as a set rather than map
	_filter_list[itype] = 0

func is_filtered(itype: int) -> bool:
	return _filter_list.has(itype)

func remove_from_filter(itype: int) -> void:
	# warning-ignore:return_value_discarded
	_filter_list.erase(itype)


func set_filter_function(obj: Object, fname: String) -> void:
	if (!obj):
		_filter_function = null
	else:
		_filter_function = funcref(obj, fname)


func add_item(item_data: Dictionary) -> void:
	var idata: Dictionary = _check_item_data(item_data)
	if (idata.empty()):
		return
	
	item_data.stack = _add_item(idata)




func remove_item(amount: int = -1) -> void:
	if (amount == 0):
		return
	
	var item: Control = _get_item()
	if (!item):
		return
	
	_remove_item(item, amount)


func pick_item(amount: int = -1) -> void:
	if (!_slot.item):
		return
	
	_picking = _slot.item
	_pick_item(amount)


func set_item_datacode(dcode: String) -> void:
	var item: Control = _get_item()
	if (item):
		item.set_datacode(dcode)


func set_item_enabled(enabled: bool) -> void:
	var item: Control = _get_item()
	if (item):
		item.set_enabled(enabled)


func set_item_background(back: Texture) -> void:
	var item: Control = _get_item()
	if (item):
		item.set_background(back)


func set_item_material(mat: Material) -> void:
	assert(!mat || mat is CanvasItemMaterial || mat is ShaderMaterial)
	
	var item: Control = _get_item()
	if (item):
		item.set_mat(mat)


func set_item_sockets(socket_data: Array, columns: int = -1, block_if_socketed: bool = false, preserve_existing: bool = false) -> void:
	var item: Control = _get_item()
	if (!item):
		return
	
	if (block_if_socketed && item.has_socketed_item()):
		return
	
	var cols: int = item.get_socket_columns() if columns <= 0 else columns
	item.set_sockets(socket_data, cols, preserve_existing)


func morph_item_socket(socket_index: int, socket_data: Dictionary, block_if_socketed: bool = false) -> void:
	var item: Control = _get_item()
	if (!item):
		return
	
	if (socket_index < 0 || socket_index >= item.get_socket_count()):
		return
	
	if (block_if_socketed && item.has_socketed_item()):
		return
	
	item.morph_socket(socket_index, socket_data)


func socket_into(socketi: int, idata: Dictionary) -> int:
	var checked: Dictionary = _check_item_data(idata)
	
	var item: Control = _get_item()
	if (!item):
		return checked.stack
	
	if (socketi < 0 || socketi >= item.get_socket_count()):
		return checked.stack
	
	var isocket: Control = item.get_socket(socketi)
	return isocket.socket_idata(checked)


func set_slot_highlight(hltype: int) -> void:
	if (hltype > InventoryCore.HighlightType.Deny):
		hltype = InventoryCore.HighlightType.None
	
	_slot.set_highlight(hltype, true)
	update()


func set_item_highlight(hltype: int) -> void:
	if (hltype > InventoryCore.HighlightType.Deny):
		hltype = InventoryCore.HighlightType.None
	
	var item: Control = _get_item()
	if (item):
		item.set_highlight(hltype, true)


func get_contents_as_json(use_indent: String = "   ") -> String:
	var retval: String = "\"" + get_name() + "\": "
	retval += JSON.print(get_item_data(true), use_indent)
	return retval


func load_from_parsed_json(parsed: Dictionary) -> void:
	remove_item(-1)
	if (parsed.empty()):
		return
	
	InventoryCore.load_resources(parsed)
	var idata: Dictionary = _check_item_data(parsed)
	
	for i in idata.socket_data.size():
		var isocketed: Dictionary = idata.socket_data[i].get("item", {})
		if (!isocketed.empty()):
			InventoryCore.load_resources(isocketed)
			idata.socket_data[i].item = _check_item_data(isocketed)
	
	# warning-ignore:return_value_discarded
	add_item(idata)



func set_column_span(v: int) -> void:
	column_span = v
	_calculate_layout()
	update_configuration_warning()

func set_row_span(v: int) -> void:
	row_span = v
	_calculate_layout()
	update_configuration_warning()

func set_free_size(v: bool) -> void:
	free_size = v
	_calculate_layout()

func set_link_primary(v: NodePath) -> void:
	link_primary = v
	if (!is_inside_tree() || Engine.is_editor_hint()):
		# Situation in which this will be the case and deferring the call is necessary:
		# - Just loading the project within Godot, when the tree will not be completed and linked nodes may fail to find each other
		# - Updating this script. Since it may not be fully parsed yet, it will be reported as "Control" rather than InventorySpecialSlot
		call_deferred("_check_primary")
	else:
		_check_primary()

func set_link_secondary(v: NodePath) -> void:
	link_secondary = v
	if (!is_inside_tree() || Engine.is_editor_hint()):
		call_deferred("_check_secondary")
	else:
		_check_secondary()


#######################################################################################################################
### "Private" definitions
# Only in the editor some extra lines will be drawn to help identify connected/linked slots
# On the "primary" slot a green rectangle and on the secondary a "red" rectangle.
# Then a line between the centers of both slots. These constants define the colors
const _PRIMARY_COLOR: Color = Color(0.1, 0.95, 0.1, 0.35)
const _SECONDARY_COLOR: Color = Color(0.85, 0.1, 0.1, 0.35)
const _CONNECTION_COLOR: Color = Color(0.9, 0.9, 0.9, 0.25)

#######################################################################################################################
### "Private" properties
# These two will be used to perform the drawing and will be set based on the "free_size" property
var _cell_size: Vector2

# Depending on the settings, this may be smaller than the rect_size
var _draw_size: Vector2

# Only one of these two can be set. If linked_primary is set, then the secondary will be cleared
# NOTE: Static typing those to Control in order to avoid cyclic references withi itself. In other words, this
# is primarily meant to avoid memory leak messages
var _linked_primary: Control = null
var _linked_secondary: Control = null


# This dictionary will be used as a set rather than a map. In other words, the values are irrelevant
var _filter_list: Dictionary = {}

# This function ref will be used to call a function to perform extra, custom filtering. This will be in
# addition to the filter list. The function must return true to allow the item and false to deny it.
# To this function it will be given the item ID and item type, in this order (both are integers)
# Note that this function will only be called if the filter has already "allowed" them item.
var _filter_function: FuncRef

# The Slot class contains necessary data, not to mention the auto highlight code is also there.
var _slot: InventorySlot = null


# If this is not null, then the item held in this slot is ghosted
var _ghost: Control = null


#######################################################################################################################
### "Private" functions
func _get_item() -> Control:
	if (!_slot.item && !_ghost):
		return null
	
	var ret: Control = _slot.item if _slot.item else _ghost._main
	
	return ret

func _get_edata(icspan: int, irspan: int, shrink: bool) -> Dictionary:
	var dsize: Vector2 = Vector2(cell_width * icspan, cell_height * irspan)
	
	if (shrink):
		var s1: float = _draw_size.x / dsize.x
		var s2: float = _draw_size.y / dsize.y
		
		if (s1 > s2):
			dsize *= s2
		else:
			dsize *= s1
	
	return {
		"slot": 0,
		"theme": _use_theme,
		"box_position": Vector2(),
		"box_size": _draw_size,
		"item_position": (_draw_size * 0.5) - (dsize * 0.5),
		"item_size": dsize,
		"item_index": 0,
		"shared": _shared_data
	}


func _set_item(idata: Dictionary) -> Control:
	var must_shrink: bool = (idata.column_span > column_span || idata.row_span > row_span)
	var edata: Dictionary = _get_edata(idata.column_span, idata.row_span, must_shrink)
	var retval: Control = InventoryCore.dictionary_to_item(idata, edata)
	
	_slot.item = retval
	_slot.set_highlight(InventoryCore.HighlightType.None, false)
	add_child(retval)
	update()
	return retval


func _set_ghost(item: Control) -> void:
	var must_shrink: bool = (item.get_column_span() > column_span || item.get_row_span() > row_span)
	var edata: Dictionary = _get_edata(item.get_column_span(), item.get_row_span(), must_shrink)
	_ghost = InventoryCore.create_ghost(item, edata)
	_slot.set_highlight(InventoryCore.HighlightType.None, false)
	add_child(_ghost)
	update()


# This should be called only when there is a "placed" item to be tested with a dragged item
func _check_drop_info(placed: Control, dragging: Control) -> void:
	assert(placed && dragging)
	# If items are the same type and ID:
	# - Setup for "adding to stack" if existing stack is not full. It doesn't matter what drop_mode is set to
	# - If stack is full:
	#   * Set for "swap with" if drop_mode is set to AllowSwap
	#   * Deny dropping if drop_mode is set to FillOnly
	# If items are not the same:
	# - Just setup for "swap with", regardless of what drop_mode is set to 
	if (placed.is_equal(dragging.get_id(), dragging.get_type(), dragging.get_datacode())):
		if (placed.is_stack_full(override_max_stack)):
			_drop_data.can_drop = _shared_data.drop_mode() == InventoryCore.DropMode.AllowSwap
			_drop_data.swap = placed if _drop_data.can_drop else null
		
		else:
			_drop_data.can_drop = true
			_drop_data.add = placed
	
	
	else:
		_drop_data.can_drop = true
		_drop_data.swap = placed


func _get_linked_slot() -> Control:
	if (_linked_secondary):
		return _linked_secondary
	
	if (_linked_primary):
		return _linked_primary
	
	return null




func _set_primary(path: NodePath, node: Control) -> void:
	assert(!node || node.get_script() == get_script())
	
	link_primary = path
	_linked_primary = node
	property_list_changed_notify()

func _set_secondary(path: NodePath, node: Control) -> void:
	assert(!node || node.get_script() == get_script())
	
	link_secondary = path
	_linked_secondary = node
	property_list_changed_notify()


func _check_primary() -> void:
	if (link_primary.is_empty()):
		# The given node path is empty so clear any previous linking, if any
		if (_linked_primary):
			_linked_primary._set_secondary("", null)
			if (Engine.is_editor_hint()):
				_linked_primary.update()
			_linked_primary = null
			
			# This was previously a secondary slot. Clear it
			update()
	else:
		# Setting a primary means this slot becomes secondary. Because of this, a secondary in this instance
		# must be empty. In other words, clear it if it's set
		if (_linked_secondary):
			_linked_secondary._set_primary("", null)
			if (Engine.is_editor_hint()):
				_linked_secondary.update()
			_set_secondary("", null)
		
		var node: Node = get_node_or_null(link_primary)
		if (node && node.is_class("InventorySpecialSlot")):
			_linked_primary = node
			node._set_secondary(node.get_path_to(self), self)
			
			if (Engine.is_editor_hint()):
				update()
				node.update()
		
		else:
			_set_primary("", null)


func _check_secondary() -> void:
	if (link_secondary.is_empty()):
		if (_linked_secondary):
			_linked_secondary._set_primary("", null)
			if (Engine.is_editor_hint()):
				_linked_secondary.update()
			_linked_secondary = null
	
	var node: Node = get_node_or_null(link_secondary)
	if (node && node.is_class("InventorySpecialSlot")):
		_linked_secondary = node
		node._set_primary(node.get_path_to(self), self)
		
		if (Engine.is_editor_hint()):
			update()
			node.update()
	
	else:
		_set_secondary("", null)

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _calculate_layout() -> void:
	if (free_size):
		pass
	
	else:
		_cell_size = Vector2(cell_width, cell_height)
	
	_draw_size = Vector2(_cell_size.x * column_span, _cell_size.y * row_span)
	rect_min_size = _draw_size
	
	update()


func _add_item(idata: Dictionary) -> int:
	var must_shrink: bool = (idata.column_span > column_span || idata.row_span > row_span)
	
	if (block_bigger_items && must_shrink):
		# While using the custom drag & drop system this should not happen. However code calling the public add_item()
		# may result in this.
		return 0
	
	# Assume nothing will be added
	var retval: int = idata.stack
	
	var item: Control = _get_item()
	if (item):
		if (item.is_equal(idata.id, idata.type, idata.datacode)):
			var canfit: int = item.remaining_stack(override_max_stack)
			if (canfit > 0):
				var delta: int = idata.stack if idata.stack < canfit else canfit
				retval = idata.stack - delta
				item.delta_stack(delta)
				
				if (!_shared_data.is_dragging()):
					_notify_item_added(item, delta)
	
	else:
		var canfit: int = override_max_stack if override_max_stack > 0 else idata.max_stack
		var delta: int = idata.stack if idata.stack < canfit else canfit
		retval = idata.stack - delta
		
		var luse: int = idata.use_linked
		var linked: Control = _get_linked_slot() if luse != InventoryCore.LinkedSlotUse.None else null
		
		var main_slot: Control = self
		var off_slot: Control = null
		
		if (linked):
			var is_secondary: bool = (luse == InventoryCore.LinkedSlotUse.SpanToPrimary && _linked_secondary ||
							luse == InventoryCore.LinkedSlotUse.SpanToSecondary && _linked_primary)
			
			if (!is_secondary):
				off_slot = linked
			else:
				main_slot = linked
				off_slot = self
		
		var nitem: Control = main_slot._set_item(idata)
		if (!_shared_data.is_dragging()):
			main_slot._notify_item_added(nitem, delta)
		
		if (off_slot):
			off_slot._set_ghost(nitem)
	
	return retval


# Each Control may have different operations to remove an item from it. So, derived classes must override this
func _remove_item(item: Control, amount: int) -> void:
	if (!_slot.item):
		if (!_ghost):
			return
		
		if (_ghost._main != item):
			return
	
	if (amount < 0):
		amount = item.get_current_stack()
	
	var linkuse: int = item.get_linked_use()
	var linked: Control = _get_linked_slot() if linkuse != InventoryCore.LinkedSlotUse.None else null
	
	var max_pick: int = InventoryCore.intmax(item.get_max_stack(), override_max_stack)
	var pick_amount: int = InventoryCore.intmin(amount, max_pick)
	
	item.delta_stack(-pick_amount)
	if (!_shared_data.is_dragging()):
		_notify_item_removed(item, pick_amount)
	
	
	if (item.get_current_stack() == 0):
		var mslot: Control = self
		var off_slot: Control = null
		
		if (linked):
			var is_secondary: bool = (linkuse == InventoryCore.LinkedSlotUse.SpanToPrimary && _linked_secondary ||
							linkuse == InventoryCore.LinkedSlotUse.SpanToSecondary && _linked_primary)
			
			if (!is_secondary):
				off_slot = linked
			else:
				mslot = linked
				off_slot = self
		
		mslot._slot.item.queue_free()
		mslot._slot.item = null
		mslot._ghost = null
		
		if (off_slot):
			off_slot._slot.item = null
			off_slot._ghost.queue_free()
			off_slot._ghost = null



# Whenever an item is being dragged over this Control, this function will be called
func _dragging_over(item: Control, _mouse_pos: Vector2) -> void:
	var is_in_type_list: bool = _filter_list.has(item.get_type())
	# Assume item can be dropped
	var hltype: int = InventoryCore.HighlightType.Allow
	
	var blocked: bool = false
	if (block_bigger_items):
		blocked = item.get_column_span() > column_span || item.get_row_span() > row_span
	
	var filter_allowed: bool = is_in_type_list if filter_type_mode == InventoryCore.FilterMode.AllowListed else !is_in_type_list
	var linked: Control = _get_linked_slot() if item.get_linked_use() != InventoryCore.LinkedSlotUse.None else null
	
	if (filter_allowed && _filter_function && _filter_function.is_valid()):
		filter_allowed = _filter_function.call_func(item.get_id(), item.get_type(), item.get_datacode())
	
	if (filter_allowed && !blocked):
		_drop_data.clear()
		
		if (linked):
			# Dragged item uses both slots, so must check them
			
			var placed1: Control = _slot.item
			var placed2: Control = linked._slot.item
			
			if (placed1 && placed2 && placed1 != placed2):
				_drop_data.can_drop = false
				hltype = InventoryCore.HighlightType.Deny
			
			else:
				# In here if item1 and item2 are valid, then both are the same
				var p: Control = placed1 if placed1 else placed2
				if (p):
					_check_drop_info(p, item)
				
				else:
					# Both linked slots are empty
					_drop_data.can_drop = true
		
		else:
			# Dragged item does not use linked slots, but it's possible there is a placed item that does use both
			var placed: Control = _get_item()
			
			if (placed):
				_check_drop_info(placed, item)
			
			else:
				# Slot is empty so just allow dropping
				_drop_data.can_drop = true
	
	else:
		_drop_data.can_drop = false
		hltype = InventoryCore.HighlightType.Deny
	
	
	if (item.is_socketable() && _shared_data.is_mouse_on_socket()):
		hltype = InventoryCore.HighlightType.None
	
	_slot.set_highlight(hltype, false)
	update()
	if (linked):
		linked._slot.set_highlight(hltype, false)
		linked.update()


# IF the derived control offers means to override the maximum stack, this function should be overridden giving that value
func _get_override_max_stack() -> int:
	return override_max_stack


func _post_drop(item: Control) -> void:
	_slot.set_highlight(InventoryCore.HighlightType.None, false)
	item.set_highlight(InventoryCore.HighlightType.Normal, false)
	update()


func _on_setting_changed() -> void:
	var item: Control = _get_item()
	if (item):
		item.refresh()



func _draw() -> void:
	### Editor only
	# If in editor, draw some additional stuff to help identify linked slots
	if (Engine.is_editor_hint()):
		if (_linked_secondary):
			# FIXME: properly calculate the connection line
			draw_rect(Rect2(Vector2(-0.5, -0.5), Vector2(_draw_size.x + 1, _draw_size.y + 1)), _PRIMARY_COLOR, true)
			
			var p1: Vector2 = rect_global_position + (_draw_size * 0.5)
			var p2: Vector2 = _linked_secondary.rect_global_position + _linked_secondary._draw_size
			var px: Vector2 = p2 - p1
			
			draw_line(_draw_size * 0.5, px, _CONNECTION_COLOR, 1.1, true)
		
		if (_linked_primary):
			draw_rect(Rect2(Vector2(-0.5, -0.5), Vector2(_draw_size.x + 1, _draw_size.y + 1)), _SECONDARY_COLOR, true)
	
	var autohle: bool = _shared_data.slot_autohighlight() if _shared_data else false
	
	_slot.render(get_canvas_item(), _draw_size, _use_theme, autohle)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT:
			_slot.set_highlight(InventoryCore.HighlightType.None, false)
			update()
			
			var linked: Control = _get_linked_slot()
			if (linked):
				linked._slot.set_highlight(InventoryCore.HighlightType.None, false)
				linked.update()
		
		
		NOTIFICATION_TRANSFORM_CHANGED:
			# If this is a secondary slot, the primary one must update if in editor - this is meant
			# to keep the editor drawing updated.
			# No need to check if in editor because the notification is enabled only when in this case
			if (_linked_primary):
				_linked_primary.update()
		
		
		NOTIFICATION_PATH_CHANGED, NOTIFICATION_PARENTED:
			# This node got renamed or changed its parent within the hierarchy. Because of that any
			# linking must be fixed
			if (_linked_primary):
				_linked_primary._set_secondary(_linked_primary.get_path_to(self), self)
			
			if (_linked_secondary):
				_linked_secondary._set_primary(_linked_secondary.get_path_to(self), self)


func _get_configuration_warning() -> String:
	var retval: String = ""
	
	var linked: Control = _get_linked_slot()
	if (linked):
		if (column_span != linked.column_span):
			retval = "Column span of linked slot (%s) do not match." % linked.get_name()
		
		if (row_span != linked.row_span):
			retval += "Row span on linked slot (%s) do not match." % linked.get_name()
	
	return retval



func get_class() -> String:
	return "InventorySpecialSlot"


func is_class(c: String) -> bool:
	return (c == "InventorySpecialSlot")


func _exit_tree() -> void:
	if (_linked_primary):
		_linked_primary._set_secondary("", null)
		if (Engine.is_editor_hint()):
			_linked_primary.update()
	
	if (_linked_secondary):
		_linked_secondary._set_primary("", null)
		if (Engine.is_editor_hint()):
			_linked_secondary.update()


func _init() -> void:
	if (Engine.is_editor_hint()):
		set_notify_transform(true)
	
	_slot = InventorySlot.new(0, 0)
