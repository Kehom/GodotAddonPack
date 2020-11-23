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

# Holds necessary data for each connected player. Because this is a node
# it will be part of the tree hierarchy, more specifically as a child of
# the network singleton.
# Besides holding data, it's also where the input data is retrieved and
# replicated to.
# Note that while it's OK to directly access objects of this class, manually
# creating then is absolutely unnecessary.


extends Node
class_name NetPlayerNode

var net_id: int = 1 setget set_network_id

# The input cache is used in two different ways, depending on which machine
# it's running and which player this node corresponds to.
# Running on server:
# - If this node corresponds to the local player (the server), then the
#   cache does nothing because there is no need to validate its data.
# - If this node corresponds to a client then the cache will hold the
#   received input data, which will be retrieved from it when iterating
#   the game state. At that moment the input is removed from the buffer
#   and a secondary container holds information that maps from the
#   snapshot signature to the used input signature. With this information
#   when encoding snapshot data it's possible to attach to it the
#   signature of the input data used to simulate the game. Another thing
#   to keep in mind is that incoming input data may be out of order or
#   duplicated. To that end it's a lot simpler to deal with a dictionary
#   to hold the objects.
# Running on client:
# - If this node corresponds to a remote player, does nothing because a
#   client knows nothing about other clients nor the server in regards
#   to input data.
# - If this node corresponds to the local player then the cache must
#   hold a sequential (ascending) set of input objects that are mostly
#   meant for validation when snapshot data arrives. When validating,
#   any input older than the one just checked must be removed from the
#   container, thus keeping this data in ascending order makes things
#   a lot easier. In this case it's better to have an array rather than
#   dictionary to hold this data.
# With all this information in mind, this inner class is meant to make
# things a bit easier to deal with those differences.
class InputCache:
	# Key = input signature | value = instance of InputData
	# This is meant for the server
	var sbuffer: Dictionary
	# The container used by the client. It is necessary so non acknowledged
	# input data must be sent again.
	var cbuffer: Array
	# Keep track of the last input signature used by this machine
	var last_sig: int
	# This will be used only on the server and each entry is keyed by the snapshot
	# signature, holding the input signature as value.
	var snapinpu: Dictionary
	# Count the number of 0-input snapshots that weren't acknowledged by the client
	# If this value is bigger than 0 then the server will send the newest full
	# snapshot within its history rather than calculating delta snapshot
	var no_input_count: int
	# Holds the signature of the last acknowledged snapshot signature. This will be
	# used as reference to cleanup older data.
	var last_ack_snap: int
	
	func _init() -> void:
		sbuffer = {}
		cbuffer = []
		last_sig = 0
		snapinpu = {}
		no_input_count = 0
		last_ack_snap = 0
	
	# Creates the association of snapshot signature with input for the corresponding
	# player. This will automatically take care of the "no input count"
	func associate(snap_sig: int, isig: int) -> void:
		snapinpu[snap_sig] = isig
		if (isig == 0):
			no_input_count += 1
	
	# Acknowledges the specified snapshot signature by removing it from the snapinpu
	# container. It automatically updates the "no_input_count" property by subtracting
	# from it if the given snapshot didn't use any input
	func acknowledge(snap_sig: int) -> void:
		# Depending on how the synchronization occurred, it's possible some older data
		# didn't get a direct acknowledgement but those are now irrelevant. So, the
		# cleanup must be performed through a loop that goes from the last acknowledged
		# up to the one specified. During this loop the "no_input_count" must be
		# correctly updated
		for sig in range(last_ack_snap + 1, snap_sig + 1):
			var isig: int = snapinpu.get(sig, -1)
			if (isig > -1):
				# warning-ignore:return_value_discarded
				snapinpu.erase(sig)
				if (isig == 0):
					no_input_count -= 1
		
		last_ack_snap = snap_sig


# The input cache
var _input_cache: InputCache

# Used to encode/decode input data
var _edec_input: EncDecBuffer

# Server will only send snapshot data to this client when this flag is
# set to true.
var _is_ready: bool = false setget set_ready

