-- @noindex

function main()
	local item_count = reaper.CountSelectedMediaItems()
	if item_count == 0 then return end

	reaper.Undo_BeginBlock()
	for id = 0, item_count - 2 do
		local item		= reaper.GetSelectedMediaItem(0, id)
		local next_item	= reaper.GetSelectedMediaItem(0, id+1)

		local item_start		= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local next_item_start	= reaper.GetMediaItemInfo_Value(next_item, "D_POSITION")
		local target_length		= next_item_start - item_start

		reaper.SetMediaItemLength(item, target_length, false)
	end
	reaper.Undo_EndBlock("Extend To Next Item", 0)

	reaper.UpdateArrange()
end

main()