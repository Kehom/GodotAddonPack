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
extends CustomControlBase
class_name ExpandablePanel

# TODO:
# - ATTEMPT to create a dummy font and assign it to the toggle buttons so their minimum height can be smaller than 14

#######################################################################################################################
### Signals and definitions
# Emitted whenever a toggle button corresponding to a page is clicked. The page index is given as argument
signal page_button_clicked(index)

# If expand animation is setup then this will be emitted when the panel starts to expand, providing the page index
# that will be shown as argument.
signal expand_started(page_index)

# When the panel finishes expanding, this is emitted, providing the active page index as argument
# This will always be emitted when the panel expands, even if no animation is setup
signal expand_finished(page_index)

# If shrink animation is setup then this will be emitted when the panel starts to shrink, providing the page index
# that will be hidden as argument.
signal shrink_started(page_index)

# When the panel finishes shrinking, this is emitted, providing the just closed page index as argument
# This will always be emitted when the panel shrinks, even if no animation is setup
signal shrink_finished(page_index)


const CNAME: String = "ExpandablePanel"


enum AttachTo {
	Left,
	Top,
	Right,
	Bottom,
}

const MIN_CONTENT_HEIGHT: int = 12
const MIN_CONTENT_WIDTH: int = 20

# These are the default icons used within the "toggle buttons". If no icon is provided then these arrows will be used
const _TX_ARROW_LEFT: Texture = preload("tx_left.png")
const _TX_ARROW_UP: Texture = preload("tx_up.png")
const _TX_ARROW_RIGHT: Texture = preload("tx_right.png")
const _TX_ARROW_DOWN: Texture = preload("tx_down.png")


#######################################################################################################################
### "Public" properties
export(AttachTo) var border: int = AttachTo.Left setget set_border

export var current_page: int = -1 setget set_current_page

export var toggle_button_separation: int = 10 setget set_button_separation

export var keep_toggle_button_focus: bool = false



#######################################################################################################################
### "Public" functions
func set_border(b: int) -> void:
	# This match is probably not entirely necessary, but makes validation of incoming value a lot easier
	match b:
		AttachTo.Top, AttachTo.Right, AttachTo.Bottom:
			border = b
		
		_:
			border = AttachTo.Left
	
	_check_pages()
	_check_layout()


func set_current_page(i: int) -> void:
	if (current_page == i):
		return
	
	if (i < -1 && i >= _page.size()):
		i = -1
	
	# Within the checks here:
	# - is_inside_tree() is necessary to ensure the panel will be expanded if the current_page is not set as -1 within
	# the editor. In other words, it can start in expanded state
	# - _shrink_time/_expand_time obviously need to be checked as if 0 then that animation is disabled
	# - requesting a different page + shrink animation on page change.
	var add_shrink: bool = (is_inside_tree() && _shrink_time > 0 && (i == -1 || _anim_shrink_on_change))
	var add_expand: bool = (is_inside_tree() && _expand_time > 0)
	
	if (current_page != -1):
		if (add_shrink):
			var astate: _AnimationState = _AnimationState.new()
			
			astate.targtime = _shrink_time
			
			match border:
				AttachTo.Left, AttachTo.Right:
					astate.starting = _content_size.x
				
				AttachTo.Top, AttachTo.Bottom:
					astate.starting = _content_size.y
			
			astate.ending = 0.0
			astate.tpage = current_page
			astate.curve = _shrink_curve
			_aniqueue.push_back(astate)
		
		else:
			call_deferred("emit_signal", "shrink_finished", current_page)
			current_page = -1
			add_expand = false
	
	
	if (i != -1):
		if (add_expand):
			var astate: _AnimationState = _AnimationState.new()
			
			astate.targtime = _expand_time
			
			match border:
				AttachTo.Left, AttachTo.Right:
					astate.ending = _content_size.x
				
				AttachTo.Top, AttachTo.Bottom:
					astate.ending = _content_size.y
			
			astate.starting = 0.0
			astate.tpage = i
			astate.curve = _expand_curve
			_aniqueue.push_back(astate)
		
		else:
			call_deferred("emit_signal", "expand_finished", i)
			current_page = i
	
	if (_aniqueue.size() > 0):
		if (_animate_on_physics):
			set_physics_process(true)
		else:
			set_process(true)
	
	else:
		_check_layout()


func get_page_name(index: int) -> String:
	if (index < 0 || index >= _page.size()):
		return ""
	
	var page: _Page = _page[index] as _Page
	if (page):
		return page.ctrl.get_name()
	
	return ""


func set_button_separation(v: int) -> void:
	toggle_button_separation = v
	
	_hbox.add_constant_override("separation", v)
	_vbox.add_constant_override("separation", v)


func set_update_on_physics(enable: bool) -> void:
	_animate_on_physics = enable

func get_update_on_physics() -> bool:
	return _animate_on_physics


func set_shrink_on_page_change(enable: bool) -> void:
	_anim_shrink_on_change = enable

func get_shrink_on_page_change() -> bool:
	return _anim_shrink_on_change


func set_expand_animation_time(seconds: float) -> void:
	_expand_time = max(0.0, seconds)

func get_expand_animation_time() -> float:
	return _expand_time


func set_expand_animation_curve(curve: Curve) -> void:
	_expand_curve = curve

func get_expand_animation_curve() -> Curve:
	return _expand_curve


