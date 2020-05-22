Some smaller commits related to minor fixes (specially comment corrections) are not going to be listed here.

#### 2020 May 22
* (Network) Now properly clear remote player list when disconnecting from server.


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
