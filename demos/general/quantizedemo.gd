# This demo is meant to focus on the keh_general/data/quantize.gd addon
# The idea here is to use quaternion quantization to coompress it using the smallest three
# method, which basically drops the largest component and quantize the rest of them into
# an smaller number of bits. This method only works for rotation quaternions.
# To test things, a cube is used to "generate" the orientation, which will then be
# compressed and immediately uncompressed to be applied into a secondary cube
#
# Important note: In the code bellow, two orientations are "replicated" to the "secondary"
# cube. One for the "pivot" point and the other is the cube itself. This is done because
# part of the motion performed here is done directly into the pivot point while the other
# part is on the cube. The idea here is to deal only with the orientations and "forget" the
# translation. However, it is possible to deal with the global orientation of the cubes in
# order to avoid having to deal with two compression/decompression operations. In that case
# the translation has be taken into account. To keep the separation of "left cube" and
# "right cube" the X coordinate of the right cube (the replicated one) must be flipped in
# comparison to the one from the left cube.

extends Spatial

var pivot_yrotation: float = -1.5        # Negative value for clockwise rotation
var pivot_zrotation: float = 45.0

var cube_xrotation: float = 2.0


var _pivot_zstate: float = 0.0
var _pivot_zdir: float = 1.0

func _ready() -> void:
	_setup_hud()



func _physics_process(dt: float) -> void:
	_pivot_zstate += pivot_zrotation * dt * _pivot_zdir
	
	if (_pivot_zstate >= 45.0):
		_pivot_zdir = -1.0
	elif (_pivot_zstate <= -45.0):
		_pivot_zdir = 1.0
	
	$source.rotation.y += pivot_yrotation * dt
	$source.rotation.z = deg2rad(_pivot_zstate)
	
	$source/cube.rotation.x += cube_xrotation * dt
	
	if ($hud/pnl/chk_9bits.is_pressed()):
		simulate_replication_9bits()
	elif ($hud/pnl/chk_10bits.is_pressed()):
		simulate_replication_10bits()
	elif ($hud/pnl/chk_15bits.is_pressed()):
		simulate_replication_15bits()


func simulate_replication_9bits() -> void:
	# First replicate the pivot orientation
	var pivq: Quat = Quat($source.transform.basis)
	# Quantize it using 9 bits per component
	var pivc: int = Quantize.compress_rquat_9bits(pivq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restpivq: Quat = Quantize.restore_rquat_9bits(pivc)
	# Apply to the replicated pivot
	$replicated.transform.basis = Basis(restpivq)
	
	# Take the source cube orientation
	var srccubeq: Quat = Quat($source/cube.transform.basis)
	# Quantize it using 9 bits per component
	var srccubec: int = Quantize.compress_rquat_9bits(srccubeq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restcubeq: Quat = Quantize.restore_rquat_9bits(srccubec)
	# Apply the restored orientantion to the "replicated" cube
	$replicated/cube.transform.basis = Basis(restcubeq)


func simulate_replication_10bits() -> void:
	# First replicate the pivot orientation
	var pivq: Quat = Quat($source.transform.basis)
	# Quantize it using 9 bits per component
	var pivc: int = Quantize.compress_rquat_10bits(pivq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restpivq: Quat = Quantize.restore_rquat_10bits(pivc)
	# Apply to the replicated pivot
	$replicated.transform.basis = Basis(restpivq)
	
	
	# Take the source cube orientation
	var srccubeq: Quat = Quat($source/cube.transform.basis)
	# Quantize it using 10 bits per component
	var srccubc: int = Quantize.compress_rquat_10bits(srccubeq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restcubeq: Quat = Quantize.restore_rquat_10bits(srccubc)
	# Apply the restored orientation to the replicated cube
	$replicated/cube.transform.basis = Basis(restcubeq)


func simulate_replication_15bits() -> void:
	# First replicate the pivot orientation
	var pivq: Quat = Quat($source.transform.basis)
	# Quantize it using 9 bits per component
	var pivc: PoolIntArray = Quantize.compress_rquat_15bits(pivq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restpivq: Quat = Quantize.restore_rquat_15bits(pivc[0], pivc[1])
	# Apply to the replicated pivot
	$replicated.transform.basis = Basis(restpivq)
	
	# Take the source cube orientation
	var srccubeq: Quat = Quat($source/cube.transform.basis)
	# Quantize it using 15 bits per component
	var srccubec: PoolIntArray = Quantize.compress_rquat_15bits(srccubeq)
	# Restore the quaternion (as it would be done on a remote machine, for example)
	var restcubeq: Quat = Quantize.restore_rquat_15bits(srccubec[0], srccubec[1])
	# Apply the restored orientation to the replicated cube
	$replicated/cube.transform.basis = Basis(restcubeq)



func _setup_hud() -> void:
	$hud/pnl/sl_pivyrot.value = pivot_yrotation
	$hud/pnl/sl_pivzrot.value = pivot_zrotation
	$hud/pnl/sl_cubexrot.value = cube_xrotation
	
	SharedUtils.connector($hud/pnl/sl_pivyrot, "value_changed", self, "_on_pivoty_changed")
	SharedUtils.connector($hud/pnl/sl_pivzrot, "value_changed", self, "_on_pivotz_changed")
	SharedUtils.connector($hud/pnl/sl_cubexrot, "value_changed", self, "_on_cubex_changed")


func _on_pivoty_changed(val: float) -> void:
	pivot_yrotation = val

func _on_pivotz_changed(val: float) -> void:
	pivot_zrotation = val

func _on_cubex_changed(val: float) -> void:
	cube_xrotation = val


func _on_bt_back_pressed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")

