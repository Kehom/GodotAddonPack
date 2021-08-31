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
extends WindowDialog


#######################################################################################################################
### Signals and definitions
signal ok_pressed(new_name)

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func showdlg(tbl: String, list: Dictionary) -> void:
	$vbox/lbl_info.text = INFO_FORMAT % tbl
	_tbl_list = list
	_nname.text = ""
	
	_btok.disabled = true
	
	_nname.call_deferred("grab_focus")
	
	popup_centered()

#######################################################################################################################
### "Private" definitions
const INFO_FORMAT: String = "Rename '%s' table to:"

#######################################################################################################################
### "Private" properties
var _tbl_list: Dictionary

onready var _nname: LineEdit = $vbox/txt_newname

onready var _btok: Button = $vbox/btbox/bt_ok

#######################################################################################################################
### "Private" functions
func _check_dlg_height() -> void:
	# Without this the height is most likely not correct because of the theme system
	rect_size.y = $vbox.get_combined_minimum_size().y + 18

#######################################################################################################################
### Event handlers
func _on_txt_newname_text_changed(new_text: String) -> void:
	$vbox/btbox/bt_ok.disabled = _tbl_list.has(new_text)


func _on_txt_newname_text_entered(_new_text: String) -> void:
	if ($vbox/btbox/bt_ok.disabled):
		return
	
	_on_bt_ok_pressed()


func _on_bt_ok_pressed() -> void:
	emit_signal("ok_pressed", $vbox/txt_newname.text)
	visible = false



func _on_bt_cancel_pressed() -> void:
	visible = false


func _on_vbox_resized() -> void:
	# Must defer the call because the fbox is nto with the correct size yet
	call_deferred("_check_dlg_height")

#######################################################################################################################
### Overrides


