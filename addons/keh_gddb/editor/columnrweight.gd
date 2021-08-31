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
extends "res://addons/keh_ui/tabular/default_columns/columnfloat.gd"

# This is a specialized "float column" that is meant to deal specifically with the random weight system of the DB.
# In here some extra functionality is added on top of the ColumnFloat. The idea here is to display a tooltip on each
# cell containing information related to the random weight system (row's accumulated weight plus its probability when
# taking all other rows into account).
# Because the contents of the tooltip can easily change when previous rows are changed, this column will require extra
# setup to take the table. Then, as soon as the mouse enters a cell it will take the required data and assign into the
# hint_tooltip property of that cell.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func extra_setup(tb: DBTable) -> void:
	_table = tb

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _table: DBTable = null

#######################################################################################################################
### "Private" functions
func _on_mouse_enter_cell(index: int, cell: LineEdit) -> void:
	if (!_table):
		return
	
	var w: float = cell.text.to_float()
	var aw: float = _table.get_row_acc_weight(index)
	var tw: float = _table.get_total_weight_sum()
	
	var prob: float = w / tw if tw > 0.0 else 0.0
	
	cell.hint_tooltip = "Probability: %s (%s%%)\nAcc weight: %s" % [prob, prob * 100.0, aw]

#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func create_cell() -> Control:
	var ret: LineEdit = .create_cell()
	
	# warning-ignore:return_value_discarded
	ret.connect("mouse_entered", self, "_on_mouse_enter_cell", [get_row_count(), ret])
	
	
	return ret
