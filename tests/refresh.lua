-- Run from the addon directory: lua5.1 tests/refresh.lua
-- WoW/Ace are boundary fixtures; this does not simulate rendering or game security.
local function newClient(projectID)
	local client = {timers = {}, after = {}, refreshes = 0, cvars = {}}
	local env = setmetatable({
		WOW_PROJECT_ID = projectID, WOW_PROJECT_MAINLINE = 1,
		SPEED = "Speed", MAX_FOLLOW_DIST = "Distance", OPTION_TOOLTIP_MAX_FOLLOW_DIST = "Distance",
		format = string.format, min = math.min, SlashCmdList = {},
	}, {__index = _G})
	env._G = env
	env.GetLocale = function() return "enUS" end
	env.GetCameraZoom = function() return 20 end
	env.GetCurrentKeyBoardFocus = function() return client.focus end
	env.CameraZoomIn = function(value) client.zoomIn = value end
	env.CameraZoomOut = function(value) client.zoomOut = value end
	env.C_AddOns = {GetAddOnMetadata = function() return "test" end}
	env.C_CVar = {
		GetCVar = function(name) return client.cvars[name] end,
		SetCVar = function(name, value) client.cvars[name] = tostring(value); return true end,
	}
	env.C_Timer = {
		After = function(_, callback) table.insert(client.after, callback) end,
		NewTicker = function(_, callback)
			local timer = {callback = callback}
			function timer:Cancel() self.cancelled = true end
			table.insert(client.timers, timer)
			return timer
		end,
	}
	env.CreateFrame = function()
		local frame = {scripts = {}, events = {}}
		function frame:RegisterEvent(event) self.events[event] = true end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:SetScript(event, callback) self.scripts[event] = callback end
		client.loader = frame
		return frame
	end
	local panel = {scripts = {}}
	function panel:HookScript(event, callback) self.scripts[event] = callback end
	function panel:IsMouseOver() return client.hover end
	function panel:Show()
		if not self.shown then
			self.shown = true
			self.scripts.OnShow(self)
		end
	end
	function panel:Hide()
		if self.shown then
			self.shown = false
			self.scripts.OnHide(self)
		end
	end
	local registry = {}
	function registry:RegisterOptionsTable(_, options) client.options = options end
	function registry:NotifyChange()
		client.refreshes = client.refreshes + 1
		client.distanceText = client.options.args.info.name()
	end
	local dialog = {OpenFrames = {}, closing = {}}
	function dialog:AddToBlizOptions() return panel end
	function dialog:SetDefaultSize(_, width, height) self.size = {width, height} end
	function dialog:Open(name)
		self.OpenFrames[name] = {frame = {IsMouseOver = function() return client.hover end}}
	end
	function dialog:Close(name) self.closing[name] = true end
	local broker = {}
	function broker:NewDataObject(_, object) client.broker = object end
	local libraries = {
		["AceConfigRegistry-3.0"] = registry,
		["AceConfigDialog-3.0"] = dialog,
		["LibDataBroker-1.1"] = broker,
	}
	env.LibStub = function(name) return assert(libraries[name], name) end
	local namespace = {}
	for _, path in ipairs({"Locales.lua", "MaxCam.lua"}) do
		setfenv(assert(loadfile(path)), env)("MaxCam", namespace)
	end
	client.loader.scripts.OnEvent(client.loader, "ADDON_LOADED", "MaxCam")
	for _, callback in ipairs(client.after) do callback() end
	-- AceConfigDialog closes on the next UI frame, before the 0.3-second ticker.
	function client:flushUI()
		for name in pairs(dialog.closing) do
			dialog.OpenFrames[name] = nil
			dialog.closing[name] = nil
		end
	end
	function client:tick()
		self.refreshes = 0
		for _, timer in ipairs(self.timers) do
			if not timer.cancelled then timer.callback(timer) end
		end
		return self.refreshes
	end
	client.env, client.panel = env, panel
	return client
end

for _, target in ipairs({{"Retail", 1}, {"Forever", 18}, {"Classic", 2}}) do
	local client = newClient(target[2])
	client.env.SlashCmdList.MAXCAM()
	for _ = 1, 5 do
		client.broker.OnClick()
		client:flushUI()
		client.broker.OnClick()
	end
	local refreshes = client:tick()
	assert(refreshes == 1, target[1] .. ": rapid close/reopen produced " .. refreshes .. " distance refreshes, expected 1")
	client.hover = true
	assert(client:tick() == 0, "Do not refresh while the mouse is over the window")
	client.hover, client.focus = false, {}
	assert(client:tick() == 0, "Do not refresh while an edit box has focus")
	client.focus = nil
	client.broker.OnClick()
	client:flushUI()
	assert(client:tick() == 0, "Closed windows must stop refreshing")
	client.env.SlashCmdList.MAXCAM()
	assert(client:tick() == 1, "A cancelled ticker must restart when reopening")
	client.broker.OnClick()
	client:flushUI()
	client:tick()

	for _ = 1, 5 do
		client.panel:Show()
		client.panel:Hide()
	end
	assert(client:tick() == 0, "Hidden Settings panels must stop refreshing")
	client.panel:Show()
	assert(client:tick() == 1, "Reopened Settings panels must refresh only once")
	client.panel:Hide()
	assert(client:tick() == 0, "Closing Settings must cancel its refresh")
	print("PASS: " .. target[1] .. " refresh lifecycle, rapid reopening and input focus")
end
