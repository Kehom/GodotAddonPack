# Copyright (c) 2019 Yuri Sarudiansky
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
extends EditorPlugin

func _enter_tree() -> void:
	# Custom type is added by class_name. Using the lines bellow will result in a
	# duplication of the Smooth*D nodes within the node creation window. Those
	# lines allow for customization of the node icon at the cost of not allowing
	# static typing.
	#add_custom_type("Smooth2D", "Node2D", preload("smooth2d/smooth2d.gd"), null)
	#add_custom_type("Smooth3D", "Spatial", preload("smooth3d/smooth3d.gd"), null)
	pass

func _exit_tree() -> void:
	#remove_custom_type("Smooth2D")
	#remove_custom_type("Smooth3D")
	pass

