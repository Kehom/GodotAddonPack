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

# This is a demonstration for the Inventory System addon. Bellow are a few notes.
# In the past this demo retrieved data from a .json file, which is left in the project for reference.
# Also, the code that uses the JSON data is left commented with some information about the fact.
# Now it uses the Database plugin. The relevant files are itemdb.json and itemdb.tres, which are found
# in the invdemo subdirectory.
#
# The item_tooltip node has its mouse filter set to ignore so it doesn't interfere with the events over the
# items. The first attempt was to use the tooltip functionality, but that resulted in terrible flickering.
# 
# This demo has been simplified as much as possible, while still trying to showcase every feature provided
# by the addon.

extends Node2D


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
## The dictionary bellow was used to store the data retrieved from the .json file.
#var item_db: Dictionary

## This is the new item database. Using a different name (from the Dictionary) in order to help differentiate
## old from new code.
const idb: GDDatabase = preload("res://demos/ui/invdemo/itemdb.tres")

## This dictionary was used to store the accumulated weights of the data loaded from the .json file. This is
## not needed with the database addon, which has this system integrated
# Hold in here the accumulated weights of the stuff that will be "randomly" generated.
#var acc_weights: Dictionary = {}

#######################################################################################################################
### "Public" functions
func init_options() -> void:
	# As mentioned in the tutorial, it doesn't matter which inventory container is used to get/set the options.
	$ui/tabs/options/opt_stackhalign.selected = $ui/tabs/stash/stashbag.get_stack_horizontal_align()
	$ui/tabs/options/opt_stackvalign.selected = $ui/tabs/stash/stashbag.get_stack_vertical_align()
	$ui/tabs/options/chk_slotautohighlight.pressed = $ui/tabs/stash/stashbag.get_slot_autohighlight()
	$ui/tabs/options/chk_itemautohighlight.pressed = $ui/tabs/stash/stashbag.get_item_autohighlight()
	$ui/tabs/options/chk_interactable.pressed = $ui/tabs/stash/stashbag.get_interactable_disabled_items()
	$ui/tabs/options/chk_alwaysdrawsockets.pressed = $ui/tabs/stash/stashbag.get_always_draw_sockets()
	$ui/tabs/options/sl_socketdrawr.value = $ui/tabs/stash/stashbag.get_socket_draw_ratio()
	$ui/tabs/options/chk_socketeditemhovered.pressed = $ui/tabs/stash/stashbag.get_socketed_item_emit_hovered()
	$ui/tabs/options/chk_autohidemouse.pressed = $ui/tabs/stash/stashbag.get_auto_hide_mouse()
	$ui/tabs/options/opt_dropmode.selected = $ui/tabs/stash/stashbag.get_drop_on_existing_stack()
	$ui/tabs/options/chk_hidesocketsondrag.pressed = $ui/tabs/stash/stashbag.get_hide_sockets_on_drag_preview()


## The following function is now commented but it is the one used to retrieve all the data from the .json file
## It also initializes the random weight system, which had to be manually done. The Database plugin automatically
## does this task. You can double click the itemdb.tres resource to see the tables within the editor plugin.
#func init_item_db() -> void:
#	# Open the item database file
#	var idbfile: File = File.new()
#	if (idbfile.open("res://demos/ui/invdemo/itemdb.json", File.READ) == OK):
#		# Parse it from JSON format - it should result in a Dictionary
#		var jresult: JSONParseResult = JSON.parse(idbfile.get_as_text())
#
#		if (jresult.result is Dictionary):
#			# Assign the parsed data into the cached item dabase. Yes, this fully loads the data into memory
#			item_db = jresult.result
#		else:
#			print("Obtained database in invalid")
#
#	acc_weights["item_type"] = 0
#	acc_weights["socket"] = 0
#	acc_weights["item"] = {}
#
#	if (!item_db.empty()):
#		for it in item_db.item_type:
#			acc_weights["item_type"] += item_db.item_type[it].weight
#			# Also append into the internal DB the currently accumulated weight
#			item_db.item_type[it]["accw"] = acc_weights["item_type"]
#
#			# Calculate accumulated weights for each item of this type
#			acc_weights.item[it] = 0
#
#			for iid in item_db[it]:
#				var w: float = item_db[it][iid].get("weight", 0.0)
#				if (w > 0.0):
#					acc_weights.item[it] += w
#					item_db[it][iid]["accw"] = acc_weights.item[it]
#
#
#		for st in item_db.socket_type:
#			acc_weights["socket"] += item_db.socket_type[st].weight
#			item_db.socket_type[st]["accw"] = acc_weights["socket"]
#
#	# When loaded, integers are actually stored as floating points. This can cause problems when dealing with
#	# "match" statements or even simple comparisons. So, convert the item_type.[type_name].index to integers
#	for itype in item_db.item_type:
#		item_db.item_type[itype].index = int(item_db.item_type[itype].index)


## This is a function newly created and is meant to take some information from the database resource and cache it
func cache_data() -> void:
	# This iteration should not be a problem since it's incredily unlikely that there will be too many socket
	# types in order to make it too slow
	var stable: DBTable = idb.get_table("socket_type")
	
	for i in stable.get_row_count():
		var row: Dictionary = stable.get_row_by_index(i)
		_socket_mask[row.mask] = row.dcode
	
	var itype: DBTable = idb.get_table("item_type")
	
	for i in itype.get_row_count():
		var row: Dictionary = itype.get_row_by_index(i)
		_item_type[row.id] = row.index


# Special slots can automatically filter item by item types. It is also possible to setup extra function to
# perform further filtering. This extra function will be used to create the specialized gem and potion storage
# within the stash
func set_special_slot_filtering() -> void:
	## This is the old code. The Dictionary has a little bit easier access to the data.
	# Those special slots are set to use the filter as white list and block everything else
