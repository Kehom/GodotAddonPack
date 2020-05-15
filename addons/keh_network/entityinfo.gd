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

# This class is meant to somewhat "describe" classes derived from SnapEntityBase,
# which are used to represent game objects within the snapshots. This info
# helps automate encoding and decoding of the snapshots into raw bytes that
# can then be sent through the network. Each instance of this class will
# describe a class and will perform some of the tasks of encoding and decoding
# entities into the given buffer arrays.
# The network singleton automatically handles this so normally speaking there
# is no need to directly deal with objects of this class.

extends Reference
class_name EntityInfo


# Those are just shortcuts
const CTYPE_UINT: int = SnapEntityBase.CTYPE_UINT
const CTYPE_USHORT: int = SnapEntityBase.CTYPE_USHORT
const CTYPE_BYTE: int = SnapEntityBase.CTYPE_BYTE

# During the registration of snapshot entity objects, supported properties
# that can be replicated through this system must have some internal data
# necessary to help with the tasks. Each one will have an instance of this
# inner class.
class ReplicableProperty:
	var name: String
	var type: int
	var mask: int
	
	func _init(_name: String, _type: int, _mask: int) -> void:
		name = _name
		type = _type
		mask = _mask
	
	# Unfortunately must use variant (arguments) here instead of static type
	func compare(v1, v2) -> bool:
		return v1 == v2

# This is a specialized replicable property for floating point numbers when a tolerance must
# be used when comparing values. In this case the is_equal_approx() function is used
class RPropApprox extends ReplicableProperty:
	func _init(_name: String, _mask: int).(_name, TYPE_REAL, _mask) -> void:
		pass
	
	func compare(v1: float, v2: float) -> bool:
		return is_equal_approx(v1, v2)

# Vector2, Vector3, Quat etc offers a function to perform the is_equal_approx() on each
# component. This specialized ReplicableProperty performs the comparison using that
class RPropApproxi extends ReplicableProperty:
	func _init(_name: String, _type: int, _mask: int).(_name, _type, _mask) -> void:
		pass
	
	func compare(v1, v2) -> bool:
		return v1.is_equal_approx(v2)

# Although a bunch of work to create one specialized replicable property for each one
# of the types bellow, it has been done because there is no easy easy way to directly
# access each component of "compound types" without using the correct names. Moreover,
# instead of creating a new base for each of those, still directly use ReplicableProperty
# as base in order to help with readability and **maybe** performance
# Nevertheless, the specializations bellow are meant to offer custom tolerance values
# to compare floating point values
class RPropTolFloat extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_REAL, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: float, v2: float) -> bool:
		return (abs(v1 - v2) < tolerance)

class RPropTolVec2 extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_VECTOR2, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: Vector2, v2: Vector2) -> bool:
		return (abs(v1.x - v2.x) < tolerance &&
			abs(v1.y - v2.y) < tolerance)

class RPropTolRec2 extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_RECT2, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: Rect2, v2: Rect2) -> bool:
		return (abs(v1.position.x - v2.position.x) < tolerance &&
			abs(v1.position.y - v2.position.y) < tolerance &&
			abs(v1.size.x - v2.size.x) < tolerance &&
			abs(v1.size.y - v2.size.y) < tolerance)

class RPropTolQuat extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_QUAT, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: Quat, v2: Quat) -> bool:
		return (abs(v1.x - v2.x) < tolerance &&
			abs(v1.y - v2.y) < tolerance &&
			abs(v1.z - v2.z) < tolerance &&
			abs(v1.w - v2.w) < tolerance)

class RPropTolVec3 extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_VECTOR3, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: Vector3, v2: Vector3) -> bool:
		return (abs(v1.x - v2.x) < tolerance &&
			abs(v1.y - v2.y) < tolerance &&
			abs(v1.z - v2.z) < tolerance)

class RPropTolColor extends ReplicableProperty:
	var tolerance: float
	func _init(_name: String, _mask: int, _tolerance: float).(_name, TYPE_COLOR, _mask) -> void:
		tolerance = _tolerance
	
	func compare(v1: Color, v2: Color) -> bool:
		return (abs(v1.r - v2.r) < tolerance &&
			abs(v1.g - v2.g) < tolerance &&
			abs(v1.b - v2.b) < tolerance &&
			abs(v1.a - v2.a) < tolerance)


