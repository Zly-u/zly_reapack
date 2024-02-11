--[[
-- Used at the top level in any of the Category folders
-- e.g. `Items Editing` or `MIDI`, so the scripts in those
-- folders can have appropriate categories in the ReaPack
-- Or else they will use full paths for categories,
-- like: `Item Editing/ExtendToNextItem`, which is bad.

-- You need to mark scripts that this metapackage provides as @noindex
--]]

--[[
@metapackage
@description Extend To Next Item
@author Zly
@version 1.0
@provides
	[main] .\Some\Path\To\MainScript.lua
	[nomain] .\Some\Path\To\Script.lua
@about
	# Script Name

	- Description
@changelog
	- Init
--]]