# Input info, necessary to properly deal with input
var _input_info: NetInputInfo

# This flag is meant to help identify if this node corresponds to the local player or not
# and is relevant mostly on the server.
var _is_local: bool

# The ping/pong system
var _ping: NetPingInfo

# Custom data system. Entries here:
# Key = custom property name
# Value = instance of NetCustomProperty
var _custom_data: Dictionary

# Counts how many custom properties have been changed and not replicated yet.
var _custom_prop_dirty_count: int = 0

# These vectors will be used to cache mouse data from the _input function
# Obviously those will only be used on the local machine
#var _mposition: Vector2 = Vector2()       # Should mouse position be used?
var _mrelative: Vector2 = Vector2()
var _mspeed: Vector2 = Vector2()

# When set to false it will disable polling input for local player
var _local_input_enabled: bool = true

### Options retrieved from project settings
var _broadcast_ping: bool = false

# "Signaler" for new ping values
var ping_signaler: FuncRef
# "Signaler" for custom property changes
var custom_prop_signaler: FuncRef
# The FuncRef pointing to the function that will request the server to actually
# broadcast the specified custom property
var custom_prop_broadcast_requester: FuncRef


func _init(input_info: NetInputInfo, is_local: bool = false) -> void:
	_is_local = is_local
	_input_info = input_info
	_input_cache = InputCache.new()
	_edec_input = EncDecBuffer.new()
	_ping = null
	_custom_data = {}
	
	if (ProjectSettings.has_setting("keh_addons/network/broadcast_measured_ping")):
		_broadcast_ping = ProjectSettings.get_setting("keh_addons/network/broadcast_measured_ping")


func _ready() -> void:
	set_process_input(_is_local)



func _input(evt: InputEvent) -> void:
	if (evt is InputEventMouseMotion):
		#_mposition = evt.position        # Should mouse position be used?
		# Accumulate mouse relative so behavior is more consistent when VSync is toggled
		_mrelative += evt.relative
		_mspeed = evt.speed


func _poll_input() -> InputData:
	assert(_is_local)
	
	_input_cache.last_sig += 1
	var retval: InputData = InputData.new(_input_cache.last_sig)
	
	if (_input_info.use_mouse_relative() && _local_input_enabled):
		retval.set_mouse_relative(_mrelative)
		# Must reset the cache otherwise motion will still be sent even if there is none
		_mrelative = Vector2()
	
	if (_input_info.use_mouse_speed() && _local_input_enabled):
		retval.set_mouse_speed(_mspeed)
		_mspeed = Vector2()
	
	# Gather the analog data
	for a in _input_info._analog_list:
		if (!_input_info._analog_list[a].custom && (_local_input_enabled && _input_info._analog_list[a].enabled)):
			retval.set_analog(a, Input.get_action_strength(a))
		else:
			# Assume this analog data is "neutral". Doing this to ensure the data
			# is present on the returned object
			retval.set_analog(a, 0.0)
		
	for b in _input_info._bool_list:
		if (!_input_info._bool_list[b].custom && (_local_input_enabled && _input_info._bool_list[b].enabled)):
			retval.set_pressed(b, Input.is_action_pressed(b))
		else:
			# Assume this custom boolean is not pressed. Doing this to ensure the
			# data is present on the returned object.
			retval.set_pressed(b, false)
	
	return retval


func reset_data() -> void:
	_input_cache.sbuffer = {}
	_input_cache.cbuffer = []
	_input_cache.last_sig = 0
	_input_cache.snapinpu = {}
	_input_cache.no_input_count = 0
	_input_cache.last_ack_snap = 0



# The server uses this to know if the client is ready to receive snapshot data.
func is_ready() -> bool:
	return _is_ready


