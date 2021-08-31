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

signal ok_pressed(settings)



#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func set_column_index(i: int) -> void:
	_cindex = i

func get_column_index() -> int:
	return _cindex


func show_dialog(db: GDDatabase, ccol: String, rweight_allowed: bool) -> void:
	_dbsource = db
	_currentcol = ccol
	
	var pop: PopupMenu = $vbox/line_vtype/opt_vtype.get_popup()
	pop.set_item_disabled(pop.get_item_index(DBTable.ValueType.VT_RandomWeight), !rweight_allowed)
	
	popup_centered()



#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _cindex: int = -1

# This will be used to gather necessary data to populate the external table drop down menu
var _dbsource: GDDatabase = null

# Obviously the external table should not reference itself, so current edited table name is necessary
var _currentcol: String = ""

# Cache the external table drop down for easier manipulation
onready var _external_pop: PopupMenu = $vbox/line_exttable/opt_othertable.get_popup()

#######################################################################################################################
### "Private" functions
func _check_dialog_height() -> void:
	# Without this the height is most likely not correct because of the theme system
	rect_size.y = $vbox.get_combined_minimum_size().y + 10


func _can_create() -> bool:
	var lblh: Label = $vbox/line_mainbts/lbl_helper
	var cname: String = $vbox/line_colname/txt_colname.text
	
	# Assume the creation is not allowed and some helper information is required
	lblh.text = "?"
	
	if (cname.empty()):
		lblh.hint_tooltip = "Column name can't be empty"
		return false
	
	if (cname.to_lower() == "id"):
		lblh.hint_tooltip = "Column name '%s' is reserved" % cname
		return false
	
	if (_dbsource.get_table(_currentcol).has_column(cname)):
		lblh.hint_tooltip = "Table '%s' already contains a column named '%s'" % [_currentcol, cname]
		return false
	
	if ($vbox/line_exttable.visible && _external_pop.get_item_count() == 0):
		lblh.hint_tooltip = "There isn't any valid table to be referenced by the new column."
		return false
	
	# If here then there is no need to dispaly "helper information"
	lblh.text = ""
	lblh.hint_tooltip = ""
	
	return true



#######################################################################################################################
### Event handlers
func _on_dlg_newcolumn_visibility_changed() -> void:
	if (visible):
		$vbox/line_colname/txt_colname.text = ""
		$vbox/line_vtype/opt_vtype.select(0)
		$vbox/line_mainbts/bt_ok.disabled = true
		$vbox/line_exttable.visible = false
		
		var pop: PopupMenu = $vbox/line_vtype/opt_vtype.get_popup()
		var i: int = pop.get_item_index(DBTable.ValueType.VT_String)
		$vbox/line_vtype/opt_vtype.selected = i
		
		_check_dialog_height()
		
		$vbox/line_colname/txt_colname.call_deferred("grab_focus")
	
	else:
		_dbsource = null
		_currentcol = ""


func _on_txt_colname_text_changed(_new_text: String) -> void:
	$vbox/line_mainbts/bt_ok.disabled = !_can_create()


func _on_txt_colname_text_entered(_new_text: String) -> void:
	if (!$vbox/line_mainbts/bt_ok.disabled):
		_on_bt_ok_pressed()


func _on_bt_ok_pressed() -> void:
	emit_signal("ok_pressed", {
		"name": $vbox/line_colname/txt_colname.text,
		"type": $vbox/line_vtype/opt_vtype.get_selected_id(),
		"external": $vbox/line_exttable/opt_othertable.text if _external_pop.get_item_count() > 0 else "", 
	})
	
	visible = false



func _on_bt_cancel_pressed() -> void:
	visible = false



func _on_vbox_resized() -> void:
	# Must defer the call because the vbox is not with the correct size yet
	call_deferred("_check_dialog_height")


func _on_opt_vtype_item_selected(index: int) -> void:
	var pop: PopupMenu = $vbox/line_vtype/opt_vtype.get_popup()
	var id: int = pop.get_item_id(index)
	
	var changeable: bool = id >= 1000
	var external: bool = (id >= 500 && id < 600)
	
	
	$vbox/lbl_alert.visible = !changeable
	$vbox/line_exttable.visible = external
	
	if (!changeable):
		$vbox/lbl_alert.text = "Caution: A column of type '%s' cannot have its type changed after creation." % pop.get_item_text(index)
	
	if (external):
		# Must populate the drop down menu....
		_external_pop.clear()
		_external_pop.rect_size = Vector2()
		
		var entries: Array = _dbsource.get_external_candidates_for(id, _currentcol)
		for c in entries:
			_external_pop.add_item(c)
		
		if (entries.size() > 0):
			$vbox/line_exttable/opt_othertable.text = entries[0]
			$vbox/line_exttable/opt_othertable.selected = 0
			$vbox/line_exttable/opt_othertable.disabled = false
		else:
			$vbox/line_exttable/opt_othertable.selected = -1
			$vbox/line_exttable/opt_othertable.text = "**No valid table found**"
			$vbox/line_exttable/opt_othertable.disabled = true
	
	
	_check_dialog_height()
	$vbox/line_mainbts/bt_ok.disabled = !_can_create()



#######################################################################################################################
### Overrides
func _ready() -> void:
	var tps: Dictionary = DBHelpers.generate_ui_types()
	
	var pop: PopupMenu = $vbox/line_vtype/opt_vtype.get_popup()
	if (!pop):
		return
	
	pop.clear()
	pop.rect_size = Vector2()
	
	for t in tps:
		pop.add_item(tps[t], t)

