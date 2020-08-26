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

# This is a "generic" interpolation node that will detect the type of the target and apply the interpolated
# transform into a list of selected nodes, as long as those do match the same type (2D vs 3D).
# A property is given to allow selection of the target node to be followed. If it is not given then the
# direct parent of this will be selected.


tool
extends Node
class_name AutoInterpolate


# If this is set to false then this node will not smoothly follow the target, but
# snap into it. It will take priority over the interpolate flags - which will serve as
# another method to disable interpolation if all flags are set to 0

# If this is set to false then no interpolation will be done. In other words, the transform will snap to the
# target instead of smoothly following it. This will take priority over the interpolate flags, which will
# serve as another method to disable interpolation if all flags are set to 0.
export var enabled: bool = true
# This property could easily substitute the enabled property, however if "enabled" is removed it may break compatibility
export(int, FLAGS, "Translation", "Orientation", "Scale") var interpolate: int = _SmoothCore.FI_ALL


export var target: NodePath = "" setget set_target

var _target: Node = null

# Holds a list of nodes to be interpolated according to the target node. Each entry is a dictionary that
# contains the following fields:
# - node: Reference to the node to be interpolated
# - npath: Path to the node in question
# - valid: True if the node can be interpolated according to the target type
var _interpolate: Array = []

# What will actually calculate the interpolation data
var _interp_data: _SmoothCore.InterpData


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


# Teleport/snap to the specified transform. Note that in this case the transform argument is not static typed
# because it must match the target node type
func teleport_to(t) -> void:
	# If this is failing then either the given transform is not of the same type of the target node or the
	# target is not valid at all
	assert((t is Transform2D && _target is Node2D) || (t is Transform && _target is Spatial))
	
	_interp_data.setft(t, t)

func snap_to_target() -> void:
	_interp_data.snap_to_target()



func _ready() -> void:
	if (is_inside_tree()):
		_check_target()
	else:
		call_deferred("_check_target")
	
	if (_target is Node2D):
		_interp_data = _SmoothCore.IData2D.new(_target)
	elif (_target is Spatial):
		_interp_data = _SmoothCore.IData3D.new(_target)
	else:
		push_warning("Node %s does not have a valid target to follow." % get_path())
	
	# If in editor disable the process function as it is useless in that case (the scene doesn't move right?)
	var proc: bool = _target != null && !Engine.is_editor_hint()
	set_process(proc)
	set_physics_process(proc)




func _process(_dt: float) -> void:
	_interp_data.cycle(false)
	
	if (_target is Node2D):
		var t: Transform2D = _interp_data.calculate(interpolate) if enabled else _interp_data.to
		
		for idata in _interpolate:
			if (idata.valid):
				idata.node.global_transform = t
	
	elif (_target is Spatial):
		var t: Transform = _interp_data.calculate(interpolate) if enabled else _interp_data.to
		
		for idata in _interpolate:
			if (idata.valid):
				idata.node.global_transform = t



func _physics_process(_dt: float) -> void:
	_interp_data.cycle(true)




func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PATH_CHANGED, NOTIFICATION_PARENTED:
			# At this point this node may not be "fully in the tree", which is required to properly check the
			# target node. Because of that, defer the call to give some time for things to finish setting up.
			call_deferred("_check_target")



func _get_property_list() -> Array:
	var ret: Array = []
	
	for i in _interpolate.size():
		var ename: String = ""
		if (_interpolate[i].valid):
			ename = "Interpolate %s"
		else:
			ename = "*Interpolate* %s"
		
		
		ret.append({
			"name": ename % (i + 1),
			"type": TYPE_NODE_PATH,
		})
	
	ret.append({
		"name": "Interpolate %s" % (_interpolate.size() + 1),
		"type": TYPE_NODE_PATH,
	})
	
	return ret


