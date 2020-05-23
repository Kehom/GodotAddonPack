###############################################################################
# Copyright (c) 2019-2020 Yuri Sarudiansky
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

# The floating point quantization code was adapted. The original code was taken from
# the Game Engine Architecture book by Jason Gregory

extends Reference
class_name Quantize

const ROTATION_BOUNDS: float = 0.707107

# Define some masks to help pack/unpack quantized rotation quaternions into integers
const MASK_A_9BIT: int = 511           # 511 = 111111111
const MASK_B_9BIT: int = 511 << 9
const MASK_C_9BIT: int = 511 << 18
const MASK_INDEX_9BIT: int = 3 << 27
const MASK_SIGNAL_9BIT: int = 1 << 30


const MASK_A_10BIT: int = 1023         # 1023 = 1111111111
const MASK_B_10BIT: int = 1023 << 10
const MASK_C_10BIT: int = 1023 << 20
const MASK_INDEX_10BIT: int = 3 << 30

const MASK_A_15BIT: int = 32767
const MASK_B_15BIT: int = 32767 << 15
# The C component is packed into a secondary integer but having dedicated
# constant may help reduce confusion when reading the code
const MASK_C_15BIT: int = 32767
const MASK_INDEX_15BIT: int = 3 << 30
# When packing compressed quaternion data using 15 bits per component, one
# bit becomes "wasted". While not entirely necessary, the system here uses
# that bit to restore the signals of the original quaternion in case those
# got flipped because the largest component was negative.
const MASK_SIGNAL_15BIT: int = 1 << 15


# Quantize a unit float (range [0..1]) into an integer of the specified number of bits)
static func quantize_unit_float(val: float, numbits: int) -> int:
	# Number of bits cannot exceed 32 bits
	assert(numbits <= 32 && numbits > 0)
	
	var intervals: int = 1 << numbits
	var scaled: float = val * (intervals - 1)
	var rounded: int = int(floor(scaled + 0.5))
	
	if (rounded > intervals - 1):
		rounded = intervals - 1
	
	return rounded

static func restore_unit_float(quantized: int, numbits: int) -> float:
	assert(numbits <= 32 && numbits > 0)
	
	var intervals: int = 1 << numbits
	var intervalsize: float = 1.0 / (intervals - 1)
	var approxfloat: float = float(quantized) * intervalsize
	
	
	return approxfloat

# Quantize a float in the range [minval..maxval]
static func quantize_float(val: float, minval: float, maxval: float, numbits: int) -> int:
	var unitfloat: float = (val - minval) / (maxval - minval)
	var quantized: int = quantize_unit_float(unitfloat, numbits)
	
	return quantized

# Restore float in arbitrary range
static func restore_float(quantized: int, minval: float, maxval: float, numbits: int) -> float:
	var unitfloat: float = restore_unit_float(quantized, numbits)
	var val: float = minval + (unitfloat * (maxval - minval))
	
	return val


# Compress the given rotation quaternion using the specified number of bits per component
# using the smallest three method. The returned dictionary contains 5 fields:
# a, b, c -> the smallest three quantized components
# index -> the index [0..3] of the dropped (largest) component
# sig -> The "signal" of the dropped component (1.0 if >= 0, -1.0 if negative) 
# Note: Signal is not exactly necessary, but is provided just so if there is any desire to encode it
static func compress_rotation_quat(q: Quat, numbits: int) -> Dictionary:
	# Unfortunately it's not possible to directly iterate through the quaternion's components
	# using a loop, so create a temporary array to store them
	var aq: Array = [q.x, q.y, q.z, q.w]
	var mindex: int = 0        # Index of largest component
	var mval: float = -1.0       # Largest component value
	var sig: float = 1.0        # "Signal" of the dropped component
	
	# Locate the largest component, storing its absolute value as well as the index
	# (0 = x, 1 = y, 2 = z and 3 = w)
	for i in 4:
		var abval: float = abs(aq[i])
		
		if (abval > mval):
			mval = abval
			mindex = i
	
	if (aq[mindex] < 0.0):
		sig = -1.0
	
	# Drop the largest component
	aq.erase(aq[mindex])
	
	# Now loop again through the components, quantizing them
	for i in 3:
		var fl: float = aq[i] * sig
		aq[i] = quantize_float(fl, -ROTATION_BOUNDS, ROTATION_BOUNDS, numbits)
	
	
	return {
		"a": aq[0],
		"b": aq[1],
		"c": aq[2],
		"index": mindex,
		"sig": 1 if (sig == 1.0) else 0,
	}


