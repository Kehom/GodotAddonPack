# Copyright (c) 2022 Yuri Sarudiansky
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
const editormain_s: PackedScene = preload("edt_main.tscn")
const editormain_t: Script = preload("edt_main.gd")


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _editormain: editormain_t = null
var _tbutton: ToolButton = null


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func edit(obj: Object) -> void:
	var da: DataAsset = obj as DataAsset
	if (da):
		_editormain.edit(da)



func handles(obj: Object) -> bool:
	var da: DataAsset = obj as DataAsset
	return (da != null)



func make_visible(visible: bool) -> void:
	if (visible):
		_tbutton.show()
		make_bottom_panel_item_visible(_editormain)
	
	
	else:
		if (_editormain && _editormain.is_visible_in_tree()):
			hide_bottom_panel()
		
		if (_tbutton):
			_tbutton.hide()



func _enter_tree() -> void:
	# Create instance of the main editor scene
	_editormain = editormain_s.instance()
	_editormain.rect_min_size = Vector2(0, 200)
	
	# Register within the editor
	_tbutton = add_control_to_bottom_panel(_editormain, "DataAsset")
	
	_tbutton.hide()


func _exit_tree() -> void:
	if (_editormain):
		remove_control_from_bottom_panel(_editormain)
		
		_editormain.free()
		
		_editormain = null
	
	_tbutton = null

