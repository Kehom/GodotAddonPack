###############################################################################
# Copyright (c) 2020 Yuri Sarudiansky
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
###############################################################################

# Although Godot does offer means to implement drag & drop, that system is rather limiting to
# inventory systems. First, it enforces the usage of left mouse button to end the operation (drop).
# If force_drag() is used to start the operation with the right mouse button, it would not be possible
# to end it using the same button.
# The force_drag() does not work depending on the mouse button state meaning that if the user tries
# to drop an item on a spot that is already occupied, it becomes rather difficult (if not impossible)
# to keep the drag operation going on without causing the item preview to flicker.
# Because of that this addon implements a custom drag & drop system.
#
# The original design idea for this system was to have each item container derived from the InventoryBase to
# perform the item drawing. That approach avoid the need to create multiple instances of controls inserted
# into the tree. However, having each item being a Control itself brings the advantage of allowing those to
# have their own custom materials, which opens some interesting possibilities related to creating special
# effects on certain items.



# TODO:
# - Allow items to have tags - and provide a function (bags) to get all items with the specified tag.
# - Allow special slots to override the ProjectSetting related to socket drawing and somewhat force sockets to be shown
#   event when "always draw sockets" is disabled. This may be useful for a "crafting slot" or something like that.
# - Add an option for sockets to consume mouse events so the system can fire extra socket mouse events
# - Special Slot Manager node, which will provide an interface meant to "affect" all target (likely children of the node) special slots.
# - Allow special slots to be linked to inventory bags so if an attempt to drop a "two hander" item into a linked
#   special slot where each one is holding "one handers" could result in one of the items being moved into the linked
#   bag while picking the other item.
# - Allow this system to be used with gamepads
# - Allow custom sorting functions to be used
# - Save/Load inventory bag state into/from binary data.
# - Strip out some unnecessary (default values) data from "saved state"
# - Different socket layouts besides just equaly spaced right-to-left them top-to-bottom


extends Reference
class_name InventoryCore

### Consts and Enums
const BASE_SETTING: String = "keh_addons/inventory/"
const BASE_GSETTING: String = "keh_addons/inventory/general/"
const BASE_SOCKSETTING: String = "keh_addons/inventory/socket/"
const BASE_DDSETTING: String = "keh_addons/inventory/custom_drag_&_drop/"

const MAX16: int = 0xFFFF
const MASKLOW: int = 0x0000FFFF
const MASKHIGH: int = 0xFFFF0000

const DEFAULT_SOCKET: Texture = preload("socket.png")

# Yes, the global scope does contain an enum for horizontal and vertical alignments, but those enums
# can't be used as variable export hints. Thus, repeating those here
enum HAlign { Left, Center, Right }
enum VAlign { Top, Center, Bottom }

enum FilterMode {
	# Item types in the filter list will be allowed and the rest will be denied
	AllowListed,
	# Item types in the filter list will be denied while the rest will be allowed
	DenyListed
}


enum HighlightType {
	None,
	Normal,
	Allow,
	Deny,
	Disabled,
}

enum LinkedSlotUse {
	None,
	SpanToSecondary,
	SpanToPrimary,
}

enum _ItemFlags {
	Socketable = 1,
}

enum DropMode { FillOnly, AllowSwap }



