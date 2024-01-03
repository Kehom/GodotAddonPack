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


extends Spatial


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
var _radius: float = 0

#######################################################################################################################
### "Private" functions
func _set_radius(rad: float) -> void:
	_radius = clamp(rad, 0.2, 5.0)
	
	var sphere: SphereMesh = ($radimpulse/visual as MeshInstance).mesh
	sphere.radius = _radius
	sphere.height = _radius * 2.0
	
	($radimpulse as RadialImpulse3D).radius = _radius


#######################################################################################################################
### Event handlers
func _on_opt_falloff_item_selected(index: int) -> void:
	var optbt: OptionButton = ($ui/panel/Settings/opt_falloff as OptionButton)
	var id: int = optbt.get_item_id(index)
	($radimpulse as RadialImpulse3D).falloff = id


func _on_txt_impulse_value_changed(value: float) -> void:
	($radimpulse as RadialImpulse3D).force = value


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
				($radimpulse as RadialImpulse3D).apply_impulse()
			
			BUTTON_WHEEL_UP:
				_set_radius(_radius + 0.1)
			
			BUTTON_WHEEL_DOWN:
				_set_radius(_radius - 0.1)
	
	
	var mm: InputEventMouseMotion = evt as InputEventMouseMotion
	if (mm):
		var cam: Camera = get_viewport().get_camera()
		var ray_from: Vector3 = cam.project_ray_origin(mm.global_position)
		var ray_dir: Vector3 = cam.project_ray_normal(mm.global_position)
		var ray_to: Vector3 = ray_from + (ray_dir * 10000.0)
		
		var hit: Dictionary = get_world().direct_space_state.intersect_ray(ray_from, ray_to, [], 2)
		if (hit.size() > 0):
			var rimp: RadialImpulse3D = ($radimpulse as RadialImpulse3D)
			
			var fpos: Vector3 = hit.position
			fpos.y = 0
			rimp.global_transform.origin = fpos
			


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
	
	_set_radius(1.0)
	
	OverlayDebugInfo.set_visibility(false)


