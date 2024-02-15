-- @noindex

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

local function hsl2rgb(H, S, L, reaper_color)
	reaper_color = reaper_color or false

	local C = (1-math.abs((2*L)-1))*S
	local X = C*(1-math.abs((((H%360) / 60)%2)-1))
	local m = L - C/2

	local color = {0, 0, 0}

	H = H % 360.0
	if 0 <= H and H < 60 then
		color = {C, X, 0}
	elseif H < 120 then
		color = {X, C, 0}
	elseif H < 180 then
		color = {0, C, X}
	elseif H < 240 then
		color = {0, X, C}
	elseif H < 300 then
		color = {X, 0, C}
	elseif H < 360 then
		color = {C, 0, X}
	end

	local outColor	= 0x0000000
	local r = math.floor((color[1]+m)*255)
	local g = math.floor((color[2]+m)*255)
	local b = math.floor((color[3]+m)*255)
	outColor		= r
	outColor		= (outColor << 8) | g
	outColor		= (outColor << 8) | b
	if reaper_color then
		outColor = outColor | 0x1000000
	else
		outColor = (outColor << 8) | 0xFF
	end
	return outColor
end

--[[===================================================]]--

local function GetNoteData(take, _id)
	local _retval, _selected, _muted, _startppqpos, _endppqpos, _chan, _pitch, _vel = reaper.MIDI_GetNote(take, _id)
	if not _retval then
		return nil
	end

	return {
		id 			= _id,
		selected	= _selected,
		muted		= _muted,
		start_pos	= _startppqpos,
		end_pos		= _endppqpos,
		channel		= _chan + 1, -- [1, 16]
		pitch		= _pitch,
		vel			= _vel
	}
end

--[[===================================================]]--

local ImGui = {}
local JS = {}
for name, func in pairs(reaper) do
	local name_imgui = name:match('^ImGui_(.+)$')
	local name_js = name:match('^JS_(.+)$')
	if name_imgui then
		ImGui[name_imgui] = func
		goto namespace_cont
	end

	if name_js then
		JS[name_js] = func
		goto namespace_cont
	end

	::namespace_cont::
end
--local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

local function get_script_path()
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	return filename:match("^(.*)[\\/](.-)$")
end
local function add_to_package_path(subpath)
	package.path = subpath .. "/?.lua;" .. package.path
end
add_to_package_path(get_script_path())

--[[===================================================]]--

-- 61 drums
local drums_start_pitch = 27-1
local drums_end_pitch = 87-1
local ch10_drum_names = {
	-- Roland GS
	[27] = "Filter Snap", -- or High Q
	[28] = "Slap Noise",
	[29] = "Scratch Push",
	[30] = "Scratch Pull",
	[31] = "Drum sticks",
	[32] = "Square Click",
	[33] = "Metronome Click",
	[34] = "Metronome Bell",

	-- General MIDI Standard
	[35] = "Acoustic Bass Drum",
	[36] = "Electric Bass Drum",
	[37] = "Side Stick",
	[38] = "Acoustic Snare",
	[39] = "Hand Clap",
	[40] = "Electric Snare",
	[41] = "Low Floor Tom",
	[42] = "Closed Hi-hat",
	[43] = "High Floor Tom",
	[44] = "Pedal Hi-hat",
	[45] = "Low Tom",
	[46] = "Open Hi-hat",
	[47] = "Low-Mid Tom",
	[48] = "High-Mid Tom",
	[49] = "Crash Cymbal 1",
	[50] = "High Tom",
	[51] = "Ride Cymbal 1",
	[52] = "Chinese Cymbal",
	[53] = "Ride Bell",
	[54] = "Tambourine",
	[55] = "Splash Cymbal",
	[56] = "Cowbell",
	[57] = "Crash Cymbal 2",
	[58] = "Vibraslap",
	[59] = "Ride Cymbal 2",
	[60] = "High Bongo",
	[61] = "Low Bongo",
	[62] = "Mute High Conga",
	[63] = "Open High Conga",
	[64] = "Low Conga",
	[65] = "High Timbale",
	[66] = "Low Timbale",
	[67] = "High Agogô",
	[68] = "Low Agogô",
	[69] = "Cabasa",
	[70] = "Maracas",
	[71] = "Short Whistle",
	[72] = "Long Whistle",
	[73] = "Short Guiro",
	[74] = "Long Guiro",
	[75] = "Claves",
	[76] = "High Woodblock",
	[77] = "Low Woodblock",
	[78] = "Mute Cuica",
	[79] = "Open Cuica",
	[80] = "Mute Triangle",
	[81] = "Open Triangle",
	-- Roland GS
	[82] = "Shaker",
	[83] = "Jingle Bell",
	[84] = "Belltree",
	[85] = "Castanets",
	[86] = "Mute Surdo",
	[87] = "Open Surdo",
}