#	$ui/tabs/stash/gem_blue.add_to_filter(item_db.item_type.gem.index)
#	$ui/tabs/stash/gem_green.add_to_filter(item_db.item_type.gem.index)
#	$ui/tabs/stash/gem_red.add_to_filter(item_db.item_type.gem.index)
#	$ui/tabs/stash/gem_yellow.add_to_filter(item_db.item_type.gem.index)
#
#	$ui/tabs/stash/potion_blue.add_to_filter(item_db.item_type.potion.index)
#	$ui/tabs/stash/potion_green.add_to_filter(item_db.item_type.potion.index)
#	$ui/tabs/stash/potion_yellow.add_to_filter(item_db.item_type.potion.index)
#
#	$ui/char_equip/mhand.add_to_filter(item_db.item_type.onehand.index)
#	$ui/char_equip/mhand.add_to_filter(item_db.item_type.twohand.index)
#	$ui/char_equip/ohand.add_to_filter(item_db.item_type.onehand.index)
#	$ui/char_equip/ohand.add_to_filter(item_db.item_type.twohand.index)
#	$ui/char_equip/ohand.add_to_filter(item_db.item_type.shield.index)
#	$ui/char_equip/ring1.add_to_filter(item_db.item_type.ring.index)
#	$ui/char_equip/ring2.add_to_filter(item_db.item_type.ring.index)
	
	## This is the new code. Because we need to access data from the item_type table a few times, instead of taking
	## it using the database itself as interface, we first retrieve the table.
	var tb_type: DBTable = idb.get_table("item_type")
	var rgem: Dictionary = tb_type.get_row("gem")
	var rpotion: Dictionary = tb_type.get_row("potion")
	var rohand: Dictionary = tb_type.get_row("onehand")
	var rthand: Dictionary = tb_type.get_row("twohand")
	var rshield: Dictionary = tb_type.get_row("shield")
	var rring: Dictionary = tb_type.get_row("ring")
	
	# Now assign the slot filters.
	$ui/tabs/stash/gem_blue.add_to_filter(rgem.index)
	$ui/tabs/stash/gem_green.add_to_filter(rgem.index)
	$ui/tabs/stash/gem_red.add_to_filter(rgem.index)
	$ui/tabs/stash/gem_yellow.add_to_filter(rgem.index)
	
	$ui/tabs/stash/potion_blue.add_to_filter(rpotion.index)
	$ui/tabs/stash/potion_green.add_to_filter(rpotion.index)
	$ui/tabs/stash/potion_yellow.add_to_filter(rpotion.index)
	
	$ui/char_equip/mhand.add_to_filter(rohand.index)
	$ui/char_equip/mhand.add_to_filter(rthand.index)
	$ui/char_equip/ohand.add_to_filter(rohand.index)
	$ui/char_equip/ohand.add_to_filter(rthand.index)
	$ui/char_equip/ohand.add_to_filter(rshield.index)
	$ui/char_equip/ring1.add_to_filter(rring.index)
	$ui/char_equip/ring2.add_to_filter(rring.index)
	
	
	# Special slots on the stash need some extra filtering in order to accept only the desired items
	$ui/tabs/stash/gem_blue.set_filter_function(self, "_on_blue_gem_filter")
	$ui/tabs/stash/gem_green.set_filter_function(self, "_on_green_gem_filter")
	$ui/tabs/stash/gem_red.set_filter_function(self, "_on_red_gem_filter")
	$ui/tabs/stash/gem_yellow.set_filter_function(self, "_on_yellow_gem_filter")
	
	$ui/tabs/stash/potion_blue.set_filter_function(self, "_on_blue_potion_filter")
	$ui/tabs/stash/potion_green.set_filter_function(self, "_on_green_potion_filter")
	$ui/tabs/stash/potion_yellow.set_filter_function(self, "_on_yellow_potion_filter")


func set_event_listeners() -> void:
	# Things to note on the connections here:
	# - The item_dropped signal is handled on a single function for both special slots and bags.
	# - The item_added signal has been separated, having a function for bags and another for special slots.
	# - The item_dropped signal could have been handled within the same function as of the item_added although
	#   a different one was created just because on a project maybe there will be a need to differentiate the
	#   events. Remember, item_dropped can also be seen as "drag & drop ended" and will not fire item_added.
	
	# The bags
	get_tree().call_group("bags", "connect", "item_clicked", self, "_on_item_clicked")
	get_tree().call_group("bags", "connect", "item_added", self, "_on_item_added")
	get_tree().call_group("bags", "connect", "item_dropped", self, "_on_item_dropped")
	get_tree().call_group("bags", "connect", "mouse_over_item", self, "_on_mouse_over_item")
	get_tree().call_group("bags", "connect", "mouse_out_item", self, "_on_mouse_out_item")
	get_tree().call_group("bags", "connect", "mouse_over_socket", self, "_on_mouse_over_socket")
	get_tree().call_group("bags", "connect", "mouse_out_socket", self, "_on_mouse_out_socket")
	
	# The special slots
	get_tree().call_group("special_slots", "connect", "item_clicked", self, "_on_item_clicked")
	get_tree().call_group("special_slots", "connect", "item_added", self, "_on_special_slot_item_added")
	get_tree().call_group("special_slots", "connect", "item_dropped", self, "_on_item_dropped")
	get_tree().call_group("special_slots", "connect", "mouse_over_item", self, "_on_mouse_over_item")
	get_tree().call_group("special_slots", "connect", "mouse_out_item", self, "_on_mouse_out_item")
	get_tree().call_group("special_slots", "connect", "mouse_over_socket", self, "_on_mouse_over_socket")
	get_tree().call_group("special_slots", "connect", "mouse_out_socket", self, "_on_mouse_out_socket")
	
	# The equip slots
	get_tree().call_group("equip_slot", "connect", "mouse_over_item", self, "_on_mouse_over_item")
	get_tree().call_group("equip_slot", "connect", "mouse_out_item", self, "_on_mouse_out_item")
	get_tree().call_group("equip_slot", "connect", "mouse_over_socket", self, "_on_mouse_over_socket")
	get_tree().call_group("equip_slot", "connect", "mouse_out_socket", self, "_on_mouse_out_socket")


# In this demo the datacode matches the socket types on the item.
# This is mostly to result in the items being reported as different by the system, which will allow items to
# be swapped through the item dragging system.
func build_datacode(sockets: Array) -> String:
	## This is the old code (using data retrieved from .json file)
#	var retval: String = ""
#	for s in sockets:
#		match s.mask:
#			item_db.socket_type.blue.mask:
#				retval += "B"
#			item_db.socket_type.red.mask:
#				retval += "R"
#			item_db.socket_type.green.mask:
#				retval += "G"
#			item_db.socket_type.yellow.mask:
#				retval += "Y"
#			item_db.socket_type.generic.mask:
#				retval += "W"
#
#	return retval
	
	## This is the new code (using data from Database addon)
	var retval: String = ""
	for s in sockets:
		retval += _socket_mask[s.mask]
	
	
	return retval


# Given an item type number, find the corresponding "ID" string within the database
func db_get_item_type_from_index(i: int) -> String:
	## This is old code, retrieving data from .json file
