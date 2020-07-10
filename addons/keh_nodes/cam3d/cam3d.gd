###############################################################################
# Copyright (c) 2019 Yuri Sarudiansky
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

# TODO: If possible, "X-Ray" effect as collision mode
# TODO: Obstructing objects get a level of transparency rather than completely hidden
# TODO: Shaped ray casts during the collision detection

tool      # Marking this as tool script so the camera can be previewed within the editor
extends Position3D
class_name Cam3D

const FLR_ROLL: int = 1                # Flag lock rotation - roll
const FLR_PITCH: int = 1 << 1          # Flag lock rotation - pitch
const FLR_YAW: int = 1 << 2            # Flag lock rotation - yaw
const ALL_LOCK: int = FLR_ROLL | FLR_PITCH | FLR_YAW

const FSM_ROTATE: int = 1              # Flag shake mode - rotate
const FSM_TRANSLATE: int = 1 << 1      # Flag shake mode - translate


# While the pivot point can smoothly follow the parent node, the camera itself can lag
# behind the "arm". This enum allows selection of how this lag will occur (if at all).
# The lag follows the smoothing technique described by Squirrel Eiserloh in his GDC
# talk called Juicing Your Camera With Math.
enum CameraLag {
	None,              # Camera will be snapped to the "arm"
	SmoothStop,        # Use asymptotic averaging while following the pivot
	SmoothStart,       # Invert the SmoothStop
}

# This enum specifies what should be done if there is something between the camera and
# the pivot point. Mostly, the "collision" is detected by casting a dynamic ray from
# the pivot point towards the camera
enum CollisionMode {
	# Nothing will be done and objects will potentially block camera view
	None,
	
	# The arm length will be reduced, potentially placing the camera closes to the pivot
	# point. The configured length will be restored if there is no object between the camera
	# and the attachment point.
	ShrinkArm,
	
	# Cull objects that are in between by manipulating the near plane of the camera. A possibly
	# interesting side effect of this method is the fact that some object may only be partially
	# culled which may even be desireable on some projects.
	CullObstructing,
	
	# Completely hide objects that in direct path between the camera and the pivot point.
	# Avoid using this method on multiplayer games as depending on how the synchronization is
	# done may result in objects being hidden for everyone or even removed from the game.
	# BUG: In Godot 3.1 procedural generated objects (CSG nodes) hidden in this way will
	# trigger a bunch of errors
	HideObstructing,
}

# How far away from the pivot the camera will be
export var arm_length: float = 8.5 setget set_arm_length
# Should any camera rotation be locked?
export(int, FLAGS, "Roll", "Pitch", "Yaw") var lock_rotation: int = FLR_ROLL | FLR_PITCH
# If enabled the pivot point will be interpolated to smoothly follow the parent node
export var interpolate_pivot: bool = false setget set_interpolate_pivot
# If enabled the camera orientation will be interpolated. This sometimes may not look good
export var interpolate_orientation: bool = false setget set_interpolate_orientation
# Determine the camera lag
export(CameraLag) var camera_lag: int = CameraLag.None setget set_camera_lag
# If camera_lag is different than None, specify the smooth weight
export(float, 0.001, 1.0, 0.001) var lag_speed: float = 0.1 setget set_lag_speed

# Collision response
export(CollisionMode) var collision_mode: int = CollisionMode.ShrinkArm

# Collision layer. That is, which layer(s) will be used when trying to detect what is
# in between the camera and the target/pivot
export(int, FLAGS,
	"Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5",
	"Layer 6", "Layer 7", "Layer 8", "Layer 9", "Layer 10",
	"Layer 11", "Layer 12", "Layer 13", "Layer 14", "Layer 15",
	"Layer 16", "Layer 17", "Layer 18", "Layer 19", "Layer 20") var collision_layers: int = 0x7FFFFFFF

