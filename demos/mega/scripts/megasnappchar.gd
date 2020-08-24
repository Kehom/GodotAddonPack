extends SnapEntityBase
class_name MegaSnapPCharacter

# With current character movement code only the vertical component of the velocity
# is really necessary to be replicated since the other two are reset at each frame
# iteration.

var position: Vector3
var orientation: Quat

#var velocity: Vector3
var vertical_vel: float
var pitch_angle: float
var stamina: float
var effects: PoolByteArray


func _init(uid: int, h: int).(uid, h) -> void:
	position = Vector3()
	orientation = Quat()
#	velocity = Vector3()
	vertical_vel = 0.0
	pitch_angle = 0.0
	stamina = 0.0
	effects = PoolByteArray()
	
	# Set so position, orientation and vertical velocity are compared with is_equal_approx(),
	# which incorporates a tolerance.
	set_meta("position", 0)
	set_meta("orientation", 0)
	set_meta("vertical_vel", 0)


func apply_state(to_node: Node) -> void:
	assert(to_node is KinematicBody)
	to_node.apply_state({
		"position": position,
		"orientation": orientation,
#		"velocity": velocity,
		"vertical_vel": vertical_vel,
		"angle": pitch_angle,
		"stamina": stamina,
		"effects": effects,
	})


func set_orientation(q: Quat) -> void:
	orientation = q

