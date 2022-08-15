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
const DAHelperT: Script = preload("../dahelper.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
# The original intention was to use Tween node, however it didn't work, at all. So using this class to help interpolate
# the positioning of the entry node
class Interpolator extends Reference:
	const DURATION: float = 0.12
	var from_y: int = 0
	var to_y: int = 0
	var t0: float = 0.0
	
	func start() -> void:
		t0 = 0.0
	
	func tick(dt: float, node: Control) -> bool:
		t0 += dt
		if (t0 > DURATION):
			t0 = DURATION
		
		var alpha: float = t0 / DURATION
		if (alpha > 1.0):
			alpha = 1.0
		node.rect_position.y = lerp(from_y, to_y, alpha)
		
		return alpha >= 1.0


class AEntry extends HBoxContainer:
	var index: int = 0
	var lbl_index: Label = Label.new()
	var editorbox: VBoxContainer = VBoxContainer.new()
	var btremove: Button = Button.new()
	var attempting_drag: bool = false
	var dragging: bool = false
	var drag_offy: int = 0
	var interp: Interpolator = Interpolator.new()
	
	
	func add_editor_row(row: HBoxContainer) -> void:
		row.size_flags_vertical = SIZE_EXPAND_FILL
		editorbox.add_child(row)
	
	func set_index(i: int) -> void:
		index = i
		lbl_index.text = str(index)
	
	func smooth_move(to: int) -> void:
		interp.from_y = int(rect_position.y)
		interp.to_y = to
		interp.start()
		set_process(true)
	
	func _process(dt: float) -> void:
		if (interp.tick(dt, self)):
			set_process(false)
	
	
	# The events will trigger the parent container to re-position the entries when attempting to drag. Of course not the
	# most efficient way to deal with the repositioning.
	func _gui_input(evt: InputEvent) -> void:
		var mb: InputEventMouseButton = evt as InputEventMouseButton
		if (mb):
			if (mb.button_index == BUTTON_LEFT):
				if (mb.is_pressed()):
					attempting_drag = true
				
				else:
					if (dragging):
						get_parent().call("drag_ended")
						set_as_toplevel(false)
					
					attempting_drag = false
					dragging = false
		
		
		var mm: InputEventMouseMotion = evt as InputEventMouseMotion
		if (mm):
			if (get_parent().get_child_count() < 2):
				# If a single element there is no point in attempting to drag so just bail
				return
			
			if (mm.button_mask == BUTTON_MASK_LEFT && attempting_drag):
				if (!dragging):
					set_as_toplevel(true)
					dragging = true
					drag_offy = int(mm.position.y)
					
				get_parent().call("drag_started")
	
	
	func _draw() -> void:
		draw_rect(Rect2(Vector2(), rect_size), get_color("dark_color_2", "Editor"))
		
		btremove.icon = get_icon("Remove", "EditorIcons")
	
	func _ready() -> void:
		set_process(false)
	
	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
		mouse_filter = MOUSE_FILTER_PASS
		
		lbl_index.text = str(index)
		lbl_index.rect_min_size.x = 70
		lbl_index.align = Label.ALIGN_RIGHT
		
		editorbox.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		editorbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		btremove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btremove.hint_tooltip = "Remove"
		
		add_child(lbl_index)
		add_child(editorbox)
		add_child(btremove)



# Creating a custom vertical box for the contents just to allowing re-arranging entries through drag and drop.
class ContentBox extends Container:
	signal entry_moved(from, to)
	
	var minh: int = 0
	var is_dragging: bool = false
	
	func drag_started() -> void:
		is_dragging = true
		queue_sort()
	
	func drag_ended() -> void:
		is_dragging = false
		queue_sort()
	
	func move_position(node: Control, new_index: int) -> void:
		# Ideally it would be better to put "AEntry" instead of Control as the argument. However it was leading to
		# memory leaks on exit. Placing the static type inside the function resolved that.
		var ae: AEntry = node as AEntry
		if (!ae):
			return
		
		move_child(ae, new_index)
		for i in get_child_count():
			var child: AEntry = get_child(i) as AEntry
			child.set_index(i)
		
		emit_signal("entry_moved", ae.index, new_index)
	
	
	func _arrange() -> void:
		var ccount: int = get_child_count()
		var sep: int = get_constant("separation", "VBoxContainer")
		# At the end of refitting this will be tested. If not null then an entry has been dragged into a different position
		var dragged: AEntry = null
		# Will be used if the dragged (previous variable) is not null
		var dragged_to: int = -1
		
		minh = 0
		
		if (ccount == 0):
			return
		
		var sz: Vector2 = Vector2(rect_size.x, 0)
		
		for i in ccount:
			var child: AEntry = get_child(i) as AEntry
			if (!child):
				continue
			
			var expected_y: int = int(minh + sep)
			var pos: Vector2 = Vector2(0, expected_y)
			sz.y = child.get_combined_minimum_size().y
			
			if (child.dragging):
				pos.x = rect_global_position.x
				pos.y = get_global_mouse_position().y - child.drag_offy
				
				pos.y = clamp(pos.y, rect_global_position.y, rect_global_position.y + rect_size.y - sz.y)
				
				# Calculate the expected Y in terms of global positioning (as the dragged element is set as top level)
				var gexpected_y: int = int(rect_global_position.y + expected_y)
				var threshold: int = int(sz.y * 0.5)
				
				var dindex: int = child.index
				
				if (pos.y < gexpected_y && dindex > 0):
					var prev: AEntry = get_child(child.index - 1)
					
					# This is the (global) position the dragged item would sit at if switched place with the previous element
					var if_prev_y: int = int(gexpected_y - (prev.get_combined_minimum_size().y + sep))
					if (pos.y < if_prev_y + threshold):
						dindex = child.index - 1
				
				elif (pos.y > gexpected_y && dindex < ccount - 1):
					var next: AEntry = get_child(child.index + 1)
					
					# This is the (global) position the dragged item would sit at if switched place with the next element
					var if_next_y: int = int (gexpected_y + next.get_combined_minimum_size().y + sep)
					if (pos.y + sz.y > if_next_y + threshold):
						dindex = child.index + 1
				
				
				dindex = int(clamp(dindex, 0, ccount - 1))
				
				if (dindex != child.index):
					dragged = child
					dragged_to = dindex
				
				
				fit_child_in_rect(child, Rect2(pos, sz))
			
			else:
				if (is_dragging):
					child.rect_size = sz
					child.rect_position.x = 0
					child.smooth_move(int(pos.y))
				
				else:
					fit_child_in_rect(child, Rect2(pos, sz))
			
			minh += int(sz.y + sep)
		
		
		if (dragged):
			yield(get_tree(), "idle_frame")
			move_position(dragged, dragged_to)
		
		minimum_size_changed()
	
	func _get_minimum_size() -> Vector2:
		return Vector2(0, minh)
	
	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_SORT_CHILDREN:
				_arrange()



#######################################################################################################################
### "Private" properties
var _value: Array = []

var _lbl_err: Label = Label.new()
var _lbl_size: Label = Label.new()

var _tbar: HBoxContainer = HBoxContainer.new()
var _btclear: Button = Button.new()
var _contents: ContentBox = ContentBox.new()
var _btmappend: MenuButton = MenuButton.new()

# Hold the type of object to be held within the '_value' array. For custom scripted types this will be TYPE_OBJECT
var _type: int = -1

# If _type is TYPE_OBJECT, or scripted type, then this will hold an instance of the script
var _typescript: GDScript

# This holds the editor that will be used for each entry within the array
var _editor_t: GDScript

# This holds the string with the name of the type. Double purpose if the type is a core resource
var _type_name: String = ""

var _typeinfo: Dictionary = {}

# When dealing with non resource (core) types, this will hold the default value for that type. This is mostly to avoid
# having to create an instance of the editor just to get the value

#######################################################################################################################
### "Private" functions
func _show_error(show: bool) -> void:
	_lbl_err.visible = show
	_tbar.visible = !show
	_btmappend.visible = !show


func _check_tbar() -> void:
	_lbl_size.text = "Size = %d" % _value.size()
	_btclear.disabled = _value.size() == 0


func _append_entry(value, index: int) -> void:
	if (!_editor_t):
		return
	
	var settings: Dictionary = {}
	
	if (_type == TYPE_OBJECT):
		if (_typescript):
			if (value):
				settings["type"] = value.get_script().resource_path
			else:
				settings["type"] = _typescript.resource_path
			
		else:
			if (value):
				settings["type"] = value.get_class()
			else:
				settings["type"] = _type_name
	
	
	var editor: Control = _editor_t.new()
	editor.call("setup", "", value, settings, _typeinfo)
	
	var entry: AEntry = AEntry.new()
	entry.set_index(index)
	entry.add_editor_row(editor)
	
	# warning-ignore:return_value_discarded
	entry.btremove.connect("pressed", self, "_on_remove_entry", [entry])
	
	# warning-ignore:return_value_discarded
	editor.connect("value_changed", self, "_on_entry_changed", [entry])
	
	_contents.add_child(entry)




#######################################################################################################################
### Event handlers
func _on_append_selected(index: int) -> void:
	var append_at: int = _contents.get_child_count()
	# Relying on Variant here
	var new_value = null
	
	if (_type == TYPE_OBJECT):
		var pop: PopupMenu = _btmappend.get_popup()
		var seltext: String = pop.get_item_text(index)
		
		if (seltext == "<Null>"):
			pass
		
		else:
			var mval = pop.get_item_metadata(index)
			
			if (mval != null):
				# Requesting to create an instance of a scripted resource
				var script: GDScript = load(mval) as GDScript
				if (script):
					new_value = script.new()
			
			else:
				# Requesting to create an instance of a core resource
				new_value = ClassDB.instance(seltext)
	
	else:
		# This array is for a core non resource type, meaning that the popup menu contains a single item.
		new_value = DAHelperT.default_value.get(_type)
	
	_append_entry(new_value, append_at)
	_value.append(new_value)
	_check_tbar()




func _on_entry_changed(nval, entry: Control) -> void:
	var ae: AEntry = entry as AEntry
	if (!ae):
		return
	
	_value[ae.index] = nval


func _on_remove_entry(ctrl: Control) -> void:
	var entry: AEntry = ctrl as AEntry
	if (!entry):
		return
	
	_value.remove(entry.index)
	_contents.remove_child(entry)
	
	for i in range(entry.index, _contents.get_child_count()):
		var upd: AEntry = _contents.get_child(i)
		upd.set_index(i)
	
	entry.queue_free()
	
	_check_tbar()
	
	if (_value.size() == 0):
		_contents.minh = 0
		_contents.minimum_size_changed()



func _on_entry_moved(from: int, to: int) -> void:
	# Relying on variant here.
	var aux = _value[from]
	_value.remove(from)
	_value.insert(to, aux)



func _about_to_show_append_menu() -> void:
	var pop: PopupMenu = _btmappend.get_popup()
	pop.clear()
	
	if (_type == TYPE_OBJECT):
		pop.add_item("<Null>")
		
		# This is an array of resources
		if (_typescript):
			# More specifically of scripted resource
			# TODO: provide means to configure the second argument of this function. Often the base class might not be
			# desireable as instances
			DAHelperT.fill_scripted_class_popup(_typescript, true, pop)
		
		else:
			# Core resources
			DAHelperT.fill_core_class_popup(_type_name, pop)
	
	else:
		# This is an array for core, non resource, type
		pop.add_item(DAHelperT.typestrings[_type].type_name)


func _on_clear_clicked() -> void:
	# TODO: confirmation dialog box as this cannot be undone
	set_value([])
	_contents.minh = 0
	_contents.minimum_size_changed()
	notify_value_changed(_value)


#######################################################################################################################
### Overrides
func set_value(value) -> void:
	_value = value
	_check_tbar()
	
	while (_contents.get_child_count() > 0):
		var n: Node = _contents.get_child(0)
		_contents.remove_child(n)
		n.free()
	
	for i in _value.size():
		_append_entry(_value[i], i)


func extra_setup(settings: Dictionary, typeinfo: Dictionary) -> void:
	_typeinfo = typeinfo
	
	if (!settings.has("type")):
		return
	
	if (settings.type is int):
		var edt_t: Script = typeinfo.get(settings.type, null)
		if (edt_t):
			_type = settings.type
			_editor_t = edt_t
			
			_show_error(false)
		
		else:
			_lbl_err.text = "The provided element type '%s' for this array is not supported." % [DAHelperT.typestrings[settings.type].type_string]
	
	
	elif (settings.type is String):
		var tp: String = settings.type
		if (tp.begins_with("res://")):
			var script: Script = load(tp) as Script
			if (script):
				_type = TYPE_OBJECT
				_typescript = script
				_type_name = tp
				_editor_t = typeinfo.get(TYPE_OBJECT, null)
				
				_show_error(false)
			
			else:
				_lbl_err.text = "Unable to load script at '%s'." % tp
		
		
		else:
			if (ClassDB.class_exists(tp) && ClassDB.is_parent_class(tp, "Resource")):
				_type = TYPE_OBJECT
				_type_name = tp
				_editor_t = typeinfo.get(TYPE_OBJECT, null)
				
				_show_error(false)
			
			else:
				_lbl_err.text = "Invalid custom type specification. It must be a path to the resource script."
	
	else:
		_lbl_err.text = "Type specification must be a TYPE_* or the path to a custom resource script."


func _notification(what: int) -> void:
	match what:
			NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
				var sthover: StyleBox = get_stylebox("hover", "Button")
				var stpressed: StyleBox = get_stylebox("pressed", "Button")
				var stfocus: StyleBox = get_stylebox("focus", "Button")
				var stnormal: StyleBox = get_stylebox("normal", "Button")
				
				_btmappend.add_stylebox_override("hover", sthover)
				_btmappend.add_stylebox_override("pressed", stpressed)
				_btmappend.add_stylebox_override("focus", stfocus)
				_btmappend.add_stylebox_override("normal", stnormal)


func _init() -> void:
	var mainbox: VBoxContainer = VBoxContainer.new()
	_right.add_child(mainbox)
	
	mainbox.add_child(_lbl_err)
	mainbox.add_child(_tbar)
	mainbox.add_child(_contents)
	
	_lbl_err.autowrap = true
	_lbl_err.text = """No type has been specified for this array.
		Within the return value of the 'get_property_info()' add a Dictionary entry keyed by this array name containing a 'type' field.
		The value can be either an integer being a subset of one of the various TYPE_* or a String specifying the path to a Script defining a type."""
	
	_tbar.visible = false
	
	_tbar.add_child(_lbl_size)
	
	_tbar.add_child(_btclear)
	_btclear.text = "Clear"
	_btclear.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	
	mainbox.add_child(_btmappend)
	_btmappend.text = "Append..."
	_btmappend.flat = false
	_btmappend.visible = false
	
	# warning-ignore:return_value_discarded
	_btmappend.connect("about_to_show", self, "_about_to_show_append_menu")
	
	# warning-ignore:return_value_discarded
	_btmappend.get_popup().connect("index_pressed", self, "_on_append_selected")
	
	# warning-ignore:return_value_discarded
	_contents.connect("entry_moved", self, "_on_entry_moved")
	
	# warning-ignore:return_value_discarded
	_btclear.connect("pressed", self, "_on_clear_clicked")
	
	_check_tbar()