# Other inner classes in this script can't directly access "loose" static functions, however
# those can access other inner classes. So, grouping some static function in this inner class
# so the functionality can still be used if necessary
class Helper:
	static func get_bool_setting(sname: String, def: bool) -> bool:
		var retval: bool = def
		if (ProjectSettings.has_setting(sname)):
			retval = ProjectSettings.get_setting(sname)
		return retval
	
	static func get_int_setting(sname: String, def: int) -> int:
		var retval: int = def
		if (ProjectSettings.has_setting(sname)):
			retval = ProjectSettings.get_setting(sname)
		return retval
	
	static func get_float_setting(sname: String, def: float) -> float:
		var retval: float = def
		if (ProjectSettings.has_setting(sname)):
			retval = ProjectSettings.get_setting(sname)
		return retval
	
	static func get_vec2_setting(sname: String, def: Vector2) -> Vector2:
		var retval: Vector2 = def
		if (ProjectSettings.has_setting(sname)):
			retval = ProjectSettings.get_setting(sname)
		return retval
	
	
	# Godot's min() function returns a float and it triggers warnings when dealing with integers. So, using this
	# function to perform integer min()
	static func intmin(a: int, b: int) -> int:
		return a if a < b else b
	
	# The same for max()
	static func intmax(a: int, b: int) -> int:
		return a if b < a else b
	
	
	static func get_static_data(root: Node) -> _StaticData:
		assert(root)
		var helper: Node = null
		if (root.has_node("_keh_helper")):
			helper = root.get_node("_keh_helper")
		else:
			helper = Node.new()
			helper.set_name("_keh_helper")
			root.add_child(helper)
		
		var ret: _StaticData = null
		if (helper.has_node("inventory_static")):
			ret = helper.get_node("inventory_static")
		else:
			ret = _StaticData.new()
			ret.set_name("inventory_static")
			helper.add_child(ret)
		
		return ret
	
	static func calculate_stack_offset(box_size: Vector2, text: String, font: Font, halign: int, valign: int) -> Vector2:
		var retval: Vector2 = Vector2(0.0, font.get_ascent())
		var dsize: Vector2 = font.get_string_size(text)
		
		# There is no need to further change when horizontal alignment is "left"
		match halign:
			HAlign.Center:
				retval.x = (box_size.x * 0.5) - (dsize.x * 0.5)
			
			HAlign.Right:
				retval.x = box_size.x - dsize.x
		
		match valign:
			VAlign.Center:
				retval.y += (box_size.y * 0.5) - (dsize.y * 0.5)
			
			VAlign.Bottom:
				retval.y = box_size.y
		
		return retval
	
	
	static func item_to_dictionary(item: Item, res_as_path: bool) -> Dictionary:
		var retval: Dictionary = {
			"id": item.get_id(),
			"type": item.get_type(),
			"datacode": item.get_datacode(),
			"column_span": item.get_column_span(),
			"row_span": item.get_row_span(),
			"stack": item.get_current_stack(),
			"max_stack": item.get_max_stack(),
			"use_linked": item.get_linked_use(),
			"socket_mask": item.get_socket_mask(),
			"enabled": item.is_enabled(),
			"socket_columns": item.get_socket_columns(),
			"socket_data": [],
			
			"highlight_type": item._highlight.type,
			"highlight_manual": item._highlight.manual,
		}
		
		for i in item.get_socket_count():
			var isocket: ItemSocket = item.get_socket(i)
			var entry: Dictionary = {}
			entry["mask"] = isocket.socket_mask
			if (res_as_path):
				entry["image"] = isocket.image.resource_path if isocket.image else ""
			else:
				entry["image"] = isocket.image
			entry["item"] = {} if !isocket.item else item_to_dictionary(isocket.item, res_as_path)
			
			retval.socket_data.append(entry)
		
		
		if (res_as_path):
			var icon: Texture = item.get_image()
			var back: Texture = item.get_background()
			var mat: Material = item.material
			
			retval["icon"] = icon.resource_path if icon else ""
			retval["background"] = back.resource_path if back else ""
			retval["material"] = mat.resource_path if mat else ""
		
		else:
			retval["icon"] = item.get_image()
			retval["background"] = item.get_background()
			retval["material"] = item.material
		
		
		return retval
	
	
	# Given the item data in dictionary format, convert resource paths into loaded resources
	static func load_resources(idata: Dictionary) -> void:
		assert(idata.has("icon") && idata.icon is String)
		assert(idata.has("background") && idata.background is String)
		assert(idata.has("material") && idata.material is String)
		
		var icon_path: String = idata.icon
		var back_path: String = idata.background
		var mat_path: String = idata.material
		
		var icon: Texture = null if icon_path.empty() else load(icon_path)
		var back: Texture = null if back_path.empty() else load(back_path)
		var mat: Material = null if mat_path.empty() else load(mat_path)
		
		idata.icon = icon
		idata.background = back
		idata.material = mat
		
		for i in idata.socket_data.size():
			var imgpath: String = idata.socket_data[i].image
			var img: Texture = null if imgpath.empty() else load(imgpath)
			idata.socket_data[i].image = img
	
	
	# Takes a dictionary using the "internal format" and build an instance of Item
	static func dictionary_to_item(idata: Dictionary, edata: Dictionary) -> Item:
		assert(edata.has("slot") && edata.slot is int)
		assert(edata.has("theme") && edata.theme is Theme)
		assert(edata.has("box_position") && edata.box_position is Vector2)
		assert(edata.has("box_size") && edata.box_size is Vector2)
		assert(edata.has("item_position") && edata.item_position is Vector2)
		assert(edata.has("item_size") && edata.item_size is Vector2)
		assert(edata.has("item_index") && edata.item_index is int)
		
		
		var ret: Item = Item.new(idata.id, idata.type, idata.icon)
		ret.set_datacode(idata.datacode)
		ret.init_rects(edata.box_position, edata.box_size, edata.item_position, edata.item_size)
		ret.init_index(edata.slot)
		ret.init_cell_span(idata.column_span, idata.row_span)
		ret.init_stack(idata.stack, idata.max_stack)
		ret.set_container_index(edata.item_index)
		
		ret._linked = idata.use_linked
		ret.set_socket_mask(idata.socket_mask)
		ret.set_enabled(idata.enabled)
		ret.set_background(idata.background)
		
		ret._theme = edata.theme
		
		ret.material = idata.material
		
		ret._highlight.type = idata.highlight_type
		ret._highlight.manual = idata.highlight_manual
		
		ret.set_sockets(idata.socket_data, idata.socket_columns, false)
		
		# If the provided socket data also contains "socketed items", add them
		for i in idata.socket_data.size():
			var idt: Dictionary = idata.socket_data[i].get("item", {})
			if (!idt.empty()):
				ret.socket_item(dictionary_to_item(idt, edata), i)
		
		
		return ret
	
	static func create_ghost(item: Item, edata: Dictionary) -> ItemGhost:
		var retval: ItemGhost = ItemGhost.new(item)
		retval.init_rects(edata.box_position, edata.box_size, edata.item_position, edata.item_size)
		retval._theme = item._theme
		retval._shared = item._shared
		
		
		return retval



##############################################################################################################
class _DropData:
	var can_drop: bool
	var at_column: int
	var at_row: int
	var swap: Item
	var add: Item
	
	func _init() -> void:
		clear()
	
	func clear() -> void:
		can_drop = false
		at_column = -1
		at_row = -1
		swap = null
		add = null


##############################################################################################################
# This rather simple class primarily meant to help deal with both slot and item highlighting.
class Highlight:
	# This should be a value of HighlightType enum
	var type: int
	# Indicate if the value in here is part of the automatic highlighting or was manually set. Manual highlight
	# should not be overwritten by the automatic system
	var manual: bool
	
	func _init() -> void:
		type = HighlightType.None
		manual = false
	
	func set_highlight(tp: int, is_manual: bool) -> void:
		if (!is_manual && manual):
			# Again, do not allow automatic highlight to overwrite manual highlight
			return
		
		type = tp
		manual = is_manual if type != HighlightType.None else false
	
	func copy_to(h: Highlight) -> void:
		h.type = type
		h.manual = manual