# Storing registered spawners could be done through dictionaries however
# that did result in errors when trying to reference non existing spawners.
# Namely, assigning "nill to a variable of type dictionary". Because of that,
# using this inner class to hold the registered spawner data
class SpawnerData:
	var spawner: NetNodeSpawner
	var parent: Node
	var extra_setup: FuncRef
	
	func _init(s: NetNodeSpawner, p: Node, es: FuncRef) -> void:
		spawner = s
		parent = p
		extra_setup = es

# The entity type name is hashed into this property
var _name_hash: int
# Resource that is used in order to create instances of the object described by 
# this entity info.
var _resource: Resource
# The replicable properties list. Each entry in this array is an instance of the
# inner class ReplicableProperty
var replicable: Array
# This is held mostly to help with debugging
var _namestr: String
# Snap entity objects may disable the class_hash and this info is cashed in this
# property to make things simpler to deal with when encoding/decoding data.
var _has_chash: bool = true

# If this string is not empty after instantiating this class, then there was an error,
# with details stored in the property
var error: String

# When encoding delta snapshot, the change mask has to be added before the entity
# itself. This variable holds how many bytes (1, 2 or 4) are used for this information
# within the raw data for this entity type. Yes, this sort of limit the number of
# properties per entity to only 30/31 (id takes one spot and if not disabled the
# class_hash takes another)).
var _cmask_size: int

# Key = unique id
# Value = Node that is created and added into the game world 
var _nodes: Dictionary


# Key = class_hash - yes, this sort of force the creation of multiple spawners, even if the
# actual class_hash only points to inner properties of the spawned node. This design decision
# greatly simplifies the automatic snapshot system.
# Value = Instances of the SpawnerData inner class
var _spawner_data: Dictionary = {}


func _init(cname: String, rpath: String) -> void:
	replicable = []
	# Verifies if the resource contains replicable properties and if implements
	# the required apply_state(node) function.
	_check_properties(cname, rpath)

	if replicable.size() <= 8:
		_cmask_size = 1
	elif replicable.size() <= 16:
		_cmask_size = 2
	else:
		_cmask_size = 4


# Spawners (classes derived from NetNodeSpawner) are necessary in order to automate the
# node spawning during the synchronization. The class_hash becomes the ID key to the
# spawner. The parent is where the new node will be attached to when it get instanced.
# The esetup is an optional function reference that will be called when a new node is
# spawned in order to perform extra setup. That function will receive the node itself
# as only argument.
func register_spawner(chash: int, spawner: NetNodeSpawner, parent: Node, esetup: FuncRef) -> void:
	assert(spawner)
	assert(parent)
	
	_spawner_data[chash] = SpawnerData.new(spawner, parent, esetup)


# Creates an instance of the entity described by this object.
func create_instance(uid: int, chash: int) -> SnapEntityBase:
	assert(_resource)
	return _resource.new(uid, chash)


# Creates a clone of the specified entity.
func clone_entity(entity: SnapEntityBase) -> SnapEntityBase:
	var ret: SnapEntityBase = create_instance(entity.id, entity.class_hash)
	
	for repl in replicable:
		if (repl.name != "id" && repl.name != "class_hash"):
			ret.set(repl.name, entity.get(repl.name))
	
	return ret


# Just to give a different access to the change mask size property.
func get_change_mask_size() -> int:
	return _cmask_size


# Compare two entities described by this instance and return a value that
# can be used as a change mask. In other words, a non zero value means the
# two given entities are in different states.
func calculate_change_mask(e1: SnapEntityBase, e2: SnapEntityBase) -> int:
	assert(typeof(e1) == typeof(e2))
	
	# The change mask
	var cmask: int = 0
	
	for p in replicable:
		if (!p.compare(e1.get(p.name), e2.get(p.name))):
			cmask |= p.mask
	
	return cmask


# Fully encode the given snapshot entity object into the specified byte buffer
func encode_full_entity(entity: SnapEntityBase, into: EncDecBuffer) -> void:
	# Ensure id is encoded first
	into.write_uint(entity.id)
	# Next, if the class_hash has not been disabled, encode it first
	if (_has_chash):
		into.write_uint(entity.class_hash)
	
	for repl in replicable:
		if (repl.name != "id" && repl.name != "class_hash"):
			_property_writer(repl, entity, into)


