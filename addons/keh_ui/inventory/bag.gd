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
class_name InventoryBag, "bag.png"

# The bag is meant to contain multiple rows and columns of slots. Items can span
# multiple "cells" if so desired.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
export var column_count: int = 10 setget set_column_count
export var row_count: int = 4 setget set_row_count

export var cell_spacing: int = 0 setget set_cell_spacing

#######################################################################################################################
### "Public" functions
# If res_as_path is set to true then resources (textures, materials...) will be given as paths (Strings)
func get_item_data(atcol: int, atrow: int, res_as_path: bool = true) -> Dictionary:
	var retval: Dictionary = {}
	
	var item: Control = _get_item(_get_slot_index(atcol, atrow))
	if (item):
		retval = InventoryCore.item_to_dictionary(item, res_as_path)
	
	return retval


func add_item(item_data: Dictionary) -> Array:
	var retval: Array = []
	var idata: Dictionary = _check_item_data(item_data)
	if (idata.empty()):
		return retval
	
	
	var column: int = item_data.get("column", -1)
	var row: int = item_data.get("row", -1)
	
	
	if (column < 0 || row < 0):
		# If here, then column and/or row are not specified/incorrectly set. In this case try to find the best
		var vscan: bool = item_data.get("vertical_scan", false)
		
		# The scanning function (_find_fitting_spot()) allows specification of the starting column/row. This is
		# useful to avoid scanning the same slots multiple times when the incoming item stack must be split into
		# multiple spots. The variables bellow hold those starting coordinates - and will be updated
		# accordingly during the scan process.
		var scol: int = 0
		var srow: int = 0
		
		var done: bool = false
		while (!done):
			var add_at: Dictionary = {}
			
			if (idata.max_stack > 1):
				# The item is stackable, so try to locate something already in the inventory that matches this
				# item and the stack is not full
				add_at = _find_matching(idata.id, idata.type, idata.datacode, vscan)
			
			# If the item is not stackable the previous scanning will not be done, in which case the add_at
			# dictionary will be empty. If the scanning was done but didn't find any place, the column/row will
			# be set to -1. In either case must scan the slots for a spot that can fit the item.
			if (add_at.empty() || (add_at.column == -1 || add_at.row == -1)):
				add_at = _find_fitting_spot(scol, srow, idata.id, idata.type, idata.datacode, idata.column_span, idata.row_span, vscan)
				
				# Update starting column/row for the possible next iteration of the scanning
				scol = add_at.column
				srow = add_at.row
			
			
			# At this point the add_at dictionary must be holding two entries, so not going to check if it's
			# empty or not here
			if (add_at.column == -1 || add_at.row == -1):
				# OK, couldn't find a proper spot for the current stack, so end scanning
				done = true
				item_data.stack = idata.stack
			
			else:
				idata["column"] = add_at.column
				idata["row"] = add_at.row
				
				var remaining: int = _add_item(idata)
				if (remaining == idata.stack):
					# OK, nothing was added so end the loop
					done = true
					retval = idata.stack
				
				else:
					# Something was added into the stack. Update the return array
					var delta: int = idata.stack - remaining
					idata.stack -= delta
					
					retval.append({
						"column": add_at.column,
						"row": add_at.row,
						"amount": delta
					})
					
					if (idata.stack == 0):
						item_data.stack = 0
						done = true
	
	else:
		# Directly try to add the item into the specified spot
		idata["column"] = column
		idata["row"] = row
		var remaining: int = _add_item(idata)
		if (remaining < idata.stack):
			retval.append({
				"column": column,
				"row": row,
				"amount": idata.stack - remaining
			})
			item_data.stack = remaining
	
	return retval


func remove_item_from(column: int, row: int, amount: int = -1) -> void:
	if (amount == 0):
		return
	
	var sloti: int = _get_slot_index(column, row)
	var item: Control = _get_item(sloti)
	if (item):
		_remove_item(item, amount)



func pick_item_from(column: int, row: int, amount: int = -1) -> void:
	var sloti: int = _get_slot_index(column, row)
	var item: Control = _get_item(sloti)
	if (!item):
		return
	
	_picking = item
	_pick_item(amount)


func set_item_datacode(column: int, row: int, dcode: String) -> void:
	var item: Control = _get_item(_get_slot_index(column, row))
	if (item):
		item.set_datacode(dcode)


