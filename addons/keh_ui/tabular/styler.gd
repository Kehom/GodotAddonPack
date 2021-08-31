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


# An instance of this class will be given to each cell in order to make things easier to
# properly obtain the theme styles.

tool
extends Reference
class_name TabularStyler

const CLASS_NAME: String = "TabularBox"

# Most of the TabularBox is based on the default theme, but with a few modifications
func generate_theme() -> void:
	if (!_tbox):
		return
	
	var panel: StyleBox = _tbox.get_stylebox("panel", "Panel")
	var hbase: StyleBox = _tbox.get_stylebox("normal", "LineEdit")
	
	
	var btn: StyleBox = _tbox.get_stylebox("normal", "Button")
	var bth: StyleBox = _tbox.get_stylebox("hover", "Button")
	var btp: StyleBox = _tbox.get_stylebox("pressed", "Button")
	
	var chk_unchecked: Texture = _tbox.get_icon("unchecked", "CheckBox")
	var chk_checked: Texture = _tbox.get_icon("checked", "CheckBox")
	
	var txtcolor: Color = _tbox.get_color("font_color", "Label")
	
	# The load() function requires absolute path. So, to make the addon slightly more compatible with different paths,
	# "calculate" the correct resource path of the icons
	var base: String = get_script().resource_path.get_base_dir()
	
	var diconpath: String = base + "/textures/darrow_8x8.png"
	var liconpath: String = base + "/textures/larrow_8x8.png"
	var riconpath: String = base + "/textures/rarrow_8x8.png"
	var tbinpath: String = base + "/textures/tbin_16x16.png"
	var ntexpath: String = base + "/textures/notex_32x32.png"
	
	var fnt: Font = _tbox.get_font("font", "Label")
	
	# Create the background stylebox
	var bgstyle: StyleBox = panel.duplicate()
	UIHelper.set_stylebox_margin(bgstyle, 1, 1, 1, 1)
	_tbox.add_theme_stylebox("background", bgstyle)
	
	
	# Create the header stylebox
	var hstyle: StyleBox = hbase.duplicate()
	UIHelper.set_stylebox_margin(hstyle, 5, 5, 5, 5)
	_tbox.add_theme_stylebox("header", hstyle)
	
	
	# Create the cell styleboxes
	var orow: StyleBoxFlat = StyleBoxFlat.new()
	UIHelper.set_stylebox_border(orow, 1, 1, 1, 1)
	UIHelper.set_stylebox_margin(orow, 4, 4, 4, 4)
	orow.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	orow.border_color = Color(0, 0, 0, 0)
	_tbox.add_theme_stylebox("odd_row", orow)
	
	var erow: StyleBoxFlat = orow.duplicate()
	erow.bg_color = Color(0.5, 0.5, 0.5, 0.1)
	_tbox.add_theme_stylebox("even_row", erow)
	
	
	### Setup 3 button states
	var bt_normal: StyleBox = btn.duplicate()
	UIHelper.set_stylebox_margin(bt_normal, 1, 1, 1, 1)
	_tbox.add_theme_stylebox("button_normal", bt_normal)
	
	var bt_hover: StyleBox = bth.duplicate()
	UIHelper.set_stylebox_margin(bt_hover, 1, 1, 1, 1)
	_tbox.add_theme_stylebox("button_hover", bt_hover)
	
	var bt_pressed: StyleBox = btp.duplicate()
	UIHelper.set_stylebox_margin(bt_pressed, 1, 1, 1, 1)
	_tbox.add_theme_stylebox("button_pressed", bt_pressed)
	
	### Setup the icons
	_tbox.add_theme_icon("unchecked", chk_unchecked.duplicate())
	_tbox.add_theme_icon("checked", chk_checked.duplicate())
	
	_tbox.add_theme_icon("down_arrow", load(diconpath))
	_tbox.add_theme_icon("left_arrow", load(liconpath))
	_tbox.add_theme_icon("right_arrow", load(riconpath))
	_tbox.add_theme_icon("trash_bin", load(tbinpath))
	_tbox.add_theme_icon("no_texture", load(ntexpath))
	
	
	### Setup the fonts
	_tbox.add_theme_font("header", fnt)
	_tbox.add_theme_font("cell", fnt)
	
	### Setup colors
	_tbox.add_theme_color("header_text", txtcolor)
	_tbox.add_theme_color("cell_text", txtcolor)
	
	
	### Create the constants
	_tbox.add_theme_constant("header_align", 1, true, "Left, Center, Right")





func get_empty_stylebox() -> StyleBox:
	return _emptysbox


func get_background_box() -> StyleBox:
	return _tbox.get_theme_stylebox("background", CLASS_NAME)


func get_header_box() -> StyleBox:
	return _tbox.get_theme_stylebox("header", CLASS_NAME)


func get_oddrow_box() -> StyleBox:
	return _tbox.get_theme_stylebox("odd_row", CLASS_NAME)


func get_evenrow_box() -> StyleBox:
	return _tbox.get_theme_stylebox("even_row", CLASS_NAME)


func get_hover_box() -> StyleBox:
	return _tbox.get_theme_stylebox("hover", CLASS_NAME)


func get_normal_button() -> StyleBox:
	return _tbox.get_theme_stylebox("button_normal", CLASS_NAME)

func get_hovered_button() -> StyleBox:
	return _tbox.get_theme_stylebox("button_hover", CLASS_NAME)

func get_pressed_button() -> StyleBox:
	return _tbox.get_theme_stylebox("button_pressed", CLASS_NAME)


func get_header_text_color() -> Color:
	return _tbox.get_theme_color("header_text", CLASS_NAME)

func get_cell_text_color() -> Color:
	return _tbox.get_theme_color("cell_text", CLASS_NAME)


func get_header_font() -> Font:
	return _tbox.get_theme_font("header", CLASS_NAME)


func get_cell_font() -> Font:
	return _tbox.get_theme_font("cell", CLASS_NAME)


func get_unchecked_icon() -> Texture:
	return _tbox.get_theme_icon("unchecked", CLASS_NAME)

func get_checked_icon() -> Texture:
	return _tbox.get_theme_icon("checked", CLASS_NAME)

func get_down_arrow_icon() -> Texture:
	return _tbox.get_theme_icon("down_arrow", CLASS_NAME)

func get_left_arrow_icon() -> Texture:
	return _tbox.get_theme_icon("left_arrow", CLASS_NAME)

func get_right_arrow_icon() -> Texture:
	return _tbox.get_theme_icon("right_arrow", CLASS_NAME)

func get_trash_bin_icon() -> Texture:
	return _tbox.get_theme_icon("trash_bin", CLASS_NAME)

func get_no_texture_icon() -> Texture:
	return _tbox.get_theme_icon("no_texture", CLASS_NAME)


func get_header_align() -> int:
	return _tbox.get_theme_constant("header_align", CLASS_NAME)


func get_button_reorder_size() -> Vector2:
	return _reorder_size

func set_button_reoder_size(s: Vector2) -> void:
	_reorder_size = s


var _tbox: CustomControlBase = null
var _emptysbox: StyleBoxEmpty = null
var _reorder_size: Vector2 = Vector2()


# Get color of the center of the given image
func _get_img_ccolor(img: Image) -> Color:
	img.lock()
	var ret: Color = img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.5))
	img.unlock()
	return ret



# Without the "null" as default value everytime this script is changed an error will be given telling that
# an instance couldn't be created.
func _init(tb: CustomControlBase = null) -> void:
	_tbox = tb
	_emptysbox = StyleBoxEmpty.new()
