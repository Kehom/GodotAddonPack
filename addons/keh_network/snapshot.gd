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

# This is the high level snapshot representation. Normally there
# is no need to directly create or even access instances of this
# class, since the network system provides a lot of interface to
# automatically deal with that.


extends Reference
class_name NetSnapshot

# Signature can also be called frame or even timestamp. In any case, this is
# just an incrementing number to help identify the snapshots
var signature: int

# Signature of the input data used when generating this snapshot. On the
# authority machine this may not make much difference but is used on clients
# to compare with incoming snapshot data
var input_sig: int

# Key = (snap) entity hashed name | Value = Dictionary
# Inner Dictionary, Key = entity unique ID | Value = instance of SnapEntityBase
var _entity_data: Dictionary


func _init(sig: int) -> void:
	signature = sig
	input_sig = 0
	_entity_data = {}

func add_type(nhash: int) -> void:
	_entity_data[nhash] = {}

func get_entity_count(nhash: int) -> int:
	assert(_entity_data.has(nhash))
	return _entity_data[nhash].size()

func add_entity(nhash: int, entity: SnapEntityBase) -> void:
	assert(_entity_data.has(nhash))
	_entity_data[nhash][entity.id] = entity

func remove_entity(nhash: int, uid: int) -> void:
	assert(_entity_data.has(nhash))
	if (_entity_data[nhash].has(uid)):
		_entity_data[nhash].erase(uid)

func get_entity(nhash: int, uid: int) -> SnapEntityBase:
	assert(_entity_data.has(nhash))
	return _entity_data[nhash].get(uid)


func build_tracker() -> Dictionary:
	var ret: Dictionary = {}
	
	for ehash in _entity_data:
		ret[ehash] = _entity_data[ehash].keys()
	
	return ret