--[[===================================================]]--

local M2I = {
	version = "2.3.1",

	sources = {},
	chords  = {},
	channel_tracks = {},

	n_channels = 0,
	is_midi_loaded = false,
	processed_midi_take = nil,
	processed_midi_take_name = "None",

	formats_string  = "",
	allowed_formats = {
		{"MP4 Files (.mp4)",	"*.mp4"},
		{"WEBM Files (.webm)",	"*.webm"},

		{"MP3 Files (.mp3)",	"*.mp3"},
		{"WAV Files (.wav)",	"*.wav"},

		{"All Files", "*.*"},
	},

	ResetAll = function(self)
		self.chords = {}
		self.channel_tracks = {}
		self.n_channels = 0
		self.processed_midi_take = nil
		self.processed_midi_take_name = "None"

		self.widget.midi_notes_num		= 0
		self.widget.midi_notes_read		= 0
		self.widget.midi_load_progress	= 0
		self.widget.midi_notes_channel_destribute = 0

		self.widget.items_progress	= 0
		self.widget.generated_notes = 0
	end,

	widget = {
		CHB_inherit_vol_click	= false,
		CHB_inherit_vol			= false,
		-------------------------------------
		CHB_blank_items			= false,
		CHB_blank_items_click	= false,
		-------------------------------------
		CHB_skip_empty_channels_click	= false,
		CHB_skip_empty_channels			= false,
		-------------------------------------
		midi_notes_num					= 0,
		midi_notes_read					= 0,
		midi_notes_channel_destribute	= 0,

		midi_load_progress = 0.0,
		-------------------------------------
		items_progress		= 0.0,
		generated_notes		= 0,
	},

	table_content = {
		-- Channel
		function(self, _ctx, index, channel_data)
			local color = 0x888888FF
			if channel_data then
				color = channel_data.is_empty and 0x888888FF or hsl2rgb(120, 1, 0.8)
			end
			ImGui.TextColored(_ctx, color, index)
		end,

		-- Source
		function(self, _ctx, index, _)
			ImGui.PushID(_ctx, index+50)
			local does_source_exist = self.sources[index] ~= "" and self.sources[index] ~= nil
			local text	= (does_source_exist) and self.sources[index] or "Select source for this channel"
			local color = 0x888888FF
			if self.sources[index] ~= nil and self.sources[index] ~= "" then
				text = text:match("[^\\]*$")
				color = 0xFFFFFFFF
			end

			ImGui.PushStyleColor(_ctx, ImGui.Col_Text(), color)
			ImGui.PushStyleColor(_ctx, ImGui.Col_HeaderHovered(), 0xFFFFFF55)
			ImGui.Selectable(_ctx, text)
			ImGui.PopStyleColor(_ctx, 2)

			-- Drop actions
			if ImGui.BeginDragDropTarget(_ctx) then
				-- First try file drop
				local rv_file, file_count = ImGui.AcceptDragDropPayloadFiles(_ctx)
				if rv_file then
					local rv, file = ImGui.GetDragDropPayloadFile(_ctx, 0)
					self.sources[index] = file
				else -- Then Try UI drop
					local rv_ui, payload = ImGui.AcceptDragDropPayload(_ctx, "DND_SAMPLES")
					if rv_ui then
						local payload_n = tonumber(payload)
						local old_source = self.sources[index]
						self.sources[index] = self.sources[payload_n]
						self.sources[payload_n] = old_source
					end
				end
				ImGui.EndDragDropTarget(_ctx)
			end

			-- Skip Drag if empty source
			if not does_source_exist then
				ImGui.PopID(_ctx)
				return
			end

			-- Drag for swap
			if ImGui.BeginDragDropSource(_ctx, ImGui.DragDropFlags_None()) then
				-- Set payload to carry the index of our item (could be anything)
				ImGui.SetDragDropPayload(_ctx, "DND_SAMPLES", tostring(index))

				-- Drag preview
				ImGui.Text(_ctx, ("Moving %s"):format(text))
				ImGui.EndDragDropSource(_ctx)
			end

			ImGui.PopID(_ctx)
		end,

		-- Set Button
		function(self, _ctx, index, _)
			ImGui.PushID(_ctx, index)
			--if ImGui.Button(_ctx, "Set") then
			if ImGui.SmallButton(_ctx, "Set") then
				local retval, fileNames = JS.Dialog_BrowseForOpenFiles("Source to use for Media Items", os.getenv("HOMEPATH") or "", "", formats_string, false)
				if retval and fileNames ~= "" then
					self.sources[index] = fileNames
				end
			end
			ImGui.PopID(_ctx)
		end,

		-- Clear Button
		function(self, _ctx, index, _)
			ImGui.PushID(_ctx, index)
			if ImGui.SmallButton(_ctx, "Clr") then
				self.sources[index] = ""
			end
			ImGui.PopID(_ctx)
		end
	},
}

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

