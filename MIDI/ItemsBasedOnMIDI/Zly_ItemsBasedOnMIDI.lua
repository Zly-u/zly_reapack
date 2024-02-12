-- @noindex

local chords = {}
local tracks = {}

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
	local _, notes_num, _, _ = reaper.MIDI_CountEvts(midi_take)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI", "Error", 0)
		return
	end

	local midi_track	= reaper.GetMediaItemTrack(midi_item)
	local _, track_name = reaper.GetTrackName(midi_track)
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

	--[[============================================]]--
	--[[============================================]]--

	for _, chord in pairs(chords) do
		for _, note in pairs(chord) do
			-- Go through tracks and find valid position
			local track_search_index = 1
			while true do
				local found_track = tracks[track_search_index]

				-- If next track to check for valid positions
				-- doesn't exist then we make it
				if found_track == nil then
					reaper.InsertTrackAtIndex(track_index - 1, true)
					local new_items_track = reaper.GetTrack(0, track_index - 1)
					reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", track_name..(track_name ~= "" and "_" or "").."ITEMs", true)

					table.insert(
						tracks, {
							track = new_items_track,
							items = {} -- notes
						}
					)
					found_track = tracks[track_search_index]

					-- can append note right away
					table.insert(found_track.items, note)
					break
				end

				-- Check if it overlaps with anything
				-- it better damn not be >:C
				local isOverlaping = false
				for _, item in pairs(found_track.items) do
					local isAtStart = note.start_pos >= item.start_pos
					local isBeforeEnd = note.start_pos < item.end_pos
					if isAtStart and isBeforeEnd then
						isOverlaping = true
						break
					end
				end

				if not isOverlaping then
					table.insert(found_track.items, note)
					break
				end
				-- else: continue the search for a free spot

				track_search_index = track_search_index + 1
			end
		end
	end

	-- Create the items
	for _, track in pairs(tracks) do
		local first_base_pitch = 0
		for note_index, note in pairs(track.items) do
			if note_index == 1 then
				first_base_pitch = note.pitch
			end

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

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()
end

main()