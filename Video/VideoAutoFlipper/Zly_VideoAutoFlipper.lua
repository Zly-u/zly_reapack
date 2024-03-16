-- Made by Zly
--	https://github.com/Zly-u
--  https://twitter.com/zly_u

-- @noindex

do	-- Allows to require scripts relatively to this current script's path.
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	package.path = filename:match("^(.*)[\\/](.-)$") .. "/?.lua;" .. package.path
end

--[[===================================================]]--
--[[=================== HELPERS =======================]]--
--[[===================================================]]--

local function UndoWrap(block_name, func)
	reaper.Undo_BeginBlock()
	func()
	reaper.Undo_EndBlock(block_name, 0)
end

local function GetFilesInDir(sub_path)
	local filename = debug.getinfo(1, "S").source:match("^@?(.+)$")
	local script_path = filename:match("^(.*)[\\/](.-)$")
	
	local dirs = {}
	
	local file_index = 0
	while true do
		local file = reaper.EnumerateFiles(script_path.."\\"..sub_path, file_index)
		if file == nil then
			break
		end
		dirs[file] = script_path.."\\"..sub_path.."\\"..file
		file_index = file_index + 1
	end
	
	return dirs
end

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

local function SplitString(str, delimiter, max_splits)
	max_splits = max_splits or -1

	local start_index = 1
	local end_index = #str
	local result_list = {}
	local split_count = 1

	for i = 1, #str do
		if split_count >= max_splits and max_splits ~= -1 then
			table.insert(result_list,
				string.sub(str, start_index, -1)
			)
			return result_list
		end

		if str:sub(i, i) == delimiter then
			end_index = i

			local found_part = string.sub(str, start_index, end_index-1)

			if found_part:sub(1, 1) == " " then
				found_part = string.sub(found_part, 2, -1)
			end
			table.insert(result_list, found_part)

			start_index = i+1
			split_count = split_count + 1
		end
	end

	local found_last_part = string.sub(str, start_index, #str)
	if found_last_part:sub(1, 1) == " " then
		found_last_part = string.sub(found_last_part, 2, -1)
	end
	table.insert(result_list, found_last_part)

	return result_list
end

local function TextWrapper(text, max_string_len, bCenter)
	bCenter = bCenter or false
	-- Text wrapping
	local splitted_text = ""
	local text_lines = { ""}
	local max_length = 0
	local final_text = ""
	if #text > max_string_len then
		splitted_text = SplitString(text, " ")
		local char_count = 0
		for _, word in pairs(splitted_text) do
			char_count = char_count + #word + 1

			-- wrapping
			if char_count > max_string_len then
				if char_count - (#word + 1) > max_length then
					max_length = char_count - (#word + 1)
				end

				table.insert(text_lines, "")
				char_count = #word + 1
			end

			text_lines[#text_lines] = text_lines[#text_lines]..word..' '
		end
	else
		return text
	end

	-- Text aligning
	if bCenter then
		if #text_lines > 1 then
			for _, line in pairs(text_lines) do
				local spaces_to_add = math.ceil((max_length - #line) / 2.0)
				final_text = final_text..string.rep(' ', spaces_to_add)..line..'\n'
			end
		end
	else
		for _, line in pairs(text_lines) do
			final_text = final_text..line..'\n'
		end
	end

	return final_text
end

local function MultiLineStringConstructor(max_len, ...)
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
		local error_msg = MultiLineStringConstructor(-1,
			"Please install next Packages through ReaPack",
			"In Order for the script to work:\n",
			self.builded_reapack_deps_list,
			"\nAfter closing this window ReaPack's Package Browser",
			"will open with the dependencies you need!"
		)

		reaper.MB(error_msg, "Error", 0)

		if not reaper.ReaPack_BrowsePackages then
			local reapack_error = MultiLineStringConstructor(-1,
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

	local pad_x, pad_y		= ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding())
	local avail_x, avail_y	= ImGui.GetContentRegionAvail(ctx)
	local text_width		= ImGui.CalcTextSize(ctx, button_text)

	local frame_size = text_width + pad_x * 2.0
	local pos = (avail_x - frame_size) * alignment

	ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + pos)

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
	outColor = r
	outColor = (outColor << 8) | g
	outColor = (outColor << 8) | b
	if reaper_color then
		outColor = outColor | 0x1000000
	else
		outColor = (outColor << 8) | 0xFF
	end
	return outColor
end

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
		image_names		= {},
		image_binaries	= {},
		selected_image_binary = nil,
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
		CHB_volume_to_opacity		= true,
		CHB_volume_to_opacity_click = false,
		
		--------------------------------------------
		--------------------------------------------
		
		CHB_flip_only_on_pitch_change		= false,
		CHB_flip_only_on_pitch_change_click = false,
		
		--------------------------------------------
		--------------------------------------------
		
		flip_count = 0,
		amount_of_items_to_flip = 0,
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
		{ImGui.StyleVar_FrameBorderSize(), {1}},
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
		
		----
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_WindowBg(),           0x404040FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_FrameBg(),            0x303030FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_TitleBgActive(),      0x1E1E1EFF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_CheckMark(),          0x40C040FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_Button(),             0x404040FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_ButtonHovered(),      0x545454FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_ButtonActive(),       0x6363A5FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_Tab(),                0x303030FF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_TabHovered(),         0x424242CC)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_TabActive(),          0x6A6A6AFF)
		--ImGui.PushStyleColor(self.ctx, ImGui.Col_TabUnfocusedActive(), 0x303030FF)
		----
		
		
		ImGui.SetNextWindowSize(self.ctx, 288, 375, ImGui.Cond_Always())
		
		local window_visible, window_open = select(1, ImGui.Begin(self.ctx, self.name.." "..self.version, true, self.window_flags))
		
		if window_visible then
			self:UpdateParams()
			self:DrawUI(self.ctx)
			
			ImGui.End(self.ctx)
		end
		
		--ImGui.PopStyleColor(self.ctx, 11)
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

local VAF = {
	VP_Presets = {},
	
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
				h = nil,
				v = nil,
				r = nil,
			}
		end
	end,


	AddVFX = function(self, track, name, presset_name, force_add)
		local fx_chroma = reaper.TrackFX_GetByName(track, "VAF: Chroma-key", false)
		local fx = reaper.TrackFX_GetByName(track, name, false)
		if fx == -1 or force_add then
			fx = reaper.TrackFX_AddByName(track, "Video processor", 0, fx_chroma ~= -1 and -1000-fx_chroma or 1)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "renamed_name", name)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "VIDEO_CODE", self.VP_Presets[presset_name])
		end
		return fx
	end,

	--[[
	params = {
		volume_to_opcaity = false
		add_flips = true
		flip_only_on_pitch_change = false
	}
	--]]
	ApplyPresset = function(self, preset_index, params)
		reaper.PreventUIRefresh(1)

		local items_count = reaper.CountSelectedMediaItems(0)
		if items_count == 0 then
			reaper.MB("No Media Items were selected!", "Error", 0)
			return
		end

		local item_track = reaper.GetMediaItemTrack(reaper.GetSelectedMediaItem(0, 0))

		local found_preset = self.presets[self.preset_names[preset_index]]

		local env_horiz_flip	= nil
		local env_vert_flip		= nil
		local env_opacity		= nil

		local flips_check = found_preset(0, nil)
		
		-- Add Flipper
		if params.add_flips then
			local fx_flip = self:AddVFX(item_track, "VAF: Flipper", "Flipper.eel")
			env_horiz_flip = flips_check.h ~= nil and reaper.GetFXEnvelope(item_track, fx_flip, 0, true) or nil
			env_vert_flip  = flips_check.v ~= nil and reaper.GetFXEnvelope(item_track, fx_flip, 1, true) or nil
		end
		
		-- Finilizing with Chroma-key
		local _ = self:AddVFX(item_track, "VAF: Chroma-key", "Chroma.eel")
		
		-- Add Opacity
		if params.volume_to_opacity then
			local fx_opacity = self:AddVFX(item_track, "VAF: Opacity", "Opacity.eel")
			env_opacity = reaper.GetFXEnvelope(item_track, fx_opacity, 0, true)
		end
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		
		local prev_ai = nil
		local process_event = function(env, env_id, value, item_take, item_pos, item_len)
			if not env then return end
			
			local ai_i = -1
			
			local _, take_name = reaper.GetSetMediaItemTakeInfo_String(item_take, "P_NAME", "", false)
			if take_name == "VAF_SILENT_FILL" then
				local env_len = reaper.GetSetAutomationItemInfo(env, prev_ai, "D_LENGTH", 0, false)
				reaper.GetSetAutomationItemInfo(env, prev_ai, "D_LENGTH", env_len+item_len, true)
				goto fuck_off
			end

			ai_i = reaper.InsertAutomationItem(
				env,
				env_id,
				item_pos, item_len
			)

			prev_ai = ai_i

			reaper.InsertEnvelopePointEx(
				env,
				ai_i,
				item_pos, value,
				1, 1,
				false, false
			)
			
			::fuck_off::
		end
		
		local flip_index = -1
		local prev_pitch = nil
		for index = 0, items_count - 1 do
			local item		= reaper.GetSelectedMediaItem(0, index)
			local item_take  = reaper.GetActiveTake(item)
			local item_pos	= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			local item_len	= reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			
			-- Flip only upon pitch change
			local _, take_name = reaper.GetSetMediaItemTakeInfo_String(item_take, "P_NAME", "", false)
			if take_name ~= "VAF_SILENT_FILL" then
				if params.flip_only_on_pitch_change then
					local take_pitch = reaper.GetMediaItemTakeInfo_Value(item_take, "D_PITCH")
					
					if take_pitch ~= prev_pitch then
						if prev_pitch ~= nil then
							flip_index = flip_index + 1
						end
						prev_pitch = take_pitch
					end
				else
					flip_index = flip_index + 1
				end
			end
			
			local evaluated_flips = found_preset(flip_index, item)
			
			process_event(env_horiz_flip,	math.max(evaluated_flips.h or 0, 0)+69, math.max(evaluated_flips.h or 0, 0), item_take, item_pos, item_len)
			process_event(env_vert_flip,	math.max(evaluated_flips.v or 0, 0)+69, math.max(evaluated_flips.v or 0, 0), item_take, item_pos, item_len)
			local item_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
			process_event(env_opacity,		math.floor(item_vol * 255), item_vol, item_take, item_pos, item_len)
			
			GUI.UI_Data.flip_count = GUI.UI_Data.flip_count + 1
		end
		
		--if env_horiz_flip then
		--	reaper.Envelope_SortPoints(env_horiz_flip)
		--end
		--if env_vert_flip then
		--	reaper.Envelope_SortPoints(env_vert_flip)
		--end
		--if env_opacity then
		--	reaper.Envelope_SortPoints(env_opacity)
		--end
		reaper.UpdateArrange()
	end
}

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--


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

	VAF:AddPreset("CW H+V Flips", function(index, item)
		return {
			v = math.floor((index)/2) % 2 == 0 and -1 or 1,
			h = math.floor((index+1)/2) % 2 == 0 and -1 or 1,
			r = nil,
		}
	end)

	VAF:AddPreset("CCW H+V Flips", function(index, item)
		return {
			v = math.floor((index+1)/2) % 2 == 0 and -1 or 1,
			h = math.floor((index)/2) % 2 == 0 and -1 or 1,
			r = nil,
		}
	end)

	for file_name, file_path in pairs(GetFilesInDir("VP_Presets")) do
		local file = io.open(file_path, 'r')

		local content = file:read("*all")
		VAF.VP_Presets[file_name] = content
	end

	--------------------------------------------------------------------------------------------------------------------

	for image_name, image_dir in pairs(GetFilesInDir("images")) do
		local image = ImGui.CreateImage(image_dir)
		reaper.ImGui_Attach(self.ctx, image)
		table.insert(self.UI_Data.image_names, image_name)
		self.UI_Data.image_binaries[image_name] = image
	end

	for _, name in pairs(VAF.preset_names) do
		self.UI_Data.presets_string = self.UI_Data.presets_string .. name .. '\0'
	end

	self.UI_Data.selected_image_binary = self.UI_Data.image_binaries[self.UI_Data.image_names[math.random(1, #self.UI_Data.image_names)]]
end




function GUI:UpdateParams()
	self.timer = (self.timer + 1) % 132

	if self.timer % 11 == 0 then
		self.UI_Data.preview_index = self.UI_Data.preview_index + 1
	end
	
	local cur_selected_items = reaper.CountSelectedMediaItems(0)
	if cur_selected_items ~= self.UI_Data.amount_of_items_to_flip then
		self.UI_Data.amount_of_items_to_flip = cur_selected_items
		self.UI_Data.flip_count = 0
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
				self.UI_Data.selected_image_binary,
				image_size, image_size-1, -- pixel perfect to the list
				uv_min_x, uv_min_y,
				uv_max_x, uv_max_y,
				0xFFFFFFFF,
				border_col
		)
	end

	self.UI_Data.CHB_add_aspect_fixer_click, self.UI_Data.CHB_add_aspect_fixer =
	ImGui.Checkbox(self.ctx, "Add Aspectratio Fixer", self.UI_Data.CHB_add_aspect_fixer)

	self.UI_Data.CHB_add_flips_click, self.UI_Data.CHB_add_flips =
	ImGui.Checkbox(self.ctx, "Add Flips", self.UI_Data.CHB_add_flips)

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
			volume_to_opacity			= self.UI_Data.CHB_volume_to_opacity,
			add_flips					= self.UI_Data.CHB_add_flips,
			flip_only_on_pitch_change	= self.UI_Data.CHB_flip_only_on_pitch_change
		}
		UndoWrap("[VAF] Apply Presset", function()
			self.UI_Data.flip_count = 0
			VAF:ApplyPresset(self.UI_Data.selected_preset + 1, params)
		end)
	end

	ImGui.SameLine(self.ctx)

	do -- Progress bar
		ImGui.PushStyleColor(self.ctx, ImGui.Col_PlotHistogram(), 0xE67A00FF)
		ImGui.PushStyleVar(self.ctx, ImGui.StyleVar_FrameBorderSize(), 1)

		ImGui.PushItemWidth(self.ctx, -FLT_MIN)
		
		local progress = self.UI_Data.flip_count ~= 0 and self.UI_Data.flip_count/self.UI_Data.amount_of_items_to_flip or 0.0
		ImGui.ProgressBar(self.ctx, progress, 0, 0, ("%d/%d"):format(self.UI_Data.flip_count, self.UI_Data.amount_of_items_to_flip))
		ImGui.SameLine(self.ctx)
		ImGui.Text(self.ctx, ("%%%03d"):format(math.floor(progress * 100.0)))
		
		ImGui.PopStyleVar(self.ctx)
		ImGui.PopStyleColor(self.ctx)
	end
end


local function Add_fx(name, presset_name, force_add)
	force_add = force_add or false

	local track_count = reaper.CountSelectedTracks(0)

	if track_count == 0 then
		reaper.MB("No tracks were selected!", "Error", 0)
		return
	end

	for i = 0, track_count-1 do
		VAF:AddVFX(
			reaper.GetSelectedTrack(0, i),
			name, presset_name,
			force_add
		)
	end
end

function GUI:TAB_VFX()
	ImGui_AlignedText(self.ctx, "Select tracks you want to", 0.5)
	ImGui_AlignedText(self.ctx, "apply any FX to.", 0.5)

	ImGui.Separator(self.ctx)

	ImGui_AlignedText(self.ctx, "Hover over each button to", 0.5)
	ImGui_AlignedText(self.ctx, "get desciption for them.", 0.5)

	if ImGui.BeginChild(self.ctx, "VFX", 0, 0, true, ImGui.WindowFlags_AlwaysVerticalScrollbar()) then
		if ImGui.CollapsingHeader(self.ctx, "TRANSFORM") then
			if ImGui_ButtonWithHint(self.ctx, "Position Offset", 0.5,
					"Sets the Video's position in percentage."
			) then
				UndoWrap("[VAF] Add Position Offset", function()
					Add_fx("VAF: Position Offset", "PositionOffset.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Rotate", 0.5) then
				UndoWrap("[VAF] Rotate", function()
					Add_fx("VAF: Rotate", "Rotate.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Scale", 0.5) then
				UndoWrap("[VAF] Scale", function()
					Add_fx("VAF: Scale", "Scale.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Opacity", 0.5) then
				UndoWrap("[VAF] Opacity", function()
					Add_fx("VAF: Opacity", "Opacity.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Flipper", 0.5,
					"Mainly used for fliping the videos,\nregular scaling doesn't let you do that."
			) then
				UndoWrap("[VAF] Flipper", function()
					Add_fx("VAF: Flipper", "Flipper.eel", true)
				end)
			end
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "HELPERS") then
			if ImGui_ButtonWithHint(self.ctx, "Aspectratio Fixer", 0.5,
					"Fixes aspectratio of the videos that don't match the size of the composition."
			) then
				UndoWrap("[VAF] Aspectratio Fixer", function()
					Add_fx("VAF: Aspectratio Fixer", "AspectratioFixer.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Pre-Compose", 0.5,
					"Bakes the current rendered frame as if it was After Effect's Pre-Compose kind of thing."
			) then
				UndoWrap("[VAF] Pre-Compose", function()
					Add_fx("VAF: Pre-Compose", "Pre-Compose.eel", true)
				end)
			end
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "CROPING") then
			if ImGui_ButtonWithHint(self.ctx, "Box Crop", 0.5) then
				UndoWrap("[VAF] Box Crop", function()
					Add_fx("VAF: Box Crop", "BoxCrop.eel", true)
				end)
			end
			
			if ImGui_ButtonWithHint(self.ctx, "Cropper", 0.5) then
				UndoWrap("[VAF] Cropper", function()
					Add_fx("VAF: Cropper", "Cropper.eel", true)
				end)
			end
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "MISC") then
			if ImGui_ButtonWithHint(self.ctx, "Solid Color Fill", 0.5,
					"Just fills the whole composition with a solid color."
			) then
				UndoWrap("[VAF] Solid Color Fill", function()
					Add_fx("VAF: Solid Color Fill", "SolidColorFill.eel", true)
				end)
			end
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "FINALIZERS") then
			if ImGui_ButtonWithHint(self.ctx, "Chroma-key", 0.5,
				MultiLineStringConstructor(-1,
					"A very inmportant effect that needs to be placed at the end of the chain of those effects that are listed above.",
					"",
					"It's done in such way due to Reaper's limitations/absurd control over the video elements in the rendering, so this is a workaround for compositing alike methods of working with videos."
				)
			) then
				UndoWrap("[VAF] Chroma-key", function()
					Add_fx("VAF: Chroma-key", "Chroma.eel", true)
				end)
			end
		end

		----------------------------------------------------------------------------------------------------------------

		ImGui.EndChild(self.ctx)
	end
end


local function create_AI(isPooled)
	isPooled = isPooled or false

	local item_count = reaper.CountSelectedMediaItems(0)

	if item_count == 0 then
		reaper.MB("No Media Items were selected!", "Error", 0)
		return
	end

	for i = 0, item_count-1 do
		local item 			= reaper.GetSelectedMediaItem(0, i)
		local item_track	= reaper.GetMediaItemTrack(item)

		local item_pos	= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_len	= reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

		local fx_null = VAF:AddVFX(item_track, "VAF: NULL", "Null.eel", false)
		local env_null = reaper.GetFXEnvelope(item_track, fx_null, 0, true)

		local _ = reaper.InsertAutomationItem(
			env_null,
			isPooled and 69 or -1,
			item_pos, item_len
		)
	end
end


function GUI:TAB_Helpers()
	ImGui_AlignedText(self.ctx, "Select items/tracks you want to", 0.5)
	ImGui_AlignedText(self.ctx, "apply any of the helpers to.", 0.5)

	ImGui.Separator(self.ctx)

	ImGui_AlignedText(self.ctx, "Hover over each button to", 0.5)
	ImGui_AlignedText(self.ctx, "get desciption for them.", 0.5)

	if ImGui.BeginChild(self.ctx, "AI", 0, 0, true, ImGui.WindowFlags_AlwaysVerticalScrollbar()) then
		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "Automation Items")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Create Pooled", 0.5,
			MultiLineStringConstructor(-1,
				"Creates Pooled Automation Items in a dummy track.",
				"",
				"So every created Automation Item is mimicking each other."
			)
		) then
			UndoWrap("[VAF] Create Pooled", function()
				create_AI(true)
			end)
		end

		if ImGui_ButtonWithHint(self.ctx, "Create Non-pooled", 0.5,
			MultiLineStringConstructor(-1,
				"Creates Non-pooled Automation Items in a dummy track.",
				"",
				"So each envelope is unique."
			)
		) then
			UndoWrap("[VAF] Create Non-Pooled", function()
				create_AI(false)
			end)
		end

		--------------------------------------------------------------------------------------------------------------------
		ImGui.SeparatorText(self.ctx, "Media Items")
		--------------------------------------------------------------------------------------------------------------------

		if ImGui_ButtonWithHint(self.ctx, "Extend to Next", 0.5, "") then
			UndoWrap("[VAF] Extend to Next", function()
				local item_count = reaper.CountSelectedMediaItems()
				if item_count == 0 then return end

				for id = 0, item_count - 2 do
					local item		= reaper.GetSelectedMediaItem(0, id)
					local next_item	= reaper.GetSelectedMediaItem(0, id+1)

					local item_start		= reaper.GetMediaItemInfo_Value(item, "D_POSITION")
					local next_item_start	= reaper.GetMediaItemInfo_Value(next_item, "D_POSITION")
					local target_length		= next_item_start - item_start

					reaper.SetMediaItemLength(item, target_length, false)
				end

				reaper.UpdateArrange()
			end)
		end
		
		if ImGui_ButtonWithHint(self.ctx, "Silent Extend to Next", 0.5, "") then
			UndoWrap("[VAF] Silent Fill to Next", function()
				local item_count = reaper.CountSelectedMediaItems()
				if item_count == 0 then return end
				
				local prev_split = nil
				for id = 0, item_count - 2 do
					local item		= reaper.GetSelectedMediaItem(0, id)
					local next_item	= reaper.GetSelectedMediaItem(0, id+1)
					
					local item_start		= reaper.GetMediaItemInfo_Value(item,		"D_POSITION")
					local item_len			= reaper.GetMediaItemInfo_Value(item,		"D_LENGTH")
					local next_item_start	= reaper.GetMediaItemInfo_Value(next_item,  "D_POSITION")
					local target_length		= next_item_start - item_start
					
					reaper.SetMediaItemLength(item, target_length, false)
					prev_split = reaper.SplitMediaItem(item, item_start+item_len)
					if prev_split then
						reaper.SetMediaItemInfo_Value(prev_split, "D_VOL", 0)
						reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(prev_split), "P_NAME", "VAF_SILENT_FILL", true)
						item_count = item_count + 1
						id = id + 1
					end
				end
				
				reaper.UpdateArrange()
			end)
		end
		
		if ImGui_ButtonWithHint(self.ctx, "Stretch to Next", 0.5, "") then
			UndoWrap("[VAF] Stretch to Next", function()
				local item_count = reaper.CountSelectedMediaItems()
				if item_count == 0 then
					reaper.MB("No Media Items were selected!", "Error", 0)
					return
				end

				reaper.PreventUIRefresh(1)

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

				reaper.UpdateArrange()
			end)
		end

		ImGui.EndChild(self.ctx)
	end
