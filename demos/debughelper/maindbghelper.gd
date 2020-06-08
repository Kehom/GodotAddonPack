# This script is meant to demonstrate how simple it is to use the scripts in the
# debug helper addon directory.
# The overlay info has been activated as a plugin, meaning that it's accessed by
# the default auto-load script name, OverlayDebugInfo

# NOTE: the root node is intentionally spatial (3D).

extends Spatial

# Keep timed texts on screen for three and a half seconds
const TIMED_TEXT_SECONDS: float = 3.5
# Save VSync setting so it is restored when going back to the main menu
onready var _original_vsync: bool = OS.vsync_enabled

func _ready() -> void:
	OverlayDebugInfo.set_visibility(true)


func _physics_process(_dt: float) -> void:
	# Show the frames per second
	OverlayDebugInfo.set_label("fps", "FPS: %s" % Engine.get_frames_per_second())
	# Show number of physics iterations per second
	OverlayDebugInfo.set_label("physicsfps", "Physics: %s/s" % Engine.iterations_per_second)
	# Show VSync setting "on/off"
	OverlayDebugInfo.set_label("vsync", "VSync: %s" % OS.vsync_enabled)
	# Show window size
	OverlayDebugInfo.set_label("winsize", "Window Size: %s" % OS.get_window_size())
	# Show window position
	OverlayDebugInfo.set_label("winpos", "Window Position: %s" % OS.get_window_position())


func _input(evt: InputEvent) -> void:
	if (evt is InputEventKey && evt.is_pressed()):
		match evt.scancode:
			KEY_F1:
				OverlayDebugInfo.toggle_visibility()
			KEY_F2:
				OverlayDebugInfo.set_horizontal_align_left()
			KEY_F3:
				OverlayDebugInfo.set_horizontal_align_center()
			KEY_F4:
				OverlayDebugInfo.set_horizontal_align_right()

func _exit_tree() -> void:
	# Restore original vsync state
	OS.vsync_enabled = _original_vsync
	# Clear all labels from the overlay
	OverlayDebugInfo.clear()
	# And hide it. If going back to the main menu, some other demos may not need this
	OverlayDebugInfo.set_visibility(false)


func _on_bt_overlaytoggle_pressed() -> void:
	OverlayDebugInfo.toggle_visibility()


func _on_bt_alignleft_pressed() -> void:
	OverlayDebugInfo.set_horizontal_align_left()
	# Add a timed text
	OverlayDebugInfo.add_timed_label("Aligning info to the left", TIMED_TEXT_SECONDS)


func _on_bt_aligncenter_pressed() -> void:
	OverlayDebugInfo.set_horizontal_align_center()
	# Add a timed text
	OverlayDebugInfo.add_timed_label("Aligning info to the center", TIMED_TEXT_SECONDS)


func _on_bt_alignright_pressed() -> void:
	OverlayDebugInfo.set_horizontal_align_right()
	# Add a timed text
	OverlayDebugInfo.add_timed_label("Aligning info to the right", TIMED_TEXT_SECONDS)


func _on_bt_aligntop_pressed() -> void:
	OverlayDebugInfo.set_vertical_align_top()
	OverlayDebugInfo.add_timed_label("Aligning info to the top", TIMED_TEXT_SECONDS)

func _on_bt_valigncenter_pressed() -> void:
	OverlayDebugInfo.set_vertical_align_center()
	OverlayDebugInfo.add_timed_label("Vertical aligning info to the cernter", TIMED_TEXT_SECONDS)

func _on_bt_alignbottom_pressed() -> void:
	OverlayDebugInfo.set_vertical_align_bottom()
	OverlayDebugInfo.add_timed_label("Aligning info to the bottom", TIMED_TEXT_SECONDS)



func _on_bt_vsync_pressed() -> void:
	OS.vsync_enabled = !OS.vsync_enabled


func _on_bt_engineversion_pressed() -> void:
	# Add engine version information for 5 seconds
	OverlayDebugInfo.add_timed_label(Engine.get_version_info().string, 5.0)


func _on_bt_back_pressed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")