func set_shrink_animation_time(seconds: float) -> void:
	_shrink_time = max(0.0, seconds)

func get_shrink_animation_time() -> float:
	return _shrink_time


func set_shrink_animation_curve(curve: Curve) -> void:
	_shrink_curve = curve

func get_shrink_animation_curve() -> Curve:
	return _shrink_curve


func set_page_button_expanded_icon(page_index: int, icon: Texture) -> void:
	if (page_index < 0 || page_index >= _page.size()):
		return
	
	var page: _Page = _page[page_index] as _Page
	if (page):
		page.expanded_icon = icon
	
	_check_layout()

func get_page_button_expanded_icon(page_index: int) -> Texture:
	if (page_index < 0 || page_index >= _page.size()):
		return null
	
	var page: _Page = _page[page_index] as _Page
	if (page):
		return page.expanded_icon
	
	return null


func set_page_button_shrinked_icon(page_index: int, icon: Texture) -> void:
	if (page_index < 0 || page_index >= _page.size()):
		return
	
	var page: _Page = _page[page_index ] as _Page
	if (page):
		page.shrinked_icon = icon
	
	_check_layout()

func get_page_button_shrinked_icon(page_index: int) -> Texture:
	if (page_index < 0 || page_index >= _page.size()):
		return null
	
	var page: _Page = _page[page_index] as _Page
	if (page):
		return page.shrinked_icon
	
	return null


func set_page_icon_color_modulation(page_index: int, color: Color) -> void:
	if (page_index < 0 || page_index >= _page.size()):
		return
	
	var page: _Page = _page[page_index] as _Page
	if (page):
		page.bt.set_mcolor(color)
	
	_check_layout()

func get_page_icon_color_modulation(page_index: int) -> Color:
	if (page_index < 0 || page_index >= _page.size()):
		return Color()
	
	var page: _Page = _page[page_index] as _Page
	if (page):
		return page.bt.get_mcolor()
	
	return Color()

#######################################################################################################################
### "Private" definitions
# The 'Button' Control contains an icon property. However this icon is only rendered at the left side of the button.
# The only customization that can be done is related to its size. More specifically, if the icon should be stretched
# or not in order to fully use the available space. This inner button places the icon at the center. Besides that,
# it also allows specifying a modulation color for the icon rendering.
class _IconButton extends Button:
	# If true then render the "expanded icon", otherwise the "shrinked icon"
	var expanded: bool = false
	
	# Expanded icon
	var _expi: Texture = null
	
	# Shrinked icon
	var _shri: Texture = null
	
	# Modulation color used to render the icon
	var _mcolor: Color = Color(1.0, 1.0, 1.0, 1.0)
	
	
	func set_expanded(e: bool) -> void:
		if (expanded != e):
			expanded = e
			update()
	
	
	func set_icons(e: Texture, s: Texture) -> void:
		_expi = e
		_shri = s
		update()
	
	func set_mcolor(c: Color) -> void:
		_mcolor = c
		update()
	
	func get_mcolor() -> Color:
		return _mcolor
	
	
	func _draw() -> void:
		var ic: Texture = _expi if expanded else _shri
		
		if (!ic):
			return
		
		var x: float = (rect_size.x - ic.get_width()) * 0.5
		var y: float = (rect_size.y - ic.get_height()) * 0.5
		
		draw_texture_rect(ic, Rect2(Vector2(x, y), Vector2(ic.get_width(), ic.get_height())), false, _mcolor)



# This inner class is meant to help hold some information to correctly perform internal upkeep
class _Page extends Reference:
	# The page index
	var index: int = -1
	
	# The Control representing this page - the node that triggered the creation of an instance of this class
	var ctrl: Control = null
	
	# Toggle button - expands or shrinks the corresponding page.
	var bt: _IconButton = null
	
	# Those are the icons assigned to the bt button. If null then the default ones will be used
	var expanded_icon: Texture = null
	var shrinked_icon: Texture = null
	
	
	func _init(i: int, c: Control) -> void:
		index = i
		ctrl = c


# Depeding on how the animation system is configured, multiple animation sequences will need to be queued. Namely, if
# it's set to shrink first before expanding into a different page. To make things easier, this inner class is used to
# store "animation targets" as well as their states (mostly the time taken).
class _AnimationState extends Reference:
	# Elapsed time
	var time: float = 0.0
	
	# Target time
	var targtime: float = 0.0
	
	# The animation will only change either the width or the height of the main control. This holds the starting value
	# Which one will be dealt with within the animation processing itself
	var starting: float = -1.0
	
	# And this holds the ending size of the width/height
	var ending: float = -1.0
	
	# This is the page index affected by the animation described by this instance
	var tpage: int = -1
	
	# Which curve to use. If not  valid then the "alpha" will be directly used, resulting in a liner interpolation
	var curve: Curve = null
	
	func is_expanding() -> bool:
		return starting < ending
	
	func update(dt: float) -> bool:
		time += dt
		return time >= targtime
	
	func calculate() -> float:
		var alpha: float = (time / targtime) if targtime > 0 else 1.0
		
		if (curve):
			alpha = curve.interpolate(alpha)
		
		return lerp(starting, ending, alpha)



