# This is the base class for (3D) player characters. This base only contains
# the functionality. The actual shape is given by the inherited scenes.

# Player characters, in this demo, are dynamically spawned through the
# networking system, which appends a meta data named "uid". In this specific
# case, the unique id for player characters correspond to the network ID. Take
# that in mind when reading the code.

extends KinematicBody
class_name p3dchar

signal stamina_changed(pid, newval)

# The local player needs a camera, so hold a preloaded packed scene for that
const camera_class: PackedScene = preload("res://addons/keh_nodes/cam3d/cam3d.tscn")
# And this will hold the camera node itself
var _camera_ref: Cam3D = null

# When moving the character with "move_and_slide()", a vector indicating the
# floor normal is necessary. Just point "up" and that's it
const _floor_normal: Vector3 = Vector3.UP

# Gravity is necessary in order to keep the character on the ground, so hold
# its magnitude
const gravity: float = 9.81

# Hold accumulated velocity through each physics iteration
var net_velocity: Vector3 = Vector3()

# This flag indicates if the character can jump
var _can_jump: bool = false

# The amount of time between firing one bullet and another. The lower this
# value, the faster the character will be able to shoot
export var shoot_interval: float = 0.3

var _shoot_timer: float = 0.0

# How fast stamina will decay while sprinting
export var stamina_decay: float = 0.1

# How fast stamina will recover while not sprinting
export var stamina_recover: float = 0.2

# Holds current stamina value
var current_stamina: float = 1.0


# This will be used to calculate the initial vertical velocity in order to
# reach the jump height in this property
export var desired_jump_height: float = 1.5

# Initial vertical velocity to reach the desired jump height. This is
# calculated based on the desired_jump_height property
onready var _jump_v0: float = calculate_jump()

# Movement speed of the character
export var move_speed: float = 9.0
# Multiplier of the move_speed when sprinting
export var sprint_mult: float = 1.8

# Ideally this should be part of an autoload script (singleton) and be given as
# a setting to the player. Just to simplify the entire demo project, holding
# this value here
var _mouse_sensitivity: Vector2 = Vector2(0.45, 0.5)

# Keep track of the pitch angle - this will be changed whe moving the mouse
var net_pitch_angle: float = 0.0

# This will be shown within the OverlayDebugInfo. In this demo, pressing F10 will show (unhide) the panel
var DEBUG_correction_count: int = 0

# When correction that is received, if directly applied, chances are big that
# the new state will be visually shown before there is any chance to replay the
# input objects. This will result in a very glitchy experience. To that end,
# correction data is actually stored within this dictionary, which will be used
# within the next physics_process iteration. A flag indicates if the data must
# be used or not.
var _correction_data: Dictionary

# Cache UID - as retrieved from the meta
var _uid: int = 0


var net_effects: PoolByteArray = PoolByteArray()

func _ready() -> void:
	# If meta is not present assume this belongs to the server
	_uid = get_meta("uid") if has_meta("uid") else 1
	set_meta("uid",_uid)
	
	# Local player character needs a camera. So, check if this is the object
	# belongs to the local player and, if so, create the camera
	if (_uid > 0 && network.is_id_local(_uid)):
		_camera_ref = camera_class.instance()
		
		#add_child(_camera_ref)
		$cam_attach_point.add_child(_camera_ref)
		_camera_ref.set_arm_length(8.0)
		_camera_ref.set_current(true)
		# If the pivot point is not interpolated then the visual representation
		# of the character will seem "jumpy"
		_camera_ref.set_interpolate_pivot(true)
		_camera_ref.set_interpolate_orientation(true)
		
		# Also, capture the mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	# Initialize the correction data dictionary
	_correction_data = {
		"transform": global_transform,
		"velocity": net_velocity,
		"angle": net_pitch_angle,
		"stamina": 1.0,
		"corrected": false,
	}

var net_transform: Transform
var net_stamina: float
var net_corrected: bool

