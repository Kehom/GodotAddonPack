extends Control

var is_playing: bool
var tenseconds: int
var last_snap: NetSnapshot
var replay: Replay
onready var c: RichTextLabel = $Panel/C
onready var files: FileDialog = $FileDialog
onready var replayinfo: Label = $"Replay Info"
onready var replaychanger: Button = $newreplay
onready var timeline: HScrollBar = $Timeline
onready var playbackspeed: SpinBox = $HBoxContainer2/SpinBox
onready var viewport: Viewport = $ViewportContainer/Viewport
onready var timereadout: Label = $VBoxContainer/time
onready var tickreadout: Label = $VBoxContainer/ticknum

func _ready() -> void:
	files.call_deferred("invalidate")
	change_replay()

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	pass

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

func go_to_first_tick() -> void:
	timeline.set_value(0)

func go_back_1_tick() -> void:
	move_by_amnt(-1)

func pause_if_playing() -> void:
	if is_playing:
		pause()

func move_by_amnt(amnt: int) -> void:
	timeline.set_value(timeline.get_value() + amnt)

func go_forward_1_tick() -> void:
	move_by_amnt(1)
#	timeline.set_value(timeline.get_value() + 1)

func go_to_last_tick() -> void:
	timeline.set_value(timeline.get_max())
	pause_if_playing()

func pause_unpause() -> void:
	is_playing = !is_playing

func play() -> void:
	is_playing = true

func pause() -> void:
	is_playing = false

func on_left_pressed() -> void:
	go_back_1_tick()
	pause_if_playing()

func get_playback_speed() -> int:
	return int(replay.tickrate * playbackspeed.get_value())

func on_right_pressed() -> void:
	go_forward_1_tick()
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
