-- @noindex

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
			print(indenty .. "*" .. (show_details and tostring(_t) or ""))
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
				sub_printTable(val, indenty, indenty..indent)
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
		sub_printTable(t, "  ")
		print("}")
	else
		sub_printTable(t, "  ")
	end
end


local notes = {
	--[[
	[1] = {1, 2, 3, 4},
	[2] = {5},
	[3] = {6, 7, {8, 9}, 10},
	--]]
}

local items = {

}

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

	-- TODO: Detecting overlapping notes
	local max_concurrent_notes = 1
	local current_chord		= {}
	for id = 0, notes_num - 1 do
		local current_note = GetNoteData(midi_take, id)

		-- Go through all notes in the chord set
		local chord_note_index = 1
		while chord_note_index <= #current_chord do
			local chord_note = current_chord[chord_note_index]

			if current_note.id ~= chord_note.id then
				local isNote_after_start = current_note.start_pos >= chord_note.start_pos
				local isNote_before_end  = current_note.start_pos <  chord_note.end_pos

				-- If the note not overlaps - make a new chord set
				if not (isNote_after_start and isNote_before_end) then
					if #current_chord > max_concurrent_notes then
						max_concurrent_notes = #current_chord
					end

					table.insert(notes, current_chord)
					current_chord = {}
					break
				end
				table.insert(current_chord, current_note)
			end

			chord_note_index = chord_note_index + 1
		end

		if #current_chord == 0 then
			table.insert(current_chord, current_note)
		end
	end

	table.insert(notes, current_chord)

	printTable(notes)


	-- TODO: New Tracks
	--reaper.InsertTrackAtIndex(track_index - 1, true)
	--local new_items_track = reaper.GetTrack(0, track_index - 1)
	--reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", track_name..(track_name ~= "" and "_" or "").."ITEMS", true)

	-- TODO: Adapt
	--local first_base_pitch = 0
	--for id = 0, notes_num - 1 do
	--	local _, _, muted, start_ppq_pos, end_ppq_pos, _, pitch, vel = reaper.MIDI_GetNote(midi_take, id)
	--	if muted then
	--		goto continue
	--	end
	--
	--	if id == 0 then
	--		first_base_pitch = pitch
	--	end
	--
	--	local new_item		= reaper.AddMediaItemToTrack(new_items_track)
	--	local new_item_take = reaper.AddTakeToMediaItem(new_item)
	--
	--	reaper.SetMediaItemInfo_Value(new_item, "D_VOL", vel/127.0)
	--	reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", pitch - first_base_pitch)
	--	reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)
	--
	--	local start_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq_pos)
	--	local end_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, end_ppq_pos)
	--
	--	reaper.SetMediaItemPosition(new_item, start_pos, false)
	--	reaper.SetMediaItemLength(new_item, end_pos-start_pos, false)
	--
	--	::continue::
	--end

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()
end

main()