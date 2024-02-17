-- @noindex

local function URL_Openner(URL)
	local OS = ({
		Win32 = "start",
		Win64 = "start",
		OSX32 = "open",
		OSX64 = "open",
		["macOS-arm64"] = "open",

		Other = "start",
	})[reaper.GetOS()]

	os.execute(OS .. " " .. URL)
end

local function MultLineStringConstructor(...)
	local strings_array = {...}
	local compiled_string = ""
	for index, line in pairs(strings_array) do
		compiled_string =
			compiled_string
			..line
			..(index ~= #strings_array and "\n" or "")
	end
	return compiled_string
end

local DepsChecker = {
	libs_to_check = {},
	builded_reapack_deps_list = "",
	builded_reapack_search_filter = "",
	-----------------------------------------------------
	AddDepsToCheck = function(self, _func, _filter)
		table.insert(self.libs_to_check, {
			func	= _func,
			filter	= _filter
		})
	end,
	CheckLibs = function(self)
		for index, lib in pairs(self.libs_to_check) do
			if not lib.func then
				self.builded_reapack_deps_list =
					self.builded_reapack_deps_list
					..'\t'..lib.filter
					..(index ~= #self.libs_to_check and '\n' or "")

				self.builded_reapack_search_filter =
				self.builded_reapack_search_filter
						..lib.filter
						..(index ~= #self.libs_to_check and " OR " or "")
			end
		end

		-- if empty then it's all good
		if self.builded_reapack_search_filter == "" then
			return true
		end

		-- I didn't wanted to write in [[str]] for a multiline string cuz it sucks to read in code
		-- and I didn't wanted to make one long ass single line string with '\n' at random places
		-- this way i can see the dimensions of the text for a proper formating
		local error_msg = MultLineStringConstructor(
				"Please install next Packages through ReaPack",
				"In Order for the script to work:\n",
				self.builded_reapack_deps_list,
				"\nAfter closing this window ReaPack's Package Browser",
				"will open with the dependencies you need!"
		)

		reaper.MB(error_msg, "Error", 0)

		if not reaper.ReaPack_BrowsePackages then
			local reapack_error = MultLineStringConstructor(
					"Someone told me you don't have ReaPack to get the deps from...",
					"After closing this window I will open the Official ReaPack website",
					"\"https://reapack.com/\" for you to download it from :)"
			)
			reaper.MB(reapack_error, "What the hell...", 0)
			URL_Openner("https://reapack.com/")
			return false
		end

		reaper.ReaPack_BrowsePackages(self.builded_reapack_search_filter)

		return false
	end,

	CheckIfIsAllInstalled = function(self)
		return self.is_all_good
	end
}

DepsChecker:AddDepsToCheck(reaper.JS_Dialog_BrowseForOpenFiles, "js_ReaScriptAPI")
DepsChecker:AddDepsToCheck(reaper.ImGui_Begin, "ReaImGui")
if not DepsChecker:CheckLibs() then
	return
end

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

--[[===================================================]]--

local function ImGui_HelpMarker(ctx, desc)
	ImGui.SameLine(ctx)
	ImGui.TextDisabled(ctx, "(?)")

	if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort()) then
		return
	end

	if ImGui.BeginTooltip(ctx) then
		ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
		ImGui.Text(ctx, desc)
		ImGui.PopTextWrapPos(ctx)
		ImGui.EndTooltip(ctx)
	end
end

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
	version = "2.4.3",

	sources = {},
	chords_channels = {},
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
		self.chords_channels = {}
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
		CHB_disable_interactive_click	= false,
		CHB_disable_interactive			= true,
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
		function(self, _ctx, index, channel_track_data)
			local color = 0x888888FF
			if channel_track_data then
				color = #channel_track_data.tracks == 0 and 0x888888FF or hsl2rgb(120, 1, 0.8)
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
				local retval, fileNames = JS.Dialog_BrowseForOpenFiles(
						"Source to use for Media Items",
						os.getenv("HOMEPATH") or "",
						"",
						self.formats_string,
						false
				)
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
	self.chords_channels = {}
	for i = 1, 16 do
		self.chords_channels[i] = {
			base_pitch = 127,
			chord_note_index = 1,
			found_overlap = false,
			chords = {}
		}
	end

	for id = 0, notes_num - 1 do
		local current_note = GetNoteData(midi_take, id) -- Can be nil if the notes are filtered out in the editor

		local current_channel
		local current_chords_list
		local current_chord

		if current_note == nil then goto skip_filtered_note end

		current_channel		= self.chords_channels[current_note.channel]
		current_chords_list	= current_channel.chords
		current_chord		= current_chords_list[#current_chords_list]


		-- create a set if none exist for the channel
		-- Or if it's at a drum track, there we don't care about chords.
		if current_chord == nil or current_channel.channel == 10 then
			-- Drum track
			if current_channel.channel == 10 then
				local drum_pitch = current_note.pitch-drums_start_pitch
				current_chord = current_chords_list[drum_pitch]
				if current_chord == nil then
					current_chords_list[drum_pitch] = {}
					current_chord = current_chords_list[drum_pitch]
				end
			else
				table.insert(current_chords_list, {})
				current_chord = current_chords_list[#current_chords_list]
			end

			table.insert(current_chord, current_note)

			goto skip
		end

		-- Overlap check with each note in the current chord
		while current_channel.chord_note_index <= #current_chord do
			local chord_note = current_chord[current_channel.chord_note_index]
			current_channel.found_overlap = false

			if current_note.id ~= chord_note.id then
				local isNote_after_start = current_note.start_pos >= chord_note.start_pos
				local isNote_before_end  = current_note.start_pos <  chord_note.end_pos

				-- If the note overlaps - we continue constructing chord set
				if isNote_after_start and isNote_before_end then
					table.insert(current_chord, current_note)
					current_channel.found_overlap = true
					break
				end
			end

			current_channel.chord_note_index = current_channel.chord_note_index + 1
		end

		-- If no note overlaping then we make a new set
		if not current_channel.found_overlap and #current_chord > 0 then
			current_channel.chord_note_index	= 1
			current_channel.found_overlap		= false

			table.insert(current_chords_list, {})
			current_chord = current_chords_list[#current_chords_list]
		end

		if #current_chord == 0 then
			table.insert(current_chord, current_note)
		end

		::skip::
		self.widget.midi_notes_read = self.widget.midi_notes_read + 1
		::skip_filtered_note::
	end

	-- Sort chords and assign base pitch
	for channel_index, chords_channel in pairs(self.chords_channels) do
		if #chords_channel.chords == 0 then goto skip_sort_for_empty end

		if channel_index == 10 then
			chords_channel.base_pitch = -1 -- Means we don't assign pitch
			goto skip_sort_for_drums
		end

		for _, chord in pairs(chords_channel.chords) do
			if #chord > 1 then
				table.sort(chord, function(A, B)
					return A.pitch < B.pitch
				end)
			end
		end

		-- Set the base pitch for each channel
		chords_channel.base_pitch = chords_channel.chords[1][1].pitch

		::skip_sort_for_drums::
		::skip_sort_for_empty::
	end

	--[[============================================]]--
	--[[============================================]]--

	--                  Intermission                  --
	--   I hate how big this whole algorithm already  --
	--      but i'm lazy to think smart about it	  --
	--             at least it should work			  --
	--            this is the slowest part            --

	--[[============================================]]--
	--[[============================================]]--

	-- Search for a free spot in tracks for each Note Item
	self.n_channels = 0
	for channel_index, chords_channel in pairs(self.chords_channels) do -- [1, 16]
		for _, chord in pairs(chords_channel.chords) do
			for _, note in pairs(chord) do
				-- Go through tracks and find valid position
				local track_search_index = 1
				while true do
					local found_channel_group_track = self.channel_tracks[channel_index]
					local found_notes_track = nil

					-- Create Channel's Group track if doesn't exist already
					if found_channel_group_track == nil then
						self.channel_tracks[channel_index] = {
							base_pitch = chords_channel.base_pitch,
							channel = channel_index,
							group_track = nil, 		--new_group_track,
							tracks = {}
						}

						found_channel_group_track = self.channel_tracks[channel_index]

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
								track = nil, --new_items_track,
								items = {}	 -- notes
							})

							found_notes_track = found_channel_group_track.tracks[track_search_index]
						else -- For drums
							for i = 1, drums_end_pitch - drums_start_pitch + 1 do
								found_channel_group_track.tracks[i] = {
									track = nil, --new_items_track
									items = {}	 -- notes
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
						for _, existing_note in pairs(found_notes_track.items) do
							local case_1 = note.start_pos >= existing_note.start_pos and note.start_pos < existing_note.end_pos -- If the start of our new note is inside of another note
							local case_2 = note.end_pos > existing_note.start_pos and note.end_pos <= existing_note.end_pos		-- If the end   of our new note is inside of another note
							local case_3 = existing_note.start_pos >= note.start_pos and existing_note.end_pos <= note.end_pos	-- If other note is inside our new note

							if case_1 or case_2 or case_3 then
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
	end
	return true
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

	if self.widget.CHB_disable_interactive then
		reaper.PreventUIRefresh(1)
	end

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
		if #channel_group_track.tracks == 0 then
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

	-- Sort drums folder
	if self.channel_tracks[10] then
		local selected_tracks_count = reaper.CountSelectedTracks(0)

		-- Deselect every track, this gave me so much pain regarding sorting holy shit
		for i = 1, selected_tracks_count do
			local sel_track = reaper.GetSelectedTrack(0, i-1)
			reaper.SetTrackSelected(sel_track, false)
		end

		local drum_group_index = reaper.GetMediaTrackInfo_Value(self.channel_tracks[10].group_track, "IP_TRACKNUMBER")
		for i = #self.channel_tracks[10].tracks, 1, -1 do
			local drum_track_data = self.channel_tracks[10].tracks[i]
			if drum_track_data.track then
				reaper.SetTrackSelected(drum_track_data.track, true)
				reaper.ReorderSelectedTracks(drum_group_index, 0)
				reaper.SetTrackSelected(drum_track_data.track, false)
			end
		end
	end

	-- Make folders
	local color_step = 360.0/self.n_channels
	local channel_index = 0
	for _, channel_track_data in pairs(self.channel_tracks) do
		local color

		-- If skipping sampless channels
		if self.widget.CHB_skip_empty_channels then
			if self.sources[channel_track_data.channel] == nil or self.sources[channel_track_data.channel] == "" then
				goto cntn_folders
			end
		end
		if #channel_track_data.tracks == 0 then
			goto cntn_folders
		end

		-- mark group track as a group
		reaper.SetMediaTrackInfo_Value(channel_track_data.group_track, "I_FOLDERDEPTH", 1)

		local found_last_track_in_group = nil
		if channel_track_data.channel ~= 10 then
			found_last_track_in_group = channel_track_data.tracks[1].track
		else
			for i = drums_end_pitch-drums_start_pitch + 1, 1, -1 do
				local found_drum = channel_track_data.tracks[i]
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
		reaper.SetTrackColor(channel_track_data.group_track, color)
		for _, notes_track in pairs(channel_track_data.tracks) do
			if notes_track.track then
				reaper.SetTrackColor(notes_track.track, color)
			end
		end
		channel_index = channel_index + 1
		::cntn_folders::
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Create the items
	for _, channel_group_track in pairs(self.channel_tracks) do
		if #channel_group_track.tracks == 0 then
			goto cnte_create_items
		end
		if self.widget.CHB_skip_empty_channels then
			if self.sources[channel_group_track.channel] == nil or self.sources[channel_group_track.channel] == "" then
				goto skip_sourceless
			end
		end
		for _, notes_track in pairs(channel_group_track.tracks) do
			if not notes_track.track then
				goto skip_trackless
			end

			for _, note in pairs(notes_track.items) do
				local start_pos
				local end_pos
				local new_item
				local new_item_take

				new_item	  = reaper.AddMediaItemToTrack(notes_track.track)
				new_item_take = reaper.AddTakeToMediaItem(new_item)

				--Applying params
				if channel_group_track.base_pitch ~= -1 then
					reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)
					reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", note.pitch - channel_group_track.base_pitch)
				end
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
		reaper.MB("No MIDI Item was selected on the timeline!", "Error", 0)
		return nil
	end

	if item_count > 1 then
		reaper.MB("Select only one Item!", "Error", 0)
		return nil
	end

	local midi_item	= reaper.GetSelectedMediaItem(0, 0)
	local midi_take = reaper.GetActiveTake(midi_item)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI Item.", "Error", 0)
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
					os.getenv("HOMEPATH") or "",
					"",
					self.formats_string,
					false
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
		self.widget.CHB_disable_interactive_click, self.widget.CHB_disable_interactive = ImGui.Checkbox(ctx, "Disable Interactive Generation", self.widget.CHB_disable_interactive)
		ImGui_HelpMarker(ctx, "Disabling Interactive Generation improves generation speed,\ne.g. less work for the DAW to do in order to just create the Items and Tracks.")
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


















