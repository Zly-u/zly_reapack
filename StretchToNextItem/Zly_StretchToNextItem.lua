--[[
@description Stretch To Next Item
@author Zly
@version 1.0
@provides
   [main] .
@about
   # Stretch To Next Item
   
   - Stretches selected Items to next adjacent item.
--]]

function main()
end

main()

--[[
import reapy

with reapy.inside_reaper():
    cur_project = reapy.Project()
    selected_items = cur_project.selected_items

    for item in selected_items:
        pos = item.position
        item_tracks_items = item.track.items

        next_item = None
        for i, searchable_item in enumerate(item_tracks_items):
            if searchable_item == item and i != len(item_tracks_items)-1:
                next_item = item_tracks_items[i+1]

        if next_item: item.set_info_value("D_LENGTH", abs(pos - next_item.position))

--]]