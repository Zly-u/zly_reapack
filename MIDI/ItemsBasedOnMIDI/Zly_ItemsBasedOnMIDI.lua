-- @noindex

local chords = {}

local channel_tracks = {}

-- TODO: UI
--		TODO: Generation Progress
--  	TODO: General info about selected MIDI

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
		channel		= _chan,
		pitch		= _pitch,
		vel			= _vel
	}
end

function main()
	reaper.ClearConsole()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then
		reaper.MB("No MIDI was selected", "Error", 0)
		return
	end

	reaper.Undo_BeginBlock()

	-- Just trying to make a Track adjacent to our original track of selected items
	local midi_item	= reaper.GetSelectedMediaItem(0, 0)
	local midi_take = reaper.GetActiveTake(midi_item)
	reaper.MIDI_Sort(midi_take)

	local _, notes_num, _, _ = reaper.MIDI_CountEvts(midi_take)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI", "Error", 0)
		return
	end

	local midi_track	= reaper.GetMediaItemTrack(midi_item)
	local track_index	= reaper.GetMediaTrackInfo_Value(midi_track, "IP_TRACKNUMBER")

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


	for _, chord in pairs(chords) do
		for _, note in pairs(chord) do
			-- Go through tracks and find valid position
			local track_search_index = 1
			while true do
				local found_channel_track = channel_tracks[note.channel]

				-- Create group track for a channel if doesn't exist already
				if found_channel_track == nil then
					reaper.InsertTrackAtIndex(track_index - 1, true)
					local new_group_track = reaper.GetTrack(0, track_index - 1)
					reaper.GetSetMediaTrackInfo_String(new_group_track, "P_NAME", "CHANNEL_"..tostring(note.channel), true)
					reaper.SetMediaTrackInfo_Value(new_group_track, "I_FOLDERDEPTH", 0)

					channel_tracks[note.channel] = {
						channel = note.channel,
						group_track = new_group_track,
						tracks = {}
					}

					found_channel_track = channel_tracks[note.channel]

					track_index = track_index + 1
				end

				local found_notes_track = found_channel_track.tracks[track_search_index]

				-- If next track to check for valid positions
				-- doesn't exist then we make it
				if found_notes_track == nil then
					local channel_track_index = reaper.GetMediaTrackInfo_Value(found_channel_track.group_track, "IP_TRACKNUMBER")
					reaper.InsertTrackAtIndex(channel_track_index, true)
					local new_items_track = reaper.GetTrack(0, channel_track_index)
					reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", "Ch_"..tostring(note.channel).." - ITEMS", true)
					--reaper.SetMediaTrackInfo_Value(new_items_track, "I_FOLDERDEPTH", -1)
					reaper.SetMediaTrackInfo_Value(new_items_track, "I_FOLDERDEPTH", 0)

					table.insert(
						found_channel_track.tracks,{
							parent = found_channel_track,
							track  = new_items_track,
							items  = {} -- notes
						}
					)
					found_notes_track = found_channel_track.tracks[track_search_index]

					-- can append note right away
					table.insert(found_notes_track.items, note)

					track_index = track_index + 1
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
		end
	end

	--[[============================================]]--
	--[[============================================]]--

	-- Sort table
	table.sort(channel_tracks, function(channelA, channelB)
		return channelA.channel < channelB.channel
	end)

	--[[============================================]]--
	--[[============================================]]--

	-- Make folders
	local color_step = 360.0/#channel_tracks
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

				reaper.SetMediaItemInfo_Value(new_item, "D_VOL", note.vel/127.0)
				reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", note.pitch - first_base_pitch)
				reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)

				local start_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.start_pos)
				local end_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, note.end_pos)

				reaper.SetMediaItemPosition(new_item, start_pos, false)
				reaper.SetMediaItemLength(new_item, end_pos-start_pos, false)
			end
		end
	end

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()
end

main()