#######################################################################################################################
### "Private" properties
# Hold here the size of the contents.  This is necessary in order to properly expand/shrink the panel. This will
# be serialized. Check the _get_property_list() function
var _content_size: Vector2 = Vector2(MIN_CONTENT_WIDTH, MIN_CONTENT_HEIGHT)

# This will be used to "lock" the content size. If this is true then the on_rect_change event handle should not change
# the _content_size property
var _csize_locked: bool = false


# The boxes that will hold "page buttons"
var _vbox: VBoxContainer = VBoxContainer.new()
var _hbox: HBoxContainer = HBoxContainer.new()

# Holds instances of _Page. This array is primarily used for iteration and correct page order within the Inspector
var _page: Array = []

# This Dictionary is primarily used to hold the instances of the pages given their names. In this way, clearing the
# '_page' array should not be too problematic as the dictionary will continue holding the page instances
var _nametopage: Dictionary = {}


# This dictionary is used to serialize page settings. The thing is, each page can contain its own settings for buttons
# and colors. Serialization of that data does not work entirely when directly dealing with the inner _Page class.
# Well, actually it doesn't work at all. Data is saved but never loaded. Then at the next save the data is overwritten
# back to the default values. As a work around this dictionary holds the relevant data and is serialized.
# The idea here is that each page generates an entry, which should be an inner dictionary containing the individual
# values that can be changed (those properties that are exposed within the Inspector).
var _pagedata: Dictionary = {}

# Determines the animation time to expand the panel
var _expand_time: float = 0.25

# Determines the curve that will be used as interpolation alpha when expanding the panel. This SHOULD be in the [0..1]
# range (which is the default for Curve resources). If this is not set then a simple linear alpha will be used.
var _expand_curve: Curve = null

# Determines the animation time to shrink the panel
var _shrink_time: float = 0.15

# Determines the curve that will be used as interpolation alpha when shrinking the panel. This SHOULD be in the [0..1]
# range (which is the default for Curve resources). If this is not set then a simple linear alpha will be used
var _shrink_curve: Curve = null


# This is meant mostly for editing purposes. The idea is that in the editor this one is changed in order to display a
# different page than the "current_page". In a way, when in editor this will take precedence over the current page
# property, while it will be completely ignored when running.
var _preview_page: int = 0


# If this is true then animation will be updated on _physics_process() instead of _process
var _animate_on_physics: bool = false

# If this is true then the shrink animation will be played when changing active page. Otherwise the contents of the
# selected page will be immediatelly shown
var _anim_shrink_on_change: bool = true


# Holds instances of the inner _AnimationState class.
var _aniqueue: Array = []


# If this control is being removed from the tree while it contains "pages", then errors will be emitted because the
# layout checking will be called as those children nodes will be removed first. To prevent that this property is used
# as a flag indicating if this node is being removed or not. Unfortunatelly the "is_queued_for_deletion()" is not
# working
var _being_removed: bool = false

#######################################################################################################################
### "Private" functions
func _get_current_page() -> int:
	if (Engine.is_editor_hint() && _page.size() > 0):
		return _preview_page
	
	return current_page


func _lock_csize() -> void:
	_csize_locked = true

func _unlock_csize() -> void:
	# Defer the call to unlock, otherwise things may change unexpectedly
	call_deferred("set", "_csize_locked", false)


func _get_button_width() -> int:
	var ret: int = 14
	
	match border:
		AttachTo.Left, AttachTo.Right:
			ret = get_theme_constant("leftright_width", CNAME)
		
		AttachTo.Top, AttachTo.Bottom:
			ret = get_theme_constant("updown_width", CNAME)
	
	if (ret < 14):
		ret = 14
	
	return ret

func _get_button_height() -> int:
	var ret: int = 14
	
	match border:
		AttachTo.Left, AttachTo.Right:
			ret = get_theme_constant("leftright_height", CNAME)
		
		AttachTo.Top, AttachTo.Bottom:
			ret = get_theme_constant("updown_height", CNAME)
	
	if (ret < 14):
		ret = 14
	
	return ret


func _get_bar_width() -> int:
	var btw: int = _get_button_width()
	var barstl: StyleBox = get_theme_stylebox("bar", CNAME)
	
	return int(barstl.get_margin(MARGIN_LEFT) + barstl.get_margin(MARGIN_RIGHT) + btw)

func _get_bar_height() -> int:
	var bth: int = _get_button_height()
	var barstl: StyleBox = get_theme_stylebox("bar", CNAME)
	
	return int(barstl.get_margin(MARGIN_TOP) + barstl.get_margin(MARGIN_BOTTOM) + bth)


func _get_ctrl_width() -> int:
	var ret: int = _get_bar_width()
	
	if (_aniqueue.size() > 0 && (border == AttachTo.Left || border == AttachTo.Right)):
		var astate: _AnimationState = _aniqueue[0] as _AnimationState
		ret += int(astate.calculate())
	
	elif (_get_current_page() != -1):
		ret += int(_content_size.x)
	
	
	return ret

func _get_ctrl_height() -> int:
	var ret: int = _get_bar_height()
	
	if (_aniqueue.size() > 0 && (border == AttachTo.Top || border == AttachTo.Bottom)):
		var astate: _AnimationState = _aniqueue[0] as _AnimationState
		ret += int(astate.calculate())
	
	elif (_get_current_page() != -1):
		ret += int(_content_size.y)
	
	return ret



func _set_content_width(w: float) -> void:
	if (_csize_locked):
		return
	
	_content_size.x = w

