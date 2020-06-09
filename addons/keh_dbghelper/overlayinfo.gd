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

# This class is meant to be used as an autoload script and aims to provide means to
# quickly dump text into the screen without having to deal with temporary UI controls
# to display debug/test information.
# Using this will add a box that expands/shrinks according to the amount of labels
# and text lengths.

extends CanvasLayer

# Use a background (Panel) which should help with readability of the text
var _background: PanelContainer

# Keep a "main box" to allow setting horizontal alignment
var _haligner: HBoxContainer
# This inner "main box" helps with vertica alignment
var _valigner: VBoxContainer
# The box that will hold the labels
var _label_box: VBoxContainer
# And one way to directly get labels to make manipulations easier
var _label_node: Dictionary = {}


func _enter_tree() -> void:
	_background = PanelContainer.new()
	_haligner = HBoxContainer.new()
	_valigner = VBoxContainer.new()
	_label_box = VBoxContainer.new()
	
	_background.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	_haligner.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	_valigner.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	_label_box.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	
	_background.self_modulate = Color(0.0, 0.0, 0.0, 0.65)
	_background.size_flags_vertical = 0
	
	# Make the outer "main box" fill the entire screen
	_haligner.anchor_right = 1.0
	_haligner.anchor_bottom = 1.0
	
	# Add the nodes into the tree
	add_child(_haligner)
	_haligner.add_child(_valigner)
	_valigner.add_child(_background)
	_background.add_child(_label_box)



func set_label(lblid: String, text: String) -> void:
	var lbl: Label = _label_node.get(lblid)
	if (!lbl):
		lbl = Label.new()
		_label_box.add_child(lbl)
		_label_node[lblid] = lbl
	
	lbl.text = text


# Add a label that will be removed after a certain amount of seconds. Timed labels
# cannot be changed after added
func add_timed_label(text: String, timeout: float) -> void:
	# Create the label and add into the container
	var lbl: Label = Label.new()
	lbl.text = text
	_label_box.add_child(lbl)
	
	# Setup the timer
	var t: Timer = Timer.new()
	t.process_mode = Timer.TIMER_PROCESS_IDLE
	# Give at least half second before removing the text label from the container.
	t.wait_time = max(0.5, timeout)
	t.one_shot = true
	# warning-ignore:return_value_discarded
	t.connect("timeout", self, "_on_timeout", [t, lbl])
	add_child(t)
	t.start()


func remove_label(lblid) -> void:
	var lbl: Label = _label_node.get(lblid)
	if (lbl):
		lbl.queue_free()
		# warning-ignore:return_value_discarded
		_label_node.erase(lbl)


func set_visibility(visible: bool) -> void:
	_background.visible = visible

func toggle_visibility() -> void:
	_background.visible = !_background.visible


func set_horizontal_align_left() -> void:
	_haligner.alignment = BoxContainer.ALIGN_BEGIN

func set_horizontal_align_center() -> void:
	_haligner.alignment = BoxContainer.ALIGN_CENTER

func set_horizontal_align_right() -> void:
	_haligner.alignment = BoxContainer.ALIGN_END


func set_vertical_align_top() -> void:
	_valigner.alignment = BoxContainer.ALIGN_BEGIN

func set_vertical_align_center() -> void:
	_valigner.alignment = BoxContainer.ALIGN_CENTER

func set_vertical_align_bottom() -> void:
	_valigner.alignment = BoxContainer.ALIGN_END


func set_panel_color(c: Color) -> void:
	_background.self_modulate = c


func clear() -> void:
	for lid in _label_node:
		_label_node[lid].queue_free()
	_label_node.clear()


func _on_timeout(t: Timer, lbl: Label) -> void:
	# Cleanup the label
	lbl.queue_free()
	# And cleanup the timer
	t.queue_free()