function M2I:ProcessMIDI(midi_take)
	reaper.ClearConsole()

	reaper.MIDI_Sort(midi_take)
	local _, notes_num, _, _ = reaper.MIDI_CountEvts(midi_take)
	self.widget.midi_notes_num = notes_num

	--[[============================================]]--
	--[[============================================]]--

	-- Detecting overlapping notes
	local max_concurrent_notes = 1
	local current_chord		= {}
	for id = 0, notes_num - 1 do
		local current_note = GetNoteData(midi_take, id) -- Can be nil if the notes are filtered out in the editor

		-- Go through all notes in the chord set (if not empty)
		local chord_note_index = 1
		local found_overlap = false

		if current_note == nil then
			goto skip_filtered_out_note
		end

		while chord_note_index <= #current_chord do
			local chord_note = current_chord[chord_note_index]

			if current_note.id ~= chord_note.id then
				local isNote_after_start = current_note.start_pos >= chord_note.start_pos
				local isNote_before_end  = current_note.start_pos <  chord_note.end_pos

				-- If the note overlaps - we continue constructing chord set
				if isNote_after_start and isNote_before_end then
					table.insert(current_chord, current_note)

					if #current_chord > max_concurrent_notes then
						max_concurrent_notes = #current_chord
					end

					found_overlap = true

					break
				end
			end

			chord_note_index = chord_note_index + 1
		end

		-- else we make a new chord set
		if not found_overlap and #current_chord > 0 then
			table.insert(self.chords, current_chord)
			current_chord = {}
		end

		if #current_chord == 0 then
			table.insert(current_chord, current_note)
		end

		self.widget.midi_notes_read = self.widget.midi_notes_read + 1

		::skip_filtered_out_note::
	end

	-- Insert the last set.
	table.insert(self.chords, current_chord)

	--[[============================================]]--
	--[[============================================]]--

	--                  Intermission                  --
	--   I hate how big this whole algorithm already  --
	--      but i'm lazy to think smart about it	  --
	--             at least it should work			  --
	--            this is the slowest part            --

	--[[============================================]]--
	--[[============================================]]--

	self.n_channels = 0
	for _, chord in pairs(self.chords) do
		for _, note in pairs(chord) do
			-- Go through tracks and find valid position
			local track_search_index = 1
			while true do
				local found_channel_group_track = self.channel_tracks[note.channel]
				local found_notes_track = nil

				-- Create group track for a channel if doesn't exist already
				if found_channel_group_track == nil then
					self.channel_tracks[note.channel] = {
						channel = note.channel,
						group_track = nil, 		--new_group_track,
						tracks = {}
					}

					found_channel_group_track = self.channel_tracks[note.channel]

					self.n_channels = self.n_channels + 1
				end

				if note.channel ~= 10 then
					found_notes_track = found_channel_group_track.tracks[track_search_index]
				else
					found_notes_track = found_channel_group_track.tracks[note.pitch-drums_start_pitch]
				end

				-- If next track to check for valid positions
				-- doesn't exist then we make it
				if found_notes_track == nil then
					if note.channel ~= 10 then
						table.insert(found_channel_group_track.tracks, {
								parent = found_channel_group_track,
								track  = nil, --new_items_track,
								items  = {} -- notes
							}
						)

						found_notes_track = found_channel_group_track.tracks[track_search_index]
					else
						for i = 1, drums_end_pitch - drums_start_pitch + 1 do
							found_channel_group_track.tracks[i] = {
								parent = found_channel_group_track.group_track,
								track  = nil,	--new_items_track
								items  = {}		-- notes
							}
						end

						found_notes_track = found_channel_group_track.tracks[note.pitch-drums_start_pitch]
					end

					-- can append note right away
					table.insert(found_notes_track.items, note)
					break
				end

				if note.channel ~= 10 then
					-- Check if it overlaps with anything
					-- it better damn not be >:C
					local isOverlaping = false
					for _, item in pairs(found_notes_track.items) do
						local isAtStart = note.start_pos >= item.start_pos
						local isBeforeEnd = note.start_pos < item.end_pos
						if isAtStart and isBeforeEnd then
							isOverlaping = true
							break
						end
					end

					if not isOverlaping then
						table.insert(found_notes_track.items, note)
						break
					end

					-- else: continue the search for a free spot, if not a drum channel
					track_search_index = track_search_index + 1
				else -- if a drum then just insert, drum notes never overlap.
					table.insert(found_notes_track.items, note)
					break
				end
			end
			self.widget.midi_notes_channel_destribute = self.widget.midi_notes_channel_destribute + 1
		end
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Sort table

	-- Fill up so the sort can work
	for i = 1 , 16 do
		if self.channel_tracks[i] == nil then
			self.channel_tracks[i] = {
				channel = i,
				is_empty = true
			}
		end
	end

	table.sort(self.channel_tracks, function(channelA, channelB)
		return channelA.channel < channelB.channel
	end)

	return true
