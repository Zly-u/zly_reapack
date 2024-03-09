-- Made by Zly
--	https://github.com/Zly-u
--  https://twitter.com/zly_u

-- @noindex

do	-- Allows to require scripts relatively to this current script's path.
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	package.path = filename:match("^(.*)[\\/](.-)$") .. "/?.lua;" .. package.path
end

--[[===================================================]]--
--[[============== TEMP CODE FOR DEBUG ================]]--
--[[vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv]]--

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
			print(indenty .. "Already used: " .. tostring(_t))
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
				sub_printTable(val, indent, indenty..indent)
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
		sub_printTable(t, "\t")
		print("}")
	else
		sub_printTable(t, "\t")
	end
end

--[[===================================================]]--

do
	local demo = require("ImGui_demo")
	local demo_ctx = reaper.ImGui_CreateContext("Demo")
	local function loop()
		demo.PushStyle(demo_ctx)
		demo.ShowDemoWindow(demo_ctx)
		if reaper.ImGui_Begin(demo_ctx, "Dear ImGui Style Editor") then
			demo.ShowStyleEditor(demo_ctx)
			reaper.ImGui_End(demo_ctx)
		end
		demo.PopStyle(demo_ctx)
		reaper.defer(loop)
	end
	reaper.defer(loop)
end

--[[===================================================]]--
--[[=================== HELPERS =======================]]--
--[[===================================================]]--

local function URL_Openner(URL)
	local OS = ({
		Win32 = "start",
		Win64 = "start",
		OSX32 = "open",
		OSX64 = "open",
		["macOS-arm64"] = "open",

		Other = "start",
	})[reaper.GetOS()]

	os.execute(OS .. " " .. URL)
end