func _set_content_height(h: float) -> void:
	if (_csize_locked):
		return
	
	_content_size.y = h



# The idea is that when this is called every single entry within the inner _Page array has been properly deleted. This
# also assumes the inner container boxes are empty too.
func _check_pages() -> void:
	# Clear both button containers. It's a lot easier than performing strict upkeep
	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.free()
	
	for c in _hbox.get_children():
		_hbox.remove_child(c)
		c.free()
		
	# Initially hide both panels. The correct one will be set to visible shortly
	_hbox.visible = false
	_vbox.visible = false
	
	var container: BoxContainer = null
	
	match border:
		AttachTo.Left, AttachTo.Right:
			container = _vbox
		
		AttachTo.Top, AttachTo.Bottom:
			container = _hbox
	
	
	if (!container):
		push_error("Attempting to verify pages but apparently the border property is incorrect")
		return
	
	# Ensure the correct button container is visible
	container.visible = true
	
	# Clear the page array. Again, alot easier than simply performing upkeep on small changes
	_page.clear()
	
	# Compare the page map with the children of the panel. Any entry within the map that is not present within the
	# children list must be removed
	var pgkeys: Array = _nametopage.keys()
	for pgname in pgkeys:
		if (get_node_or_null(pgname) == null):
			# warning-ignore:return_value_discarded
			_nametopage.erase(pgname)
			
			_remove_page_data(pgname)
	
	
	
	var idx: int = 0
	for c in get_children():
		if (c == _vbox || c == _hbox || !(c is Control)):
			continue
		
		var cname: String = c.get_name()
		
		var pg: _Page = _nametopage.get(cname, null)
		
		if (!pg):
			# In here the page does not exist. It must be created
			pg = _Page.new(idx, c)
			
			_nametopage[cname] = pg
		
		
		# Setup the button - at the beginning of this function the button containers were cleared so new ones must be
		# created
		pg.bt = _IconButton.new()
		pg.bt.set_name("_bt_toggle_%s" % cname)
		pg.bt.hint_tooltip = cname
		
		_set_bt_style(pg.bt, _get_button_width(), _get_button_height(), idx == _get_current_page())
		
		# warning-ignore:return_value_discarded
		pg.bt.connect("pressed", self, "_on_page_button_clicked", [idx])
		
		# Attempt to load the page data.
		_load_page_data(pg)
		
		container.add_child(pg.bt)
		
		# The page array has been cleared. Add the page entry
		_page.append(pg)
		
		# Update the page index
		idx += 1
	
	container.update()


func _set_bt_style(bt: Button, w: int, h: int, expanded: bool) -> void:
	var affix: String = "expanded" if expanded else "shrinked"
	
	bt.add_stylebox_override("hover", get_theme_stylebox("button_%s_hover" % affix, CNAME))
	bt.add_stylebox_override("pressed", get_theme_stylebox("button_%s_pressed"  % affix, CNAME))
	bt.add_stylebox_override("focus", get_theme_stylebox("button_%s_focus" % affix, CNAME))
	bt.add_stylebox_override("normal", get_theme_stylebox("button_%s_normal" % affix, CNAME))
	
	bt.rect_min_size = Vector2(w, h)
	bt.rect_size = Vector2(w, h)




