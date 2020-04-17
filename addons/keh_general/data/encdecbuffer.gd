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

extends Reference
class_name EncDecBuffer

# This class is meant to simplify the task of encoding/decoding data into low
# level bytes (PoolByteArray). The thing is, the idea is to remove the variant
# header bytes from properties (which incorporate 4 bytes for each one).
# This class deals with a sub-set of the types given by Godot and was
# primarily meant to be used with the networking addon, but this can be useful
# in other scenarios (like a saving system for example).
#
# Now, why this trouble? Variables in GDScript take more bytes than we normally
# expect. Each one contains an additional set of 4 bytes representing the "header",
# which is basically indicating which type is actually held in memory. Some
# types may even bring further overhead and directly using them through the
# network may not necessarily be the best option.
#
# Now there is one very special case there. Unfortunately we don't have unsigned
# integers within GDScript. This brings a somewhat not so fun "limitation" to
# how numbers are represented.
#
# The maximum positive number that can be represented with an unsigned 32 bit
# integer is 4294967295. However, because GDScript only deals with signed
# numbers, the limit here would be 2147483647. But we can have bigger positive
# numbers in GDScript, only that behind the scenes Godot uses 64 bit integers.
# In other words, if we directly send a hash number (32 bit), the result will
# be that 12 bytes will be used instead of just 8 (or the desired 4 bytes).
#
# This class allows "unsigned integers" to be stored in the PoolByteArray
# using the desired 4 bytes, provided the value stays within the boundary.
#
# There is another improvement that could have been done IF GDScript supported
# static variables (that is, shared between instances of the object - which
# would create a "proper caching" of the internal data).

const CTYPE_UINT: int = 65538
const MAX_UINT: int = 0xFFFFFFFF

# The "uint" is probably internally using 64 bit integers. As a variant it uses a different
# type header but the byte ordering must be known. This property holds where the relevant
# bytes are in the variable data.
var uint_start: int setget noset

# Certain encodings will remove some extra bytes from the internal variant data. In order to
# rebuild those variables the bytes (sequences of 0's) must be added back. The next properties
# are meant to hold those "fills" as ByteArrays in order to make things easier
var fill_4bytes: PoolByteArray setget noset
var fill_3bytes: PoolByteArray setget noset
var fill_2bytes: PoolByteArray setget noset

# Cache the "property headers" so those can be rebuilt
# Key = type code
# Value = Another dictionary containing two fields:
#    header = PoolByteArray corresponding to the variant header
#    size = number of bytes necessary used by a property of this type
var property_header: Dictionary = {} setget noset

# A flag indicating if the system is running on big endian or little endian. I'm honestly
# not sure if this is needed but....
var is_big: bool setget noset

# The buffer to store the bytes.
var buffer: PoolByteArray setget set_buffer


# Buffer reading index, so "read_*()" can be used to retrieve data and avoid external code
# to deal with the correct indexing within the buffer.
var rindex: int

func _init() -> void:
	# Set some internal values that will help code/decode data when byte order is important
	var etest: int = 0x01020304
	var ebytes: PoolByteArray = var2bytes(etest)
	is_big = ebytes[0] == 1
	
	uint_start = 8 if is_big else 4
	
	fill_4bytes.append(0)
	fill_4bytes.append(0)
	fill_4bytes.append(0)
	fill_4bytes.append(0)
	
	fill_3bytes.append(0)
	fill_3bytes.append(0)
	fill_3bytes.append(0)
	
	fill_2bytes.append(0)
	fill_2bytes.append(0)
	
	
	property_header[TYPE_BOOL] = {
		header = PoolByteArray(var2bytes(bool(false)).subarray(0, 3)),
		size = 1
	}
	property_header[TYPE_INT] = {
		header = PoolByteArray(var2bytes(int(0)).subarray(0, 3)),
		size = 4
	}
	property_header[TYPE_REAL] = {
		header = PoolByteArray(var2bytes(float(0.0)).subarray(0, 3)),
		size = 4
	}
	property_header[TYPE_VECTOR2] = {
		header = PoolByteArray(var2bytes(Vector2()).subarray(0, 3)),
		size = 8
	}
	property_header[TYPE_RECT2] = {
		header = PoolByteArray(var2bytes(Rect2()).subarray(0, 3)),
		size = 16
	}
	property_header[TYPE_VECTOR3] = {
		header = PoolByteArray(var2bytes(Vector3()).subarray(0, 3)),
		size = 12
	}
	property_header[TYPE_QUAT] = {
		header = PoolByteArray(var2bytes(Quat()).subarray(0, 3)),
		size = 16
	}
	property_header[TYPE_COLOR] = {
		header = PoolByteArray(var2bytes(Color()).subarray(0, 3)),
		size = 16
	}
	property_header[CTYPE_UINT] = {
		header = PoolByteArray(var2bytes(int(MAX_UINT)).subarray(0, 3)),
		size = 4
	}