func set_item_enabled(column: int, row: int, enabled: bool) -> void:
	var item: Control = _get_item(_get_slot_index(column, row))
	if (item):
		item.set_enabled(enabled)


func set_item_background(atcolumn: int, atrow: int, back: Texture) -> void:
	var item: Control = _get_item(_get_slot_index(atcolumn, atrow))
	if (item):
		item.set_background(back)


func set_item_material(atcolumn: int, atrow: int, mat: Material) -> void:
	assert(!mat || mat is CanvasItemMaterial || mat is ShaderMaterial)
	var item: Control = _get_item(_get_slot_index(atcolumn, atrow))
	if (item):
		item.set_mat(mat)


func set_item_sockets(atcol: int, atrow: int, socket_data: Array, columns: int = -1, block_if_socketed: bool = false, preserve_existing: bool = false) -> void:
	var item: Control = _get_item(_get_slot_index(atcol, atrow))
	if (!item):
		return
	
	if (block_if_socketed && item.has_socketed_item()):
		return
	
	var cols: int = item.get_socket_columns() if columns <= 0 else columns
	
	item.set_sockets(socket_data, cols, preserve_existing)


func morph_item_socket(atcol: int, atrow: int, socket_index: int, socket_data: Dictionary, block_if_socketed: bool = false) -> void:
	var item: Control = _get_item(_get_slot_index(atcol, atrow))
	if (!item):
		return
	
	if (socket_index < 0 || socket_index >= item.get_socket_count()):
		return
	
	if (block_if_socketed && item.has_socketed_item()):
		return
	
	item.morph_socket(socket_index, socket_data)


# Add the given item into the (0-based) socket index in the item at the specified column/row.
# Return number of items not added into the socket. Or in other words, the remaining stack of the given item data.
func socket_into(atcol: int, atrow: int, socketi: int, idata: Dictionary) -> int:
	var checked: Dictionary = _check_item_data(idata)
	
	var item: Control = _get_item(_get_slot_index(atcol, atrow))
	if (!item):
		return checked.stack
	
	if (socketi < 0 || socketi >= item.get_socket_count()):
		return checked.stack
	
	var isocket: Control = item.get_socket(socketi)
	return isocket.socket_idata(checked)



func set_slot_highlight(col: int, row: int, hltype: int) -> void:
	var sloti: int = _get_slot_index(col, row)
	if (sloti < 0 || sloti >= _slot_container.size()):
		return
	
	if (hltype > InventoryCore.HighlightType.Disabled):
		hltype = InventoryCore.HighlightType.None
	
	var islot: InventorySlot = _slot_container[sloti]
	islot.set_highlight(hltype, true)
	update()


func set_item_highlight(atcol: int, atrow: int, hltype: int) -> void:
	var sloti: int = _get_slot_index(atcol, atrow)
	if (sloti < 0 || sloti >= _slot_container.size()):
		return
	
	if (hltype > InventoryCore.HighlightType.Deny):
		hltype = InventoryCore.HighlightType.None
	
	var islot: InventorySlot = _slot_container[sloti]
	if (islot.item):
		islot.item.set_highlight(hltype, true)


# This will call the given function reference for each stored item, providing the item data as argument. The
# function must return a dictionary containing information related to how the item and used slots must be
# changed. Fields are optional and if not given will set everything to "default" rendering state. The options
# are:
# - item_highlight -> Which item highlight type should be applied to the item. By default "None"
# - slot_highlight -> How the slots used by this item will be changed. By default, "None".
# - enabled -> Changes the enabled state of the item. By default it will be true.
# - material -> Change the material of the item. Defaults to null
func mass_highlight(apply_filter: FuncRef, res_as_path: bool = true) -> void:
	if (!apply_filter.is_valid()):
		return
	
	for i in _item_container.size():
		var item: Control = _item_container[i]
		var idata: Dictionary = InventoryCore.item_to_dictionary(item, res_as_path)
		var afres = apply_filter.call_func(idata)
		if (afres is Dictionary):
			item.set_highlight(afres.get("item_highlight", InventoryCore.HighlightType.None), true)
			var shltype: int = afres.get("slot_highlight", InventoryCore.HighlightType.None)
			_set_slot_highlight(item.get_slot(), shltype, item.get_column_span(), item.get_row_span(), true)
			item.set_enabled(afres.get("enabled", true))
			item.material = afres.get("material", null)


