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

# This is meant to be a "lightweight data object". Basically, when input
# is gathered through the network input system, an object of this class
# will be generated. When encoding data, it will be retrieved from one
# object of this class. When decoding, an object of this class will be
# generated.
# Instead of using the normal input polling, when this kind of data becomes
# necessary it should be requested from the network object, which will then
# provide an object of this class.

extends Reference
class_name InputData

var _vec2: Dictionary = {}
var _vec3: Dictionary = {}
var _analog: Dictionary = {}
var _action: Dictionary = {}
var _has_input: bool = false
var signature: int = 0

func _init(s: int) -> void:
	signature = s

func has_input() -> bool:
	return _has_input

func get_custom_vec2(name: String) -> Vector2:
	return _vec2.get(name, Vector2())

func set_custom_vec2(name: String, val: Vector2) -> void:
	_vec2[name] = val
	_has_input = (val.x != 0.0 || val.y != 0.0 || _has_input)

func get_custom_vec3(name: String) -> Vector3:
	return _vec3.get(name, Vector3())

func set_custom_vec3(name: String, val: Vector3) -> void:
	_vec3[name] = val
	_has_input = (val.x != 0.0 || val.y != 0.0 || val.z != 0.0 || _has_input)

func set_custom_bool(name: String, val: bool) -> void:
	_action[name] = val
	_has_input = (val || _has_input)


func get_mouse_relative() -> Vector2:
	return get_custom_vec2("relative")

func set_mouse_relative(mr: Vector2) -> void:
	set_custom_vec2("relative", mr)

func get_mouse_speed() -> Vector2:
	return get_custom_vec2("speed")

func set_mouse_speed(ms: Vector2) -> void:
	set_custom_vec2("speed", ms)

func get_analog(map: String) -> float:
	return _analog.get(map, 0.0)

func set_analog(map: String, val: float) -> void:
	_analog[map] = val
	_has_input = (val != 0.0 || _has_input)

func is_pressed(map: String) -> bool:
	return _action.get(map, false)

func get_custom_bool(map: String) -> bool:
	return _action.get(map, false)


func set_pressed(map: String, p: bool) -> void:
	_action[map] = p
	_has_input = (p || _has_input)

