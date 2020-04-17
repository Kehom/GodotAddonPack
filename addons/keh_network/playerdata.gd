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

# Meant to make things easier to manage player data by holding containers
# and providing access function to manipulate those.
# This is not meant to be manually instanced but direct access to an object
# of this class is very helpful specially when player list is required. To
# that end, it should be pretty simple to do so using the instance that is
# automatically created within the network singleton (network.player_data).

extends Reference
class_name NetPlayerData

# This input info will be given to each instance of NetPlayerNode so proper input processing
# can be done, specially encoding/decoding
var input_info: NetInputInfo

var local_player: NetPlayerNode

# Map from network ID to node
var remote_player: Dictionary

# Holds the list of registered custom properties. When a player node is created, a copy of
# this dictionary must be attached into that node. Note that it must be a copy and not a
# reference since the custom properties are potentially different on each player.
var custom_property: Dictionary

# The FuncRefs that are used within each NetPlayerNode
var ping_signaler: FuncRef setget set_ping_signaler
var cprop_signaler: FuncRef setget set_cprop_signaler
var cprop_broadcaster: FuncRef setget set_cprop_broadcaster

func _init() -> void:
	input_info = NetInputInfo.new()
	local_player = NetPlayerNode.new(input_info, true)
	remote_player = {}
	custom_property = {}

# Create an instance of a NetPlayerNode while also adding the necessary
# internal data to the created object.
func create_player(id: int) -> NetPlayerNode:
	var np: NetPlayerNode = NetPlayerNode.new(input_info)
	np.set_network_id(id)
	np.ping_signaler = ping_signaler
	np.custom_prop_signaler = cprop_signaler
	np.custom_prop_broadcast_requester = cprop_broadcaster
	
	# Add the registered custom properties
	for pname in custom_property:
		np._add_custom_property(pname, custom_property[pname])
	
	return np

# Add a player node to the internal container. Effectively registers a player.
# This is automatically called by the internal system and there is no need
# to deal with this from game code.
func add_remote(np: NetPlayerNode) -> void:
	remote_player[np.net_id] = np


# Cleanup the internal player node container
func clear_remote() -> void:
	for p in remote_player:
		remote_player[p].queue_free()
	
	remote_player.clear()


# Retrieve the NetPlayerNode corresponding to the specified player ID
func get_pnode(pid: int) -> NetPlayerNode:
	if (local_player.net_id == pid):
		return local_player
	return remote_player.get(pid)


# Retrieve the number of players, including the local one.
func get_player_count() -> int:
	# Local player plus remote peers
	return 1 + remote_player.size()


# Add (register) a custom player property
func add_custom_property(pname: String, default_value, replicate: int = NetCustomProperty.ReplicationMode.ServerOnly) -> void:
	var prop: NetCustomProperty = NetCustomProperty.new(default_value, replicate)
	custom_property[pname] = prop
	
	# The player node function will create a new custom property object so no need to worry about references
	# interfering with different player nodes. Nevertheless, ensure the local player gets this custom property
	local_player._add_custom_property(pname, prop)
	
	# And ensure the remote players also have this custom property
	for pid in remote_player:
		remote_player[pid]._add_custom_property(pname, prop)


### Setters/getters
func set_ping_signaler(ps: FuncRef) -> void:
	ping_signaler = ps
	local_player.ping_signaler = ps

func set_cprop_signaler(cps: FuncRef) -> void:
	cprop_signaler = cps
	local_player.custom_prop_signaler = cps

func set_cprop_broadcaster(cpb: FuncRef) -> void:
	cprop_broadcaster = cpb
	local_player.custom_prop_broadcast_requester = cpb
