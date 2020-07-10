###############################################################################
# Copyright (c) 2019 Yuri Sarudiansky
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

# Only a single instance of this class is necessary and is automatically
# done within the network singleton.
# This class is meant to manage the instances of the high level snapshot
# objects.

extends Reference
class_name NetSnapshotData


# Each entry in this dictionary is an instance of the EntityInfo, keyed by the
# hashed name of the entity class derived from SnapEntityBase (snapentity.gd)
var _entity_info: Dictionary = {}

# This dictionary is a helper container that takes the resource name (normally
# directly the class_name) and points to the hashed name, which will then help
# get into the desired entry within _entity_info
var _entity_name: Dictionary = {}

# Holds the history of snapshots
var _history: Array = []

# This object will hold the most recent snapshot data received from the server.
# When delta snapshot is received, a reference must be used in order to rebuild
# the full snapshot, which will be exactly the contents of this object.
var _server_state: NetSnapshot = null



func _init() -> void:
	register_entity_types()


# This function gather the list of available (script) classes and for each entry
# corresponding to a class derived from SnapEntityBase will then be further analyzed.
# In that case, provided it contains any valid replicable property and implements
# the necessary methods, it will be automatically registered within the valid
# classes that can be represented within the snapshots.
func register_entity_types() -> void:
	# Each entry in the obtained array is a dictionary containing the following fields:
	# base, class, language, path
	var clist: Array = ProjectSettings.get_setting("_global_script_classes") if ProjectSettings.has_setting("_global_script_classes") else []
	
	for c in clist:
		# Only interested in classes derived from SnapEntityBase
		if (c.base == "SnapEntityBase"):
			var edata: EntityInfo = EntityInfo.new(c.class, c.path)
			
			if (edata.error.length() > 0):
				var msg: String = "Skipping registration of class %s (%d). Reason: %s"
				push_warning(msg % [c.class, edata._name_hash, edata.error])
			
			else:
				print_debug("Registering snapshot object type ", c.class, " with hash ", edata._name_hash)
				
				# This is the actual registration of the object type
				_entity_info[edata._name_hash] = edata
				# And this will help obtain the necessary data given the class' resource
				_entity_name[edata._resource] = {
					"name": c.class,
					"hash": edata._name_hash,
				}



# Spawners are the main mean to create game nodes in association with the various
# classes derived from SnapEntityBase
func register_spawner(eclass: Resource, chash: int, spawner: NetNodeSpawner, parent: Node, esetup: FuncRef = null) -> void:
	# Using this assert to ensure that if a function reference for extra setup is given, it's at
	# least valid. Using assert because it becomes removed from release builds
	assert(!esetup || esetup.is_valid())
	
	var ename: Dictionary = _entity_name.get(eclass)
	if (!ename):
		var e: String = "Trying to register spawner associated with snapshot entity class defined in %s, which is not registered."
		push_error(e % eclass.resource_path)
		return
	
	var einfo: EntityInfo = _entity_info.get(ename.hash)
	einfo.register_spawner(chash, spawner, parent, esetup)


# Spawn a game node using a registered spawner
func spawn_node(eclass: Resource, uid: int, chash: int) -> Node:
	var ret: Node = null
	
	var ename: Dictionary = _entity_name.get(eclass)
	if (ename):
		var einfo: EntityInfo = _entity_info.get(ename.hash)
		ret = einfo.spawn_node(uid, chash)
	
	return ret

# Internally used to retrieve the EntityInfo instance associated with specified snapshot entity class
func _get_entity_info(snapres: Resource) -> EntityInfo:
	var ename: Dictionary = _entity_name.get(snapres)
	if (ename):
		return _entity_info.get(ename.hash)
	
	return null

# Retrieve a game node given its unique ID and associated snapshot entity class
func get_game_node(uid: int, snapres: Resource) -> Node:
	var ret: Node = null
	var einfo: EntityInfo = _get_entity_info(snapres)
	if (einfo):
		ret = einfo.get_game_node(uid)
	
	return ret


