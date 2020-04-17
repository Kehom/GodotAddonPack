extends KinematicBody
class_name CharUnitClass

var _owner_id: int = 1
var _target: Vector3
var _selected: bool = false
var _color: Color = Color()

# This will be set during the unit custom initialization. Because dictionaries are
# references, this should not bring extra costs to the unit class other than the
# reference overhead itself
var _materials: Dictionary


func _ready() -> void:
	_target = global_transform.origin


func _physics_process(_dt: float) -> void:
	if (network.has_authority()):
		tick_movement()
	
	network.snapshot_entity(generate_snapshot_entity())

func tick_movement() -> void:
	var pos: Vector3 = global_transform.origin
	
	if (pos.distance_to(_target) > 1.0):
		# This is already normalized
		var dir: Vector3 = pos.direction_to(_target)
		# warning-ignore:return_value_discarded
		move_and_slide(dir * 15.0)




func set_color(c: Color) -> void:
	var mat: SpatialMaterial = _materials.get(c)
	if (mat):
		$mesh.set_surface_material(0, mat)
		_color = c
	else:
		push_warning("There is not matching material for provided color %s. Unit remains with default color." % c)


# Commands the unit to move to the target location.
func move_to(target: Vector3) -> void:
	_target = target


func select(with_visual: bool = true) -> void:
	$mesh/outline_hover.visible = false
	if (with_visual):
		$mesh/outline_select.visible = true
	_selected = true

func unselect() -> void:
	$mesh/outline_select.visible = false
	$mesh/outline_hover.visible = false
	_selected = false

func hover() -> void:
	if (!$mesh/outline_select.visible):
		$mesh/outline_hover.visible = true

func unhover() -> void:
	$mesh/outline_hover.visible = false


func generate_snapshot_entity() -> NetSnapUnit:
	# The class hash is not enabled so setting it 0 for this kind of entity
	var ret: NetSnapUnit = NetSnapUnit.new(get_meta("uid"), 0)
	
	ret.position = global_transform.origin
	ret.orientation = Quat(global_transform.basis)
	ret.owner_id = _owner_id
	ret.target = _target
	ret.selected = _selected
	ret.color = _color
	
	return ret


func apply_state(state: Dictionary) -> void:
	global_transform.origin = state.position
	global_transform.basis = Basis(state.orientation)
	_owner_id = state.owner_id
	_target = state.target
	_selected = state.selected
	set_color(state.color)