##############################################################################################################
### Item Socket
# Sockets are not meant to be directly used, so making this as an internal class.
class ItemSocket extends Control:
	# Determines what can be socketed into this socket
	var socket_mask: int
	# If this is null then use "DEFAULT_SOCKET" when drawing
	var image: Texture
	# This is the array index of this socket within the owning item.
	var index: int
	# Socketed item. If null obviously this socket is not holding anything. This will not be added as a child
	# and rendering will be dealt by the socket itself
	var item: Item
	# Triggering the item hovered from the notification (mouse_enter) is not correctly working. So, the signal
	# is emitted from the mouse motion event. To avoid continuous emitting of this event, a flag is used to
	# tell when it should be given and when it should not.
	var _emit_hovered: bool = false
	
	# And cache the _StaticData, which is necessary to deal with the custom drag&drop
	var _shared: _StaticData = null
	
	func _init() -> void:
		socket_mask = 0xFFFFFFFF          # By default everything will be allowed in this socket
		image = null
		
		mouse_filter = Control.MOUSE_FILTER_PASS
	
	
	func _enter_tree() -> void:
		if (!_shared):
			_shared = Helper.get_static_data(get_tree().get_root())
	
	func _notification(what: int) -> void:
		if (!_shared):
			return
		match what:
			NOTIFICATION_MOUSE_ENTER:
				_shared.set_mouse_on_socket(true)
				
				# func _notify_mouse_over_socket(item: Item, sowner: Item, info: Dictionary, mdata: Dictionary) -> void:
				var sowner: Item = get_parent_control()   # Socket owner
				var cowner: Control = sowner.get_parent_control()   # Container owning socket owner
				if (cowner.has_method("_notify_mouse_over_socket")):
					var mdata: Dictionary = {
						"local_mouse_position": get_local_mouse_position(),
						"global_mouse_position": get_global_mouse_position(),
					}
					
					cowner.call("_notify_mouse_over_socket", item, sowner, {"mask": socket_mask, "index": index}, mdata)
				
				
			NOTIFICATION_MOUSE_EXIT:
				_shared.set_mouse_on_socket(false)
				_emit_hovered = false
				
				var sowner: Item = get_parent_control()
				var cowner: Control = sowner.get_parent_control()
				if (cowner.has_method("_notify_mouse_out_socket")):
					var mdata: Dictionary = {
						"local_mouse_position": get_local_mouse_position(),
						"global_mouse_position": get_global_mouse_position(),
					}
					
					cowner.call("_notify_mouse_out_socket", item, sowner, {"mask": socket_mask, "index": index}, mdata)
	
	
	func _gui_input(evt: InputEvent) -> void:
		if (evt is InputEventMouseButton):
			if (_handle_mouse_button(evt)):
				accept_event()
		
		if (evt is InputEventMouseMotion):
			if (item):
				accept_event()
				
				if (!_emit_hovered && _shared.socketed_item_emit_hovered()):
					var mitem: Item = get_parent_control()
					var owner: Control = mitem.get_parent_control()
					if (owner.has_method("_notify_item_hovered")):
						_emit_hovered = true
						owner.call("_notify_item_hovered", item, true)
	
	
	func _handle_mouse_button(evt: InputEventMouseButton) -> bool:
		# Calling accept_event() from this helper function does not work. So, returning true if the event must
		# be accepted and false otherwise.
		var retval: bool = false
		
		if (evt.is_pressed()):
			if (_shared.is_dragging() && evt.button_index == _shared.pick_item_mouse_button()):
				var di: Item = _shared.get_dragged_item()
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
					# FIXME: allow socketed item swaping
					can_socket = (socket_mask & di.get_socket_mask()) != 0 && !item
				
				var oitem: Item = get_parent_control()
				var ibase: Control = oitem.get_parent_control()
				
				if (can_socket):
					# NOTE: Socketed item swapping requires some additional code in here...
					
					socket_item(di)
					_shared.delta_dragged_stack(-1)
					update()
					
					if (ibase.has_method("_notify_item_socketed")):
						ibase.call("_notify_item_socketed", item, oitem, {"mask": socket_mask, "index": index})
				else:
					if (ibase.has_method("_notify_item_socketing_denied")):
						ibase.call("_notify_item_socketing_denied", di, oitem, {"mask": socket_mask, "index": index})
			
			else:
				if (!is_empty() && evt.button_index == _shared.unsocket_item_mouse_button()):
					retval = true
					
					var dragged: Item = _shared.get_dragged_item()
					if (dragged && (!dragged.is_equal(item.get_id(), item.get_type(), item.get_datacode()) || dragged.remaining_stack() <= 0)):
						# NOTE: Should a signal be given here, indicating "unsocket denied" or something like that?
						return retval
					
					var oitem: Item = get_parent_control()
					var ibase: Control = oitem.get_parent_control()
					
					# First notify mouse out socketed item
					if (ibase.has_method("_notify_mouse_out_item")):
						ibase.call("_notify_mouse_out_item", item, false)
					
					var unsocketed: Item = unsocket_item()
					if (dragged):
						_shared.delta_dragged_stack(1)
					else:
						_shared.start_drag(unsocketed, -1)
					
					# Then notify mouse over socket owner
					if (ibase.has_method("_notify_item_hovered")):
						ibase.call("_notify_item_hovered", oitem, false)
					
					# Finally, item unsocketed
					if (ibase.has_method("_notify_item_unsocketed")):
						ibase.call("_notify_item_unsocketed", item, oitem, {"mask": socket_mask, "index": index})
					
					item = null
					update()
		else:
			var info: Dictionary = {
				"shift": evt.shift,
				"control": evt.control,
				"alt": evt.alt,
				"command": evt.command,
				"has_modifier": (evt.shift || evt.control || evt.alt || evt.command),
				"button": evt.button_index,
				"mask": socket_mask,
			}
			if (item && evt.button_index != _shared.pick_item_mouse_button()):
				var oitem: Item = get_parent_control()
				var ibase: Control = oitem.get_parent_control()
				if (ibase.has_method("_notify_socketed_item_clicked")):
					ibase.call("_notify_socketed_item_clicked", item, oitem, info)
		
		return retval
	
	
	func _draw() -> void:
		var so: Item = get_parent_control()
		var dcolor: Color = Color(1.0, 1.0, 1.0, 1.0)
		
		if (!so.is_enabled()):
			var t: Theme = so._theme
			dcolor = t.get_color("item_disabled", "Inventory")
		
		var img: Texture = DEFAULT_SOCKET if !image else image
		draw_texture_rect(img, Rect2(Vector2(), rect_size), false, dcolor)
		
		# If the socket is not empty, draw the socketed item
		if (item):
			draw_texture_rect(item.get_image(), Rect2(Vector2(), rect_size), false, dcolor)
	
	func is_empty() -> bool:
		return item == null
	
	
	func can_socket(idata: Dictionary) -> bool:
		return is_empty() && (socket_mask & idata.socket_mask)
	
	
	func socket_item(i: Item) -> void:
		# NOTE: Should a mask checking be performed here?
		item = i.copy(1)
	
	func socket_idata(idata: Dictionary, theme: Theme) -> int:
		if (item):
			return idata.stack
		
		if (socket_mask & idata.socket_mask == 0):
			return idata.stack
		
		var retval: int = idata.stack - 1
		idata.stack = 1
		var sz: Vector2 = Vector2(idata.column_span * _shared.preview_cell_width(), idata.row_span * _shared.preview_cell_height())
		var edata: Dictionary = {
			"slot": 0,
			"theme": theme,
			"box_position": Vector2(),
			"box_size": sz,
			"item_position": Vector2(),
			"item_size": sz,
			"item_index": 0,
		}
		item = Helper.dictionary_to_item(idata, edata)
		return retval
	
	func unsocket_item() -> Item:
		return item
	
	
	func set_socket_mask(m: int) -> void:
		socket_mask = m
	
	func set_image(img: Texture) -> void:
		image = img
	
	func set_index(i: int) -> void:
		index = i
	
	func copy_to(dest: ItemSocket) -> void:
		dest.socket_mask = socket_mask
		dest.image = image
		dest.item = item.copy(1) if item else null
		dest._shared = _shared
		dest.index = index
	
	
	func morph(nmask: int, nimg: Texture) -> void:
		socket_mask = nmask
		image = nimg
		
		# NOTE: Should masks be verified here?
		
		update()


