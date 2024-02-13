-- @noindex

local function get_script_path()
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	return filename:match("^(.*)[\\/](.-)$")
end
local function add_to_package_path(subpath)
	package.path = subpath .. "/?.lua;" .. package.path
end
add_to_package_path(get_script_path())

--[[===================================================]]--

local ImGui = {}
for name, func in pairs(reaper) do
	name = name:match('^ImGui_(.+)$')
	if name then ImGui[name] = func end
end
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

local JS = {}
for name, func in pairs(reaper) do
	name = name:match('^JS_(.+)$')
	if name then JS[name] = func end
end
--[[===================================================]]--

_G._print = print
_G.print = function(...)
	local string = ""
	for _, v in pairs({...}) do
		string = string .. tostring(v) .. "\t"
	end
	string = string.."\n"
	reaper.ShowConsoleMsg(string)
end

--[[===================================================]]--

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


--[[===================================================]]--

local async = require("async")
local demo = require("demo")

local M2I = {
	widget = {
		CHB_inherit_vol_click	= false,
		CHB_inherit_vol			= false,
		-------------------------------------
		midi_notes_num					= 0,
		midi_notes_read					= 0,
		midi_notes_channel_destribute	= 0,

		midi_progress_string = "%d/%d",

		midi_load_progress = 0.0,
		-------------------------------------
		items_progress		= 0.0,
		generated_notes		= 0,
	},
	sources = {}
}

local version = "2.0"
local chords = {}
local channel_tracks = {}
local n_channels = 0
local track_index = -1

-- TODO: UI
--  	TODO: General info about selected MIDI
--		TODO: Load data button
--			TODO: Load progress
--  	TODO: Ability to pick source per channel
--		TODO: Generation Progress

local function hsl2rgb(H, S, L)
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
	outColor		= outColor | 0x1000000
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
		channel		= _chan+1,
		pitch		= _pitch,
		vel			= _vel
	}
end

local function ProcessMIDI(midi_item, midi_take)
	reaper.ClearConsole()

	reaper.MIDI_Sort(midi_take)
	local _, notes_num, _, _ = reaper.MIDI_CountEvts(midi_take)
	M2I.widget.midi_notes_num = notes_num

	local midi_track	= reaper.GetMediaItemTrack(midi_item)
	track_index			= reaper.GetMediaTrackInfo_Value(midi_track, "IP_TRACKNUMBER")

	--[[============================================]]--
	--[[============================================]]--

	-- Detecting overlapping notes
	local max_concurrent_notes = 1
	local current_chord		= {}
	for id = 0, notes_num - 1 do
		local current_note = GetNoteData(midi_take, id)

		-- Go through all notes in the chord set (if not empty)
		local chord_note_index = 1
		local found_overlap = false
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
			table.insert(chords, current_chord)
			current_chord = {}
		end

		if #current_chord == 0 then
			table.insert(current_chord, current_note)
		end
		M2I.widget.midi_notes_read = M2I.widget.midi_notes_read + 1
	end

	-- Insert the last set.
	table.insert(chords, current_chord)

	--[[============================================]]--
	--[[============================================]]--

	                 -- Intermission --
	--   I hate how big this whole algorithm already  --
	--      but i'm lazy to think smart about it	  --
	--             at least it should work			  --
	--            this is the slowest part            --

	--[[============================================]]--
	--[[============================================]]--

	n_channels = 0
	for _, chord in pairs(chords) do
		for _, note in pairs(chord) do
			-- Go through tracks and find valid position
			local track_search_index = 1
			while true do
				local found_channel_track = channel_tracks[note.channel]

				-- Create group track for a channel if doesn't exist already
				if found_channel_track == nil then
					channel_tracks[note.channel] = {
						channel = note.channel,
						group_track = nil, --new_group_track,
						tracks = {}
					}

					found_channel_track = channel_tracks[note.channel]

					n_channels = n_channels + 1
				end

				local found_notes_track = found_channel_track.tracks[track_search_index]

				-- If next track to check for valid positions
				-- doesn't exist then we make it
				if found_notes_track == nil then
					table.insert(
						found_channel_track.tracks,{
							parent = found_channel_track,
							track  = nil, --new_items_track,
							items  = {} -- notes
						}
					)
					found_notes_track = found_channel_track.tracks[track_search_index]

					-- can append note right away
					table.insert(found_notes_track.items, note)
					break
				end

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
				-- else: continue the search for a free spot

				track_search_index = track_search_index + 1
			end
			M2I.widget.midi_notes_channel_destribute = M2I.widget.midi_notes_channel_destribute + 1
		end
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Sort table
	table.sort(channel_tracks, function(channelA, channelB)
		print(channelA, channelB)
		if not channelB or not channelA then
			return false
		end
		return channelA.channel < channelB.channel
	end)