# Clear all slot highlighting, including manually ones
func clear_all_slot_highlight() -> void:
	for s in _slot_container:
		s.set_highlight(0, true)


func find_first(type: int, id: String, datacode: String = "") -> Dictionary:
	var retval: Dictionary = {
		"column": -1,
		"row": -1,
	}
	
	for i in _item_container:
		if (i.is_equal(id, type, datacode)):
			retval = _get_column_row(i.get_slot())
	
	return retval


func can_store_at(idata: Dictionary, column: int, row: int) -> bool:
	var retval: bool = false
	
	if (!idata.has("id")):
		push_warning("[can_store_at()]: Provided item data does not contain the required \"id\" (String) field.")
		return retval
	
	if (!idata.has("type")):
		push_warning("[find_spot()]: Provided item data does not contain the required \"type\" (int) field.")
		return retval
	
	if (idata.stack > idata.max_stack):
		return retval
	
	var colldata: Dictionary = _get_colliding_data(column, row, idata.id, idata.type, idata.datacode, idata.column_span, idata.row_span)
	if (!colldata.overflows && colldata.disabled_slot.size() == 0):
		if (colldata.collision_count == 0):
			retval = true
		else:
			var matched: Array = colldata.matching.keys()
			for item in matched:
				var canfit: int = item.remaining_stack()
				if (canfit > 0 && canfit <= idata.stack):
					retval = true
					break
	
	return retval


func find_spot(idata: Dictionary, vertical_scan: bool) -> Dictionary:
	var retval: Dictionary = {}
	
	if (!idata.has("id")):
		push_warning("[find_spot()]: Provided item data does not contain the required \"id\" (String) field.")
		return retval
	
	if (!idata.has("type")):
		push_warning("[find_spot()]: Provided item data does not contain the required \"type\" (int) field.")
		return retval
	
	
	var cspan: int = idata.get("column_span", 1)
	var rspan: int = idata.get("row_span", 1)
	
	var ffs_res: Dictionary = _find_fitting_spot(0, 0, idata.id, idata.type, idata.datacode, cspan, rspan, vertical_scan)
	if (ffs_res.column >= 0 && ffs_res.row >= 0):
		retval["column"] = ffs_res.column
		retval["row"] = ffs_res.row
	
	return retval


func sort_items(bigger_first: bool = true, vertical: bool = false) -> void:
	# Create an auxiliary array to hold current contents. Item locations are not necessary so setting argument to false
	var aux_container: Array = get_contents_as_dictionaries(false)
	
	# Sort the auxiliary array
	if (bigger_first):
		if (vertical):
			aux_container.sort_custom(_ItemSorter, "vert_bigger_first")
		else:
			aux_container.sort_custom(_ItemSorter, "horiz_bigger_first")
	else:
		if (vertical):
			aux_container.sort_custom(_ItemSorter, "vert_smaller_first")
		else:
			aux_container.sort_custom(_ItemSorter, "horiz_smaller_first")
	
	
	# Clear the item container
	_clear_contents()
	
	# Now add each item back into the inventory
	for idata in aux_container:
		idata["vertical_scan"] = vertical
		
		# warning-ignore:return_value_discarded
		add_item(idata)
	
	# And update so the new organization is shown
	update()


func get_items_of_type(type: int, include_position: bool = true, resource_as_path: bool = false) -> Array:
	var retval: Array = []
	
	for i in _item_container:
		var item: Control = i
		
		if (item.get_type() == type):
			var idict: Dictionary = InventoryCore.item_to_dictionary(item, resource_as_path)
			if (include_position):
				var crow: Dictionary = _get_column_row(item.get_slot())
				idict["column"] = crow.column
				idict["row"] = crow.row
			
			retval.append(idict)
	
	return retval


# Build an array where each entry is a dictionary holding item data corresponding to the contents within the inventory.
# The format of each entry will be in the exact same one that is expected by the add_item() function.
func get_contents_as_dictionaries(include_position: bool = true, resource_as_path: bool = false) -> Array:
	var retval: Array = []
	
	for i in _item_container:
		var item: Control = i
		
		var idict: Dictionary = InventoryCore.item_to_dictionary(item, resource_as_path)
		if (include_position):
			var crow: Dictionary = _get_column_row(item.get_slot())
			idict["column"] = crow.column
			idict["row"] = crow.row
		
		retval.append(idict)
	
	return retval


