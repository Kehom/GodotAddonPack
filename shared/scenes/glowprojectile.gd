extends KinematicBody

# Destroy itself after 4 seconds
const TIME_TO_LIVE: float = 4.0
const SPEED: float = 55.0

# Keep track of how long this bullet has lived
var _time_alive: float = 0.0

# If true, the projectile hit something
var _hit: bool = false

# And if there is an impact, this indicate the location
var _impact_position: Vector3 = Vector3()

func _process(dt: float) -> void:
	# The following will update the internal timer and force despawning of the
	# projectile if it reaches its maximum alive time. This is safe to be
	# done regardless if server or client
	_time_alive += dt
	if (_time_alive >= TIME_TO_LIVE):
		var uid: int = get_meta("uid") if has_meta("uid") else 0
		if (uid > 0):
			network.snapshot_data.despawn_node(MegaSnapProjectile, uid)


func _physics_process(dt: float) -> void:
	if (is_queued_for_deletion()):
		return
	
	var uid: int = get_meta("uid") if has_meta("uid") else 0
	
	if (_hit):
		# Force despawning since the projectile did hit something and the previous
		# test didn't indicate this node is queued for removal
		network.snapshot_data.despawn_node(MegaSnapProjectile, uid)
	
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
	
	# Only add the projectile to the snapshot if it didn't hit something. The thing
	# is, there is no point in adding something that is about to be removed from the
	# game. Moreover, delta data will take care of explicitly telling about this fact.
	if (!_hit):
		var sobj: MegaSnapProjectile = MegaSnapProjectile.new(uid, 0)
		sobj.position = global_transform.origin
		sobj.orientation = Quat(global_transform.basis)
#		sobj.fired_by = 
		
		network.snapshot_entity(sobj)

func init(t: Transform) -> void:
	global_transform = t
	$Smooth3D.snap_to_target()


func apply_state(state: Dictionary) -> void:
	var orient: Quat = state.orientation

	global_transform = Transform(Basis(orient), state.position)
	$Smooth3D.snap_to_target()

