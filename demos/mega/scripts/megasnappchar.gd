extends SnapEntityBase
class_name MegaSnapPCharacter

# With current character movement code only the vertical component of the velocity
# is really necessary to be replicated since the other two are reset at each frame
# iteration.

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