###############################################################################################################
### Item - This is not meant to be directly instanced so making this as inner class
class Item extends Control:
	var _id: String
	var _type: int
	var _datacode: String
	# 16 bit low = Slot index within inventory bag
	# 16 bit high = container index within the inventory bag - this will make things easier to remove items from the bag
	var _index: int
	# The icon representing the item - this will be used to draw the item within the inventory bag/special_slot
	var _icon: Texture
	# Optionally an item can have a background - it can be changed after it is placed on the slot/bag
	var _background: Texture
	# 16 bit low = column span of the item
	# 16 bit high = row span of the item
	var _cellspan: int
	# 16 bit low = current stack
	# 16 bit high = maximum stack
	# Yes, this limits the maximum stack size to 65.535
	var _stack: int
	# Indicate if this item uses linked slots
	var _linked: int
	
	# Indicate the socket mask - if this is zero then the item is considered as non socketable.
	var _socket_mask: int
	
	# Holds instances of ItemSocket
	var _socket: Array
	# Number of columns to distribute the sockets above this item
	var _socket_cols: int
	
	
	### Data used to draw the item in the correct position and size
	var _item_rect: Rect2     # On special slots it may be smaller than the rect_size
	var _theme: Theme
	var _is_hovered: bool
	var _highlight: Highlight
	
	var _enabled: bool
	
	### And some overal state is necessary to be known, so take the "StaticData"
	var _shared: _StaticData = null
	
	# If not null, this item is ghosted
	var _ghost: ItemGhost = null
	
	func _init(iid: String, itype: int, icon: Texture) -> void:
		_id = iid
		_type = itype
		_icon = icon
		_datacode = ""
		
		_is_hovered = false
		_highlight = Highlight.new()
		_enabled = true
		
		set_ignore_mouse(false)
	
	
	func _enter_tree() -> void:
		if (!_shared):
			_shared = Helper.get_static_data(get_tree().get_root())
	
	
	func _ready() -> void:
		var imevt: InputEventMouseButton = InputEventMouseButton.new()
		imevt.position = get_local_mouse_position()
		imevt.global_position = get_global_mouse_position()
		imevt.button_index = _shared.pick_item_mouse_button()
		Input.parse_input_event(imevt)
	
	
	func _exit_tree() -> void:
		if (_shared.get_hovered() == self):
			_set_mouse_out()
	
	
	func init_index(sloti: int) -> void:
		_index = 0xFFFF0000 | (sloti & MASKLOW)
	
	func init_cell_span(cspan: int, rspan: int) -> void:
		assert(cspan < MAX16 && rspan < MAX16)
		_cellspan = ((rspan << 16) & MASKHIGH)  | (cspan & MASKLOW)
	
	func init_stack(cstack: int, mstack: int) -> void:
		assert(cstack <= MAX16 && mstack <= MAX16)
		_stack = ((mstack << 16) & MASKHIGH) | (cstack & MASKLOW)
	
	
	func init_rects(bpos: Vector2, bsize: Vector2, ipos: Vector2, isize: Vector2) -> void:
		rect_position = bpos
		rect_size = bsize
		rect_min_size = bsize
		
		_item_rect = Rect2(ipos, isize)
		call_deferred("_calculate_socket_layout")
	
	
	func refresh() -> void:
		set_show_sockets(_shared.always_draw_sockets())
		
		_check_mouse_pos()
		
		update()
		
		_calculate_socket_layout()
	
	
	func _draw() -> void:
		# If there is a background and it is enabled, draw it
		if (_shared.draw_background() && _background):
			draw_texture_rect(_background, Rect2(Vector2(), rect_size), false, Color(1.0, 1.0, 1.0, 1.0))
		
		
		# Draw highlight if it's enabled or manually set
		if (_shared.item_autohighlight() || _highlight.manual):
			var hlbox: StyleBox = null
			match _highlight.type:
				HighlightType.Normal:
					hlbox = _theme.get_stylebox("item_normal_highlight", "Inventory")
				HighlightType.Allow:
					hlbox = _theme.get_stylebox("item_allow_highlight", "Inventory")
				HighlightType.Deny:
					hlbox = _theme.get_stylebox("item_deny_highlight", "Inventory")
				HighlightType.Disabled:
					hlbox = _theme.get_stylebox("item_disabled_highlight", "Inventory")
			
			if (hlbox):
				draw_style_box(hlbox, Rect2(Vector2(), rect_size))
		
		# Get the proper color modulation for the item drawing
		var icolor: Color = Color(1.0, 1.0, 1.0, 1.0)
		if (_enabled):
			icolor = _theme.get_color("item_hover", "Inventory") if _is_hovered else _theme.get_color("item_normal", "Inventory") 
		else:
			icolor = _theme.get_color("item_disabled", "Inventory")
		
		# Draw the item itself
		draw_texture_rect(_icon, _item_rect, false, icolor)
		
