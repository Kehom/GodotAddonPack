# Copyright (c) 2021 Yuri Sarudiansky
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

tool
extends EditorPlugin


#######################################################################################################################
### Signals and definitions
const dbemain_ps: PackedScene = preload("res://addons/keh_gddb/editor/dbemain.tscn")
const dbemain_t: Script = preload("dbemain.gd")

const LAYOUT_CAT: String = "GDDBPlugin"

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# This function will be assigned as a FuncRef within the dbemain_instance.
func save_layout() -> void:
	if (_restoring_layout):
		return
	
	# Triggers the get_window_layout() call, which is meant to add entries into the config file.
	queue_save_layout()

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _dbemain: dbemain_t

var _restoring_layout: bool = false

# This is meant to hold the list of widths of all columns. In here things become a little bit complicated.
# The layout of every single edited database must be saved. Moreover, the widths of every column of every
# table must be saved.
# This entire saving should not be that problematic because the file holding the data will be created for
# in a per project basis, meaning that it will not affect other projects.
# The dictionary itself will be provided to the debmain scene script which should take care of updating its
# contents accordingly
# All that said, this dictionary holds dictionaries:
# - key = database name -> value = dictionary of tables
# Within the dictionary of tables, there will be dictionaries:
# - key = column title -> value = width
var _col_width_data: Dictionary = {}

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func _enter_tree() -> void:
	# Create instance of the main editor scene
	_dbemain = dbemain_ps.instance()
	
	# Add to the editor
	get_editor_interface().get_editor_viewport().add_child(_dbemain)
	
	# Make it hidden by default
	make_visible(false)
	
	# Setup some data
	_dbemain.layout_saver = funcref(self, "save_layout")
	_dbemain.setup_cwidth_data(_col_width_data)



func _exit_tree() -> void:
	if (_dbemain):
		_dbemain.queue_free()
		_dbemain = null


func has_main_screen() -> bool:
	return true


func handles(obj: Object) -> bool:
	return (obj is GDDatabase)


func edit(obj: Object) -> void:
	if (obj is GDDatabase):
		_dbemain.edit(obj)


func make_visible(vis: bool) -> void:
	if (_dbemain):
		_dbemain.visible = vis


func get_plugin_name() -> String:
	return "Database"


func get_plugin_icon() -> Texture:
	var base: String = get_script().resource_path.get_base_dir()
	return (load(base + "/db_16x16.png") as Texture)


# This is to save the layout into a file and will be called by Godot after the "queue_save_layout()"
# function is called. Because the queue_save_layout() is part of EditorPlugin class, it will be
# indirectly called through a FuncRef set within the main UI scene (dbemain.gd) of this plugin
func get_window_layout(layout: ConfigFile) -> void:
	var last_open: String = _dbemain.get_edited_db()
	var last_table: String = _dbemain.get_selected_table()
	var column_width: Dictionary = _col_width_data
	var splitter_offset: int = _dbemain.get_splitter_offset()
	
	
	layout.set_value(LAYOUT_CAT, "last_open", last_open)
	layout.set_value(LAYOUT_CAT, "last_table", last_table)
	layout.set_value(LAYOUT_CAT, "column_width", column_width)
	layout.set_value(LAYOUT_CAT, "splitter", splitter_offset)


# This is to load layout from file
func set_window_layout(layout: ConfigFile) -> void:
	var last_open: String = layout.get_value(LAYOUT_CAT, "last_open", "")
	var last_table: String = layout.get_value(LAYOUT_CAT, "last_table", "")
	_col_width_data = layout.get_value(LAYOUT_CAT, "column_width", {})
	var soff: int = layout.get_value(LAYOUT_CAT, "splitter", 0)
	
	_restoring_layout = true
	
	# Ensure the scene is holding the correct copy of the width data
	_dbemain.setup_cwidth_data(_col_width_data)
	
	if (!last_open.empty()):
		_dbemain.edit(load(last_open))
	
	if (!last_table.empty()):
		_dbemain.open_table(last_table)
	
	_dbemain.set_hsplit_offset(soff)
	
	_restoring_layout = false