func _check_layout() -> void:
	if (_being_removed):
		return
	
	_lock_csize()
	
	# For some absolutelly frustrating reason, set_anchors_preset() or set_anchors_and_margins_preset() simply do
	# nothing to either the main panel or the inner toggle button. Unfortunatelly must change each anchor and each
	# margin individually.
	var btw: int = _get_button_width()
	var bth: int = _get_button_height()
	
	
	var stlbg: StyleBox = get_theme_stylebox("background", CNAME)
	var stlbar: StyleBox = get_theme_stylebox("bar", CNAME)
	
	# To make things easier, obtain the bar margins
	var bml: int = int(stlbar.get_margin(MARGIN_LEFT))
	var bmt: int = int(stlbar.get_margin(MARGIN_TOP))
	var bmr: int = int(stlbar.get_margin(MARGIN_RIGHT))
	var bmb: int = int(stlbar.get_margin(MARGIN_BOTTOM))
	
	# These are to define the margins of the content pages
	var cml: int = int(stlbg.get_margin(MARGIN_LEFT))
	var cmt: int = int(stlbg.get_margin(MARGIN_TOP))
	var cmr: int = int(-stlbg.get_margin(MARGIN_RIGHT))
	var cmb: int = int(-stlbg.get_margin(MARGIN_BOTTOM))
	
	# Default expanded and shrinked button icons. Assume panel is attached to the left border
	var exp_icon: Texture = _TX_ARROW_LEFT
	var shk_icon: Texture = _TX_ARROW_RIGHT
	
	match border:
		AttachTo.Left:
			UIHelper.set_anchor_points(self, 0.0, 0.0, 0.0, 1.0)
			UIHelper.set_margins(self, 0, 0, _get_ctrl_width(), 0)
			
			UIHelper.set_anchor_points(_vbox, 1.0, 0.0, 1.0, 1.0)
			UIHelper.set_margins(_vbox, -btw - bmr, bmt, -bmr, -bmb)
			
			cmr -= _get_bar_width()
		
		AttachTo.Top:
			UIHelper.set_anchor_points(self, 0.0, 0.0, 1.0, 0.0)
			UIHelper.set_margins(self, 0, 0, 0, _get_ctrl_height())
			
			UIHelper.set_anchor_points(_hbox, 0.0, 1.0, 1.0, 1.0)
			UIHelper.set_margins(_hbox, bml, -bth - bmt, -bmr, -bmb)
			
			cmb -= _get_bar_height()
			
			exp_icon = _TX_ARROW_UP
			shk_icon = _TX_ARROW_DOWN
		
		AttachTo.Right:
			UIHelper.set_anchor_points(self, 1.0, 0.0, 1.0, 1.0)
			UIHelper.set_margins(self, -_get_ctrl_width(), 0, 0, 0)
			
			UIHelper.set_anchor_points(_vbox, 0.0, 0.0, 0.0, 1.0)
			UIHelper.set_margins(_vbox, bml, bmt, btw, -bmb)
			
			cml += _get_bar_width()
			
			exp_icon = _TX_ARROW_RIGHT
			shk_icon = _TX_ARROW_LEFT
		
		AttachTo.Bottom:
			UIHelper.set_anchor_points(self, 0.0, 1.0, 1.0, 1.0)
			UIHelper.set_margins(self, 0, -_get_ctrl_height(), 0, 0)
			
			UIHelper.set_anchor_points(_hbox, 0.0, 0.0, 1.0, 0.0)
			UIHelper.set_margins(_hbox, bml, bmt, -bmr, bth)
			
			cmt += _get_bar_height()
			
			exp_icon = _TX_ARROW_DOWN
			shk_icon = _TX_ARROW_UP
	
	
	var cpage: int = _get_current_page()
	
	
	for gp in _page:
		var p: _Page = gp as _Page
		
		var expanded: bool = (cpage == p.index)
		
		UIHelper.set_anchor_points(p.ctrl, 0.0, 0.0, 1.0, 1.0)
		UIHelper.set_margins(p.ctrl, cml, cmt, cmr, cmb)
		
		p.ctrl.visible = expanded
		p.ctrl.set_meta("_edit_lock_", true)
		
		_set_bt_style(p.bt, btw, bth, expanded)
		
		var ei: Texture = exp_icon if !p.expanded_icon else p.expanded_icon
		var si: Texture = shk_icon if !p.shrinked_icon else p.shrinked_icon
		
		p.bt.set_icons(ei, si)
		p.bt.set_expanded(expanded)
	
	
	_unlock_csize()
	update()



func _save_page_data(page: _Page) -> void:
	_pagedata[page.ctrl.get_name()] = {
		"expanded_icon": page.expanded_icon,
		"shrinked_icon": page.shrinked_icon,
		"icon_color": page.bt.get_mcolor(),
	}


func _load_page_data(page: _Page) -> void:
	var pdata: Dictionary = _pagedata.get(page.ctrl.get_name(), {})
	
	if (!pdata.empty()):
		page.expanded_icon = pdata.expanded_icon
		page.shrinked_icon = pdata.shrinked_icon
		page.bt.set_mcolor(pdata.icon_color)
	
	else:
		_save_page_data(page)


func _remove_page_data(pgname) -> void:
	# warning-ignore:return_value_discarded
	_pagedata.erase(pgname)




func _are_anchors_correct() -> bool:
	# Assume anchors are correct
	var ret: bool = true
	
	var al: float = anchor_left
	var at: float = anchor_top
	var ar: float = anchor_right
	var ab: float = anchor_bottom
	
	if (al == 0 && at == 0 && ar == 0 && ab == 1):
		ret = (border == AttachTo.Left)
	
	elif (al == 0 && at == 0 && ar == 1 && ab == 0):
		ret = (border == AttachTo.Top)
	
	elif (al == 1 && at == 0 && ar == 1 && ab == 1):
		ret = (border == AttachTo.Right)
	
	elif (al == 0 && at == 1 && ar == 1 && ab == 1):
		ret = (border == AttachTo.Bottom)
	
	else:
		ret = false
	
	return ret



# When this script is changed and saved, the dynamically created Controls are not automatically deleted, however new
# ones are created and attached into this one. The result is that some stray Controls remain withinthe panel and they
# do interfere with the development. This function is meant to perform cleanup of those left overs. This should not be
# a problem when the Control is in use.
func _stray_cleanup() -> void:
	# Attempt to retrieve the inner children
	var vbn: Node = get_node_or_null("__vertical_box__")
	var hbn: Node = get_node_or_null("__horizontal_box__")
	
	if (vbn):
		remove_child(vbn)
		vbn.free()
	
	if (hbn):
		remove_child(hbn)
		hbn.free()



func _handle_anim(dt: float) -> void:
	if (_aniqueue.size() == 0):
		set_process(false)
		set_physics_process(false)
		return
	
	var astate: _AnimationState = _aniqueue[0]
	
	if (astate.time == 0):
		if (astate.is_expanding()):
			emit_signal("expand_started", astate.tpage)
		
		else:
			emit_signal("shrink_started", astate.tpage)
	
	
	#if (astate.tpage != -1):
	if (astate.is_expanding()):
		# Change to the target page if current animation state is expanding the panel. This will reveal the contents as
		# the panel expands.
		current_page = astate.tpage
	
	
	if (astate.update(dt)):
		_aniqueue.pop_front()
		
		if (!astate.is_expanding()):
			current_page = -1
		
		# This part of the animation has finished. Notify
		if (astate.is_expanding()):
			emit_signal("expand_finished", astate.tpage)
		
		else:
			emit_signal("shrink_finished", astate.tpage)
	
	_check_layout()




