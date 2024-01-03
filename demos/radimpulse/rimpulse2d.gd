# Copyright (c) 2024 Yuri Sarudiansky
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


extends Node2D


#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions



#######################################################################################################################
### "Private" properties
var _original_physics: int = 30

# Cache the radius for easier deltas - the initial value doesn't matter as it will be set later within the _ready()
var _radius: int = 0

#######################################################################################################################
### "Private" functions
func _set_radius(val: float) -> void:
	val = clamp(val, 32, 500)
	
	_radius = int(val)
	
	# Calculate the scale to be set within the "visual" of the RadialImpulse. The texture is 40x40 so dividing the
	# requested radius by 20 should give the appropriate scale value
	var s: float = val / 20.0
	
	($radimpulse/visual as Sprite).scale = Vector2(s, s)
	($radimpulse as RadialImpulse2D).radius = _radius


#######################################################################################################################
### Event handlers
func _on_opt_falloff_item_selected(index: int) -> void:
	var optbt: OptionButton = ($ui/panel/Settings/opt_falloff as OptionButton)
	var id: int = optbt.get_item_id(index)
	($radimpulse as RadialImpulse2D).falloff = id


func _on_txt_impulse_value_changed(value: float) -> void:
	($radimpulse as RadialImpulse2D).force = value


func _on_bt_back_pressed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")


#######################################################################################################################
### Overrides
func _unhandled_input(evt: InputEvent) -> void:
	var mb: InputEventMouseButton = evt as InputEventMouseButton
	if (mb && mb.is_pressed()):
		match mb.button_index:
			BUTTON_LEFT:
				($radimpulse as RadialImpulse2D).apply_impulse()
			
			BUTTON_WHEEL_UP:
				_set_radius(_radius + 5)
			
			BUTTON_WHEEL_DOWN:
				_set_radius(_radius - 5)
	
	
	var mm: InputEventMouseMotion = evt as InputEventMouseMotion
	if (mm):
		if (($helper as Control).get_rect().has_point(mm.global_position)):
			($radimpulse as RadialImpulse2D).global_position = mm.global_position



func _exit_tree() -> void:
	Engine.iterations_per_second = _original_physics


func _enter_tree() -> void:
	_original_physics = Engine.iterations_per_second
	Engine.iterations_per_second = 60


func _ready() -> void:
	# Fill the OptionButton with the FallOff options - and ensure the selected one matches the RadialImpulse
	var optfall: OptionButton = ($ui/panel/Settings/opt_falloff as OptionButton)
	optfall.clear()
	optfall.add_item("Constant", RadialImpulse2D.ImpulseFalloff.CONSTANT)
	optfall.add_item("Linear", RadialImpulse2D.ImpulseFalloff.LINEAR)
	optfall.selected = 0
	_on_opt_falloff_item_selected(optfall.selected)
	
	# Ensure the impulse value in the SpinBox matches the one on the RadialImpulse
	_on_txt_impulse_value_changed(($ui/panel/Settings/txt_impulse as SpinBox).value)
	
	_set_radius(40)
	
	OverlayDebugInfo.set_visibility(false)

