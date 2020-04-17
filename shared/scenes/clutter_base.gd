extends RigidBody

# Rigid bodies must set/update the state through the custom itegration function.
# To that end, the "Custom Integrator" property must be enabled and the function
# must be implemented. From there server state can be applied to the object. But
# when the data arrives it's not possible to force the integration to be called
# and it's needed to wait until the next physics update. So, this dictionary
# will hold the rigid body state. Also, when setting up the snapshot the data
# will be taken from this dictionary
var _current_state: Dictionary

# Holds the unique ID of the object.
var _uid: int
# Holds the class hash that will be used when creating the snapshot object
var _chash: int


func _ready() -> void:
	# Although the property has been set through the editor, ensure this fact here
	custom_integrator = true
	
	_current_state = {
		"transform": global_transform,
		"angular_velocity": Vector3(),
		"linear_velocity": Vector3(),
		"has_correction": false,
	}
	
	_uid = get_name().hash()
	_chash = 0
	
	# The basic idea here is that "clutter/rigid bodies" are added to the scene
	# through the editor, so "pre-spawned". The replication system must know
	# about these otherwise it will fail to locate and properly correct the state
	# when needed. To that end, add itself to the internal node management of
	# the network system. Note that even if, at some point, clutter objects
	# are dynamically spawned, it will not be a big problem since all that is
	# done with this function is associate the node with the UID.
	if (!Engine.editor_hint):
		network.snapshot_data.add_pre_spawned_node(MegaSnapClutter, _uid, self)


# During the physics_process() iteration the snapshot object is created and
# added into the snapshot that is currently being built.
func _physics_process(_dt: float) -> void:
	# Generate the snapshot entity object and add to the snapshot
	pass
	var sobj: MegaSnapClutter = MegaSnapClutter.new(_uid, _chash)
	sobj.position = _current_state.transform.origin
	sobj.orientation = _current_state.transform.basis
	sobj.ang_velocity = _current_state.angular_velocity
	sobj.lin_velocity = _current_state.linear_velocity
	
	network.snapshot_entity(sobj)




# This is the custom integration
func _integrate_forces(state: PhysicsDirectBodyState) -> void:
	if (_current_state.has_correction):
		# The _current_state is holding new data (taken from the server) so
		# apply it into the object.
		state.set_transform(_current_state.transform)
		state.set_angular_velocity(_current_state.angular_velocity)
		state.set_linear_velocity(_current_state.linear_velocity)
		
		# And ensure next time _integrate_forces is called the data is not
		# applied again
		_current_state.has_correction = false
	
	# Integrate the forces
	state.integrate_forces()
	# Add gravity
	state.linear_velocity.y -= 9.8 * state.get_step()
	
	# Store the state so it can be added into the snapshot
	_current_state.transform = state.get_transform()
	_current_state.angular_velocity = state.get_angular_velocity()
	_current_state.linear_velocity = state.get_linear_velocity()


func apply_state(state: Dictionary) -> void:
	# This is called during the replication system update, meaning that it
	# contains data from the server correcting the internal state. Indicate
	# the fact through the flag and store the correction so it can be applied
	# during the next physics iteration
	# First, must restore the orientation, that is compressed
	#var orient: Quat = KehUtils.restore_rquat_10bit(state.orientation)
	var t: Transform = Transform(Basis(state.orientation), state.position)

	_current_state.has_correction = true
	_current_state.transform = t
	_current_state.angular_velocity = state.angular_velocity
	_current_state.linear_velocity = state.linear_velocity
