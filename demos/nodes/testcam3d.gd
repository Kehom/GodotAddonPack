extends Spatial

const Cam3DClass = preload("res://addons/keh_nodes/cam3d/cam3d.gd")

var pivot_rot_speed: float = 1.57   # Roughly pi/2
var roll_speed: float = 0.0
var pitch_speed: float = 0.0
var current_pitch: float = 0.0

onready var original_physics: int = Engine.iterations_per_second

## Easy access to some nodes
onready var camera: Cam3DClass = $rotator/dummy_char/Cam3D
onready var lpanel: Panel = $ctrl/lpnl
onready var rpanel: Panel = $ctrl/rpnl

# This will be used to build the dropdown menu as well as help with the signal handling
# of the choices within that control, which is meant to change the camera motion mode
# (smoothing, that is).
var lag_mode: Dictionary = {
	1: { "label": "No lag", "code": Cam3DClass.CameraLag.None },
	2: { "label": "Smooth Start", "code": Cam3DClass.CameraLag.SmoothStart },
	3: { "label": "Smooth Stop", "code": Cam3DClass.CameraLag.SmoothStop },
}

# This will be used to build the dropdown menu as well as help with the signal handling
# of the choices within that control, which is meant to change the camera collision mode
var coll_mode_list: Dictionary = {
	1: { "label": "None", "code": Cam3DClass.CollisionMode.None },
	2: { "label": "Shrink Arm", "code": Cam3DClass.CollisionMode.ShrinkArm },
	3: { "label": "Cull Obstructing", "code": Cam3DClass.CollisionMode.CullObstructing },
	4: { "label": "Hide Obstructing", "code": Cam3DClass.CollisionMode.HideObstructing }
}