#	for it in item_db.item_type:
#		if (item_db.item_type[it].index == i):
#			return it
	
	## This is new code, retrieving data from database addon
	var itype: DBTable = idb.get_table("item_type")
	for ri in itype.get_row_count():
		var row: Dictionary = itype.get_row_by_index(ri)
		if (row.index == i):
			return row.id
	
	return ""



func db_get_item_name(itype: int, iid: String) -> String:
	var retval: String = ""
	var itypestr: String = db_get_item_type_from_index(itype)
	
	if (!itypestr.empty()):
		## This single line is old code, retriving data from .json file
#		retval = item_db[itypestr].get(iid, {}).get("name", "")
		
		## This is the new code
		var tbl: DBTable = idb.get_table(itypestr)
		retval = tbl.get_row(iid).get("name", "")
	
	return retval


func db_get_item_tooltip(itype: int, iid: String) -> Dictionary:
	var retval: Dictionary = {}
	var itypestr: String = db_get_item_type_from_index(itype)
	
	if (!itypestr.empty()):
		## This single line is old code
#		var item: Dictionary = item_db[itypestr].get(iid, {})
		
		## The next two lines are new code
		var tbl: DBTable = idb.get_table(itypestr)
		var item: Dictionary = tbl.get_row(iid)
		
		if (!item.empty()):
			retval["name"] = item.get("name", "")
			retval["description"] = item.get("description", "")
	
	return retval


# Randomly pick a socket type from the database and build the corresponding dictionary to be fed into the
# inventory system.
func db_pick_socket() -> Dictionary:
	## Old code manually take a random socket from the data retrieved from the .json file
#	var roll: float = rand_range(0.0, acc_weights.socket)
#
#	for socket in item_db.socket_type:
#		if (item_db.socket_type[socket].accw > roll):
#			return {
#				"image": load(item_db.socket_type[socket].image),
#				"mask": item_db.socket_type[socket].mask
#			}
#
#	return {}
	
	## The database addon offers the random picking out of the box
	var rsocket: Dictionary = idb.randomly_pick_from("socket_type")
	
	return {
		"image": load(rsocket.image),
		"mask": rsocket.mask
	}


# This function is used to attempt to move an item from one item container into another. The destination container
# must be a bag
# The code in here only works if the "Use Resource Paths on Signals" is disabled. Otherwise it would be necessary
# to take all resource paths and convert into actual resouces like Texture, Material and so on.
# This demo project does have that option disabled.
func attempt_move_to_bag(from: InventoryBase, to: InventoryBag, idata: Dictionary) -> void:
	if (from is InventorySpecialSlot):
		# warning-ignore:return_value_discarded
		idata.erase("column")
		# warning-ignore:return_value_discarded
		idata.erase("row")
		
		var stack: int = idata.stack
		var tomove: int = int(min(idata.stack, idata.max_stack))
		idata.stack = tomove
		
		# warning-ignore:return_value_discarded
		to.add_item(idata)
		if (idata.stack < stack):
			from.remove_item(tomove - idata.stack)
	
	
	elif (from is InventoryBag):
		var stack: int = idata.stack
		
		# Item data contains column and row information from where the item is being taken. However those fields
		# cannot be present when adding the item into the destination bag otherwise the algorithm will not attempt
		# to locate a proper place to store the item. So, cache the values then erase them from the dictionary
		var fcol: int = idata.column
		var frow: int = idata.row
		# warning-ignore:return_value_discarded
		idata.erase("column")
		# warning-ignore:return_value_discarded
		idata.erase("row")
		
		# warning-ignore:return_value_discarded
		to.add_item(idata)
		if (idata.stack < stack):
			var delta: int = stack - idata.stack
			from.remove_item_from(fcol, frow, delta)



# This function is used to attempt to move an item into a special slot within the stash. The return value will
# be the remaining stack from the given item.
func attemp_move_to_special(from: InventoryBase, idata: Dictionary) -> int:
	# If the given item is not a gem nor a potion, bail
	## This commented check is the old code
#	if (idata.type != item_db.item_type.gem.index && idata.type != item_db.item_type.potion.index):
#		return idata.stack
	
	## This check is the new code
	var itype: DBTable = idb.get_table("item_type")
	if (idata.type != itype.get_row("gem").index && idata.type != itype.get_row("potion").index):
		return idata.stack
	
	# Assume nothing will be added
	var retval: int = idata.stack
	var to: InventorySpecialSlot = null
	
	## This is the old check
#	if (idata.type == item_db.item_type.gem.index):
	## This is the new check
	if (idata.type == itype.get_row("gem").index):
		match idata.id:
			"blue":
				to = $ui/tabs/stash/gem_blue
			"green":
				to = $ui/tabs/stash/gem_green
			"red":
				to = $ui/tabs/stash/gem_red
			"yellow":
				to = $ui/tabs/stash/gem_yellow
	
	## This check is the olde code
#	elif (idata.type == item_db.item_type.potion.index):
	## This is the new code
	elif (idata.type == itype.get_row("potion").index):
		match idata.id:
			"blue":
				to = $ui/tabs/stash/potion_blue
			"green":
				to = $ui/tabs/stash/potion_green
			"yellow":
				to = $ui/tabs/stash/potion_yellow

	if (to):
		var ostack: int = idata.stack
		to.add_item(idata)
		retval = idata.stack
		var delta: int = ostack - retval
		if (delta > 0):
			if (from is InventoryBag):
				from.remove_item_from(idata.column, idata.row, delta)
	
	return retval


# Helper function to take an item from the equip special slot into the specified bag. The first try is to
# move into the specified column/row. If item cannot be placed there, it will try to move into the first
# free spot. The returned dictionary will always contain a field named "added", which will be true if the
# item was moved or false otherwise. If added is true and from is not empty, then the returned dictionary will
# also contain column and row fields, indicating where the item was stored at
func from_special_to_bag(from: InventorySpecialSlot, tobag: InventoryBag, atcol: int, atrow: int) -> Dictionary:
	var retval: Dictionary = {
		"added": false,
	}
	
	var idata: Dictionary = from.get_item_data(false)
	if (idata.empty()):
		# The slot is empty. Return true as it will help with the coding
		retval.added = true
		return retval
	
	if (atcol >= 0 && tobag.can_store_at(idata, atcol, atrow)):
		idata["column"] = atcol
		idata["row"] = atrow
		retval.added = true
		retval["column"] = atcol
		retval["row"] = atrow
	
	else:
		var spot: Dictionary = tobag.find_spot(idata, false)
		if (!spot.empty()):
			idata["column"] = spot.column
			idata["row"] = spot.row
			retval.added = true
			retval["column"] = spot.column
			retval["row"] = spot.row
	
	if (retval.added):
		# warning-ignore:return_value_discarded
		tobag.add_item(idata)
		from.remove_item(-1)
	
	return retval


