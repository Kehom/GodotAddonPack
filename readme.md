# Kehom's Godot Addon Pack

This repository contains not only a collection of Godot addons, it's also a demo project using those "plugins". All of them are pure GDScript, yet there is a C++ module version of this pack that can be found [here](https://github.com/Kehom/GodotModulePack).

The addons in this pack require Godot v3.2+ to work.

The following addons are part of this pack:

* DebugHelpers: Some scripts to aid with testing/debugging.
* General: Contains a few "general use" scripts.
* Network: Automates most of the networked multiplayer synchronization process, through snapshots. The addon sort of "forces" the creation of an authoritative server system.
* Nodes: Some Godot scenes with attached scripts that are meant to be used by attaching instances within other scenes.
* Smooth: Largely based on [Lawnjelly's Smoothing Addon](https://github.com/lawnjelly/smoothing-addon), automates interpolation calculation of child nodes.
* UI: Custom user interface Control nodes.
* Database: An in game database system based on Godot Resource. It contains an editor plugin for easier editing of the data.
* DataAsset: A resource meant to hold data. A plugin editor is provided to help edit the properties, including support for custom scripted resources and some more advanced array editing.

## Installation

Normally speaking, installing an addon into a Godot project consists of copying the addon directory into the project's "addons" subdirectory. As an example, suppose you have a project under the `mygame` directory and want to install the `Network` addon. The process here would be to just copy the contents of the `network` directory (from this repository) into the `mygame/addons/network`.

Some addons here may have internal dependencies, like the `Network` addon. In this specific case, it requires the `encdecbuffer.gd`, which is inside the `general/data` directory (in this repository).

Finally, on some cases it may be necessary to activate the addon from the project settings (`Plugins` tab). Such is the case for the `Network` addon. Bellow is an slightly more detailed list of what is provided and on each case there will be enough information related to what must be copied in order to be used as well as the activation requirement or not.

Some addons might add a few additional settings into the ProjectSettings window. In that case a new category (`Keh Addons`) is added and, under it, an entry for the addon, containing its settings.

## Tutorial

On my web page [kehomsforge.com](http://kehomsforge.com/tutorials/multi/GodotAddonPack) there is a set of tutorials for each of the addons in this pack. Each page corresponds to one addon and contains two major sections, one explaining the basics of using the addon while the other explains a little bit of how the addon internally works.

## The Addons

Bellow is a slightly more detailed list of the addons, including information regarding if the addon (or "sub-addon") has interdependency, needs activation and if it adds additional settings.

### Debug Helpers

Needs Activation |
-|
yes*

This addon is meant to bring a few additional tools to help debug projects.

\* Activating this plugin only adds the scripts into the auto-load list (with default name `OverlayDebugInfo` and `DebugLine3D`). Alternatively you can manually add the desired script(s) to your auto-load list, meaning that you can set your preferred name to access the functionality.

#### overlayinfo.gd

Interdependency | Extra Settings
-|-
none | no

I find myself constantly creating temporary UI controls (`Label`) to dump text into screen (specially when trying to debug networked values), which becomes rather tedious after some time. This script offers means to quickly add text into the screen, including timed labels that will be removed after a specified amount of seconds.

#### line3d.gd

Interdependency | Extra Settings
-|-
none | no

This little script is meant to make things easier to draw lines in 3D. Using the default `add_line()` function will draw a line that will last for a single frame. There is the option to add lines that will last for the specified amount of seconds (`add_timed_line()`).

### General

As mentioned this addon is meant to contain some "general use" scripts.

#### data/encdecbuffer.gd

Interdependency | Needs Activation | Extra Settings
-|-|-
none | no | no

Implements a class (`EncDecBuffer`) that wraps a `PoolByteArray` and provides means to add or extract data into the wrapped array. One of the features is that it allows "short integers" (8 or 16 bits) to be encoded/decoded. The main reason for this buffer to exist is to strip out variant headers (4 bytes per property) from the encoded data, mostly for packing properties to be sent through networks. Although this can be useful for other things, like binary save files.

#### data/quantize.gd

Interdependency | Needs Activation | Extra Settings
-|-|-
none | no | no

Provides means to quantize floating point numbers as well as compress rotation quaternions using the *smallest three* method. The entire functionality is provided through static functions, meaning that it's not necessary to create instances of the class (`Quantize`). Although the returned quantized data are still using the full GDScript variant data, the resulting integers can be packed into others through bit masking. Also, this data can be directly used with the encdecbuffer.gd script, meaning the two complement each other rather well.

### Network

Interdependency | Needs Activation | Extra Settings
-|-|-
`data/encdecbuffer.gd`, `data/quantize.gd*` | yes | yes

This addon was born in order to help create authoritative servers that send replication data to clients through snapshots and events. Most of the process is automated and the internal design is meant to be as "less intrusive as possible". The idea is to not completely change node hierarchy and have minimal impact on game logic code.

\* The `data/quantize.gd` will be required if analog input quantization is enabled within the project settings window.

I now have a [tutorial](http://www.kehomsforge.com/tutorials/single/gdDedicatedServer) on how to create dedicated servers, which does use this addon to perform synchronization.

### Nodes

The contents of this addon are meant to be Godot scenes with attached scripts that are meant to be used by simply creating an instance of the scene wherever desired.

#### Cam3d

Interdependency | Needs Activation | Extra Settings
-|-|-
none | no | no

Wraps the Camera (3D) node to facilitate with certain tasks. Features:

* Follows the parent node from a configurable distance.
* Orientation axes can be individually locked/unlocked. A locked axis can still be (manually) changed, it only prevents the parent (automatically) affecting the camera.
* Shaking using simplex noise in order to "improve the feeling". The shake behavior can be configured (translation, orientation and so on).
* The movement can be smoothed and it also can contain lag.
* "Collision detection". There are some options to try to change the behavior if some object is in between the camera and the parent node.

### Smooth

Interdependency | Needs Activation | Extra Settings
-|-|-
none | yes | no

As mentioned, this addon is largely based on Lawnjelly's work. The addon in this pack is meant to automatically interpolate the transform of the parent node, rather than provide a property to indicate the target object.

### UI

Interdependency *may* vary according to the implemented control (to that end each control will have this information bellow).\

Needs Activation |
-|
yes

The idea here is to provide custom user interface controls in order to increase the offer given by Godot. Activating this addon will make all of the installed controls available for use.

#### CustomControlBase

Interdependency | Extra Settings
-|-
none | no

This is a base class meant to serve as a starting point for custom Controls implemented with pure GDScript. The idea of this class is to deal with the theme system in a way that will allow easier overriding of style options from the Inspector, much like any other core Control.

#### FancyLineEdit

Interdependency | Extra Settings
-|-
none | no

Implements most of the functionality of the `LineEditControl` but provides means to "register" rules that will affect how the entered text is rendered. As an example, ":)" can be set to render an image rather than the two characters. Images will be automatically scaled in order to fit the input box, based on the font height. The main idea of this control is to be used as input for consoles and/or chat boxes.

#### Inventory

**Attention**: If you already use this plugin before [this commit (10b9c0080937037abc9ad4537ac26aaa0be4937d)](https://github.com/Kehom/GodotAddonPack/commit/10b9c0080937037abc9ad4537ac26aaa0be4937d), updating will result in a one time script error, when loading the project, telling that the `InventorySlot` identifier isn't valid. Don't worry because the compatibility was not broken and everything will work correctly and further project loads will not result in this error.

Interdependency | Extra Settings
-|-
none | yes

Two new Control widgets, `InventoryBag` and `InventorySpecialSlots` are used to allow the creation of several styles of inventories. Some of the features:

* Bags automatically handle multiple slots and items. The amount of columns and rows can be specified from the *Inspector*.
* Items can span across multiple rows and columns.
* Special slots can be linked in order to easily manage "two handed weapons".
* Special slots use internal filters to automatically *allow* or *deny* specified items.
* A completely custom drag & drop system in order to allow for a finer control over when and how to start/end the process.
* Items can have sockets.
* Items on a bag can be automatically sorted.
* Saving/loading inventory state into/from JSON data (binary support is in the TODO).
* Inventory bag can be expanded or shrinked without affecting item placement.
* Special slots can override maximum stack sizes to create specialized storing systems.


#### TabularBox

Interdependency | Extra Settings
-|-
`CustomControlBase` | no

This Control brings tabular data viewing and editing capabilities. To increase its flexibility, it relies on Data Sources, which are resources implemented by users in order to provide the data to be rendered. When editing, the widget will directly interact with the assigned data source. This means that the actual data storage is entirely up to the project needs. A relatively simple data source is provided out of the box.

There are also column types that allow advanced means to show/edit the data within the TabularBox control. Creating custom ones is relatively simple.

#### ExpandablePanel

Interdependency | Extra Settings
--|--
`CustomControlBase` | no

Add a panel that can expand or shrink in order to reveal/hide its contents. Each child node becomes a "page" allowing the expanding/shrinking to deal with multiple different types of contents. Expanding and/or shrinking can be animated and even have curve resources affecting the behavior of the animation.

Each page gets a "button" to toggle its content. The associated icon used within that button can be configured for each available page within the expandable panel.


#### SpinSlider

Interdependency | Extra Settings
--|--
`CustomControlBase` | no

Implements a control similar to `SpinBox` but if a well defined value range is defined then the spin buttons will be hidden while a slider will be shown.


### Database

Interdependency | Needs Activation | Extra Settings
-|-|-
`UI/TabularBox` | yes | no

This addon uses Godot Resource to implement a database system. A database can contain multiple tables. A table can reference another one if so desired. For easier creation/editing/management of the database, an editor plugin that uses `TabularBox` is part of this addon.


### DataAsset

Interdependency | Needs Activation | Extra Settings
--|--|--
`UI/SpinSlider` | yes | no

Resources meant to hold data can be very useful. Yet editing properties through the *Inspector* panel might be very limiting on many occasions. This plugin is meant to make this kind of editing at least less clunky.

### AudioMaster

Interdependency | Needs Activation | Extra Settings
-|-|-
none | yes* | no

This addon is meant to provide means to easily playback audio without having to worry about node lifetime. A few additional features are added, which makes cross-fading between audio tracks rather simple.

The specific demo for this addon uses assets:

- 3 audio tracks by Rafael Krux and downloaded from https://freepd.com
- The texture and the sound effects are by Kenney, https://kenney.nl


\* Activating this plugin only adds the `AudioMaster` script into the auto-load list. Alternatively you can manually add the desired script(s) to your auto-load list, meaning that you can set your preferred name more easily in order to access the functionality.