#######################################################################################################################
### Event handlers
func _on_tree_exiting() -> void:
	_being_removed = true
	
	if (!is_inside_tree()):
		return
	
	var t: SceneTree = get_tree()
	if (!t):
		return
	
	
	if (t.is_connected("node_added", self, "_on_node_added")):
		t.disconnect("node_added", self, "_on_node_added")
	
	if (t.is_connected("node_removed", self, "_on_node_removed")):
		t.disconnect("node_removed", self, "_on_node_removed")
	
	if (t.is_connected("node_renamed", self, "_on_node_renamed")):
		t.disconnect("node_renamed", self, "_on_node_renamed")


func _on_node_added(n: Node) -> void:
	if (n.get_parent() == self && n != _vbox && n != _hbox):
		call_deferred("_check_pages")
		call_deferred("_check_layout")


func _on_node_removed(n: Node) -> void:
	if (n.get_parent() == self && n != _vbox && n != _hbox):
		# In here must defer the checks because the "page" control might still be part of the tree, but is being removed
		call_deferred("_check_pages")
		call_deferred("_check_layout")


func _on_node_renamed(n: Node) -> void:
	# At this point the node is already holding its new name. However the corresponding _Page instance does have a
	# reference to the node itself. So most locate the correct instance then update the page map and the page data
	# dictionaries
	var page: _Page = null
	
	for pg in _page:
		var p: _Page = pg as _Page
		
		if (!p):
			continue
		
		if (p.ctrl == n):
			page = p
			break
	
	if (page):
		_nametopage[n.get_name()] = page
		_save_page_data(page)
		
		# This will remove the old entry from both _nametopage and _pagedata dictionaries
		_check_pages()
		_check_layout()



func _on_page_changed() -> void:
	call_deferred("_check_pages")
	call_deferred("_check_layout")




func _on_page_button_clicked(index: int) -> void:
	set_current_page(index if index != current_page else -1)
	
	if (!keep_toggle_button_focus):
		var page: _Page = _page[index] as _Page
		
		if (page):
			page.bt.release_focus()
	
	emit_signal("page_button_clicked", index)




func _DEBUG_draw_box(b: BoxContainer) -> void:
	b.draw_rect(Rect2(Vector2(), b.rect_size), Color(1.0, 0.0, 0.0))




#######################################################################################################################
### Overrides
# The CustomControlBase call this in order to create entries within the Theme object
func _create_custom_theme() -> void:
	var stlbg: StyleBoxFlat = StyleBoxFlat.new()
	stlbg.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	stlbg.border_color = Color(0.2, 0.2, 0.2, 1.0)
	UIHelper.set_stylebox_border(stlbg, 2, 2, 2, 2)
	UIHelper.set_stylebox_margin(stlbg, 4, 4, 4, 4)
	
	add_theme_stylebox("background", stlbg)
	
	var stlbar: StyleBoxFlat = StyleBoxFlat.new()
	stlbar.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	UIHelper.set_stylebox_margin(stlbar, 2, 2, 2, 2)
	
	add_theme_stylebox("bar", stlbar)
	
	
	# Styles for buttons when panel is expanded
	var stlbteh: StyleBoxFlat = StyleBoxFlat.new()
	stlbteh.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	stlbteh.border_color = Color(0.55, 0.55, 0.65, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbteh, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbteh, 1, 1, 1, 1)
	add_theme_stylebox("button_expanded_hover", stlbteh)
	
	var stlbtep: StyleBoxFlat = StyleBoxFlat.new()
	stlbtep.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	stlbtep.border_color = Color(0.12, 0.12, 0.33, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtep, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtep, 1, 1, 1, 1)
	add_theme_stylebox("button_expanded_pressed", stlbtep)
	
	var stlbtef: StyleBoxFlat = StyleBoxFlat.new()
	stlbtef.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	stlbtef.border_color = Color(0.22, 0.22, 0.53, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtef, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtef, 1, 1, 1, 1)
	add_theme_stylebox("button_expanded_focus", stlbtef)
	
	var stlbten: StyleBoxFlat = StyleBoxFlat.new()
	stlbten.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	stlbten.border_color = Color(0.12, 0.12, .33, 1)
	UIHelper.set_stylebox_corner_radius(stlbten, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbten, 1, 1, 1, 1)
	add_theme_stylebox("button_expanded_normal", stlbten)
	
	
	# Styles for buttons when panel is shrinked
	var stlbtsh: StyleBoxFlat = StyleBoxFlat.new()
	stlbtsh.bg_color = Color(0.35, 0.35, 0.45, 1.0)
	stlbtsh.border_color = Color(0.53, 0.53, 0.53, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtsh, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtsh, 1, 1, 1, 1)
	add_theme_stylebox("button_shrinked_hover", stlbtsh)
	
	var stlbtsp: StyleBoxFlat = StyleBoxFlat.new()
	stlbtsp.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	stlbtsp.border_color = Color(0.12, 0.12, 0.33, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtsp, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtsp, 1, 1, 1, 1)
	add_theme_stylebox("button_shrinked_pressed", stlbtsp)
	
	var stlbtsf: StyleBoxFlat = StyleBoxFlat.new()
	stlbtsf.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	stlbtsf.border_color = Color(0.22, 0.22, 0.53, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtsf, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtsf, 1, 1, 1, 1)
	add_theme_stylebox("button_shrinked_focus", stlbtsf)
	
	var stlbtsn: StyleBoxFlat = StyleBoxFlat.new()
	stlbtsn.bg_color = Color(0.35, 0.35, 0.45, 1.0)
	stlbtsn.border_color = Color(0.12, 0.12, 0.33, 1.0)
	UIHelper.set_stylebox_corner_radius(stlbtsn, 2, 2, 2, 2)
	UIHelper.set_stylebox_border(stlbtsn, 1, 1, 1, 1)
	add_theme_stylebox("button_shrinked_normal", stlbtsn)
	
	
	
	# Range 14..500, allowing greater values, but not allowing lesser values
	add_theme_constant_range("updown_width", 25, 14, 500, false, true)
	add_theme_constant_range("updown_height", 14, 14, 500, false, true)
	add_theme_constant_range("leftright_width", 14, 14, 500, false, true)
	add_theme_constant_range("leftright_height", 25, 14, 500, false, true)
	
	
	rect_min_size = Vector2(5, 5)
	_check_layout()
	call_deferred("update")


