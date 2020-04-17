# This can be (sort of) considered the main interaction "windows" of the player with the game.
# Granted, it does hold the camera! Thw WASD buttons can be used to move the control around,
# which in turn will move the camera. Mouse wheel can be used to get the camera closer or
# farther away from the control. Note that it does not matter where this control is when in
# multiplayer because it only deals with what the player can see. Fog of war is a method that
# can be applied in order to hide what the player is not meant to see (this is not used in this
# demo, though).
# Mouse input is gathered here, transformed (IE.: from screen to world space) then applied to
# the custom input system, which will take care of handling the data and sending to the server.
#
# The box selection here consists in building a "sub-frustum" from the drawn rectangle. With that,
# a collision convex polygon shape is dynamically set and used in order to detect which units are
# inside the selection. In order to obtain those points a camera is necessary and, because of that,
# the 3D points are pre-computed and sent to the server as part of the custom input data.


extends Spatial

# Create a "class alias" to the unit character
const CharUnit = preload("res://demos/network/scenes/unit.tscn")

export var move_speed: float = 40.0
export var zoom_speed: float = 0.5

# These two properties will control the near and far "planes" when calling the cameras's
# project_position() function, which will then convert screen space coordinates into world
# position. Those will be used to perform the "box selection"
export var near_selection: float = 1.0
export var far_selection: float = 30.0


# This will be used to cache the mouse position so it can be used when relevant
var _mouse_pos: Vector2

# The UnitSelectionData class (selectiondata.gd) is used to handle unit
# selection logic for the local player
var _selection_data: UnitSelectionData

# This holds selection data for remote players and will be filled only on the
# server. Key is unique ID of the remote player and value is another dictionary
# containing the following fields:
# - "selecting": a flag that, if true, means that the selection button pressed
#   state has already been handled and "unselection" has happened if necessary.
# - "data": instace of the UnitSelectionData class
var _remote_selection: Dictionary = {}


func _ready() -> void:
	# Ensure the camera is set to be the current one. This can be safely done
	# because the cam_control is created only in the local machine
	$camera.set_current(true)
	# Initialize the object that will handle selected units.
	_selection_data = UnitSelectionData.new(network.player_data.local_player.net_id)
	
	# On the server, whenever a client joins, a new entry must be added into the "remote_selection"
	# internal variable. Likewise, when client leaves, the corresponding entry must be removed.
	# To that end, listen to the events given by the network addon
	SharedUtils.connector(network, "player_added", self, "on_player_joined")
	SharedUtils.connector(network, "player_removed", self, "on_player_left")




func _physics_process(dt: float) -> void:
	# Keep the camera control center point on ground level
	if ($floor_locator.is_colliding()):
		global_transform.origin.y = $floor_locator.get_collision_point().y
	
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	
	var dir: Vector3 = Vector3()
	
	if (Input.is_action_pressed("move_forward")):
		dir += forward
	if (Input.is_action_pressed("move_backward")):
		dir -= forward
	if (Input.is_action_pressed("move_left")):
		dir -= right
	if (Input.is_action_pressed("move_right")):
		dir += right
	
	global_transform.origin += (dir.normalized() * move_speed * dt)
	
	# Deal with input for this player (IE.: the local one)
	var local_id: int = network.player_data.local_player.net_id
	var input: InputData = network.get_input(local_id)
	_handle_input(input, local_id)
	
	# And if this is the server, deal with remote players
	if (network.has_authority()):
		for pid in network.player_data.remote_player:
			var i: InputData = network.get_input(pid)
			_handle_input(i, pid)



func _input(evt: InputEvent) -> void:
	if (evt is InputEventMouseButton && evt.is_pressed()):
		match evt.button_index:
			BUTTON_WHEEL_UP:
				_zoom(-1.0)
			BUTTON_WHEEL_DOWN:
				_zoom(1.0)
	
	if (evt is InputEventMouseMotion):
		# Cache mouse position
		_mouse_pos = evt.position
		
		# If the middle mouse is pressed, rotate the camera. Now close attention
		# here as button index (BUTTON_*) and button mask (BUTTON_MASK_*) are on
		# the same enum but are completely different. Obviously this can cause
		# confusion specially because the documentation points to the enum from
		# different locations without making it clear that one must look for the
		# masks or indices.
		if (evt.button_mask & BUTTON_MASK_MIDDLE):
			rotation.y -= (deg2rad(1) * evt.relative.x)