#		# And if this is stackable, draw current stack size
		if (get_max_stack() > 1):
			var font: Font = _theme.get_font("stack_size", "Inventory")
			var stack_color: Color = _theme.get_color("stack_size", "Inventory")
			
			var stackstr: String = str(get_current_stack())
			var stackpos: Vector2 = _shared.stack_offset()
			stackpos += Helper.calculate_stack_offset(_item_rect.size, stackstr, font, _shared.stack_halign(), _shared.stack_valign())
			draw_string(font, stackpos, stackstr, stack_color, int(rect_size.x))
	
	
	
	func _notification(what: int) -> void:
		if (!is_instance_valid(_shared)):
			return
		if (!_shared || (!_enabled && !_shared.interactable_disabled_items())):
			return
		
		match what:
			NOTIFICATION_MOUSE_ENTER:
				_set_mouse_over()
			
			NOTIFICATION_MOUSE_EXIT:
				_set_mouse_out()
	
	func _check_mouse_pos() -> void:
		if (mouse_filter == MOUSE_FILTER_IGNORE):
			return
		
		
		var r: Rect2 = Rect2(Vector2(), rect_size)
		if (r.has_point(get_local_mouse_position())):
			_set_mouse_over()
		else:
			_set_mouse_out()
	
	
	func set_enabled(v: bool) -> void:
		if (v != _enabled):
			_enabled = v
			update()
			
			for s in _socket:
				s.update()
	
	
	func is_enabled() -> bool:
		return _enabled
	
	
	func set_ignore_mouse(v: bool) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_PASS
	
	func _set_mouse_over() -> void:
		if (!_shared.is_dragging()):
			_is_hovered = true
			set_highlight(HighlightType.Normal, false)
		
		var phovered = _shared.get_hovered()
		_shared.set_hovered(self)
		if (!_shared.always_draw_sockets()):
			set_show_sockets(true)
		
		if (phovered != self):
			var owner: Control = get_parent_control()
			if (owner.has_method("_notify_item_hovered")):
				owner.call("_notify_item_hovered", self, false)
			
			update()
	
	func _set_mouse_out() -> void:
		_is_hovered = false
		set_highlight(HighlightType.None, false)
		
		var phovered = _shared.get_hovered()
		_shared.set_hovered(null)
		if (!_shared.always_draw_sockets()):
			set_show_sockets(false)
		
		if (phovered == self):
			var owner: Control = get_parent_control()
			if (owner.has_method("_notify_mouse_out_item")):
				owner.call("_notify_mouse_out_item", self, false)
			
			update()
	
	
	# Make a copy of this item, allowing a custom stack size to be set. Current stack will be used if
	# custom_stack is negative
	func copy(custom_stack: int) -> Item:
		assert(custom_stack < MAX16)
		var stack: int = get_current_stack() if custom_stack < 0 else custom_stack
		var ret: Item = Item.new(_id, _type, _icon)
		
		ret._datacode = _datacode
		ret._shared = _shared
		ret._background = _background
		ret._cellspan = _cellspan
		ret._stack = _stack
		ret.set_current_stack(stack)
		ret._linked = _linked
		ret._socket_mask = _socket_mask
		ret._theme = _theme
		ret._enabled = _enabled
		_highlight.copy_to(ret._highlight)
		
		ret.material = material
		ret._socket_cols = _socket_cols
		for i in _socket.size():
			var s: ItemSocket = ItemSocket.new()
			_socket[i].copy_to(s)
			ret._socket.append(s)
			ret.add_child(s)
		
		ret._calculate_socket_layout()
		
		return ret
	
	
	# Any new socket in here will be empty. Also, if removed sockets contain items those will be lost too.
	func set_sockets(sdata: Array, cols: int, preserve_existing: bool) -> void:
		_socket_cols = cols
		var cursize: int = _socket.size()
		var dsize: int = sdata.size()
		var need_layout: bool = false
		
		if (cursize == dsize):
			if (preserve_existing):
				return
			
			# In here just ensure the sockets match the data
			for i in cursize:
				_socket[i].set_index(i)
				_socket[i].morph(sdata[i].get("mask", 0xFFFFFFFF), sdata[i].get("image", null))
		
		
		elif (cursize < dsize):
			# Current size is smaller than the requested one, so must add sockets
			need_layout = true
			
			# First morph the existing sockets if preserve_existing is false
			if (!preserve_existing):
				for i in cursize:
					_socket[i].morph(sdata[i].get("mask", 0xFFFFFFFF), sdata[i].get("image", null))
			
			# Then add the new sockets
			var diff: int = dsize - cursize
			for i in diff:
				var index: int = cursize + i
				var nsocket: ItemSocket = ItemSocket.new()
				nsocket.set_socket_mask(sdata[index].get("mask", 0xFFFFFFFF))
				nsocket.set_image(sdata[index].get("image", null))
				nsocket.set_index(index)
				_socket.append(nsocket)
				add_child(nsocket)
		
		else:
			# Current size is bigger than the requested one, so must remove sockets
			need_layout = true
			while _socket.size() > dsize:
				_socket.back().queue_free()
				_socket.pop_back()
			
			# Morph remaining sockets if not preserving existing
			if (!preserve_existing):
				for i in _socket.size():
					_socket[i].morph(sdata[i].get("mask", 0xFFFFFFFF), sdata[i].get("image", null))
		
		
		if (need_layout):
			if (!_shared):
				# If _shared is not initialized yet, give some time before calculating the layout
				call_deferred("_calculate_socket_layout")
			else:
				_calculate_socket_layout()
	
	
	
	func set_highlight(hltype: int, is_manual: bool) -> void:
		_highlight.set_highlight(hltype, is_manual)
		
		update()
		
		if (_ghost):
			_ghost.update()
	
	
	func is_equal(id: String, type: int, datacode: String) -> bool:
		return (_id == id && _type == type && _datacode == datacode)
	
	func get_id() -> String:
		return _id
	
	func get_type() -> int:
		return _type
	
	func set_datacode(dc: String) -> void:
		_datacode = dc
	
	func get_datacode() -> String:
		return _datacode
	
	func get_slot() -> int:
		return _index & MASKLOW
	
	func set_slot(s: int) -> void:
		assert(s <= MAX16)
		_index = (_index & MASKHIGH) | (s & MASKLOW)
	
	func get_container_index() -> int:
		var ret: int = (_index & MASKHIGH) >> 16
		if (ret == 0xFFFF):
			ret = -1
		return ret
	
	func set_container_index(i: int) -> void:
		# In here reserving 0xFFFF for "not stored"
		assert(i < MAX16)
		_index = (_index & MASKLOW) | ((i << 16) & MASKHIGH)
	
	func get_image() -> Texture:
		return _icon
	
	func get_background() -> Texture:
		return _background
	
	func set_background(t: Texture) -> void:
		_background = t
		update()
		if (_ghost):
			_ghost.update()
	
	func set_mat(mat: Material) -> void:
		material = mat
		if (_ghost):
			_ghost.material = mat
	
	func get_column_span() -> int:
		return (_cellspan & MASKLOW)
	func get_row_span() -> int:
		return ((_cellspan & MASKHIGH) >> 16)
	
	
	func get_current_stack() -> int:
		return (_stack & MASKLOW)
	
	func set_current_stack(s: int) -> void:
		assert(s <= MAX16)
		_stack = (_stack & MASKHIGH) | (s & MASKLOW)
		update()
	
	func delta_stack(dt: int) -> void:
		# NOTE: In here performing "debug check (assert)" for resulting stack to be smaller than the MAX16 instead of
		#    given "max_stack". This is on purpose to allow some special cases in which the maximum stack can be
		#    overridden - maybe stash tab can hold more than in the character's inventory bag, for instance.
		var cstack: int = _stack & MASKLOW
		cstack += dt
		assert(cstack >= 0 && cstack <= MAX16)
		_stack = (_stack & MASKHIGH) | (cstack & MASKLOW)
		update()
	
	func remaining_stack(override_max: int = 0) -> int:
		var use_max: int = override_max if override_max > 0 else get_max_stack()
		return use_max - get_current_stack()
	
	func is_stack_full(override_max: int = 0) -> bool:
		var use_max: int = override_max if override_max > 0 else get_max_stack()
		return get_current_stack() >= use_max
	
	func get_max_stack() -> int:
		return ((_stack & MASKHIGH) >> 16)
	
	
	func get_linked_use() -> int:
		return _linked
	
	
	func is_socketable() -> bool:
		return _socket_mask > 0
	
	func has_socketed_item() -> bool:
		for s in _socket:
			if (!s.is_empty()):
				return true
		return false
	
	
	func socket_item(item: Item, sindex: int) -> void:
		assert(sindex >= 0 && sindex < _socket.size())
		_socket[sindex].socket_item(item)
	
	func unsocket_item(sindex: int) -> Item:
		assert(sindex >= 0 && sindex < _socket.size())
		return _socket[sindex].unsocket_item()
	
	
	func set_socket_mask(m: int) -> void:
		_socket_mask = m
	
	func get_socket_mask() -> int:
		return _socket_mask
	
	func get_socket_count() -> int:
		return _socket.size()
	
	func get_socket_columns() -> int:
		return _socket_cols
	
	func get_socket(i: int) -> ItemSocket:
		assert(i < _socket.size())
		return _socket[i]
	
	func morph_socket(i: int, sdata: Dictionary) -> void:
		assert(i >= 0 && i < _socket.size())
		
		_socket[i].morph(sdata.get("mask", 0xFFFFFFFF), sdata.get("image", null))
	
	
	func is_socket_empty(i: int) -> bool:
		assert(i >= 0 && i < _socket.size())
		return _socket[i].is_empty()
	
	
	func set_show_sockets(e: bool) -> void:
		for s in _socket:
			s.visible = e
	
	func set_socket_ignore_mouse(e: bool) -> void:
		var m: int = MOUSE_FILTER_IGNORE if e else MOUSE_FILTER_PASS
		for s in _socket:
			s.mouse_filter = m
	
	
	func _get_cell_size() -> Vector2:
		var isize: Vector2 = _item_rect.size
		return Vector2(isize.x / get_column_span(), isize.y / get_row_span())
	
	func _calculate_socket_layout() -> void:
		if (_socket_cols == 0 || !_shared):
			# If here, initialization may not be finished yet
			return
		
		var usecols: int = _socket_cols if _socket.size() > 1 else 1
		
		var rows: int = int(ceil(float(_socket.size()) / float(usecols)))
		
		var socket_size = _get_cell_size() * _shared.socket_draw_ratio()
		
		var swidth: int = int(socket_size.x * usecols)
		var sheight: int = int(socket_size.y * rows)
		
		var spacex: int = int((rect_size.x - swidth) / (usecols + 1))
		var spacey: int = int((rect_size.y - sheight) / (rows + 1))
		
		var cx: int = spacex
		var cy: int = spacey
		
		var ccol: int = 0
		for i in _socket.size():
			var s: ItemSocket = _socket[i]
			if (!s):
				return
			
			s.rect_size = socket_size
			s.rect_position = Vector2(cx, cy)
			
			cx += int(socket_size.x + spacex)
			
			ccol += 1
			if (ccol == usecols):
				ccol = 0
				cy += int(socket_size.y + spacey)
				cx = spacex
		
		if (!_shared.always_draw_sockets() && !_is_hovered):
			set_show_sockets(false)