# Obtain number of bytes used by a property of the specified type
func get_field_size(ftype: int) -> int:
	var p: Dictionary = property_header.get(ftype)
	if (p):
		return p.size
	else:
		return 0

# If true is returned then the reading index is a at a position not past
# the last byte of the internal PoolByteArray
func has_read_data() -> bool:
	return rindex < buffer.size()

# Return current amount of bytes stored within the internal buffer
func get_current_size() -> int:
	return buffer.size()


# A generic function to encode the specified property into the internal
# byte array.
func encode_bytes(val, count: int, start: int = 4) -> PoolByteArray:
	return var2bytes(val).subarray(start, start + count - 1)

func _rewrite_bytes(val, at: int, count: int, start: int = 4) -> void:
	var bts: PoolByteArray = encode_bytes(val, count, start)
	var idx: int = at
	for bt in bts:
		buffer.set(idx, bt)
		idx += 1


func write_bool(val: bool) -> void:
	buffer.append(val)

func rewrite_bool(val: bool, at: int) -> void:
	buffer.set(at, val)

func write_int(val: int) -> void:
	buffer.append_array(encode_bytes(val, 4))

func rewrite_int(val: int, at: int) -> void:
	_rewrite_bytes(val, at, 4)


func write_float(val: float) -> void:
	# Floats in Godot are somewhat finicky! When stored in individual variables they use
	# 8 bytes rather than 4! When stored in vectors they use 4 bytes. So, creating a dummy
	# vector just to get the correct data size and store into the buffer. Retrieving it
	# later into a "loose variable" will work as desired.
	var dummyvec: Vector2 = Vector2(val, 0)
	buffer.append_array(encode_bytes(dummyvec.x, 4))

func rewrite_float(val: float, at: int) -> void:
	var dummyvec: Vector2 = Vector2(val, 0)
	_rewrite_bytes(dummyvec.x, at, 4)

func write_vector2(val: Vector2) -> void:
	buffer.append_array(encode_bytes(val, 8))

func rewrite_vector2(val: Vector2, at: int) -> void:
	_rewrite_bytes(val, at, 8)

func write_rect2(val: Rect2) -> void:
	buffer.append_array(encode_bytes(val, 16))

func rewrite_rect2(val: Rect2, at: int) -> void:
	_rewrite_bytes(val, at, 16)

func write_vector3(val: Vector3) -> void:
	buffer.append_array(encode_bytes(val, 12))

func rewrite_vector3(val: Vector3, at: int) -> void:
	_rewrite_bytes(val, at, 12)

func write_quat(val: Quat) -> void:
	buffer.append_array(encode_bytes(val, 16))

func rewrite_quat(val: Quat, at: int) -> void:
	_rewrite_bytes(val, at, 16)

func write_color(val: Color) -> void:
	buffer.append_array(encode_bytes(val, 16))

func rewrite_color(val: Color, at: int) -> void:
	_rewrite_bytes(val, at, 16)

