--[[
@metapackage
@description Video Auto-Flipper [YTPMV]
@author Zly
@version 1.0.3
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

	- Flips selected items with a specified presset in the GUI.\
	- Has additional settings for the flipping.
	- Flips preview in the GUI.
	- Has a tab for VFX chains for ease of making simple but yet presentable and easilty animatable visuals in Reaper.
	- Has a tab for Helper functions.
	- Has some brief FAQ page, just in case.
@changelog
	- Fixed the case where `reaper.CF_ShellExecute` didn't existed, so it would break the UI.
--]]