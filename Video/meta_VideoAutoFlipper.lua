--[[
@metapackage
@description Video Auto-Flipper [YTPMV]
@author Zly
@version 1.1.1
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
	- Has a tab for Helper functions.
	- Has some brief FAQ page, just in case.
@changelog
	- Adapted `ImGui.BeginChild` to new version of ReaImGui to prevent crashes.
	- Made it so Flip Envelopes stretch to the start of the next items now, so potentially making it more practical for editing.
--]]