end


_G._print = print
_G.print = function(...)
	local string = ""
	for _, v in pairs({...}) do
		string = string .. tostring(v) .. "\t"
	end
	string = string.."\n"
	reaper.ShowConsoleMsg(string)
end

local function printTable(t, show_details)
	show_details = show_details or false
	local printTable_cache = {}

	local function sub_printTable(_t, indent, indenty)
		indenty = indenty or indent

		if printTable_cache[tostring(_t)] then
			print(indenty .. "*" .. tostring(_t))
			return
		end


		printTable_cache[tostring(_t)] = true
		if type(_t) ~= "table" then
			print(indenty..(show_details and tostring(_t) or ""))
			return
		end


		for key, val in pairs(_t) do
			if type(val) == "table" then
				print(indenty .. "[" .. key .. "] => " .. (show_details and tostring(_t) or "") .. "{")
				sub_printTable(val, indent, indenty..indent)
				print(indenty .. "}")
			elseif type(val) == "string" then
				print(indenty .. "[" .. key .. '] => "' .. val .. '"')
			else
				print(indenty .. "[" .. key .. "] => " .. tostring(val))
			end
		end
	end

	if type(t) == "table" then
		print((show_details and tostring(t)..": " or "").."{")
		sub_printTable(t, "\t")
		print("}")
	else
		sub_printTable(t, "\t")
	end
end

