-- @noindex

function main()
end

main()

--[[
import reapy
DEBUG = False

with reapy.inside_reaper():

    curProject = reapy.Project()
    rea_items = curProject.selected_items
    items_info = []

    time_selection: reapy.TimeSelection = curProject.time_selection

    MIDI_startPos = 0
    MIDI_endPos = 0
    item_track = rea_items[0].track
    if DEBUG: reapy.print("rea_items: "+str(len(rea_items)))
    for i, item in enumerate(rea_items):
        take        = item.active_take
        pitch       = take.get_info_value("D_PITCH")
        length      = item.length
        position    = item.position
        velocity    = item.get_info_value("D_VOL")*127

        if DEBUG:
            reapy.print("Item #"+str(i))
            reapy.print("pitch: "+str(pitch))
            reapy.print("length: "+str(length))
            reapy.print("position: "+str(position)+"\n")
            reapy.print("velocity: "+str(velocity)+"\n")

        if time_selection.length == 0:
            if i == 0:
                MIDI_startPos = position
                if DEBUG: reapy.print("startPos: "+str(MIDI_startPos)+"\n")
            if i == len(rea_items)-1 or len(rea_items) == 1:
                MIDI_endPos = position+length
                if DEBUG: reapy.print("endPos: "+str(MIDI_endPos)+"\n")

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