func attempt_equip_item(from: InventoryBag, idata: Dictionary) -> void:
	var dslot1: InventorySpecialSlot = null
	var dslot2: InventorySpecialSlot = null
	var spanto: InventorySpecialSlot = null
	
	match idata.type:
		## This is the old matching for rings
#		item_db.item_type.ring.index:
		## This is the new matching for rings
		_item_type.ring:
			# Rings can be placed on either slot
			dslot1 = $ui/char_equip/ring1
			dslot2 = $ui/char_equip/ring2
		
		## This is the old matching for shidles
#		item_db.item_type.shield.index:
		## This is the new matching for shields
		_item_type.shield:
#			# Shields are off-hand items
			dslot1 = $ui/char_equip/ohand
		
		## This is the old matching for one handers
#		item_db.item_type.onehand.index:
		## This is the new matching for one handers
		_item_type.onehand:
			dslot1 = $ui/char_equip/mhand
			dslot2 = $ui/char_equip/ohand
		
		## This is the old matching for two handers
#		item_db.item_type.twohand.index:
		## This is the new matching for two handers
		_item_type.twohand:
			dslot1 = $ui/char_equip/mhand
			spanto = $ui/char_equip/ohand
	
	# Not always dslot2 will be valid. But if dslot1 is not, then there is no actual slot for the given item type.
	if (!dslot1):
		return
	
	# Place here the slot that will actually receive the item.
	var destslot: InventorySpecialSlot = null
	
	# Cache column and row where the item is store at within the bag
	var col: int = idata.column
	var row: int = idata.row
	
	# With column and row cached, strip that out from the given idata as it might result in problems if the
	# item has to be added back into the bag
	# warning-ignore:return_value_discarded
	idata.erase("column")
	# warning-ignore:return_value_discarded
	idata.erase("row")
	
	# Remove it from the bag so if there is anything within the destination slot then hopefully there will be
	# room for it to be placed in the bag.
	from.remove_item_from(col, row, -1)
	
	# Obtain item data from the possible destination slot.
	var stored1: Dictionary = dslot1.get_item_data(false)
	
	if (stored1.empty()):
		# Since the first slot is empty, the check here is rather simple. Basically, if the spanto is valid,
		# just try to move its contents into the bag. If the helper function returns true then the item can
		# be occupied. If spanto is not valid then the equipping can be done anyway.
		if (!spanto || from_special_to_bag(spanto, from, col, row).added):
			destslot = dslot1
	
	else:
		# First slot is not empty. Check second slot.
		if (dslot2):
			var stored2: Dictionary = {}
			stored2 = dslot2.get_item_data(false)
			
			if (stored2.empty()):
				destslot = dslot2
		
		if (!destslot):
			# If here then either both slot options are occupied or the item does not have an alternative slot.
			var moved: bool = false
			var movedata1: Dictionary = from_special_to_bag(dslot1, from, col, row)
			moved = movedata1.added
			
#			moved = from_special_to_bag(dslot1, from, col, row)
			if (moved):
				if (!spanto || from_special_to_bag(spanto, from, col, row).added):
					destslot = dslot1
				
				if (spanto && !destslot):
					# If here the spanned slot couldn't be emptied. However, the dslot1 was so must put the item
					# back into it.
					# warning-ignore:return_value_discarded
					dslot1.add_item(stored1)
					# Also, the item that was indeed moved into the bag must be removed in order to give some room
					# for the original item to be added back into the bag
					from.remove_item_from(movedata1.column, movedata1.row, -1)
			
			else:
				# The first slot couldn't be emptied. If there is a secondary slot then at least a try to empty
				# it should be done (maybe it is holding a smaller item). In this demo there are no items that
				# span into a secondary slot and also could be stored in an alternative slot. Because of that
				# not checking for this case in here.
				
				pass
	
	
	if (destslot):
		# warning-ignore:return_value_discarded
		destslot.add_item(idata)
	
	else:
		# If here there was not valid destination slot that could store the requested item. So, add it back into
		# the bag that was previously holding it, using the cached column and row
		
		idata["column"] = col
		idata["row"] = row
		# warning-ignore:return_value_discarded
		from.add_item(idata)





# Whenever the mass highlight function is called on a bag, this function will be assigned to perform the mass
# highlighting. Basically this will take the search criteria and try to find it within the item name
func bag_mass_highlight(idata: Dictionary) -> Dictionary:
	var retval: Dictionary = {}
	
	if (!_search_criteria.empty()):
		# In here only matching the item name, but something a lot more complex could obviously be done.
		var lcase_search: String = _search_criteria.to_lower()
		var lcase_name: String = db_get_item_name(idata.type, idata.id).to_lower()
		
		if (lcase_name.find(lcase_search) == -1):
			# The search criteria was no found on the item name. So, disable it
			retval["enabled"] = false
		else:
			# The search criteria was found on the item name. Add some frame around the item
			retval["item_highlight"] = InventoryCore.HighlightType.Normal
	
	# If the search criteria was empty, then this dictionary will be empty, which will reset the highlighting
	return retval


# This will be used to verify the item highlighting on the given special slot
func check_special_slot_highlight(slot: InventorySpecialSlot) -> void:
	var scriteria = $ui/tabs/stash/stashfilter.text
	var idata: Dictionary = slot.get_item_data()
	if (idata.empty()):
		return
	
	if (scriteria.empty()):
		# Clear any highlight as the search criteria is empty
		slot.set_item_enabled(true)
		slot.set_item_highlight(InventoryCore.HighlightType.None)
	
	else:
		var lcase_search: String = scriteria.to_lower()
		var lcase_name: String = db_get_item_name(idata.type, idata.id).to_lower()
		
		if (lcase_name.find(lcase_search) == -1):
			slot.set_item_enabled(false)
			slot.set_item_highlight(InventoryCore.HighlightType.None)
		else:
			slot.set_item_enabled(true)
			slot.set_item_highlight(InventoryCore.HighlightType.Normal)