func _process(dt: float) -> void:
	_handle_anim(dt)


func _physics_process(dt: float) -> void:
	_handle_anim(dt)




func _draw() -> void:
	var bg: StyleBox = get_theme_stylebox("background", CNAME)
	var stlbar: StyleBox = get_theme_stylebox("bar", CNAME)
	
	var bgrect: Rect2 = Rect2()
	var barrect: Rect2 = Rect2()
	
	var bhmargin: int = int(stlbar.get_margin(MARGIN_LEFT) + stlbar.get_margin(MARGIN_RIGHT))
	var bvmargin: int = int(stlbar.get_margin(MARGIN_TOP) + stlbar.get_margin(MARGIN_BOTTOM))
	
	var cwidth: float = rect_size.x - _get_bar_width()
	var cheight: float = rect_size.y - _get_bar_height()
	
	match border:
		AttachTo.Left:
			bgrect.size = Vector2(cwidth, rect_size.y)
			
			barrect.position.x = cwidth if (_get_current_page() != -1) else 0.0
			barrect.size = Vector2(bhmargin + _vbox.rect_size.x, rect_size.y)
		
		AttachTo.Top:
			bgrect.size = Vector2(rect_size.x, cheight)
			
			barrect.position.y = cheight if (_get_current_page() != -1) else 0.0
			barrect.size = Vector2(rect_size.x, _hbox.rect_size.y + bvmargin)
		
		AttachTo.Right:
			bgrect.size = Vector2(cwidth, rect_size.y)
			bgrect.position.x = _get_bar_width() if (_get_current_page() != -1) else 0
			
			barrect.size = Vector2(bhmargin + _vbox.rect_size.x, rect_size.y)
			
		
		AttachTo.Bottom:
			bgrect.size = Vector2(rect_size.x, cheight)
			bgrect.position.y = _get_bar_height() if (_get_current_page() != -1) else 0
			
			barrect.size = Vector2(rect_size.x, bvmargin + _hbox.rect_size.y)
	
	if (_get_current_page() != -1):
		draw_style_box(bg, bgrect)
	
	
	draw_style_box(stlbar, barrect)






# _content_size must be serialized but it's not meant to be exposed. So use the next three functions to force this
# serialization
func _get_property_list() -> Array:
	var ret: Array = []
	
	
	ret.append({
		"name": "animation/update_on_physics",
		"type": TYPE_BOOL,
	})
	
	ret.append({
		"name": "animation/shrink_on_page_change",
		"type": TYPE_BOOL
	})
	
	ret.append({
		"name": "animation/expand_time",
		"type": TYPE_REAL,
	})
	
	if (_expand_time > 0):
		ret.append({
			"name": "animation/expand_curve",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Curve"
		})
	
	ret.append({
		"name": "animation/shrink_time",
		"type": TYPE_REAL,
	})
	
	if (_shrink_time > 0):
		ret.append({
			"name": "animation/shrink_curve",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Curve"
		})
	
	
	if (_page.size() > 0):
		# Should this be serialized?
		ret.append({
			"name": "pages/preview",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,%d" % (_page.size() - 1),
		})
	
	ret.append({
		"name": "__content_size",
		"type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_STORAGE,       # This is the "magic" to serialize the property without exposing it
	})
	
	ret.append({
		"name": "__page_data",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE,
	})
	
	
	for pg in _page:
		var p: _Page = pg as _Page
		
		if (p):
			# None of the following properties should be directly serialized. That doesn't fully work. Because the relevant
			# data is being saved/loaded with a different property (__page_data - _pagedata dictionary), there is no point
			# in storing those values again, which will not serve any purpose other than increse the resource size.
			
			ret.append({
				"name": ("pages/%s/icon_expanded" % p.ctrl.get_name()),
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "Texture",
				"usage": PROPERTY_USAGE_EDITOR,
			})
			
			ret.append({
				"name": ("pages/%s/icon_shrinked" % p.ctrl.get_name()),
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "Texture",
				"usage": PROPERTY_USAGE_EDITOR,
			})
			
			ret.append({
				"name": ("pages/%s/icon_color" % p.ctrl.get_name()),
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_EDITOR,
			})
	
	
	return ret

