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


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func show_dialog(info: Dictionary) -> void:
	# Using BBCode in here but none of the default themes use a font that supports it.
	var code: String = "[b]Database: %s[/b]\n" % info.database
	code += "Table data (count = %d)\n" % info.table_count
	
	for t in info.table_data:
		code += ("\n[b]%s (%s)[/b] - [i]%s[/i] ID\n    Column count: %d | Row count: %d\n" % [t.name, t.path, t.id_type, t.column_count, t.row_count])
		code += "    References: %s\n" % str(t.references)
		code += "    Referenced by: %s\n" % str(t.referenced_by)
	
	$vbox/txt_info.bbcode_text = code
	
	popup_centered()



#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers
func _on_bt_ok_pressed() -> void:
	visible = false

#######################################################################################################################
### Overrides



