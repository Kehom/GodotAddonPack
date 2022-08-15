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
extends HBoxContainer

# "Generic" resource (inner) editor. Basically, the idea is to have a "bar" containing the resource "instance itself"
# This should allow creating the object using any of the resources derived from the given base class. This editor will
# be inserted into the main "ped_resource" instance, which will then fill the resource property editors within that
# "outer editor".
# This could have easily been an inner (ped_resource) class, however separating this into a different script file to
# make it easier to create specialized visualizations (textures, for example, to display a thumbnail)

#######################################################################################################################
### Signals and definitions
signal new_instance(nval)

const DAHelperT: Script = preload("../../dahelper.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func prepend() -> void:
	pass


func set_type_checker(fref: FuncRef) -> void:
	_checktype = fref

func lock_instance() -> void:
	_optbutton.visible = false

func setup_builtin(restype: String) -> void:
	# warning-ignore:return_value_discarded
	_optbutton.connect("about_to_show", self, "_on_popup_showing_for_core", [restype])



func setup_scripted(base: Script, allow_base: bool) -> void:
	# warning-ignore:return_value_discarded
	_optbutton.connect("about_to_show", self, "_on_popup_showing_for_scripted", [base, allow_base])



func set_instance(val: Resource) -> void:
	if (val == null):
		_lblcurrent.text = "null"
	
	else:
		var res: String = val.resource_path if !val.resource_path.empty() else str(val)
		
		_lblcurrent.text = res


#######################################################################################################################
### "Private" definitions
#const _BASE_ITEM_TXT: String = "New '%s'"

#######################################################################################################################
### "Private" properties
var _lblcurrent: Label = Label.new()
var _optbutton: MenuButton = MenuButton.new()

# The main property editor owning the instance editor has a function that verifies if a given resource is of the
# expected type. This funcref points to that function
var _checktype: FuncRef = null

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_popup_showing_for_core(restype: String) -> void:
	var pop: PopupMenu = _optbutton.get_popup()
	pop.clear()
	
	DAHelperT.fill_core_class_popup(restype, pop)



func _on_popup_showing_for_scripted(base: Script, allow_base: bool) -> void:
	var pop: PopupMenu = _optbutton.get_popup()
	pop.clear()
	
	DAHelperT.fill_scripted_class_popup(base, allow_base, pop)



func _on_index_pressed(index: int) -> void:
	var pop: PopupMenu = _optbutton.get_popup()
	
	var mval = pop.get_item_metadata(index)
	
	if (mval != null):
		# If here, then the data is a String, containing the path to a script
		var script: GDScript = load(mval) as GDScript
		if (script):
			emit_signal("new_instance", script.new())
	
	else:
		var cname: String = pop.get_item_text(index)
		emit_signal("new_instance", ClassDB.instance(cname))


#######################################################################################################################
### Overrides
func can_drop_data(_position: Vector2, data) -> bool:
	if (!_optbutton.visible):
		# If here, then "lock_instance()" has been called. Most likely this belongs to the "root resource editor". It
		# should not allow dropping a new instance here.
		return false
	
	if (!(data is Dictionary)):
		return false
	
	var ret: bool = false
	var dtype: String = data.get("type", "")
	if (dtype == "files"):
		var files: Array = data.get("files", [])
		if (files.size() > 1):
			return false
		
		var res: Resource = load(files[0])
		ret = _checktype.call_func(res)
	
	return ret


func drop_data(_position: Vector2, data) -> void:
	var files: Array = data.get("files", [])
	var res: Resource = load(files[0])
	emit_signal("new_instance", res)



func _init() -> void:
	prepend()
	
	add_child(_lblcurrent)
	_lblcurrent.text = "null"
	_lblcurrent.size_flags_horizontal = SIZE_EXPAND_FILL
	
	add_child(_optbutton)
	_optbutton.rect_min_size.x = 120
	_optbutton.text = "New instance of..."
	
	# warning-ignore:return_value_discarded
	_optbutton.get_popup().connect("index_pressed", self, "_on_index_pressed")


