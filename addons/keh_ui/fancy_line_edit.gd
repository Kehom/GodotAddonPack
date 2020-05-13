# Copyright (c) 2019-2020 Yuri Sarudiansky
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
extends Control
class_name FancyLineEdit, "fancy_line_edit.png"

# TODO:
# - Add a context menu (typically brought by right clicking)
# - Ctrl+Arrows to move the caret to the next/previous word within the input box
# - Text outline formatting
# - Find one way to place the control with the same dimensions of the LineEdit control when newly added into the scene.
# - When the assigned theme is changed, update display in the editor
# - Incorporate means to limit string (input) size
# - When clicking the input box to move the caret, perform a finer location targetting rather than moving into the first
#   index after the clicked coordinate



# On both signals the "new_text" argument will contain the raw_text.
signal text_changed(new_text)     # Emitted when text changes
signal text_entered(new_text)     # Emitted when user presses KEY_ENTER on the FancyLineEdit


const CNAME: String = "FancyLineEdit"


enum FormatFlags {
	# Add this flag for italic text
	FF_ITALIC = 1,
	# Add this flag for bold text
	FF_BOLD = 2,
	# Add this flag for underline text
	FF_UNDERLINE = 4,
	# If this is neabled, then the auto-format word can appear anywhere in the string, otherwise only at the beginning
	FF_WORDANYWHERE = 64,
}

# This class will be used to provide information regading the various "auto-format" rules that can be registered
# within the control
class FormatData:
	var flags: int           # Should use flags from the FormatFlags enum
	var color: Color
	var builder: FuncRef
	var patt_end: String
	var image: Texture
	
	func _init() -> void:
		flags = 0
		color = Color(1, 1, 1, 1)
		builder = null
		patt_end = ""
		image = null



# This is a base class to hold rendering information.
class RenderableData:
	var _color: Color
	var _raw_text: String = ""
	
	func _init() -> void:
		_color = Color(1, 1, 1, 1)
	
	func get_length() -> int:
		# The RenderableData class must be derived and not directly used
		# This must return how many things/characters are rendered, which will influence how the caret moves
		assert(0)
		return 0
	
	func get_width() -> int:
		# The RenderableData class must be derived and not directly used
		# This must return the actual rendering width of the contents of this renderable
		assert(0)
		return 0
	
	func get_raw_length() -> int:
		return _raw_text.length()
	
	func render(_ci: RID, _position: Vector2, _left: int, _right: int) -> int:
		return 0
	
	func get_xoffset_at(_i: int) -> int:
		return 0


class ImageRenderable extends RenderableData:
	var _image: Texture = null
	var _size: Vector2 = Vector2()
	
	# The font argument is only used to know how much the image must be scaled up/down
	# in order to fit inside the control's height
	func _init(img: Texture, font_ref: Font, color: Color) -> void:
		_color = color
		_image = img
		var fheight: float = font_ref.get_height()
		var scale: float = fheight / img.get_size().y
		_size = Vector2(img.get_size().x * scale, fheight)
	
	func get_length() -> int:
		return 1
	
	func get_width() -> int:
		return int(_size.x)
	
	func render(ci: RID, position: Vector2, left: int, right: int) -> int:
		if (position.x < left || position.x + _size.x > right):
			return int(_size.x)
		
		_image.draw_rect(ci, Rect2(position, _size), false, _color)
		return int(_size.x)
	
	func get_xoffset_at(_i: int) -> int:
		return int(_size.x)


class TextRenderable extends RenderableData:
	var _text: String = ""
	var _font: Font = null
	var _width: int = 0
	var _underline: bool = false    # Underline is not a font feature
	
	func _init(txt: String, f: Font, c: Color, uline: bool) -> void:
		_color = c
		_text = txt
		_font = f
		_width = int(f.get_string_size(txt).x)
		_underline = uline
	
	func get_length() -> int:
		return _text.length()
	
	func get_width() -> int:
		return _width
	
	func get_raw_length() -> int:
		var ret = _raw_text.length()
		if (ret == 0):
			ret = _text.length()
		return ret
	
	func render(ci: RID, position: Vector2, left: int, right: int) -> int:
		# This function is called during the _draw() of the Control, meaning that drawing functions
		# can be used within this function.
		
		if (position.x + _width < left || position.x > right):
			return _width
		
		var stri: int = 0    # Initial index of the string that will be rendered
		var acc: int = int(position.x)
		while (acc < left):
			acc += int(_font.get_string_size(_text[stri]).x)
			stri += 1
		
		var stre: int = _text.length() - 1
		var racc: int = int(_width + position.x)
		while (racc > right && stre >= 0):
			racc -= int(_font.get_string_size(_text[stre]).x)
			stre -= 1
		
		var ascent: int = int(_font.get_ascent())
		var under_width: int = _width       # Assume the entire text is rendered
		
		if (stri > 0 || stre < _text.length() - 1):
			# Only a subsection of the text can be rendered
			var rlen: int = stre - stri + 1    # Render length
			var rtxt: String = _text.substr(stri, rlen)
			
			_font.draw(ci, Vector2(acc, position.y + ascent), rtxt, _color)
			
			if (_underline):
				under_width = int(_font.get_string_size(rtxt).x)
			
		else:
			_font.draw(ci, Vector2(position.x, position.y + ascent), _text, _color)
		
		if (_underline):
			var upos: int = int(position.y + _font.get_height())
			var xfrom: int = int(position.x)
			var xto: int = xfrom + under_width
			VisualServer.canvas_item_add_line(ci, Vector2(xfrom, upos), Vector2(xto, upos), _color)
		
		return _width
	
	func get_xoffset_at(i: int) -> int:
		return int(_font.get_string_size(_text[i]).x)