end


function GUI:TAB_FAQ()
	local fla = 0
		| ImGui.WindowFlags_NoResize()
		| ImGui.WindowFlags_AlwaysVerticalScrollbar()
	if ImGui.BeginChild(self.ctx, "AI", 0, 0, true, fla) then
		local max_line_len = 36

		if ImGui.CollapsingHeader(self.ctx, "Why Chroma Key thing?") then
			ImGui.Text(self.ctx,
					TextWrapper(
							"Okay... This is a weird workaround I figured in order to do what I wanted this FX chain to do.",
							max_line_len,
							true
					)
			)
			ImGui.Text(self.ctx,
					TextWrapper(
							"Every effect of VAF effect essentially fills the BG of the source with either Blue or Green for Chroma Key",
							max_line_len,
							true
					)
			)
			ImGui.Text(self.ctx,
					TextWrapper(
							"It essentially allows you to do anything you want with the source without touching anything that is behind the video we are working with.",
							max_line_len,
							true
					)
			)
			ImGui.Text(self.ctx,
					TextWrapper(
							"After the Chroma-Key is aplied everything else behind our video will appear untouched.",
							max_line_len,
							true
					)
			)
			ImGui.Text(self.ctx,
					TextWrapper(
							"Without this the FXs would be applied to the videos behind our current video we are working with.",
							max_line_len,
							true
					)
			)
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "VFX: Chroma Key?") then
			ImGui.Text(self.ctx,
				TextWrapper(
					"Every VFX you add will be added before existing Chroma Key, so you don't have to do that manually.",
					max_line_len,
					true
				)
			)
		end
		
		----------------------------------------------------------------------------------------------------------------
		
		if ImGui.CollapsingHeader(self.ctx, "Helpers: Automation Items?") then
			ImGui.Text(self.ctx,
				TextWrapper(
					"They are handy for creating envelopes to be used for each Media Item, like for animations.",
					max_line_len,
					true
				)
			)
		end
		

		if ImGui.CollapsingHeader(self.ctx, "Helpers: Silent Extend to Next?") then
			ImGui.Text(self.ctx,
				TextWrapper(
					"Silent Fills created by this script won't interfere with the flipping generation, I have made a sure of that.",
					max_line_len,
					true
				)
			)
		end
		
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
				},
				{
					text = "Support",
					url = "https://boosty.to/zly",
				}
			})
		end
	)

	ImGui.Separator(self.ctx)

	--------------------------------------------------------------------------------------------------------------------

	if ImGui.BeginTabBar(self.ctx, "Tabs", ImGui.TabBarFlags_None()) then
		if ImGui.BeginTabItem(self.ctx, "Flipper") then
			self:TAB_Flipper()
			ImGui.EndTabItem(self.ctx)
		end
		if ImGui.BeginTabItem(self.ctx, "VFX") then
			self:TAB_VFX()
			ImGui.EndTabItem(self.ctx)
		end
		if ImGui.BeginTabItem(self.ctx, "Helpers") then
			self:TAB_Helpers()
			ImGui.EndTabItem(self.ctx)
		end
		if ImGui.BeginTabItem(self.ctx, "FAQ") then
			self:TAB_FAQ()
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