func _ready() -> void:
	setup_dropdown(rpanel.get_node("box_camlag/mnu_camlag"), lag_mode, "_on_cam_lag_changed")
	setup_dropdown(rpanel.get_node("box_collision/mnu_collision"), coll_mode_list, "_on_cam_collision_changed")

	### Manually connect some events in order to pass in payloads which can make things simpler
	### by avoiding the creation of many functions to handle the signals
	
	# Sliders to control camera arm rotation - payload indicate axis index (0 = x | 1 = y | 2 = z)
	SharedUtils.connector(lpanel.get_node("box_armrotx/sl_armrotx"), "value_changed", self, "_on_arm_rotation_changed", [0])
	SharedUtils.connector(lpanel.get_node("box_armroty/sl_armroty"), "value_changed", self, "_on_arm_rotation_changed", [1])
	SharedUtils.connector(lpanel.get_node("box_armrotz/sl_armrotz"), "value_changed", self, "_on_arm_rotation_changed", [2])
	
	# Buttons to reset camera arm rotation - payload indicate axis index and corresponding slider
	# so it can be updated to hold the correct value
	SharedUtils.connector(lpanel.get_node("box_armrotx/bt_armrotxreset"), "pressed", self, "_on_arm_rotation_reset", [0, lpanel.get_node("box_armrotx/sl_armrotx")])
	SharedUtils.connector(lpanel.get_node("box_armroty/bt_armrotyreset"), "pressed", self, "_on_arm_rotation_reset", [1, lpanel.get_node("box_armroty/sl_armroty")])
	SharedUtils.connector(lpanel.get_node("box_armrotz/bt_armrotzreset"), "pressed", self, "_on_arm_rotation_reset", [2, lpanel.get_node("box_armrotz/sl_armrotz")])
	
	
	# Check boxes to toggle camera rotation locking - payload indicate which axis should be locked
	SharedUtils.connector(rpanel.get_node("box_lockcam/chk_lockpitch"), "toggled", self, "_on_lock_changed", ["pitch"])
	SharedUtils.connector(rpanel.get_node("box_lockcam/chk_lockyaw"), "toggled", self, "_on_lock_changed", ["yaw"])
	SharedUtils.connector(rpanel.get_node("box_lockcam/chk_lockroll"), "toggled", self, "_on_lock_changed", ["roll"])
	
	# Check boxes to change the camera shake mode - payload indicate shake rotate (0) or translate (1)
	SharedUtils.connector(rpanel.get_node("box_shakemode/chk_shakerotate"), "toggled", self, "_on_cam_shake_toggled", [0])
	SharedUtils.connector(rpanel.get_node("box_shakemode/chk_shaketranslate"), "toggled", self, "_on_cam_shake_toggled", [1])
	
	# Sliders to change maximum rotation during camera shake - payload = which axis
	SharedUtils.connector(rpanel.get_node("box_mshakeyaw/sl_mshakeyaw"), "value_changed", self, "_on_max_shake_rotate", ["yaw"])
	SharedUtils.connector(rpanel.get_node("box_mshakepitch/sl_mshakepitch"), "value_changed", self, "_on_max_shake_rotate", ["pitch"])
	SharedUtils.connector(rpanel.get_node("box_mshakeroll/sl_mshakeroll"), "value_changed", self, "_on_max_shake_rotate", ["roll"])
	# And their corresponding reset buttons - payload is which axis
	SharedUtils.connector(rpanel.get_node("box_mshakeyaw/bt_mshakeyawreset"), "pressed", self, "_on_max_rotate_reset", ["yaw"])
	SharedUtils.connector(rpanel.get_node("box_mshakepitch/bt_mshakepitchreset"), "pressed", self, "_on_max_rotate_reset", ["pitch"])
	SharedUtils.connector(rpanel.get_node("box_mshakeroll/bt_mshakerollreset"), "pressed", self, "_on_max_rotate_reset", ["roll"])
	
	# Sliders to change maximum translation during camera shake
	SharedUtils.connector(rpanel.get_node("box_mshakex/sl_mshakex"), "value_changed", self, "_on_max_translate", [0])
	SharedUtils.connector(rpanel.get_node("box_mshakey/sl_mshakey"), "value_changed", self, "_on_max_translate", [1])
	SharedUtils.connector(rpanel.get_node("box_mshakez/sl_mshakez"), "value_changed", self, "_on_max_translate", [2])
	# And their corresponding reset buttons
	SharedUtils.connector(rpanel.get_node("box_mshakex/bt_mshakexreset"), "pressed", self, "_on_max_translate_reset", [0])
	SharedUtils.connector(rpanel.get_node("box_mshakey/bt_mshakeyreset"), "pressed", self, "_on_max_translate_reset", [1])
	SharedUtils.connector(rpanel.get_node("box_mshakez/bt_mshakezreset"), "pressed", self, "_on_max_translate_reset", [2])
	
	# The two opacity sliders - one for the left panel and the other for the right panel
	SharedUtils.connector(lpanel.get_node("box_opacity/sl_opacity"), "value_changed", self, "_on_opacity_changed", [lpanel])
	SharedUtils.connector(rpanel.get_node("box_opacity/sl_opacity"), "value_changed", self, "_on_opacity_changed", [rpanel])
	
	### Make UI reflect the settings
	lpanel.get_node("box_mspeed/sl_movespeed").value = pivot_rot_speed
	lpanel.get_node("box_rollspeed/sl_rollspeed").value = roll_speed
	lpanel.get_node("box_pitchspeed/sl_pitchspeed").value = pitch_speed
	
	lpanel.get_node("box_physicsfps/sl_physicsfps").value = original_physics
	lpanel.get_node("box_physicsfps/lbl_fps").text = str(original_physics)
	
	rpanel.get_node("box_lockcam/chk_lockpitch").pressed = camera.is_pitch_locked()
	rpanel.get_node("box_lockcam/chk_lockyaw").pressed = camera.is_yaw_locked()
	rpanel.get_node("box_lockcam/chk_lockroll").pressed = camera.is_roll_locked()
	
	rpanel.get_node("box_shakemode/chk_shakerotate").pressed = camera.is_shake_rotate_enabled()
	rpanel.get_node("box_shakemode/chk_shaketranslate").pressed = camera.is_shake_translate_enabled()
	rpanel.get_node("box_shakedecay/sl_shakedecay").value = camera.trauma_decay
	rpanel.get_node("box_timescale/sl_shaketscale").value = camera.shake_frequency