function M2I:Generate(midi_take)
	self.widget.generated_notes = 0

	reaper.Undo_BeginBlock()

	if not reaper.ValidatePtr(midi_take, "MediaItem_Take*") then
		reaper.MB("The MIDI Item doesn't exist anymore.", "Error", 0)
		return false
	end

	local midi_track  = reaper.GetMediaItemTakeInfo_Value(midi_take, "P_TRACK")
	local track_index = reaper.GetMediaTrackInfo_Value(midi_track, "IP_TRACKNUMBER")

	for _, channel_group_track in pairs(self.channel_tracks) do
		-- Stupid GOTOs that i use as `continue` don't let me do the jumps because of local variable being declared
		-- inbetween the lable and goto call >:(
		-- I like to do it unsafe, you dick, I know what I'm doing.
		local new_group_track
		local source_name = ""
		local channel_name = ""

		-- If skipping sampless channels
		if self.widget.CHB_skip_empty_channels then
			if self.sources[channel_group_track.channel] == nil or self.sources[channel_group_track.channel] == "" then
				goto cntue_tracks
			end
		end
		-- Skip if empty channel
		if channel_group_track.is_empty then
			goto cntue_tracks
		end

		-- Create channel Group Track
		reaper.InsertTrackAtIndex(track_index - 1, true)
		new_group_track = reaper.GetTrack(0, track_index - 1)
		source_name = self.sources[channel_group_track.channel] and self.sources[channel_group_track.channel]:match("[^\\]*$") or "BLANK"
		channel_name = ("CHANNEL_%d - %s"):format(channel_group_track.channel, source_name)
		reaper.GetSetMediaTrackInfo_String(new_group_track, "P_NAME", channel_name, true)
		channel_group_track.group_track = new_group_track

		track_index = track_index + 1

		local channel_track_index = reaper.GetMediaTrackInfo_Value(channel_group_track.group_track, "IP_TRACKNUMBER")
		-- Create channel Track for Notes
		for _, notes_track in pairs(channel_group_track.tracks) do
			local new_items_track
			local note_track_name = ""

			if #notes_track.items == 0 then
				goto skip_note_track1
			end

			reaper.InsertTrackAtIndex(channel_track_index, true)
			new_items_track = reaper.GetTrack(0, channel_track_index)
			if channel_group_track.channel ~= 10 then
				note_track_name = ("%d - %s"):format(channel_group_track.channel, source_name)
			else
				note_track_name = ("%d: %s - %s"):format(
					notes_track.items[1].pitch-drums_start_pitch,
					ch10_drum_names[notes_track.items[1].pitch] or "Unknown",
					source_name
				)
			end
			reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", note_track_name, true)

			notes_track.track = new_items_track

			track_index = track_index + 1

			::skip_note_track1::
		end

		::cntue_tracks::
	end

	--[[============================================]]--

	-- TODO: Sorting drums holy fuck what the fuck
	print("Sorting drums")
	-- Sort drums folder
	if self.channel_tracks[10] then
		local selected_tracks_count = reaper.CountSelectedTracks(0)

		for i=1, selected_tracks_count do
			local sel_track = reaper.GetSelectedTrack(0, i-1)
			reaper.SetTrackSelected(sel_track, false)
		end

		for i = 1, #self.channel_tracks[10].tracks do
			local drum_track_data = self.channel_tracks[10].tracks[i]
			if drum_track_data.track then
				local drum_group_index = reaper.GetMediaTrackInfo_Value(self.channel_tracks[10].group_track, "IP_TRACKNUMBER")
				print(drum_track_data.items[1].pitch-drums_start_pitch)
				reaper.SetTrackSelected(drum_track_data.track, true)
				reaper.ReorderSelectedTracks(drum_group_index, 0)
				reaper.SetTrackSelected(drum_track_data.track, false)
				break
			end
		end
	end

	-- Make folders
	local color_step = 360.0/self.n_channels
	local channel_index = 0
	for _, channel_group_data in pairs(self.channel_tracks) do
		local color

		-- If skipping sampless channels
		if self.widget.CHB_skip_empty_channels then
			if self.sources[channel_group_data.channel] == nil or self.sources[channel_group_data.channel] == "" then
				goto cntn_folders
			end
		end
		if channel_group_data.is_empty then
			goto cntn_folders
		end

		-- mark group track as a group
		reaper.SetMediaTrackInfo_Value(channel_group_data.group_track, "I_FOLDERDEPTH", 1)

		local found_last_track_in_group = nil
		if channel_group_data.channel ~= 10 then
			found_last_track_in_group = channel_group_data.tracks[1].track
		else
			for i = drums_end_pitch-drums_start_pitch+1, 1, -1 do
				local found_drum = channel_group_data.tracks[i]
				print(i, found_drum)
				if found_drum.track ~= nil then
					found_last_track_in_group = found_drum.track
					break
				end
			end
		end

		-- mark the last track as an edning track for the group
		reaper.SetMediaTrackInfo_Value(found_last_track_in_group, "I_FOLDERDEPTH", -1)

		-- Coloring
		color = hsl2rgb(color_step * (channel_index), 1, 0.8, true)
		reaper.SetTrackColor(channel_group_data.group_track, color)
		for _, notes_track in pairs(channel_group_data.tracks) do
			if notes_track.track then
				reaper.SetTrackColor(notes_track.track, color)
			end
		end
		channel_index = channel_index + 1
		::cntn_folders::
	end

	-- Reorder Channel Folders according to the sorted table
	--for _, channel_group_track in pairs(self.channel_tracks) do
	--	if channel_group_track.is_empty then
	--		goto cntue_reorder
	--	end
	--	if not reaper.ValidatePtr(channel_group_track.group_track, "MediaTrack*") then
	--		goto cntue_reorder
	--	end
	--
	--	reaper.SetTrackSelected(channel_group_track.group_track, true)
	--	reaper.ReorderSelectedTracks(track_index-1, 0)
	--	reaper.SetTrackSelected(channel_group_track.group_track, false)
	--
	--	::cntue_reorder::
	--end

	--[[============================================]]--
	--[[============================================]]--

	-- Detect the lowest pitch in the first potential chord
	local first_base_pitch = 127
	if #self.chords[1] > 1 then
		for _, note in pairs(self.chords[1]) do
			if note.pitch < first_base_pitch then
				first_base_pitch = note.pitch
			end
		end
	else
		first_base_pitch = self.chords[1][1].pitch
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Create the items
	for _, channel_group_track in pairs(self.channel_tracks) do
		if channel_group_track.is_empty then
			goto cnte_create_items
		end
		if self.widget.CHB_skip_empty_channels then
			if self.sources[channel_group_track.channel] == nil or self.sources[channel_group_track.channel] == "" then
				goto skip_sourceless
			end
		end
		for _, notes_track in pairs(channel_group_track.tracks) do
			if not notes_track.track then
				print("Item create: skip")
				goto skip_trackless
			end
			print("Items:", notes_track.items)
			for _, note in pairs(notes_track.items) do
				local start_pos
				local end_pos
				local new_item
				local new_item_take

				new_item	  = reaper.AddMediaItemToTrack(notes_track.track)
				new_item_take = reaper.AddTakeToMediaItem(new_item)

				--Applying params
				reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)
				reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", note.pitch - first_base_pitch)
				if self.widget.CHB_inherit_vol then
					reaper.SetMediaItemInfo_Value(new_item, "D_VOL", note.vel/127.0)
				end

				-- Applying Sources
				if not self.widget.CHB_blank_items then
					local note_channel = self.sources[note.channel]
					if note_channel ~= nil then
						local source_file = reaper.PCM_Source_CreateFromFile(note_channel)
						reaper.SetMediaItemTake_Source(new_item_take, source_file)
					end
				end

				start_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.start_pos)
				end_pos		= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.end_pos)

				reaper.SetMediaItemPosition(new_item, start_pos, false)
				reaper.SetMediaItemLength(new_item, end_pos-start_pos, false)

				self.widget.generated_notes = self.widget.generated_notes + 1
			end
			::skip_trackless::
		end
		::skip_sourceless::
		::cnte_create_items::
	end

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()

	return true
