extends KinematicBody
class_name GlowProjectile

# Destroy itself after 4 seconds
const TIME_TO_LIVE: float = 4.0
const SPEED: float = 55.0

# Keep track of how long this bullet has lived
var _time_alive: float = 0.0

# If true, the projectile hit something
var _hit: bool = false

# And if there is an impact, this indicate the location
var _impact_position: Vector3 = Vector3()

# Cache the unique ID
var _uid: int = 0

# These variables hold correction data so it is applied only during physics
# process. This should avoid some jittery movement
var net_position: Vector3
var net_orientation: Quat
var net_has_correction: bool

func _ready() -> void:
	
	_uid = get_meta("uid") if has_meta("uid") else 0
	# just in case
	set_meta("uid",_uid)

func _process(dt: float) -> void:
	# The following will update the internal timer and force despawning of the
	# projectile if it reaches its maximum alive time. This is safe to be
	# done regardless if server or client
	_time_alive += dt
	if (_time_alive >= TIME_TO_LIVE):
		if (_uid > 0):
			network.snapshot_data.despawn_node(get_script(), _uid)


func _physics_process(dt: float) -> void:
	if (is_queued_for_deletion()):
		return
	
	if (_hit):
		# Force despawning since the projectile did hit something and the previous
		# test didn't indicate this node is queued for removal
		network.snapshot_data.despawn_node(get_script(), _uid)
	
	if (net_has_correction):
		global_transform = Transform(Basis(net_orientation), net_position)
		net_has_correction = false
		
		# Re-simulate the projectile the number of times client predicted this after server data was used
		# to trigger the correction
		for _i in network.snapshot_data.get_prediction_count(_uid, get_script()):
			_simulate(dt)
		
		$Smooth3D.snap_to_target()
	
	_simulate(dt)
	
	# Only add the projectile to the snapshot if it didn't hit something. The thing
	# is, there is no point in adding something that is about to be removed from the
	# game. Moreover, delta data will take care of explicitly telling about this fact.
	if (!_hit):
		
		net_position = global_transform.origin
		net_orientation = global_transform.basis.get_rotation_quat()
		
		# See clutter_base.gd's _physics_process for detailed explanation
		if net_has_correction:
			network.snapshot_entity(self)
		else:
			net_has_correction = true
			network.snapshot_entity(self)
			net_has_correction = false


func init(t: Transform) -> void:
	global_transform = t
	$Smooth3D.snap_to_target()

func apply_state() -> void:
	pass


func _simulate(dt: float) -> void:
	var dir: Basis = global_transform.basis
	var motion: Vector3 = (-dir.z * SPEED * dt)
	
	var coll: KinematicCollision = move_and_collide(motion, false)
	
	if (coll):
		_hit = true
		_impact_position = coll.position
		
		# Projectiles are kinematic bodies. If colliding with rigid bodies a force
		# must be applied otherwise they will remain "dormant"
		if (coll.collider is RigidBody):
			coll.collider.apply_impulse(coll.position, -coll.normal * 0.1)