# In here the goal is to check the stash bag for items that could be placed on the special slots and try to
# move into those. The idea is to call this before auto sorting the bag.
func check_special_on_stash() -> void:
	# This array holds a list of item types that contain special slots. So, should new special slots be added
	# at some point related to other types, updating this array should be enough as the rest of the task is
	# done by the attemp_move_to_special() function.
	
	## This is the old array building
#	var sp_data: Array = [
#		item_db.item_type.gem.index,
#		item_db.item_type.potion.index,
#	]
	
	## This is the new array building
	var sp_data: Array = [
		_item_type.gem,
		_item_type.potion,
	]
	
	# Iterate through item types that contain special slots
	for itype in sp_data:
		# Obtain all items of this type from the stash tab
		var contents: Array = $ui/tabs/stash/stashbag.get_items_of_type(itype)
		
		for idata in contents:
			# warning-ignore:return_value_discarded
			attemp_move_to_special($ui/tabs/stash/stashbag, idata)


#######################################################################################################################
### "Private" definitions
# Preload the material that will be assigned to items that are dragged above "valid sockets"
const mat_pulsing: Material = preload("res://demos/ui/invdemo/mat_pulsing.tres")

#######################################################################################################################
### "Private" properties
# This dictionary didn't exist in the old code. However it is now used to cache some data related to the
# socket masks, taken from the database. The info held here is actually the "code" used to build the datacode
var _socket_mask: Dictionary = {}

# This is also a new dictionary that is used to cache the item type codes (index column from the item_type table)
var _item_type: Dictionary = {}


# Before calling the mass highlight on any bag, this property will be set with the correct criteria. This is
# because there are two search boxes in this demo.
var _search_criteria: String = ""


# The part of the demo simulating "buying rows" in a bag uses this property to tell which row is being bought
var _buy_row_index: int = 1

# This dictionary will be used to provide some data to properly split stacks. The fields:
# - container: The inventory container holding the item
# - column: The column where the item is stored at
# - row: The row where the item is stored at
# Obviously column and row are only relevant if container is a bag. The actual splitting size can be obtained
# from the popup widget
var _splitinfo: Dictionary

#######################################################################################################################
### "Private" functions
func _generate_item() -> void:
	## Old code to randomly pick something from the json data. This process is now automatic as the database addon
	## has it integrated
	# Roll for the item type
#	var roll: float = rand_range(0.0, acc_weights.item_type)
#	var gen_type: String = ""
#
#	# Locate which one was "picked by the roll"
#	for it in item_db.item_type:
#		if (item_db.item_type[it].accw > roll):
#			gen_type = it
#			break
#	var gbutton: Button = null
#	var rrange: float = -1.0
	
	
	# With the structure the JSON data is in, the code bellow could completely skip the match and directly
	# retrieve data from the database. It would allow for easy creation of new item types by just adding
	# them into the correct "tables". Basically it would be a new entry in the item_type "table" then a new
	# "table" corresponding to that entry. Having a match like bellow restricts to only the known types.
	# Yes, probably the accumulated weights would need a proper verification of known types in order to not
	# completely screw up the generation here.
#	match gen_type:
#		"gem", "ring", "potion", "shield", "onehand", "twohand":
#			rrange = acc_weights.item[gen_type]
	
#	if (rrange > 0.0):
#		roll = rand_range(0.0, rrange)
#
#		for iid in item_db[gen_type]:
#			if (item_db[gen_type][iid].accw > roll):
#				gbutton = Button.new()
#				gbutton.text = item_db[gen_type][iid].name
#
#				var picked: Dictionary = item_db[gen_type][iid]
#				var smaskname: String = picked.get("socket_mask", "")
#				var sdata: Dictionary = item_db.socket_type.get(smaskname, {})
#				var msockets: int = picked.get("max_sockets", 0)
#				var sockets: Array = []
#
#				# If this item can contains sockets, generate them. Do not generate socket data if this item is
#				# marked to be socketable.
#				if (msockets > 0 && smaskname.empty()):
#					var gen_sockets: int = randi() % (msockets + 1)
#					for _i in gen_sockets:
#						sockets.append(db_pick_socket())
#
#
#				var idata: Dictionary = {
#					"type": item_db.item_type[gen_type].index,
#					"id": iid,
#					"icon": load(picked.icon),
#					"datacode": build_datacode(sockets),
#					# Fill some of the optional fields with default values
#					"max_stack": picked.get("max_stack", 1),       # Default is non stackable
#					"socket_mask": sdata.get("mask", 0),           # Default is non socketable
#					"column_span": picked.get("column_span", 1),
#					"row_span": picked.get("row_span", 1),
#					"socket_data": sockets,         # If array is empty no sockets will be added at all
#					"use_linked": 0 if gen_type != "twohand" else InventoryCore.LinkedSlotUse.SpanToSecondary,
#				}
#
#				# warning-ignore:return_value_discarded
#				gbutton.connect("pressed", self, "_on_bt_item_pressed", [idata, gbutton])
#
#				break
	
	
#	if (gbutton):
#		$ui/ground/generated.add_child(gbutton)
	
	## New code - simply use the "ramdonly_pick_from" function and use the "id" column to find which item type
	## is meant to be generated
	# First make a "button" that will be added into the "ground", which will be used to "get" it
	var gbutton: Button = null
	
	var gen_row: Dictionary = idb.randomly_pick_from("item_type")
	var gen_type: String = gen_row.id
	
	# Pick a random item from the "gen_type" table
	var irow: Dictionary = idb.randomly_pick_from(gen_type)
	
	# Item row should not be empty, but checking just to make sure
	if (!irow.empty()):
		gbutton = Button.new()
		gbutton.text = irow.name
		
		var smaskname: String = irow.get("socket_mask", "")
		var sdata: Dictionary = idb.get_row_from("socket_type", smaskname)
		var msockets: int = irow.get("max_sockets", 0)
		var sockets: Array = []
		
		# If this item can contain sockets, generate them.
		if (msockets > 0 && smaskname.empty()):
			var gen_sockets: int = randi() & (msockets + 1)
			for _i in gen_sockets:
				sockets.append(db_pick_socket())
		
		# Build the Dictionary containing item data that must be passed to the Inventory
		var idata: Dictionary = {
			"type": gen_row.index,
			"id": irow.id,
			"icon": load(irow.icon),
			"datacode": build_datacode(sockets),
			# Fill some of the optional fields with default values
			"max_stack": irow.get("max_stack", 1),       # Default is non stackable
			"socket_mask": sdata.get("mask", 0),         # Default is non socketable
			"column_span": irow.get("column_span", 1),
			"row_span": irow.get("row_span", 1),
			"socket_data": sockets,      # If array is empty no sockets will be added at all
			"use_linked": 0 if gen_type != "twohand" else InventoryCore.LinkedSlotUse.SpanToSecondary,
		}
		
		# warning-ignore:return_value_discarded
		gbutton.connect("pressed", self, "_on_bt_item_pressed", [idata, gbutton])
	
	if (gbutton):
		$ui/ground/generated.add_child(gbutton)




