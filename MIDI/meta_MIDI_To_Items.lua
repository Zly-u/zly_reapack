--[[
@metapackage
@description MIDI -> Items
@author Zly
@version 1.2.2
@provides
	[main] .\MIDI_To_Items\Zly_MIDI_To_Items.lua
@about
	# Items Based On MIDI

	- Creates Items based on selected MIDI.
	- Each of the item's pitch is based off the first note in the MIDI.
	- Inherits Volume from midi.
	- Creates Channels in their own Folder Tracks for ease of work.

	# USAGE
	1. Select MIDI (Right now works only with one selected MIDI at the time)
	2. Use the script
@screenshot
	Image Preview https://github.com/Zly-u/NAGASHIZAR_reapack/blob/master/MIDI/ItemsBasedOnMIDI/img_MIDI2Items.png
@changelog
	- Fixed sorting when some channels are missing.
	- Fixed coloring based on the amount of channels.
--]]