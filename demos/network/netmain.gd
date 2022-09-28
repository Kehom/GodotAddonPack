# This is the game world of the network demo. Note that it is meant
# to be simple and "minimalist" in order to focus on the network
# addon. To that end, the characters used in here do not interpolate
# their states.
# However, this demo also uses advanced input setup in order to deal
# with custom data, which is necessary in order to deal with certain
# kinds of game genres. More specifically, the custom data involves
# sending the world coordinates of where the mouse button were clicked,
# as well as which buttons were used.

extends Spatial

# Unit character
const UnitCharScene: PackedScene = preload("res://demos/network/scenes/unit.tscn")
# The base material to be applied to the units
const BaseUnitMaterial: SpatialMaterial = preload("res://demos/network/mats/mat_basic_unit.tres")

# Some format strings that will be used in the HUD
const latency_info_str: String = "Latency: %d ms"
const fps_info_str: String = "FPS: %d | Physics: %d"

# To help differentiate units, each player will get a color
# Note that while this is hard coding the colors, this is done for
# simplicity, however obviously it would be interesting to provide
# an option so the player can choose. The megademo shows how to deal
# with this kind of player choice.
const player_color: Dictionary = {
	1: Color(.8, .1, .1, 1),
	2: Color(.1, .8, .1, 1),
	3: Color(.1, .1, .8, 1),
	4: Color(.1, .8, .8, 1),
}

# Materials can be shared between mesh instances. So, to avoid creating multiple instances
# of a certain material (which is meant to change just the color, from the base material),
# this dictionary will hold the created dynamic materials, keyed by the color. Each unit
# will get a reference to this dictionary and when a color is applied to it, the held 
# material instance will be assigned to the mesh instance.
var unit_material: Dictionary = {}


func _ready() -> void:
	_setup_net_input()
	_setup_net_spawners()
	
	# If this is client, must tell the server that it can start sending
	# snapshot data this way
	if (!network.has_authority()):
		network.notify_ready()
	
	SharedUtils.connector(network, "player_removed", self, "on_player_left")
	
	# Initialize the materials
	for i in player_color:
		var col: Color = player_color[i]
		unit_material[col] = BaseUnitMaterial.duplicate()
		unit_material[col].albedo_color = col
	


func _exit_tree() -> void:
	# Ensure the server is closed. If single player or client, nothing will happen.
	network.close_server()
	
	# Disconnect from server. If this is running  in single player or is a server,
	# nothing will happen
	network.disconnect_from_server()
	
	# Clear registered input mappings within the network system. Note that this
	# is being done just because some other demo in this project may need a different
	# input setup. In other words, generally speaking clearing registered input
	# is not needed in a dedicated project.
	network.reset_input()
	
	# Reset the rest of the networking system. This one is usually a good idea
	# to be performed every time the game goes back to the main menu since it
	# will reset the various time signatures within the system.
	network.reset_system()


func _physics_process(_dt: float) -> void:
	$hud/lbl_fpsinfo.text = fps_info_str % [int(Engine.get_frames_per_second()), Engine.iterations_per_second]
	
	# Start building a new snapshot object.
	network.init_snapshot()
	
	# If this is the authority machine, spawn the character class for each
	# player if that wasn't already done
	if (network.has_authority()):
		# First the local player
		create_player_units(network.player_data.local_player, 1)
		
		# WARNING:
		# The pnum value will be used (when spawning the units) for two things:
		# 1 - Locate the proper spawn locations
		# 2 - Determine the color of the units
		# The way things were done in this code results is a weak association between player and
		# color/locations. This will reasult in problems, specially when players leave the game
		# and new ones connect. An stronger association between player <-> color/locations must
		# be used in a final product.
		var pnum: int = 2
		# Then each of the connected players - in this case, clients
		for pid in network.player_data.remote_player:
			create_player_units(network.player_data.remote_player[pid], pnum)
			pnum += 1




# Provide means to get back to the main menu
func _input(evt: InputEvent) -> void:
	if (evt is InputEventKey):
		if (evt.pressed && evt.scancode == KEY_F4):
			# warning-ignore:return_value_discarded
			get_tree().change_scene("res://main.tscn")



func create_player_units(pnode: NetPlayerNode, pnum: int) -> void:
	# Each player will get 3 units. The unique ID will be built by first
	# creating an string with the player ID and appending an index. After
	# that the string is hashed.
	var s_points: Spatial = $spawn_points.get_node("player" + str(pnum))
	if (!s_points):
		return
	
	for i in 3:
		var idstr: String = "%d_%d" % [pnode.net_id, i]
		var uid: int = idstr.hash()
		
		var unode: KinematicBody = network.snapshot_data.get_game_node(uid, CharUnitClass)
		if (unode):
			# If here, all 3 nodes are likely spawned, so bail
			return
		
		var point: Position3D = s_points.get_node(str(i + 1))
		if (!point):
			return
		
		# If here, the node does not exist so create it. Remember, for this
		# specific case/demo, class_hash is not used, so setting it to 0
		unode = network.snapshot_data.spawn_node(CharUnitClass, uid, 0)
		unode.global_transform = point.global_transform
		
		# Must set the owner
		unode.net_owner_id = pnode.net_id
		
		# Must ensure the target position of the unit corresponds to the spawn point
		# otherwise it will move towards the origin (0, 0, 0)
		unode.net_target = point.global_transform.origin
		
		unode.set_color(player_color[pnum])





func _setup_net_input() -> void:
	# For this demo, custom input data is required. In this setup register those
	# extra custom data.
	network.register_custom_input_vec3("topleftnear")
	network.register_custom_input_vec3("bottomrightnear")
	network.register_custom_input_vec3("topleftfar")
	network.register_custom_input_vec3("bottomrightfar")
	
	network.register_custom_input_vec3("target")
	
	# Boolean data
	network.register_action("multiselect", false)
	network.register_action("select_unit", false)
	network.register_action("command_unit", false)


func _setup_net_spawners() -> void:
	# In this specific demo, class_hash is not needed for the spawned objects (the
	# units). Since every spawned unit will be of the exact same type/scene, there
	# is no need to deal with this extra information. So, the second argument is 0
	# There is also an extra setup that is needed. In this case, setting the function
	# reference to the "unit_etra_setup()" function to perform this task
	network.snapshot_data.register_spawner(CharUnitClass, 0, NetDefaultSpawner.new(UnitCharScene), $player, funcref(self, "unit_extra_setup"))


func on_player_left(pid: int) -> void:
	# Player has left. Must remove that player's units from the game.
	for i in 3:
		var idstr: String = "%d_%d" % [pid, i]
		var uid: int = idstr.hash()
		network.snapshot_data.despawn_node(CharUnitClass, uid)


# This function will be called by the network system whenever a unit node is spawned. This
# is registered with the spawner
func unit_extra_setup(unit: CharUnitClass) -> void:
	unit._materials = unit_material