#######################################################################################################################
### Event handlers
func _on_bt_roll_pressed() -> void:
	# How many items to generate
	var gencount: int = randi() % 6 + 3
	
	# Clear the "ground"
	for bt in $ui/ground/generated.get_children():
		bt.queue_free()
	
	for _i in gencount:
		_generate_item()


func _on_blue_gem_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "blue"

func _on_green_gem_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "green"

func _on_red_gem_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "red"

func _on_yellow_gem_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "yellow"


func _on_blue_potion_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "blue"

func _on_green_potion_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "green"

func _on_yellow_potion_filter(iid: String, _itype: int, _dcode: String) -> bool:
	return iid == "yellow"


func _on_item_clicked(evt: InventoryEventMouse) -> void:
	if (evt.has_modifier):
		if (evt.shift && evt.button_index == BUTTON_LEFT):
			var from: InventoryBase = evt.container
			var to: InventoryBag = null
			
			var pnl: Panel = evt.container.get_parent_control()
			if (pnl == $ui/tabs/stash):
				# Moving from stash into player bag. No "special case" here
				to = $ui/char_equip/charbag
			elif (pnl == $ui/char_equip):
				# Moving from player bag into stash. In this case, the stash contains special slots for potions
				# and gems. If the clicked item is one of those, try moving into those slots.
				var ostack: int = evt.item_data.stack
				var remaining: int = attemp_move_to_special(from, evt.item_data)
				
				if (from is InventoryBag):
					from.remove_item_from(evt.item_data.column, evt.item_data.row, ostack - remaining)
				
				if (remaining > 0):
					to = $ui/tabs/stash/stashbag
			
			
			if (from && to):
				attempt_move_to_bag(from, to, evt.item_data)
		
		elif ((evt.control || evt.command) && evt.button_index == BUTTON_LEFT):
			var mstack: int = evt.item_data.max_stack
			if (mstack == 1):
				return
			var stack: int = evt.item_data.stack
			if (stack < 2):
				return
			var ssize: int = stack if stack <= mstack else mstack
			
			_splitinfo["container"] = evt.container
			if (evt.container is InventoryBag):
				_splitinfo["column"] = evt.item_data.column
				_splitinfo["row"] = evt.item_data.row
			
			pop_split(ssize, evt.global_mouse_position)
	
	else:
		if (evt.button_index == BUTTON_RIGHT && evt.container is InventoryBag):
			attempt_equip_item(evt.container, evt.item_data)



func _on_item_added(evt: InventoryEventContainer) -> void:
	if (evt.container == $ui/char_equip/charbag):
		# Ensure the newly added item get the correct highlight
		_search_criteria = $ui/char_equip/txt_search.text
		$ui/char_equip/charbag.mass_highlight(funcref(self, "bag_mass_highlight"))
	elif (evt.container == $ui/tabs/stash/stashbag):
		_search_criteria = $ui/tabs/stash/stashfilter.text
		$ui/tabs/stash/stashbag.mass_highlight(funcref(self, "bag_mass_highlight"))

func _on_special_slot_item_added(evt: InventoryEventContainer) -> void:
	# Use the "if" just to ensure the container is of the correct type
	if (evt.container is InventorySpecialSlot):
		check_special_slot_highlight(evt.container)


# When item is dropped it does not result in item_added event. While it would be possible to handle the event from
# the same function that is handling the item_added, separating things just because it would then become possible
# to perform something different. Think about the item_dropped as a "drag & drop ended event"
func _on_item_dropped(evt: InventoryEventContainer) -> void:
	if (evt.container is InventoryBag):
		if (evt.container == $ui/char_equip/charbag):
			_search_criteria = $ui/char_equip/txt_search.text
		elif (evt.container == $ui/tabs/stash/stashbag):
			_search_criteria = $ui/tabs/stash/stashfilter.text
		else:
			_search_criteria = ""
		
		evt.container.mass_highlight(funcref(self, "bag_mass_highlight"))
	
	elif (evt.container is InventorySpecialSlot):
		var cparent: Panel = evt.container.get_parent_control()
		if (cparent == $ui/tabs/stash):
			check_special_slot_highlight(evt.container)


func _on_mouse_over_item(evt: InventoryEventMouse) -> void:
	# Do not show tooltip if something is being dragged
	if (evt.is_dragging):
		return
	
	var ttip: Dictionary = db_get_item_tooltip(evt.item_data.type, evt.item_data.id)
	$ui/item_tooltip/lbl_name.text = ttip.name
	$ui/item_tooltip/lbl_description.text = ttip.description
	
	var x: int = evt.global_mouse_position.x - $ui/item_tooltip.rect_size.x
	var y: int = evt.global_mouse_position.y - $ui/item_tooltip.rect_size.y
	
	if (x < 0):
		x = 0
	if (y < 0):
		y = 0
	
	$ui/item_tooltip.rect_global_position = Vector2(x, y)
	
	$ui/item_tooltip.visible = true


func _on_mouse_out_item(_evt: InventoryEventMouse) -> void:
	$ui/item_tooltip.visible = false


func _on_mouse_over_socket(evt: InventoryEventSocketMouse) -> void:
	if (!evt.item_data.empty() || !evt.is_dragging):
		return
	
	if (evt.mask & evt.dragged_socket_mask != 0):
		evt.container.set_dragged_item_material(mat_pulsing)



func _on_mouse_out_socket(evt: InventoryEventSocketMouse) -> void:
	if (evt.is_dragging):
		# Just ensture the dragged item has no material set
		evt.container.set_dragged_item_material(null)





func _on_bt_item_pressed(idata: Dictionary, bt: Button) -> void:
	$ui/char_equip/charbag.add_item(idata)
	if (idata.stack == 0):
		bt.queue_free()



func _on_bt_destroy_pressed() -> void:
	$ui/ground/special.remove_item(-1)


