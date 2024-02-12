--[[
@metapackage
@description Items Based On MIDI
@author Zly
@version 1.1.1
@provides
	[main] .\ItemsBasedOnMIDI\Zly_ItemsBasedOnMIDI.lua
@about
	# Items Based On MIDI

	- Creates Items based on selected MIDI.
	- Each of the item's pitch is based off the first note in the MIDI.
	- Inherits Volume from midi as well.
@changelog
	- Reversed tracks to more or less represent the midi.
	- Made it so all the notes refer the very first note in the track
--]]