func _set(propname: String, value) -> bool:
	match (propname):
		"animation/update_on_physics":
			_animate_on_physics = value
			return true
		
		"animation/shrink_on_page_change":
			_anim_shrink_on_change = value
			return true
		
		"animation/expand_time":
			# Use max here so this value never goes bellow 0
			_expand_time = max(value, 0.0)
			return true
		
		"animation/expand_curve":
			_expand_curve = value
			return true
		
		"animation/shrink_time":
			# Use max here so this value never goes bellow 0
			_shrink_time = max(value, 0.0)
			return true
		
		"animation/shrink_curve":
			_shrink_curve = value
			return true
		
		"__content_size":
			_content_size = value
			return true
		
		"__page_data":
			_pagedata = value
			return true
		
		"pages/preview":
			_preview_page = value
			call_deferred("_check_layout")
			return true
	
	# The properties associated with pages begin with the page name. Extract that
	var propsection: PoolStringArray = propname.split("/", true, 2)
	
	if (propsection[0] == "pages"):
		var page: _Page = _nametopage.get(propsection[1], null)
		
		if (page):
			match propsection[2]:
				"icon_expanded":
					page.expanded_icon = value
				
				"icon_shrinked":
					page.shrinked_icon = value
				
				"icon_color":
					page.bt.set_mcolor(value)
			
			_save_page_data(page)
	
	
	return false

func _get(propname: String):
	match propname:
		"animation/update_on_physics":
			return _animate_on_physics
		
		"animation/shrink_on_page_change":
			return _anim_shrink_on_change
		
		"animation/expand_time":
			return _expand_time
		
		"animation/expand_curve":
			return _expand_curve
		
		"animation/shrink_time":
			return _shrink_time
		
		"animation/shrink_curve":
			return _shrink_curve
		
		"__content_size":
			return _content_size
		
		"__page_data":
			return _pagedata
		
		"pages/preview":
			return _preview_page
	
	var propsection: PoolStringArray = propname.split("/", true, 2)
	
	if (propsection[0] == "pages"):
		var page: _Page = _nametopage.get(propsection[1], null)
		
		if (page):
			match propsection[2]:
				"icon_expanded":
					return page.expanded_icon
				
				"icon_shrinked":
					return page.shrinked_icon
				
				"icon_color":
					return page.bt.get_mcolor()
	
	
	return null




func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if (_are_anchors_correct() && Engine.is_editor_hint()):
				match border:
					AttachTo.Left, AttachTo.Right:
						_set_content_width(rect_size.x - _get_bar_width())
					
					AttachTo.Top, AttachTo.Bottom:
						_set_content_height(rect_size.y - _get_bar_height())
			
			else:
				_check_layout()
			
			update()
		
		NOTIFICATION_EXIT_TREE, NOTIFICATION_PREDELETE:
			_on_tree_exiting()
		
		
		NOTIFICATION_POST_ENTER_TREE:
			# In editor when the scene tab is changed, the _being_removed will be set to true but the node will not be
			# actually deleted.
			if (_being_removed):
				_being_removed = false
			
			call_deferred("_check_layout")





func _enter_tree() -> void:
	if (Engine.is_editor_hint()):
		var t: SceneTree = get_tree()
		
		if (!t.is_connected("node_added", self, "_on_node_added")):
			# warning-ignore:return_value_discarded
			t.connect("node_added", self, "_on_node_added")
		
		if (!t.is_connected("node_removed", self, "_on_node_removed")):
			# warning-ignore:return_value_discarded
			t.connect("node_removed", self, "_on_node_removed")
		
		if (!t.is_connected("node_renamed", self, "_on_node_renamed")):
			# warning-ignore:return_value_discarded
			t.connect("node_renamed", self, "_on_node_renamed")





func _ready() -> void:
	_check_pages()
	
	
	# Defer the call to check anchors and margins otherwise the Control will not correctly use the border when it's
	# first added into the scene
	call_deferred("_check_layout")
	
	# By default disable processing. It should be enabled only when animating (expanding/shrinking)
	set_process(false)
	set_physics_process(false)



func _init() -> void:
	anchor_bottom = 0
	rect_clip_content = true
	
	_stray_cleanup()
	
	_vbox.set_name("__vertical_box__")
	_hbox.set_name("__horizontal_box__")
	
	
	
	add_child(_vbox)
	add_child(_hbox)
	
	_vbox.alignment = BoxContainer.ALIGN_CENTER
	_hbox.alignment = BoxContainer.ALIGN_CENTER
	
	_vbox.add_constant_override("separation", 15)
	_hbox.add_constant_override("separation", 15)
	
	_vbox.visible = false
	_hbox.visible = false
	
	_check_pages()
	
	if (!is_connected("tree_exiting", self, "_on_tree_exiting")):
		# warning-ignore:return_value_discarded
		connect("tree_exiting", self, "_on_tree_exiting")
	
	
	# warning-ignore:return_value_discarded
#	_vbox.connect("draw", self, "_DEBUG_draw_box", [_vbox])
	# warning-ignore:return_value_discarded
#	_hbox.connect("draw", self, "_DEBUG_draw_box", [_hbox])





