--[[
@metapackage
@description Items -> MIDI
@author Zly
@version 1.2.1
@provides
	[main] .\ItemsBasedOnMIDI\Zly_ItemsBasedOnMIDI.lua
@about
	# Items Based On MIDI

	- Creates Items based on selected MIDI.
	- Each of the item's pitch is based off the first note in the MIDI.
	- Inherits Volume from midi.
	- Creates Channels in their own Folder Tracks for ease of work.
@changelog
	- Renamed script to be more compact with naming
	- Fixed weird case with Channel 0 not being sorted.
	- Now channels start from 1, instead of 0.
--]]