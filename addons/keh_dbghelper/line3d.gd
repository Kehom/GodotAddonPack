###############################################################################
# Copyright (c) 2020 Yuri Sarudiansky
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################

# This is a "quick and dirty" script that is meant to be added into the auto-load script list
# With this it becomes possible to draw simple lines in 3D which may help debug things.
# It also provides means to add "timed lines", which will be deleted after the specified amount
# of seconds when the lines are created.

extends ImmediateGeometry

class Line3D:
	var p0: Vector3
	var p1: Vector3
	var color: Color
	
	func _init(point0: Vector3, point1: Vector3, col: Color) -> void:
		p0 = point0
		p1 = point1
		color = col


# Without material override, line colors don't work
var _mat: SpatialMaterial


# Lines in this array are "one-frame"
var _onef_line: Array = []

# Entries in this dictionary are meant to represent lines that will be deleted after the
# specified amount of seconds. The key here is an "unique ID" (_primid, declared bellow)
# Value is another dictionary, with fields:
# - line: instance of Line3D
# - timer: instace of Timer
var _timed_line: Dictionary = {}



# This is just to internally generate the IDs of the timed primitives
var _primid: int


func _enter_tree() -> void:
	# Just to make sure
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	
	_mat = SpatialMaterial.new()
	_mat.flags_unshaded = true       # So lighting doesn't matter
	_mat.vertex_color_use_as_albedo = true     # So the specified line color works
	
	set_material_override(_mat)


func _physics_process(_dt: float) -> void:
	# Clear lines from previous frame
	clear()
	# Begin the "process"
	begin(Mesh.PRIMITIVE_LINES)
	
	# Iterate through the "one-frame" lines
	for l in _onef_line:
		set_color(l.color)
		add_vertex(l.p0)
		add_vertex(l.p1)
	
	for l in _timed_line.values():
		set_color(l.line.color)
		add_vertex(l.line.p0)
		add_vertex(l.line.p1)
	
	# End the "process"
	end()
	
	# Clear the "one-frame" line array and the sphere array
	_onef_line.clear()


func set_enabled(e: bool) -> void:
	set_physics_process(e)
	if (!e):
		# Remove all lines that were drawn
		clear()
		# Clear the line containers
		_onef_line.clear()
		_timed_line.clear()

func is_enabled() -> bool:
	return is_physics_processing()


func add_line(p0: Vector3, p1: Vector3, color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if (!is_physics_processing()):
		# Avoid filling the line container when the functionality is disabled
		return
	_onef_line.append(Line3D.new(p0, p1, color))

# Adds a timed line. Return the ID of this line. The ID is necessary in case time is set to 0, in which
# case the line has to be manually deleted, which requires the return value from this function
func add_timed_line(p0: Vector3, p1: Vector3, time: float, color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> int:
	# NOTE: is this really necessary?
	if (!is_physics_processing()):
		# Avoid filling the line container when the functionality is disabled
		return 0
	
	_primid += 1
	_timed_line[_primid] = {
		"line": Line3D.new(p0, p1, color),
		"timer": Timer.new() if time > 0.0 else null
	}
	
	var t: Timer = _timed_line[_primid].timer
	if (t):
		# Configure the timer if it's valid
		t.one_shot = true
		t.wait_time = time
		# warning-ignore:return_value_discarded
		t.connect("timeout", self, "_on_timeout", [_primid, _timed_line])
		add_child(t)
		t.start()
	
	return _primid

func remove_timed_line(id: int) -> void:
	var linfo: Dictionary = _timed_line.get(id, {})
	if (linfo.size() > 0):
		var t: Timer = linfo.timer
		if (t):
			t.stop()
			t.queue_free()
		
		# warning-ignore:return_value_discarded
		_timed_line.erase(id)



func _on_timeout(id: int, container: Dictionary) -> void:
	if (container == _timed_line):
		remove_timed_line(id)

