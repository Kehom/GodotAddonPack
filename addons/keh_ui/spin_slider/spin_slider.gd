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
extends CustomControlBase
class_name SpinSlider

# Unfortunately the EditorSpinSlider is not fully exposed to GDScript. And the SpinBox Control lacks some of the features
# of the EditorSpinSlider.
# Originally this was intended to be a "translation" of the EditorSpinSlider code from C++ into GDScript. However the
# control itself is a subclass of Range, which is an abstract class. Unfortunately it's not possible to extend an
# abstract class using GDScript, meaning that what is found here is actually (almost) a "translation" of both Range and
# the desired EditorSpinSlider into a single Control. The Range control allows sharing of the internal data with other
# Range controls. This one does not offer such feature.
# Besides that, this control behaves slightly different from the EditorSpinSlider. Basically, in the original Control
# a slier is shown when the "step" property is different from 1. In here the slider is shown only when both the minimum
# and maximum values are set/enabled. Otherwise the spin buttons will be shown.


#######################################################################################################################
### Signals and definitions
const CNAME: String = "SpinSlider"


# Emitted when value changes, providing the new value (float) as argument to the signal handler
signal value_changed(value)

#######################################################################################################################
### "Public" properties
export var step: float = 1.0 setget set_step


# This is exported through the _get_property_list(). Unfortunately this removes the "reset to default value", but by
# doing so, when "set_value" is called during initialization the properties that it depends on are fully initialized.
# Without this those properties will be at default values and the resulting value might become incorrect
var value: float = 0.0 setget set_value

export var rounded_values: bool = false

export var flat: bool setget set_flat

export var select_all_on_focus: bool = true


# The next 4 properties will be exported through the _get_property_list()
var use_min_value: bool = false setget set_use_min_value
var min_value: float = 0.0 setget set_min_value

var use_max_value: bool = false setget set_use_max_value
var max_value: float = 100.0 setget set_max_value


#######################################################################################################################
### "Public" functions
func set_as_ratio(ratio: float) -> void:
	set_value(lerp(min_value, max_value, ratio))



func get_as_ratio() -> float:
	if (is_equal_approx(min_value, max_value)):
		# This is to prevent division by 0
		return 1.0
	
	return (value - min_value) / (max_value - min_value)


func set_value(val: float) -> void:
	if (step > 0):
		val = round(val / step) * step
	
	if (rounded_values):
		val = round(val)
	
	if (use_max_value && val > max_value):
		val = max_value
	
	if (use_min_value && val < min_value):
		val = min_value
	
	if (value == val):
		return

	value = val
	emit_signal("value_changed", value)
	update()
	_slider.update()
	property_list_changed_notify()



func set_use_min_value(val: bool) -> void:
	use_min_value = val
	property_list_changed_notify()
	minimum_size_changed()
	_adjust()
	update()

func set_min_value(mval: float) -> void:
	min_value = mval
	
	call_deferred("_check_range")


func set_use_max_value(val: bool) -> void:
	use_max_value = val
	property_list_changed_notify()
	minimum_size_changed()
	_adjust()
	update()

func set_max_value(mval: float) -> void:
	max_value = mval
	
	call_deferred("_check_range")


func set_step(val: float) -> void:
	step = val
	
	call_deferred("_check_range")



func set_flat(val: bool) -> void:
	flat = val
	# The flat thing means the background style should not be rendered. LineEdit does not support this. So, override its
	# "Focus" and "Normal" styles with empty ones
	update()


#######################################################################################################################
### "Private" definitions
class DragData extends Reference:
	var base_val: float = 0.0
	var allowed: bool = false
	var dragging: bool = false
	var capture_pos: Vector2 = Vector2()
	var diffy: float = 0.0

#######################################################################################################################
### "Private" properties
var _value_input: LineEdit = LineEdit.new()
var _slider: Control = Control.new()

var _mouse_over: bool = false
var _mouse_over_slider: bool = false

var _range_click_timer: Timer = Timer.new()

var _grabbing_grabber: bool = false

var _empty_style: StyleBoxEmpty = StyleBoxEmpty.new()

# This is used to track the last valid text entered within the _value_input LineEdit. This is meant to disallow non
# numeric digits from being typed in. In this regard it would have been fantastic if the LineEdit Control provided one
# way to validate keystrokes
var _last_valid: String = "0"


