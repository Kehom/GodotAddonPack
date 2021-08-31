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
signal ok_pressed(tbl_name, tbl_file, embed, idtype)

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func show_dialog(tblist: Dictionary) -> void:
	_tbset = tblist
	popup_centered()


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _tbset: Dictionary

#######################################################################################################################
### "Private" functions
func _check_dialog_height() -> void:
	# Without this the height is most likely not correct because of the theme system
	rect_size.y = $vbox.get_combined_minimum_size().y + 18

#######################################################################################################################
### Event handlers
func _on_dlg_newtable_visibility_changed() -> void:
	if (visible):
		$vbox/line_buttons/bt_ok.disabled = true
		$vbox/line_name/edt_tbname.text = ""
		$vbox/line_file/edt_filename.text = ""
		$vbox/line_file/edt_filename.placeholder_text = ""
		
		$vbox/line_name/edt_tbname.call_deferred("grab_focus")


func _on_edt_tbname_text_changed(new_text: String) -> void:
	$vbox/line_buttons/bt_ok.disabled = new_text.empty() || _tbset.has(new_text)
	$vbox/line_file/edt_filename.placeholder_text = new_text




func _on_chk_embed_toggled(button_pressed: bool) -> void:
	$vbox/line_file/edt_filename.editable = !button_pressed
	$vbox/line_file/edt_filename.placeholder_text = "" if button_pressed else $vbox/line_name/edt_tbname.text


func _on_bt_ok_pressed() -> void:
	var tbname: String = $vbox/line_name/edt_tbname.text
	var tbfile: String = $vbox/line_file/edt_filename.text
	if (tbfile.empty()):
		tbfile = tbname
	
	var idtype: int = TYPE_INT if $vbox/line_idtype/chk_integer.pressed else TYPE_STRING
	
	emit_signal("ok_pressed", tbname, tbfile, $vbox/line_file/chk_embed.pressed, idtype)
	
	visible = false


func _on_bt_cancel_pressed() -> void:
	visible = false


func _on_vbox_resized():
	# Must defer the call because the vbox is not with the correct size yet
	call_deferred("_check_dialog_height")


func _on_edit_entered(_ntext: String) -> void:
	if (!$vbox/line_buttons/bt_ok.disabled):
		_on_bt_ok_pressed()



#######################################################################################################################
### Overrides


