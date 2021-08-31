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
extends VBoxContainer


#######################################################################################################################
### Signals and definitions
signal table_resource_dropped(res)

const TableListEntryT: Script = preload("tbl_list_entry.gd")

#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions


#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties


#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
func can_drop_data(_pos: Vector2, data) -> bool:
	var retval: bool = false
	
	if (data is Dictionary && data.has("type") && data.type == "files"):
		for f in data.files:
			# Unfortunately must load the resource in order to check its type
			var res: Resource = ResourceLoader.load(f)
			if (res && res is DBTable):
				# Even if only one file in a selection is valid, must return true because the entire batch will be
				# given to the drop_data function
				retval = true
				break
	
	return retval


func drop_data(_pos: Vector2, data) -> void:
	# In here assuming the "can_drop_data" has already filtered non dictionary and those that don't contain
	# valid resources
	for f in data.files:
		var res: Resource = ResourceLoader.load(f)
		if (res && res is DBTable):
			emit_signal("table_resource_dropped", res)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			for tbl in get_children():
				if (tbl is TableListEntryT):
					tbl.check_style()