# Retrieve the prediction count for the specified entity
func get_prediction_count(uid: int, snapres: Resource) -> int:
	var ret: int = 0
	var einfo: EntityInfo = _get_entity_info(snapres)
	if (einfo):
		ret = einfo.get_pred_count(uid)
	
	return ret



# Despawn a node from the game
func despawn_node(eclass: Resource, uid: int) -> void:
	var ename: Dictionary = _entity_name.get(eclass)
	if (ename):
		var einfo: EntityInfo = _entity_info.get(ename.hash)
		einfo.despawn_node(uid)

# Adds a "pre-spawned" node into the internal node management so it can be
# properly handled (located) by the replication system.
func add_pre_spawned_node(eclass: Resource, uid: int, node: Node) -> void:
	var ename: Dictionary = _entity_name.get(eclass)
	if (ename):
		var einfo: EntityInfo = _entity_info.get(ename.hash)
		einfo.add_pre_spawned(uid, node)


# Locate the snapshot given its signature and return it, null if not found
func get_snapshot(signature: int) -> NetSnapshot:
	for s in _history:
		if (s.signature == signature):
			return s
	
	return null

func get_snapshot_by_input(isig: int) -> NetSnapshot:
	for s in _history:
		if (s.input_sig == isig):
			return s
	
	return null


func reset() -> void:
	for ehash in _entity_info:
		_entity_info[ehash].clear_nodes()
	
	_server_state = null
	_history.clear()


# Encode the provided snapshot into the given EncDecBuffer, "attaching" the given
# input signature as part of the data. This function encodes the entire snapshot
func encode_full(snap: NetSnapshot, into: EncDecBuffer, isig: int) -> void:
	# Encode signature of the snapshot
	into.write_uint(snap.signature)
	
	# Encode the input signature
	into.write_uint(isig)
	
	# Iterate through the valid entity types
	for ehash in _entity_info:
		# First bandwidth optimization -> don't encode entity type + quantity
		# if the quantity is 0.
		var ecount: int = snap.get_entity_count(ehash)
		if (ecount == 0):
			continue
		
		# There is at least one entity to be encoded, so obtain the description
		# object to help with the entities
		var einfo: EntityInfo = _entity_info[ehash]
		
		# Encode the entity hash ID
		into.write_uint(ehash)
		# Encode the amount of entities of this type
		into.write_uint(ecount)
		
		# Encode the entities of this type
		for uid in snap._entity_data[ehash]:
			# Get the entity in order to encode the properties
			var entity: SnapEntityBase = snap.get_entity(ehash, uid)
			
			einfo.encode_full_entity(entity, into)


# Decode the snapshot data from the provided EncDecBuffer, returning an instance of
# NetSnapshot.
func decode_full(from: EncDecBuffer) -> NetSnapshot:
	# Decode the signature of the snapshot
	var sig: int = from.read_uint()
	# Decode the input signature
	var isig: int = from.read_uint()
	
	# This function is called only on clients, where verified snapshots are removed
	# from its history. This means that if this snapshot is older than the first
	# in the container then it can be discarded. However the matching system here
	# uses the input signature and not the snapshot signature (which is used to
	# acknowledge data to the server).
	if (isig > 0 && _history.size() > 0 && isig < _history.front().input_sig):
		return null
	
	var retval: NetSnapshot = NetSnapshot.new(sig)
	
	# "Attach" input signature into the snapshot
	retval.input_sig = isig
	
	# The snapshot checking algorithm requires that each entity type has its
	# entry within the snapshot data, so add them
	for ehash in _entity_info:
		retval.add_type(ehash)
	
	
	# Decode the entities
	while from.has_read_data():
		# Read the entity type ID
		var ehash: int = from.read_uint()
		
		var einfo: EntityInfo = _entity_info.get(ehash)
		
		if (!einfo):
			var e: String = "While decoding full snapshot data, got an entity type hash %d which doesn't map to any valid registered entity type."
			push_error(e % ehash)
			return null
		
		# Take number of entities of this type
		var count: int = from.read_uint()
		
		for _i in count:
			var entity: SnapEntityBase = einfo.decode_full_entity(from)
			if (entity):
				retval.add_entity(ehash, entity)
	
	return retval