# This inner class is used to help with the rendering of the control contents. The raw_text property
# holds the data used to build what is to be rendered. As an example, ":)" may be rendered as an image
# instead of two characters. An object of this class will parse the given data and generate internal
# objects that will perform the rendering, based on the a set of registered rules.
class RenderHelper:
	enum ParsingState {
		neutral, wording, spacing, pattern
	}
	
	# If this flag is true then new renderables can be added, otherwise nothing will happen. This
	# flag will be change during the parse()
	var can_receive_renderable: bool = false
	# Holds RenderableData objects
	var renderable: Array = []
	# Cache the length (in characters) of the rendered text - images are considered as a single character,
	# meaning that formatting markers will not be considered in this computation
	var cache_str_len: int = 0
	
	# An internal function used to add renderables to the array. This is mostly to help with the upkeep
	# of the cached values
	func _add_renderable(r: RenderableData, raw: String) -> void:
		if (can_receive_renderable):
			r._raw_text = raw
			renderable.push_back(r)
			cache_str_len += r.get_length()
	
	
	# This function is called during the parsing in order to verify if "strict autoformat" is meant to
	# be used or not
	func _check_strict(word: String, fonts: Dictionary, color: Color, aformat: Dictionary, acc: String) -> bool:
		# Verify if there is any strict formatting matching word
		var stri: FormatData = aformat.strict.get(word, null)
		
		if (stri):
			# Check if there is any accumulated text to be added to the renderable array
			if (acc.length() > 0):
				# There is, append it
				_add_renderable(TextRenderable.new(acc, fonts.normal, color, false), acc)
			
			# Formatting not performed by a custom function
			var img: Texture = stri.image
			
			if (img):
				# The word becomes an image. Build the corresponding renderable
				_add_renderable(ImageRenderable.new(img, fonts.normal, stri.color), word)
			
			else:
				# The word is meant to be displayed with a different style. Build it
				# Font can be: normal, italic, bold or bodl italic
				var combined: int = FormatFlags.FF_ITALIC | FormatFlags.FF_BOLD
				var masked: int = stri.flags & combined
				var use_font: Font = fonts.normal
				
				match masked:
					FormatFlags.FF_ITALIC:
						use_font = fonts.italic
					FormatFlags.FF_BOLD:
						use_font = fonts.bold
					combined:
						use_font = fonts.bold_italic
				
				_add_renderable(TextRenderable.new(word, use_font, stri.color, stri.flags & FormatFlags.FF_UNDERLINE), word)
			
			return true
		
		return false
	
	# This function is called during the parsing in order to verify if "pattern autoformat" is meant to
	# be used or not
	func _check_pattern(c: String, aformat: Dictionary, rindex: int) -> Array:
		# Check if there is any pattern that start with c
		var patt: FormatData = aformat.pattern.get(c, null)
		if (patt):
			# There is. Check if it can match anywhere
			var is_anywhere: bool = (FormatFlags.FF_WORDANYWHERE & patt.flags != 0)
			
			if (!is_anywhere && rindex > 0):
				# Can't match if not at the beginning of the string. So consider this as normal text
				return [ParsingState.wording, null]
			else:
				return [ParsingState.pattern, patt]
		
		return [ParsingState.wording, null]
	
	
	func parse(raw_txt: String, fonts: Dictionary, icolor: Color, aformat: Dictionary) -> void:
		# Initiating parsing - allow new renderables to be added
		can_receive_renderable = true
		renderable.clear()
		cache_str_len = 0
		
		if (raw_txt.length() == 0):
			return
		
		var rstate: int = ParsingState.neutral
		
		var acc_text: String = ""
		var word: String = ""
		var cpatt_entry: FormatData = null    # Hold current reading "pattern" entry from the aformat
		
		for i in raw_txt.length():
			# Extract current character
			var c: String = raw_txt[i]
			# A "last character" flag
			var is_lastchar: bool = (i == raw_txt.length() - 1)
			
			match rstate:
				ParsingState.neutral:
					if (c == " "):
						rstate = ParsingState.spacing
						acc_text += " "
					
					else:
						var pattcheck: Array = _check_pattern(c, aformat, i)
						rstate = pattcheck[0]
						cpatt_entry = pattcheck[1]
						word += c
				
				ParsingState.wording:
					if (c == " "):
						if (_check_strict(word, fonts, icolor, aformat, acc_text)):
							# If there was any previously accumulated text, it was appended into the renderable array
							# so cleanup the acc_text
							acc_text = ""
						else:
							# Word does not trigger auto-formatting. Just accumulate it
							acc_text += word
						
						# Accumulate the space
						acc_text += " "
						rstate = ParsingState.spacing
						word = ""
					
					else:
						var pattcheck: Array = _check_pattern(c, aformat, i)
						if (pattcheck[0] == ParsingState.pattern):
							rstate = pattcheck[0]
							cpatt_entry = pattcheck[1]
							if (acc_text.length() > 0 || word.length() > 0):
								acc_text += word
								_add_renderable(TextRenderable.new(acc_text, fonts.normal, icolor, false), acc_text)
								acc_text = ""
								word = c
						
						else:
							word += c
				
				ParsingState.spacing:
					if (c != " "):
						var pattcheck: Array = _check_pattern(c, aformat, i)
						rstate = pattcheck[0]
						cpatt_entry = pattcheck[1]
						word += c
						
						if (rstate == ParsingState.pattern && acc_text.length() > 0):
							_add_renderable(TextRenderable.new(acc_text, fonts.normal, icolor, false), acc_text)
							acc_text = ""
					
					else:
						acc_text += " "
				
				ParsingState.pattern:
					if (c == cpatt_entry.patt_end || (is_lastchar && c != " ")):
						if (c != " "):
							word += c
						
						# Give priority to strict words
						if (is_lastchar && _check_strict(word, fonts, icolor, aformat, acc_text)):
							acc_text = ""
						
						else:
							# Request the renderable object, giving it the flag indicating if the pattern
							# has ended or not. This is necessary as the user may be typing the word and
							# partial formatting may be desired
							var r: RenderableData = cpatt_entry.builder.call_func(word, cpatt_entry.patt_end == c)
							if (r):
								_add_renderable(r, word)
							
							if (c == " "):
								acc_text = " "
								rstate = ParsingState.spacing
							else:
								rstate = ParsingState.neutral
						
						word = ""
					
					else:
						if (c == " "):
							if (_check_strict(word, fonts, icolor, aformat, acc_text)):
								acc_text = ""
							else:
								acc_text += word
							
							word = ""
							
							rstate = ParsingState.spacing
							acc_text += " "
						
						else:
							word += c
			
			if (is_lastchar && word.length() > 0):
				if (_check_strict(word, fonts, icolor, aformat, acc_text)):
					acc_text = ""
					word = ""
				else:
					acc_text += word
		
		if (acc_text.length() > 0):
			_add_renderable(TextRenderable.new(acc_text, fonts.normal, icolor, false), acc_text)
		
		# Parsing has ended - block for new renderables
		can_receive_renderable = false
	
	
	# Given an index within the edit control, return the renderable that holds it
	func get_renderable_at(index: int) -> Dictionary:
		var ret: Dictionary = {
			inner = 0,         # The inner index corresponding to the requested position
			rindex = 0,        # The renderable index within the array
		}
		
		var al: int = 0
		for r in renderable:
			al += r.get_length()
			if (index < al):
				ret.inner = r.get_length() - (al - index)
				return ret
			
			ret.rindex += 1
		
		return ret



