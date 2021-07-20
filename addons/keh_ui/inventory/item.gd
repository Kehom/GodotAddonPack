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


#######################################################################################################################
### "Public" properties



#######################################################################################################################
### "Public" functions
func set_enabled(v: bool) -> void:
	if (v != _enabled):
		_enabled = v
		update()
		
		for s in _socket:
			s.update()


func is_enabled() -> bool:
	return _enabled


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
	return _index & InventoryCore.MASKLOW

func set_slot(s: int) -> void:
	assert(s <= InventoryCore.MAX16)
	_index = (_index & InventoryCore.MASKHIGH) | (s & InventoryCore.MASKLOW)

func get_container_index() -> int:
	var ret: int = (_index & InventoryCore.MASKHIGH) >> 16
	if (ret == 0xFFFF):
		ret = -1
	return ret

func set_container_index(i: int) -> void:
	# In here reserving 0xFFFF for "not stored"
	assert(i < InventoryCore.MAX16)
	_index = (_index & InventoryCore.MASKLOW) | ((i << 16) & InventoryCore.MASKHIGH)

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
	return (_cellspan & InventoryCore.MASKLOW)

func get_row_span() -> int:
	return ((_cellspan & InventoryCore.MASKHIGH) >> 16)


func get_current_stack() -> int:
	return (_stack & InventoryCore.MASKLOW)

func set_current_stack(s: int) -> void:
	assert(s <= InventoryCore.MAX16)
	_stack = (_stack & InventoryCore.MASKHIGH) | (s & InventoryCore.MASKLOW)
	update()


func delta_stack(dt: int) -> void:
	var cstack: int = _stack & InventoryCore.MASKLOW
	cstack += dt
	
	# NOTE: In here performing "debug check (assert)" for resulting stack to be smaller than the MAX16 instead of
	#    given "max_stack". This is on purpose to allow some special cases in which the maximum stack can be
	#    overridden - maybe stash tab can hold more than in the character's inventory bag, for instance.
	assert(cstack >= 0 && cstack <= InventoryCore.MAX16)
	
	_stack = (_stack & InventoryCore.MASKHIGH) | (cstack & InventoryCore.MASKLOW)
	
	update()


func get_max_stack() -> int:
	return ((_stack & InventoryCore.MASKHIGH) >> 16)


func is_stack_full(override_max: int = 0) -> bool:
	var use_max: int = override_max if override_max > 0 else get_max_stack()
	return get_current_stack() >= use_max


func remaining_stack(override_max: int = 0) -> int:
	var use_max: int = override_max if override_max > 0 else get_max_stack()
	return use_max - get_current_stack()


func get_linked_use() -> int:
	return _linked


func is_socketable() -> bool:
	return _socket_mask > 0

func has_socketed_item() -> bool:
	for s in _socket:
		if (!s.is_empty()):
			return true
	return false


func socket_item(idata: Dictionary, sindex: int) -> void:
	assert(sindex >= 0 && sindex < _socket.size())
	
	_socket[sindex].socket_idata(idata)


# NOTE: Returning a Control (ItemSocket's base) to avoid cyclic references
func unsocket_item(sindex: int) -> Control:
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


# NOTE: Static typing the return to Control (ItemSocket's base) to avoid cyclic references
func get_socket(i: int) -> Control:
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



# Make a copy of this item, allowing a custom stack size to be set. Current stack will be used if custom_stack is negative
# NOTE: Static typing the return value to Control to avoid a problem that results in memory leak warnings when exiting the
# game/project/app....
func copy(custom_stack: int) -> Control:
	assert(custom_stack < InventoryCore.MAX16)
	
	var stack: int = get_current_stack() if custom_stack < 0 else custom_stack
	
	var ret: Control = get_script().new(_id, _type, _icon, _shared)
	
	ret._datacode = _datacode
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
	
	ret.set_sockets(get_socket_data(), _socket_cols, false)
	
	for si in _socket.size():
		var socket: Control = _socket[si]
		if (!socket.is_empty()):
			ret.socket_item(socket.get_item_data(), si)
	
	return ret



func set_highlight(hltype: int, is_manual: bool) -> void:
	_highlight.set_highlight(hltype, is_manual)
	
	update()
	
	if (_ghost):
		_ghost.update()


