extends Reference
class_name UnitSelectionData


var _shape: ConvexPolygonShape
var _query: PhysicsShapeQueryParameters
var _owner: int = 1
var _selected: Array = []
var _selecting: Array = []

func _init(owner: int) -> void:
	_shape = ConvexPolygonShape.new()
	_query = PhysicsShapeQueryParameters.new()
	_owner = owner


func has_selection() -> bool:
	return (_selected.size() > 0)


# Based on a set of 8 points build a collision shape. Use the given
# physics state to determine if there are any units inside of the
# resulting shape. The owner of those units must match the given
# owner_id in order to perform the selection
func check_selection(points: Dictionary, state: PhysicsDirectSpaceState, validating: bool = false) -> void:
	# There is the chance that some "in selection" units got outside of
	# the shape, so those must be "unselected"
	for s in _selecting:
		s.unhover()
	_selecting.clear()
	
	var shape_points: PoolVector3Array = PoolVector3Array()
	shape_points.append(points.top_left_near)
	shape_points.append(points.top_right_near)
	shape_points.append(points.bottom_right_near)
	shape_points.append(points.bottom_left_near)
	shape_points.append(points.top_left_far)
	shape_points.append(points.top_right_far)
	shape_points.append(points.bottom_right_far)
	shape_points.append(points.bottom_left_far)
	
	_shape.points = shape_points
	_query.set_shape(_shape)
	
	var hits: Array = state.intersect_shape(_query)
	
	for h in hits:
		if (h.collider is CharUnitClass):
			var unit: CharUnitClass = h.collider
			if (unit._owner_id == _owner):
				if (validating):
					_selected.push_back(unit)
					unit.select(false)
				else:
					_selecting.push_back(unit)
					unit.hover()


func commit_selection() -> void:
	for s in _selecting:
		_selected.push_back(s)
		s.select()
	
	_selecting.clear()


func unselect_all() -> void:
	for s in _selected:
		s.unselect()
	_selected.clear()


func move_selected_to(pos: Vector3) -> void:
	for s in _selected:
		s.move_to(pos)

