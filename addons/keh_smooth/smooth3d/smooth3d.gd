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

extends Spatial
# This is needed in order to static type Smooth3D.
class_name Smooth3D


# If this is set to false then this node will not smoothly follow the target, but
# snap into it.
export var enabled: bool = true
export(int, FLAGS, "Translation", "Orientation", "Scale") var interpolate: int = _SmoothCore.FI_ALL

var _interp_data: _SmoothCore.IData3D


func set_interpolate_translation(enable: bool) -> void:
	interpolate = _SmoothCore.set_bits(interpolate, _SmoothCore.FI_TRANSLATION, enable)

func is_interpolating_translation() -> bool:
	return _SmoothCore.is_enabled(interpolate, _SmoothCore.FI_TRANSLATION)


func set_interpolate_orientation(enable: bool) -> void:
	interpolate = _SmoothCore.set_bits(interpolate, _SmoothCore.FI_ORIENTATION, enable)

func is_interpolating_orientation() -> bool:
	return _SmoothCore.is_enabled(interpolate, _SmoothCore.FI_ORIENTATION)


func set_interpolate_scale(enable: bool) -> void:
	interpolate = _SmoothCore.set_bits(interpolate, _SmoothCore.FI_SCALE, enable)

func is_interpolating_scale() -> bool:
	return _SmoothCore.is_enabled(interpolate, _SmoothCore.FI_SCALE)


func _ready() -> void:
	# If node is initially hidden, must ensure processing is disabled
	set_process(is_visible_in_tree())
	set_physics_process(is_visible_in_tree())
	
	_interp_data = _SmoothCore.IData3D.new(get_parent_spatial())


func _process(_dt: float) -> void:
	_interp_data.cycle(false)
	
	if (enabled):
		global_transform = _interp_data.calculate(interpolate)
		
	else:
		global_transform = _interp_data.to


func _physics_process(_dt: float) -> void:
	_interp_data.cycle(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			var process: bool = is_visible_in_tree()
			set_process(process)
			set_physics_process(process)


func teleport_to(t: Transform) -> void:
	_interp_data.setft(t, t)



func snap_to_target() -> void:
	_interp_data.snap_to_target()

