-- @noindex

--[[
	TODO: Horiz Flips
	TODO: Vert Flips

	TODO: Horiz+Vert alteration flips CW
	TODO: Horiz+Vert alteration flips CCW

	TODO: Rotations CW
	TODO: Rotations CCW

	TODO: Volume to Opacity

	TODO: Template Pooled Envelopes for each Item
]]

--[==========================================]]--
--[==========================================]]--
--[==========================================]]--


local function get_script_path()
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	return filename:match("^(.*)[\\/](.-)$")
end
local function add_to_package_path(subpath)
	package.path = subpath .. "/?.lua;" .. package.path
end
add_to_package_path(get_script_path())

function UndoWrap(block_name, func)
	reaper.Undo_BeginBlock()
	func()
	reaper.Undo_EndBlock(block_name, 0)
end

--[==========================================]]--
--[==========================================]]--
--[==========================================]]--


local gui = require("VAF_GUI")
if gui.error then
	if gui.error == "NoLib" then
		return
	end
	reaper.MB("Something went wrong", "Error", 0)
	return
end


_G._print = print
_G.print = function(...)
	local string = ""
	for _, v in pairs({...}) do
		string = string .. tostring(v) .. "\t"
	end
	reaper.ShowConsoleMsg(string)
end


function TestFunction()
	local item_count = reaper.CountSelectedMediaItems()

	reaper.Undo_BeginBlock()
	for id = 0, item_count - 1 do
		local item = reaper.GetSelectedMediaItem(0, id)
		if not item then
			goto TestFunction_continue
		end

		local track = reaper.GetMediaItem_Track(item)
		--local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		--print("Item: ", len)
		reaper.DeleteTrackMediaItem(track, item)

		::TestFunction_continue::
	end
	reaper.Undo_EndBlock("DEKETUIB", 0)
	reaper.UpdateArrange()
end


function main()
	--reaper.ShowConsoleMsg("Test")
	--gui:StartGUI()
	UndoWrap("Test", TestFunction)
end


main()