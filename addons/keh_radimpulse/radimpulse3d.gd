# Copyright (c) 2024 Yuri Sarudiansky
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

tool
extends Spatial
class_name RadialImpulse3D

#######################################################################################################################
### Signals and definitions
signal impulse_applied()

enum ImpulseFalloff {
	CONSTANT,
	LINEAR,
}

#######################################################################################################################
### "Public" properties
export var radius: float = 10.0 setget set_radius

export var force: float = 0.0

export(ImpulseFalloff) var falloff: int = ImpulseFalloff.CONSTANT

#######################################################################################################################
### "Public" functions
func apply_impulse() -> void:
	if (is_equal_approx(force, 0.0) || !is_inside_tree()):
		return
	
	# Enable physics processing and apply the impulses only at that moment. This the easiest (and probably the "correct")
	# way of ensuring the internal _body array is holding the correct bodies that must be affected by the impulses
	# Otherwise there is a big chance it will be "out-dated" with old information before the Physics server updates the
	# states of all physics bodies/areas...
	set_physics_process(true)


func set_radius(val: float) -> void:
	radius = val
	_sshape.radius = val

#######################################################################################################################
### "Private" definitions
var _area: Area = Area.new()
var _shape: CollisionShape = CollisionShape.new()
var _sshape: SphereShape = SphereShape.new()

# Holds bodies that are inside the area AND can have impulses applied to
var _body: Array = []

#######################################################################################################################
### "Private" properties
func _on_body_entered(body: Node) -> void:
	var rigid: RigidBody = body as RigidBody
	if (!rigid):
		return
	
	_body.append(rigid)


func _on_body_exited(body: Node) -> void:
	var rigid: RigidBody = body as RigidBody
	if (!rigid):
		return
	
	_body.erase(rigid)

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _get_property_list() -> Array:
	var ret: Array = []
	
	ret.append({
		"name": "layer",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_LAYERS_2D_PHYSICS
	})
	
	ret.append({
		"name": "mask",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_LAYERS_2D_PHYSICS
	})
	
	
	return ret


func _set(pname: String, val) -> bool:
	var ret: bool = true
	
	match pname:
		"layer":
			_area.collision_layer = val
		"mask":
			_area.collision_mask = val
		
		# For some reason, attempting to set anything related to the Transform is not working because of _set() and _get
		# Manually dealing with those seems to fix things
		"rotation_degrees":
			rotation_degrees = val
		"translation":
			translation = val
		"scale":
			scale = val
		"global_transform":
			global_transform = val
		
		"_":
			ret = false
	
	return ret


func _get(pname: String):
	match pname:
		"layer":
			return _area.collision_layer
		"mask":
			return _area.collision_mask
	
	return null


func _physics_process(_dt: float) -> void:
	for bi in _body.size():
		var body: RigidBody = _body[bi]
		
		var dir: Vector3 = body.global_transform.origin - global_transform.origin
		var dist: float = dir.length()
		
		if (is_equal_approx(dist, 0.0) || (dist > radius && falloff == ImpulseFalloff.LINEAR)):
			# A distance of "0" will result in problems when calculating the normalized direction.
			# Also, if the falloff is set to LINEAR then there is no point in calculating anything if distance is
			# bigger than radius. So just skip this body if that is the case
			continue
		
		# The expensive operation of vector normalization (calculate its length) has already been done. To prevent doing
		# it again by calling "vector.normalized()" manually calculate the normalized vector by simply dividing by its
		# length (which is dist)
		dir = dir / dist
		
		match falloff:
			ImpulseFalloff.CONSTANT:
				body.apply_impulse(Vector3(), dir * force)
			
			ImpulseFalloff.LINEAR:
				var f: float = (radius - dist) / radius * force
				body.apply_impulse(Vector3(), dir * f)
	
	emit_signal("impulse_applied")
	
	# Disable physics processing again
	set_physics_process(false)


func _init() -> void:
	# This is just some cleanup needed during development
	var a: Node = get_node_or_null("_area_")
	if (a):
		a.name = "_remarea_"
		a.queue_free()
	
	_area.name = "_area_"
	add_child(_area)
	_area.add_child(_shape)
	_shape.shape = _sshape
	
	# warning-ignore:return_value_discarded
	_area.connect("body_entered", self, "_on_body_entered")
	
	# warning-ignore:return_value_discarded
	_area.connect("body_exited", self, "_on_body_exited")


func _ready() -> void:
	set_physics_process(false)
	set_process(false)