func encode_delta(snap: NetSnapshot, oldsnap: NetSnapshot, into: EncDecBuffer, isig: int) -> void:
	# Scan oldsnap comparing to snap. Encode only the changes. Removed entities must
	# be explicitly encoded with a "change mask = 0"
	# Scanning will iterate through entities in the snap object. The same entity will
	# be retrieved from oldsnap. If not found, then assume iterated entity is new.
	# A list must be used to keep track of entities that are in the older snapshot but
	# not on the newer one, indicating removed game object.
	
	# Encode snapshot signature
	into.write_uint(snap.signature)
	
	# Encode input signature
	into.write_uint(isig)
	
	# Encode a flag indicating if there is any change at all in this snapshot - assume there isn't
	into.write_bool(false)
	# But not for the actual flag here. It's easier to change this to true
	var has_data: bool = false
	
	# During entity scanning, entries from this container will be removed. After the loop,
	# any remaining entries are entities removed from the game
	var tracker: Dictionary = oldsnap.build_tracker()
	
	# Iterate through the valid entity types
	for ehash in _entity_info:
		# Get entity count in the new snapshot
		var necount: int = snap.get_entity_count(ehash)
		# Get entity count in the old snapshot
		var oecount: int = oldsnap.get_entity_count(ehash)
		
		# Don't encode entity type + quantity if both are 0
		if (necount == 0 && oecount == 0):
			continue
		
		# At least one of the snapshots contains entities of this type. Assume every
		# single entity has been changed
		var ccount: int = necount
		
		var einfo: EntityInfo = _entity_info[ehash]
		
		
		# NOTE: Postponing encoding of typehash plus change count to a moment where it is
		# sure there is at least one changed entity of this type. Originally trie to do
		# things normally and remove the relevant bytes from the buffer array but it didn't
		# work very well.
		# This flag is used to tell if the typehash plus change count has been encoded or
		# not, just to prevent multiple encodings of this data
		var written_type_header: bool = false
		
		# Get the writing position of the entity count as most likely it will be updated
		var countpos: int = into.get_current_size() + 4
		
		# Check the entities
		for uid in snap._entity_data[ehash]:
			# Retrive old state of this entity - obviously if it exists (if not this will be null)
			var eold: SnapEntityBase = oldsnap.get_entity(ehash, uid)
			# Retrieve new state of this entity - it should exist as the iteration is based on the
			# new snapshot.
			var enew: SnapEntityBase = snap.get_entity(ehash, uid)
			
			# Assume the entity is new
			var cmask: int = einfo.get_full_change_mask()
			
			if (eold && enew):
				# Ok, entity exist on both snapshots so it's not new. Calculate the "real" change mask
				cmask = einfo.calculate_change_mask(eold, enew)
				# Remove this from the tracker so it isn't considered as a removed entity
				tracker[ehash].erase(uid)
				
			
			if (cmask != 0):
				if (!written_type_header):
					# Write the entity type has ID.
					into.write_uint(ehash)
					# And the change counter
					into.write_uint(ccount)
					# Prevent rewriting the information
					written_type_header = true
				
				# This entity requires encoding
				einfo.encode_delta_entity(uid, enew, cmask, into)
				has_data = true
			
			else:
				# The entity was not changed. Update the change counter
				ccount -= 1
		
		# Check the tracker for entities that are in the old snapshot but not in the new one.
		# In other words, entities that were removed from the game world
		# Those must be encoded with a change mask set to 0, which will indicate remove entities
		# when being decoded.
		for uid in tracker[ehash]:
			if (!written_type_header):
				into.write_uint(ehash)
				into.write_uint(ccount)
				written_type_header = true
			
			einfo.encode_delta_entity(uid, null, 0, into)
			ccount += 1
		
		if (ccount > 0):
			into.rewrite_uint(ccount, countpos)
	
	# Everything iterated through. Check if there is anything at all
	if (has_data):
		into.rewrite_bool(true, 8)


