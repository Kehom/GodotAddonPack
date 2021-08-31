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
extends "../columnbase.gd"


#######################################################################################################################
### Signals and definitions
const TEX_DIMENSIONS: int = 32

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions
class TexCell extends Control:
	var idx: int = -1      # This is mostly to make things easier for the drag forwarding.
	var tex: Texture = null
	var bt: Button = null
	var btc: Button = null
	
	func set_tex(data: Dictionary) -> void:
		tex = data.texture
		bt.text = data.label
		bt.hint_tooltip = data.tooltip
		btc.visible = data.clearv
		
		update()
	
	
	func _init() -> void:
		bt = Button.new()
		bt.set_name("texpath")
		bt.align = Button.ALIGN_LEFT
		bt.text = "..."
		add_child(bt)
		
		bt.anchor_left = 0
		bt.anchor_top = 1
		bt.anchor_right = 1
		bt.anchor_bottom = 1
		
		bt.margin_left = 0
		bt.margin_bottom = 0
		
		
		btc = Button.new()
		btc.set_name("clear")
		btc.hint_tooltip = "Clear texture"
		btc.mouse_filter = Control.MOUSE_FILTER_PASS
		btc.visible = false
		btc.expand_icon = true
		add_child(btc)
		
		# set_anchor_and_margin(MARGIN_LEFT, 1, -16) is not working. However, first setting the anchor then the margin does work.
		btc.anchor_left = 1
		btc.margin_left = -16
		btc.set_anchor_and_margin(MARGIN_TOP, 0, 0)
		btc.set_anchor_and_margin(MARGIN_RIGHT, 1, 0)
		btc.set_anchor_and_margin(MARGIN_BOTTOM, 0, 16)




#######################################################################################################################
### "Private" properties
# In here I really wanted the dialog to display thumbnails of the textures. The EditorFileDialog does allow that BUT
# it cannot be instantiated by script and only by the editor.
var _dlg_lt: FileDialog = null


#######################################################################################################################
### "Private" functions
func _apply_style(cell: TexCell) -> void:
	assert(cell != null)
	
	style_button(cell.bt)
	
	var bth: float = get_button_min_height()
	
	cell.btc.add_stylebox_override("normal", _styler.get_empty_stylebox())
	cell.btc.add_stylebox_override("hover", _styler.get_empty_stylebox())
	cell.btc.add_stylebox_override("pressed", _styler.get_empty_stylebox())
	cell.btc.add_stylebox_override("focus", _styler.get_empty_stylebox())
	
	cell.btc.icon = _styler.get_trash_bin_icon()
	cell.btc.margin_bottom = bth
	cell.btc.margin_left = -bth
	
	cell.bt.margin_top = -get_button_min_height()



func _check_tex_path(path: String) -> Dictionary:
	var tex: Texture = null
	var label: String = ""
	var ttip: String = ""
	var cvisible: bool = false
	
	if (path.empty()):
		label = "..."
		ttip = "Load texture resource."
		tex = _styler.get_no_texture_icon()
	
	elif (!ResourceLoader.exists(path)):
		label = "!" + path.get_file()
		ttip = "'%s' is not a Texture.\nClick to Load texture resource." % path
		tex = _styler.get_no_texture_icon()
	
	else:
		label = path.get_file()
		ttip = path
		cvisible = true
		
		var res: Resource = load(path)
		if (res is Texture):
			tex = res
		else:
			tex = _styler.get_no_texture_icon()
	
	
	return {
		"texture": tex,
		"label": label,
		"tooltip": ttip,
		"clearv": cvisible,
	}


func _set_tex(path: String, cell: TexCell) -> void:
	assert(cell != null)
	
	cell.set_tex(_check_tex_path(path))
	notify_value_entered(cell.idx, path)



# This will get the rectangle size meant to keep the texture within the constraints and the correct aspect ratio
func _get_draw_rect_size(tex: Texture) -> Vector2:
	if (tex.get_width() == tex.get_height()):
		return Vector2(TEX_DIMENSIONS, TEX_DIMENSIONS)
	
	var fdim: float = float(TEX_DIMENSIONS)
	var s1: float = fdim / tex.get_width()
	var s2: float = fdim / tex.get_height()
	
	var s: float = 1.0
	
	if (s1 > s2):
		s = s2
	
	else:
		s = s1
	
	return Vector2(tex.get_width() * s, tex.get_height() * s)