# When adding trauma (shake), which kinds of perturbations will be added to the camera
export(int, FLAGS, "Rotate", "Translate") var shake_mode: int = FSM_ROTATE
# How fast trauma will decay over time. Amount that will be subtract from trauma each second
export var trauma_decay: float = 0.75 setget set_trauma_decay
# Determines the frequency of the shake
export var shake_frequency: float = 1.0 setget set_shake_frequency
# Determine the maximum rotation during shake (pitch, yaw, roll)
export var max_shake_rotation: Vector3 = Vector3(2.0, 2.0, 2.0)
# Determine the maximum translation during shake
export var max_shake_offset: Vector3 = Vector3(1.0, 1.0, 1.0)

### In order to change the camera settings without changing the cam3d.tscn, those properties
### are given. Through the setget the settings can be set in the $camera node. Trying to
### follow the same order in which the properties appear on the camera. Note that some are
### not exposed.

export(int, "Keep Width", "Keep Height") var keep_aspect: int = 1 setget set_keep_aspect_mode
# skipping cull_mask since exporting a bit flag like that does not result very well
export var environment: Environment = null setget set_environment
export var h_offset: float = 0.0 setget set_h_offset
export var v_offset: float = 0.0 setget set_v_offset
export(int, "Disabled", "Idle", "Physics") var doppler_tracking: int = 0 setget set_doppler_tracking
export(int, "Perspective", "Orthogonal") var projection: int = 0 setget set_projection
export var current: bool = false setget set_current
export(float, 1, 179, 0.1) var fov: float = 70.0 setget set_fov
export(float) var near: float = 0.05 setget set_znear
export(float) var far: float = 100.0 setget set_zfar

### Using internal classes instead of dictionaries for the easier coding.
### Those bring code completion and early errors

# Hold data necessary for interpolation. Internally the pivot point (Cam3D root) will be
# snapped to its parent. However the reference point used to move the camera backwards
# will be interpolated if pivot_mode is set to PivotMode.Interpolated
class InterpData:
	var pivot_from: Vector3             # Pivot initial location
	var pivot_to: Vector3               # Pivot final location
	var had_physics: bool               # Flag indicating if physics happened
	var cam_rotfrom: Basis              # Camera rotation from
	var cam_rotto: Basis                # Camera rotation to
	var cam_pos: Vector3                # Camera position - mostly for the lag system
	
	func _init(pos: Vector3, camrot: Basis, l: float) -> void:
		pivot_from = pos
		pivot_to = pos
		had_physics = false
		cam_rotfrom = camrot
		cam_rotto = camrot
		cam_pos = pos + (camrot.z * l)

# This holds data for the camera shake state
class ShakeState:
	var noise: OpenSimplexNoise
	var trauma: float
	var time: float
	
	func _init() -> void:
		noise = OpenSimplexNoise.new()
		noise.seed = randi()
		noise.octaves = 4
		noise.period = 1.0
		noise.persistence = 1.0
		trauma = 0.0
		time = 0.0


# The interpolation data object
var _interpolation: InterpData
# Shake data
var _shake: ShakeState
# Objects obstructing camera view, from the previous frame
var _obstructing: Array = []

# Keep a copy of the camera node
onready var _camnode: Camera = $camera

func _ready() -> void:
	_interpolation = InterpData.new(global_transform.origin, _get_cam_basis(), arm_length)
	_shake = ShakeState.new()



