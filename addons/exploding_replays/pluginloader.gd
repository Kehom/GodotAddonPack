###############################################################################
# Copyright (c) 2022 Miles Mazzotta
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

const base_path: String = Replay.explodingreplays

var _extra_settings: Array = []


# This will be called by the engine whenever the plugin is activated
func enable_plugin() -> void:
	pass

# This will be called by the engine whenever the plugin is deactivated
func disable_plugin() -> void:
	pass
	
	# Remove the additional project settings - those will remain on the ProjectSettings window until
	# the editor is restarted
	for es in _extra_settings:
		ProjectSettings.clear(es)
	
	_extra_settings.clear()


func _enter_tree():
	_reg_setting(Replay.recsetting, TYPE_BOOL, false)
	_reg_setting(Replay.capratesetting, TYPE_INT, 30)
	_reg_setting(Replay.fullratesetting, TYPE_INT, 30)
	_reg_setting(Replay.defaultdiresetting, TYPE_STRING, Replay.default_save_path)


func _exit_tree() -> void:
	pass



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