# Reroll the sockets on the item that is in the "ground/special" slot
func _on_bt_rollsockets_pressed() -> void:
	var idata: Dictionary = $ui/ground/special.get_item_data(true)
	if (idata.empty()):
		return
	
	# Check on the item db if this item can have sockets
	var tbl: String = db_get_item_type_from_index(idata.type)
	if (tbl.empty()):
		return
	
	## This single line is old code
#	var dbitem: Dictionary = item_db[tbl].get(idata.id, {})

	## This single line is new code
	var dbitem: Dictionary = idb.get_row_from(tbl, idata.id)
	
	if (dbitem.empty()):
		return
	
	var msockets: int = dbitem.get("max_sockets", 0)
	if (msockets <= 0):
		return
	
	# Randomly obtian number of sockets to be generated
	var gen_sockets: int = randi() % (msockets + 1)
	var sockets: Array = []
	for _i in gen_sockets:
		sockets.append(db_pick_socket())
	
	$ui/ground/special.set_item_sockets(sockets, -1, true)
	$ui/ground/special.set_item_datacode(build_datacode(sockets))


# Change the socket types on the item placed in the "ground/special" slot
func _on_bt_morphsockets_pressed() -> void:
	var idata: Dictionary = $ui/ground/special.get_item_data(true)
	if (idata.empty()):
		return
	
	var socket_count: int = idata.socket_data.size()
	
	for i in socket_count:
		idata.socket_data[i] = db_pick_socket()
		$ui/ground/special.morph_item_socket(i, idata.socket_data[i], true)
		$ui/ground/special.set_item_datacode(build_datacode(idata.socket_data))


func _on_bt_sortbfirst_hor_pressed() -> void:
	# Bigger first, horizontal
	$ui/char_equip/charbag.sort_items(true, false)

func _on_bt_sortsfirst_hor_pressed() -> void:
	# Smaller first, horizontal
	$ui/char_equip/charbag.sort_items(false, false)


func _on_bt_sortbfirst_ver_pressed() -> void:
	# Bigger first, vertical
	$ui/char_equip/charbag.sort_items(true, true)

func _on_bt_sortsfirst_ver_pressed() -> void:
	# Smaller first, vertical
	$ui/char_equip/charbag.sort_items(false, true)


# The sorting on the stash tab can also, if desired, incorporate extra code to move things from bag into the
# special slots
func _on_bt_sortbfirsth_pressed() -> void:
	check_special_on_stash()
	$ui/tabs/stash/stashbag.sort_items(true, false)

func _on_bt_sortsfirsth_pressed() -> void:
	check_special_on_stash()
	$ui/tabs/stash/stashbag.sort_items(false, false)


func _on_bt_sortbfirstv_pressed() -> void:
	check_special_on_stash()
	$ui/tabs/stash/stashbag.sort_items(true, true)

func _on_bt_sortsfirstv_pressed() -> void:
	check_special_on_stash()
	$ui/tabs/stash/stashbag.sort_items(false, true)




func _on_txt_search_text_changed(new_text: String) -> void:
	_search_criteria = new_text
	$ui/char_equip/charbag.mass_highlight(funcref(self, "bag_mass_highlight"))


func _on_stashfilter_text_changed(new_text: String) -> void:
	_search_criteria = new_text
	$ui/tabs/stash/stashbag.mass_highlight(funcref(self, "bag_mass_highlight"))
	
	# Must check the special slots. Great thing those are part of a group!
	for s in get_tree().get_nodes_in_group("special_slots"):
		if (s is InventorySpecialSlot):
			check_special_slot_highlight(s)


func _on_opt_stackhalign_item_selected(id: int) -> void:
	$ui/tabs/stash/stashbag.set_stack_horizontal_align(id)

func _on_opt_stackvalign_item_selected(id: int) -> void:
	$ui/tabs/stash/stashbag.set_stack_vertical_align(id)


func _on_chk_slotautohighlight_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_slot_autohighlight(button_pressed)

func _on_chk_itemautohighlight_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_item_autohighlight(button_pressed)

func _on_chk_interactable_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_interactable_disabled_items(button_pressed)

func _on_chk_alwaysdrawsockets_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_always_draw_sockets(button_pressed)

func _on_sl_socketdrawr_value_changed(value: float) -> void:
	$ui/tabs/stash/stashbag.set_socket_draw_ratio(value)

func _on_chk_socketeditemhovered_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_socketed_item_emit_hovered_event(button_pressed)

func _on_chk_autohidemouse_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_auto_hide_mouse(button_pressed)

func _on_opt_dropmode_item_selected(id: int) -> void:
	$ui/tabs/stash/stashbag.set_drop_on_existing_stack(id)

func _on_chk_hidesocketsondrag_toggled(button_pressed: bool) -> void:
	$ui/tabs/stash/stashbag.set_hide_sockets_on_drag_preview(button_pressed)


func _on_bt_mainmenu_pressed() -> void:
	get_tree().change_scene("res://main.tscn")

func _on_bt_quit_pressed() -> void:
	get_tree().quit()

#######################################################################################################################
### Overrides
func _ready() -> void:
	randomize()
	
	# Deferring this call because it uses functions that require the tree to be fully built. 
	call_deferred("init_options")
	
	## Calling the init_item_db() was necessary in order to load the data from .json. However, this is not needed
	## anymore. The function is fully commented bellow and there is some more information regarding its tasks.
	#init_item_db()
	
	## Calling a new function here to cache datacode information related to the socket types
	cache_data()
	
	set_special_slot_filtering()
	set_event_listeners()
	
	init_odd_shaped_bag()
	init_withbuyoption_bag()





#############################################################################################################
### Bellow is code specifically for the "expanding" tab
# In here, just showcasing the possibility to add/remove columns/rows in the bag without affecting the
# item placement.

func _on_bt_addcolumn_pressed() -> void:
	if ($ui/tabs/expandable/bag.column_count == 12):
		return
	
	$ui/tabs/expandable/bag.add_columns(1)


func _on_bt_remcolumn_pressed() -> void:
	if ($ui/tabs/expandable/bag.column_count == 4):
		return
	
	$ui/tabs/expandable/bag.remove_columns(1)


func _on_bt_addrow_pressed() -> void:
	if ($ui/tabs/expandable/bag.row_count == 13):
		return
	
	$ui/tabs/expandable/bag.add_rows(1)


func _on_bt_remrow_pressed() -> void:
	if ($ui/tabs/expandable/bag.row_count == 4):
		return
	
	$ui/tabs/expandable/bag.remove_rows(1)


#############################################################################################################
### Bellow is code specifically for the "slots" tab.
# In here showcasing two possible use cases for the disabled slot feature.

