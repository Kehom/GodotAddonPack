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

# This is largely based on the Lawnjelly's smoothing-addon, which can be found
# here: https://github.com/lawnjelly/smoothing-addon
# In here there are a few notable differences:
# - The target will be automatically assigned to be directly the node
# this is attached to. In other words, the smooth's parent.
# - Internally global transforms are used just so this will automatically
# work regardless of node hierarchy.

extends Node2D
# This is needed in order to static type Smooth2D. Unfortunately this also
# results in a duplication of Smooth2D from the node creation window
class_name Smooth2D

# If this is set to false then this node will not smoothly follow the target, but
# snap into it.
export var enabled: bool = true

var _target: Node2D = null

var _from: Transform2D
var _to: Transform2D

var _had_physics: bool = false

func _ready() -> void:
	# If node is initially hidden, must ensure processing is disabled
	set_process(is_visible_in_tree())
	set_physics_process(is_visible_in_tree())
	
	_target = get_parent()
	
	if (_target):
		_from = _target.global_transform
		_to = _from


func _process(dt: float) -> void:
	if (_had_physics):
		_cycle()
		_had_physics = false
	
	if (enabled):
		var alpha = Engine.get_physics_interpolation_fraction()
		global_transform = _from.interpolate_with(_to, alpha)
	else:
		global_transform = _to


func _physics_process(dt: float) -> void:
	if (_had_physics):
		_cycle()
	
	_had_physics = true



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())
			set_physics_process(is_visible_in_tree())

# Teleport/snap to the specified transform
func teleport_to(t: Transform2D) -> void:
	_from = t
	_to = t


func snap_to_target() -> void:
	if (!_target):
		return
	
	teleport_to(_target.global_transform)


func _cycle() -> void:
	if (!_target):
		return
	
	_from = _to
	_to = _target.global_transform