local function MultLineStringConstructor(...)
	local strings_array = {...}
	local compiled_string = ""
	for index, line in pairs(strings_array) do
		compiled_string =
		compiled_string
				..line
				..(index ~= #strings_array and "\n" or "")
	end
	return compiled_string
end

local DepsChecker = {
	libs_to_check = {},
	builded_reapack_deps_list = "",
	builded_reapack_search_filter = "",
	-----------------------------------------------------
	AddDepsToCheck = function(self, _func, _filter)
		table.insert(self.libs_to_check, {
			func	= _func,
			filter	= _filter
		})
	end,
	CheckLibs = function(self)
		for index, lib in pairs(self.libs_to_check) do
			if not lib.func then
				self.builded_reapack_deps_list =
				self.builded_reapack_deps_list
						..'\t'..lib.filter
						..(index ~= #self.libs_to_check and '\n' or "")

				self.builded_reapack_search_filter =
				self.builded_reapack_search_filter
						..lib.filter
						..(index ~= #self.libs_to_check and " OR " or "")
			end
		end

		-- if empty then it's all good
		if self.builded_reapack_search_filter == "" then
			return true
		end

		-- I didn't wanted to write in [[str]] for a multiline string cuz it sucks to read in code
		-- and I didn't wanted to make one long ass single line string with '\n' at random places
		-- this way i can see the dimensions of the text for a proper formating
		local error_msg = MultLineStringConstructor(
				"Please install next Packages through ReaPack",
				"In Order for the script to work:\n",
				self.builded_reapack_deps_list,
				"\nAfter closing this window ReaPack's Package Browser",
				"will open with the dependencies you need!"
		)

		reaper.MB(error_msg, "Error", 0)

		if not reaper.ReaPack_BrowsePackages then
			local reapack_error = MultLineStringConstructor(
					"Someone told me you don't have ReaPack to get the deps from...",
					"After closing this window I will open the Official ReaPack website",
					"\"https://reapack.com/\" for you to download it from :)"
			)
			reaper.MB(reapack_error, "What the hell...", 0)
			URL_Openner("https://reapack.com/")
			return false
		end

		reaper.ReaPack_BrowsePackages(self.builded_reapack_search_filter)

		return false
	end,

	CheckIfIsAllInstalled = function(self)
		return self.is_all_good
	end
}

DepsChecker:AddDepsToCheck(reaper.JS_Dialog_BrowseForOpenFiles, "js_ReaScriptAPI")
DepsChecker:AddDepsToCheck(reaper.ImGui_Begin, "\"ReaImGui: ReaScript binding for Dear ImGui\"")
if not DepsChecker:CheckLibs() then
	return
end

--[[===================================================]]--

local ImGui = {}
local JS = {}
for name, func in pairs(reaper) do
	local name_imgui = name:match('^ImGui_(.+)$')
	local name_js	 = name:match('^JS_(.+)$')

	if name_imgui then
		ImGui[name_imgui] = func
		goto namespace_cont
	end

	if name_js then
		JS[name_js] = func
		goto namespace_cont
	end

	::namespace_cont::
end
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

--[[===================================================]]--

local function ImGui_InfoMarker(ctx, desc)
	ImGui.SameLine(ctx)
	ImGui.TextDisabled(ctx, "(?)")

	if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort()) then
		return
	end

	if ImGui.BeginTooltip(ctx) then
		ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
		ImGui.Text(ctx, desc)
		ImGui.PopTextWrapPos(ctx)
		ImGui.EndTooltip(ctx)
	end
end

local function ImGui_Link(ctx, alignment, text, url)
	alignment = alignment or 0.5

	local window_width = ImGui.GetWindowSize(ctx)
	local text_width   = ImGui.CalcTextSize(ctx, text)

	if not reaper.CF_ShellExecute then
		ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
		ImGui.Text(ctx, url)
		return
	end

	local color = ImGui.GetStyleColor(ctx, ImGui.Col_CheckMark())
	ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
	ImGui.TextColored(ctx, color, text)
	if ImGui.IsItemClicked(ctx) then
		reaper.CF_ShellExecute(url)
	elseif ImGui.IsItemHovered(ctx) then
		ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
	end
end

local function ImGui_PopupText(ctx, text, alignment, urls)
	if #urls == 0 then
		return
	end

	if #text == 0 then
		return
	end

	alignment = alignment or 0.5

	if alignment ~= -1 then
		local window_width = ImGui.GetWindowSize(ctx)
		local text_width   = ImGui.CalcTextSize(ctx, text)
		ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
	end

	if not reaper.CF_ShellExecute then
		ImGui.Text(ctx, urls[math.random(1, #urls)].url)
		return
	end

	local color = ImGui.GetStyleColor(ctx, ImGui.Col_CheckMark())
	ImGui.TextColored(ctx, color, text)
	if ImGui.IsItemClicked(ctx) then
		ImGui.OpenPopup(ctx, text.."_Links")
	elseif ImGui.IsItemHovered(ctx) then
		ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
	end

	if ImGui.BeginPopup(ctx, text.."_Links") then
		for _, link in pairs(urls) do
			if ImGui.Selectable(ctx, link.text) then
				reaper.CF_ShellExecute(link.url)
			end
		end
		ImGui.EndPopup(ctx)
	end
end

local function ImGui_AlignedText(ctx, text, alignment)
	alignment = alignment or 0.5

	local window_width = ImGui.GetWindowSize(ctx)
	local text_width   = ImGui.CalcTextSize(ctx, text)

	ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
	ImGui.Text(ctx, text)
end

local function ImGui_AlignedElements(ctx, alignment, texts, func)
	alignment = alignment or 0.5

	local window_width = ImGui.GetWindowSize(ctx)
	local text_width   = 0
	for _, text in pairs(texts) do
		text_width = text_width + ImGui.CalcTextSize(ctx, text)
	end

	ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
	func(texts)
end

local function ImGui_Indenter(ctx, amount, func)
	for _ = 1, amount do
		ImGui.Indent(ctx)
	end

	func()

	for _ = 1, amount do
		ImGui.Unindent(ctx)
	end
end

local function ImGui_ButtonWithHint(ctx, button_text, alignment, desc)
	desc = desc or ""

	alignment = alignment or 0.5

	local window_width = ImGui.CalcItemWidth(ctx)
	local text_width   = ImGui.CalcTextSize(ctx, button_text)

	ImGui.SetCursorPosX(ctx, window_width * alignment - text_width / 2.0)
	local rv = ImGui.Button(ctx, button_text)

	if desc == "" or not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort()) then
		return rv
	end

	if ImGui.BeginTooltip(ctx) then
		ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
		ImGui.Text(ctx, desc)
		ImGui.PopTextWrapPos(ctx)
		ImGui.EndTooltip(ctx)
	end

	return rv
end

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

-- If `reaper_color` is `true` then the color will b e for Reaper's UI elements such as Tracks and Items.
local function hsl2rgb(H, S, L, reaper_color)
	reaper_color = reaper_color or false

	local C = (1-math.abs((2*L)-1))*S
	local X = C*(1-math.abs((((H%360) / 60)%2)-1))
	local m = L - C/2

	local color = {0, 0, 0}

	H = H % 360.0
	if 0 <= H and H < 60 then
		color = {C, X, 0}
	elseif H < 120 then
		color = {X, C, 0}
	elseif H < 180 then
		color = {0, C, X}
	elseif H < 240 then
		color = {0, X, C}
	elseif H < 300 then
		color = {X, 0, C}
	elseif H < 360 then
		color = {C, 0, X}
	end

	local outColor	= 0x0000000
	local r = math.floor((color[1]+m)*255)
	local g = math.floor((color[2]+m)*255)
	local b = math.floor((color[3]+m)*255)
	outColor		= r
	outColor		= (outColor << 8) | g
	outColor		= (outColor << 8) | b
	if reaper_color then
		outColor = outColor | 0x1000000
	else
		outColor = (outColor << 8) | 0xFF
	end
	return outColor
end

local VAF = {
	VP_Presets = {},

	params = {

	},

	preset_names = {},
	presets		 = {},

	AddPreset = function(self, name, func)
		table.insert(self.preset_names, name)
		self.presets[name] = func
	end,

	PreviewPresset = function(self, preset_index, index)
		local found_preset = self.presets[self.preset_names[preset_index]]
		if found_preset then
			return found_preset(index, nil)
		else
			return {
				h = 0,
				v = 0,
			}
		end
	end,

	AddVFX = function(self, track, name, presset_name, force_add)
		local fx = reaper.TrackFX_GetByName(track, name, false)
		if fx == -1 or force_add then
			fx = reaper.TrackFX_AddByName(track, "Video processor", 0, 1)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "renamed_name", name)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "VIDEO_CODE", self.VP_Presets[presset_name])
		end
		return fx
	end,

	--[[
	params = {
		volumet_to_opcaity = false
	}
	--]]
	ApplyPresset = function(self, preset_index, params)
		reaper.Undo_BeginBlock()
		reaper.PreventUIRefresh(1)

		local items_count = reaper.CountSelectedMediaItems(0)
		if items_count == 0 then
			return
		end

		local item_track = reaper.GetMediaItemTrack(reaper.GetSelectedMediaItem(0, 0))

		local found_preset = self.presets[self.preset_names[preset_index]]

		local env_horiz_flip	= nil
		local env_vert_flip		= nil
		local env_opacity		= nil

		local flips_check = found_preset(0, 0)

		-- TODO: Prepare envelopes

		-- TODO:Add pressets

		-- Add Flipper

		if params.add_flips then
			local fx_flip = self:AddVFX(item_track, "VAF: Flipper", "Flipper.eel")
			env_horiz_flip = flips_check.h ~= nil and reaper.GetFXEnvelope(item_track, fx_flip, 0, true) or nil
			env_vert_flip  = flips_check.v ~= nil and reaper.GetFXEnvelope(item_track, fx_flip, 1, true) or nil
		end

		-- Add Opacity
		if params.volume_to_opacity then
			local fx_opacity = self:AddVFX(item_track, "VAF: Opacity", "Opacity.eel")
			env_opacity = reaper.GetFXEnvelope(item_track, fx_opacity, 0, true)
		end


		-- Finilizing with Chroma-key
		local _ = self:AddVFX(item_track, "VAF: Chroma-key", "Chroma.eel")
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------

		-- Process flippings
		for index = 0, items_count - 1 do
			local item		= reaper.GetSelectedMediaItem(0, index)
			local item_pos	= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			--local item_len	= reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

			local evaluated_flips = found_preset(index, item)

			-- TODO: Figure out inseritng points into pooled automation items.
			--local ai_i = reaper.InsertAutomationItem(
			--	env_horiz_flip,
			--	math.max(evaluated_flips.h, 0)+1,
			--	---1,
			--	item_pos, item_len
			--)

			if env_horiz_flip then
				reaper.InsertEnvelopePointEx(
					-- env
					env_horiz_flip,
					-- autoitem_idx
					-1,
					-- pos, val
					item_pos, math.max(evaluated_flips.h, 0),
					-- shape, tension
					1, 1,
					-- isSelected, noSort
					false, true
				)
			end

			if env_vert_flip then
				reaper.InsertEnvelopePointEx(
					-- env
					env_vert_flip,
					-- autoitem_idx
					-1,
					-- pos, val
					item_pos, math.max(evaluated_flips.v, 0),
					-- shape, tension
					1, 1,
					-- isSelected, noSort
					false, true
				)
			end

			-- Volume -> Opacity
			if env_opacity then
				reaper.InsertEnvelopePointEx(
					env_opacity,
					-1,
					item_pos, reaper.GetMediaItemInfo_Value(item, "D_VOL"),
					1, 1,
					false, true
				)
			end
		end

		reaper.Envelope_SortPoints(env_horiz_flip)

		reaper.Undo_EndBlock("[VAF] Apply Presset", 0)
		reaper.UpdateArrange()
	end
}

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

local GUI = {
	version = "1.0.0",
	name	= "Video Auto-Flipper",

	timer = 0.0,
	ctx = nil, -- ImGui context.

	UI_Data = {
		preview_index = 0,
		--------------------------------------------
		images_to_load = {
			"img_rosn.png",
			"Img_rosnBass.png",
		},
		image_binaries = {},
		selected_image = "",
		--------------------------------------------
		selected_preset		  = 0,
		selected_preset_click = 0,
		presets_string = "",

		--------------------------------------------
		--------------------------------------------

		CHB_add_aspect_fixer		= true,
		CHB_add_aspect_fixer_click	= true,
		--------------------------------------------
		CHB_add_cropper			= true,
		CHB_add_cropper_click	= true,
		--------------------------------------------
		CHB_add_flips		= true,
		CHB_add_flips_click = false,
		--------------------------------------------
		CHB_volume_to_opacity		= false,
		CHB_volume_to_opacity_click = false,

		--------------------------------------------
		--------------------------------------------

		CHB_flip_only_on_pitch_change		= false,
		CHB_flip_only_on_pitch_change_click = false,
	},

	-------------------------------------------------------------------------------------------------------------------

	window_flags = ImGui.WindowFlags_None()
		| ImGui.WindowFlags_NoDocking()
		| ImGui.WindowFlags_NoResize()
		| ImGui.WindowFlags_NoCollapse()
		--| ImGui.WindowFlags_NoSavedSettings()
		| ImGui.WindowFlags_AlwaysAutoResize()
	, -- this lil fella is here so i can add and comment out flags at the end with ease, okay?

	global_style_vars = {
		{ImGui.StyleVar_WindowTitleAlign(), {0.5, 0.5}},
		{ImGui.StyleVar_SeparatorTextAlign(), {0.5, 0.5}},
	},

	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------

	-- Implementable Function
	Init = function(self) end,

	-- Implementable Function
	UpdateParams = function(self) end,

	-------------------------------------------------------------------------------------------------------------------

	StyleVar_Processor = function(self)
		for _, style_var in pairs(self.global_style_vars) do
			ImGui.PushStyleVar(self.ctx, style_var[1], table.unpack(style_var[2]))
		end
	end,

	-- Most likely won't change ever.
	LoopUI = function(self)
		self:StyleVar_Processor()

		ImGui.SetNextWindowSize(self.ctx, 290, 371, ImGui.Cond_Always())

		local window_visible, window_open = select(1, ImGui.Begin(self.ctx, self.name.." "..self.version, true, self.window_flags))

		if window_visible then
			self:UpdateParams()
			self:DrawUI(self.ctx)

			ImGui.End(self.ctx)
		end

		ImGui.PopStyleVar(self.ctx, #self.global_style_vars)

		-- Continue looping itself
		if window_open then
			reaper.defer(self:LoopUI_Wrapper())
		end
	end,

	-- Wrappy wrap
	LoopUI_Wrapper = function(self)
		return function() self:LoopUI() end
	end,

	-- Overridable
	SetupWindow = function(self)
		self.ctx = ImGui.CreateContext(self.name)

		self:Init()

		ImGui.SetConfigVar(self.ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(),	1)
		ImGui.SetConfigVar(self.ctx, ImGui.ConfigVar_WindowsResizeFromEdges(),		1)

		reaper.defer(self:LoopUI_Wrapper())
	end,

	-------------------------------------------------------------------------------------------------------------------

	DrawUI = function(self) end, -- Implementable Function

}

-----------------------------------------------------------------------------------------------------------------------

function GUI:Init()
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	local script_path = filename:match("^(.*)[\\/](.-)$")

	-------------------------------------------------------------------------------------------------------------------

	VAF:AddPreset("Horizontal Flips", function(index, item)
		return {
			v = nil,
			h = index % 2 == 0 and -1 or 1,
			r = nil,
		}
	end)

	VAF:AddPreset("Vertical Flips", function(index, item)
		return {
			v = index % 2 == 0 and -1 or 1,
			h = nil,
			r = nil,
		}
	end)

	VAF:AddPreset("CV H+V Flips", function(index, item)
		return {
			v = math.floor((index+1)/2) % 2 == 0 and -1 or 1,
			h = math.floor((index)/2) % 2 == 0 and -1 or 1,
			r = nil,
		}
	end)

	VAF:AddPreset("CCV H+V Flips", function(index, item)
		return {
			v = math.floor((index)/2) % 2 == 0 and -1 or 1,
			h = math.floor((index+1)/2) % 2 == 0 and -1 or 1,
			r = nil,
		}
	end)

	local preset_names = {
		"AspectratioFixer.eel",
		"BoxCrop.eel",
		"Cropper.eel",
		"Flipper.eel",
		"Opacity.eel",
		"PositionOffset.eel",
		"Pre-Compose.eel",
		"Rotate.eel",
		"Scale.eel",
		"Chroma.eel",
		"SolidColorFill.eel",
	}

	for _, preset_name in pairs(preset_names) do
		local file = io.open(script_path .. "\\VP_Presets\\" .. preset_name, 'r')

		local content = file:read("*all")
		VAF.VP_Presets[preset_name] = content
	end

	--------------------------------------------------------------------------------------------------------------------

	for _, image_name in pairs(self.UI_Data.images_to_load) do
		local image = ImGui.CreateImage(script_path .. "\\images\\" .. image_name)
		reaper.ImGui_Attach(self.ctx, image)
		self.UI_Data.image_binaries[image_name] = image
	end

	for _, name in pairs(VAF.preset_names) do
		self.UI_Data.presets_string = self.UI_Data.presets_string .. name .. '\0'
	end

	self.UI_Data.selected_image = self.UI_Data.images_to_load[math.random(1, #self.UI_Data.images_to_load)]
end




function GUI:UpdateParams()
	self.timer = (self.timer + 1) % 132

	if self.timer % 11 == 0 then
		self.UI_Data.preview_index = self.UI_Data.preview_index + 1
	end
end


function GUI:TAB_Flipper()
	ImGui_AlignedText(self.ctx, "Select Video Items you want to flip", 0.5)

	--------------------------------------------------------------------------------------------------------------------
	ImGui.SeparatorText(self.ctx, "PRESETS")
	--------------------------------------------------------------------------------------------------------------------
	-- Presets --

	ImGui.PushItemWidth(self.ctx, 150)
	self.UI_Data.selected_preset_click, self.UI_Data.selected_preset =
	ImGui.ListBox(self.ctx, "->", self.UI_Data.selected_preset, self.UI_Data.presets_string, 5)

	ImGui.SameLine(self.ctx)

	do
		local flips = VAF:PreviewPresset(self.UI_Data.selected_preset + 1, self.UI_Data.preview_index)
		local uv_min_x = 1.0 -  math.max(flips.h or 1, 0.0)
		local uv_min_y = 1.0 -  math.max(flips.v or 1, 0.0)
		local uv_max_x = 		math.max(flips.h or 1, 0.0)
		local uv_max_y = 		math.max(flips.v or 1, 0.0)

		local image_size = 94
		local border_col = ImGui.GetStyleColor(self.ctx, ImGui.Col_Border())
		ImGui.Image(
				self.ctx,
				self.UI_Data.image_binaries[self.UI_Data.selected_image],
				image_size, image_size-1, -- pixel perfect to the list
				uv_min_x, uv_min_y,
				uv_max_x, uv_max_y,
				0xFFFFFFFF,
				border_col
		)
	end

	self.UI_Data.CHB_add_aspect_fixer_click, self.UI_Data.CHB_add_aspect_fixer =
	ImGui.Checkbox(self.ctx, "Add Aspectratio Fixer.", self.UI_Data.CHB_add_aspect_fixer)

	self.UI_Data.CHB_add_flips_click, self.UI_Data.CHB_add_flips =
	ImGui.Checkbox(self.ctx, "Add Flips.", self.UI_Data.CHB_add_flips)

	self.UI_Data.CHB_volume_to_opacity_click, self.UI_Data.CHB_volume_to_opacity =
	ImGui.Checkbox(self.ctx, "Volume -> Opacity", self.UI_Data.CHB_volume_to_opacity)

	--------------------------------------------------------------------------------------------------------------------
	ImGui.SeparatorText(self.ctx, "SETTINGS")
	--------------------------------------------------------------------------------------------------------------------
	-- Settings --

	self.UI_Data.CHB_flip_only_on_pitch_change_click, self.UI_Data.CHB_flip_only_on_pitch_change =
	ImGui.Checkbox(self.ctx, "Flip only on Pitch change.", self.UI_Data.CHB_flip_only_on_pitch_change)

	--------------------------------------------------------------------------------------------------------------------
	ImGui.SeparatorText(self.ctx, "")
	--------------------------------------------------------------------------------------------------------------------
	-- Buttons --

	if ImGui.Button(self.ctx, "Apply") then
		local params = {
			volume_to_opacity	= self.UI_Data.CHB_volume_to_opacity,
			add_flips			= self.UI_Data.CHB_add_flips
		}
		VAF:ApplyPresset(self.UI_Data.selected_preset + 1, params)
	end

	ImGui.SameLine(self.ctx)

	do -- Progress bar
		ImGui.PushStyleColor(self.ctx, ImGui.Col_PlotHistogram(), 0xE67A00FF)
		ImGui.PushStyleVar(self.ctx, ImGui.StyleVar_FrameBorderSize(), 1)

		ImGui.PushItemWidth(self.ctx, -FLT_MIN)
		ImGui.ProgressBar(self.ctx, 0.0, 0, 0, ("%.1f/%d"))

		ImGui.PopStyleVar(self.ctx)
		ImGui.PopStyleColor(self.ctx)
	end
end


local function Add_fx(name, presset_name, force_add)
	force_add = force_add or false
	for i = 0, reaper.CountSelectedTracks(0) do
		VAF:AddVFX(
			reaper.GetSelectedTrack(0, i),
			name, presset_name,
			force_add
		)
	end
end

function GUI:TAB_VFX()
	ImGui_AlignedText(self.ctx, "Select tracks you want to apply any FX to.", 0.5)
	ImGui_AlignedText(self.ctx, "Hover over each button to\nget desciption for them.", 0.5)
	if ImGui.BeginChild(self.ctx, "VFX", 0, 0, true, ImGui.WindowFlags_AlwaysVerticalScrollbar()) then
		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "TRANSFORM")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Position Offset", 0.5,
			"Sets the Video's position in percentage."
		) then
			Add_fx("VAF: Position Offset", "PositionOffset.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Rotate", 0.5) then
			Add_fx("VAF: Rotate", "Rotate.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Scale", 0.5) then
			Add_fx("VAF: Scale", "Scale.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Opacity", 0.5) then
			Add_fx("VAF: Opacity", "Opacity.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Flipper", 0.5,
			"Mainly used for fliping the videos,\nregular scaling doesn't let you do that."
		) then
			Add_fx("VAF: Flipper", "Flipper.eel", true)
		end

		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "HELPERS")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Aspectratio Fixer", 0.5,
			"Fixes aspectratio of the videos that don't match the size of the composition."
		) then
			Add_fx("VAF: Aspectratio Fixer", "AspectratioFixer.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Pre-Compose", 0.5,
			"Bakes the current rendered frame as if it was After Effect's Pre-Compose kind of thing."
		) then
			Add_fx("VAF: Pre-Compose", "Pre-Compose.eel", true)
		end

		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "CROPING")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Box Crop", 0.5) then
			Add_fx("VAF: Box Crop", "BoxCrop.eel", true)
		end

		if ImGui_ButtonWithHint(self.ctx, "Cropper", 0.5) then
			Add_fx("VAF: Cropper", "Cropper.eel", true)
		end

		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "MISC")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Solid Color Fill", 0.5) then
			Add_fx("VAF: Solid Color Fill", "SolidColorFill.eel", true)
		end

		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "FINALIZERS")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Chroma-key", 0.5,
			MultLineStringConstructor(
				"A very inmportant effect that needs to be placed at the end of the chain of those effects that are listed above.",
				"",
				"It's done in such way due to Reaper's limitations/absurtd control over the video elements in the rendering, so this is a workaround for compositing alike methods of working with videos."
			)
		) then
			Add_fx("VAF: Chroma-key", "Chroma.eel", true)
		end

		--------------------------------------------------------------------------------------------------------------------

		ImGui.EndChild(self.ctx)
	end