##############################################################################################################
### Item Ghost
# Special slots may be linked and allow items to occupy both ones. In that case, a ghosted item will be
# created. It is a much simplified version of the item itself, just enough to correctly render it.
class ItemGhost extends Control:
	var img: Texture
	var main: Item
	var _item_rect: Rect2
	var _highlight: Highlight
	var _theme: Theme
	var _shared: _StaticData
	
	func _init(mi: Item) -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_highlight = mi._highlight       # The internal dictionary is now a reference to the one in the main item
		mi._ghost = self
		
		main = mi
		img = mi.get_image()
		material = mi.material
	
	func _enter_tree() -> void:
		if (!_shared):
			_shared = Helper.get_static_data(get_tree().get_root())
		
		if (mouse_filter != MOUSE_FILTER_IGNORE):
			# rect.has_point() is failing all the time so manually performing the test
			var mpos: Vector2 = get_local_mouse_position()
			
			if (mpos.x >= 0 && mpos.x <= rect_size.x && mpos.y >= 0 && mpos.y <= rect_size.y):
				main.set_highlight(HighlightType.Normal, false)
				_shared.set_hovered(main)
	
	func _draw() -> void:
		# If there is a background and it is enabled, draw it
		if (_shared.draw_background() && main._background):
			draw_texture_rect(main._background, Rect2(Vector2(), rect_size), false, Color(1.0, 1.0, 1.0, 1.0))
		
		if (_shared.item_autohighlight() || _highlight.manual):
			var hlbox: StyleBox = null
			match _highlight.type:
				HighlightType.Normal:
					hlbox = _theme.get_stylebox("item_normal_highlight", "Inventory")
				HighlightType.Allow:
					hlbox = _theme.get_stylebox("item_allow_highlight", "Inventory")
				HighlightType.Deny:
					hlbox = _theme.get_stylebox("item_deny_highlight", "Inventory")
				HighlightType.Disabled:
					hlbox = _theme.get_stylebox("item_disabled_highlight", "Inventory")
			
			if (hlbox):
				draw_style_box(hlbox, Rect2(Vector2(), rect_size))
		
		draw_texture_rect(img, _item_rect, false, _theme.get_color("item_ghost", "Inventory"))
	
	
	func init_rects(bpos: Vector2, bsize: Vector2, ipos: Vector2, isize: Vector2) -> void:
		rect_position = bpos
		rect_size = bsize
		rect_min_size = bsize
		
		_item_rect = Rect2(ipos, isize)
	
	
	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_MOUSE_ENTER:
				main._set_mouse_over()
				update()
			
			NOTIFICATION_MOUSE_EXIT:
				main._set_mouse_out()
				update()
	
	func set_highlight(hltype: int, is_manual: bool) -> void:
		_highlight.set_highlight(hltype, is_manual)
		
		update()