var _dragdata: DragData = DragData.new()

#######################################################################################################################
### "Private" functions
func _get_text_value() -> String:
	# In the source code, this function returns the result of the static String::num() function, which is not exposed to
	# scripting. I hope this results in the same output of that function
	#return "%.*f" % [step_decimals(step), value]
	return str(value)


func _use_slider() -> bool:
	return use_min_value && use_max_value


func _check_range() -> void:
	# This function is mostly used to "set_value()" through a deferred call after setting min_value and max_value. This
	# is required as when the Control is being loaded the "value" property is setup after the range properties. Deferring
	# the call when those are set allow for proper setup if the value set is outside of the new range.
	set_value(value)



func _adjust() -> void:
	if (_use_slider()):
		_slider.visible = true
		var sl_height: int = get_theme_constant("slider_height", CNAME)
		var sb: StyleBox = get_theme_stylebox("normal", CNAME)
		
		_value_input.margin_right = 0
		
		_slider.margin_top = -sl_height
		_slider.margin_left = sb.get_margin(MARGIN_LEFT) if sb else 0.0
		_slider.margin_right = -sb.get_margin(MARGIN_RIGHT) if sb else 0.0
	
	else:
		_slider.visible = false
		var updown: Texture = get_theme_icon("updown", CNAME)
		_value_input.margin_right = -updown.get_width()



#######################################################################################################################
### Event handlers
func _on_draw_slider() -> void:
	var fc: Color = get_theme_color("font_color", CNAME)
	fc.a = 0.2
	
	_slider.draw_rect(Rect2(Vector2(), _slider.rect_size), fc)
	
	var ix: int = int(get_as_ratio() * _slider.rect_size.x) - 2
	fc.a = 0.9
	_slider.draw_rect(Rect2(Vector2(ix, 0), Vector2(4, _slider.rect_size.y)), fc)
	
	
	if (_mouse_over || _mouse_over_slider):
		var gb: Texture = get_theme_icon("grabber_highlight", CNAME) if _mouse_over_slider else get_theme_icon("grabber", CNAME)
		var gx: int = int(ix - gb.get_width() * 0.5) + 2
		var gy: int = int((_slider.rect_size.y - gb.get_height()) * 0.5)
		
		_slider.draw_texture(gb, Vector2(gx, gy), Color(1, 1, 1, 1))



func _on_slider_mouse_entered() -> void:
	_mouse_over_slider = true
	_slider.update()

func _on_slider_mouse_exited() -> void:
	_mouse_over_slider = false
	_slider.update()


func _on_slider_gui_input(evt: InputEvent) -> void:
	var calculate_pos: bool = false
	var mpos: Vector2 = Vector2()
	
	var mb: InputEventMouseButton = evt as InputEventMouseButton
	if (mb):
		if (mb.button_index == BUTTON_LEFT):
			if (mb.is_pressed()):
				_value_input.grab_focus()
				_grabbing_grabber = true
				calculate_pos = true
				mpos = mb.position
			
			else:
				_grabbing_grabber = false
	
	var mm: InputEventMouseMotion = evt as InputEventMouseMotion
	if (mm):
		if (_grabbing_grabber):
			calculate_pos = true
			mpos = mm.position
	
	
	if (calculate_pos):
		var r: float = clamp(mpos.x / _slider.rect_size.x, 0.0, 1.0)
		set_as_ratio(r)


func _on_text_changed(nval: String) -> void:
	if (nval.empty() || nval.is_valid_float() || nval.is_valid_integer() || nval == "." || nval == "-"):
		_last_valid = nval
	
	else:
		_value_input.text = _last_valid
		_value_input.set_cursor_position(_last_valid.length())



func _on_text_entered(nval: String) -> void:
	set_value(float(nval))
	
	if (select_all_on_focus && _value_input.has_focus()):
		_value_input.call_deferred("select_all")


func _on_value_input_focus_enter() -> void:
	if (select_all_on_focus):
		_value_input.call_deferred("select_all")


func _on_value_input_focus_exit() -> void:
	if (_value_input.get_menu().visible):
		# Focus was removed because of context menu. So bail
		return
	
	_on_text_entered(_value_input.text)
	_value_input.select(0, 0)