func set_ignore_mouse(v: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_PASS



func init_index(sloti: int) -> void:
	_index = 0xFFFF0000 | (sloti & InventoryCore.MASKLOW)

func init_cell_span(cspan: int, rspan: int) -> void:
	assert(cspan < InventoryCore.MAX16 && rspan < InventoryCore.MAX16)
	_cellspan = ((rspan << 16) & InventoryCore.MASKHIGH)  | (cspan & InventoryCore.MASKLOW)

func init_stack(cstack: int, mstack: int) -> void:
	assert(cstack <= InventoryCore.MAX16 && mstack <= InventoryCore.MAX16)
	_stack = ((mstack << 16) & InventoryCore.MASKHIGH) | (cstack & InventoryCore.MASKLOW)


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
		
		var socket_t: Script = load("res://addons/keh_ui/inventory/socket.gd")
		
		# Then add the new sockets
		var diff: int = dsize - cursize
		for i in diff:
			var index: int = cursize + i
			var nsocket: Control = socket_t.new(_shared, _theme)
			
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


func get_socket_data() -> Array:
	var ret: Array = []
	
	for si in _socket.size():
		ret.append({
			"mask": _socket[si].get_socket_mask(),
			"image": _socket[si].get_image(),
		})
	
	return ret



#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
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
var _highlight: InventoryHighlight

var _enabled: bool

### And some overal state is necessary to be known, so take the "StaticData"
var _shared: CanvasLayer = null

# If not null, this item is ghosted
# NOTE: Static typing this to Control (the base of ItemGhost) to avoid cyclic references
var _ghost: Control = null

#######################################################################################################################
### "Private" functions
func _set_mouse_over() -> void:
	if (!_shared.is_dragging()):
		_is_hovered = true
		set_highlight(InventoryCore.HighlightType.Normal, false)
	
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
	set_highlight(InventoryCore.HighlightType.None, false)
	
	var phovered = _shared.get_hovered()
	_shared.set_hovered(null)
	
	
	if (!_shared.always_draw_sockets()):
		set_show_sockets(false)
	
	if (phovered == self):
		var owner: Control = get_parent_control()
		if (owner.has_method("_notify_mouse_out_item")):
			owner.call("_notify_mouse_out_item", self, false)
		
		update()


func _get_cell_size() -> Vector2:
	var isize: Vector2 = _item_rect.size
	return Vector2(isize.x / get_column_span(), isize.y / get_row_span())


func _check_mouse_pos() -> void:
	if (mouse_filter == MOUSE_FILTER_IGNORE):
		return
	
	var r: Rect2 = Rect2(Vector2(), rect_size)
	if (r.has_point(get_local_mouse_position())):
		_set_mouse_over()
	
	else:
		_set_mouse_out()


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
		var s: Control = _socket[i]
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


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _draw() -> void:
	# If there is a background and it is enabled, draw it
	if (_shared.draw_background() && _background):
		draw_texture_rect(_background, Rect2(Vector2(), rect_size), false, Color(1.0, 1.0, 1.0, 1.0))
	
	
	# Draw highlight if it's enabled or manually set
	if (_shared.item_autohighlight() || _highlight.is_manual()):
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
		stackpos += InventoryCore.calculate_stack_offset(_item_rect.size, stackstr, font, _shared.stack_halign(), _shared.stack_valign())
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




func _ready() -> void:
	var imevt: InputEventMouseButton = InputEventMouseButton.new()
	imevt.position = get_local_mouse_position()
	imevt.global_position = get_global_mouse_position()
	imevt.button_index = _shared.pick_item_mouse_button()
	Input.parse_input_event(imevt)


func _enter_tree() -> void:
	if (!_shared):
		_shared = InventoryCore.get_static_data(get_tree().get_root())


func _exit_tree() -> void:
	if (_shared.get_hovered() == self):
		_set_mouse_out()



func _init(iid: String = "", itype: int = 0, icon: Texture = null, shared: CanvasLayer = null) -> void:
	_id = iid
	_type = itype
	_icon = icon
	_datacode = ""
	
	_is_hovered = false
	_highlight = InventoryHighlight.new()
	_enabled = true
	
	_shared = shared
	
	set_ignore_mouse(false)

