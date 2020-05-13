###############################################################################
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
###############################################################################

# The default spawner just takes the packed scene, through its constructor,
# that should be used to spawn a game node. With that in mind, each type of
# node to be dynamically spawned should have a corresponding spawner. If there
# are more advanced things to be done with each spawning then a different class,
# derived from NetNodeSpawner, can be created.

extends NetNodeSpawner
class_name NetDefaultSpawner

# This holds the packed scene corresponding to the node that should be spawned
var _scene_class: PackedScene = null


func _init(ps: PackedScene) -> void:
	_scene_class = ps

# Function that must be overridden. This is where the actual node is instanced
func spawn() -> Node:
	return _scene_class.instance() if _scene_class else null