func _process(dt: float) -> void:
	var pivotpos: Vector3 = global_transform.origin if !_interpolation else _interpolation.pivot_to
	var cambasis: Basis = _get_cam_basis() if !_interpolation else _interpolation.cam_rotto
	
	# 'campos' is meant to hold the desired camera position. It will be further manipulated based
	# on the various settings of the camera
	var forward: Vector3 = -cambasis.z
	var campos: Vector3 = pivotpos - (forward * arm_length)
	
	if (_interpolation):
		if (interpolate_pivot || interpolate_orientation):
			if (_interpolation.had_physics):
				_cycle_interp()
				_interpolation.had_physics = false
			
			var alpha: float = Engine.get_physics_interpolation_fraction()
			if (interpolate_pivot):
				pivotpos = _interpolation.pivot_from.linear_interpolate(_interpolation.pivot_to, alpha)
			if (interpolate_orientation):
				cambasis = _interpolation.cam_rotfrom.slerp(_interpolation.cam_rotto, alpha)
			
			# Pivot and/or camera basis have been modified (interpolated). Must recalculate the
			# desired location
			forward = -cambasis.z
			campos = pivotpos - (forward * arm_length)
		
		match camera_lag:
			CameraLag.SmoothStop:
				# Again, asymptotic averaging
				_interpolation.cam_pos += (campos - _interpolation.cam_pos) * lag_speed
				campos = _interpolation.cam_pos
			
			CameraLag.SmoothStart:
				# This is the inverse of the SmoothStop
				var weight: float = 1 - lag_speed
				weight = 1 - (weight * weight)
				_interpolation.cam_pos += (campos - _interpolation.cam_pos) * weight
				campos = _interpolation.cam_pos
	
	# A few things here:
	# - The ray cast is meant to manipulate the camera settings according to the actual locations,
	# that is, the interpolated values (if using that). The documentation says to not access the
	# direct space state outside of the _physics_process because it may be locked in a multi-threaded
	# setup. Keeping the ray cast at the physics process will look really terrible, mostly because
	# it forces to perform the ray casts on non interpolated (visual) states and will be "choppy"
	# - For 3D there isn't a setting to enable/disable thread physics mode.
	# - The only goal here is to detect if the camera view is being obstructed or not and not
	# change the actual physical space. To that end, performing the ray cast from the _process()
	# and hope everything will continue to work!
	# - Well, the HideObstructing mode does change the actual physical state by hiding objects so
	# it will not be handled here and only from the _physics_process()
	if (collision_mode != CollisionMode.None):
		var dspace: PhysicsDirectSpaceState = get_world().get_direct_space_state()
		var ignore: Array = [get_parent()]
		
		if (dspace):
			match collision_mode:
				CollisionMode.ShrinkArm:
					var coll: Dictionary = dspace.intersect_ray(pivotpos, campos, ignore, collision_layers)
					
					if (coll.size() > 0):
						campos = coll.position
				
				CollisionMode.CullObstructing:
					var coll: Dictionary = dspace.intersect_ray(pivotpos, campos, ignore, collision_layers)
					
					if (coll.size() > 0):
						# Move the near plane of the camera to the first collision point
						_camnode.set_znear((campos - coll.position).length())
					else:
						# Restore to the desired setting
						_camnode.set_znear(near)
	
	var cam_t: Transform = Transform(cambasis, campos)
	$camera.global_transform = cam_t
	
	# Add perturbation (shake) after setting the camera - using simplex noise to achieve "smoother shaking"
	if (_shake && _shake.trauma > 0.0):
		var noisey: float = _shake.time * shake_frequency
		
		if (shake_mode & FSM_ROTATE):
			var dpitch: float = deg2rad(max_shake_rotation.x * _shake.trauma * _shake.noise.get_noise_2d(0, noisey))
			var dyaw: float = deg2rad(max_shake_rotation.y * _shake.trauma * _shake.noise.get_noise_2d(1, noisey))
			var droll: float = deg2rad(max_shake_rotation.z * _shake.trauma * _shake.noise.get_noise_2d(2, noisey))
			
			_camnode.rotation += Vector3(dpitch, dyaw, droll)
		
		if (shake_mode & FSM_TRANSLATE):
			var offx: float = max_shake_offset.x * _shake.trauma * _shake.noise.get_noise_2d(3, noisey)
			var offy: float = max_shake_offset.y * _shake.trauma * _shake.noise.get_noise_2d(4, noisey)
			var offz: float = max_shake_offset.z * _shake.trauma * _shake.noise.get_noise_2d(5, noisey)
			
			_camnode.global_transform.origin += Vector3(offx, offy, offz)
		
		_shake.trauma = clamp(_shake.trauma - (trauma_decay * dt), 0.0, 1.0)
		_shake.time += dt




