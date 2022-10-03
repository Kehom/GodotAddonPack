extends Panel

var is_playing: bool
var tenseconds: int
var last_snap: NetSnapshot
var replay: Replay
onready var c: RichTextLabel = $Panel/C
onready var files: FileDialog = $FileDialog
onready var replayinfo: Label = $"Replay Info"
onready var replaychanger: Button = $newreplay
onready var timeline: HScrollBar = $VBoxContainer/Timeline
onready var playbackspeed: SpinBox = $TimeScale
onready var viewport: Viewport = $CenterContainer/ViewportContainer/Viewport
onready var timereadout: Label = $TimecodeInfo/TimeReadout/Readout
onready var tickreadout: Label = $TimecodeInfo/FrameReadout/Readout
onready var fpsreadout: Label = $FPS/Readout
onready var playpauseicon: Button = $VBoxContainer/MediaControls/PauseAndPlayMediaControls/PauseAndPlay

var playicon: Texture = preload("res://addons/keh_gddb/editor/btplay_16x16.png")
var pauseicon: Texture = preload("res://addons/keh_gddb/editor/btpause_16x16.png")

func assign_icon() -> void:
	playpauseicon.set_button_icon(get_icon_from_is_playing())

func get_icon_from_is_playing() -> Texture:
	return playicon if is_playing else pauseicon

func _ready() -> void:
	files.call_deferred("invalidate")
	change_replay()

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	fpsreadout.set_text(str(Engine.get_frames_per_second()))

func _input(event: InputEvent) -> void:
	# Forward 1 frame
	if Input.is_action_pressed("ui_right"):
		# Forward 10 seconds
		if Input.is_action_pressed("sprint"):
			# To end
			if Input.is_action_pressed("multiselect"):
				go_to_end()
			else:
				go_forward()
		else:
			go_forward_1()
	
	# Back 1 frame
	if Input.is_action_pressed("ui_left"):
		# Back 10 seconds
		if Input.is_action_pressed("sprint"):
			# Restart
			if Input.is_action_pressed("multiselect"):
				restart()
			else:
				go_back()
		else:
			go_back_1()

	# Timescale up/down
	if Input.is_action_pressed("ui_up"):
		pass
	if Input.is_action_pressed("ui_down"):
		pass
	
	# Play/pause
	if Input.is_action_pressed("ui_select"):
		pause_unpause()
	
	if (event is InputEventKey):
		if (event.pressed):
			match event.scancode:
				KEY_F1:
					OS.vsync_enabled = !OS.vsync_enabled
				
				KEY_F4:
					# Restore mouse visibility
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					# Go back to the main menu
					# warning-ignore:return_value_discarded
					get_tree().change_scene("res://main.tscn")
				
				KEY_F10:
					OverlayDebugInfo.toggle_visibility()
				
				
				KEY_ESCAPE:
					# TODO: toggle visibility of a menu - set mouse mode based on that
					# For now just toggle mouse mode
					if (Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE):
						# It's already visible, so capture it TODO: only if freecam enabled
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						# It's captured, so show it
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

#static func get_time_from_ticknum(ticknum: int, tickrate: int) -> String:
#	return History.get_replay_length_from_tick_count(ticknum, tickrate)

func tick_feed(value: int) -> void:
	pass

func simulate_up_to_current_snapshot(this_snap: NetSnapshot) -> void:
	pass

func change_replay() -> void:
	files.show()
	# setup subwindow size (godot 4 quack func)

func clear_replay() -> void:
	pass

func read_replay() -> void:
	pass

func setup_timeline() -> void:
	pass

func on_timeline_ticked(value: String) -> void:
	pass

func set_replay_info() -> void:
	pass
#	replayinfo.set_text("tickrate: %s | SS tickrate: %s | size: %s | length %s\nmap: %s | mode: %s"%[replay.tickrate,
#																				replay.snapshot_tickrate,
#																				replay.history.size(),
#																				get_time_from_ticknum(replay.history.size(),replay.tickrate),
#																				Map.map_name_from_path(replay.map_file_path),
#																				Gamemodes.get_gamemode_name(replay.gamemode)])

func restart() -> void:
	timeline.set_value(0)

func go_back_1() -> void:
	move_by_amnt(-1)

func pause_if_playing() -> void:
	if is_playing:
		pause()

func move_by_amnt(amnt: int) -> void:
	timeline.set_value(timeline.get_value() + amnt)

func go_forward_1() -> void:
	move_by_amnt(1)
#	timeline.set_value(timeline.get_value() + 1)

func go_to_end() -> void:
	timeline.set_value(timeline.get_max())
	pause_if_playing()

func pause_unpause() -> void:
	is_playing = !is_playing
	assign_icon()

func play() -> void:
	is_playing = true
	assign_icon()

func pause() -> void:
	is_playing = false
	assign_icon()

func on_left_pressed() -> void:
	go_back_1()
	pause_if_playing()

func get_playback_speed() -> int:
	return int(replay.tickrate * playbackspeed.get_value())

func on_right_pressed() -> void:
	go_forward_1()
	pause_if_playing()

func change_playback_speed(value: float) -> void:
	pass
#	Quack.set_tickrate(replay.tickrate * value)

func goto_main_menu() -> void:
	pass
#	Quack.change_scene("res://Interface/Menus/Main Menu.tscn")

func go_forward() -> void:
	move_by_amnt(tenseconds)

func go_back() -> void:
	move_by_amnt(-tenseconds)
	
	
func clear_gameplay_if_loaded() -> void:
	pass
#	if map_is_loaded():
#			Network.get_entities().clear()
#			Network.clear_map()

func map_is_loaded() -> bool:
	pass
	return Network.map != null

func setup_map() -> void:
	pass
#	Network.map = load(replay.map_file_path).instantiate()
#	viewport.add_child(Network.map)
#	Network.setup_entity_groups()
#	last_tick = []


func on_tree_exiting() -> void:
	pass
#	clear_gameplay_if_loaded()

func on_timeline_scrolled() -> void:
	pass
	pause_if_playing()


func Pause() -> void:
	pass # Replace with function body.
