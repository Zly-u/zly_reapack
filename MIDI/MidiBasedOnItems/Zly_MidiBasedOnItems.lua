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


--[[
def _resolve_midi_unit(self, pos_tuple, unit="seconds"):
        if unit == "ppq":
            return pos_tuple
        item_start_seconds = self.item.position

        def resolver(pos):
            if unit == "beats":
                take_start_beat = self.track.project.time_to_beats(
                    item_start_seconds
                )
                return self.beat_to_ppq(take_start_beat + pos)

            if unit == "seconds":
                return self.time_to_ppq(item_start_seconds + pos)

            raise ValueError('unit param should be one of seconds|beats|ppq')
        return [resolver(pos) for pos in pos_tuple]
]]--


function main()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then return end

	reaper.Undo_BeginBlock()

	-- Just trying to make a Track adjacent to our original track of selected items
	local first_item	= reaper.GetSelectedMediaItem(0, 0)
	local track			= reaper.GetMediaItemTrack(first_item)
	local _, track_name = reaper.GetTrackName(track)
	local track_index	= reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
	reaper.InsertTrackAtIndex(track_index-1, true)
	local new_midi_track = reaper.GetTrack(0, track_index-1)
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
		local take_volume	= reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")*127
		take_pitch = math.min(math.max(take_pitch, 0), 127)

		reaper.MIDI_InsertNote(
			midi_take, false, false, 												-- MediaItem_Take take, boolean selected, boolean muted,
			reaper.MIDI_GetPPQPosFromProjTime(midi_take, item_start),				-- number startppqpos,
			reaper.MIDI_GetPPQPosFromProjTime(midi_take, item_start+item_duration),	-- number endppqpos,
			0, take_pitch, take_volume,												-- integer chan, integer pitch, integer vel
			false																	-- optional boolean noSortIn
		)

	end
	reaper.MIDI_Sort(midi_take)

	reaper.Undo_EndBlock("MIDI Based on Items", 0)
	reaper.UpdateArrange()
end

main()

--[[
import reapy

with reapy.inside_reaper():

    curProject = reapy.Project()
    rea_items = curProject.selected_items
    items_info = []

    time_selection: reapy.TimeSelection = curProject.time_selection

    MIDI_startPos = 0
    MIDI_endPos = 0
    item_track = rea_items[0].track
    for i, item in enumerate(rea_items):
        take        = item.active_take
        pitch       = take.get_info_value("D_PITCH")
        length      = item.length
        position    = item.position
        velocity    = item.get_info_value("D_VOL")*127

        if time_selection.length == 0:
            if i == 0:
                MIDI_startPos = position
            if i == len(rea_items)-1 or len(rea_items) == 1:
                MIDI_endPos = position+length

        items_info.append([position, length, pitch, velocity])

    if time_selection.length != 0:
        MIDI_startPos   = time_selection.start
        MIDI_endPos     = time_selection.end

    midi_track = curProject.add_track(name=item_track.name + "_MIDI", index=item_track.index + 1)
    midi: reapy.Item = midi_track.add_midi_item(start=MIDI_startPos, end=MIDI_endPos, quantize=False)
    midi_take   = midi.active_take

    for item_info in items_info:
        position    = item_info[0]
        length      = item_info[1]
        pitch       = 63+int(item_info[2])
        velocity    = max(min(int(item_info[3]), 127), 1)

        midi_take.add_note(
            position-MIDI_startPos,
            position+length-MIDI_startPos,
            pitch,
            velocity=velocity, channel=0, selected=False, muted=False, unit="seconds", sort=False
        )

    midi_take.sort_events()
--]]