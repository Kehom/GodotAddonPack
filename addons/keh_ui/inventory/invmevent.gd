###############################################################################
# Copyright (c) 2020 Yuri Sarudiansky
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

extends InventoryEvent
class_name InventoryEventMouse

# warning-ignore:unused_class_variable
var local_mouse_position: Vector2
# warning-ignore:unused_class_variable
var global_mouse_position: Vector2
# warning-ignore:unused_class_variable
var is_dragging: bool
# This is obviously irrelevant if is_dragging is set to false. Nevertheless, if true, then dragged item is
# of the same type + id + datacode of the item that triggered this event
# warning-ignore:unused_class_variable
var is_dragged_equal: bool

var button_index: int
var shift: bool setget set_shift
var control: bool setget set_control
var alt: bool setget set_alt
var command: bool setget set_command
var has_modifier: bool


func _init(idata: Dictionary, cont: Control).(idata, cont) -> void:
	button_index = 0
	shift = false
	control = false
	alt = false
	command = false
	has_modifier = false



func set_shift(v: bool) -> void:
	shift = v
	has_modifier = (shift || control || alt || command)

func set_control(v: bool) -> void:
	control = v
	has_modifier = shift || control || alt || command

func set_alt(v: bool) -> void:
	alt = v
	has_modifier = shift || control || alt || command

func set_command(v: bool) -> void:
	command = v
	has_modifier = shift || control || alt || command