func _exit_tree() -> void:
	# Ensure the physics FPS is set to the project settings
	Engine.iterations_per_second = original_physics


func _process(delta: float) -> void:
	$rotator.rotation.y -= (pivot_rot_speed * delta)
	$rotator/dummy_char.rotation.z -= (roll_speed * delta)
	
	if (pitch_speed != 0.0):
		current_pitch += (pitch_speed * delta)
		$rotator/dummy_char.rotation.x = sin(current_pitch) * 0.5
	
	# Keep the trauma bar updated
	lpanel.get_node("pg_current_trauma").value = camera.get_trauma()




func setup_dropdown(ctrl: MenuButton, optlist: Dictionary, sig_handler: String) -> void:
	var pop: PopupMenu = ctrl.get_popup()
	for id in optlist:
		pop.add_item(optlist[id].label, id)
	
	SharedUtils.connector(pop, "id_pressed", self, sig_handler)


### Left panel event handlers

func _on_sl_movespeed_value_changed(value: float) -> void:
	pivot_rot_speed = value

func _on_bt_zeromspeed_pressed() -> void:
	pivot_rot_speed = 0.0
	lpanel.get_node("box_mspeed/sl_movespeed").value = 0.0

func _on_sl_rollspeed_value_changed(value: float) -> void:
	roll_speed = value

func _on_bt_zerorollspeed_pressed() -> void:
	if (roll_speed == 0.0):
		# Also reset the "character's" roll angle to 0 if roll_speed is already 0
		$rotator/dummy_char.rotation.z = 0.0
	
	roll_speed = 0.0
	lpanel.get_node("box_rollspeed/sl_rollspeed").value = 0.0

func _on_sl_pitchspeed_value_changed(value: float) -> void:
	pitch_speed = value
	if (value == 0.0):
		$rotator/dummy_char.rotation.x = 0.0

func _on_bt_zeropitchspeed_pressed() -> void:
	pitch_speed = 0.0
	lpanel.get_node("box_pitchspeed/sl_pitchspeed").value = 0.0
	$rotator/dummy_char.rotation.x = 0.0

func _on_arm_rotation_changed(value: float, which: int) -> void:
	match which:
		0:
			camera.rotation_degrees.x = value
		1:
			camera.rotation_degrees.y = value
		2:
			camera.rotation_degrees.z = value

func _on_arm_rotation_reset(which: int, sl: HSlider) -> void:
	match which:
		0:
			camera.rotation_degrees.x = 0.0
		1:
			camera.rotation_degrees.y = 0.0
		2:
			camera.rotation_degrees.z = 0.0
	
	sl.value = 0.0

func _on_bt_addtrauma_pressed() -> void:
	camera.add_trauma(lpanel.get_node("box_addtrauma/sl_traumaamount").value)


func _on_chk_showsmooth_toggled(pressed: bool) -> void:
	$rotator/dummy_char/Smooth3D.visible = pressed

func _on_CheckBox_toggled(pressed: bool) -> void:
	$rotator/dummy_char/unsmoothed.visible = pressed

func _on_chk_interpivot_toggled(pressed: bool) -> void:
	camera.set_interpolate_pivot(pressed)

func _on_chk_interporient_toggled(pressed: bool) -> void:
	camera.set_interpolate_orientation(pressed)


func _on_sl_physicsfps_value_changed(value: float) -> void:
	var i: int = int(value)
	Engine.iterations_per_second = i
	lpanel.get_node("box_physicsfps/lbl_fps").text = str(i)

func _on_bt_physicsreset_pressed() -> void:
	Engine.iterations_per_second = original_physics
	lpanel.get_node("box_physicsfps/sl_physicsfps").value = original_physics
	lpanel.get_node("box_physicsfps/lbl_fps").text = str(original_physics)


