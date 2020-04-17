extends SnapEntityBase
class_name MegaSnapPCharacter

# In here the orientation compression is done in a different way compared
# to the clutter and projectile objects, mostly to show another approach.
# Besides that, the compression precision here uses 15 bits per component
# rather than just 10, meaning that two integers are necessary to hold the
# orientation. Note however that the second integer is marked to be encoded
# as a short_uint(), meaning that only 16 bits of it will be added into
# the raw snapshot data.

var position: Vector3
var orientation: Quat

var velocity: Vector3
var pitch_angle: float
var stamina: float


func _init(uid: int, h: int).(uid, h) -> void:
	position = Vector3()
	orientation = Quat()
	velocity = Vector3()
	pitch_angle = 0.0
	stamina = 0.0


func apply_state(to_node: Node) -> void:
	assert(to_node is KinematicBody)
	to_node.apply_state({
		"position": position,
		"orientation": orientation,
		"velocity": velocity,
		"angle": pitch_angle,
		"stamina": stamina,
	})


func set_orientation(q: Quat) -> void:
	orientation = q
