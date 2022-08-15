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
extends "res://addons/keh_dataasset/editor/propeditors/ped_base.gd"


#######################################################################################################################
### Signals and definitions
const SpinSliderT: Script = preload("res://addons/keh_ui/spin_slider/spin_slider.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# Derived classes had trouble creating instances of the inner Component class. So, making a function that will create the
# instance and automatically add it into the _component array.
func create_component(lblname: String, deflabeltxt: String, colindex: int, funcname: String) -> void:
	var ncomp: Component = Component.new(lblname, deflabeltxt, colindex, funcname)
	
	# warning-ignore:return_value_discarded
	ncomp.spin.connect("value_changed", self, "_on_value_changed", [_component.size()])
	
	_component.append(ncomp)
	
	if (!_current_row):
		create_row()
	
	_current_row.add_child(ncomp.label)
	_current_row.add_child(ncomp.spin)


func update_component(compindex: int, nval: float) -> void:
	var comp: Component = _component[compindex]
	if (comp):
		comp.spin.value = nval


func force_min_val(mval: float) -> void:
	_force_min_val = true
	_min_val = mval

func force_step(val: float) -> void:
	_force_step = true
	_step = val


func create_row(row_label: String = "", mwidth_lbl: int = 0) -> void:
	if (!_current_row):
		# This check allows for derived classes to not have to explicitly call "_create_row()" whenever there is no need
		# for additional rows (which is the majority of the composite types)
		_generate_row(row_label, mwidth_lbl)
		return
	
	if (!_vbox):
		_vbox = VBoxContainer.new()
		_vbox.add_child(_current_row)
	
	_generate_row(row_label, mwidth_lbl)
	_vbox.add_child(_current_row)


func add_to_row(ctrl: Control) -> void:
	if (!_current_row):
		create_row()
	
	_current_row.add_child(ctrl)


#######################################################################################################################
### "Private" definitions
class Component extends Reference:
	const SpinSliderT: Script = preload("res://addons/keh_ui/spin_slider/spin_slider.gd")
	
	var label: Label = Label.new()
	var spin: SpinSliderT = SpinSliderT.new()
	
	# The setting name, as it will be retrieved from the dictionary
	var sname: String = ""
	# The default label value, as it will be retrieved from the settings dictionary
	var dlabel: String = ""
	
	# This will be used to calculate the label color
	var cindex: int = 0
	
	# Name of the function that will be called when this component is changed
	# Said function must return the full updated "composite" (Vector2, Vector3, Rect2 and so on)
	var funcname: String = ""
	
	func _init(sn: String, dl: String, idx: int, fname: String) -> void:
		sname = sn
		dlabel = dl
		cindex = idx
		funcname = fname
		
		spin.flat = true

#######################################################################################################################
### "Private" properties
# This will be applied to the labels
var _stylebox: StyleBoxFlat = StyleBoxFlat.new()


# If this is null then a single row of component editors will be added (which is the _current_row)
# Otherwise, if the 'create_row()' is called, then this will be set and _current_row will be appended into this one
# while a new _current_row will be created
var _vbox: VBoxContainer = null

var _current_row: HBoxContainer = HBoxContainer.new()

# Meant to hold instances of the inner Component class
var _component: Array = []

# A composite might not need some of the extra settings. Color, as an example, should enforce a minimum value of 0.
# So the following properties are used to bypass extra settings. A flag marked as true in here will mean that the
# settings entry will simply be ignored and the value next to it will be used
var _force_min_val: bool = false
var _min_val: float = 0.0

var _force_step: bool = false
var _step: float = 0.001

#######################################################################################################################
### "Private" functions
func _set_label(lbl: Label, index: int, basecolor: Color) -> void:
	var c: Color = basecolor
	c = c.from_hsv(float(index) / 3.0 + 0.05, c.s * 0.75, c.v)
	lbl.add_color_override("font_color", c)
	lbl.add_stylebox_override("normal", _stylebox)


func _generate_row(lbl: String, width: int) -> void:
	_current_row = HBoxContainer.new()
	
	if (!lbl.empty()):
		var rl: Label = Label.new()
		rl.text = lbl
		rl.rect_min_size.x = width
		_current_row.add_child(rl)
	
	elif (width > 0):
		# Label is meant to be empty, however a minimum width is desired. So create a "sizer control" for that task
		var sizer: Control = Control.new()
		sizer.rect_min_size.x = width
		_current_row.add_child(sizer)


#######################################################################################################################
### Event handlers
func _on_value_changed(nval: float, compindex: int) -> void:
	var comp: Component = _component[compindex]
	if (comp):
		notify_value_changed(call(comp.funcname, nval))


#######################################################################################################################
### Overrides
# Set value must be implemented in the "final class"
#func set_value(value) -> void:
#	pass


# "Final class" MUST override this in order to create the instances within the "_component" array
#func _init() -> void:
#	_component


func extra_setup(settings: Dictionary, _typeinfo: Dictionary) -> void:
	#var force_int: bool = settings.get("force_int", false)
	#var step: float = 1.0 if force_int else settings.get("step", 0.001)
	var step: float = _step
	if (!_force_step):
		var force_int: bool = settings.get("force_int", false)
		step = 1.0 if force_int else settings.get("step", 0.001)
	
	var use_min: bool = true if _force_min_val else settings.has("range_min")
	#var minval: float = settings.range_min if use_min else 0.0
	var minval: float = _min_val
	if (!_force_min_val && use_min):
		minval = settings.range_min
	var use_max: bool = settings.has("range_max")
	var maxval: float = settings.range_max if use_max else 0.0
	
	for i in _component.size():
		var c: Component = _component[i]
		if (c):
			c.label.text = settings.get(c.sname, c.dlabel)
			c.spin.step = step
			c.spin.use_min_value = use_min
			c.spin.min_value = minval
			c.spin.use_max_value = use_max
			c.spin.max_value = maxval



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			_stylebox.bg_color = get_color("dark_color_3", "Editor")
			_stylebox.content_margin_left = 4
			_stylebox.content_margin_top = 4
			_stylebox.content_margin_right = 4
			_stylebox.content_margin_bottom = 4
			
			var base: Color = get_color("accent_color", "Editor")
			
			for i in _component.size():
				var c: Component = _component[i]
				if (c):
					_set_label(c.label, c.cindex, base)


func _ready() -> void:
	if (!_vbox):
		# The Vertical box is not valid, meaning that a single row is enough. So, add it into the "right panel"
		_right.add_child(_current_row)
	
	else:
		# OK, the vertical box being valid means that multiple rows are desired. So, add that box into the right panel
		# All rows should already be inserted into the vertical box
		_right.add_child(_vbox)


