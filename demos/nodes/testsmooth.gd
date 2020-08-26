extends Spatial

# Hold the initial object states so the simulation can be reset and replayed
var initial_states: Dictionary

const pfps_label: String = "Physics FPS (%d):"
const pjitter_label: String = "Jitter Fix (%.2f):"

# Store the original physics FPS setting so it can be restored when leaving the scene
var original_physics_fps: int = 0.0

func _ready() -> void:
	# Take the original physics fps setting
	original_physics_fps = Engine.iterations_per_second
	
	# Enforce the slow physics pace
	Engine.iterations_per_second = 5
	
	initial_states = {
		# The 3D nodes
		"nsmooth3": $s3d/non_smooth.global_transform,
		"ysmooth3": $s3d/smoothed.global_transform,
		"asmooth3": $s3d/autosmoothed.global_transform,
		
		# The 2D nodes
		"nsmooth2": $s2d/non_smooth.global_transform,
		"ysmooth2": $s2d/smoothed.global_transform,
		"asmooth2": $s2d/autosmoothed.global_transform,
	}
	
	# By default hide the "ghost" of smoothed objects
	$s3d/smoothed/refmesh.visible = false
	
	# Allow the 2D smoothed objects to use the teleport feature at the correct time by
	# using the "on reset" signal. The thing is, the actual reset occur during a physics
	# update through the custom integration function. If the teleport is done at the wrong
	# time some visual anomalies will occur. Thus, a signal has been created in order to
	# tell the moment the reset has happened and give the change to perform the teleportation
	# of the smoothed nodes
	SharedUtils.connector($s2d/smoothed, "performed_reset", self, "on_rigid2d_reset", [$s2d/smoothed/Smooth2D, initial_states.ysmooth2])
	SharedUtils.connector($s2d/autosmoothed, "performed_reset", self, "on_rigid2d_asmooth_reset", [$s2d/autosmoothed/AutoInterpolate, initial_states.asmooth2])
	
	
	setup_hud()

func _exit_tree() -> void:
	# Restore the original Physics FPS setting so other demos can correctly work
	Engine.iterations_per_second = original_physics_fps


func _physics_process(_dt: float) -> void:
	$hud/pnl/lbl_fps.text = "FPS: %d" % Engine.iterations_per_second


func _on_bt_replay_pressed() -> void:
	# Yes, directly changing physics state is not recommended. In the 3D case, using Bullet Physics
	# things do work in THIS DEMO, but ideally a custom script implementing _integrate_forces()
	# must be used. That said, the 2D side of things doesn't work without the correct way, thus
	# those are using the /shared/scenes/rigid2d.gd script to perform the task
	$s3d/non_smooth.linear_velocity = Vector3()
	$s3d/non_smooth.angular_velocity = Vector3()
	$s3d/smoothed.linear_velocity = Vector3()
	$s3d/smoothed.angular_velocity = Vector3()
	$s3d/autosmoothed.linear_velocity = Vector3()
	$s3d/autosmoothed.angular_velocity = Vector3()
	
	$s3d/non_smooth.global_transform = initial_states.nsmooth3
	$s3d/smoothed.global_transform = initial_states.ysmooth3
	$s3d/autosmoothed.global_transform = initial_states.asmooth3
	
	# Even though the "can_sleep" property is set to false, ensure the rigid bodies are not sleeping
	$s3d/non_smooth.sleeping = false
	$s3d/smoothed.sleeping = false
	$s3d/autosmoothed.sleeping = false
	
	$s2d/non_smooth.reset_to(initial_states.nsmooth2)
	$s2d/smoothed.reset_to(initial_states.ysmooth2)
	$s2d/autosmoothed.reset_to(initial_states.asmooth2)
	
	# The smoothed object must be teleported
	if ($hud/pnl/chk_useteleport.pressed):
		$s3d/smoothed/Smooth3D.snap_to_target()
		$s3d/AutoInterpolate.snap_to_target()
		# The 2D objects will be "teleported" based on a signal, handled by the
		# on_rigid2d_reset() function (bellow)



func on_rigid2d_reset(s: Smooth2D, t: Transform2D) -> void:
	if ($hud/pnl/chk_useteleport.pressed):
		# Defer the call for one extra frame, to give the change of the target object to be moved
		s.call_deferred("teleport_to", t)


func on_rigid2d_asmooth_reset(s: AutoInterpolate, t: Transform2D) -> void:
	if ($hud/pnl/chk_useteleport.pressed):
		s.call_deferred("teleport_to", t)


func setup_hud() -> void:
	$hud/pnl/lbl_physicsfps.text = pfps_label % Engine.iterations_per_second
	$hud/pnl/lbl_jitterfix.text = pjitter_label % Engine.physics_jitter_fix
	$hud/pnl/sl_jitterfix.value = Engine.physics_jitter_fix
	$hud/pnl/chk_vsync.pressed = OS.vsync_enabled
	$hud/pnl/chk_showghost.pressed = $s3d/smoothed/refmesh.visible
	
	$hud/pnl/chk_show3d.pressed = $s3d.visible
	$hud/pnl/chk_show2d.pressed = $s2d.visible
	
	SharedUtils.connector($hud/pnl/sl_physicsfps, "value_changed", self, "_on_pfps_changed")
	SharedUtils.connector($hud/pnl/sl_jitterfix, "value_changed", self, "_on_jitter_changed")
	SharedUtils.connector($hud/pnl/chk_vsync, "toggled", self, "_on_vsync_toggled")
	SharedUtils.connector($hud/pnl/chk_showghost, "toggled", self, "_on_showghost_toggled")
	SharedUtils.connector($hud/pnl/chk_show3d, "toggled", self, "_on_show3d_toggled")
	SharedUtils.connector($hud/pnl/chk_show2d, "toggled", self, "_on_show2d_toggled")



func _on_pfps_changed(val: float) -> void:
	Engine.iterations_per_second = int(val)
	$hud/pnl/lbl_physicsfps.text = pfps_label % Engine.iterations_per_second

func _on_jitter_changed(val: float) -> void:
	Engine.physics_jitter_fix = val
	$hud/pnl/lbl_jitterfix.text = pjitter_label % Engine.physics_jitter_fix

func _on_vsync_toggled(pressed: bool) -> void:
	OS.vsync_enabled = pressed

func _on_showghost_toggled(pressed: bool) -> void:
	$s3d/smoothed/refmesh.visible = pressed
	$s2d/smoothed/refsprite.visible = pressed
	$s2d/autosmoothed/refsprite.visible = pressed

func _on_show3d_toggled(pressed: bool) -> void:
	$s3d.visible = pressed

func _on_show2d_toggled(pressed: bool) -> void:
	$s2d.visible = pressed

func _on_chk_enable2d_toggled(pressed: bool) -> void:
	$s2d/smoothed/Smooth2D.enabled = pressed

func _on_chk_enable3d_toggled(pressed: bool) -> void:
	$s3d/smoothed/Smooth3D.enabled = pressed



func _on_bt_back_pressed():
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")

