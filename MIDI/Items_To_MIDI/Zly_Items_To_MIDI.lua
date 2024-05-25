-- @noindex

function main()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then return end

	reaper.Undo_BeginBlock()

	-- Just trying to make a Track adjacent to our original track of selected items
	local first_item	= reaper.GetSelectedMediaItem(0, 0)
	local track			= reaper.GetMediaItemTrack(first_item)
	local _, track_name = reaper.GetTrackName(track)
	local track_index	= reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
	reaper.InsertTrackAtIndex(track_index, true)
	local new_midi_track = reaper.GetTrack(0, track_index)
	reaper.GetSetMediaTrackInfo_String(new_midi_track, "P_NAME", track_name..(track_name ~= "" and "_" or "").."MIDI", true)

	-- Create MIDI item
	local first_item_start		= reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
	local last_item				= reaper.GetSelectedMediaItem(0, item_count - 1)
	local last_item_start		= reaper.GetMediaItemInfo_Value(last_item, "D_POSITION")
	local last_item_duration	= reaper.GetMediaItemInfo_Value(last_item, "D_LENGTH")

	local MIDI_startPos	= first_item_start
	local MIDI_endPos	= last_item_start+last_item_duration
	local midi_item		= reaper.CreateNewMIDIItemInProj(new_midi_track, MIDI_startPos, MIDI_endPos, false)
	local midi_take		= reaper.GetActiveTake(midi_item)


	for id = 0, item_count - 1 do
		local item			= reaper.GetSelectedMediaItem(0, id)
		local item_start	= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_duration	= reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

		local take			= reaper.GetActiveTake(item)
		local take_pitch	= reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")+63
		local take_volume	= reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")*127 or 0
		take_pitch = math.min(math.max(take_pitch, 0), 127)
		
		reaper.MIDI_InsertNote(
			midi_take, false, false, 												-- MediaItem_Take take, boolean selected, boolean muted,
			reaper.MIDI_GetPPQPosFromProjTime(midi_take, item_start),				-- number startppqpos,
			reaper.MIDI_GetPPQPosFromProjTime(midi_take, item_start+item_duration),	-- number endppqpos,
			0, math.floor(take_pitch), math.floor(take_volume),												-- integer chan, integer pitch, integer vel
			false																	-- optional boolean noSortIn
		)

	end
	reaper.MIDI_Sort(midi_take)

	reaper.Undo_EndBlock("MIDI Based on Items", 0)
	reaper.UpdateArrange()
end

main()