end

function GUI:DrawUI()
	local _
	--------------------------------------------------------------------------------------------------------------------
	ImGui_AlignedElements(
		self.ctx,
		0.5,
		{
			"Made By",
			"Zly"
		},
		function(texts)
			ImGui.Text(self.ctx, texts[1])
			ImGui.SameLine(self.ctx)
			ImGui_PopupText(self.ctx, texts[2], -1, {
				{
					text = "YT (AmySupica)",
					url = "https://www.youtube.com/@AmySupica",
				},
				{
					text = "Twitter",
					url = "https://twitter.com/zly_u",
				},
				{
					text = "Blue Sky",
					url = "https://bsky.app/profile/zly.bsky.social",
				},
				{
					text = "GitHub",
					url = "https://github.com/Zly-u",
				}
			})
		end
	)

	if ImGui.BeginTabBar(self.ctx, '##tabs', ImGui.TabBarFlags_None()) then
		if ImGui.BeginTabItem(self.ctx, "Flipper") then
			self:TAB_Flipper()
			ImGui.EndTabItem(self.ctx)
		end
		if ImGui.BeginTabItem(self.ctx, "VFX") then
			self:TAB_VFX()
			ImGui.EndTabItem(self.ctx)
		end
		ImGui.EndTabBar(self.ctx)
	end
end

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

function main()
	GUI:SetupWindow()
end

main()