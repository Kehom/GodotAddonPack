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
var value

# The replication method for this custom property
var replicate: int = ReplicationMode.ServerOnly

func _init(initial_val, repl_mode: int = ReplicationMode.ServerOnly) -> void:
	value = initial_val
	replicate = repl_mode

