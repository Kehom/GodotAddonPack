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

# Initializing the ping system requires quite a bit of code. So adding that
# into a class.
# This is meant for internal addon usage so normally there is no need to
# directly access objects of this class.

extends Reference
class_name NetPingInfo

const PING_INTERVAL: float = 1.0        # Wait one second between ping requests
const PING_TIMEOUT: float = 5.0         # Wait five seconds before considering a ping request as lost

var interval: Timer          # Timer to control interval between ping requests
var timeout: Timer           # Timer to control ping timeouts
var signature: int           # Signature of the ping request
var lost_packets: int        # Number of packets considered lost
var last_ping: float         # Last measured ping, in milliseconds
var parent: Node             # Node to hold the timers and remote functions. It should be a NetPlayerNode

func _init(pid: int, node: Node) -> void:
	signature = 0
	lost_packets = 0
	last_ping = 0.0
	parent = node
	
	# Initialize the timers
	interval = Timer.new()
	interval.wait_time = PING_INTERVAL
	interval.process_mode = Timer.TIMER_PROCESS_IDLE
	interval.set_name("net_ping_interval")
	# warning-ignore:return_value_discarded
	interval.connect("timeout", self, "_request_ping", [pid])
	
	timeout = Timer.new()
	timeout.wait_time = PING_TIMEOUT
	timeout.process_mode = Timer.TIMER_PROCESS_IDLE
	timeout.set_name("net_ping_timeout")
	# warning-ignore:return_value_discarded
	timeout.connect("timeout", self, "_on_ping_timeout", [pid])
	
	# Timers must be added into the tree otherwise they aren't updated
	parent.add_child(interval)
	parent.add_child(timeout)
	
	# Make sure the timeout is stopped while the interval is running
	timeout.stop()
	interval.start()


func _request_ping(pid: int) -> void:
	signature += 1
	interval.stop()
	timeout.start()
	parent.rpc_unreliable_id(pid, "_client_ping", signature, last_ping)

func _on_ping_timeout(pid: int) -> void:
	# The last ping request has timed out. No answer received, so assume the packet has been lost
	lost_packets += 1
	# Request a new ping - no need to wait through interval since there was already 5 seconds
	# from the previous request
	_request_ping(pid)

func calculate_and_restart(sig: int) -> float:
	var ret: float = -1.0
	if (signature == sig):
		# Obtain the amount of time and convert to milliseconds
		last_ping = (PING_TIMEOUT - timeout.time_left) * 1000
		ret = last_ping
		timeout.stop()
		interval.start()
	
	return ret