# In here the "old snapshot" is not needed because it is basically a property in this
# class (_server_state)
func decode_delta(from: EncDecBuffer) -> NetSnapshot:
	# Decode snapshot signature
	var snapsig: int = from.read_uint()
	# Decode input signature
	var isig: int = from.read_uint()
	
	# This check is explained in the decode_full() function
	if (isig > 0 && _history.size() > 0 && isig < _history.front().input_sig):
		return null
	
	var retval: NetSnapshot = NetSnapshot.new(snapsig)
	
	retval.input_sig = isig
	
	# The snapshot checking algorithm requires that each entity type has its
	# entry within the snapshot data, so add them
	for ehash in _entity_info:
		retval.add_type(ehash)
	
	# Check if the flag indicating if there is any data at all
	var has_data: bool = from.read_bool()
	
	# This will be used to track unchaged entities. Basically, when an entity is decoded,
	# the corresponding entry will be removed from this data. After that, remaining entries
	# here are indicating entities that didn't change and must be copied into the new snapshot
	var tracker: Dictionary = _server_state.build_tracker()
	
	if (has_data):
		# Decode the entities
		while from.has_read_data():
			# Read entity type ID
			var ehash: int = from.read_uint()
			var einfo: EntityInfo = _entity_info.get(ehash)
			
			if (!einfo):
				var e: String = "While decoding delta snapshot data, got an entity type hash %d which doesn't map to any valid registered entity type."
				push_error(e % ehash)
				return null
			
			# Take number of encoded entities of this type
			var count: int = from.read_uint()
			
			# Decode them
			for _i in count:
				var edata: Dictionary = einfo.decode_delta_entity(from)
				
				var oldent: SnapEntityBase = _server_state.get_entity(ehash, edata.entity.id)
				
				if (oldent):
					# The entity exists in the old state. Check if it's not marked for removal
					if (edata.cmask > 0):
						# It isn't. So, "match" the delta to make the data correct (that is, take unchanged)
						# data from the old state and apply into the new one.
						einfo.match_delta(edata.entity, oldent, edata.cmask)
						# Add the changed entity into the return value
						retval.add_entity(ehash, edata.entity)
					
					# This is a changed entity, so remove it from the tracker
					tracker[ehash].erase(edata.entity.id)
				
				else:
					# Entity is not in the old state. Add the decoded data into the return value in the
					# hopes it is holding the entire correct data (this can be checked by comparing the cmask though)
					# Change mask can be 0 in this case, when the acknowledgement still didn't arrive theren when
					# server dispatched a new data set.
					if (edata.cmask > 0):
						retval.add_entity(ehash, edata.entity)
	
	# Check the tracker now
	for ehash in tracker:
		var einfo: EntityInfo = _entity_info.get(ehash)
		for uid in tracker[ehash]:
			var entity: SnapEntityBase = _server_state.get_entity(ehash, uid)
			retval.add_entity(ehash, einfo.clone_entity(entity))
	
	return retval




