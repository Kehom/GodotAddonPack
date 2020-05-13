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

# Retrieve a game node given its unique ID and associated snapshot entity class
func get_game_node(uid: int, snapres: Resource) -> Node:
	var ename: Dictionary = _entity_name.get(snapres)
	var ret: Node = null
	
	if (ename):
		var einfo: EntityInfo = _entity_info.get(ename.hash)
		ret = einfo.get_game_node(uid)
	
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

		# Encode the entity hash ID, even if there is no entity of this type within
		# the snapshot
		into.write_uint(ehash)
		# Encode the amount of entities of this type
		into.write_uint(snap.get_entity_count(ehash))
		
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
	
	# Decode the input signature
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
	if (snap.input_sig > 0):
		# Locate the local snapshot with corresponding input signature. Remove it and all
		# older than that from the internal history
		while (_history.size() > 0 && _history.front().input_sig <= snap.input_sig):
			local = _history.pop_front()
		
		if (local.input_sig != snap.input_sig):
			# This should not occur!
			return
	
	else:
		local = _history.front() if _history.size() > 0 else null
	
	
	if (!local):
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