# Obtain a JSON formatted string corresponding to the contents of this bag. It can be directly used to restore the bag
# state. This may be very useful for a save system
# The returned format will be similar to this:
# "InventoryBagNodeName": [ CONTENTS ]
func get_contents_as_json(use_indent: String = "   ") -> String:
	var retval: String = "\"" + get_name() + "\": "
	retval += JSON.print(get_contents_as_dictionaries(true, true), use_indent)
	
	return retval


# This expects the array that is directly obtained from the get_contents_as_json() function.
func load_from_parsed_json(parsed: Array) -> void:
	_clear_contents()
	
	for rdata in parsed:
		InventoryCore.load_resources(rdata)
		var idata: Dictionary = _check_item_data(rdata)
		idata.column = rdata.column
		idata.row = rdata.row
		
		for i in idata.socket_data.size():
			var isocketed: Dictionary = idata.socket_data[i].get("item", {})
			if (!isocketed.empty()):
				InventoryCore.load_resources(isocketed)
				idata.socket_data[i].item = _check_item_data(isocketed)
		
		# warning-ignore:return_value_discarded
		add_item(idata)




# Returns true if specified amount of columns can be added, expanding the bag.
func can_add_columns(amount: int) -> bool:
	if (column_count + amount >= InventoryCore.MAX16):
		return false
	
	return true

# Returns true if specified amount of rows can be added, expanding the bag.
func can_add_rows(amount: int) -> bool:
	if (row_count + amount >= InventoryCore.MAX16):
		return false
	
	return true

func add_columns(amount: int) -> void:
	if (!can_add_columns(amount)):
		return
	
	var newcount: int = column_count + amount
	
	for i in _item_container:
		var idx: int = i.get_slot()
		# warning-ignore:integer_division
		var row: int = int(idx / column_count)
		
		var new_index: int = idx + (row * amount)
		i.set_slot(new_index)
	
	
	set_column_count(newcount)
	_verify_item_placement()



func add_rows(amount: int) -> void:
	if (!can_add_rows(amount)):
		return
	
	# Addings rows is way easier than columns. No item slot index will change
	var ncount: int = row_count + amount
	set_row_count(ncount)


# Returns the amount of columns that can be removed without loosing any item. If 0 is returned,
# then no column can be removed from the bag
func get_column_remove_count() -> int:
	var retval: int = 0
	
	for c in range(column_count-1, 0, -1):
		var index: int = c
		for r in row_count:
			if (_slot_container[index].item):
				return retval
			index += column_count
		
		retval += 1
	
	return retval

# Returns the amount of rows that can be removed without loosing any item. If 0 is returned,
# then no row can be removed from the bag
func get_row_remove_count() -> int:
	var retval: int = 0
	
	for r in range(row_count-1, 0, -1):
		var index: int = column_count * r
		for c in column_count:
			if (_slot_container[index].item):
				return retval
			index += 1
		
		retval += 1
	
	return retval


func remove_columns(amount: int) -> void:
	var can_remove: int = get_column_remove_count()
	if (amount < 0):
		amount = can_remove
	
	if (amount > can_remove):
		return
	
	var oldcount: int = column_count
	var newcount: int = column_count - amount
	
	for i in _item_container:
		var idx: int = i.get_slot()
		# warning-ignore:integer_division
		var row: int = int(idx / oldcount)
		
		var new_index: int = idx - (row * amount)
		i.set_slot(new_index)
	
	set_column_count(newcount)
	_verify_item_placement()


func remove_rows(amount: int) -> void:
	var can_remove: int = get_row_remove_count()
	if (amount < 0):
		amount = can_remove
	
	if (amount > can_remove):
		return
	
	# Removing rows is way easier than removing columns. This operation does not change any item slot index
	var new_rowcount: int = row_count - amount
	set_row_count(new_rowcount)


func set_column_count(v: int) -> void:
	column_count = _intclamp(v, 0, InventoryCore.MAX16-1)
	_calculate_layout()

func set_row_count(v: int) -> void:
	row_count = _intclamp(v, 0, InventoryCore.MAX16-1)
	_calculate_layout()

