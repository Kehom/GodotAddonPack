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

# This class is meant to hold information regarding which input data
# (based on the project settings input mappings) should be encoded/decoded
# when dealing with the network.
# This is meant for internal usage and normally speaking should not be
# directly used by external code.

extends Reference
class_name NetInputInfo


### Those are options retrieved from the ProjectSettings
var _use_mouse_relative: bool = false
var _use_mouse_speed: bool = false
# If this is true then analog input data will be quantized with precision of 8 bits
# Error margin should be more than acceptable for this kind of data
var _quantize_analog: bool = false


# The following dictionaries are meant to hold the list of input data meant to be
# encoded/decoded, thus replicated through the network. Each dictionary corresponds to
# a supported data type (analog, boolean, vector2 and vector3). Analog and boolean are
# the only ones to be automatically retrieved by polling the input device state, based
# on the input map settings and the registered input names.
# Within those dictionaries each entry, keyed by the input name, will be another dictionary
# with the following fields:
# mask: a bit mask corresponding to the entry when building the "change mask"
# custom: true if the input entry corresponds to a custom data.

var _analog_list: Dictionary = {}
var _bool_list: Dictionary = {}
var _vec2_list: Dictionary = {}
var _vec3_list: Dictionary = {}

# As soon as a custom input data type is registered this flag will be set to true.
# This is mostly to help issue warnings when custom input are required but the function
# reference necessary to generate the data is not set
var _has_custom_data: bool = false


var _print_debug: bool = false


func _init() -> void:
	# Obtain the options from ProjectSettings
	if (ProjectSettings.has_setting("keh_addons/network/use_input_mouse_relative")):
		_use_mouse_relative = ProjectSettings.get_setting("keh_addons/network/use_input_mouse_relative")
	
	if (ProjectSettings.has_setting("keh_addons/network/use_input_mouse_speed")):
		_use_mouse_speed = ProjectSettings.get_setting("keh_addons/network/use_input_mouse_speed")
	
	if (ProjectSettings.has_setting("keh_addons/network/quantize_analog_input")):
		_quantize_analog = ProjectSettings.get_setting("keh_addons/network/quantize_analog_input")
	
	if (ProjectSettings.has_setting("keh_addons/network/print_debug_info")):
		_print_debug = ProjectSettings.get_setting("keh_addons/network/print_debug_info")


func has_custom_data() -> bool:
	return _has_custom_data


# A 'generic' internal function meant to create the correct entry within the various
# input list containers.
func _register_data(container: Dictionary, n: String, c: bool) -> void:
	if (!container.has(n)):
		container[n] = {
			"mask": 1 << container.size(),
			"custom": c,
			"enabled": true
		}
	_has_custom_data = _has_custom_data || c


# Register either a boolean or analog input data.
func register_action(map: String, is_analog: bool, custom: bool) -> void:
	if (_print_debug):
		print_debug("Registering%snetwork input '%s' | analog: %s" % [" custom " if custom else " ", map, is_analog])
	if (is_analog):
		_register_data(_analog_list, map, custom)
	else:
		_register_data(_bool_list, map, custom)

# Register vector2 data, which is necessarily custom data
func register_vec2(map: String) -> void:
	if (_print_debug):
		print_debug("Registering custom vector2 network input data %s" % map)
	_register_data(_vec2_list, map, true)

# Register vector3 data, which is necessarily custom data
func register_vec3(map: String) -> void:
	if (_print_debug):
		print_debug("Registering custom vector3 network input data %s" % map)
	_register_data(_vec3_list, map, true)


# Reset all previous input registration.
func reset_actions() -> void:
	_analog_list.clear()
	_bool_list.clear()
	_vec2_list.clear()
	_vec3_list.clear()
	_has_custom_data = false


# Set enabled state of action
func set_action_enabled(map: String, enabled: bool) -> void:
	if _analog_list.has(map):
		_analog_list[map].enabled = enabled
	elif _bool_list.has(map):
		_bool_list[map].enabled = enabled
	else:
		push_warning("Trying to set action enabled state on non-existent action '%s'." % map)


# Allow overriding the project setting related to the mouse relative
func set_use_mouse_relative(use: bool) -> void:
	_use_mouse_relative = use

# Allow overriding the project setting related to the mouse speed
func set_use_mouse_speed(use: bool) -> void:
	_use_mouse_speed = use


func use_mouse_relative() -> bool:
	return _use_mouse_relative

func use_mouse_speed() -> bool:
	return _use_mouse_speed


func make_empty() -> InputData:
	var ret: InputData = InputData.new(0)
	
	if (_use_mouse_relative):
		ret.set_mouse_relative(Vector2())
	if (_use_mouse_speed):
		ret.set_mouse_speed(Vector2())
	
	for a in _analog_list:
		ret.set_analog(a, 0.0)
	
	for b in _bool_list:
		ret.set_pressed(b, false)
	
	for v in _vec2_list:
		ret.set_custom_vec2(v, Vector2())
	
	for v in _vec3_list:
		ret.set_custom_vec3(v, Vector3())
	
	return ret

# When encoded, change masks use a variable number of bytes depending on the
# amount of registered input data of the specific type. So, if there are less
# than 9 analog actions, the change mask will use a single byte. This requires
# some checking before (re)writing data. This helper internal function is meant
# to perform the correct writing of the mask.
# This function assumes the proper check of the size > 0 has already been done
func _write_mask(m: int, size: int, buffer: EncDecBuffer, at: int = -1) -> void:
	if (size <= 8):
		if (at < 0):
			buffer.write_byte(m)
		else:
			buffer.rewrite_byte(m, at)
	
	elif (size <= 16):
		if (at < 0):
			buffer.write_ushort(m)
		else:
			buffer.rewrite_ushort(m, at)
	
	else:
		if (at < 0):
			buffer.write_uint(m)
		else:
			buffer.rewrite_uint(m, at)

