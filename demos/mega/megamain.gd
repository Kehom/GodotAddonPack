# This is the "main" game scene of the "MegaDemo", which is basically a demo
# showcasing every relevant addon combined. This is meant to be used as a
# way to show addons in a "real case use" rather than the focused demos
# that are meant to be used as simplistic examples of specific addons.
#
# Things to note in this demo:
# - The network addon is used to perform synchronization using snapshots.
#   This addon requires activation in the project settings window
# - The smooth addon (Smooth3D) is used to perform interpolation of the
#   visual representation of the various game objects. Enabling this addon
#   in the project settings window brings the smooth nodes to the node
#   selection window.

# TODO:
# - Use the network chat system
# - Use the entered name in the main menu
# - Include environment (time of day and maybe weather)
# - Add (simple) pickups (to showcase the network event system)

extends Spatial

#var TEMP_INT: int = 0       # (was) used for debugging

# (Pre)Load the UI scene that will represent each player within the HUD
const UIRemotePlayer: PackedScene = preload("res://shared/ui/ui_remoteplayer.tscn")


# Some format strings that will be used in the HUD
const latency_info_str: String = "Latency: %d ms"
const fps_info_str: String = "FPS: %d | Physics: %d"

# This will hold the "class hash" of the default player character type (capsule)
# It's necessary so if the correct custom player data is not valid something
# can still be used and a character be spawned (this case happens when directly)
# testing the game (this) scene.
var _default_pchar_hash: int = 0    # will be set during the _setup_net_spawners

# Whenever a player joins the game an instance of the ui_remoteplayer.tscn scene
# will be created and added into the HUD. When that player leaves, the node must
# be removed. To help with this task, this dictionary associates the player ID
# with the created node.
var _ui_player: Dictionary = {}

# When disconnected from the server this will be displayed in a message box. In case
# of the disconnection being caused by a kick (closing server or active by the server's player)
# then this property will be changed.
var _disconnected_message: String



func _ready() -> void:
	_setup_net_input()
	_setup_hud()
	_setup_net_spawners()
	
	# Set default message for disconnection from server.
	_disconnected_message = "Disconnected from server, going back to the main menu."
	
	# Use the incrementing ID system to handle the unique IDs of the projectiles.
	network.register_incrementing_id("glow_projectile")
	
	# The networking system will emit some signals that must be handled here.
	# The "player_added" will be used to update the HUD and only that
	SharedUtils.connector(network, "player_added", self, "on_player_joined")
	# The "player_removed" will be used to update the HUD and to remove the
	# player character from the game world.
	SharedUtils.connector(network, "player_removed", self, "on_player_left")
	# The "ping_updated" is used to update the HUD in order to show the measured
	# ping for the indicated player
	SharedUtils.connector(network, "ping_updated", self, "on_ping_updated")
	# And the "disconnected" event is used to leave the game world and go back
	# to the main menu.
	SharedUtils.connector(network, "disconnected", self, "on_disconnected")
	# When kicked by the server, this signal will be given.
	SharedUtils.connector(network, "kicked", self, "on_kicked")
	
	# If this is a client, must notify the server that snapshot data can come
	# this way
	if (!network.has_authority()):
		network.notify_ready()



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
	# Update the HUD info
	$hud/lbl_fpsinfo.text = fps_info_str % [int(Engine.get_frames_per_second()), Engine.iterations_per_second]
	
	# Start building a new snapshot object.
	network.init_snapshot()
	
	# If this is the authority machine, spawn the character class for each
	# player if that wasn't already done
	if (network.has_authority()):
		# First the local player
		create_player_character(network.player_data.local_player)
		
		# Then each of the connected players - in this case, clients
		for pid in network.player_data.remote_player:
			create_player_character(network.player_data.remote_player[pid])



# Provide means to get back to the main menu
func _input(evt: InputEvent) -> void:
	if (evt is InputEventKey):
		if (evt.pressed):
			match evt.scancode:
				KEY_F4:
					# Restore mouse visibility
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					# Go back to the main menu
					# warning-ignore:return_value_discarded
					get_tree().change_scene("res://main.tscn")
				
				KEY_ESCAPE:
					# TODO: toggle visibility of a menu - set mouse mode based on that
					# For now just toggle mouse mode
					if (Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE):
						# It's already visible, so capture it
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						# It's captured, so show it
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)