func set_cell_spacing(v: int) -> void:
	cell_spacing = v if v >= 0 else 0
	_calculate_layout()

#######################################################################################################################
### "Private" definitions
# This will be used to sort items within the inventory
class _ItemSorter:
	# "Generic" function to compare magnitudes. The order in which those are given determine the priority. The "l"
	# prefix indicate left side while "r" right side.
	static func check_mags(lmag1: int, rmag1: int, lmag2: int, rmag2: int, lmag3: int, rmag3: int, lmag4: String, rmag4: String) -> bool:
		if (lmag1 != rmag1):
			return lmag1 < rmag1
		
		if (lmag2 != rmag2):
			return lmag2 < rmag2
		
		if (lmag3 != rmag3):
			return lmag3 < rmag3
		
		return lmag4 < rmag4
	
	# The "Horizontal sort" will place items left-to-right, top-to-bottom
	# Give priority to the height when defining "bigger items". Otherwise compare
	# the total amount of used cells
	static func horiz_bigger_first(a: Dictionary, b: Dictionary) -> bool:
		# The generic function returns smaller first, so inverting "left size vs right side" here
		var aheight: int = b.row_span
		var bheight: int = a.row_span
		var asize: int = aheight * b.column_span
		var bsize: int = bheight * a.column_span
		
		return check_mags(aheight, bheight, asize, bsize, b.type, a.type, b.id, a.id)
	
	
	# In here the same logic as before, giving priority to heights. However, this time
	# the smaller items come first
	static func horiz_smaller_first(a: Dictionary, b: Dictionary) -> bool:
		var aheight: int = a.row_span
		var bheight: int = b.row_span
		var asize: int = aheight * a.column_span
		var bsize: int = bheight * b.column_span
		
		return check_mags(aheight, bheight, asize, bsize, a.type, b.type, a.id, b.id)
	
	
	# The "vertical sort" will place items top-to-bottom, "left-to-right"
	# In this case width has priority when considering "bigger"
	static func vert_bigger_first(a: Dictionary, b: Dictionary) -> bool:
		# The generic function returns smaller first, so inverting "left size vs right side" here
		var awidth: int = b.column_span
		var bwidth: int = a.column_span
		var asize: int = awidth * b.row_span
		var bsize: int = bwidth * a.row_span
		
		return check_mags(awidth, bwidth, asize, bsize, b.type, a.type, b.id, a.id)
	
	
	# Same logic as before, but prioritizing widths
	static func vert_smaller_first(a: Dictionary, b: Dictionary) -> bool:
		var awidth: int = a.column_span
		var bwidth: int = b.column_span
		var asize: int = awidth * a.row_span
		var bsize: int = bwidth * b.row_span
		
		return check_mags(awidth, bwidth, asize, bsize, a.type, b.type, a.id, b.id)


#######################################################################################################################
### "Private" properties
# The size of the bag, slots + spacing between them
var _total_size: Vector2 = Vector2()

# Holds instances of InventoryCore.Slot
var _slot_container: Array = []

# Each entry in this array is an instance of InventoryCore.Item
var _item_container: Array = []

## Holds mouse hovering data
var _hovering: int = -1

#######################################################################################################################
### "Private" functions
# Given column and row indices, return the slot array index
func _get_slot_index(col: int, row: int) -> int:
	return column_count * row + col


func _get_item(sloti: int) -> Control:
	if (sloti < 0 || sloti >= _slot_container.size()):
		return null
	
	var islot: InventorySlot = _slot_container[sloti]
	return islot.item


# Test "collision" between items.
func _get_colliding_data(col: int, row: int, iid: String, itype: int, dcode: String, cspan: int, rspan: int) -> Dictionary:
	var retval: Dictionary = {
		"overflows": false,
		"collision_count": 0,
		"matching": {},
		"non_matching": {},
		"disabled_slot": {},
	}
	
	if (col + cspan > column_count || row + rspan > row_count):
		retval.overflows = true
	
	if (!retval.overflows):
		var sloti: int = _get_slot_index(col, row)
		var rowstep: int = column_count - cspan
	
		for _y in rspan:
			for _x in cspan:
				if (_shared_data.disabled_slots_occupied() && !_slot_container[sloti].is_enabled()):
					# Assign whatever as this inner dictionary is meant to be used as a set rather than map
					retval.disabled_slot[sloti] = 1
				else:
					var item: Control = _slot_container[sloti].item
					if (item):
						# Assign whatever because the inner dictionaries are meant to be used as sets rather than maps
						if (item.is_equal(iid, itype, dcode) && (!item.is_stack_full() || _shared_data.drop_mode() == InventoryCore.DropMode.FillOnly)):
							retval.matching[item] = 1
						else:
							retval.non_matching[item] = 1
				
				sloti += 1
			sloti += rowstep
	
	retval.collision_count = retval.matching.size() + retval.non_matching.size()
	
	return retval


