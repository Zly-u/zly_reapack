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
DepsChecker:AddDepsToCheck(reaper.ImGui_Begin, "ReaImGui")
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
--local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

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

--[[===================================================]]--
--[[===================================================]]--
--[[===================================================]]--

local SCRIPT = {
	version = "0.0.0",
	name	= "[INSERT NAME HERE]",

	ctx = nil, -- ImGui context.
	timer = 0.0,

	UI_Data = {
		DEMO_progress = 0,
	},

	-------------------------------------------------------------------------------------------------------------------
	-- For File Browse Dialogs
	formats_string  = "",
	allowed_formats = {
		{"MP4 Files (.mp4)",	"*.mp4"},
		{"WEBM Files (.webm)",	"*.webm"},

		{"MP3 Files (.mp3)",	"*.mp3"},
		{"WAV Files (.wav)",	"*.wav"},

		{"All Files", "*.*"},
	},

	-------------------------------------------------------------------------------------------------------------------

	window_flags = ImGui.WindowFlags_None()
		| ImGui.WindowFlags_NoDocking()
		| ImGui.WindowFlags_NoResize()
		| ImGui.WindowFlags_NoCollapse()
		--| ImGui.WindowFlags_NoSavedSettings()
		| ImGui.WindowFlags_AlwaysAutoResize()
	, -- this lil fella is here so i can add and comment out flags at the end with ease, okay?

	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------

	-- Implementable Function
	Init = function(self) end,

	-- Implementable Function
	UpdateParams = function(self) end,

	-------------------------------------------------------------------------------------------------------------------

	-- Most likely won't change ever.
	LoopUI = function(self)
		ImGui.PushStyleVar(self.ctx, ImGui.StyleVar_WindowTitleAlign(), 0.5, 0.5)
		local window_visible, window_open = select(1, ImGui.Begin(self.ctx, self.name.." "..self.version, true, self.window_flags))

		ImGui.PopStyleVar(self.ctx)
		if window_visible then
			self:UpdateParams()
			self:DrawUI(self.ctx)

			ImGui.End(self.ctx)
		end

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

		ImGui.SetConfigVar(self.ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(),	1)
		ImGui.SetConfigVar(self.ctx, ImGui.ConfigVar_WindowsResizeFromEdges(),		1)

		reaper.defer(self:LoopUI_Wrapper())
	end,

	-------------------------------------------------------------------------------------------------------------------

	DrawUI = function(self) end, -- Implementable Function

}

-----------------------------------------------------------------------------------------------------------------------

function SCRIPT:Init()
	-- Init formats for File Browse Dialogs
	for _, format in pairs(self.allowed_formats) do
		self.formats_string = self.formats_string..format[1]..'\0'..format[2]..'\0'
	end

end

function SCRIPT:UpdateParams()
	self.timer = (self.timer + 1.0/33.0) % 1 -- [0, 1)

	self.UI_Data.DEMO_progress = 0.5 + math.sin(self.timer*math.pi*2) * 0.5
end

function SCRIPT:DrawUI()
	ImGui.Text(self.ctx, "Some Text.")
	ImGui.TextColored(
		self.ctx,
		hsl2rgb(60, 1, 0.8),
		"Some probably important text."
	)
	ImGui_InfoMarker(self.ctx, "It is important tho.\nYellow is a sign of warning, I guess.")

	ImGui.Separator(self.ctx)

	do -- Progress bar
		ImGui.PushStyleColor(self.ctx, ImGui.Col_PlotHistogram(), 0xE67A00FF)
		ImGui.PushStyleVar(self.ctx, ImGui.StyleVar_FrameBorderSize(), 1)

		ImGui.ProgressBar(self.ctx, self.UI_Data.DEMO_progress, 0, 0, ("%.1f/%d"):format(self.UI_Data.DEMO_progress * 33, 33))

		ImGui.PopStyleVar(self.ctx)
		ImGui.PopStyleColor(self.ctx)
	end
	ImGui_InfoMarker(self.ctx, "The window is 33FPS, sadly.")

	if ImGui.Button(self.ctx, "Dialog") then
		local retval, fileNames = JS.Dialog_BrowseForOpenFiles(
			"Source to use for Media Items",
			os.getenv("HOMEPATH") or "",
			"",
			self.formats_string,
			false
		)
	end

	ImGui.SameLine(self.ctx)

	if ImGui.Button(self.ctx, "Not Okay") then
	end
end

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

function main()
	SCRIPT:Init()
	SCRIPT:SetupWindow()
end

main()