#######################################################################################################################
### Event handlers
func _on_draw_cell(cell: TexCell) -> void:
	if (cell.tex):
		cell.draw_texture_rect(cell.tex, Rect2(Vector2(), _get_draw_rect_size(cell.tex)), false)



func _on_load_clicked(index: int) -> void:
	_dlg_lt.set_meta("index", index)
	_dlg_lt.popup_centered()

func _on_clear_clicked(index: int) -> void:
	_set_tex("", get_cell_control(index) as TexCell)


func _on_file_selected(path: String) -> void:
	var index: int = _dlg_lt.get_meta("index")
	_set_tex(path, get_cell_control(index) as TexCell)



#######################################################################################################################
### Overrides
func set_row_value(cell: Control, value) -> void:
	if (!(cell is TexCell)):
		return
	
	if (!(value is String)):
		return
	
	cell.set_tex(_check_tex_path(value))


func create_cell() -> Control:
	var index: int = get_row_count()
	
	var ret: TexCell = TexCell.new()
	ret.idx = index
	
	# warning-ignore:return_value_discarded
	ret.connect("draw", self, "_on_draw_cell", [ret])
	
	# warning-ignore:return_value_discarded
	ret.bt.connect("pressed", self, "_on_load_clicked", [index])
	
	# warning-ignore:return_value_discarded
	ret.btc.connect("pressed", self, "_on_clear_clicked", [index])
	
	ret.set_drag_forwarding(self)
	
	_apply_style(ret)
	
	return ret




func get_min_row_height() -> float:
	var margins: Dictionary = get_cell_internal_margins()
	var ret: float = margins.top + margins.top + margins.bottom + TEX_DIMENSIONS + get_button_min_height()
	
	return ret


func check_style() -> void:
	for i in get_row_count():
		var c: TexCell = get_cell_control(i) as TexCell
		if (!c):
			continue
		
		_apply_style(c)


# The created cells will forward the drag handling into the column itself.
func can_drop_data_fw(_pos: Vector2, data, from: Control) -> bool:
	if (!(from is TexCell)):
		return false
	
	if (data.type != "files"):
		return false
	
	if (data.files.size() != 1):
		return false
	
	var p: String = data.files[0]
	var res: Resource = load(p)
	return (res is Texture)


func drop_data_fw(_pos: Vector2, data, from: Control) -> void:
	assert(data.type == "files" && data.files.size() == 1)
	
	if (!(from is TexCell)):
		return
	
	var p: String = data.files[0]
	_set_tex(p, from)



func _init() -> void:
	rect_size.x = 80
	
	
	_dlg_lt = FileDialog.new()
	_dlg_lt.set_name("dlg_load_tex")
	_dlg_lt.mode = FileDialog.MODE_OPEN_FILE
	_dlg_lt.popup_exclusive = true
	_dlg_lt.window_title = "Open texture"
	_dlg_lt.resizable = true
	_dlg_lt.rect_size = Vector2(600, 340)
	_dlg_lt.access = FileDialog.ACCESS_RESOURCES
	add_child(_dlg_lt)
	
	
	_dlg_lt.filters = PoolStringArray([
		"*.atlastex; ATLASTEX",
		"*.bmp; BMP",
		"*.curvetex; CURVETEX",
		"*.dds; DDS",
		"*.exr; EXR",
		"*.hdr; HDR",
		"*.jpeg; JPEG",
		"*.jpg; JPG",
		"*.largetex; LARGETEX",
		"*.meshtex; MESHTEX",
		"*.pkm; PKM",
		"*.png; PNG",
		"*.pvr; PVR",
		"*.res; RES",
		"*.svg; SVG",
		"*.svgz; SVGZ",
		"*.tex; TEX",
		"*.tga; TGA",
		"*.tres; TRES",
		"*.webp; WEBP",
	])
	
	# warning-ignore:return_value_discarded
	_dlg_lt.connect("file_selected", self, "_on_file_selected")

