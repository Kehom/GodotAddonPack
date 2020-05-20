# This class represents projectiles within the network snapshots

extends SnapEntityBase
class_name MegaSnapProjectile

var position: Vector3
#var orientation: Quat
# The orientation here uses compression through the smallest three method.
# In this case, 9 bits per component, meaning that everything fits in a single
# integer.
var orientation: int


# Hold network ID of the player that fired this projectile
var fired_by: int

func _init(uid: int, h: int).(uid, h) -> void:
	# In this demo there is only one type of projectile so disabling the
	# class_hash property
	set_meta("class_hash", 0)
	# The fired_by property is a unique ID and when sent through the network
	# it may be changed because of the signal and number of bits. So, indicate
	# this is meant to be dealt as an unsigned int
	set_meta("fired_by", EncDecBuffer.CTYPE_UINT)
	
	position = Vector3()
#	orientation = Quat()
	orientation = 0
	fired_by = 1


func apply_state(to_node: Node) -> void:
	assert(to_node is KinematicBody)
	to_node.apply_state({
		"position": position,
		"orientation": orientation,
		"fired_by": fired_by,
	})

