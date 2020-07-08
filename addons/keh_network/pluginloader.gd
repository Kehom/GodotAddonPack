###############################################################################
# Copyright (c) 2019 Yuri Sarudiansky
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################

tool
extends EditorPlugin

const base_path: String = "keh_addons/network/"

func _enter_tree():
	# Add project settings if they are not present
	var compr: Dictionary = {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "None, RangeCoder, FastLZ, ZLib, ZSTD"
	}
	
	_reg_setting("compression", TYPE_INT, NetworkedMultiplayerENet.COMPRESS_RANGE_CODER, compr)
	_reg_setting("max_snapshot_history", TYPE_INT, 120)
	_reg_setting("max_client_snapshot_history", TYPE_INT, 60)
	_reg_setting("full_snapshot_threshold", TYPE_INT, 12)
	_reg_setting("broadcast_measured_ping", TYPE_BOOL, true)
	_reg_setting("use_input_mouse_relative", TYPE_BOOL, false)
	_reg_setting("use_input_mouse_speed", TYPE_BOOL, false)
	_reg_setting("quantize_analog_input", TYPE_BOOL, false)
	
	
	# Automatically add the network class as a singleton (autoload)
	add_autoload_singleton("network", "res://addons/keh_network/network.gd")


func _exit_tree():
	# And remove the network class from the singleton (autoload) list
	remove_autoload_singleton("network")
	
	# Remove the additional project settings - those will remain on the ProjectSettings window until
	# the editor is restarted
	ProjectSettings.clear(base_path + "compression")
	ProjectSettings.clear(base_path + "max_snapshot_history")
	ProjectSettings.clear(base_path + "max_client_snapshot_history")
	ProjectSettings.clear(base_path + "full_snapshot_threshold")
	ProjectSettings.clear(base_path + "broadcast_measured_ping")
	ProjectSettings.clear(base_path + "use_input_mouse_relative")
	ProjectSettings.clear(base_path + "use_input_mouse_speed")
	ProjectSettings.clear(base_path + "quantize_analog_input")


# def_val is relying on the variant, thus no static typing
func _reg_setting(sname: String, type: int, def_val, info: Dictionary = {}) -> void:
	var fpath: String = base_path + sname
	if (!ProjectSettings.has_setting(fpath)):
		ProjectSettings.set(fpath, def_val)

	# Those must be done regardless if the setting existed before or not, otherwise the ProjectSettings window
	# will not work correctly (yeah, the default value as well as the hints must be provided)
	ProjectSettings.set_initial_value(fpath, def_val)
	
	var propinfo: Dictionary = {
		"name": fpath,
		"type": type
	}
	if (info.has("hint")):
		propinfo["hint"] = info.hint
	if (info.has("hint_string")):
		propinfo["hint_string"] = info.hint_string
	
	ProjectSettings.add_property_info(propinfo)

