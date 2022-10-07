extends KinematicBody
class_name CharUnitClass

var net_owner_id: int = 1
var net_target: Vector3
var net_position: Vector3
var net_orientation: Quat
var net_selected: bool = false
var net_color: Color = Color()

# This will be set during the unit custom initialization. Because dictionaries are
# references, this should not bring extra costs to the unit class other than the
# reference overhead itself
var _materials: Dictionary


func _ready() -> void:
	net_target = global_transform.origin
	net_position = global_transform.origin
	net_orientation = Quat(global_transform.basis)


func _physics_process(_dt: float) -> void:
	global_transform = Transform(Basis(net_orientation),net_position)
	if (network.has_authority()):
		tick_movement()
	net_position = global_transform.origin
	net_orientation = Quat(global_transform.basis)
	network.snapshot_entity(self)

func tick_movement() -> void:
	var pos: Vector3 = global_transform.origin
	
	if (pos.distance_to(net_target) > 1.0):
		# This is already normalized
		var dir: Vector3 = pos.direction_to(net_target)
		# warning-ignore:return_value_discarded
		move_and_slide(dir * 15.0)




func set_color(c: Color) -> void:
	var mat: SpatialMaterial = _materials.get(c)
	if (mat):
		$mesh.set_surface_material(0, mat)
		net_color = c
	else:
		push_warning("There is not matching material for provided color %s. Unit remains with default color." % c)


# Commands the unit to move to the target location.
func move_to(target: Vector3) -> void:
	net_target = target


func select(with_visual: bool = true) -> void:
	$mesh/outline_hover.visible = false
	if (with_visual):
		$mesh/outline_select.visible = true
	net_selected = true

func unselect() -> void:
	$mesh/outline_select.visible = false
	$mesh/outline_hover.visible = false
	net_selected = false

func hover() -> void:
	if (!$mesh/outline_select.visible):
		$mesh/outline_hover.visible = true

func unhover() -> void:
	$mesh/outline_hover.visible = false

func apply_state() -> void:
	pass