# This inner class helps with selection
class SelectionData:
	# Starting index of the selection
	var start: int = 0
	# End index of the selection
	var end: int = 0
	# If this is true then mouse is being used to create selection
	var is_selecting: bool = false
	
	func set_sel(s: int, e: int) -> void:
		start = int(min(s, e))
		end = int(max(s, e))
	
	func get_size() -> int:
		return end - start
	
	func reset() -> void:
		start = 0
		end = 0
	
	func add_left(amount: int, up_boundary: int) -> void:
		start = int(clamp(start + amount, 0, up_boundary))
	
	func add_right(amount: int, up_boundary: int) -> void:
		end = int(clamp(end + amount, 0, up_boundary))



### Meant to be public and possibly exported to the editor

# Holds the raw text data, not necessarily what is rendered though
export var raw_text: String = "" setget set_raw_text

# If this is true then it will not be possible to enter text within the instance
export var read_only: bool = false setget set_read_only

# If true, the caret will blink
export var blink_caret: bool = true setget set_blink_caret

# If crate blinking is enabled, this tell how fast the effect will be
export(float, 0.01, 10.0) var blink_caret_speed: float = 0.65 setget set_blink_caret_speed

# If the raw text is empty, this will be rendered with a configurable color
export var placeholder: String = "" setget set_placeholder

