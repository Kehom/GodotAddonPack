# Kehom's Godot Addon Pack

This repository contains not only a collection of Godot addons, it's also a demo project using those "plugins".

The addons in this pack require Godot v3.2.x to work.

The following addons are part of this pack:

* DebugHelpers: Some scripts to aid with testing/debugging.
* General: Contains a few "general use" scripts.
* Network: Automates most of the networked multiplayer synchronization process, through snapshots. The addon sort of "forces" the creation of an authoritative server system.
* Nodes: Some Godot scenes with attached scripts that are meant to be used by attaching instances within other scenes.
* Smooth: Largely based on [Lawnjelly's Smoothing Addon](https://github.com/lawnjelly/smoothing-addon), automates interpolation calculation of child nodes.
* UI: Custom user interface Control nodes.

## Installation

Normally speaking, installing an addon into a Godot project consists of copying the addon directory into the project's "addons" subdirectory. As an example, suppose you have a project under the `mygame` directory and want to install the `Network` addon. The process here would be to just copy the contents of the `network` directory (from this repository) into the `mygame/addons/network`.

Some addons here may have internal dependencies, like the `Network` addon. In this specific case, it requires the `encdecbuffer.gd`, which is inside the `general/data` directory (in this repository).

Finally, on some cases it may be necessary to activate the addon from the project settings (`Plugins` tab). Such is the case for the `Network` addon. Bellow is an slightly more detailed list of what is provided and on each case there will be enough information related to what must be copied in order to be used as well as the activation requirement or not.

## Tutorial

On my web page [kehomsforge.com](http://kehomsforge.com/tutorials/multi/GodotAddonPack) there is a set of tutorials for each of the addons in this pack. Each page corresponds to one addon and contains two major sections, one explaining the basics of using the addon while the other explains a little bit of how the addon internally works.

## The Addons

Bellow is a slightly more detailed list of the addons.

### Debug Helpers

This addon is meant to bring a few additional tools to help debug projects.

#### overlayinfo.gd

Interdependency: none\
Requires Activation: yes*

I find myself constantly creating temporary UI controls (`Label`) to dump text into screen (specially when trying to debug networked values), which becomes rather tedious after some time. This script offers means to quickly add text into the screen, including timed labels that will be removed after a specified amount of seconds.

\* Activating this plugin only adds the script into the auto-load list (with default name `OverlayDebugInfo`). Alternatively you can manually add the script to your auto-load list, meaning that you can set your preferred name to access the functionality.


#### line3d.gd

Interdependency: none\
Requires Activation: yes*

This little script is meant to make things easier to draw lines in 3D. Using the default `add_line()` function will draw a line that will last for a single frame. There is the option to add lines that will last for the specified amount of seconds (`add_timed_line()`).

\* Activating this plugin only adds the script into the auto-load list (with default name `DebugLine3D`). Alternatively you can manually add the script to your auto-load list, meaning that you can set your preferred name to access the functionality.

### General

As mentioned this addon is meant to contain some "general use" scripts.

#### data/encdecbuffer.gd

Interdependency: none\
Requires Activation: no

Implements a class (`EncDecBuffer`) that wraps a `PoolByteArray` and provides means to add or extract data into the wrapped array. One of the features is that it allows "short integers" (8 or 16 bits) to be encoded/decoded. The main reason for this buffer to exist is to strip out variant headers (4 bytes per property) from the encoded data, mostly for packing properties to be sent through networks. Although this can be useful for other things, like binary save files.

#### data/quantize.gd

Interdependency: none\
Requires Activation: no

Provides means to quantize floating point numbers as well as compress rotation quaternions using the *smallest three* method. The entire functionality is provided through static functions, meaning that it's not necessary to create instances of the class (`Quantize`). Although the returned quantized data are still using the full GDScript variant data, the resulting integers can be packed into others through bit masking. Also, this data can be directly used with the encdecbuffer.gd script, meaning the two complement each other rather well.

### Network

Interdependency: `data/encdecbuffer.gd`, `data/quantize.gd*\`
Requires Activation: yes

This addon was born in order to help create authoritative servers that send replication data to clients through snapshots and events. Most of the process is automated and the internal design is meant to be as "less intrusive as possible". The idea is to not completely change node hierarchy and have minimal impact on game logic code.

\* The `data/quantize.gd` will be required if analog input quantization is enabled within the project settings window.


### Nodes

The contents of this addon are meant to be Godot scenes with attached scripts that are meant to be used by simply creating an instance of the scene wherever desired.

#### Cam3d

Interdependency: none\
Requires Activation: no

Wraps the Camera (3D) node to facilitate with certain tasks. Features:

* Follows the parent node from a configurable distance.
* Orientation axes can be individually locked/unlocked. A locked axis can still be (manually) changed, it only prevents the parent (automatically) affecting the camera.
* Shaking using simplex noise in order to "improve the feeling". The shake behavior can be configured (translation, orientation and so on).
* The movement can be smoothed and it also can contain lag.
* "Collision detection". There are some options to try to change the behavior if some object is in between the camera and the parent node.

### Smooth

Interdependency: none\
Requires Activation: yes

As mentioned, this addon is largely based on Lawnjelly's work. The addon in this pack is meant to automatically interpolate the transform of the parent node, rather than provide a property to indicate the target object.

### UI

Interdependency *may* vary according to the implemented control (to that end each control will have this information bellow).\
Requires Activation: yes

The idea here is to provide custom user interface controls in order to increase the offer given by Godot. Activating this addon will make all of the installed controls available for use.

#### FancyLineEdit

Interdependency: none

Implements most of the functionality of the `LineEditControl` but provides means to "register" rules that will affect how the entered text is rendered. As an example, ":)" can be set to render an image rather than the two characters. Images will be automatically scaled in order to fit the input box, based on the font height. The main idea of this control is to be used as input for consoles and/or chat boxes.

