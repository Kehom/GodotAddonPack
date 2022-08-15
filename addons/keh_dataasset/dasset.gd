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
extends Resource
class_name DataAsset

# This is the base "Data Asset" class. There is a single function that must be derived in order for the Editor Plugin
# to properly work, which is "get_data_info()". It should return an array containing dictionaries describing the
# properties of this asset. Granted, it would easily be possible to automate the retrieval of such data from script
# but there are a few reasons for the function requirement:
# 1 - Full control over what will be shown within the Editor window. Maybe a property is meant to be hidden and
# automatically calculated by internal code (which is something that can't exactly be generalized)
# 2 - This provides means to specify which *type* will be created when adding entries in an array property.
# 3 - From script there is no way to retrieve the default value of a property, but with this function it becomes a
# possibility, allowing the editor to provide a button to reset the value of a given property
# 4 - Simplified way to provide numerical ranges as it's not exactly the easiest (if possible at all) to retrieve such
# information through scripting.

#######################################################################################################################
### Signals and definitions


#######################################################################################################################
### "Public" properties


#######################################################################################################################
### "Public" functions
# This function can be used in order to provide some customization over how the editor will look/behave. In the returned
# dictionary it should contain other dictionaries with the customization settings, keyed by the name of the exposed
# property. Each type of property have its setting normally are always optional. However, arrays must specify a type,
# which is done through this function.
# Within the list bellow, the available option is provided with its default value in case it's not used
# *** Bool property
# - label: "On" -> A string determining which label will be attached to the editor checkbox
#
# *** Int Property:
# - range_min: 0 -> Determines the minimum value that can be assigned
# - range_max: 100 -> Determines the maximum value that can be assigned
# - step: 1 -> The "delta" applied to the value when clicking the spin buttons or moving the slider
#
# *** Float property:
# - range_min: 0.0 -> Determines the minimum value that can be assigned
# - range_max: 1.0 -> Determines the maximum value that can be assigned
# - step: 0.1 -> The "delta" applied to the value when clicking the spin buttons or moving the slider
#
# *** Array property:
# - type: Either an integer as a subset of TYPE_*, the full path to a script defining a resource type or the *name*
#   of a core resource _class_.
#
# *** Scripted Resource type property:
# - type: The full path to the script defining the resource.
func get_property_info() -> Dictionary:
	return {}


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