# The placeholder rendering color
export var placeholder_color: Color = Color(1, 1, 1, 0.6) setget set_placeholder_color


### Meant to be private

var _use_theme: Theme

# Related to the caret
var _draw_caret: bool = false
var _caret_timer: Timer = Timer.new()
var _cursor_index: int = 0

# This helps with "scrolling" the text within the box
# The value held here corresponds to the index of the first rendered glyph on the control
var _display_window: int = 0

# Renderer for the main text - the input data
var _render_main: RenderHelper = RenderHelper.new()
# Renderer for the placeholder text
var _render_pholder: RenderHelper = RenderHelper.new()

# Auto-format identifiers - this will filled when registering the formatting patterns
var _autoformat: Dictionary = { strict = {}, pattern = {}}

# Hold text selection information
var _selection: SelectionData = SelectionData.new()



func _init() -> void:
	_check_theme()


func _ready() -> void:
	# This is the same minimum size of the common LineEdit control
	set_custom_minimum_size(Vector2(58, 24))
	# The typical "text editing" mouse cursor
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	# Allow the control to receive focus - should this be exposed as a property?
	set_focus_mode(Control.FOCUS_ALL)
	# Initialize the caret timer
	_caret_timer.set_wait_time(blink_caret_speed)
	# warning-ignore:return_value_discarded
	_caret_timer.connect("timeout", self, "_toggle_draw_caret")
	add_child(_caret_timer)
	
	if (blink_caret && !Engine.is_editor_hint()):
		_caret_timer.start()


func _draw() -> void:
	if (Engine.is_editor_hint()):
		_draw_caret = false
	
	# First draw the box
	var style: StyleBox = _use_theme.get_stylebox("read_only" if read_only else "normal", CNAME)
	draw_style_box(style, Rect2(Vector2(), rect_size))
	
	# If the control has focus, draw an extra box. By default a blue outline
	if (has_focus()):
		var focus_box: StyleBox = _use_theme.get_stylebox("focus", CNAME)
		draw_style_box(focus_box, Rect2(Vector2(), rect_size))
	
	if (read_only || !has_focus()):
		# Assigning _draw_caret as direct result of above expression like
		# _draw_caret = read_only || !has_focus()
		# is incorrect since the value may already be false as a result of the
		# blinking timer, in which case it may be reverted to true.
		_draw_caret = false
	
	var font: Font = _use_theme.get_font("normal_font", CNAME)
	var xoffset: int = int(style.get_offset().x)
	var yoffset: int = int(style.get_offset().y)
	var window_offset: int = _get_xpos_at(_display_window)

	
	if (_draw_caret || _selection.get_size() > 0):
		var y_area: int = int(get_size().y - get_minimum_size().y)
		var fheight: int = int(font.get_height())
		var cheight: int = y_area if fheight > y_area else fheight
		
		var cursorx: int = _get_xpos_at(_cursor_index) + xoffset - window_offset
		
		if (_selection.get_size() > 0):
			var sel_col: Color = _use_theme.get_color("selection_color", CNAME)
			var first_x: int = 0
			var last_x: int = 0
			
			if (_cursor_index == _selection.start):
				first_x = cursorx
				last_x = int(min(_get_xpos_at(_selection.end) + xoffset - window_offset, get_size().x - xoffset))
			
			else:
				first_x = int(max(_get_xpos_at(_selection.start) + xoffset - window_offset, xoffset))
				last_x = cursorx
			
			var w: int = last_x - first_x
			draw_rect(Rect2(Vector2(first_x, yoffset), Vector2(w, cheight)), sel_col)
		
		if (_draw_caret):
			var ccolor: Color = _use_theme.get_color("caret_color", CNAME)
			draw_rect(Rect2(Vector2(cursorx - 1, yoffset), Vector2(1, cheight)), ccolor)
	
	var xpos: int = xoffset - window_offset
	var ci: RID = get_canvas_item()
	
	# Take the correct renderer (main or place holder)
	var renderer: RenderHelper = _render_main if raw_text.length() > 0 else _render_pholder
	
	# Now draw every renderable
	for r in renderer.renderable:
		# Render the data
		xpos += r.render(ci, Vector2(xpos, yoffset), xoffset, get_size().x - xoffset)


