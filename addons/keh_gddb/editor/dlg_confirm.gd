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
extends ConfirmationDialog


# This little dialog is a "multi purpose" one. Because the DBEMain requires several tasks to be confirmed,
# there are a few possibilities:
# 1 - Create a dialog box for type of task that needs confirmation.
# 2 - Create one dialog box on the fly when it's necessary then connect the "popup_hide" signal to automatically delete
#     it from the tree when the dialog is closed.
# 3 - Use an "ID system" indicating which type of action is being confirmed. A single signal handler can be used,
#     which will simply check which action code is in the dialog and perform accordingly

# Each approach has its own pros and cons. This file is the dialog meant to follow approach 3.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
func show_dialog(txt: String, action: int, data: Dictionary) -> void:
	_action = action
	dialog_text = txt
	_data = data
	popup_centered()


func get_action_code() -> int:
	return _action


func get_data() -> Dictionary:
	return _data

#######################################################################################################################
### "Private" definitions


#######################################################################################################################
### "Private" properties
var _action: int = -1

var _data: Dictionary = {}

#######################################################################################################################
### "Private" functions


#######################################################################################################################
### Event handlers


#######################################################################################################################
### Overrides
