extends Panel

var is_playing: bool
var tenseconds: int
var last_snap: NetSnapshot
var replay: Replay
var gameworld: Spatial
onready var c: RichTextLabel = $Panel/C
onready var files: FileDialog = $FileDialog
onready var replayinfo: Label = $"Replay Info"
onready var replaychanger: Button = $newreplay
onready var timeline: HSlider = $VBoxContainer/Timeline
onready var playbackspeed: SpinBox = $TimeScale
onready var viewport: Viewport = $CenterContainer/ViewportContainer/Viewport
onready var timereadout: Label = $TimecodeInfo/TimeReadout/Readout
onready var maxtime: Label = $TimecodeInfo/TimeReadout/Max
onready var tickreadout: Label = $TimecodeInfo/FrameReadout/Readout
onready var maxticks: Label = $TimecodeInfo/FrameReadout/Max
onready var fpsreadout: Label = $FPS/Readout
onready var playpause: Button = $VBoxContainer/MediaControls/PauseAndPlay
onready var tickrate: Label = $ReplayInfo/Tickrate/Readout
onready var fullrate: Label = $ReplayInfo/FullSnapshotRate/Readout

var playicon: Texture = preload("res://addons/keh_gddb/editor/btplay_16x16.png")
var pauseicon: Texture = preload("res://addons/keh_gddb/editor/btpause_16x16.png")

func assign_icon() -> void:
	playpause.set_button_icon(get_icon_from_is_playing())

func get_icon_from_is_playing() -> Texture:
	return playicon if is_playing else pauseicon

const defaultreplayfolder: String = "user://replays"
func _ready() -> void:
	Replay.make_dir_if_doesnt_exist(defaultreplayfolder)
	files.set_current_dir(defaultreplayfolder)
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
					goto_main_menu()
				
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

func simulate_up_to_current_snapshot(this_snap: NetSnapshot) -> void:
	var remainder: int = this_snap.signature%replay._tickrate+1
	var last_full_snap_idx: int = this_snap.signature
	for i in remainder:
		assert(last_snap.signature + i != this_snap.signature)
		update_entities(replay.get_snapshot(last_full_snap_idx+i))

func change_replay() -> void:
	files.show()
	# setup subwindow size (godot 4 quack func)

func clear_replay() -> void:
	pause_if_playing()
	if gameworld:
		gameworld.queue_free()
		gameworld = null
	last_snap = null

# Maybe rename to denote that it's related to files
static func load_new_replay(filepath: String) -> Replay:
	var serialized: Array = Replay.read_compressed_replay_file(filepath)
	Replay.assert_enumerated_array_correct(serialized)
	var ret = Replay.new(serialized[Replay.TICKRATE],serialized[Replay.FULL_SNAPSHOT_TICKRATE],serialized[Replay.SCENE_PATH])
	ret.deserialize_history(serialized[Replay.HISTORY])
	return ret

func read_replay(filepath: String) -> void:
	clear_replay()
	if replay:
		replay = load_new_replay(filepath)
	else:
		replay.load_replay(filepath)
	change_playback_speed(playbackspeed.value)
	setup_timeline()
	tenseconds = replay._tickratre * 10
	setup_game_scene()

func setup_game_scene() -> void:
	var scene: Resource = load(replay._scene_path)
	assert(scene is PackedScene)
	gameworld = scene.instance()
	assert(gameworld is Spatial)
	viewport.add_child(gameworld)
	call_deferred("set_physics_process_recursive",gameworld,false)

func setup_timeline() -> void:
	timeline.set_min(0)
	timeline.set_max(replay._history.size()-1)

func on_timeline_ticked(value: int) -> void:
	var snapshot: NetSnapshot = replay.get_snapshot(value)
	if !replay.is_full_snapshot(snapshot) and (!last_snap or last_snap.signature != snapshot.signature - 1):
		simulate_up_to_current_snapshot(snapshot)
	update_entities(snapshot)
	last_snap = snapshot
	timereadout.set_text(replay.get_current_time_as_string(value))
	tickreadout.set_text(str(value))

func update_entities(snapshot: NetSnapshot) -> void:
	var entity_data: Dictionary = snapshot._entity_data
	for entity_type in entity_data.values():
		assert(entity_type is Dictionary)
		for entity in entity_type.values():
			assert(entity is SnapEntityBase)
			entity.apply_state(network.snapshot_data._get_entity_info(entity.get_script()).get_game_node(entity.id))

func set_replay_info() -> void:
	tickrate.set_text(str(replay._tickrate))
	fullrate.set_text(str(replay._full_snapshot_tickrate))
	maxtime.set_text(replay.get_total_time_as_string())
	maxticks.set_text(str(replay._history.size()-1))

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
	if replay:
		pause_or_unpause(!is_playing)

func play() -> void:
	pause_or_unpause(true)

func pause() -> void:
	pause_or_unpause(false)

func on_left_pressed() -> void:
	go_back_1()
	pause_if_playing()

func pause_or_unpause(playing: bool) -> void:
	is_playing = playing
	apply_pause_unpaused_differences()

func apply_pause_unpaused_differences() -> void:
#	apply_physics_processing_if_playing()
	assign_icon()

func apply_physics_processing_if_playing() -> void:
	set_physics_process_recursive(gameworld,is_playing)

func get_playback_speed() -> int:
	return int(replay.tickrate * playbackspeed.get_value())

func on_right_pressed() -> void:
	go_forward_1()
	pause_if_playing()

func change_playback_speed(value: float) -> void:
	Engine.set_iterations_per_second(replay._tickrate * value)

func goto_main_menu() -> void:
	# Restore mouse visibility
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Go back to the main menu
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")

func go_forward() -> void:
	move_by_amnt(tenseconds)

func go_back() -> void:
	move_by_amnt(-tenseconds)

func on_timeline_scrolled() -> void:
	pass
	pause_if_playing()

static func set_physics_process_recursive(node: Node, enabled: bool) -> void:
	if !node.get_script():
		if enabled == false:
			assert(!node.is_physics_processing())
	else:
		node.set_physics_process(enabled)
		if node.get_child_count() > 0:
			for child in node.get_children():
				set_physics_process_recursive(child,enabled)