func _gui_input(evt: InputEvent) -> void:
	if (read_only):
		return
	
	if (evt is InputEventMouseButton):
		_handle_mouse_button(evt)
	
	if (evt is InputEventMouseMotion):
		_handle_mouse_motion(evt)
	
	if (evt is InputEventKey):
		_handle_key(evt)



func _notification(what: int) -> void:
	if (what == NOTIFICATION_THEME_CHANGED):
		var t: Theme = get_theme()
		if (t && t != _use_theme):
			_check_theme()



### "Public" functions

func get_string_length() -> int:
	return _render_main.cache_str_len


# This is a "generic" function to add an strict rule to auto-format the rendered data
# Bellow are some "specialized" functions to make things easier to deal with the various
# input arguments of this function
func add_strict_autoformat(identifier: String, image: Texture, color: Color, flags: int) -> void:
	var fd: FormatData = FormatData.new()
	fd.image = image
	fd.color = color
	fd.flags = flags
	
	_autoformat.strict[identifier] = fd
	_refresh(true, true)

# Add an strict rule that will result in an image
func add_strict_image(identifier: String, img: Texture, color: Color) -> void:
	add_strict_autoformat(identifier, img, color, FormatFlags.FF_WORDANYWHERE)

# Add an strict rule that will alter the rendered text
func add_strict_text(identifier: String, color: Color, italic: bool, bold: bool, underline: bool, anywhere: bool) -> void:
	var flags: int = 0
	if (italic):
		flags |= FormatFlags.FF_ITALIC
	if (bold):
		flags |= FormatFlags.FF_BOLD
	if (underline):
		flags |= FormatFlags.FF_UNDERLINE
	if (anywhere):
		flags |= FormatFlags.FF_WORDANYWHERE
	
	add_strict_autoformat(identifier, null, color, flags)


func add_pattern_autoformat(start: String, end: String, anywhere: bool, _func: FuncRef) -> void:
	# Starting of the pattern must be defined by a single character
	assert(start.length() == 1)
	# End of pattern can be empty but at most one single character
	assert(end.length() < 2)
	# Pattern rules must contain a function reference to return a RenderableData object
	assert(_func && _func.is_valid())
	
	var fd: FormatData = FormatData.new()
	# If no "end" is provided, setting it to an space will make things easier when parsing
	fd.patt_end = end if end.length() == 1 else " "
	fd.builder = _func
	fd.flags = FormatFlags.FF_WORDANYWHERE if anywhere else 0
	
	_autoformat.pattern[start] = fd
	_refresh(true, true)




# Removes the specified strict auto-format rule
func remove_strict_autoformat(identifier: String) -> void:
	# warning-ignore:return_value_discarded
	_autoformat.strict.erase(identifier)
	_refresh(true, true)

# Removes the specified pattern auto-format rule
func remove_pattern_autoformat(identifier: String) -> void:
	# warning-ignore:return_value_discarded
	_autoformat.pattern.erase(identifier)
	_refresh(true, true)

# Remove all formatting rules
func clear_autoformat() -> void:
	_autoformat.strict.clear()
	_autoformat.pattern.clear()
	_refresh(true, true)


func add_text_at(txt: String, pos: int) -> void:
	var rawindex: int = _render_index_to_raw(pos)
	
	var first: String = raw_text.substr(0, rawindex)
	var last: String = raw_text.substr(rawindex, -1)
	
	var len_before: int = get_string_length()
	set_raw_text(first + txt + last)
	var len_after: int = get_string_length()
	
	set_caret_index(_cursor_index + (len_after - len_before))


# Copy selected test to the clipboard
func copy() -> void:
	if (_selection.get_size() > 0):
		var rawstart: int = _render_index_to_raw(_selection.start)
		var rawend: int = _render_index_to_raw(_selection.end)
		
		OS.set_clipboard(raw_text.substr(rawstart, rawend))

# Paste text from clipboard
func paste() -> void:
	var buff: String = OS.get_clipboard()
	
	if (buff != ""):
		delete_selection()
		add_text_at(buff, _cursor_index)