##############################################################################################################
### Slot
# The inventory bag will hold multiple instances of this class, mostly to cache the drawing position of each slot
class Slot:
	# Drawing position
	var posx: int
	var posy: int
	# If null then this slot does not contain any item or part of an item
	var item: Item
	
	var _highlight: Highlight
	
	
	func _init(px: int, py: int) -> void:
		set_pos(px, py)
		item = null
		
		_highlight = Highlight.new()
	
	func set_pos(px: int, py: int) -> void:
		posx = px
		posy = py
	
	func set_highlight(type: int, is_manual: bool) -> void:
		_highlight.set_highlight(type, is_manual)
	
	func render(rid: RID, size: Vector2, theme: Theme, autohle: bool) -> void:
		var rd: Rect2 = Rect2(Vector2(posx, posy), size)
		
		var stl: StyleBox = theme.get_stylebox("slot", "Inventory")
		if (autohle || _highlight.manual):
			match _highlight.type:
				HighlightType.Normal:
					stl = theme.get_stylebox("slot_normal_highlight", "Inventory")
				HighlightType.Allow:
					stl = theme.get_stylebox("slot_allow_highlight", "Inventory")
				HighlightType.Deny:
					stl = theme.get_stylebox("slot_deny_highlight", "Inventory")
				HighlightType.Disabled:
					stl = theme.get_stylebox("slot_disabled_highlight", "Inventory")
		
		if (stl):
			stl.draw(rid, rd)
	
	func is_enabled() -> bool:
		return _highlight.type != HighlightType.Disabled