# Given the raw byte array, decode an entity from it and return the instance
# with the properties set. This assumes the reading index is at the desired
# position
func decode_full_entity(from: EncDecBuffer) -> SnapEntityBase:
	# Read the unique ID
	var uid: int = from.read_uint()
	# If the class_hash has not been disabled, read it
	var chash: int = from.read_uint() if _has_chash else 0
	
	var ret: SnapEntityBase = create_instance(uid, chash)
	
	# Read/decode each one of the replicable properties
	for repl in replicable:
		if (repl.name != "id" && repl.name != "class_hash"):
			_property_reader(repl, from, ret)
	
	return ret




# Retrieve a game node given its unique ID.
func get_game_node(uid: int) -> Node:
	return _nodes.get(uid)


# Perform full cleanup of the internal container that is used to manage the
# game nodes.
func clear_nodes() -> void:
	for uid in _nodes:
		if (!_nodes[uid].is_queued_for_deletion()):
			_nodes[uid].queue_free()
	
	_nodes.clear()


func spawn_node(uid: int, chash: int) -> Node:
	var ret: Node = null

	var sdata: SpawnerData = _spawner_data.get(chash)
	if (sdata):
		ret = sdata.spawner.spawn()

		ret.set_meta("uid", uid)
		ret.set_meta("chash", chash)

		_nodes[uid] = ret
		sdata.parent.add_child(ret)
		
		if (sdata.extra_setup && sdata.extra_setup.is_valid()):
			sdata.extra_setup.call_func(ret)
		
	else:
		var w: String = "Could not retrieve spawner for entity %s with unique ID %d."
		push_warning(w % [_namestr, uid])
	
	return ret


func despawn_node(uid: int) -> void:
	var n: Node = _nodes.get(uid)
	
	if (n):
		if (!n.is_queued_for_deletion()):
			n.queue_free()
		
		# warning-ignore:return_value_discarded
		_nodes.erase(uid)


# Game object nodes added through the editor that are meant to be replicated
# must be registered within the network system. This function performs this
func add_pre_spawned(uid: int, node: Node) -> void:
	_nodes[uid] = node


# This will check the specified resource and if there are any replicable
# properties finalize the initialization of this object.
func _check_properties(cname: String, rpath: String) -> void:
	_resource = load(rpath)
	
	if (!_resource):
		return
	
	# Unfortunately it's necessary to create an instance of the class in order
	# to traverse its properties and methods. Since this is a dummy object
	# uid and class_hash are irrelevant
	var obj: SnapEntityBase = create_instance(0, 0)
	
	if (!obj):
		_resource = null
		error = "Unable to create dummy instance of the class %s (%s)"
		error = error % [cname, rpath]
		return
	
	if (!obj.has_method("apply_state")):
		_resource = null
		error = "Method apply_state(Node) is not implemented."
		return
	
	var mask: int = 1
	var plist: Array = obj.get_property_list()
	var min_size: int = 2      # Assume class_hash is not disabled
	
	for p in plist:
		if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			# If this property is the class_hash and the meta "class_hash" is set
			# to 0, then skip it as it means it's desired to be disabled
			if (p.name == "class_hash" && obj.get_meta("class_hash") == 0):
				_has_chash = false
				min_size -= 1
				continue
			
			var tp: int = p.type
			var rprop: ReplicableProperty = _build_replicable_prop(p.name, tp, mask, obj)
			
			if (rprop):
				# Push the replicable property into the internal container
				replicable.push_back(rprop)
				# Advance the mask
				mask *= 2
	
	
	# After iterating through available properties, verify if there is at least
	# one replicable property besides "id" and "class_hash" taking into account
	# the fact that class_hash may be disabled).
	if (replicable.size() <= min_size):
		_resource = null
		error = "There are no defined (supported) replicable properties."
		return
	
	_name_hash = cname.hash()
	_namestr = cname
	_nodes = {}