func _handle_input(input: InputData, owner: int) -> void:
	if (!input || input.signature == 0):
		return
	
	# If this is client, custom input data must be built when relevant. This data includes:
	# - box selection 3D corners (top-left-near, bottom-right-near, top-left-far, bottom-right-far)
	# - 4 flags (selectended, multiselect, select_unit and command_unit)
	# If server, take the custom data to calculate the other four points if necessary. With that,
	# validate selection and keep on the internal dictionary. Based on the flags, perform the
	# tasks accordingly.
	var points: Dictionary = {}
	var corners: Dictionary = {}
	var sel_data: UnitSelectionData = null
	var just_validatesel: bool = false
	
	if (network.is_id_local(owner)):
		sel_data = _selection_data
		
		# Running for local machine, so obtain initial input device state
		if (input.is_pressed("select_unit")):
			if ($rect_drawer.is_dragging()):
				# Already "dragging" (drawing selection box). Update it
				$rect_drawer.set_end(_mouse_pos)
				
			else:
				if (!input.is_pressed("multiselect")):
					sel_data.unselect_all()
				
				# Just pressed the unit selection button. Set the rect drawing
				$rect_drawer.set_start(_mouse_pos)
			
			corners = $rect_drawer.get_corners()
		
		else:
			# Unit selection button is not pressed. If a rectangle was drawn then it means user
			# released the button. Commit the selection and build custom input data if this is
			# client. With that, server will get the necessary information to validate the selection.
			if ($rect_drawer.is_dragging()):
				# At this point the selection data has already tested everything that is inside the
				# box, so it should be safe to commit the selection
				_selection_data.commit_selection()
				
				if (!network.has_authority()):
					# Saving corners data so custom input data can be built on client machines.
					corners = $rect_drawer.get_corners()
				
				# And clear the rectangle drawing
				$rect_drawer.clear()
			
			else:
				# There was no previous dragging operation. Only check if the "command unit" button was
				# pressed at this moment to avoid trying to command them while dragging the selection box.
				if (input.is_pressed("command_unit")):
					# Must calculate the clicked location. Use mask = 2 to include only the floor objects in the
					# collision detection.
					var cam: Camera = $camera.get_camera()
					var ray_from: Vector3 = cam.project_ray_origin(_mouse_pos)
					var ray_dir: Vector3 = cam.project_ray_normal(_mouse_pos)
					var ray_to: Vector3 = ray_from + (ray_dir * 1000.0)
					
					var hit: Dictionary = get_world().get_direct_space_state().intersect_ray(ray_from, ray_to, [], 2)
					if (hit.size() > 0):
						sel_data.move_selected_to(hit.position)
						
						if (!network.has_authority()):
							# This is client, must send the target position to the server, through the custom
							# input data
							input.set_custom_vec3("target", hit.position)
	
	else:
		# This is running on the server for a client. In here must take from the input data the custom
		# entries in order to build the necessary information to validate selection. The important thing
		# here follows:
		# - First check if the flag "selectended" is set. If so, obtain the custom vectors to calculate
		#   the remaining points and use the convex polygon shape to test what is inside (if anything).
		# - Verify if the flag "command_unit" is set. If so, obtain the custom vector "target" which will
		#   be used as the targe to move the selected units to.
		sel_data = _remote_selection[owner].data
		just_validatesel = true
		if (input.is_pressed("select_unit")):
			if (!_remote_selection[owner].selecting && !input.is_pressed("multiselect")):
				sel_data.unselect_all()
			
			_remote_selection[owner].selecting = true
		
		else:
			if (_remote_selection[owner].selecting):
				# Selection has ended. Gather custom input data (top-left and bottom-right, near and far)
				points["top_left_near"] = input.get_custom_vec3("topleftnear")
				points["bottom_right_near"] = input.get_custom_vec3("bottomrightnear")
				points["top_left_far"] = input.get_custom_vec3("topleftfar")
				points["bottom_right_far"] = input.get_custom_vec3("bottomrightfar")
				
				_remote_selection[owner].selecting = false
			
			else:
				if (input.is_pressed("command_unit")):
					sel_data.move_selected_to(input.get_custom_vec3("target"))
	
	
	if (!sel_data):
		return
	
	# Check if there is corner information. In this case, calculate the world space points that would
	# match the drawn rectangle's corners (top left and bottom right)
	if (corners.size() == 2):
		var cam: Camera = $camera.get_camera()
		points["top_left_near"] = cam.project_position(corners.topleft, near_selection)
		points["bottom_right_near"] = cam.project_position(corners.bottomright, near_selection)
		points["top_left_far"] = cam.project_position(corners.topleft, far_selection)
		points["bottom_right_far"] = cam.project_position(corners.bottomright, far_selection)
		
		# The following expression will result in custom data being attached into the inputo bject
		# only when "commiting" to the selection box.
		if (!network.has_authority() && !input.is_pressed("select_unit")):
			# This is client machine, so build custom input data to be sent to the server
			input.set_custom_vec3("topleftnear", points.top_left_near)
			input.set_custom_vec3("bottomrightnear", points.bottom_right_near)
			input.set_custom_vec3("topleftfar", points.top_left_far)
			input.set_custom_vec3("bottomrightfar", points.bottom_right_far)
	
	
	# If there are four points in the "points" dictionary variable, then there is enough data to
	# calculate the other four world points that will match the top right and bottom left corners
	# of the drawn rectangle. Note that when running on the server for a client machine those four
	# initial points will be filled through the custom input data.
	if (points.size() == 4):
		# If here, then the dictionary is holding four 3D points, corresponding to the top-left-near,
		# bottom-right-near, top-left-far and bottom-right-far. With this it's possible to compute the
		# other four points. First, set the spatial nodes within the "selecthelper" node.
		$selecthelper/top_left_near.global_transform.origin = points.top_left_near
		$selecthelper/bottom_right_near.global_transform.origin = points.bottom_right_near
		$selecthelper/top_left_far.global_transform.origin = points.top_left_far
		$selecthelper/bottom_right_far.global_transform.origin = points.bottom_right_far
		
		# Those spatial nodes now contain local coordinates that can be used in order to properly position
		# the other four nodes, which will automatically generate the desired global positions
		var local_tln: Vector3 = $selecthelper/top_left_near.transform.origin
		var local_brn: Vector3 = $selecthelper/bottom_right_near.transform.origin
		var local_tlf: Vector3 = $selecthelper/top_left_far.transform.origin
		var local_brf: Vector3 = $selecthelper/bottom_right_far.transform.origin
		
		$selecthelper/top_right_near.transform.origin = Vector3(local_brn.x, local_tln.y, local_tln.z)
		$selecthelper/bottom_left_near.transform.origin = Vector3(local_tln.x, local_brn.y, local_brn.z)
		$selecthelper/top_right_far.transform.origin = Vector3(local_brf.x, local_tlf.y, local_tlf.z)
		$selecthelper/bottom_left_far.transform.origin = Vector3(local_tlf.x, local_brf.y, local_brf.z)
		
		# Now fill the other 4 entries of the "points" dictionary variable
		points["top_right_near"] = $selecthelper/top_right_near.global_transform.origin
		points["bottom_left_near"] = $selecthelper/bottom_left_near.global_transform.origin
		points["top_right_far"] = $selecthelper/top_right_far.global_transform.origin
		points["bottom_left_far"] = $selecthelper/bottom_left_far.global_transform.origin
		
		# Check the selection
		sel_data.check_selection(points, get_world().get_direct_space_state(), just_validatesel)


func _zoom(dir: float) -> void:
	var l: float = $camera.arm_length + (zoom_speed * dir)
	$camera.arm_length = clamp(l, 10.0, 30.0)


func on_player_joined(pid: int) -> void:
	_remote_selection[pid] = {
		"selecting": false,
		"data": UnitSelectionData.new(pid)
	}



func on_player_left(pid: int) -> void:
	# warning-ignore:return_value_discarded
	_remote_selection.erase(pid)