# This function is meant to be run on clients but not called remotely. The objective here
# is to take the provided snapshot, which contains server's data, locate the internal
# corresponding snapshot and compare them. Any differences are to be considered as errors
# in the client's prediction and must be corrected using the server's data.
# Corresponding snapshot means, primarily, the snapshot with the same input signatures.
# However, it's possible the server will send snapshot without any client's input. This will
# always be the case at the very beginning of the client's session, when there is no
# server data to initiate the local simulation. Still, if there is enough data loss
# during the synchronization then the sever will have to send snapshot data without any
# client's input.
# That said, the overall tasks here:
# - Snapshot contains input -> locate the snapshot in the history with the same input
#   signature and use that one to compare, removing any older (or equal) from the history.
# - Snapshot does not contain input -> take the last snapshot in the history to use for
#   comparison and don't remove anything from the history.
# During the comparison, any difference must be corrected by applying the server state into
# all snapshots in the local history.
# On errors the ideal path is to locally re-simulate the game using cached input data
# just so no input is missed on small errors. Since this is not possible with Godot then
# just apply the corrected state into the corresponding nodes and hope the interpolation
# will make things look "less glitchy"
func client_check_snapshot(snap: NetSnapshot) -> void:
	var local: NetSnapshot = null
	var popcount: int = 0
	if (snap.input_sig > 0):
		
		# Locate the local snapshot with corresponding input signature. Remove it and all
		# older than that from the internal history
		while (_history.size() > 0 && _history.front().input_sig <= snap.input_sig):
			local = _history.pop_front()
			popcount += 1
		
		if (local.input_sig != snap.input_sig):
			_update_prediction_count(-popcount)
			# This should not occur!
			return
	
	else:
		local = _history.front() if _history.size() > 0 else null
	
	
	if (!local):
		_update_prediction_count(-popcount)
		# This should not occur!
		return
	
	_server_state = snap
	
	for ehash in _entity_info:
		var einfo: EntityInfo = _entity_info[ehash]
		
		# The entity type *must* exist on both ends
		assert(local._entity_data.has(ehash))
		assert(snap._entity_data.has(ehash))
		
		# Retrieve the list of entities on the local snapshot. This will be used to
		# track ones that are locally present but not on the server's data.
		var local_entity: Array = local._entity_data[ehash].keys()
		
		# Iterate through entities of the server's snapshot
		for uid in snap._entity_data[ehash]:
			var rentity: SnapEntityBase = snap.get_entity(ehash, uid)
			var lentity: SnapEntityBase = local.get_entity(ehash, uid)
			var node: Node = null
			
			if (rentity && lentity):
				# Entity exists on both ends. First update the local_entity array because
				# it's meant to hold entities that are present only in the local machine
				local_entity.erase(uid)
				
				# And now check if there is any difference
				var cmask: int = einfo.calculate_change_mask(rentity, lentity)
				
				if (cmask > 0):
					# There is at least one property with different values. So, it must be corrected.
					node = einfo.get_game_node(uid)
			
			else:
				# Entity exists only on the server's data. If necessary spawn the game node.
				var n: Node = einfo.get_game_node(uid)
				if (!n):
					node = einfo.spawn_node(uid, rentity.class_hash)
			
			
			if (node):
				# If here, then it's necessary to apply the server's state into the node
				rentity.apply_state(node)
				
				# "Propagate" the server's data into every snapshot in the local history
				for s in _history:
					s.add_entity(ehash, einfo.clone_entity(rentity))
		
		# Now check the entities that are in the local snapshot but not on the
		# remote one. The local ones must be removed from the game.
		for uid in local_entity:
			despawn_node(einfo._resource, uid)
	
	# All entities have been verified. Now update the prediction count
	_update_prediction_count(-popcount)


func _add_to_history(snap: NetSnapshot) -> void:
	_history.push_back(snap)
	
	pass

func _check_history_size(max_size: int, has_authority: bool) -> void:
	var popped: int = 0
	
	while (_history.size() > max_size):
		_history.pop_front()
		popped += 1
	
	if (!has_authority):
		_update_prediction_count(1 - popped)

# Internally used, this updates the prediction count of each entity
func _update_prediction_count(delta: int) -> void:
	for ehash in _entity_info:
		var einfo: EntityInfo = _entity_info[ehash]
		einfo.update_pred_count(delta)
