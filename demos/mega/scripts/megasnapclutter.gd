extends SnapEntityBase
class_name MegaSnapClutter

var position: Vector3
# The orientation is compressed using 10 bits per component precision
var orientation: Quat
var ang_velocity: Vector3
var lin_velocity: Vector3



func _init(uid: int, h: int).(uid, h) -> void:
	position = Vector3()
	orientation = Quat()
	ang_velocity = Vector3()
	lin_velocity = Vector3()


func apply_state(to_node: Node) -> void:
	assert(to_node is RigidBody)
	to_node.apply_state({
		"position": position,
		"orientation": orientation,
		"angular_velocity": ang_velocity,
		"linear_velocity": lin_velocity,
	})

