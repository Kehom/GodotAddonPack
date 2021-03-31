###############################################################################
# Copyright (c) 2019-2021 Yuri Sarudiansky
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

# This is the base settings path, not installation directory
const base_path: String = "keh_addons/inventory/"
const general_subcat: String = "general/"
const socket_subcat: String = "socket/"
const drag_drop_subcat: String = "custom_drag_&_drop/"

# Without this loader none of the UI Controls will appear in the editor
# Moreover, depending on what is installed a few extra settings will be added into the Project Settings window
# Note that this script will first check if the addon is actually installed before performing any addition to
# the settings list

# Hold a list of all registered custom additional ProjectSettings here to make cleanup easier
var _extra_settings: Array = []

func _enter_tree():
	# The inventory addon uses a few extra options within the project settings window.
	_init_inventory()




# Automatically called by the editor when plugin is deactivated. Cleanup the additional project settings
func disable_plugin() -> void:
	for es in _extra_settings:
		ProjectSettings.clear(es)
	
	_extra_settings.clear()



func _init_inventory() -> void:
	# First check if the inventory addon is installed. If not just bail
	if (!_exists("res://addons/keh_ui/inventory/core.gd")):
		return
	
	### General settings that need hinting
	var pmbutton: Dictionary = {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "None, Left, Right, Middle"
	}
	var ratioinfo: Dictionary = {
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0, 1, 0.01"
	}
	
	### Drag & Drop settings that need hinting
	var valign: Dictionary = {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Top, Center, Bottom"
	}
	var halign: Dictionary = {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Left, Center, Right"
	}
	var dropmode: Dictionary = {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "FillOnly, AllowSwap"
	}
	
	# General settings
	_reg_setting(general_subcat + "pick_item_mouse_button", TYPE_INT, BUTTON_LEFT, pmbutton)
	_reg_setting(general_subcat + "stack_size_vertical_alignment", TYPE_INT, 0, valign)
	_reg_setting(general_subcat + "stack_size_horizontal_alignment", TYPE_INT, 0, halign)
	_reg_setting(general_subcat + "stack_size_offset", TYPE_VECTOR2, Vector2(0.0, 0.0))
	_reg_setting(general_subcat + "slot_auto_highlight", TYPE_BOOL, true)
	_reg_setting(general_subcat + "item_auto_highlight", TYPE_BOOL, true)
	_reg_setting(general_subcat + "draw_item_background", TYPE_BOOL, false)
	_reg_setting(general_subcat + "use_resource_paths_on_signals", TYPE_BOOL, false)
	_reg_setting(general_subcat + "interactable_disabled_items", TYPE_BOOL, true)
	_reg_setting(general_subcat + "disabled_slots_block_items", TYPE_BOOL, true)
	
	# Socket settings
	_reg_setting(socket_subcat + "unsocket_item_mouse_button", TYPE_INT, BUTTON_RIGHT, pmbutton)
	_reg_setting(socket_subcat + "always_draw_sockets", TYPE_BOOL, true)
	_reg_setting(socket_subcat + "socket_draw_ratio", TYPE_REAL, 0.7, ratioinfo)
	_reg_setting(socket_subcat + "socketed_item_emit_hovered_event", TYPE_BOOL, true)
	
	
	# Custom drag&drop settings
	_reg_setting(drag_drop_subcat + "auto_hide_mouse", TYPE_BOOL, true)
	_reg_setting(drag_drop_subcat + "drop_on_existing_stack", TYPE_INT, 0, dropmode)
	_reg_setting(drag_drop_subcat + "inherit_preview_size", TYPE_BOOL, false)
	_reg_setting(drag_drop_subcat + "preview_cell_width", TYPE_INT, 32)
	_reg_setting(drag_drop_subcat + "preview_cell_height", TYPE_INT, 32)
	_reg_setting(drag_drop_subcat + "hide_sockets_on_drag_preview", TYPE_BOOL, false)


func _exists(p: String) -> bool:
	return Directory.new().file_exists(p)


# def_val is relying on the variant, thus no static typing
func _reg_setting(sname: String, type: int, def_val, info: Dictionary = {}) -> void:
	var fpath: String = base_path + sname
	if (!ProjectSettings.has_setting(fpath)):
		ProjectSettings.set(fpath, def_val)
	
	_extra_settings.append(fpath)
	
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
