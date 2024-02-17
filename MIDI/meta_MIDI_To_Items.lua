--[[
@metapackage
@description MIDI To Items Converter
@author Zly
@version 2.4.3
@provides
	[main] .\MIDI_To_Items\Zly_MIDI_To_Items.lua
@about
	# MIDI To Items Converter

	- Creates Media Items based on selected MIDI.
	- Each of the item's pitch is relative to the first note in the MIDI.
	- Creates Channels in their own Folder Tracks for ease of work.
	- Able to choose a sample source file for each Channel before generating all the Media Items.
	- Drag and Drop features:
		* Ability to drop sources into the Channels.
		* Ability to rearrange the sources in the Channels.
	- And some more.
@screenshot
	Overview https://github.com/Zly-u/NAGASHIZAR_reapack/blob/master/MIDI/MIDI_To_Items/img_MIDI2Items.png
@links
	Author https://twitter.com/zly_u
	DnD_Preview https://github.com/Zly-u/NAGASHIZAR_reapack/blob/master/MIDI/MIDI_To_Items/Preview_DnD_Feature.gif
@donation
	Donate https://boosty.to/zly
@changelog
	-  Fixed missed formats variable in the object.
--]]