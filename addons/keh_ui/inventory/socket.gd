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



#######################################################################################################################
### Signals and definitions
const DEFAULT_SOCKET: Texture = preload("socket.png")

#######################################################################################################################
### "Public" properties
func is_empty() -> bool:
	return _item == null


func can_socket(idata: Dictionary) -> bool:
	return is_empty() && (_socket_mask & idata.socket_mask)

###################################################################################################################################################################
#func get_item_data() -> Dictionary:
#	return _idata
func get_item_data() -> Dictionary:
	return InventoryCore.item_to_dictionary(_item, false) if !is_empty() else {}


func socket_idata(idata: Dictionary) -> int:
	if (!is_empty()):
		# Socket is not empty, so return the entire stack of the attempted socketing item, which means nothing inserted
		return idata.stack
	
	if (_socket_mask & idata.socket_mask == 0):
		# The socket masks doesn't mach, meaning this socket is not meant for the item being inserted here.
		return idata.stack
	
	var retval: int = idata.stack - 1
	idata.stack = 1
	var sz: Vector2 = Vector2(idata.column_span * _shared.preview_cell_width(), idata.row_span * _shared.preview_cell_height())
	var edata: Dictionary = {
		"slot": 0,
		"theme": _theme,
		"box_position": Vector2(),
		"box_size": sz,
		"item_position": Vector2(),
		"item_size": sz,
		"item_index": 0,
		"shared": _shared,
	}
	
	_socket_item(InventoryCore.dictionary_to_item(idata, edata))
	
	return retval



func unsocket_item() -> Control:
	var ret: Control = _item
	_item = null
	
	ret.visible = true
	return ret



func set_socket_mask(m: int) -> void:
	_socket_mask = m

func get_socket_mask() -> int:
	return _socket_mask


func set_image(img: Texture) -> void:
	_image = img

func get_image() -> Texture:
	return _image

func set_index(idx: int) -> void:
	_index = idx



func morph(nmask: int, nimg: Texture) -> void:
	_socket_mask = nmask
	_image = nimg
	
	# NOTE: Should masks be verified here?
	
	update()

#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
# Determines what can be socketed into this socket
var _socket_mask: int = 0xFFFFFFFF

# If this is null then use "DEFAULT_SOCKET" when drawing
var _image: Texture = null

# This is the array index of this socket within the owning item.
var _index: int

# Socketed item. If null obviously this socket is not holding anything. This will not be added as a child
# and rendering will be dealt by the socket itself
# NOTE: Static typing this to Control (item's base) in order to avoid cyclic references
var _item: Control = null


# Triggering the item hovered from the notification (mouse_enter) is not correctly working. So, the signal
# is emitted from the mouse motion event. To avoid continuous emitting of this event, a flag is used to
# tell when it should be given and when it should not.
var _emit_hovered: bool = false

# Cache the StaticData, which is necessary to deal with the custom drag & drop system
var _shared: CanvasLayer = null

# This is a copy of the _theme within the parent Item
var _theme: Theme = null

#######################################################################################################################
### "Private" functions
func _socket_item(item: Control) -> void:
	assert(_item == null)
	
	_item = item
	_item.visible = false



