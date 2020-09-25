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

# This network addon provides means to create properties that are associated
# with players and be automatically replicated. By default the stored values
# will be sent only to the server, however it's possible to configure each
# property in a way that the server will broadcast the values to other clients.
# This class is meant for internal usage and normally there is no need to
# directly use it.
#
# Update: if the stored value is of a supported type by the EncDecBuffer then
# the custom property will potentially be sent with multiple others in order
# to reduce the number of remote calls. Basically, when a property is changed,
# if it is supported a flag will be set. Then, at the end of the update all
# properties with this flag will be encoded into a single byte array


extends Reference
class_name NetCustomProperty

# Properties through this system can be marked for automatic replication.
# This enumeration configures how that will work
enum ReplicationMode {
	None,               # No replication of this property
	ServerOnly,         # If a property is changed in a client machine, it will be sent only to the server
	ServerBroadcast,    # Property value will be broadcast to every player through the server
}

# Because custom properties can be of any type, this class' property meant to hold
# the actual custom value is not static typed
var value setget _setval

# The replication method (actually, mode) for this custom property
var replicate: int = ReplicationMode.ServerOnly

# This flag tells if the custom property must be synchronized or not. Normally this will be set after
# changing the "value" property.
var dirty: bool


func _init(initial_val, repl_mode: int = ReplicationMode.ServerOnly) -> void:
	value = initial_val
	replicate = repl_mode
	dirty = false



func encode_to(edec: EncDecBuffer, pname: String, expected_type: int) -> bool:
	if (!dirty):
		return false
	
	var cfunc: String = ""
	match expected_type:
		TYPE_BOOL:
			cfunc = "write_bool"
		TYPE_INT:
			cfunc = "write_int"
		TYPE_REAL:
			cfunc = "write_float"
		TYPE_VECTOR2:
			cfunc = "write_vector2"
		TYPE_RECT2:
			cfunc = "write_rect2"
		TYPE_VECTOR3:
			cfunc = "write_vector3"
		TYPE_QUAT:
			cfunc = "write_quat"
		TYPE_COLOR:
			cfunc = "write_color"
		TYPE_STRING:
			cfunc = "write_string"
	
	if (!cfunc.empty()):
		edec.write_string(pname)
		edec.call(cfunc, value)
		# It was encoded. Assume the data will be send to through the network, thus clean up this property.
		dirty = false
	
	return !cfunc.empty()


func decode_from(edec: EncDecBuffer, expected_type: int, make_dirty: bool) -> bool:
	var cfunc: String = ""
	match expected_type:
		TYPE_BOOL:
			cfunc = "read_bool"
		TYPE_INT:
			cfunc = "read_int"
		TYPE_REAL:
			cfunc = "read_float"
		TYPE_VECTOR2:
			cfunc = "read_vector2"
		TYPE_RECT2:
			cfunc = "read_rect2"
		TYPE_VECTOR3:
			cfunc = "read_vector3"
		TYPE_QUAT:
			cfunc = "read_quat"
		TYPE_COLOR:
			cfunc = "read_color"
		TYPE_STRING:
			cfunc = "read_string"
	
	if (!cfunc.empty()):
		value = edec.call(cfunc)
		dirty = make_dirty
	
	return !cfunc.empty()


func _setval(v) -> void:
	# By not doing anything if the incoming value is not different from the already stored value some bandwidth
	# will be saved. This happens because data is only sent if it is marked as "dirty">
	if (v != value):
		value = v
		dirty = replicate != ReplicationMode.None

