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


extends Node


#######################################################################################################################
### Signals and definitions


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
func _ready() -> void:
	### Perform a one-time setup of the AudioMaster
	# Set maximum amount of audio stream player nodes for each bus
	AudioMaster.set_maximum_players("Music", 4)
	AudioMaster.set_maximum_players("SFX", 16)
	AudioMaster.set_maximum_players("SFX2D", 16)
	AudioMaster.set_maximum_players("SFX3D", 16)
	AudioMaster.set_maximum_players("UI", 6)
	
	# Ensure the correct audio stream player node will be used within SFX2D and SFX3D audio buses
	AudioMaster.set_player_type("SFX2D", AudioMaster.PlayerType.Player2D)
	AudioMaster.set_player_type("SFX3D", AudioMaster.PlayerType.Player3D)
	
	# Pre-allocate the music stream players since Cross-fading is desired - which requires explicit node index usage
	AudioMaster.allocate_players("Music", 4)
	
	# On project load ideally this call should take the value from a settings file. In here hard-coding to 1/4 of the
	# maximum output volume.
	AudioMaster.set_bus_volume_percent("Master", 0.25)