func create_player_character(pnode: NetPlayerNode) -> void:
	# Unique ID for player character will be the same as the network unique ID
	var charnode: KinematicBody = network.snapshot_data.get_game_node(pnode.net_id, MegaSnapPCharacter)
	if (!charnode):
		# The desired character class hash is specified in the custom property named "char_class")
		var chash: int = pnode.get_custom_property("char_class", _default_pchar_hash)
		
		# Spawn the node
		charnode = network.snapshot_data.spawn_node(MegaSnapPCharacter, pnode.net_id, chash)
		
		# Use the spawn points within the level to set the initial player position
		var index: int = network.player_data.get_player_count()
		charnode.global_transform.origin = $spawn_point.get_node(str(index)).global_transform.origin




# Setup the input within the the network. Without this the networking system
# will not be able to send any kind of input data.
# Ideally this would be done from a project autoload script (singleton) so
# there would be no need to setup this upon loading the game level. However
# this project contains multiple demos and in order to avoid "clashing" the
# data, perform this setup from this place.
# One thing to keep in mind is that the registration requires the input mappings
# to be set within the project settings (Input Map tab).
func _setup_net_input() -> void:
	# The main network demo of this project does not require mouse relative
	# data (it actually uses a different method to deal with mouse input).
	# However, this demo does require mouse relative data, so ensure it's
	# enabled, regardless of what has been setup in the project settings as
	# the other demo may have changed it.
	network.set_use_mouse_relative(true)
	
	# Setup the actions that are meant to be deals as boolean values, non analog
	# data. This is done by setting the second argument as false.
	network.register_action("jump", false)
	network.register_action("sprint", false)
	network.register_action("shoot", false)
	
	# Now the analog actions
	network.register_action("move_forward", true)
	network.register_action("move_backward", true)
	network.register_action("move_left", true)
	network.register_action("move_right", true)



# The HUD holds a bunch of information so it must be setup.
func _setup_hud() -> void:
	if (network.is_single_player()):
		$hud/lbl_typeinfo.text = "Single Player"
		$hud/lbl_latency.visible = false
	else:
		if (network.has_authority()):
			$hud/lbl_typeinfo.text = "Multiplayer Server"
			$hud/lbl_latency.visible = false
		else:
			$hud/lbl_typeinfo.text = "Multiplayer Client"
			$hud/lbl_latency.visible = true
			$hud/lbl_latency.text = latency_info_str % 0
	
	# Ensure players registered before getting to this scene are part of the HUD
	for pid in network.player_data.remote_player:
		_add_player_to_hud(pid)



# The networking system uses spawner objects in order to automate spawning of
# nodes within the game world. Those spawners must be registered within the
# network system. This function perform this task.
# When registering a new spawner, 4 arguments are necessary:
# - The class name (as a resource) which is basically a class derived from
#   SnapEntityBase that represents the node within the snapshots
# - The "class hash" that should identify the packed scene node type.
# - An instance of a class derived from NetNodeSpawner
# - The parent node within the tree hierarchy that will hold the new one.
func _setup_net_spawners() -> void:
	# Player characters require extra setup. Since all of them can be done from a single
	# function, create the function reference here and provide it when registering all
	# of the necessary spawners
	var fref: FuncRef = funcref(self, "on_player_character_spawned")
	
	# Player characters are very simple and don't require any advanced tasks so
	# the NetDefaultSpawner (defaultspawner.gd) is enough. Still, there are 3
	# character types, so 3 instances of that spawner are necessary.
	var ps_caps: PackedScene = load("res://shared/scenes/pchar_capsule.tscn")
	var chash_caps: int = ps_caps.resource_path.hash()
	network.snapshot_data.register_spawner(MegaSnapPCharacter, chash_caps, NetDefaultSpawner.new(ps_caps), $player, fref)
	
	var ps_cyl: PackedScene = load("res://shared/scenes/pchar_cylinder.tscn")
	var chash_cyl: int = ps_cyl.resource_path.hash()
	network.snapshot_data.register_spawner(MegaSnapPCharacter, chash_cyl, NetDefaultSpawner.new(ps_cyl), $player, fref)
	
	var ps_cube: PackedScene = load("res://shared/scenes/pchar_cuboid.tscn")
	var chash_cube: int = ps_cube.resource_path.hash()
	network.snapshot_data.register_spawner(MegaSnapPCharacter, chash_cube, NetDefaultSpawner.new(ps_cube), $player, fref)
	
	# The projectiles of this demo are also very simple. And because there aren't
	# different types of them, class hash has been disabled (see the megasnapprojectile.gd)
	# In this case, those are meant to be children of the "projectile" node
	var ps_glowproj: PackedScene = load("res://shared/scenes/glowprojectile.tscn")
	network.snapshot_data.register_spawner(MegaSnapProjectile, 0, NetDefaultSpawner.new(ps_glowproj), $projectile)
	
	# And set the default player character class_hash to be the capsule one.
	_default_pchar_hash = chash_caps