# Delete the selected text
func delete_selection() -> void:
	var selsize: int = _selection.get_size()
	
	if (selsize < 1):
		return
	
	var first: int = _render_index_to_raw(_selection.start)
	var last: int = _render_index_to_raw(_selection.end)
	var rsize: int = last - first
	
	if (_cursor_index == _selection.end):
		_cursor_index = _selection.start
	
	_selection.reset()
	
	var len_before: int = get_string_length()
	raw_text.erase(first, rsize)
	_refresh(true, false)
	var len_after: int = get_string_length()
	set_caret_index(_cursor_index - (len_before - len_after - selsize))
	update()


# Obtain the current caret index
func get_caret_index() -> int:
	return _cursor_index

# Set current caret index
func set_caret_index(index: int) -> void:
	_cursor_index = int(clamp(index, 0, get_string_length()))
	
	if (_cursor_index <= _display_window):
		_display_window = int(max(0, _cursor_index - 1))
	else:
		var style: StyleBox = _use_theme.get_stylebox("normal", CNAME)
		var wwidth: int = int(get_size().x - style.get_minimum_size().x)
		
		if (wwidth < 0):
			return
		
		var i: int = _cursor_index - 1
		var sl: int = get_string_length()
		var aw: int = 0
		var fp: int = _display_window
		# Returned dictionary:
		# rindex -> Renderable index within the renderable array
		# inner -> The inner index that corresponds to the requested rendered index
		var rdata: Dictionary = _render_main.get_renderable_at(i)
		
		var r: RenderableData = null
		if (rdata.rindex < _render_main.renderable.size()):
			r = _render_main.renderable[rdata.rindex]
		
		while (i >= _display_window):
			if (i < sl):
				if (r):
					aw += r.get_xoffset_at(rdata.inner)
				rdata.inner -= 1
				if (rdata.inner < 0):
					rdata.rindex -= 1
					r = _render_main.renderable[rdata.rindex]
					rdata.inner = r.get_length() - 1
			
			if (aw > wwidth):
				break
			
			fp = i
			i -= 1
		
		if (fp != _display_window):
			_display_window = fp
	
	_reset_caret()
	update()


func get_normal_font() -> Font:
	return _use_theme.get_font("normal_font", CNAME)

func get_bold_font() -> Font:
	return _use_theme.get_font("bold_font", CNAME)

func get_italics_font() -> Font:
	return _use_theme.get_font("italics_font", CNAME)

func get_bold_italics_font() -> Font:
	return _use_theme.get_font("bold_italics_font", CNAME)


func get_default_font_color() -> Color:
	return _use_theme.get_color("font_default_color", CNAME)


# Given a "box size" (width/length), obtain its scaled values so the box fits inside the edit control
func get_scaled_size(original: Vector2) -> Vector2:
	var f: Font = get_normal_font()
	var fheight: float = f.get_height()
	var scale: float = fheight / original.y
	
	return Vector2(original.x * scale , fheight)


### Some helper functions that are meant to be private
func _check_theme() -> void:
	var bname: String = "LineEdit"       # "base" control name
	
	# Try to recursively obtain the first valid theme
	_use_theme = get_theme()
	var cparent: Control = get_parent_control()
	while (!_use_theme && cparent):
		_use_theme = cparent.get_theme()
		cparent = cparent.get_parent_control()
	
	# If still not valid, create a new one
	if (!_use_theme):
		_use_theme = Theme.new()
	
	# Ensure style boxes are valid
	if (!_use_theme.has_stylebox("normal", CNAME)):
		_use_theme.set_stylebox("normal", CNAME, get_stylebox("normal", bname))
	if (!_use_theme.has_stylebox("focus", CNAME)):
		_use_theme.set_stylebox("focus", CNAME, get_stylebox("focus", bname))
	if (!_use_theme.has_stylebox("read_only", CNAME)):
		_use_theme.set_stylebox("read_only", CNAME, get_stylebox("read_only", bname))
	
	# Ensure the fonts are valid
	var default_font: Font = get_font("font", bname)
	if (!_use_theme.has_font("normal_font", CNAME)):
		_use_theme.set_font("normal_font", CNAME, default_font)
	if (!_use_theme.has_font("bold_font", CNAME)):
		_use_theme.set_font("bold_font", CNAME, default_font)
	if (!_use_theme.has_font("italics_font", CNAME)):
		_use_theme.set_font("italics_font", CNAME, default_font)
	if (!_use_theme.has_font("bold_italics_font", CNAME)):
		_use_theme.set_font("bold_italics_font", CNAME, default_font)
	
	# Ensure the colors are valid
	if (!_use_theme.has_color("font_default_color", CNAME)):
		_use_theme.set_color("font_default_color", CNAME, Color("e0e0e0"))
	if (!_use_theme.has_color("caret_color", CNAME)):
		_use_theme.set_color("caret_color", CNAME, Color("f0f0f0"))
	if (!_use_theme.has_color("selection_color", CNAME)):
		_use_theme.set_color("selection_color", CNAME, Color("7d7d7d"))
	
	_refresh(true, true)


