extends Control

var tab_list: Dictionary = {}
onready var btbox: VBoxContainer = $mpnl/demo_list/pnl/vbox

# This project contains multiple demos, mostly one for each addon plus a
# "mega demo". Any demo that requires a server will have to deal with the
# networking addon's signals in order to properly transition into the correct
# scene. This variable holds the path to the scene that should be opened
# whenever creating a server or connecting to one.
var _open_net_scene: String = ""

func _ready() -> void:
	randomize()
	
	# Make sure the overlay debug info is hidden
	OverlayDebugInfo.set_visibility(false)
	
	_open_net_scene = ""
	var tcount: int = $mpnl/stabs.get_tab_count()
	
	for i in tcount:
		tab_list[$mpnl/stabs.get_tab_title(i)] = i
	
	# Connect the "toggled" signal on all of the "demo buttons", binding the tab index as payload
	set_tab_button("bt_encdec", "encdecbuffer")
	set_tab_button("bt_quantize", "quantize")
	set_tab_button("bt_network", "network")
	set_tab_button("bt_cam3d", "cam3d")
	set_tab_button("bt_fancyle", "fancyle")
	set_tab_button("bt_inventory", "inventory")
	set_tab_button("bt_smooth", "smooth")
	set_tab_button("bt_megademo", "megademo")
	set_tab_button("bt_dbghelper", "dbghelper")
	set_tab_button("bt_audiomaster", "audiomaster")
	set_tab_button("bt_replaydemo","replaydemo")
	
	# Connect the networking signals. Those are necessary in order to transition
	# into the game scene only on success and give the chance to show a message
	# in case of failure.
	SharedUtils.connector(network, "server_created", self, "_on_server_created")
	SharedUtils.connector(network, "join_accepted", self, "_on_join_success")
	
	# Perform extra setup if the demo requires it
	setup_megademo()


func _input(evt: InputEvent) -> void:
	if (evt is InputEventKey):
		match evt.get_scancode():
			KEY_F1:
				print("Physics iterations per second: ", Engine.iterations_per_second)

func set_tab_button(bt: String, tabkey: String) -> void:
	SharedUtils.connector(btbox.get_node(bt), "toggled", self, "_on_demo_button_toggled", [tab_list[tabkey]])


# This is just a "shortcut" function meant to change to the specified scene
# but also allowing to avoid multiple "tags" to ignore the warning that the
# return value was not used
func open_scene(path: String) -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene(path)



# The toggle buttons are part of a group so they are only "unpressed" if a different button
# is pressed. Because of that, there is no need to check the "_pressed" argument and
# it's possible to directly activate the corresponding tab pages
func _on_demo_button_toggled(_pressed: bool, index: int) -> void:
	$mpnl/stabs.current_tab = index


#### Network demo
func setup_megademo() -> void:
	# This demo also showcases the possibility of the player choosing different character
	# classes (which in this case only changes the visual appearance). From the main menu
	# the player chooses the desired character then either create or join a game. The way
	# the choice is broadcast is done through the *custom player data* in the addon.
	# This system first requires prior registration of the properties. In this case, a
	# simple integer is used to represent the character class. This integer is actually the
	# result of hashing the resource path of character class, more specifically the shape.
	var caps_hash: int = load("res://shared/scenes/pchar_capsule.tscn").resource_path.hash()
	var cyl_hash: int = load("res://shared/scenes/pchar_cylinder.tscn").resource_path.hash()
	var cube_hash: int = load("res://shared/scenes/pchar_cuboid.tscn").resource_path.hash()
	network.player_data.add_custom_property("char_class", caps_hash, NetCustomProperty.ReplicationMode.ServerOnly)
	
	# Now make the buttons change the custom setting
	SharedUtils.connector($mpnl/stabs/megademo/bt_charcapsule, "pressed", self, "_on_character_clicked", [caps_hash])
	SharedUtils.connector($mpnl/stabs/megademo/bt_charcylinder, "pressed", self, "_on_character_clicked", [cyl_hash])
	SharedUtils.connector($mpnl/stabs/megademo/bt_charcube, "pressed", self, "_on_character_clicked", [cube_hash])
	
	
	network.player_data.add_custom_property("testing_broadcast", 5, NetCustomProperty.ReplicationMode.ServerBroadcast)




func _on_server_created() -> void:
	open_scene(_open_net_scene)


func _on_join_success() -> void:
	network.player_data.local_player.set_custom_property("testing_broadcast", randi() % 10)
	open_scene(_open_net_scene)



func _on_character_clicked(chash: int) -> void:
	# One of the player character types button has been selected. It should
	# change a custom property within the networking system, which will
	# automatically replicate to the server which will deal with the correct
	# spawning.
	network.player_data.local_player.set_custom_property("char_class", chash)


### Related to the mega demo
func _on_megabt_single_pressed() -> void:
	# The "single player" button has been pressed. Since no server is necessary
	# it is safe to directly transition into the game scene
	open_scene("res://demos/mega/megamain.tscn")


func _on_megabt_host_pressed() -> void:
	# If server creation succeeds, must open the following scene
	_open_net_scene = "res://demos/mega/megamain.tscn"
	# Try to create the server
	network.create_server(1234, "The Server", 5)


func _on_megabt_join_pressed() -> void:
	# If joining the server succeeds, must open the following scene
	_open_net_scene = "res://demos/mega/megamain.tscn"
	# Try to join the server
	network.join_server("127.0.0.1", 1234)

### Network demo
func _on_bt_single_pressed() -> void:
	# This is the single player mode, so just open the scene
	open_scene("res://demos/network/netmain.tscn")

func _on_bt_create_pressed() -> void:
	# If server creation succeeds, must open the following scene
	_open_net_scene = "res://demos/network/netmain.tscn"
	# Try to create the server allowing a maximum of 4 players (3 connections)
	network.create_server(1234, "The Server", 3)

func _on_bt_join_pressed() -> void:
	# If joining the server succeeds, must open the following scene
	_open_net_scene = "res://demos/network/netmain.tscn"
	# Obtain the address of the server
	var ip: String = $mpnl/stabs/network/txt_serverip.text
	# Try to join the server
	network.join_server(ip, 1234)

### The encdec buffer demo
func _on_bt_encdecload_pressed() -> void:
	open_scene("res://demos/general/edbuffer.tscn")


### The quantize (previously named utilities) demo
func _on_bt_utilsload_pressed() -> void:
	open_scene("res://demos/general/quantizedemo.tscn")


### Cam3D demo
func _on_bt_cam3dload_pressed() -> void:
	open_scene("res://demos/nodes/testcam3d.tscn")

### Smooth nodes demo
func _on_bt_smoothload_pressed():
	open_scene("res://demos/nodes/testsmooth.tscn")

### FancyLineEdit demo
func _on_bt_fleload_pressed() -> void:
	open_scene("res://demos/ui/fancy_le.tscn")

### Inventory demo
func _on_bt_invdemoload_pressed() -> void:
	open_scene("res://demos/ui/invdemo.tscn")

### Debug Helpers
func _on_bt_dbgload_pressed() -> void:
	open_scene("res://demos/debughelper/maindbghelper.tscn")

### AudioMaster
func _on_bt_amasterload_pressed():
	open_scene("res://demos/audiomaster/amaster.tscn")

### Replay demo
func _on_bt_replaydemo_pressed() -> void:
	open_scene("res://demos/replaydemo/Replay Viewer.tscn")


func _on_bt_quit_pressed() -> void:
	get_tree().quit()