# Based on the given instance of ReplicableProperty, reads a property from the
# byte buffer into an instance of the snapshot entity object.
func _property_reader(repl: ReplicableProperty, from: EncDecBuffer, into: SnapEntityBase) -> void:
	match repl.type:
		TYPE_BOOL:
			into.set(repl.name, from.read_bool())
		TYPE_INT:
			into.set(repl.name, from.read_int())
		TYPE_REAL:
			into.set(repl.name, from.read_float())
		TYPE_VECTOR2:
			into.set(repl.name, from.read_vector2())
		TYPE_RECT2:
			into.set(repl.name, from.read_rect2())
		TYPE_QUAT:
			into.set(repl.name, from.read_quat())
		TYPE_COLOR:
			into.set(repl.name, from.read_color())
		TYPE_VECTOR3:
			into.set(repl.name, from.read_vector3())
		CTYPE_UINT:
			into.set(repl.name, from.read_uint())
		CTYPE_BYTE:
			into.set(repl.name, from.read_byte())
		CTYPE_USHORT:
			into.set(repl.name, from.read_ushort())

# Based on the given instance of ReplicableProperty, writes a property from the
# instance of snapshot entity object into the specified byte array
func _property_writer(repl: ReplicableProperty, entity: SnapEntityBase, into: EncDecBuffer) -> void:
	# Relying on the variant feature so no static typing here
	var val = entity.get(repl.name)
	
	match repl.type:
		TYPE_BOOL:
			into.write_bool(val)
		TYPE_INT:
			into.write_int(val)
		TYPE_REAL:
			into.write_float(val)
		TYPE_VECTOR2:
			into.write_vector2(val)
		TYPE_RECT2:
			into.write_rect2(val)
		TYPE_QUAT:
			into.write_quat(val)
		TYPE_COLOR:
			into.write_color(val)
		TYPE_VECTOR3:
			into.write_vector3(val)
		CTYPE_UINT:
			into.write_uint(val)
		CTYPE_BYTE:
			into.write_byte(val)
		CTYPE_USHORT:
			into.write_ushort(val)



func _build_replicable_prop(name: String, tp: int, mask: int, obj: Object) -> ReplicableProperty:
	var ret: ReplicableProperty = null
	
	match tp:
		TYPE_INT:
			# Check if this integer is meant to be used with a different size in bytes
			# when encoding/decoding into a byte array
			if (obj.has_meta(name)):
				var mval: int = obj.get_meta(name)
				match mval:
					CTYPE_UINT, CTYPE_BYTE, CTYPE_USHORT:
						tp = mval
			
			# Use the regular ReplicableProperty because integers don't need tolerance to compare them
			ret = ReplicableProperty.new(name, tp, mask)
		
		TYPE_REAL, TYPE_VECTOR2, TYPE_RECT2, TYPE_QUAT, TYPE_VECTOR3, TYPE_COLOR:
			# In here, any specialized comparison will be left for later in this function
			if (!obj.has_meta(name)):
				# This property does not require any special comparison method, so just
				# use the default replicable property class
				ret = ReplicableProperty.new(name, tp, mask)
		
		TYPE_BOOL:
			ret = ReplicableProperty.new(name, tp, mask)
		
		_:
			# This is not a supported type. Bail so the test bellow can be done
			return null
	
	if (!ret):
		# If here, the type is supported but it does require one of the specialized ReplicableProperty
		# because a tolerance is required when comparing values. What this means is, the test for the
		# existance of the meta has already been done
		var tol: float = obj.get_meta(name)
		
		if (tol <= 0.0):
			# No custom tolerance is requested so use the is_equal_approx() function
			if (tp == TYPE_REAL):
				ret = RPropApprox.new(name, mask)
			else:
				ret = RPropApproxi.new(name, tp, mask)
		
		else:
			# A custom tolerance is required. This means the specific type must be known in order to
			# create the correct replicable property
			match (tp):
				TYPE_REAL:
					ret = RPropTolFloat.new(name, mask, tol)
				TYPE_VECTOR2:
					ret = RPropTolVec2.new(name, mask, tol)
				TYPE_RECT2:
					ret = RPropTolRec2.new(name, mask, tol)
				TYPE_QUAT:
					ret = RPropTolQuat.new(name, mask, tol)
				TYPE_VECTOR3:
					ret = RPropTolVec3.new(name, mask, tol)
				TYPE_COLOR:
					ret = RPropTolColor.new(name, mask, tol)
	
	return ret