end

local function Generate(midi_take)
	reaper.Undo_BeginBlock()

	for _, channel_track in pairs(channel_tracks) do
		-- Channel Group Track
		reaper.InsertTrackAtIndex(track_index - 1, true)
		local new_group_track = reaper.GetTrack(0, track_index - 1)
		reaper.GetSetMediaTrackInfo_String(new_group_track, "P_NAME", "CHANNEL_"..tostring(channel_track.channel), true)
		channel_track.group_track = new_group_track

		track_index = track_index + 1

		-- Channel Track for Notes
		for _, channel_note_track in pairs(channel_track.tracks) do
			local channel_track_index = reaper.GetMediaTrackInfo_Value(channel_track.group_track, "IP_TRACKNUMBER")
			reaper.InsertTrackAtIndex(channel_track_index, true)
			local new_items_track = reaper.GetTrack(0, channel_track_index)
			reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", "Ch_"..tostring(channel_track.channel).." - ITEMS", true)

			channel_note_track.track = new_items_track

			track_index = track_index + 1
		end
	end

	--[[============================================]]--

	-- Make folders
	local color_step = 360.0/n_channels
	for index, ch_track in pairs(channel_tracks) do
		reaper.SetMediaTrackInfo_Value(ch_track.group_track,		"I_FOLDERDEPTH", 1)
		reaper.SetMediaTrackInfo_Value(ch_track.tracks[1].track,	"I_FOLDERDEPTH", -1)

		-- Coloring
		local color = hsl2rgb(color_step * (index-1), 1, 0.8)
		reaper.SetTrackColor(ch_track.group_track, color)
		for _, ch_child in pairs(ch_track.tracks) do
			reaper.SetTrackColor(ch_child.track, color)
		end
	end

	-- Reorder Folders according to the sorted table
	for _, channel in pairs(channel_tracks) do
		reaper.SetTrackSelected(channel.group_track, true)
		reaper.ReorderSelectedTracks(track_index-1, 0)
		reaper.SetTrackSelected(channel.group_track, false)
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Detect the lowest pitch in the first potential chord
	local first_base_pitch = 127
	if #chords[1] > 1 then
		for _, note in pairs(chords[1]) do
			if note.pitch < first_base_pitch then
				first_base_pitch = note.pitch
			end
		end
	else
		first_base_pitch = chords[1][1].pitch
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Create the items
	for _, ch_track in pairs(channel_tracks) do
		for _, track in pairs(ch_track.tracks) do
			for _, note in pairs(track.items) do
				local new_item		= reaper.AddMediaItemToTrack(track.track)
				local new_item_take = reaper.AddTakeToMediaItem(new_item)


				reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)
				reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", note.pitch - first_base_pitch)
				if M2I.widget.CHB_inherit_vol then
					reaper.SetMediaItemInfo_Value(new_item, "D_VOL", note.vel/127.0)
				end

				local note_channel = M2I.sources[note.channel]
				if note_channel ~= nil then
					local source_file = reaper.PCM_Source_CreateFromFile(note_channel)
					reaper.SetMediaItemTake_Source(new_item_take, source_file)
				end

				local start_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.start_pos)
				local end_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.end_pos)

				reaper.SetMediaItemPosition(new_item, start_pos, false)
				reaper.SetMediaItemLength(new_item, end_pos-start_pos, false)

				M2I.widget.generated_notes = M2I.widget.generated_notes + 1
			end
		end
	end

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()
end


local function ProcessSelectedMIDI()
	local midi_count = reaper.CountSelectedMediaItems(0)
	if item_count == 0 then
		reaper.MB("No MIDI was selected", "Error", 0)
		return
	end

	for i = 0, midi_count - 1 do
		local midi_item	= reaper.GetSelectedMediaItem(0, i)
		local midi_take = reaper.GetActiveTake(midi_item)
		ProcessMIDI(midi_take)
	end