func on_player_joined(pid: int) -> void:
	_add_player_to_hud(pid)


# This is a signal handler. This will happen whenever a player leaves the game
# While the spawning is based on the actual player list, de-spawning needs to
# be done in a different way. In this case, through this event handler. Also,
# the HUD will be updated
func on_player_left(pid: int) -> void:
	# Remove the player character node from the game world
	network.snapshot_data.despawn_node(MegaSnapPCharacter, pid)
	
	_ui_player[pid].queue_free()
	# warning-ignore:return_value_discarded
	_ui_player.erase(pid)


func on_ping_updated(peer: int, value: float) -> void:
	var ctrl: Control = _ui_player.get(peer)
	if (ctrl):
		ctrl.set_ping(value)
	else:
		if (network.is_id_local(peer) && peer != 1):
			$hud/lbl_latency.text = latency_info_str % int(value)



func on_disconnected() -> void:
	set_pause_mode(Node.PAUSE_MODE_STOP)
	# Restore the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var err_diag: AcceptDialog = AcceptDialog.new()
	#err_diag.dialog_text = "Disconnected from server, going back to the main menu."
	err_diag.dialog_text = _disconnected_message
	err_diag.window_title = "Disconnected"
	err_diag.popup_exclusive = true
	
	# warning-ignore:return_value_discarded
	err_diag.connect("confirmed", self, "_on_err_confirmed")
	add_child(err_diag)
	
	err_diag.popup_centered()


func on_kicked(reason: String) -> void:
	# Just change the disconnection message. The rest of the actions (displaying
	# a message box then going back to main menu will be taken care from the "on_disconnected")
	_disconnected_message = reason


func _on_err_confirmed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")


func _add_player_to_hud(pid: int) -> void:
	# Create an instance of the ui_remoteplayer scene so information about the
	# new player can be shown
	var ctrl: Control = UIRemotePlayer.instance()
	# Add the node to the internal dictionary so it can be used later
	_ui_player[pid] = ctrl
	
	# Setup the UI (using its script')
	ctrl.set_player_name(str(pid))
	
	# Add to the HUD
	$hud/box_plist.add_child(ctrl)



# This function will be called (by the network system) whenever a new player character
# node is spanwed in the game world. The function is associated to the net spawners.
# as extra setup. Check the _setup_net_spawners() function for details on this association.
func on_player_character_spawned(node: Node) -> void:
	# The desired extra setup for player characters here is to connect the signal
	# "stamina_changed" of the player character to a function in this script meant to
	# update the HUD
	SharedUtils.connector(node, "stamina_changed", self, "_on_character_stamina_changed")



func _on_character_stamina_changed(uid: int, newval: float) -> void:
	if (network.is_id_local(uid)):
		# The local player has an specific widget (pg_localstamina) that will be
		# directly changed
		$hud/pg_localstamina.value = newval
	
	else:
		var ctrl: Control = _ui_player.get(uid)
		if (ctrl):
			ctrl.set_stamina(newval)