# This must be called only on client machines belonging to the local player. All of the cached
# input data will be encoded and sent to the server.
func _dispatch_input_data() -> void:
	# If this assert is failing then the function is being called on authority machine
	assert(get_tree().has_network_peer() && !get_tree().is_network_server())
	assert(_is_local)
	
	# NOTE: Should this check amount of input data and do nothing if it's 0?
	
	# Prepare the encdecbuffer to encode input data
	_edec_input.buffer = PoolByteArray()
	
	# Encode buffer size - two bytes should give plenty of packet loss time
	_edec_input.write_ushort(_input_cache.cbuffer.size())
	
	# Now encode each input object in the buffer
	for input in _input_cache.cbuffer:
		_input_info.encode_to(_edec_input, input)
	
	# Send the encoded data to the server - this should go directly to the
	# correct player node within the server
	rpc_unreliable_id(1, "server_receive_input", _edec_input.buffer)


# Obtain input data. If running on the local machine the state will be polled.
# If on a client (still local machine) then the data will be sent to the server.
# If on server (but not local) the data will be retrieved from the cache/buffer.
func get_input(snap_sig: int) -> InputData:
	# This will be used for a few tests within this function
	var is_authority: bool = !get_tree().has_network_peer() || get_tree().is_network_server()
	
	# This function should be called only by the authority or local machine
	assert(_is_local || is_authority)

	var retval: InputData
	if (_is_local):
		retval = _poll_input()
		
		if (!is_authority):
			# Local machine but on a client. This means, input data must be sent to the server
			# First, cache the new input object
			_input_cache.cbuffer.push_back(retval)
			
			# Input will be sent to the server when the snapshot is finished just so it give a
			# chance for custom input to be correctly set before dispatching
	
	else:
		# In theory if here it's authority machine as the assert above should
		# break if not local machine and not on authority. Asserts are removed
		# from release builds and that assert in this function is mostly to *try*
		# to catch errors early. Anyway, checking here again just to make sure
		if (!is_authority):
			return null
		
		# Running on the server but for a client. Must retrieve the data from
		# the input cache
		if (_input_cache.sbuffer.size() > 0):
			retval = _input_cache.sbuffer.get(_input_cache.last_sig + 1)
			if (retval):
				# There is a valid input object in the cache, so update the last
				# used signature
				_input_cache.last_sig += 1
				# The object that will be used is not needed within the cache anymore
				# so remove it
				# warning-ignore:return_value_discarded
				_input_cache.sbuffer.erase(_input_cache.last_sig)
		
		if (!retval):
			retval = _input_info.make_empty()
		
		# Later, given the snapshot obtain the input signature from the snapinpu dictionary
		_input_cache.associate(snap_sig, retval.signature)
	
	return retval



# This should already be the correct player within the hierarchy node.
remote func server_receive_input(encoded: PoolByteArray) -> void:
	assert(get_tree().is_network_server())
	
	_edec_input.buffer = encoded
	# Decode the amount of input objects
	var count: int = _edec_input.read_ushort()
	
	# Decode each one of the objects
	for _i in count:
		var input: InputData = _input_info.decode_from(_edec_input)
		
		# Cache this if it's newer than the last input signature
		if (input.signature > _input_cache.last_sig):
			_input_cache.sbuffer[input.signature] = input


# Retrieve the signature of the last input data used on this machine
func get_last_input_signature() -> int:
	return _input_cache.last_sig

# Given the snapshot signature, return the input signature that was used. This will
# be "valid" only on servers on a node corresponding to a client
func get_used_input_in_snap(sig: int) -> int:
	assert(get_tree().has_network_peer() && get_tree().is_network_server())
	
	var ret: int = _input_cache.snapinpu.get(sig, 0)
	
	return ret


# Returns the signature of the last acknowledged snapshot
func get_last_acked_snap_sig() -> int:
	return _input_cache.last_ack_snap


# Returns the amount of non acknowledged snapshots, which will be used by the
# server to determine if full snapshot data must be sent or not
func get_non_acked_snap_count() -> int:
	return _input_cache.snapinpu.size()

# Tells if there is any non acknowledged snapshot that didn't use any input from the
# client corresponding to this node. This is another condition that will be used to
# determine which data will be sent to this client
func has_snap_with_no_input() -> bool:
	return _input_cache.no_input_count > 0

