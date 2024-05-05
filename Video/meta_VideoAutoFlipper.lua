--[[
@metapackage
@description Video Auto-Flipper [YTPMV]
@author Zly
@version 1.1.2
@provides
	[main] .\VideoAutoFlipper\Zly_VideoAutoFlipper.lua
	.\VideoAutoFlipper\images\*.png
	.\VideoAutoFlipper\VP_Presets\*.eel
@links
	Details https://github.com/Zly-u/zly_reapack/tree/master/Video/VideoAutoFlipper
	Wiki https://github.com/Zly-u/zly_reapack/wiki
@donation
	Donate https://boosty.to/zly
@about
	# Video Auto-Flipper [YTPMV]

	- Flips selected items with a specified presset in the GUI.
	- Has additional settings for the flipping.
	- Flips preview in the GUI.
	- Has a tab for VFX chains for ease of making simple but yet presentable and easilty animatable visuals in Reaper.
	- Has a tab for Helper functions to assist with video animation and such.
	- Has some brief FAQ page, just in case.
@changelog
	- Changed VFX Effects add behavior: Chroma-Key is being added, if none existed already, when applying any of the VFX effects.
	- Opacity now adds after Chroma-key, so no more weird unexpected color behavior because of the wrong effects order.
	- Changed `Scale` effect to have filtering off by default.
	- Some additional FAQ pages.
--]]