### Right panel event handlers

func _on_sl_armlength_value_changed(value: float) -> void:
	camera.set_arm_length(value)

func _on_bt_alengthreset_pressed() -> void:
	camera.set_arm_length(6.0)
	rpanel.get_node("box_armlength/sl_armlength").value = 6.0

func _on_lock_changed(pressed: bool, which: String) -> void:
	match which:
		"roll":
			camera.set_lock_roll(pressed)
		"pitch":
			camera.set_lock_pitch(pressed)
		"yaw":
			camera.set_lock_yaw(pressed)


func _on_cam_lag_changed(id: int) -> void:
	var s: Dictionary = lag_mode[id]
	
	rpanel.get_node("box_camlag/mnu_camlag").text = s.label
	var editable_speed: bool = false         # Assume the "no lag" option was selected
	match s.label:
		"Smooth Start", "Smooth Stop":
			editable_speed = true
	
	rpanel.get_node("box_camlag/sl_lagspeed").editable = editable_speed
	camera.set_camera_lag(s.code)

func _on_sl_camfov_value_changed(value: float) -> void:
	camera.set_fov(value)

func _on_bt_camfovreset_pressed() -> void:
	camera.set_fov(70.0)
	rpanel.get_node("box_camfov/sl_camfov").value = 70.0

func _on_cam_collision_changed(id: int) -> void:
	var c: Dictionary = coll_mode_list[id]
	
	rpanel.get_node("box_collision/mnu_collision").text = c.label
	camera.collision_mode = c.code

func _on_cam_shake_toggled(pressed: bool, which: int) -> void:
	match which:
		0:
			camera.set_shake_rotate(pressed)
		1:
			camera.set_shake_translate(pressed)

func _on_sl_shakedecay_value_changed(value: float) -> void:
	camera.trauma_decay = value

func _on_bt_shakedecayreset_pressed() -> void:
	camera.trauma_decay = 0.75
	rpanel.get_node("box_shakedecay/sl_shakedecay").value = 0.75

func _on_sl_shaketscale_value_changed(value: float) -> void:
	camera.set_shake_frequency(value)

func _on_bt_shaketscalereset_pressed() -> void:
	camera.set_shake_frequency(1.0)
	rpanel.get_node("box_timescale/sl_shaketscale").value = 1.0

func _on_max_shake_rotate(value: float, which: String) -> void:
	match which:
		"pitch":
			camera.max_shake_rotation.x = value
		"yaw":
			camera.max_shake_rotation.y = value
		"roll":
			camera.max_shake_rotation.z = value

func _on_max_rotate_reset(which: String) -> void:
	var n: String
	match which:
		"pitch":
			camera.max_shake_rotation.x = 2.0
			n = "box_mshakepitch/sl_mshakepitch"
		"yaw":
			camera.max_shake_rotation.y = 2.0
			n = "box_mshakeyaw/sl_mshakeyaw"
		"roll":
			camera.max_shake_rotation.z = 2.0
			n = "box_mshakeroll/sl_mshakeroll"
	
	rpanel.get_node(n).value = 2.0

func _on_max_translate(value: float, which: int) -> void:
	match which:
		0:
			camera.max_shake_offset.x = value
		1:
			camera.max_shake_offset.y = value
		2:
			camera.max_shake_offset.z = value

func _on_max_translate_reset(which: int) -> void:
	match which:
		0:
			camera.max_shake_offset.x = 2.0
			rpanel.get_node("box_mshakex/sl_mshakex").value = 2.0
		1:
			camera.max_shake_offset.y = 2.0
			rpanel.get_node("box_mshakey/sl_mshakey").value = 2.0
		2:
			camera.max_shake_offset.z = 2.0
			rpanel.get_node("box_mshakez/sl_mshakez").value = 2.0


func _on_opacity_changed(value: float, pnl: Panel) -> void:
	pnl.self_modulate.a8 = int(value)


func _on_bt_mmenu_pressed():
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")