func _physics_process(_dt: float) -> void:
	# Verify if there is any correction to be performed
	if (net_corrected):
		DEBUG_correction_count += 1
		# Reset the flag otherwise this "correction" may be played again
		# and will result in errors
		net_corrected = false
		
		# Apply the correct state 
		global_transform = net_transform
#		_velocity = _correction_data.velocity
#		_pitch_angle = _correction_data.angle
		current_stamina = net_stamina
#		_effects = _correction_data.effects
		
		# Replay the input objects within internal history if this character belongs
		# to the local player
		if (network.is_id_local(_uid)):
			var inlist: Array = network.player_data.local_player.get_cached_input_list()
			for i in inlist:
				handle_input(i)
				network.correct_in_snapshot(self, i)
				OverlayDebugInfo.set_label("correct_count", "Correction Count: %s" % DEBUG_correction_count)
	
	
	var mvisible: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE
	var input: InputData = null
	# If this is local machine and mouse is not captured (visible) then no input
	# should be gathered. Yet the input handling function must still be called in
	# order to keep the character updated (maybe something is happening and affecting
	# it - remember, multiplayer should not be paused)
	if (network.is_id_local(_uid) && mvisible):
		input = InputData.new(0)
	else:
		# Request input data using the networking system. The argument tells which player
		# this data must match. Null will be returned if this machine is not meant to
		# deal with input.
		input = network.get_input(_uid)
	
	
	# Do something with the new input data
	handle_input(input)
	
	# Snapshot this entity
	network.snapshot_entity(self)
	
	# Even if the value hasn't changed this will ensure the HUD can stay updated
	emit_signal("stamina_changed", _uid, current_stamina)
	
	
	# Output to the overlay the effects
	var msg: String = "Player %s, effects:" % _uid
	for e in net_effects:
		msg += " " + str(e)
	OverlayDebugInfo.set_label("p%s_effects" % _uid, msg)



# The snapshot entity object representing player characters (instances of
# MegaSnapPCharacter) will call this function when the state must be applied
func apply_state(state: Dictionary) -> void:
	_correction_data.corrected = true
	_correction_data.transform = Transform(Basis(state.orientation), state.position)
	_correction_data.velocity.y = state.vertical_vel
	_correction_data.angle = state.angle
	_correction_data.stamina = state.stamina
	_correction_data.effects = state.effects



