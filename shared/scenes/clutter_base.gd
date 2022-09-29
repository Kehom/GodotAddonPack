extends RigidBody
class_name ClutterBase

# Rigid bodies must set/update the state through the custom itegration function.
# To that end, the "Custom Integrator" property must be enabled and the function
# must be implemented. From there server state can be applied to the object. But
# when the data arrives it's not possible to force the integration to be called
# and it's needed to wait until the next physics update. So, these variables
# will hold the rigid body state. Also, when setting up the snapshot the data
# will be taken from these variables
var net_has_correction: bool
var net_position: Vector3
var net_orientation: Basis
var net_ang_velocity: Vector3
var net_lin_velocity: Vector3

# Holds the unique ID of the object.
var _uid: int
# Holds the class hash that will be used when creating the snapshot object
var _chash: int


func _ready() -> void:
	# Although the property has been set through the editor, ensure this fact here
	custom_integrator = true
	
	_uid = get_name().hash()
	_chash = 0
	set_meta("uid",_uid)
	set_meta("chash",_chash)
	
	# The basic idea here is that "clutter/rigid bodies" are added to the scene
	# through the editor, so "pre-spawned". The replication system must know
	# about these otherwise it will fail to locate and properly correct the state
	# when needed. To that end, add itself to the internal node management of
	# the network system. Note that even if, at some point, clutter objects
	# are dynamically spawned, it will not be a big problem since all that is
	# done with this function is associate the node with the UID.
	if (!Engine.editor_hint):
		network.snapshot_data.add_pre_spawned_node(get_script(), _uid, self)


# During the physics_process() iteration the snapshot object is created and
# added into the snapshot that is currently being built.
func _physics_process(_dt: float) -> void:
	# Generate the snapshot entity object and add to the snapshot
	
	net_position = global_transform.origin
	net_orientation = global_transform.basis
	net_ang_velocity = angular_velocity
	net_lin_velocity = linear_velocity
	
	# Because creating a snapshot entity pulls directly from the script's variables,
	# and the net_has_correction variable should always be set to true in a new
	# snapshot, but the _integrate_forces() function executes in different ways
	# depending on if there's a correction to be applied or not, net_has_correction
	# needs to be always true before creating a new snapshot entity, but needs
	# to be turned back off if it was that way before. this makes sure that the
	# net_has_correction variable will be both set properly for extracting snapshot
	# data and for the remainder of the node's logic
	if net_has_correction:
		network.snapshot_entity(self)
	else:
		net_has_correction = true
		network.snapshot_entity(self)
		net_has_correction = false




# This is the custom integration
func _integrate_forces(state: PhysicsDirectBodyState) -> void:
	if (net_has_correction):
		# The _current_state is holding new data (taken from the server) so
		# apply it into the object.
		state.transform = Transform(Basis(net_orientation),net_position)
		assert(state.transform.origin == net_position and state.transform.basis.is_equal_approx(Basis(net_orientation)))
		state.set_angular_velocity(net_ang_velocity)
		state.set_linear_velocity(net_lin_velocity)
		
		# And ensure next time _integrate_forces is called the data is not
		# applied again
		net_has_correction = false
	
	# Integrate the forces
	state.integrate_forces()
	# Add gravity
	state.linear_velocity.y -= 9.8 * state.get_step()
	
	# Store the state so it can be added into the snapshot
	net_position = state.transform.origin
	net_orientation = state.transform.basis.get_rotation_quat()
	net_ang_velocity = state.get_angular_velocity()
	net_lin_velocity = state.get_linear_velocity()

func apply_state() -> void:
	pass