func _on_range_click_timeout() -> void:
	if (!_dragdata.dragging && Input.is_mouse_button_pressed(BUTTON_LEFT)):
		var up: bool = get_local_mouse_position().y < (rect_size.y * 0.5)
		set_value(value + (step if up else -step))
		
		if (_range_click_timer.one_shot):
			_range_click_timer.wait_time = 0.075
			_range_click_timer.one_shot = false
			_range_click_timer.start()
	
	else:
		_range_click_timer.stop()



#######################################################################################################################
### Overrides
func _create_custom_theme() -> void:
	var sb_normal: StyleBox = get_stylebox("normal", "LineEdit").duplicate()
	add_theme_stylebox("normal", sb_normal)
	
	var sb_focus: StyleBox = get_stylebox("focus", "LineEdit").duplicate()
	add_theme_stylebox("focus", sb_focus)
	
	
	var updown: Texture = get_icon("updown", "SpinBox")
	add_theme_icon("updown", updown)
	
	var grtex: Texture = get_icon("grabber", "HSlider")
	add_theme_icon("grabber", grtex)
	
	var grhltex: Texture = get_icon("grabber_highlight", "HSlider")
	add_theme_icon("grabber_highlight", grhltex)
	
	
	var lcolor: Color = get_color("font_color", "LineEdit")
	add_theme_color("font_color", lcolor)
	
	
	var font: Font = get_font("font", "LineEdit")
	add_theme_font("font", font)
	
	# func add_theme_constant_range(name: String, constant: int, minval: int, maxval: int, allowlesser: bool = false, allowgreater: bool = false) -> void:
	add_theme_constant_range("slider_height", 4, 1, 10, false, true)


# The exposed name match exactly the names of the properties so there is no need to also override _set() and _get()
func _get_property_list() -> Array:
	var ret: Array = []
	
	ret.append({
		"name": "use_min_value",
		"type": TYPE_BOOL,
	})
#
	if (use_min_value):
		ret.append({
			"name": "min_value",
			"type": TYPE_REAL,
		})
	
	ret.append({
		"name": "use_max_value",
		"type": TYPE_BOOL,
	})
	
	if (use_max_value):
		ret.append({
			"name": "max_value",
			"type": TYPE_REAL,
		})
	
	
	ret.append({
		"name": "value",
		"type": TYPE_REAL
	})
	
	return ret




func _get_minimum_size() -> Vector2:
	var ret: Vector2 = _value_input.get_combined_minimum_size()
	if (_use_slider()):
		pass
	
	else:
		var updown: Texture = get_theme_icon("updown", CNAME)
		ret.x += updown.get_width()
	
	return ret



func _draw() -> void:
	var sbn: StyleBox = get_theme_stylebox("normal", CNAME)
	var sbf: StyleBox = get_theme_stylebox("focus", CNAME)
	
	_value_input.add_stylebox_override("normal", sbn)
	_value_input.add_stylebox_override("focus", sbf)
	
	var use_slider: bool = _use_slider()
	
	if (!use_slider):
		var updown: Texture = get_theme_icon("updown", CNAME)
		var ud_x: int = int(rect_size.x - updown.get_width())
		var ud_y: int = int((rect_size.y - updown.get_height()) * 0.5)
		draw_texture(updown, Vector2(ud_x, ud_y))
	
	var txtval: String = _get_text_value()
	if (_value_input.text != txtval):
		_value_input.text = txtval
		_last_valid = txtval
	
	var sb: StyleBox = get_theme_stylebox("normal", CNAME)
	
	if (flat):
		_empty_style.content_margin_left = sb.get_margin(MARGIN_LEFT)
		_empty_style.content_margin_top = sb.get_margin(MARGIN_TOP)
		_empty_style.content_margin_right = sb.get_margin(MARGIN_RIGHT)
		_empty_style.content_margin_bottom = sb.get_margin(MARGIN_BOTTOM)
		
		_value_input.add_stylebox_override("focus", _empty_style)
		_value_input.add_stylebox_override("normal", _empty_style)
		
	
	else:
		_value_input.add_stylebox_override("focus", get_theme_stylebox("focus", CNAME))
		_value_input.add_stylebox_override("normal", sb)



