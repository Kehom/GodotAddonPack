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

# This class is meant to hold information about an event type that can be
# replicated through the network. It also performs the task of encoding and
# decoding the events of the described type.

extends Reference
class_name NetEventInfo

# Those are just shortcuts
const CTYPE_UINT: int = SnapEntityBase.CTYPE_UINT
const CTYPE_USHORT: int = SnapEntityBase.CTYPE_USHORT
const CTYPE_BYTE: int = SnapEntityBase.CTYPE_BYTE

# Type ID of events described by this
var _type_id: int

# This array holds the types of the parameters expected by events this type
var _param_types: Array

# Functions held here will be called as soon as events are decoded. Each entry is
# a dictionary with the following fields:
# - obj: Object instance holding the function to be called
# - funcname: Function name to be called
var _evt_handlers: Array


func _init(id: int, pt: Array) -> void:
	# Event type ID must fit in 16 bits
	assert(id >= 0 && id < 0xFFFF)
	# If the next assert fails, then an unsupported parameter type is in the array
	assert(check_types(pt))
	
	_type_id = id
	_param_types = pt


func attach_handler(obj: Object, fname: String) -> void:
	_evt_handlers.push_back({"obj": obj, "funcname": fname})


func clear_handlers() -> void:
	_evt_handlers.clear()


func encode(into: EncDecBuffer, params: Array) -> void:
	# Parameters must match the expected parameter list
	assert(params.size() == _param_types.size())
	
	# Write the parameters
	var idx: int = 0
	for pt in _param_types:
		match pt:
			TYPE_BOOL:
				into.write_bool(params[idx])
			TYPE_INT:
				into.write_int(params[idx])
			TYPE_REAL:
				into.write_float(params[idx])
			TYPE_VECTOR2:
				into.write_vector2(params[idx])
			TYPE_RECT2:
				into.write_rect2(params[idx])
			TYPE_QUAT:
				into.write_quat(params[idx])
			TYPE_COLOR:
				into.write_color(params[idx])
			TYPE_VECTOR3:
				into.write_vector3(params[idx])
			CTYPE_UINT:
				into.write_uint(params[idx])
			CTYPE_BYTE:
				into.write_byte(params[idx])
			CTYPE_USHORT:
				into.write_ushort(params[idx])
		
		idx += 1


func decode(from: EncDecBuffer) -> void:
	# At this point, "from" should already have gone past the type ID of this event
	var params: Array = []
	
	for pt in _param_types:
		match pt:
			TYPE_BOOL:
				params.push_back(from.read_bool())
			TYPE_INT:
				params.push_back(from.read_int())
			TYPE_REAL:
				params.push_back(from.read_float())
			TYPE_VECTOR2:
				params.push_back(from.read_vector2())
			TYPE_RECT2:
				params.push_back(from.read_rect2())
			TYPE_QUAT:
				params.push_back(from.read_quat())
			TYPE_COLOR:
				params.push_back(from.read_color())
			TYPE_VECTOR3:
				params.push_back(from.read_vector3())
			CTYPE_UINT:
				params.push_back(from.read_uint())
			CTYPE_BYTE:
				params.push_back(from.read_byte())
			CTYPE_USHORT:
				params.push_back(from.read_ushort())
	
	call_handlers(params)


func call_handlers(params: Array) -> void:
	var toerase: Array = []
	for eh in _evt_handlers:
		if (eh.obj):
			eh.obj.callv(eh.funcname, params)
		
		else:
			toerase.push_back(eh)
	
	for te in toerase:
		_evt_handlers.erase(te)



# This is meant to be called within the assert, in other words only on non release builds
func check_types(ptypes: Array) -> bool:
	for pt in ptypes:
		match pt:
			TYPE_BOOL, TYPE_INT, TYPE_REAL, TYPE_VECTOR2, TYPE_RECT2, TYPE_QUAT, TYPE_COLOR, TYPE_VECTOR3,\
			CTYPE_UINT, CTYPE_BYTE, CTYPE_USHORT:
				pass
			_:
				return false
	return true
