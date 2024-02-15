--[[
@metapackage
@description MIDI -> Items
@author Zly
@version 2.3
@provides
	[main] .\MIDI_To_Items\Zly_MIDI_To_Items.lua
@about
	# Items Based On MIDI

	- Creates Media Items based on selected MIDI.
	- Each of the item's pitch is relative to the first note in the MIDI.
	- Creates Channels in their own Folder Tracks for ease of work.
	- Able to choose a sample source file for each Channel before generating all the Media Items.
	- Drag and Drop features:
		- Ability to drop sources into the Channels.
		- Ability to rearrange the sources in the Channels.
	- And some more.
@screenshot
	Overview https://github.com/Zly-u/NAGASHIZAR_reapack/blob/master/MIDI/MIDI_To_Items/img_MIDI2Items.png
	DnD Preview https://github.com/Zly-u/NAGASHIZAR_reapack/blob/master/MIDI/MIDI_To_Items/Preview_DnD_Feature.gif
@changelog
	- Added a feature for Channel 10 (drums channel): feature redistributes notes to their own tracks and renames tracks to their corresponding drum names that those pitches are mapped to by the MIDI standard.
--]]