# This will be called only for the properties within the returned array (_get_property_list())
func _set(pname: String, val) -> bool:
	var sarr: PoolStringArray = pname.split(" ")
	var retval: bool = false
	
	
	if (sarr.size() != 2):
		return retval
	
	var trimmed: String = sarr[0].trim_prefix("*").trim_suffix("*")
	if (trimmed == "Interpolate"):
		var index: int = sarr[1].to_int() - 1
		if (index < 0 || index > _interpolate.size()):
			return retval
		
		if (index < _interpolate.size()):
			# In here setting a target node that already exists within the array
			_interpolate[index].npath = val
		
		else:
			# In here creating a new entry to be interpolated
			_interpolate.append({
				"node": null,
				"npath": val,
				"valid": false,
			})
		
		if (is_inside_tree()):
			_check_interp_list()
		else:
			call_deferred("_check_interp_list")
		
		retval = true
	
	
	return retval


# This override returns a variant, which cant be statically typed.
func _get(pname: String):
	var index: int = _get_interp_index(pname)
	if (index < 0 || index >= _interpolate.size()):
		return null
	
	return _interpolate[index].npath



func _get_configuration_warning() -> String:
	var retval: String = ""
	
	if (!_target):
		retval = "There is no valid node to be followed. Consider assigning the Target property or attaching this node into a valid one (derived from either Node2D ou Spatial)."
	
	if (_interpolate.size() == 0):
		if (!retval.empty()):
			retval += "\n"
		retval += "The list of nodes to be interpolated is empty. Consider assigning at least one through the Interpolate [n] property."
	else:
		var invmsg: String = "" if retval.empty() else "\n"
		if (_target is Node2D):
			invmsg += "Target node is 2D but the following nodes in the interpolate list are 3D:"
		elif (_target is Spatial):
			invmsg += "Target node is 3D but the following nodes in the interpolate list are 2D:"
		
		for i in _interpolate.size():
			if (!_interpolate[i].valid):
				if (!invmsg.empty()):
					retval += invmsg
					invmsg = ""
				
				retval += "\n- Interpolate %s" % (i + 1)
	
	return retval


func _check_interp_list() -> void:
	var mode: int = 0
	if (_target):
		if (_target is Node2D):
			mode = 1
		elif (_target is Spatial):
			mode = 2
	var index: int = 0
	var done: bool = index >= _interpolate.size()
	while (!done):
		var path: NodePath = _interpolate[index].npath if _interpolate[index].npath else ""
		
		var keep_entry = true
		var inode: Node = get_node_or_null(path)
		if (!inode || inode == _target):
			if (inode == _target && inode):
				push_warning("Interpolate %s property is assigned to the same Target node. Removing it." % (index + 1))
			keep_entry = false
		
		else:
			_interpolate[index].node = inode
			
			match mode:
				1:
					_interpolate[index].valid = inode is Node2D
				2:
					_interpolate[index].valid = inode is Spatial
				_:
					# To avoid flooding the warning message, just mark the entry as valid although there is no valid target
					_interpolate[index].valid = true
		
		
		if (keep_entry):
			index += 1
		else:
			_interpolate.remove(index)
		
		done = index >= _interpolate.size()
	
	property_list_changed_notify()
	update_configuration_warning()




func _get_interp_index(pname: String) -> int:
	var retval: int = -1
	var split: PoolStringArray = pname.split(" ")
	
	if (split.size() == 2):
		var trimmed: String = split[0].trim_prefix("*").trim_suffix("*")
		if (trimmed == "Interpolate"):
			retval = split[1].to_int() - 1
	
	
	return retval



func _check_target() -> void:
	var tnode: Node = null
	
	tnode = get_node_or_null(target)
	if (!tnode):
		if (!target.is_empty() && _target):
			target = get_path_to(_target)
			tnode = get_node_or_null(target)
	
	if (!tnode):
		target = ""
		tnode = get_parent()
	
	# Assume target node is invalid
	_target = null
	
	if (tnode):
		if (tnode is Node2D):
			_target = tnode
		
		elif (tnode is Spatial):
			_target = tnode
	
	if (!_target):
		target = ""
	
	
	#update_configuration_warning()
	_check_interp_list()


func set_target(v: NodePath) -> void:
	target = v
	if (is_inside_tree()):
		_check_target()
	else:
		call_deferred("_check_target")