# This function is meant to be run on clients but not called remotely.
# It removes from the cache all the input objects older and equal to the specified signature
func client_acknowledge_input(sig: int) -> void:
	assert(get_tree().has_network_peer() && !get_tree().is_network_server())
	
	while (_input_cache.cbuffer.size() > 0 && _input_cache.cbuffer.front().signature <= sig):
		_input_cache.cbuffer.pop_front()

# Retrieve the list of cached input objects, which corresponds to non acknowledged input data.
func get_cached_input_list() -> Array:
	return _input_cache.cbuffer


# This function is meant to be run on servers but not called remotely.
# Basically, when a client receives snapshot data, an answer must be given specifying
# the signature of the newest received. With this, internal cleanup can be performed
# and then later only the relevant data can be sent to the client
func server_acknowledge_snapshot(sig: int) -> void:
	assert(get_tree().has_network_peer() && get_tree().is_network_server())
	
	_input_cache.acknowledge(sig)


### Ping/Pong system
func start_ping() -> void:
	_ping = NetPingInfo.new(net_id, self)

# When the interval timer expires, a function will be called and that function will
# remote call this, which is meant to be run only on client machines
remote func _client_ping(sig: int, last_ping: float) -> void:
	# Answer back to the server
	rpc_unreliable_id(1, "_server_pong", sig)
	if (sig > 1):
		ping_signaler.call_func(net_id, last_ping)

remote func _server_pong(sig: int) -> void:
	# Bail if not the server - this should be an error though
	if (!get_tree().is_network_server()):
		return
	
	# The RPC call "arrives" at the node corresponding to the player that "called" it.
	# This means that "net_id" holds the correct network ID of the client.
	
	var measured: float = _ping.calculate_and_restart(sig)
	if (measured >= 0.0):
		if (_broadcast_ping):
			for pid in get_tree().get_network_connected_peers():
				if (pid != net_id):
					rpc_unreliable_id(pid, "_client_ping_broadcast", measured)
		
		# The server must get a signal with the measured value
		ping_signaler.call_func(net_id, measured)

# If the broadcast ping option is enabled then the server will call this function on
# each client in order to give the measured ping value and allow other clients to
# display somewhere the player's latency values
remote func _client_ping_broadcast(value: float) -> void:
	# When this is called it will run on the player node corresponding to the correct
	# player, meaning that the "net_id" property holds the correct player's network ID
	ping_signaler.call_func(net_id, value)


### Custom property system - This relies on the variant feature, specially when dealing
### with the property values. So, no static typing for those
func _add_custom_property(pname: String, prop: NetCustomProperty) -> void:
	_custom_data[pname] = NetCustomProperty.new(prop.value, prop.replicate)

func has_dirty_custom_prop() -> bool:
	return _custom_prop_dirty_count > 0

# Encode the "dirty" supported custom properties into the given EncDecBuffer. If a non supported property is
# found then it will be directly sent through the "_check_replication()" function.
# the prop_ref argument here is the the dicitonary that holds the list of properties with their initial values,
# which are then used to determine the expected value type.
# Retruns true if at least one of the "dirty properties" is supported by the EncDecBuffer.
func _encode_custom_props(edec: EncDecBuffer, prop_ref: Dictionary) -> bool:
	if (!has_dirty_custom_prop()):
		return false
	
	var is_authority: bool = (!get_tree().has_network_peer() || get_tree().is_network_server())
	
	edec.buffer = PoolByteArray()
	edec.write_uint(net_id)
	
	# Yes, this limits to 255 custom properties that can be encoded into a single packet.
	# This should be way more than enough! Regardless, the writing loop will end at 255 encoded properties.
	# On the next loop iteration the remaining dirty properties will be encoded.
	edec.write_byte(0)
	var encoded_props: int = 0
	
	for pname in _custom_data:
		var prop: NetCustomProperty = _custom_data[pname]
		if (prop.replicate == NetCustomProperty.ReplicationMode.ServerOnly && is_authority):
			# This property is meant to be "server only" and code is running on the server. Ensure the prop is
			# not dirty and don't encode it.
			prop.dirty = false
			continue
		
		# In here it doesn't matter if the code is running on srever or client. The property has to be checked
		# and if dirty it must be sent through network regardless.
		if (prop.encode_to(edec, pname, typeof(prop_ref[pname].value))):
			# The property was encoded - that means, it is of supported type AND is dirty. Update the encoded
			# counter.
			encoded_props += 1
		elif (prop.dirty):
			# This property is dirty but it couldn't be encoded. Most likely because it's is not supported by the
			# EncDecBuffer. Because of that, individually send this property
			_check_replication(pname, prop)
		
		if (encoded_props == 255):
			# Do not allow encoding go past 255 properties. Yet, with this system any property that still need
			# to be synchronized will be dispatched at a later moment
			break
	
	if (encoded_props > 0):
		# Rewrite the custom property header which is basically the number of encoded properties.
		edec.rewrite_byte(encoded_props, 4)
	
	return encoded_props > 0


