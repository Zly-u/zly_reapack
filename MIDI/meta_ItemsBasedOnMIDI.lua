--[[
@metapackage
@description Items -> MIDI
@author Zly
@version 1.2
@provides
	[main] .\ItemsBasedOnMIDI\Zly_ItemsBasedOnMIDI.lua
@about
	# Items Based On MIDI

	- Creates Items based on selected MIDI.
	- Each of the item's pitch is based off the first note in the MIDI.
	- Inherits Volume from midi as well.
@changelog
	- Sorts each note to their corresponding channel.
	- Makes Groups for each channel.
	- Sorts the Grouped Tracks.
	- Colors every Channel Group
--]]