# Find any item that matches the specified one that is not at full stack
func _find_matching(iid: String, itype: int, dcode: String, vscan: bool) -> Dictionary:
	var retval: Dictionary = {
		"column": -1,
		"row": -1,
	}
	
	if (vscan):
		# Vertical scan. That is, top-to-bottom, left-to-right
		var col: int = 0
		var row: int = 0
		var done: bool = false
		var index: int = 0
		while (!done):
			var item: Control = _slot_container[index].item
			if (item && item.is_equal(iid, itype, dcode) && !item.is_stack_full()):
				retval.column = col
				retval.row = row
				done = true
			
			if (!done):
				row += 1
				
				if (row >= row_count):
					row = 0
					col += 1
					index = col
				else:
					index += column_count
				
				done = col >= column_count
	
	else:
		# Horizontal scan. That is, left-to-right, top-to-bottom
		for slot in _slot_container:
			var item: Control = slot.item
			if (item && item.is_equal(iid, itype, dcode) && !item.is_stack_full()):
				retval = _get_column_row(item.get_slot())
				break
	
	return retval


# Try to locate an empty spot that can fit the specified item. This function takes into account items that may
# span through multiple cells
func _find_fitting_spot(scol: int, srow: int, iid: String, itype: int, dcode: String, cspan: int, rspan: int, vscan: bool) -> Dictionary:
	var retval: Dictionary = {
		"column": -1,
		"row": -1,
	}
	
	# First perform the obvious check (overflowing) to avoid needless looping
	if (scol + cspan > column_count || srow + rspan > row_count):
		return retval
	
	var col: int = scol
	var row: int = srow
	var done: bool = false
	
	while (!done):
		var colldata: Dictionary = _get_colliding_data(col, row, iid, itype, dcode, cspan, rspan)
		
		# Check if the spot is empty. Because this function is meant to be called after the _find_matching() has
		# already run, items of the same type which are not at full stack may have already been used. Because of
		# that, this specific test will not be done in here.
		if (colldata.collision_count == 0):
			# Spot is completely free, so it can indeed hold the requested item
			retval.column = col
			retval.row = row
			done = true
		
		if (!done):
			if (vscan):
				row += 1
				if (row + rspan > row_count):
					row = 0
					col += 1
				done = col + cspan > column_count
			
			else:
				col += 1
				if (col + cspan > column_count):
					col = 0
					row += 1
				done = row + rspan > row_count
	
	return retval


func _set_slot_highlight(sloti: int, type: int, cspan: int, rspan: int, manual: bool) -> void:
	assert(sloti >= 0 && sloti < _slot_container.size())
	
	var cindex: int = sloti
	var rowstep: int = column_count - cspan
	for _y in rspan:
		for _x in cspan:
			_slot_container[cindex].set_highlight(type, manual)
			cindex += 1
		
		cindex += rowstep
	
	update()


func _clear_contents() -> void:
	for i in _item_container:
		i.queue_free()
	
	_item_container.clear()
	
	for s in _slot_container:
		s.item = null


# This function is meant to take multi-cells-span items and set the touched slots accordingly so the algorithms
# can correctly work and find "empty spots".
# cspan and rspan are needed as arguments because item may be null (null is to make slots empty)
func _set_slot_content(sloti: int, cspan: int, rspan: int, item: Control) -> void:
	# This function assume all boundary checks were already done.
	var cindex: int = sloti
	var rowstep: int = column_count - cspan
	for _y in rspan:
		for _x in cspan:
			_slot_container[cindex].item = item
			cindex += 1
		
		cindex += rowstep


