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
class_name InventoryCore

#######################################################################################################################
### Signals and definitions

const MAX16: int = 0xFFFF
const MASKLOW: int = 0x0000FFFF
const MASKHIGH: int = 0xFFFF0000

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

enum DropMode { FillOnly, AllowSwap }


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
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


# In order to avoid cyclic references and memory leaks the return value of this function can be the exact
# desired type (staticd.gd), so returning its base class instead
static func get_static_data(root: Node) -> CanvasLayer:
	assert(root != null)
	
	var helper: Node = root.get_node_or_null("_keh_helper")
	
	if (!helper):
		helper = Node.new()
		helper.set_name("_keh_helper")
		root.add_child(helper)
	
	var st: Script = load("res://addons/keh_ui/inventory/staticd.gd")
	
	var ret: CanvasLayer = helper.get_node_or_null("inventory_static")
	
	if (!ret):
		ret = st.new()
		ret.set_name("inventory_static")
		helper.add_child(ret)
	
	return ret


static func calculate_stack_offset(box_size: Vector2, text: String, font: Font, halign: int, valign: int) -> Vector2:
	var retval: Vector2 = Vector2(0.0, font.get_ascent())
	var dsize: Vector2 = font.get_string_size(text)
	
	# There is no need to further change when horizontal alignment is "left"
	match halign:
		HAlign.Center:
			retval.x = (box_size.x - dsize.x) * 0.5
		
		HAlign.Right:
			retval.x = box_size.x - dsize.x
	
	match valign:
		VAlign.Center:
			retval.y += (box_size.y - dsize.y) * 0.5
		
		VAlign.Bottom:
			retval.y = box_size.y
	
	return retval


# NOTE: Static typing the item to Control to avoid cyclic references
static func item_to_dictionary(item: Control, res_as_path: bool) -> Dictionary:
	assert(item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
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
		
		"highlight_type": item._highlight.get_type(),
		"highlight_manual": item._highlight.is_manual(),
	}
	
	var socket_t: Script = load("res://addons/keh_ui/inventory/socket.gd")
	
	for i in item.get_socket_count():
		var isocket: Control = item.get_socket(i)
		
		assert(isocket.get_script() == socket_t)
		
		var entry: Dictionary = {}
		entry["mask"] = isocket.get_socket_mask()
		
		if (res_as_path):
			entry["image"] = isocket.get_image().resource_path if isocket.get_image() else ""
		
		else:
			entry["image"] = isocket.get_image()
		
		var sidata: Dictionary = isocket.get_item_data()
		entry["item"] = sidata.duplicate()
		
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



# Takes a dictionary using the "internal format" and build an instance of Item (item.gd)
# NOTE: Static typing the return value to Control in order to avoid cyclic references
static func dictionary_to_item(idata: Dictionary, edata: Dictionary) -> Control:
	assert(edata.has("slot") && edata.slot is int)
	assert(edata.has("theme") && edata.theme is Theme)
	assert(edata.has("box_position") && edata.box_position is Vector2)
	assert(edata.has("box_size") && edata.box_size is Vector2)
	assert(edata.has("item_position") && edata.item_position is Vector2)
	assert(edata.has("item_size") && edata.item_size is Vector2)
	assert(edata.has("item_index") && edata.item_index is int)
	
	var ret: Control = load("res://addons/keh_ui/inventory/item.gd").new(idata.id, idata.type, idata.icon, edata.get("shared", null))
	
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
	
	ret._highlight._type = idata.highlight_type
	ret._highlight._manual = idata.highlight_manual
	
	ret.set_sockets(idata.socket_data, idata.socket_columns, false)
	
	# If the provided socket data also contains "socketed items", add them
	for i in idata.socket_data.size():
		var idt: Dictionary = idata.socket_data[i].get("item", {})
		
		if (!idt.empty()):
			ret.socket_item(idt, i)
	
	return ret



static func create_ghost(item: Control, edata: Dictionary) -> Control:
	assert(item && item.get_script() == load("res://addons/keh_ui/inventory/item.gd"))
	
	var ighost_t: Script = load("res://addons/keh_ui/inventory/itemghost.gd")
	var retval: Control = ighost_t.new(item)
	
	retval.init_rects(edata.box_position, edata.box_size, edata.item_position, edata.item_size)
	retval._theme = item._theme
	retval._shared = item._shared
	
	return retval

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