func handle_input(input: InputData) -> void:
	if (!input):
		return
	
	var dt: float = get_physics_process_delta_time()
	var move_dir: Vector3 = Vector3()
	var jump_pressed: bool = input.is_pressed("jump")
	var speed: float = move_speed
	
	if (input.is_pressed("sprint")):
		if (current_stamina > 0):
			current_stamina = max(current_stamina - (stamina_decay * dt), 0.0)
			speed *= sprint_mult
	else:
		current_stamina = min(current_stamina + (stamina_recover * dt), 1.0)
	
	if (_shoot_timer > 0.0):
		_shoot_timer = max(_shoot_timer - dt, 0.0)
	
	
	# Reset floor movement - that is, ensure character does not move as a result
	# of the slide from the previous update
	net_velocity.x = 0.0
	net_velocity.z = 0.0
	
	# First deal with mouse relative input data as it may change orientation
	var relative: Vector2 = input.get_mouse_relative()
	
	if (relative.x != 0.0):
		rotate_y(deg2rad(-relative.x * _mouse_sensitivity.x))
		orthonormalize()
	
	if (relative.y != 0.0):
		var change: float = relative.y * _mouse_sensitivity.y
		net_pitch_angle = clamp(net_pitch_angle + change, -40, 70)
		if (_camera_ref):
			_camera_ref.rotation.x = deg2rad(net_pitch_angle)
	
	# Movement input
	var aim: Basis = get_global_transform().basis
	
	move_dir -= aim.z * input.get_analog("move_forward")
	move_dir += aim.z * input.get_analog("move_backward")
	move_dir -= aim.x * input.get_analog("move_left")
	move_dir += aim.x * input.get_analog("move_right")
	
	# Jump input
	if (_can_jump && jump_pressed):
		move_dir.y = _jump_v0
		_can_jump = false
	
	# Clamp the "horizontal plane of the move_dir" so the character doesn't go
	# faster than the desired speed. But still allow slower movement based on
	# analog input data.
	var sqa: float = move_dir.x * move_dir.x
	var sqb: float = move_dir.z * move_dir.z
	
	if (sqa + sqb > 1.0):
		# If here then the vector's magnitude is bigger than the desired maximum
		# speed, so it must be scaled down
		var s: float = 1.0 / sqrt(sqa + sqb)
		speed *= s
	
	move_dir.x *= speed
	move_dir.z *= speed
	
	# Integrate gravity. IN 3D, negative Y is down
	net_velocity.y -= (gravity * dt)
	
	# Apply input to the velocity
	net_velocity += move_dir
	
	# Perform the movement. One thing to keep in mind is the last argument of the
	# move_and_slide() function, which enables/disables infinite inertia. It
	# must be false in order for kinematic bodies to correctly collide with
	# rigid bodies.
	net_velocity = move_and_slide(net_velocity, _floor_normal, false, 4, 0.785398, false)
	
	# Cache the "on_floor" state so in the next frame the jump button can be
	# directly used
	_can_jump = is_on_floor() && !jump_pressed
	
	# While projectiles are create only on the server and spawned on clients through
	# the replication system, it would be a good idea to play an animation on clients
	# to let them know the input has been processed by their game.
	# In that case the client also must count the time between each allowed shooting.
	# This is not being done in this demo, at least not for now.
	if (input.is_pressed("shoot") && network.has_authority()):
		shoot()


func shoot() -> void:
	if (!network.has_authority()):
		return
	
	# While ideally new nodes should be spawned only on the server and use the
	# replication system to do this task on clients, projectiles may be a bit
	# too fast to rely on that in the sense that often the projectile will appear
	# on the client only when nearing destruction
	
	if (_shoot_timer > 0.0):
		# A projectile has been fired and the time before another can be fired
		# has not been elapsed.
		return
	
	_shoot_timer = shoot_interval
	
	var projid: int = network.get_incrementing_id("glow_projectile")
	
	var position_node: Position3D = $projectile_source
	
	# Spawn the projectile and set its state - last argument, class_hash is not
	# needed in this demo since there aren't different types of projectiles.
	var bullet: Node = network.snapshot_data.spawn_node(GlowProjectile, projid, 0)
	bullet.init(position_node.global_transform)
	# Apply the correct pitch
	bullet.rotation.x = deg2rad(net_pitch_angle)
	
	# Set a random number of effects (between 0 and 5). Please note that in here the effects array will be
	# completely rewritten just to test the replication of the arrays.
	var ne: int = randi() % 6
	net_effects = PoolByteArray()
	for _i in ne:
		net_effects.append(randi() % 51)



func calculate_jump() -> float:
	return sqrt(2.0 * gravity * desired_jump_height)


# This function is used to create the snapshot entity object representing player
# characters within the snapshots
#func create_snapentity_object() -> MegaSnapPCharacter:
#	assert(has_meta("uid"))
#	assert(has_meta("chash"))
#
#	var uid: int = get_meta("uid")
#	var chash: int = get_meta("chash")
#
#	var e: MegaSnapPCharacter = MegaSnapPCharacter.new(uid, chash)
#	e.position = global_transform.origin
#	e.set_orientation(Quat(global_transform.basis))
##	e.velocity = _velocity
#	e.vertical_vel = _velocity.y
#	e.pitch_angle = _pitch_angle
#	e.stamina = current_stamina
#	e.effects = _effects
#
#	return e