# If the "add_column" is used, the "item" property of each Slot will be changed when the item in question is
# bellow the first row. This function is meant to fix the placement within the slots
func _verify_item_placement() -> void:
	# First nullify the item property on all slots
	for s in _slot_container:
		s.item = null
	
	# Now correctly set the contents of the slots
	for i in _item_container:
		_set_slot_content(i.get_slot(), i.get_column_span(), i.get_row_span(), i)


func _clear_autohighlight() -> void:
	# IF this becomes a problem in terms of performance then a special container will be necessary to help target
	# only the highlighted slots
	
	for s in _slot_container:
		s.set_highlight(InventoryCore.HighlightType.None, false)
	
	# IF this becomes a problem in terms of performance then a special container will be necessary to help target
	# only the highlighted items
	for i in _item_container:
		i.set_highlight(InventoryCore.HighlightType.None, false)
	
	update()


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _calculate_layout() -> void:
	_total_size.x = (column_count * cell_width) + ((column_count - 1) * cell_spacing)
	_total_size.y = (row_count * cell_height) + ((row_count - 1) * cell_spacing)
	
	# Set calculated size into the control's rect
	rect_min_size = _total_size
	rect_size = _total_size
	
	# Check slot container
	var scount: int = column_count * row_count
	
	if (scount != _slot_container.size()):
		_slot_container.resize(scount)
	
	# Each instance of the InventoryCore.Slot is meant to hold/cache the position in which the slot/cell must
	# be drawn. Do so bellow
	# First, calculate how much each slot has to "move" away from the other
	var dx: int = cell_width + cell_spacing
	var dy: int = cell_height + cell_spacing
	
	var idx: int = 0      # Slot index (within the _slot_container)
	var px: int = 0       # Calculated X coordinate
	var py: int = 0       # Calculated Y coordinate
	
	for y in row_count:
		for x in column_count:
			if (!_slot_container[idx]):
				_slot_container[idx] = InventorySlot.new(px, py)
			
			else:
				_slot_container[idx].set_pos(px, py)
			
			idx += 1
			px += dx
		
		py += dy
		px = 0


# Return number of items NOT added into the inventory
func _add_item(idata: Dictionary) -> int:
	# This function is meant to be internally called so using asserts here just to ensure the calls are correct
	assert(idata.has("column") && idata.has("row"))
	assert(idata.has("id") && idata.has("type"))
	assert(idata.has("icon"))
	assert(idata.has("column_span") && idata.has("row_span"))
	assert(idata.has("stack") && idata.has("max_stack"))
	
	var colldata: Dictionary = _get_colliding_data(idata.column, idata.row, idata.id, idata.type, idata.datacode, idata.column_span, idata.row_span)
	# Assume nothing will be added into the inventory
	var retval: int = idata.stack
	_hovering = -1
	
	if (!colldata.overflows && colldata.disabled_slot.size() == 0):
		var sloti: int = _get_slot_index(idata.column, idata.row)
		if (colldata.collision_count == 0):
			# The spot is empty, so just add the item
			var dsize: Vector2 = Vector2()
			dsize.x = (cell_width * idata.column_span) + ((idata.column_span - 1) * cell_spacing)
			dsize.y = (cell_height * idata.row_span) + ((idata.row_span - 1) * cell_spacing)
			
			
			var islot: InventorySlot = _slot_container[sloti]
			
			var edata: Dictionary = {
				"slot": sloti,
				"theme": _use_theme,
				"box_position": Vector2(islot.posx, islot.posy),
				"box_size": dsize,
				"item_position": Vector2(),
				"item_size": dsize,
				"item_index": _item_container.size(),
				"shared": _shared_data,
			}
			
			var nitem: Control = InventoryCore.dictionary_to_item(idata, edata)
			
			# Remove slot highlight before adding the item
			_clear_autohighlight()
			
			add_child(nitem)
			_item_container.append(nitem)
			_set_slot_content(sloti, idata.column_span, idata.row_span, nitem)
			
			if (!_shared_data.is_dragging()):
				# retval at this point is holding the full stack value so it should be correct
				_notify_item_added(nitem, retval)
			
			# But since the entire stack was dropped, must return 0, which is the remaining stack
			retval = 0
		
		
		else:
			# The spot is not free. Take colldata "matching" data and the first one that is not at full stack should
			# receive what can still fit
			var matched: Array = colldata.matching.keys()
			
			for item in matched:
				var canfit: int = item.remaining_stack()
				if (canfit > 0):
					# OK, there is still room in this stack
					var delta: int = idata.stack if idata.stack < canfit else canfit
					
					retval = idata.stack - delta
					item.delta_stack(delta)
					if (!_shared_data.is_dragging()):
						_notify_item_added(item, retval)
					
					break
	
	
	return retval


