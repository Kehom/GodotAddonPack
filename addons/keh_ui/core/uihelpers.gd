# Copyright (c) 2021 Yuri Sarudiansky
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
extends Reference
class_name UIHelper


# Set the width of the border of the given stylebox. Note that this will obviously fail if the given stylebox subclass
# does not contain the border properties
static func set_stylebox_border(onto: StyleBoxFlat, left: int, top: int, right: int, bottom: int) -> void:
	onto.border_width_left = left
	onto.border_width_top = top
	onto.border_width_right = right
	onto.border_width_bottom = bottom


# Set the corner radius of the given style box (flat). The corners are in clockwise direction, from the top-left.
static func set_stylebox_corner_radius(onto: StyleBoxFlat, topleft: int, topright: int, bottomright: int, bottomleft: int) -> void:
	onto.corner_radius_top_left = topleft
	onto.corner_radius_top_right = topright
	onto.corner_radius_bottom_right = bottomright
	onto.corner_radius_bottom_left = bottomleft


# Set the content margin of the given stylebox. Note that this will obviously fail if the given stylebox subclass
# does not contain the margin properties.
static func set_stylebox_margin(onto: StyleBox, left: int, top: int, right: int, bottom: int) -> void:
	onto.content_margin_left = left
	onto.content_margin_top = top
	onto.content_margin_right = right
	onto.content_margin_bottom = bottom


# Given a font and a "box height", return the Y coordinate necessary to render a text using that font vertically centered
# within that box
static func get_text_vertical_center(font: Font, box_height: float) -> float:
	return ((box_height + (font.get_height() - font.get_descent() * 2.0)) * 0.5)


# Given a Control, change its four anchor points.
static func set_anchor_points(ctrl: Control, left: float, top: float, right: float, bottom: float) -> void:
	ctrl.set_anchor(MARGIN_LEFT, left)
	ctrl.set_anchor(MARGIN_TOP, top)
	ctrl.set_anchor(MARGIN_RIGHT, right)
	ctrl.set_anchor(MARGIN_BOTTOM, bottom)



# Given a Control, change its four margin points.
static func set_margins(ctrl: Control, left: int, top: int, right: int, bottom: int) -> void:
	ctrl.set_margin(MARGIN_LEFT, left)
	ctrl.set_margin(MARGIN_TOP, top)
	ctrl.set_margin(MARGIN_RIGHT, right)
	ctrl.set_margin(MARGIN_BOTTOM, bottom)