end


function M2I:LoadSelectedMIDI()
	self:ResetAll()

	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then
		reaper.MB("No MIDI was selected", "Error", 0)
		return nil
	end

	local midi_item	= reaper.GetSelectedMediaItem(0, 0)
	local midi_take = reaper.GetActiveTake(midi_item)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI", "Error", 0)
		return nil
	end

	local success = self:ProcessMIDI(midi_take)
	if not success then
		return nil
	end

	return midi_take
end


--[[==================================================]]--
--[[==================================================]]--
--[[==================================================]]--


function M2I:UpdateParams()
	self.widget.midi_load_progress =
	self.widget.midi_notes_num == 0
			and 0
			or (self.widget.midi_notes_read + self.widget.midi_notes_channel_destribute) / (self.widget.midi_notes_num * 2)

	self.widget.items_progress = self.widget.generated_notes / self.widget.midi_notes_read
end


function M2I:UI(ctx)

	--[[===============================]]--
	--[[============ PARAMS ===========]]--
	--[[===============================]]--

	ImGui.Text(ctx, "Select a MIDI item and press \"Load MIDI\".")

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextAlign(), 0.5, 0.5)
	ImGui.SeparatorText(ctx, "Properties")
	ImGui.PopStyleVar(ctx)

	self.widget.CHB_inherit_vol_click, self.widget.CHB_inherit_vol = ImGui.Checkbox(ctx, "Inherit Volume", self.widget.CHB_inherit_vol)

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextAlign(), 0.5, 0.5)
	ImGui.SeparatorText(ctx, "MIDI")
	ImGui.PopStyleVar(ctx)

	--[[==================================]]--
	--[[============ MIDI LOAD ===========]]--
	--[[==================================]]--

	ImGui.TextColored(ctx,
		hsl2rgb(60, 1, 0.8),
		"If MIDI did not read at 100% then that means you\nhave filtered out Channels in the MIDI Editor."
	)

	if ImGui.Button(ctx, "Load MIDI") then
		self.processed_midi_take = self:LoadSelectedMIDI()
		self.is_midi_loaded = reaper.ValidatePtr(self.processed_midi_take, "MediaItem_Take*")
	end

	ImGui.SameLine(ctx)

	--	void ImGui.ProgressBar(ImGui_Context ctx, number fraction, number size_arg_w = -FLT_MIN, number size_arg_h = 0.0, string overlay = nil)
	ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram(), 0xE67A00FF)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize(), 1)
	ImGui.ProgressBar(ctx, self.widget.midi_load_progress, 0, 0, ("%d/%d"):format(self.widget.midi_notes_read, self.widget.midi_notes_num))
	ImGui.PopStyleVar(ctx)
	ImGui.PopStyleColor(ctx)

	ImGui.SameLine(ctx)
	ImGui.Text(ctx, ("%%%03d"):format(math.floor(self.widget.midi_load_progress * 100.0)))
	--ImGui.Spacing(ctx)

	local table_flags =
	ImGui.TableFlags_SizingFixedFit() |
			ImGui.TableFlags_RowBg() |
			ImGui.TableFlags_Borders() |
			ImGui.TableFlags_Hideable()

	if ImGui.BeginTable(ctx, "table", 4, table_flags) then
		--(ctx, label, flagsIn, init_width_or_weightIn, integer user_idIn)
		ImGui.TableSetupColumn(ctx, "Channel",	ImGui.TableColumnFlags_WidthFixed())
		ImGui.TableSetupColumn(ctx, "Source",	ImGui.TableColumnFlags_NoResize(), 210)
		ImGui.TableSetupColumn(ctx, "",			ImGui.TableColumnFlags_WidthFixed())
		ImGui.TableSetupColumn(ctx, "",			ImGui.TableColumnFlags_WidthFixed())
		ImGui.TableHeadersRow(ctx)
		for row = 1, 16 do
			ImGui.TableNextRow(ctx)
			for column = 0, 3 do
				ImGui.TableSetColumnIndex(ctx, column)
				self.table_content[column+1](self, ctx, row, self.channel_tracks[row])
			end
		end

		ImGui.TableNextRow(ctx) do
		local color = hsl2rgb(60, 1, 0.8)
		ImGui.TableSetColumnIndex(ctx, 0)
		ImGui.TextColored(ctx, color, "All")

		ImGui.TableSetColumnIndex(ctx, 1)
		ImGui.TextColored(ctx, color, "Select source for all channels")

		ImGui.TableSetColumnIndex(ctx, 2)
		if ImGui.SmallButton(ctx, "Set") then
			local retval, fileNames = JS.Dialog_BrowseForOpenFiles(
					"Source to use for all Channels",
					os.getenv("HOMEPATH") or "", "",
					self.formats_string, false
			)
			if retval and fileNames ~= "" then
				for i = 1, 16 do
					self.sources[i] = fileNames
				end
			end
		end

		ImGui.TableSetColumnIndex(ctx, 3)
		if ImGui.SmallButton(ctx, "Clr") then
			for i = 1, 16 do
				self.sources[i] = ""
			end
		end
	end

		ImGui.EndTable(ctx)
	end

	--[[==========================================]]--
	--[[============= GENEATGE BUTTONS ===========]]--
	--[[==========================================]]--

	if reaper.ValidatePtr(self.processed_midi_take, "MediaItem_Take*") then

		ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextAlign(), 0.5, 0.5)
		ImGui.SeparatorText(ctx, "Generate Items")
		ImGui.PopStyleVar(ctx)

		if ImGui.Button(ctx, "Generate") then
			if self.processed_midi_take then
				local _ = self:Generate(self.processed_midi_take)
			end
		end

		ImGui.SameLine(ctx)

		ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram(), 0xE67A00FF)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize(), 1)
			ImGui.ProgressBar(ctx, self.widget.items_progress, 0, 0, ("%d/%d"):format(self.widget.generated_notes, self.widget.midi_notes_read))
		ImGui.PopStyleColor(ctx)
		ImGui.PopStyleVar(ctx)

		ImGui.SameLine(ctx)
		ImGui.Text(ctx, ("%%%03d"):format(math.floor(self.widget.items_progress * 100)))

		self.widget.CHB_blank_items_click, self.widget.CHB_blank_items = ImGui.Checkbox(ctx, "Blank Items", self.widget.CHB_blank_items)
		ImGui.SameLine(ctx)
		self.widget.CHB_skip_empty_channels_click, self.widget.CHB_skip_empty_channels = ImGui.Checkbox(ctx, "Skip Sampless channels", self.widget.CHB_skip_empty_channels)
	else
		if self.is_midi_loaded then
			self.is_midi_loaded = false
			self:ResetAll()
		end
	end