end


local function LoadSelectedMIDI()
	chords			= {}
	channel_tracks	= {}

	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then
		reaper.MB("No MIDI was selected", "Error", 0)
		return
	end

	local midi_item	= reaper.GetSelectedMediaItem(0, 0)
	local midi_take = reaper.GetActiveTake(midi_item)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI", "Error", 0)
		return
	end

	ProcessMIDI(midi_item, midi_take)

	return midi_take
end


--[[==================================================]]--
--[[==================================================]]--
--[[==================================================]]--


local processed_midi_take = nil

local function UpdateParams()
	M2I.widget.midi_load_progress 	=
		M2I.widget.midi_notes_num == 0
		and 0
		or (M2I.widget.midi_notes_read + M2I.widget.midi_notes_channel_destribute) / (M2I.widget.midi_notes_num * 2)

	M2I.widget.midi_progress_string =
		M2I.widget.midi_notes_num == 0
		and "%0 : 0/0"
		or ("%%%d : %d/%d"):format(
				M2I.widget.midi_load_progress * 100,
				math.floor(M2I.widget.midi_notes_read+M2I.widget.midi_notes_channel_destribute)/2,
				M2I.widget.midi_notes_num
		)

	M2I.widget.items_progress = M2I.widget.generated_notes / M2I.widget.midi_notes_num
end

local tables = {
	resz_mixed = {
		flags = ImGui.TableFlags_SizingFixedFit() |
				ImGui.TableFlags_RowBg() |
				ImGui.TableFlags_Borders() |
				--ImGui.TableFlags_Resizable() |
				--ImGui.TableFlags_Reorderable() |
				ImGui.TableFlags_Hideable()
	}
}

local allowed_formats = {
	{"MP4 Files (.mp4)",	"*.mp4"},
	{"WEBM Files (.webm)",	"*.webm"},

	{"MP3 Files (.mp3)",	"*.mp3"},
	{"WAV Files (.wav)",	"*.wav"},

	{"All Files", "*.*"},
}

--"ReaScript files\0*.lua;*.eel\0Lua files (.lua)\0*.lua\0EEL files (.eel)\0*.eel\0\0".
local formats_string = ""
for _, format in pairs(allowed_formats) do
	formats_string = formats_string..format[1]..'\0'..format[2]..'\0'
end

local table_content = {
	-- Channel used?
	function(_ctx, index, channel_data)
		local text  = (channel_data == nil) and "x" or "*"
		local color = (channel_data == nil) and 0x888888FF or 0xFFFFFFFF
		ImGui.TextColored(_ctx, color, text)
	end,

	-- Channel
	function(_ctx, index, channel_data)
		local color = (channel_data == nil) and 0x888888FF or 0xFFFFFFFF
		ImGui.TextColored(_ctx, color, index)
	end,

	-- Source
	function(_ctx, index, channel_data)
		local text	= (M2I.sources[index] ~= "") and M2I.sources[index] or "Select source for this channel"
		local color = 0x888888FF
		if M2I.sources[index] ~= nil and M2I.sources[index] ~= "" then
			text = text:match("[^\\]*$")
			color = 0xFFFFFFFF
		end
		ImGui.TextColored(_ctx, color, text)
	end,

	-- Set Button
	function(_ctx, index, channel_data)
		ImGui.PushID(_ctx, index)
		--if ImGui.Button(_ctx, "Set") then
		if ImGui.SmallButton(_ctx, "Set") then
			--integer retval, string fileNames = reaper.JS_Dialog_BrowseForOpenFiles(string windowTitle, string initialFolder, string initialFile, string extensionList, boolean allowMultiple)
			local retval, fileNames = JS.Dialog_BrowseForOpenFiles("Source to use for Media Items", os.getenv("HOMEPATH") or "", "", formats_string, false)
			if retval and fileNames ~= "" then
				M2I.sources[index] = fileNames
			end
		end
		ImGui.PopID(_ctx)
	end
}

