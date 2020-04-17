extends SnapEntityBase
class_name NetSnapUnit

var position: Vector3 = Vector3()
var orientation: Quat = Quat()
var owner_id: int = 1
var target: Vector3 = Vector3()
var selected: bool = false
var color: Color = Color()


func _init(uid: int, chash: int).(uid, chash) -> void:
	# class_hash is not needed, so set the meta with this name to 0
	set_meta("class_hash", 0)
	
	# Hanlde the owner_id as an unsigned int
	set_meta("owner_id", EntityInfo.CTYPE_UINT)



func apply_state(to_node: Node) -> void:
	assert(to_node is KinematicBody)
	to_node.apply_state({
		"position": position,
		"orientation": orientation,
		"owner_id": owner_id,
		"target": target,
		"selected": selected,
		"color": color,
	})
	