func _decode_custom_props(from: EncDecBuffer, prop_ref: Dictionary, isauthority: bool) -> void:
	var ecount: int = from.read_byte()
	
	for _i in ecount:
		var pname: String = from.read_string()
		var pref: NetCustomProperty = prop_ref.get(pname, null)
		if (!pref):
			return
		
		var prop: NetCustomProperty = _custom_data[pname]
		if (!prop.decode_from(from, typeof(pref.value), isauthority)):
			return
		else:
			# Allow the "core" of the networking system to emit a signal indicating that a custom property has
			# been changed through synchronization
			custom_prop_signaler.call_func(net_id, pname, prop.value)
		
		if (prop.dirty):
			_custom_prop_dirty_count += 1



func _check_replication(pname: String, prop: NetCustomProperty) -> void:
	var is_authority: bool = (!get_tree().has_network_peer() || get_tree().is_network_server())
	match prop.replicate:
		NetCustomProperty.ReplicationMode.ServerOnly:
			# This property is meant to be given only to the server so if already there nothing
			# to be done. Otherwise, directly send the property to the server, which will be
			# automaticaly given to the correct node
			if (!is_authority):
				rpc_id(1, "_rem_set_custom_property", pname, prop.value)
		
		NetCustomProperty.ReplicationMode.ServerBroadcast:
			# This property must be broadcast through the server. So if running there directly
			# use the rpc() function, othewise use the FuncRef to request the server to do the
			# broadcasting
			if (is_authority):
				rpc("_rem_set_custom_property", pname, prop.value)
			
			else:
				custom_prop_broadcast_requester.call_func(pname, prop.value)
	
	prop.dirty = false



func set_custom_property(pname: String, value) -> void:
	assert(_custom_data.has(pname))
	
	var prop: NetCustomProperty = _custom_data[pname]
	# This line automatically marks the property as "dirty" if necessary. Dirty properties will be synchronized
	# at a later moment.
	prop.value = value
	if (prop.dirty):
		_custom_prop_dirty_count += 1



# This is used to retrieve the value of a custom property
func get_custom_property(pname: String, defval = null):
	var prop: NetCustomProperty = _custom_data.get(pname, null)
	return prop.value if prop else defval



# This function is meant to be called by (and in) the server in order to send all properties
# set to "ServerBroadcast" to the specified player
func sync_custom_with(pid: int) -> void:
	if (!get_tree().is_network_server()):
		return
	
	for pname in _custom_data:
		var prop: NetCustomProperty = _custom_data[pname]
		
		if (prop.replicate == NetCustomProperty.ReplicationMode.ServerBroadcast):
			rpc_id(pid, "_rem_set_custom_property", pname, prop.value)


# This is meant to set the custom property but by using remote calls. This should be
# automatically called based on the replication setting. One thing to note is that
# this will be called using the reliable channel
remote func _rem_set_custom_property(pname: String, val) -> void:
	assert(_custom_data.has(pname))
	_custom_data[pname].value = val
	
	# This allows the "core" of the networking system to emit a signal indicating that
	# a custom property has been changed through remote call
	custom_prop_signaler.call_func(net_id, pname, val)


### Setters/Getters
func set_network_id(id: int) -> void:
	net_id = id
	set_name("player_%d" % net_id)

func set_ready(r: bool) -> void:
	_is_ready = r

