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

# Objects derived from this class are meant to represent the state of the
# game nodes within the high level snapshots. Basically, properties within
# those classes are meant to hold the data that will be replicated through
# the network system. Note that not all property types are supported, only
# the following ones:
# - bool
# - int
# - float
# - Vector2
# - Rect2
# - Quat
# - Color
# - Vector3
# Another thing to keep in mind is the fact that derived classes *must*
# implement the "apply_state(node)" function, which is basically the may
# way the replication system will take snapshot state and apply into the
# game nodes.
# At the end of this file there is a template that can be copied and
# pasted into new files to create new entity types. In the demo project
# there are also some examples of classes that can be used.

extends Reference
class_name SnapEntityBase

const CTYPE_UINT: int = 65538
const CTYPE_BYTE: int = 131074
const CTYPE_USHORT: int = 196610


# A unique ID is necessary in order to correctly find the node within the game
# world that is associated with this entity data.
# Note that the uniqueness is a requirement within the entity type and not necessarily
# across the entire game session.
var id: int

# In order to properly spawn game objects the packed scene is necessary information and
# some times the correct one must be replicated. Instead of sending a string (which
# is not supported by the automatic replication system), a "name" is hashed and that
# value is replicated (which adds another 4 bytes). This name is the "category" when
# registering the spawners within the snapshot data object. Still, sometimes this value
# is not necessary and it can be completely ignored if, at the _init() of the derived
# class, a call to set_meta("class_hash", 0) is added.
# Yes, this means you can't create a field named no_class_hash and set it to be unsigned.
var class_hash: int



func _init(uid: int, chash: int) -> void:
	id = uid
	class_hash = chash
	
	# Both id and class_hash are meant to be replicated (encoded/decoded) as unsigned integers
	# of 32 bits. So, set both of them to be used as such by just creating two meta values
	# with the property names and the "EntityDescription.CTYPE_UINT"
	set_meta("id", CTYPE_UINT)
	set_meta("class_hash", CTYPE_UINT)



############################################################################
### Copy the code bellow into a derived entity type to have a "template" ###
############################################################################

#extends SnapEntityBase
#class_name TheEntityTypeNameClass
#
#func _init(uid: int, chash: int).(uid, chash) -> void:
#	pass        # Initialize the entity data
#
#func apply_state(to_node: Node) -> void:
#	pass        # Apply the properties of this entity into the node