func _refresh(main_text: bool, pholder: bool) -> void:
	var fonts: Dictionary = {
		normal = get_normal_font(),
		bold = get_bold_font(),
		italic = get_italics_font(),
		bold_italic = get_bold_italics_font(),
	}
	
	var tcolor: Color = _use_theme.get_color("font_default_color", CNAME)
	
	if (main_text):
		_render_main.parse(raw_text, fonts, tcolor, _autoformat)
	
	if (pholder):
		_render_pholder.parse(placeholder, fonts, placeholder_color, _autoformat)
	
	update()


func _toggle_draw_caret() -> void:
	_draw_caret = !_draw_caret
	if (is_visible_in_tree() && has_focus()):
		update()

func _reset_caret() -> void:
	if (blink_caret):
		_draw_caret = true
		_caret_timer.start()
		update()


# Given a display index (normaly caret) return the X coordinate corresponding to that location
# without considering the style offset
func _get_xpos_at(index: int) -> int:
	var ret: int = 0    # current width - also, return value
	var clen: int = 0   # current display length (number of renderable elements)
	
	for r in _render_main.renderable:
		if (index >= r.get_length() + clen):
			# If here, the cursor is positioned on a subsequent renderable
			ret += r.get_width()
			clen += r.get_length()
		
		else:
			# Caret is within the current renderable object (or in between this and the previous one)
			var ri: int = 0          # read characte rindex of the renderable
			while (clen < index):
				ret += r.get_xoffset_at(ri)
				ri += 1
				clen += 1
			
			return ret
	
	return ret


# Given a rendering index return the corresponding index within the raw_text. This becomes necessary
# when manipulating the text through the box
func _render_index_to_raw(pos: int) -> int:
	var cindex: int = 0
	var ret: int = 0
	
	for r in _render_main.renderable:
		if (cindex + r.get_length() > pos):
			while (cindex < pos):
				cindex += 1
				ret += 1
		
		else:
			cindex += r.get_length()
			ret += r.get_raw_length()
	
	return ret


# Based on a visual position, set the caret index to be as close to that location as possible.
# The idea of this algorithm is to find the first character that begins after pos
# TODO: perform a finer positioning. That is, instead of placing after the first character that comes after
#       xpos, position the cursor closer to the mouse (before or after the character under the mouse)
func _set_caret_at_xpos(xpos: int) -> void:
	var nindex: int = _display_window
	var style: StyleBox = _use_theme.get_stylebox("normal", CNAME)
	var cx: int = int(style.get_offset().x)
	
	for r in _render_main.renderable:
		if (cx + r.get_width() > xpos):
			# Current x + current renderable width goes beyond requested X position
			# Cursor is then within current renderable
			var rchar: int = 0
			while (cx < xpos):
				cx += r.get_xoffset_at(rchar)
				rchar += 1
				nindex += 1
			
			break
		
		else:
			# Requested position is still beyond current X + renderable width
			cx += r.get_width()
			nindex += r.get_length()
	
	set_caret_index(nindex)



# Given the X coordinate xpos, spread selection from it. This occurs on the following situations:
# - Click with shift pressed
# - Drag to create selection
# - Shift+Left/Right Arrow key
func _spread_selection_from(xpos: int) -> void:
	var current: int = _cursor_index
	_set_caret_at_xpos(xpos)
	
	if (_selection.get_size() > 0):
		if (current < _selection.end):
			current = _selection.end
		else:
			current = _selection.start
	
	_selection.set_sel(current, _cursor_index)


### Some event (input) handlers to better separate the code
func _handle_mouse_button(evt: InputEventMouseButton) -> void:
	if (evt.is_pressed()):
		match evt.get_button_index():
			BUTTON_LEFT:
				if (evt.get_shift()):
					_spread_selection_from(int(evt.get_position().x))
				
				else:
					_selection.reset()
					_set_caret_at_xpos(int(evt.get_position().x))
				
				_selection.is_selecting = true
				_reset_caret()
			
			BUTTON_RIGHT:
					# TODO: bring a context menu
				pass
	
	else:
		if (evt.get_button_index() == BUTTON_LEFT):
			_selection.is_selecting = false
			_reset_caret()


func _handle_mouse_motion(evt: InputEventMouseMotion) -> void:
	if (evt.button_mask & BUTTON_LEFT):
		if (_selection.is_selecting):
			_spread_selection_from(int(evt.get_position().x))
			_reset_caret()