# And this helper internal function is meant to perform the reading of encoded
# change masks.
func _read_mask(size: int, buffer: EncDecBuffer) -> int:
	if (size <= 8):
		return buffer.read_byte()
	elif (size <= 16):
		return buffer.read_ushort()
	
	return buffer.read_uint()



# Given an EncDecBuffer and an InputData, encode the input into the buffer
func encode_to(encdec: EncDecBuffer, input: InputData) -> void:
	# Encode the signature of the input object - Integer, set as uint - 4 bytes
	encdec.write_uint(input.signature)
	
	# Encode the flag indicating if this object has input or not
	encdec.write_bool(input.has_input())
	
	# If there is input, encode it
	if (input.has_input()):
		# Encode mouse relative if it's enabled - Vector2 - 8 bytes
		if (_use_mouse_relative):
			encdec.write_vector2(input.get_mouse_relative())
		
		# Encode mouse speed if it's enabled - Vector2 - 8 bytes
		if (_use_mouse_speed):
			encdec.write_vector2(input.get_mouse_speed())
		
		# Encode analog data, if there is at least one registered
		if (_analog_list.size() > 0):
			var windex: int = encdec.get_current_size()
			var cmask: int = 0
			_write_mask(cmask, _analog_list.size(), encdec)
			
			for a in _analog_list:
				var fval: float = input.get_analog(a)
				if (fval != 0):
					cmask |= _analog_list[a].mask
					# Since this analog input is not zero, encode it
					if (_quantize_analog):
						# Quantization is enabled, so use it
						var quant: int = Quantize.quantize_float(fval, 0.0, 1.0, 8)
						encdec.write_byte(quant)
					else:
						# Encode normaly
						encdec.write_float(fval)
			
			# All relevant analogs have been encoded. If something changed the
			# mask must be updated within the encoded byte array. The correct index
			# is stored in the windex variable
			if (cmask != 0):
				_write_mask(cmask, _analog_list.size(), encdec, windex)
		
		# Encode boolean data
		if (_bool_list.size() > 0):
			var mask: int = 0
			for m in _bool_list:
				if (input.is_pressed(m)):
					mask |= _bool_list[m].mask
			
			_write_mask(mask, _bool_list.size(), encdec)
		
		# Encode custom vector2 data
		if (_vec2_list.size() > 0):
			var windex: int = encdec.get_current_size()
			var mask: int = 0
			_write_mask(mask, _vec2_list.size(), encdec)
			
			for v in _vec2_list:
				var vec2: Vector2 = input.get_custom_vec2(v)
				if (vec2.x != 0.0 || vec2.y != 0.0):
					mask |= _vec2_list[v].mask
					encdec.write_vector2(vec2)
			
			if (mask != 0):
				_write_mask(mask, _vec2_list.size(), encdec, windex)
		
		# Encode custom vector3 data
		if (_vec3_list.size() > 0):
			var windex: int = encdec.get_current_size()
			var mask: int = 0
			_write_mask(mask, _vec3_list.size(), encdec)
			
			for v in _vec3_list:
				var vec3: Vector3 = input.get_custom_vec3(v)
				if (vec3.x != 0.0 || vec3.y != 0.0 || vec3.z != 0.0):
					mask |= _vec3_list[v].mask
					encdec.write_vector3(vec3)
			
			if (mask != 0):
				_write_mask(mask, _vec3_list.size(), encdec, windex)



# Use the received EncDecBuffer to decode data into an InputData object, which will
# be returned. This assumes the buffer is in the correct reading position
func decode_from(encdec: EncDecBuffer) -> InputData:
	var ret: InputData = InputData.new(0)
	
	# Decode the signature
	ret.signature = encdec.read_uint()
	# Decode the _has_input flag
	var has_input: bool = encdec.read_bool()
	
	if (has_input):
		# Decode mouse relative data if it's enabled
		if (_use_mouse_relative):
			ret.set_mouse_relative(encdec.read_vector2())
		
		# Decode mouse speed data if it's enabled
		if (_use_mouse_speed):
			ret.set_mouse_speed(encdec.read_vector2())
		
		
		# Decode analog data
		if (_analog_list.size() > 0):
			# First the change mask, indicating which of the analog inputs were
			# encoded
			var cmask: int = _read_mask(_analog_list.size(), encdec)
			for a in _analog_list:
				if (cmask & _analog_list[a].mask):
					if (_quantize_analog):
						# Analog quantization is enabled, so extract the quantized value first
						var quantized: int = encdec.read_byte()
						# Then restore the float
						ret.set_analog(a, Quantize.restore_float(quantized, 0.0, 1.0, 8))
					else:
						# No quantization used, so directly take the float
						ret.set_analog(a, encdec.read_float())
		
		# Decode boolean data
		if (_bool_list.size() > 0):
			var mask: int = _read_mask(_bool_list.size(), encdec)
			for b in _bool_list:
				ret.set_pressed(b, (mask & _bool_list[b].mask))
		
		# Decode vector2 data
		if (_vec2_list.size() > 0):
			var mask: int = _read_mask(_vec2_list.size(), encdec)
			for v in _vec2_list:
				if (mask & _vec2_list[v].mask):
					ret.set_custom_vec2(v, encdec.read_vector2())
		
		# Decode vector3 data
		if (_vec3_list.size() > 0):
			var mask: int = _read_mask(_vec3_list.size(), encdec)
			for v in _vec3_list:
				if (mask & _vec3_list[v].mask):
					ret.set_custom_vec3(v, encdec.read_vector3())
	
	return ret