func init_odd_shaped_bag() -> void:
	$ui/tabs/slots/odd_shape.set_slot_highlight(4, 0, InventoryCore.HighlightType.Disabled)
	$ui/tabs/slots/odd_shape.set_slot_highlight(5, 0, InventoryCore.HighlightType.Disabled)
	$ui/tabs/slots/odd_shape.set_slot_highlight(4, 1, InventoryCore.HighlightType.Disabled)
	$ui/tabs/slots/odd_shape.set_slot_highlight(5, 1, InventoryCore.HighlightType.Disabled)


func init_withbuyoption_bag() -> void:
	for row in range(1, $ui/tabs/slots/withbuyopt.row_count):
		for col in $ui/tabs/slots/withbuyopt.column_count:
			$ui/tabs/slots/withbuyopt.set_slot_highlight(col, row, InventoryCore.HighlightType.Disabled)


func _on_bt_buyrow_pressed() -> void:
	# Obviously that in a real game it would be necessary to check if the player has the necessary "gold" to
	# buy this extra row.
	if (_buy_row_index == $ui/tabs/slots/withbuyopt.row_count):
		return
	
	for col in $ui/tabs/slots/withbuyopt.column_count:
		$ui/tabs/slots/withbuyopt.set_slot_highlight(col, _buy_row_index, InventoryCore.HighlightType.None)
	
	_buy_row_index += 1


func _on_bt_resetrows_pressed() -> void:
	init_withbuyoption_bag()
	_buy_row_index = 1



#############################################################################################################
### The code bellow is specifically for the split stack system.
# Note that it could easily be moved into a separate script + scene. Obviously that a few changes would be
# required in order to properly exchange data and, most importantly, the moment the cancel or Ok buttons are
# pressed (in that case through signals)

func pop_split(ssize: int, mpos: Vector2) -> void:
	var popsize: Vector2 = $ui/pop_split.rect_size
	
	# For some reason the min_value keeps resetting, so ensure it is 1
	$ui/pop_split/sl_split.min_value = 1
	# Obviously the maximum value must match the stack size
	$ui/pop_split/sl_split.max_value = ssize
	
	# Try to put current split in the middle
	# warning-ignore:integer_division
	$ui/pop_split/sl_split.value = (ssize + 1) / 2
	
	# Update the right label to show the maximum picking size - which should be the entire stack
	$ui/pop_split/lbl_take.text = str(ssize)
	
	var x: float = mpos.x - (popsize.x / 2)
	var y: float = mpos.y - (popsize.y / 2)
	
	$ui/pop_split.popup(Rect2(Vector2(x, y), popsize))


func _on_sl_split_value_changed(value: float) -> void:
	var intval: int = int(value)
	$ui/pop_split/lbl_csplit.text = str(intval)


func _on_bt_oksplit_pressed() -> void:
	if (_splitinfo.empty()):
		return
	
	var picksize: int = $ui/pop_split/sl_split.value
	if (_splitinfo.container is InventoryBag):
		_splitinfo.container.pick_item_from(_splitinfo.column, _splitinfo.row, picksize)
	elif (_splitinfo.container is InventorySpecialSlot):
		_splitinfo.container.pick_item(picksize)
	
	_splitinfo.clear()
	$ui/pop_split.visible = false


func _on_bt_cancelsplit_pressed() -> void:
	$ui/pop_split.visible = false
	_splitinfo.clear()



#############################################################################################################
### Save and load the inventory state
# The extra tabs will NOT be saved here. The example here should be enough to exand into anything else that is
# desired.
func _on_bt_load_pressed() -> void:
	$ui/load_dlg.popup_centered()


func _on_bt_save_pressed() -> void:
	$ui/save_dlg.popup_centered()


func _on_load_dlg_file_selected(path: String) -> void:
	var file: File = File.new()
	if (file.open(path, File.READ) != OK):
		print("Failed to open \"", path, "\" to restore inventory state")
		return
	
	var pres: JSONParseResult = JSON.parse(file.get_as_text())
	# The file is not needed anymore so close it
	file.close()
	
	if (pres.error == OK):
		if (pres.result is Dictionary):
			var special: Dictionary = pres.result.get("special", {})
			var equip: Dictionary = pres.result.get("equip", {})
			var bags: Dictionary = pres.result.get("bags", {})
			
			# Note something very important here:
			# Special slots require dictionaries when loading from parsed json data
			# Bags require arrays when loading from parsed json data.
			for s in get_tree().get_nodes_in_group("special_slots"):
				if (s is InventorySpecialSlot):
					var nname: String = s.get_name()
					s.load_from_parsed_json(special.get(nname, {}))
			
			for e in get_tree().get_nodes_in_group("equip_slot"):
				if (e is InventorySpecialSlot):
					var nname: String = e.get_name()
					e.load_from_parsed_json(equip.get(nname, {}))
			
			for b in get_tree().get_nodes_in_group("bags"):
				if (b is InventoryBag):
					var nname: String = b.get_name()
					b.load_from_parsed_json(bags.get(nname, []))


func _on_save_dlg_file_selected(path: String) -> void:
	var file: File = File.new()
	if (file.open(path, File.WRITE) != OK):
		print("Failed to create the file to hold the inventory state at \"" + path + "\".")
		return
	
	var need_comma: bool = false
	
	file.store_string("{\n")
	# First save the contents of the special slots
	file.store_string("   \"special\": {\n")
	for s in get_tree().get_nodes_in_group("special_slots"):
		if (s is InventorySpecialSlot):
			if (need_comma):
				file.store_string(",\n")
			file.store_string("      " + s.get_contents_as_json())
			need_comma = true
	
	file.store_string("\n   },\n")
	need_comma = false
	
	# Now the "equip slots"
	file.store_string("   \"equip\": {\n")
	for s in get_tree().get_nodes_in_group("equip_slot"):
		if (s is InventorySpecialSlot):
			if (need_comma):
				file.store_string(",\n")
			file.store_string("      " + s.get_contents_as_json())
			need_comma = true
	
	file.store_string("\n   },\n")
	need_comma = false
	
	# The bags
	file.store_string("   \"bags\": {\n")
	for s in get_tree().get_nodes_in_group("bags"):
		if (s is InventoryBag):
			if (need_comma):
				file.store_string(",\n")
			
			file.store_string("      " + s.get_contents_as_json())
			need_comma = true
	
	file.store_string("   }\n")
	
	file.store_string("}")
	file.close()