func _gui_input(evt: InputEvent) -> void:
	var mb: InputEventMouseButton = evt as InputEventMouseButton
	if (mb):
		if (mb.is_pressed()):
			var up: bool = mb.position.y < (rect_size.y * 0.5)
			
			match mb.button_index:
				BUTTON_LEFT:
					_value_input.grab_focus()
					
					set_value(value + (step if up else -step))
					
					_range_click_timer.wait_time = 0.6
					_range_click_timer.one_shot = true
					_range_click_timer.start()
					
					_dragdata.allowed = true
					_dragdata.capture_pos = mb.position
				
				BUTTON_RIGHT:
					_value_input.grab_focus()
					if (up && use_max_value):
						set_value(max_value)
					if (!up && use_min_value):
						set_value(min_value)
				
				BUTTON_WHEEL_UP:
					if (_value_input.has_focus()):
						set_value(value + step * mb.factor)
						accept_event()
				
				BUTTON_WHEEL_DOWN:
					if (_value_input.has_focus()):
						set_value(value - step * mb.factor)
						accept_event()
		
		else:
			# Button released
			if (mb.button_index == BUTTON_LEFT):
				_range_click_timer.stop()
				_dragdata.allowed = false
				if (_dragdata.dragging):
					_dragdata.dragging = false
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					warp_mouse(_dragdata.capture_pos)
	
	
	var mm: InputEventMouseMotion = evt as InputEventMouseMotion
	if (mm && mm.button_mask & BUTTON_MASK_LEFT):
		if (_dragdata.dragging):
			_dragdata.diffy += mm.relative.y
			var diffy: float = -0.01 * pow(abs(_dragdata.diffy), 1.8) * sign(_dragdata.diffy)
			set_value(_dragdata.base_val + step * diffy)
		
		elif (_dragdata.allowed && _dragdata.capture_pos.distance_to(mm.position) > 2):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_dragdata.dragging = true
			_dragdata.base_val = value
			_dragdata.diffy = 0.0



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_over = true
			update()
			_slider.update()
		
		NOTIFICATION_MOUSE_EXIT:
			_mouse_over = false
			update()
			_slider.update()
		
		NOTIFICATION_ENTER_TREE:
			_adjust()
		
		
		NOTIFICATION_THEME_CHANGED:
			call_deferred("minimum_size_changed")
			_value_input.call_deferred("minimum_size_changed")
			_adjust()




func _init() -> void:
	# This is required when implementing the Control, as saving changes trigger a "rebuild" of the script but does not
	# cleanup any children, leading to duplicated nodes. The stray children (if Controls) will interfere with the drawing
	while (get_child_count() > 0):
		var c: Node = get_child(0)
		remove_child(c)
		c.free()
	
	
	add_child(_value_input)
	_value_input.visible = true
	_value_input.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_value_input.mouse_filter = Control.MOUSE_FILTER_PASS
	_value_input.text = "0"
	
	# warning-ignore:return_value_discarded
	_value_input.connect("text_changed", self, "_on_text_changed")
	
	# warning-ignore:return_value_discarded
	_value_input.connect("text_entered", self, "_on_text_entered", [], CONNECT_DEFERRED)
	
	# warning-ignore:return_value_discarded
	_value_input.connect("focus_entered", self, "_on_value_input_focus_enter")
	
	# warning-ignore:return_value_discarded
	_value_input.connect("focus_exited", self, "_on_value_input_focus_exit", [], CONNECT_DEFERRED)
	
	
	add_child(_slider)
	_slider.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider.visible = false
	
	# warning-ignore:return_value_discarded
	_slider.connect("draw", self, "_on_draw_slider")
	
	# warning-ignore:return_value_discarded
	_slider.connect("mouse_entered", self, "_on_slider_mouse_entered")
	
	# warning-ignore:return_value_discarded
	_slider.connect("mouse_exited", self, "_on_slider_mouse_exited")
	
	# warning-ignore:return_value_discarded
	_slider.connect("gui_input", self, "_on_slider_gui_input")
	
	
	add_child(_range_click_timer)
	
	# warning-ignore:return_value_discarded
	_range_click_timer.connect("timeout", self, "_on_range_click_timeout")
	
	_adjust()


