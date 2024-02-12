-- @noindex

function main()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then
		reaper.MB("No MIDI was selected", "Error", 0)
		return
	end

	reaper.Undo_BeginBlock()

	-- Just trying to make a Track adjacent to our original track of selected items
	local midi_item	= reaper.GetSelectedMediaItem(0, 0)
	local midi_take = reaper.GetActiveTake(midi_item)

	if not reaper.TakeIsMIDI(midi_take) then
		reaper.MB("The selected Item is not a MIDI", "Error", 0)
		return
	end

	local midi_track	= reaper.GetMediaItemTrack(midi_item)
	local _, track_name = reaper.GetTrackName(midi_track)
	local track_index	= reaper.GetMediaTrackInfo_Value(midi_track, "IP_TRACKNUMBER")
	reaper.InsertTrackAtIndex(track_index - 1, true)
	local new_items_track = reaper.GetTrack(0, track_index - 1)
	reaper.GetSetMediaTrackInfo_String(new_items_track, "P_NAME", track_name..(track_name ~= "" and "_" or "").."ITEMS", true)

	local _, notes_num, _, _ = reaper.MIDI_CountEvts(midi_take)
	local first_base_pitch = 0
	for id = 0, notes_num - 1 do
		local _, _, muted, start_ppq_pos, end_ppq_pos, _, pitch, vel = reaper.MIDI_GetNote(midi_take, id)
		if muted then
			goto continue
		end

		if id == 0 then
			first_base_pitch = pitch
		end

		local new_item		= reaper.AddMediaItemToTrack(new_items_track)
		local new_item_take = reaper.AddTakeToMediaItem(new_item)

		reaper.SetMediaItemInfo_Value(new_item, "D_VOL", vel/127.0)
		reaper.SetMediaItemTakeInfo_Value(new_item_take, "D_PITCH", pitch - first_base_pitch)
		reaper.SetMediaItemTakeInfo_Value(new_item_take, "B_PPITCH", 1)

		local start_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq_pos)
		local end_pos	= reaper.MIDI_GetProjTimeFromPPQPos(midi_take, end_ppq_pos)

		reaper.SetMediaItemPosition(new_item, start_pos, false)
		reaper.SetMediaItemLength(new_item, end_pos-start_pos, false)

		::continue::
	end

	reaper.Undo_EndBlock("Items Based on MIDI", 0)
	reaper.UpdateArrange()
end

main()