func write_uint(val: int) -> void:
	assert(val <= MAX_UINT)
	var bytes: PoolByteArray = var2bytes(val)
	if (bytes.size() == 8):
		buffer.append_array(bytes.subarray(4, 7))
	else:
		buffer.append_array(bytes.subarray(uint_start, uint_start + 3))

func rewrite_uint(val: int, at: int) -> void:
	assert(val <= MAX_UINT)
	var bytes: PoolByteArray = var2bytes(val)
	var sidx: int = uint_start      # Source index
	if (bytes.size() == 8):
		sidx = 4
	
	for i in 4:
		buffer.set(at + i, bytes[sidx + i])

func write_byte(val: int) -> void:
	assert(val <= 255 && val >= 0)
	buffer.append(val)

func rewrite_byte(val: int, at: int) -> void:
	assert(val <= 255 && val >= 0)
	buffer.set(at, val)

func write_ushort(val: int) -> void:
	assert(val <= 0xFFFF && val >= 0)
	buffer.append_array(encode_bytes(val, 2, 6 if is_big else 4))

func rewrite_ushort(val: int, at: int) -> void:
	assert(val <= 0xFFFF && val >= 0)
	_rewrite_bytes(val, at, 2, 6 if is_big else 4)


# This relies on the variant so no static typing here. This is a generic
# function meant to extract a property from the internal PoolByteArray
func read_by_type(tp: int):
	var sz: int = property_header[tp].size
	return bytes2var(property_header[tp].header + buffer.subarray(rindex, rindex + sz - 1))



func read_bool() -> bool:
	var r: int = rindex
	rindex += 1
	
	if (is_big):
		return bytes2var(property_header[TYPE_BOOL].header + fill_3bytes + buffer.subarray(r, r))
	else:
		return bytes2var(property_header[TYPE_BOOL].header + buffer.subarray(r, r) + fill_3bytes)

func read_int() -> int:
	var ret: int = read_by_type(TYPE_INT)
	rindex += 4
	return ret

func read_float() -> float:
	var ret: float = read_by_type(TYPE_REAL)
	rindex += 4
	return ret

func read_vector2() -> Vector2:
	var ret: Vector2 = read_by_type(TYPE_VECTOR2)
	rindex += 8
	return ret

func read_rect2() -> Rect2:
	var ret: Rect2 = read_by_type(TYPE_RECT2)
	rindex += 16
	return ret

func read_vector3() -> Vector3:
	var ret: Vector3 = read_by_type(TYPE_VECTOR3)
	rindex += 12
	return ret

func read_quat() -> Quat:
	var ret: Quat = read_by_type(TYPE_QUAT)
	rindex += 16
	return ret

func read_color() -> Color:
	var ret: Color = read_by_type(TYPE_COLOR)
	rindex += 16
	return ret

func read_uint() -> int:
	var r: int = rindex
	rindex += 4
	
	if (uint_start == 4):
		return bytes2var(property_header[CTYPE_UINT].header + buffer.subarray(r, r + 3) + fill_4bytes)
	else:
		return bytes2var(property_header[CTYPE_UINT].header + fill_4bytes + buffer.subarray(r, r + 3))

func read_byte() -> int:
	var r: int = rindex
	rindex += 1
	
	if (is_big):
		return bytes2var(property_header[TYPE_INT].header + fill_3bytes + buffer.subarray(r, r))
	else:
		return bytes2var(property_header[TYPE_INT].header + buffer.subarray(r, r) + fill_3bytes)

func read_ushort() -> int:
	var r: int = rindex
	rindex += 2
	
	if (is_big):
		return bytes2var(property_header[TYPE_INT].header + fill_2bytes + buffer.subarray(r, r + 1))
	else:
		return bytes2var(property_header[TYPE_INT].header + buffer.subarray(r, r + 1) + fill_2bytes)


### Setters/getters
func set_buffer(b: PoolByteArray) -> void:
	buffer = b
	rindex = 0


func noset(_v) -> void:
	pass

