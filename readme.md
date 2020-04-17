# Kehom's Godot Addon Pack

This repository contains not only a collection of Godot addons, it's also a demo project using those "plugins".

The addons in this pack require Godot v3.2.x to work.

The following addons are part of this pack:

* General: Contains a few "general use" scripts. As an example, a class that offers means to encode/decode variables into byte arrays while stripping out the 4 byte headers from the variants.
* Network: Automates most of the networked multiplayer synchronization process, through snapshots. The addon sort of "forces" the creation of an authoritative server system.
* Nodes: Some Godot scenes with attached scripts that are meant to be used by attaching instances within other scenes.
* Smooth: Largely based on [Lawnjelly's](https://github.com/lawnjelly/smoothing-addon) Smoothing Addon, automates interpolation calculation of child nodes.

## Installation

Normally speaking, installing an addon into a Godot project consists of copying the addon directory into the project's "addons" subdirectory. As an example, suppose you have a project under the `mygame` directory and want to install the `Network` addon. The process here would be to just copy the contents of the `network` directory (from this repository) into the `mygame/addons/network`.

Some addons here may have internal dependencies, like the `Network` addon. In this specific case, it requires the `encdecbuffer.gd`, which is inside the `general/data` directory (in this repository).

Finally, on some cases it may be necessary to activate the addon from the project settings (`Plugins` tab). Such is the case for the `Network` addon.

## Tutorial

On my web page [kehomsforge.com](http://kehomsforge.com/tutorials/multi/GodotAddonpack) there is a set of tutorials for each of the addons in this pack. Each page corresponds to one addon and contains two major sections, one explaining the basics of using the addon while the other explains a little bit of how the addon internally works.

