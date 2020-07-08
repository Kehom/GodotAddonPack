Some smaller commits related to minor fixes (specially comment corrections) are not going to be listed here.

#### 2020 Jul 08
* (Network) Small correction to the plugin loader, which should make the ProjectSettings window work as intended.

#### 2020 Jul 07
* (Network) Added means to easily correct local client snapshots once server data has triggered a *re-conciliation*. This should reduce the chance of visual glitches when entities are corrected. The tutorial has been updated to use this, under the *Correcting The Snapshot* topic.

#### 2020 Jun 11
* (Network) It now performs snapshot delta compression. If you want to always use full snapshot data set the `Full Snapshot Threshold` to 0 in the *Project Settings*. There is no need to change your code to use delta compression though. NOTE: rigid bodies are always triggering changes meaning that the savings on the mega-demo are not too great because there are 11 of those objects.

#### 2020 Jun 08
* New addon, "DebugHelper" meant to hold scripts to help with the fun debugging process.
* overlayinfo.gd DebugHelper "sub-addon" script to help dump text into the screen without the need to create multiple temporary UI controls all over the place.
* line3d.gd DebugHelper "sub-addon" script to help draw (debug) lines in 3D.

#### 2020 Jun 04
* (Network) Maximum snapshot history size can now be configured with a different size for clients and servers. By default 60 and 120, respectively.
* (Network) Analog input can now be quantized (8-bit precision). It is a project setting that can be enabled (by default it's not used). This creates a new interdependency on the `quantize.gd` script.

#### 2020 Jun 03
* (Network) Added a "prediction counter" that can be used to re-simulate entities that don't need input data when correction is triggered (`network.snapshot_data.get_prediction_count()`). Tutorial has been updated to show how to use this (topic `Prediction Without Input Data`).
* (Megademo) Glowing projectiles use this counter to re-simulate the movement when corrected by server data.

#### 2020 May 25
* (Network) Fixed problem that caused client's snapshot container to never be cleaned up when no input data is necessary (IE.: interacting with a menu).
* (Network) Mouse relative is accumulated in order to try to obtain a more consistent behavior when toggling VSync.
* (Megademo) Added code to "simulate" this menu situation (press ESCAPE during demo to toggle).
* (Megademo) Added F1 key to toggle VSync mode.

#### 2020 May 23
* (Network) When manually disconnecting from server, reset player data (both local and remote).
* (Network) When manually disconnecting from server, reset ENet object, which should fix problems when client goes back to main menu and start single player.
* Fixed a few typos, including in this changelog.

#### 2020 May 22
* (Network) Now properly clear remote player list when disconnecting from server.
* (Megademo) Improved how the disconnection from server is dealt with (kicked vs connection loss). Mostly, multiple causes will be handled from a single place.

#### 2020 May 20
* Added a new "sub-addon" into the General addon directory, `quantize.gd`. It provides means to quantize floating point numbers as well as compression of rotation quaternions using the smallest three method. Tutorial (http://kehomsforge.com/tutorials/multi/GodotAddonPack) has been updated.
* (Megademo) Now uses the rotation quaternion compression to replicate projectiles orientation.

#### 2020 May 15
* (Network) Replicated floating point numbers (even compound ones like Vector2, Vector3 etc) can use tolerance to compare them. Tutorial (http://kehomsforge.com/tutorials/multi/GodotAddonPack) has been updated to show how to use this (topic `Floating Point Comparison`)

#### 2020 May 13
* Added a new UI control, the `FancyLineEdit`.
* (Megademo) Changed the "clutter barrel" from CSGPrimitives to a crude "barrel" 3D model.
* (Megademo) projectiles now use client side prediction code.

#### 2020 May 05
* (Network) A rejected player is now properly disconnected.
* (Megademo) Fixed prediction code.

#### 2020 May 04
* (Network) Fixed wrong remote call in the chat system.
* (Network) Slightly improved the function to retrieve custom replicated properties.
* (Megademo) Fixed problem that prevented the main scene to be directly tested (F6 key)

#### 2020 April 17
* Initial release of the Addon Pack.
