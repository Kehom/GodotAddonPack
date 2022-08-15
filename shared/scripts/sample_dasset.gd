# Copyright (c) 2022 Yuri Sarudiansky
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
extends DataAsset
class_name SampleDataAsset

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties
# warning-ignore:unused_class_variable
export var some_string: String = ""

# warning-ignore:unused_class_variable
export var some_float: float = 1.0

# warning-ignore:unused_class_variable
export(int, FLAGS, "physical", "poison", "fire", "cold", "lightning") var some_flags: int = 0

# warning-ignore:unused_class_variable
export var some_resource: Resource = null

# warning-ignore:unused_class_variable
export var some_texture: Texture = null

# warning-ignore:unused_class_variable
export var some_array: Array = []

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
func get_property_info() -> Dictionary:
	return {
		"some_float": {
			"range_min": 0.0,
			"range_max": 1.0,
		},
		
		"some_resource": {
			"type": "res://shared/scripts/sample_resource.gd",
		},
		
		"some_array": {
			"type": "res://shared/scripts/sample_resource.gd",
		},
	}