func _handle_mouse_button(evt: InputEventMouseButton) -> bool:
	# Calling accept_event() from this helper function does not work. So, returning true if the event must
	# be accepted and false otherwise.
	var retval: bool = false
	
	if (evt.is_pressed()):
		if (_shared.is_dragging() && evt.button_index == _shared.pick_item_mouse_button()):
			# NOTE: Static typing this to Control (item's base) to avoid cyclic references
			var di: Control = _shared.get_dragged_item()
			if (!di.is_socketable()):
				return retval
			
			var empty: bool = is_empty()
			retval = true
			
			# Assume the dragged item can be socketed
			var can_socket: bool = true
			# If dragged stack is bigger than 1 and this socket is not empty, then deny socketing.
			# This is because a drag swap in here would be rather difficult to be performed
			if (!empty && di.get_current_stack() > 1):
				can_socket = false
			else:
				can_socket = (_socket_mask & di.get_socket_mask()) != 0 && is_empty()
			
			# NOTE: Static typing this to Control (item's base) to avoid cyclic references
			var oitem: Control = get_parent_control()
			var ibase: Control = oitem.get_parent_control()
			
			if (can_socket):
				# NOTE: Socketed item swapping requires some additional code in here...
				_socket_item(di.copy(1))
				_shared.delta_dragged_stack(-1)
				update()
				
				if (ibase.has_method("_notify_item_socketed")):
					ibase.call("_notify_item_socketed", _item, oitem, {"mask": _socket_mask, "index": _index})
			
			else:
				if (ibase.has_method("_notify_item_socketing_denied")):
					ibase.call("_notify_item_socketing_denied", di, oitem, {"mask": _socket_mask, "index": _index})
		
		else:
			if (!is_empty() && evt.button_index == _shared.unsocket_item_mouse_button()):
				retval = true
				
				# NOTE: Static typing to Control (item's base) to avoid cyclic references
				var dragged: Control = _shared.get_dragged_item()
				
				if (dragged && (!dragged.is_equal(_item.get_id(), _item.get_type(), _item.get_datacode()) || dragged.remaining_stack() <= 0)):
					# NOTE: Should a signal be given here, indicating "unsocket denied" or something like that?
					return retval
				
				# NOTE: Static typing to Control to avoid cyclic references
				var oitem: Control = get_parent_control()
				var ibase: Control = oitem.get_parent_control()
				
				
				# First notify mouse out socketed item
				if (ibase.has_method("_notify_mouse_out_item")):
					ibase.call("_notify_mouse_out_item", _item, false)
				
				var unsocketed: Control = unsocket_item()
				if (dragged):
					_shared.delta_dragged_stack(1)
				
				else:
					_shared.start_drag(unsocketed, -1)
				
				# Notify mouse over socket owner
				if (ibase.has_method("_notify_item_hovered")):
					ibase.call("_notify_item_hovered", oitem, false)
				
				# Notify item unsocketed
				if (ibase.has_method("_notify_item_unsocketed")):
					ibase.call("_notify_item_unsocketed", unsocketed, oitem, { "mask": _socket_mask, "index": _index })
				
				unsocketed.free()
				update()
	
	else:
		var info: Dictionary = {
			"shift": evt.shift,
			"control": evt.control,
			"alt": evt.alt,
			"command": evt.command,
			"has_modifier": (evt.shift || evt.control || evt.alt || evt.command),
			"button": evt.button_index,
			"mask": _socket_mask,
		}
		
		if (_item && evt.button_index != _shared.pick_item_mouse_button()):
			var oitem: Control = get_parent_control()
			var ibase: Control = oitem.get_parent_control()
			
			if (ibase.has_method("_notify_socketed_item_clicked")):
				ibase.call("_notify_socketed_item_clicked", _item, oitem, info)
	
	return retval

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _draw() -> void:
	var so: Control = get_parent_control()
	var dcolor: Color = Color(1.0, 1.0, 1.0, 1.0)
	
	if (!so.is_enabled()):
		var t: Theme = so._theme
		dcolor = t.get_color("item_disabled", "Inventory")
	
	var img: Texture = DEFAULT_SOCKET if !_image else _image
	draw_texture_rect(img, Rect2(Vector2(), rect_size), false, dcolor)
	
	# If the socket is not empty, draw the socketed item
	if (_item):
		draw_texture_rect(_item.get_image(), Rect2(Vector2(), rect_size), false, dcolor)



func _gui_input(evt: InputEvent) -> void:
	if (evt is InputEventMouseButton):
		if (_handle_mouse_button(evt)):
			accept_event()
	
	if (evt is InputEventMouseMotion):
		if (_item):
			accept_event()
			
			if (!_emit_hovered && _shared.socketed_item_emit_hovered()):
				var mitem: Control = get_parent_control()
				var owner: Control = mitem.get_parent_control()
				
				if (owner.has_method("_notify_item_hovered")):
					_emit_hovered = true
					owner.call("_notify_item_hovered", _item, true)



func _notification(what: int) -> void:
	if (!_shared):
		return
	
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_shared.set_mouse_on_socket(true)
			
			# NOTE: Static typing to Control to avoid cyclic references
			var sowner: Control = get_parent_control()   # Socket owner
			var cowner: Control = sowner.get_parent_control()   # Container owning socket owner
			
			if (cowner.has_method("_notify_mouse_over_socket")):
				var mdata: Dictionary = {
					"local_mouse_position": get_local_mouse_position(),
					"global_mouse_position": get_global_mouse_position(),
				}
				
				cowner.call("_notify_mouse_over_socket", _item, sowner, {"mask": _socket_mask, "index": _index}, mdata)
		
		NOTIFICATION_MOUSE_EXIT:
			_shared.set_mouse_on_socket(false)
			_emit_hovered = false
			
			# NOTE: Static typing to Control to avoid cyclic references
			var sowner: Control = get_parent_control()
			var cowner: Control = sowner.get_parent_control()
			
			if (cowner.has_method("_notify_mouse_out_socket")):
				var mdata: Dictionary = {
					"local_mouse_position": get_local_mouse_position(),
					"global_mouse_position": get_global_mouse_position(),
				}
				
				cowner.call("_notify_mouse_out_socket", _item, sowner, {"mask": _socket_mask, "index": _index}, mdata)


func _enter_tree() -> void:
	if (!_shared):
		_shared = InventoryCore.get_static_data(get_tree().get_root())



func _exit_tree() -> void:
	if (_item):
		# No need to use queue_free() because the item is not in the tree
		_item.free()



func _init(s: CanvasLayer = null, t: Theme = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_shared = s
	_theme = t

