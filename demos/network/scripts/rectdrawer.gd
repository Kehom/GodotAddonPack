extends Node2D
class_name RectangleDrawer

var _rect_data: Dictionary = {}

func is_dragging() -> bool:
	return (_rect_data.size() == 2)

func set_start(s: Vector2) -> void:
	_rect_data["start"] = s
	_rect_data["end"] = Vector2()
	update()

func set_end(e: Vector2) -> void:
	_rect_data["end"] = e - _rect_data.start
	update()

func clear() -> void:
	_rect_data.clear()
	update()

func _draw() -> void:
	if (_rect_data.size() == 2):
		draw_rect(Rect2(_rect_data.start, _rect_data.end), Color(.5, .5, .5), false)


func get_corners() -> Dictionary:
	if (!_rect_data.size() == 2):
		return {}
	
	var p1: Vector2 = _rect_data.start
	var p2: Vector2 = _rect_data.end + _rect_data.start
	
	var minx: float = min(p1.x, p2.x)
	var maxx: float = max(p1.x, p2.x)
	var miny: float = min(p1.y, p2.y)
	var maxy: float = max(p1.y, p2.y)
	
	
	return {
		"topleft": Vector2(minx, miny),
		"bottomright": Vector2(maxx, maxy),
	}