func _handle_key(evt: InputEventKey) -> void:
	if (!evt.is_pressed()):
		return
	
	var scode: int = evt.get_scancode()
	var handled: bool = true
	
	match scode:
		KEY_LEFT:
			# Move the cursor to the left (if it's not at 0)
			# If there is a selection:
			# - Reset it if shift is not pressed
			# - Expand/Shrink if shift is pressed
			var strlen: int = get_string_length()
			
			if (evt.get_shift()):
				if (_selection.get_size() > 0):
					if (_cursor_index == _selection.start):
						_selection.add_left(-1, strlen)
					else:
						_selection.add_right(-1, strlen)
				else:
					if (_cursor_index > 0):
						_selection.set_sel(_cursor_index - 1, _cursor_index)
			else:
				_selection.reset()
			
			if (_cursor_index > 0):
				set_caret_index(_cursor_index - 1)
		
		KEY_RIGHT:
			# Move the cursor to the right (if it's not at the end)
			# If there is a selection:
			# - Rest it if shift is not pressed
			# - Expand/Shrink if shift is pressed
			var strlen: int = get_string_length()
			
			if (evt.get_shift()):
				if (_selection.get_size() > 0):
					if (_cursor_index == _selection.end):
						_selection.add_right(1, strlen)
					else:
						_selection.add_left(1, strlen)
				else:
					if (_cursor_index < strlen):
						_selection.set_sel(_cursor_index, _cursor_index + 1)
			else:
				_selection.reset()
			
			if (_cursor_index < strlen):
				set_caret_index(_cursor_index + 1)
		
		KEY_ENTER:
			emit_signal("text_entered", raw_text)
		
		KEY_BACKSPACE:
			if (_cursor_index > 0 || _selection.get_size() > 0):
				if (_selection.get_size() == 0):
					_selection.set_sel(_cursor_index - 1, _cursor_index)
				delete_selection()
		
		KEY_DELETE:
			if (_cursor_index < get_string_length() || _selection.get_size() > 0):
				if (_selection.get_size() == 0):
					_selection.set_sel(_cursor_index, _cursor_index + 1)
				delete_selection()
		
		KEY_END:
			var strlen: int = get_string_length()
			
			if (evt.get_shift()):
				if (_selection.get_size() == 0):
					_selection.set_sel(_cursor_index, strlen)
				else:
					if (_cursor_index == _selection.start):
						_selection.set_sel(_selection.end, strlen)
					else:
						_selection.add_right(strlen, strlen)
			else:
				_selection.reset()
			
			set_caret_index(strlen)
		
		KEY_HOME:
			var strlen: int = get_string_length()
			
			if (evt.get_shift()):
				if (_selection.get_size() == 0):
					_selection.set_sel(0, _cursor_index)
				else:
					if (_cursor_index == _selection.end):
						_selection.set_sel(0, _selection.start)
					else:
						_selection.add_left(-strlen, strlen)
			else:
				_selection.reset()
			
			set_caret_index(0)
		
		KEY_V:
			if (evt.get_control() || evt.get_command()):
				paste()
			else:
				handled = false
		
		KEY_X, KEY_C:
			if (evt.get_control() || evt.get_command()):
				copy()
				if (scode == KEY_X && _selection.get_size() > 0):
					delete_selection()
			else:
				handled = false
		
#		KEY_F1:
#			print(raw_text)
		
		_:
			handled = false
		
	if (!handled):
		var ucode: int = evt.get_unicode()
		if (ucode >= 32 && scode != KEY_DELETE):
			if (_selection.get_size() > 0):
				delete_selection()
				_selection.reset()
			
			add_text_at(PoolByteArray([ucode]).get_string_from_utf8(), _cursor_index)
			emit_signal("text_changed", raw_text)
	
	_reset_caret()


### Setters/Getters
func set_raw_text(t: String) -> void:
	raw_text = t
	_refresh(true, false)

func set_read_only(b: bool) -> void:
	read_only = b
	update()

func set_blink_caret(b: bool) -> void:
	blink_caret = b
	if (_caret_timer.is_inside_tree()):
		if (blink_caret):
			_caret_timer.start()
		else:
			_caret_timer.stop()
	
	_draw_caret = true

func set_blink_caret_speed(s: float) -> void:
	blink_caret_speed = s
	_caret_timer.set_wait_time(blink_caret_speed)

func set_placeholder(s: String) -> void:
	placeholder = s
	_refresh(false, true)

func set_placeholder_color(c: Color) -> void:
	placeholder_color = c
	_refresh(false, true)