func _physics_process(_dt: float) -> void:
	if (_interpolation):
		# Deal with the case of multiple physics ticks between "normal frames"
		if (_interpolation.had_physics):
			_cycle_interp()
		
		_interpolation.had_physics = true
	
	# Objects that were hidden in a previous frame may not be obstructing the view
	# anymore, but since they are hidden the ray cast will ignore those. So, restore
	# their visibility prior to the casts. Do this regardless of the collision mode
	# set as if it's changed during the game some objects may stay hidden, which
	# obviously is not desireable
	_restore_hidden()
	
	if (collision_mode == CollisionMode.HideObstructing):
		var dspace: PhysicsDirectSpaceState = get_world().get_direct_space_state()
		var ignore: Array = [get_parent()]
		var campos: Vector3 = _camnode.global_transform.origin
		var pivot: Vector3 = global_transform.origin
		
		# Cast rays, hiding anything that is hit, until no object is in between the
		# camera and the pivot point
		var done: bool = false
		while (!done):
			var coll: Dictionary = dspace.intersect_ray(pivot, campos, ignore, collision_layers)
			
			if (coll.size() > 0):
				_obstructing.push_back(coll.collider)
				ignore.push_back(coll.collider)
				coll.collider.hide()
			else:
				done = true


func get_camera() -> Camera:
	return _camnode


func add_trauma(amount: float) -> void:
	assert(_shake)
	_shake.trauma = clamp(_shake.trauma + amount, 0.0, 1.0)

func get_trauma() -> float:
	assert(_shake)
	return _shake.trauma

func stop_shake() -> void:
	assert(_shake)
	_shake.trauma = 0.0


func _get_cam_basis() -> Basis:
	# This function is meant to return the desired orientation Basis to be applied
	# to the $camera node. This is based on the lock_rotation flags property
	match lock_rotation:
		0:
			# No locked axis - use global transform
			return global_transform.basis
		
		ALL_LOCK:
			# All axes are locked - use local transform
			return transform.basis
		
		_:
			# Must combine global and local transforms
			var re: Vector3 = global_transform.basis.get_euler()
			var le: Vector3 = transform.basis.get_euler()
			
			if (lock_rotation & FLR_ROLL):
				re.z = le.z
			if (lock_rotation & FLR_PITCH):
				re.x = le.x
			if (lock_rotation & FLR_YAW):
				re.y = le.y
			
			return Basis(re)


func _cycle_interp() -> void:
	_interpolation.pivot_from = _interpolation.pivot_to
	_interpolation.pivot_to = global_transform.origin
	_interpolation.cam_rotfrom = _interpolation.cam_rotto
	_interpolation.cam_rotto = _get_cam_basis()


func _restore_hidden() -> void:
	for obj in _obstructing:
		obj.show()
	_obstructing.clear()


### Setters/Getters

func set_arm_length(l: float) -> void:
	arm_length = max(l, 0.0)

func set_interpolate_pivot(e: bool) -> void:
	interpolate_pivot = e
	if (_interpolation && e):
		_interpolation.pivot_from = global_transform.origin
		_interpolation.pivot_to = global_transform.origin
		_interpolation.cam_rotfrom = _get_cam_basis()
		_interpolation.cam_rotto = _interpolation.cam_rotfrom

func set_interpolate_orientation(e: bool) -> void:
	interpolate_orientation = e
	if (_interpolation && e):
		_interpolation.pivot_from = global_transform.origin
		_interpolation.pivot_to = global_transform.origin
		_interpolation.cam_rotfrom = _get_cam_basis()
		_interpolation.cam_rotto = _interpolation.cam_rotfrom