local function UI(ctx)
	ImGui.Text(ctx, "Select a MIDI item and press \"Load MIDI\".")

	--boolean retval, string buf = reaper.ImGui_InputTextWithHint(
	--			ImGui_Context ctx, string label, string hint, string buf,
	--			number flags = InputTextFlags_None, ImGui_Function callback = nil)
	--ImGui.InputTextWithHint(ctx, 'input text (w/ hint)', 'enter text here', widgets.basic.str1)

	ImGui.SeparatorText(ctx, "Properties")

	M2I.widget.CHB_inherit_vol_click, M2I.widget.CHB_inherit_vol =
		ImGui.Checkbox(ctx, "Inherit Volume", M2I.widget.CHB_inherit_vol)

	ImGui.SeparatorText(ctx, "MIDI")

	--[[==================================]]--
	--[[============ MIDI LOAD ===========]]--
	--[[==================================]]--

	if ImGui.Button(ctx, "Load MIDI") then
		M2I.widget.midi_notes_num = 0
		M2I.widget.midi_load_progress = 0
		M2I.widget.midi_notes_read = 0
		M2I.widget.midi_notes_channel_destribute = 0

		M2I.widget.items_progress = 0

		-- stupid way of return by reference
		processed_midi_take = nil
		processed_midi_take = LoadSelectedMIDI()
	end

	ImGui.SameLine(ctx)

	--	void ImGui.ProgressBar(ImGui_Context ctx, number fraction, number size_arg_w = -FLT_MIN, number size_arg_h = 0.0, string overlay = nil)
	--ImGui.ProgressBar(ctx, M2I.widget.midi_load_progress, -FLT_MIN, 0, M2I.widget.midi_progress_string)
	ImGui.ProgressBar(ctx, M2I.widget.midi_load_progress)

	if ImGui.BeginTable(ctx, "table", 4, tables.resz_mixed.flags) then
		--(ctx, label, flagsIn, init_width_or_weightIn, integer user_idIn)
		ImGui.TableSetupColumn(ctx, "Used?",	ImGui.TableColumnFlags_WidthFixed())
		ImGui.TableSetupColumn(ctx, "Channel",	ImGui.TableColumnFlags_WidthFixed())
		ImGui.TableSetupColumn(ctx, "Source",	ImGui.TableColumnFlags_NoResize(), 210)
		ImGui.TableSetupColumn(ctx, "",			ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_NoResize())
		ImGui.TableHeadersRow(ctx)
		for row = 1, 16 do
			ImGui.TableNextRow(ctx)
			for column = 0, 3 do
				ImGui.TableSetColumnIndex(ctx, column)
				table_content[column+1](ctx, row, channel_tracks[row])
			end
		end
		ImGui.EndTable(ctx)
	end

	--[[=================================]]--
	--[[============= BUTTONS ===========]]--
	--[[=================================]]--

	ImGui.SeparatorText(ctx, "")

	ImGui.ProgressBar(ctx, M2I.widget.items_progress)

	if ImGui.Button(ctx, "Generate") then
		if processed_midi_take then
			Generate(processed_midi_take)
		end
	end

	ImGui.SameLine(ctx)

	ImGui.SameLine(ctx)
	if ImGui.Button(ctx, "Generate Blank") then
	end
end


--[[=========================================]]--
--[[=========================================]]--
--[[=========================================]]--


local function Init()

end

local function SetupUI()
	local ctx = ImGui.CreateContext("MIDI -> Items")

	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsResizeFromEdges(), 1)
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsResizeFromEdges(), 1)
	local window_flags =
		--ImGui.WindowFlags_None() |
		ImGui.WindowFlags_NoDocking() |
		ImGui.WindowFlags_NoResize() |
		ImGui.WindowFlags_NoCollapse() |
		ImGui.WindowFlags_NoSavedSettings()
	local function LoopUI()
		local visible, open = reaper.ImGui_Begin(ctx, "MIDI -> Items "..version, true, window_flags)
		if visible then
			UpdateParams()
			UI(ctx)
			ImGui.End(ctx)
		end

		-- Continue looping itself
		if open then
			reaper.defer(LoopUI)
		end
	end

	reaper.defer(LoopUI)
end


--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--


function main()
	Init()
	SetupUI()
end

main()


--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

-- DEMO --

local ctx = reaper.ImGui_CreateContext("DEMO")
local function loop()
	demo.PushStyle(ctx)
	demo.ShowDemoWindow(ctx)
	if reaper.ImGui_Begin(ctx, "Dear ImGui Style Editor") then
		demo.ShowStyleEditor(ctx)
		reaper.ImGui_End(ctx)
	end
	demo.PopStyle(ctx)
	reaper.defer(loop)
end
reaper.defer(loop)

















