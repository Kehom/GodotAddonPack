# Copyright (c) 2022 Yuri Sarudiansky
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

tool
extends Control
class_name SFXHelper

#######################################################################################################################
### Signals and definitions
# Position is relative to the listener
signal source_chosen(relative_pos)

#######################################################################################################################
### "Public" properties
export var scale: float = 0.01

#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
const _listener_image: Texture = preload("res://demos/audiomaster/manBrown_stand.png")

#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions
# The "origin" here is meant to be the center of the Control.
func _get_origin() -> Vector2:
	var cx: float = rect_size.x * 0.5
	var cy: float = rect_size.y * 0.5
	
	return Vector2(cx, cy)

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _gui_input(evt: InputEvent) -> void:
	var mb: InputEventMouseButton = evt as InputEventMouseButton
	if (mb):
		if (!mb.pressed && mb.button_index == BUTTON_LEFT):
			var origin: Vector2 = _get_origin()
			var diff: Vector2 = (mb.position - origin) * scale
			
			emit_signal("source_chosen", diff, scale)



func _draw() -> void:
	var origin: Vector2 = _get_origin()
	
	var subdiv: Vector2 = rect_size * 0.25
	
	# Draw the background
	draw_rect(Rect2(Vector2(), rect_size), Color(0.2, 0.2, 0.2, 1.0))
	
	# Draw some subdivision lines
	draw_line(Vector2(origin.x - subdiv.x, 0), Vector2(origin.x - subdiv.x, rect_size.y), Color(1.0, 1.0, 1.0, 0.25))
	draw_line(Vector2(origin.x + subdiv.x, 0), Vector2(origin.x + subdiv.x, rect_size.y), Color(1.0, 1.0, 1.0, 0.25))
	
	draw_line(Vector2(0, origin.y + subdiv.y), Vector2(rect_size.x, origin.y + subdiv.y), Color(1.0, 1.0, 1.0, 0.25))
	draw_line(Vector2(0, origin.y - subdiv.y), Vector2(rect_size.x, origin.y - subdiv.y), Color(1.0, 1.0, 1.0, 0.25))
	
	# Draw center lines to help identify the "origin"
	draw_line(Vector2(origin.x, 0), Vector2(origin.x, rect_size.y), Color(0.2, 1.0, 0.2, 0.5))
	draw_line(Vector2(0, origin.y), Vector2(rect_size.x, origin.y), Color(1.0, 0.2, 0.2, 0.5))
	
	
	
	
	# Save current transfor, as the texture must be rotated -90 degree. But to do so the transform must be changed
	# before calling the draw function
	var trfm: Transform2D = get_canvas_transform()
	
	# Calculate the offset so the texture is centered in the desired position
	var offx: float = -_listener_image.get_height() * 0.5
	var offy: float = _listener_image.get_width() * 0.5
	
	# The texture must be rotated so the "person is looking up in the screen". So, must set the transform
	draw_set_transform(origin + Vector2(offx, offy), -PI/2.0, Vector2(1, 1))
	
	# Finally draw the "listener"
	draw_texture(_listener_image, Vector2())
	
	# And reset back so any other drawing will work correctly
	draw_set_transform_matrix(trfm)




func _get_minimum_size() -> Vector2:
	return Vector2(100, 100)