func set_camera_lag(cl: int) -> void:
	camera_lag = cl if (cl >= 0 && cl <= 3) else CameraLag.None

func set_lag_speed(ls: float) -> void:
	lag_speed = ls


func set_collision_layer(enable: bool, layer_index: int) -> void:
	assert(layer_index > 0 && layer_index <= 20)
	var mask: int = 1 << (layer_index - 1)
	if (enable):
		collision_layers |= mask
	else:
		collision_layers &= (~mask)

func is_collision_layer_enabled(layer_index: int) -> bool:
	assert(layer_index > 0 && layer_index <= 20)
	var mask: int = 1 << (layer_index - 1)
	return (collision_layers & mask != 0)




func set_shake_rotate(enabled: bool) -> void:
	if (enabled):
		shake_mode |= FSM_ROTATE
	else:
		shake_mode &= ~FSM_ROTATE

func is_shake_rotate_enabled() -> bool:
	return (shake_mode & FSM_ROTATE) == FSM_ROTATE

func set_shake_translate(enabled: bool) -> void:
	if (enabled):
		shake_mode |= FSM_TRANSLATE
	else:
		shake_mode &= ~FSM_TRANSLATE

func is_shake_translate_enabled() -> bool:
	return (shake_mode & FSM_TRANSLATE) == FSM_TRANSLATE

func set_trauma_decay(td: float) -> void:
	trauma_decay = td

func set_shake_frequency(s: float) -> void:
	shake_frequency = max(0.1, s)


func set_lock_pitch(enabled: bool) -> void:
	if (enabled):
		lock_rotation |= FLR_PITCH
	else:
		lock_rotation &= ~FLR_PITCH

func is_pitch_locked() -> bool:
	return (lock_rotation & FLR_PITCH) == FLR_PITCH

func set_lock_yaw(enabled: bool) -> void:
	if (enabled):
		lock_rotation |= FLR_YAW
	else:
		lock_rotation &= ~FLR_YAW

func is_yaw_locked() -> bool:
	return (lock_rotation & FLR_YAW) == FLR_YAW

func set_lock_roll(enabled: bool) -> void:
	if (enabled):
		lock_rotation |= FLR_ROLL
	else:
		lock_rotation &= ~FLR_ROLL

func is_roll_locked() -> bool:
	return (lock_rotation & FLR_ROLL) == FLR_ROLL



func set_keep_aspect_mode(m: int) -> void:
	keep_aspect = m if (m >= 0 && m <= 1) else 1
	if (_camnode):
		_camnode.set_keep_aspect_mode(keep_aspect)

func set_environment(env: Environment) -> void:
	environment = env
	if (_camnode):
		_camnode.set_environment(env)

func set_h_offset(o: float) -> void:
	h_offset = o
	if (_camnode):
		_camnode.set_h_offset(o)

func set_v_offset(o: float) -> void:
	v_offset = o
	if (_camnode):
		_camnode.set_v_offset(o)

func set_doppler_tracking(d: int) -> void:
	doppler_tracking = d if (d >= 0 && d <= 2) else 0
	if (_camnode):
		_camnode.set_doppler_tracking(doppler_tracking)

func set_projection(p: int) -> void:
	projection = p if (p >= 0 && p <= 1) else 0
	if (_camnode):
		_camnode.set_projection(projection)

func set_current(c: bool) -> void:
	current = c
	if (_camnode):
		_camnode.set_current(c)

func set_fov(f: float) -> void:
	fov = clamp(f, 1, 179.0)
	if (_camnode):
		_camnode.set_fov(fov)

func set_znear(n: float) -> void:
	near = max(0.01, n)
	if (_camnode):
		_camnode.set_znear(near)

func set_zfar(f: float) -> void:
	far = max(0.01, f)
	if (_camnode):
		_camnode.set_zfar(far)