###############################################################################################################
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


##############################################################################################################
# This class will be used to share data accross multiple instances of classes derived from the InventoryCore
# For a C++ programmer, think something similar to the static variables.
# Most of this data is related to the custom drag&drop code
class _StaticData extends CanvasLayer:
	# This is the node that will follow the mouse when custom drag&drop operation is happening
	var _dragnode: _DragNode = null
	# And this is the item that should follow the mouse, which will be attached to the _dragnode
	var _dragging: Item = null
	
	# If auto hide is enabled, must store the original mouse mode so it can be restored when the drag operation ends
	var _prev_mouse_mode: int = -1
	
	# Just a single item can be hovered by the mouse at the same time
	var _hovered: Item
	
	# If mouse is over a socket, this will be set to true
	var _mouse_on_socket: bool
	
	# Store here everything all the ProjectSettings data
	var _settings: Dictionary
	
	# This dictionary is used as a set rather than map. Nevertheless, each container (derived from InventoryBase) will
	# register itself within this static class when entering the tree. This will be used mostly to perform updates as
	# soon as settings are changed
	var _item_holder: Dictionary
	
	func _init() -> void:
		layer = 99999
		_settings = {
			# General Settings
			"pick_item_mbutton": Helper.get_int_setting(BASE_GSETTING + "pick_item_mouse_button", BUTTON_LEFT),
			"stack_valign": Helper.get_int_setting(BASE_GSETTING + "stack_size_vertical_alignment", 0),
			"stack_halign": Helper.get_int_setting(BASE_GSETTING + "stack_size_horizontal_alignment", 0),
			"stack_offset": Helper.get_vec2_setting(BASE_GSETTING + "stack_size_offset", Vector2()),
			"slot_autohighlight": Helper.get_bool_setting(BASE_GSETTING + "slot_auto_highlight", true),
			"item_autohighlight": Helper.get_bool_setting(BASE_GSETTING + "item_auto_highlight", true),
			"draw_background": Helper.get_bool_setting(BASE_GSETTING + "draw_item_background", false),
			"use_respath_on_events": Helper.get_bool_setting(BASE_GSETTING + "use_resource_paths_on_signals", false),
			"interactable_ditems": Helper.get_bool_setting(BASE_GSETTING + "interactable_disabled_items", true),
			"disabled_slots_occupied": Helper.get_bool_setting(BASE_GSETTING + "disabled_slots_block_items", true),
			
			# Socket settings
			"unsocket_item_mbutton": Helper.get_int_setting(BASE_SOCKSETTING + "unsocket_item_mouse_button", BUTTON_RIGHT),
			"always_draw_sockets": Helper.get_bool_setting(BASE_SOCKSETTING + "always_draw_sockets", true),
			"socket_draw_ratio": Helper.get_float_setting(BASE_SOCKSETTING + "socket_draw_ratio", 0.7),
			"socketed_item_hovered": Helper.get_bool_setting(BASE_SOCKSETTING + "socketed_item_emit_hovered_event", true),
			
			
			# Drag and Drop Settings
			"auto_hide_cursor": Helper.get_bool_setting(BASE_DDSETTING + "auto_hide_mouse", true),
			"drop_mode": Helper.get_int_setting(BASE_DDSETTING + "drop_on_existing_stack", DropMode.FillOnly),
			"inherit_preview_size": Helper.get_bool_setting(BASE_DDSETTING + "inherit_preview_size", false),
			"cell_width": Helper.get_int_setting(BASE_DDSETTING + "preview_cell_width", 32),
			"cell_height": Helper.get_int_setting(BASE_DDSETTING + "preview_cell_height", 32),
			"hide_sockets": Helper.get_bool_setting(BASE_DDSETTING + "hide_sockets_on_drag_preview", false),
		}
	
	
	func _enter_tree() -> void:
		_dragnode = _DragNode.new()
		add_child(_dragnode)
	
	func set_hovered(i: Item) -> void:
		if (_dragging && _dragging == i):
			return
		
		_hovered = i
	
	
	
	func get_hovered() -> Item:
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
	
	
	func start_drag(item: Item, amount: int) -> void:
		assert(_dragnode)
		assert(!_dragging)
		assert(item)
		
		_dragging = item.copy(amount)
		_dragging.set_ignore_mouse(true)
		_dragging.set_highlight(HighlightType.None, false)
		
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
	
	
	func swap_drag(item: Item) -> void:
		assert(_dragging)
		assert(_dragnode)
		assert(item)
		
		_dragging.queue_free()
		_dragging = item.copy(-1)
		_dragging.set_ignore_mouse(true)
		_dragging.set_highlight(HighlightType.None, false)
		
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
	
	
	
	func get_dragged_item() -> Item:
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