end


--[[=========================================]]--
--[[=========================================]]--
--[[=========================================]]--


function M2I:Init()
	for i = 1, 16 do
		self.sources[i] = nil
	end

	--"ReaScript files\0*.lua;*.eel\0Lua files (.lua)\0*.lua\0EEL files (.eel)\0*.eel\0\0".
	for _, format in pairs(self.allowed_formats) do
		self.formats_string = self.formats_string..format[1]..'\0'..format[2]..'\0'
	end
end


function M2I:SetupUI()
	local ctx = ImGui.CreateContext("MIDI -> Items")

	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsResizeFromEdges(), 1)
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsResizeFromEdges(), 1)

	local window_flags =
	--ImGui.WindowFlags_None() |
	ImGui.WindowFlags_NoDocking() |
			ImGui.WindowFlags_NoResize() |
			ImGui.WindowFlags_NoCollapse() |
			ImGui.WindowFlags_NoSavedSettings() |
			ImGui.WindowFlags_AlwaysAutoResize()

	function M2I:LoopUI()
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign(), 0.5, 0.5)
		local visible, open = reaper.ImGui_Begin(ctx, "MIDI -> Items "..self.version, true, window_flags)
		ImGui.PopStyleVar(ctx)
		if visible then
			self:UpdateParams()
			self:UI(ctx)
			ImGui.End(ctx)
		end

		-- Continue looping itself
		if open then
			reaper.defer(function() M2I.LoopUI(self) end)
		end
	end

	reaper.defer(function() M2I.LoopUI(self) end)
end


--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--


function main()
	M2I:Init()
	M2I:SetupUI()
end

main()


