# Restore the rotation quaternion. The quantized values must be given in a dictionary with
# the same format of the one returned by the compress_rotation_quat() function.
static func restore_rotation_quat(quant: Dictionary, numbits: int) -> Quat:
	# Take the signal (just a multiplier)
	var sig: float = 1.0 if quant.sig == 1 else -1.0
	
	# Restore components a, b and c
	var ra: float = restore_float(quant.a, -ROTATION_BOUNDS, ROTATION_BOUNDS, numbits) * sig
	var rb: float = restore_float(quant.b, -ROTATION_BOUNDS, ROTATION_BOUNDS, numbits) * sig
	var rc: float = restore_float(quant.c, -ROTATION_BOUNDS, ROTATION_BOUNDS, numbits) * sig
	# Restore the dropped component
	var dropped: float = sqrt(1.0 - ra*ra - rb*rb - rc*rc) * sig
	
	var ret: Quat = Quat()
	
	match quant.index:
		0:
			# X was dropped
			ret = Quat(dropped, ra, rb, rc)
		
		1:
			# Y was dropped
			ret = Quat(ra, dropped, rb, rc)
		
		2:
			# Z was dropped
			ret = Quat(ra, rb, dropped, rc)
		
		3:
			# W was dropped
			ret = Quat(ra, rb, rc, dropped)
	
	return ret



# Compress the given rotation quaternion using 9 bits per  component. This is a "wrapper"
# function that packs the quantized value into a single integer. Because there is still
# some "room" (only 29 bits of the 32 are used), the original signal of the quaternion is
# also stored, meaning that it can be restored.
static func compress_rquat_9bits(q: Quat) -> int:
	# Compress the components using the generalized Quat compression
	var c: Dictionary = compress_rotation_quat(q, 9)
	return ( ((c.sig << 30) & MASK_SIGNAL_9BIT) |
				((c.index << 27) & MASK_INDEX_9BIT) |
				((c.c << 18) & MASK_C_9BIT) |
				((c.b << 9) & MASK_B_9BIT) |
				(c.a & MASK_A_9BIT) )

# Restores a quaternion that was previously quantized into a single integer using 9 bits
# per component. In this case the original signal of the quaternion will be restored.
static func restore_rquat_9bits(compressed: int) -> Quat:
	var unpacked: Dictionary = {
		"a": compressed & MASK_A_9BIT,
		"b": (compressed & MASK_B_9BIT) >> 9,
		"c": (compressed & MASK_C_9BIT) >> 18,
		"index": (compressed & MASK_INDEX_9BIT) >> 27,
		"sig": (compressed & MASK_SIGNAL_9BIT) >> 30,
	}
	
	return restore_rotation_quat(unpacked, 9)


# Compress the given rotation quaternion using 10 bits per component. This is a "wrapper"
# function that packs the quantized values into a single integer. Note that in this case
# the restored quaternion may be entirely "flipped" as the original signal cannot be
# stored within the packed integer.
static func compress_rquat_10bits(q: Quat) -> int:
	# Compress the components using the generalized function
	var c: Dictionary = compress_rotation_quat(q, 10)
	return ( ((c.index << 30) & MASK_INDEX_10BIT) |
				((c.c << 20) & MASK_C_10BIT) |
				((c.b << 10) & MASK_B_10BIT) |
				(c.a & MASK_A_10BIT) )

# Restores a quaternion that was previously quantized into a single integer using 10 bits
# per component. In this case the original signal may not be restored.
static func restore_rquat_10bits(c: int) -> Quat:
	# Unpack the components
	var unpacked: Dictionary = {
		"a": c & MASK_A_10BIT,
		"b": (c & MASK_B_10BIT) >> 10,
		"c": (c & MASK_C_10BIT) >> 20,
		"index": (c & MASK_INDEX_10BIT) >> 30,
		"sig": 1,     # Use 1.0 as multiplier because the signal cannot be restored in this case
	}
	
	return restore_rotation_quat(unpacked, 10)


# Compress the given rotation quaternion using 15 bits per component. This is a "wrapper"
# function that packs the quantized values into two intergers (using PoolIntArray). In
# memory this will still use the full range of the integer values, but the second entry in
# the returned array can safely discard 16 bits, which is basically the desired usage when
# sending data through network. Note that in this case, using a full 32 bit + 16 bit leaves
# room for a single bit, which is used to encode the original quaternion signal.
static func compress_rquat_15bits(q: Quat) -> PoolIntArray:
	# Obtain the compressed data
	var c: Dictionary = compress_rotation_quat(q, 15)
	
	# Pack the first element of the array - contains index, A and B elements
	var packed0: int = ( ((c.index << 30) & MASK_INDEX_15BIT) |
								((c.b << 15) & MASK_B_15BIT) |
								(c.a & MASK_A_15BIT) )
	
	# Pack the second element of the array - contains signal and C element
	var packed1: int = (((c.sig & MASK_SIGNAL_15BIT) << 15) | (c.c & MASK_C_15BIT))
	
	return PoolIntArray([packed0, packed1])

# Restores a quaternion compressed using 15 bits per component. The input must be integers
# within the PoolIntArray of the compression function, in the same order for the arguments.
static func restore_rquat_15bits(pack0: int, pack1: int) -> Quat:
	# Unpack the elements
	var unpacked: Dictionary = {
		"a": pack0 & MASK_A_15BIT,
		"b": (pack0 & MASK_B_15BIT) >> 15,
		"c": pack1 & MASK_C_15BIT,
		"index": (pack0 & MASK_INDEX_15BIT) >> 30,
		"sig": (pack1 & MASK_SIGNAL_15BIT) >> 15
	}
	
	return restore_rotation_quat(unpacked, 15)


