-- @noindex

function main()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then return end

	reaper.Undo_BeginBlock()
	for id = 0, item_count - 2 do
		local item		= reaper.GetSelectedMediaItem(0, id)
		local next_item	= reaper.GetSelectedMediaItem(0, id+1)

		local item_start		= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_duration		= reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local item_take 		= reaper.GetActiveTake(item)
		local item_playrate		= reaper.GetMediaItemTakeInfo_Value(item_take, "D_PLAYRATE")

		local next_item_start	= reaper.GetMediaItemInfo_Value(next_item, "D_POSITION")

		local target_duration	= next_item_start - item_start
		local target_playrate	= item_playrate * (item_duration/target_duration)

		reaper.SetMediaItemLength(item, target_duration, false)
		reaper.SetMediaItemTakeInfo_Value(item_take, "D_PLAYRATE", target_playrate)
	end
	reaper.Undo_EndBlock("Stretch To Next Item", 0)

	reaper.UpdateArrange()
end

main()