func _remove_item(item: Control, amount: int) -> void:
	assert(item)
	
	var cstack: int = item.get_current_stack()
	var toremove: int = cstack if (amount < 1 || amount > cstack) else amount
	
	item.delta_stack(-toremove)
	if (!_shared_data.is_dragging()):
		_notify_item_removed(item, toremove)
	
	if (item.get_current_stack() == 0):
		var conti: int = item.get_container_index()
		
		# Clear the slots
		_set_slot_content(item.get_slot(), item.get_column_span(), item.get_row_span(), null)
		
		# Remove from the container
		_item_container.remove(conti)
		
		# Previous operations may have shuffled things around within the item container, so fix the indices
		for i in _item_container.size():
			_item_container[i].set_container_index(i)
		
		item.queue_free()


func _dragging_over(item: Control, mouse_pos: Vector2) -> void:
	# When dragging, the drawn icon preview has an offset so its center corresponds to the mouse cursor.
	# Because of that, add some offset to the calculated hovering indices just so the position of the icon
	# better represents where the item will be dropped
	var mpos: Vector2 = mouse_pos + _shared_data.get_drag_icon_offset()
	# Further shift this position, half cell size, just so the "drop position" becomes closer to the
	# actual preview location
	mpos.x += cell_width * 0.5
	mpos.y += cell_height * 0.5
	
	# Calculate the "percent" of the mouse position over the bag
	# Another way to see this is normalized coordinates, in the range [0..1]
	var perx: float = mpos.x / _total_size.x
	var pery: float = mpos.y / _total_size.y
	
	# Now convert that into column/row 0-based indices
	var column: int = int(perx * column_count)
	var row: int = int(pery * row_count)
	
	var hovering: int = _get_slot_index(column, row)
	
	
	if (hovering != _hovering && hovering >= 0):
		_drop_data.clear()
		_hovering = hovering
		_clear_autohighlight()
		
		
		var cspan: int = item.get_column_span()
		var rspan: int = item.get_row_span()
		
		var colldata: Dictionary = _get_colliding_data(column, row, item.get_id(), item.get_type(), item.get_datacode(), cspan, rspan)
		
		if (colldata.overflows || colldata.disabled_slot.size() > 0):
			_drop_data.can_drop = false
		
		
		else:
			var collcount: int = colldata.collision_count
			if (collcount == 0):
				_drop_data.can_drop = true
			
			else:
				var ihltype: int = InventoryCore.HighlightType.Allow if collcount == 1 else InventoryCore.HighlightType.Deny
				_drop_data.can_drop = collcount == 1
				
				# Highlight all "colliding" items
				for i in colldata.matching:
					i.set_highlight(ihltype, false)
					_drop_data.add = i
				
				for i in colldata.non_matching:
					i.set_highlight(ihltype, false)
					_drop_data.swap = i
			
			if (_drop_data.can_drop):
				if (item.is_socketable() && _shared_data.is_mouse_on_socket()):
					pass
				else:
					_set_slot_highlight(hovering, InventoryCore.HighlightType.Allow, cspan, rspan, false)
				_drop_data.at_column = column
				_drop_data.at_row = row


# Given slot array index, return column/row indices within a dictionary
func _get_column_row(sloti: int) -> Dictionary:
	return {
		"column": sloti % column_count,
		# warning-ignore:integer_division
		"row": int(sloti / column_count)
	}


func _post_drop(item: Control) -> void:
	var sloti: int = item.get_slot()
	_set_slot_highlight(sloti, InventoryCore.HighlightType.None, item.get_column_span(), item.get_row_span(), false)
	item.set_highlight(InventoryCore.HighlightType.Normal, false)
	_hovering = -1


func _on_setting_changed() -> void:
	for i in _item_container:
		i.refresh()




func _draw() -> void:
	var size: Vector2 = Vector2(cell_width, cell_height)
	for s in _slot_container:
		s.render(get_canvas_item(), size, _use_theme, _shared_data.slot_autohighlight() if _shared_data else false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT:
			_hovering = -1
			_clear_autohighlight()
