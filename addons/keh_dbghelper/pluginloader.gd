###############################################################################
# Copyright (c) 2020 Yuri Sarudiansky
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
###############################################################################

tool
extends EditorPlugin

func enable_plugin() -> void:
	# Add relevant scripts to the autoload list
	add_autoload_singleton("OverlayDebugInfo", "res://addons/keh_dbghelper/overlayinfo.gd")
	add_autoload_singleton("DebugLine3D", "res://addons/keh_dbghelper/line3d.gd")


func disable_plugin() -> void:
	# Remove relevant scripts from the autoload list
	remove_autoload_singleton("OverlayDebugInfo")
	remove_autoload_singleton("DebugLine3D")


func _exit_tree() -> void:
	var root: Node = get_tree().get_root()
	
	var odbgi: Node = root.get_node_or_null("OverlayDebugInfo")
	if (odbgi):
		odbgi.queue_free()
	
	var dbgl3d: Node = root.get_node_or_null("DebugLine3D")
	if (dbgl3d):
		dbgl3d.queue_free()

