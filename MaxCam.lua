local NAME, S = ...
local L = S.L

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local db

local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local BASE = 15
local MAX_RETAIL = 39
local MAX_CLASSIC = 50

local defaults = {
	increment = 4,
	speed = 20,
	distance = isRetail and 2.6 or 3.34,
	nearDistance = 5,
	nearIncrement = 1,
}

-- @param func		the prehooked function to call
-- @param increment	the increment in yards to zoom
local function CameraZoom(func, increment)
	-- anything not 1 could be a custom zoom increment from another addon
	if increment ~= 1 then
		func(increment)
	else
		local isCloseUp = GetCameraZoom() < db.nearDistance and db.increment > 1
		func(isCloseUp and db.nearIncrement or db.increment)
	end
end

local oldZoomIn = CameraZoomIn
local oldZoomOut = CameraZoomOut

function CameraZoomIn(v)
	CameraZoom(oldZoomIn, v)
end

function CameraZoomOut(v)
	CameraZoom(oldZoomOut, v)
end

local options = {
	type = "group",
	name = format("%s |cffADFF2F%s|r", NAME, GetAddOnMetadata(NAME, "Version")),
	args = {
		group1 = {
			type = "group", order = 1,
			name = " ",
			inline = true,
			args = {
				increment = {
					type = "range", order = 1,
					width = "double", descStyle = "",
					name = L.ZOOM_INCREMENT,
					get = function(i) return db.increment end,
					set = function(i, v) db.increment = v end,
					min = 1, max = 10, softMax = 5, step = .5,
				},
				spacing1 = {type = "description", order = 2, name = "\n"},
				speed = {
					type = "range", order = 3,
					width = "double", descStyle = "",
					name = L.ZOOM_SPEED,
					get = function(i) return tonumber(GetCVar("cameraZoomSpeed")) end,
					set = function(i, v)
						db.speed = v
						SetCVar("cameraZoomSpeed", db.speed)
					end,
					min = 1, max = 50, step = 1,
				},
				spacing2 = {type = "description", order = 4, name = "\n"},
				distance = {
					type = "range", order = 5,
					width = "double", desc = OPTION_TOOLTIP_MAX_FOLLOW_DIST,
					name = MAX_FOLLOW_DIST,
					get = function(i) return min(MAX_CLASSIC, GetCVar("cameraDistanceMaxZoomFactor") * BASE) end,
					set = function(i, v)
						db.distance = v / BASE
						SetCVar("cameraDistanceMaxZoomFactor", db.distance)
					end,
					min = BASE,
					max = isRetail and MAX_RETAIL or MAX_CLASSIC,
					step = isRetail and 1.5 or 1,
				},
			},
		},
		info = {
			type = "description", order = 2,
			name = function() return format(" %s = |cffADFF2F%.1f|r", L.CURRENT_DISTANCE, GetCameraZoom()) end,
			fontSize = "medium",
		},
	},
}

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == NAME then
		MaxCamDB = MaxCamDB or {}
		db = MaxCamDB
		for k, v in pairs(defaults) do
			if db[k] == nil then
				db[k] = v
			end
		end

		ACR:RegisterOptionsTable(NAME, options)
		ACD:AddToBlizOptions(NAME, NAME)
		ACD:SetDefaultSize(NAME, 420, 330)

		C_Timer.After(1, function()
			-- not actually necessary to override from savedvars
			-- but better to do this if other addons also set it
			SetCVar("cameraDistanceMaxZoomFactor", db.distance)
			SetCVar("cameraZoomSpeed", db.speed)
		end)

		self:UnregisterEvent(event)
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

local function UpdateDistanceACD() -- AceGUI distance
	ACR:NotifyChange(NAME) -- hide that initial flicker
	C_Timer.NewTicker(.3, function(self)
		if ACD.OpenFrames.MaxCam then
			if not ACD.OpenFrames.MaxCam.frame:IsMouseOver() and not GetCurrentKeyBoardFocus() then
				ACR:NotifyChange(NAME)
			end
		else
			self:Cancel()
		end
	end)
end

local PanelTicker

local function UpdateDistancePanel() -- InterfaceOptionsFrame distance
	local panel = InterfaceOptionsFramePanelContainer.displayedPanel
	if panel.name == NAME and not PanelTicker then
		PanelTicker = C_Timer.NewTicker(.3, function(self)
			if panel:IsVisible() and panel.name == NAME then
				if not panel:IsMouseOver() and not GetCurrentKeyBoardFocus() then
					panel:Hide()
					panel:Show() -- refresh
				end
			else
				self:Cancel()
				PanelTicker = nil
			end
		end)
	end
end

if not isRetail then
	hooksecurefunc("InterfaceOptionsList_DisplayPanel", UpdateDistancePanel) -- navigating to MaxCam panel
	InterfaceOptionsFrame:HookScript("OnShow", UpdateDistancePanel) -- opening straight to MaxCam panel
end

for i, v in pairs({"mc", "maxcam"}) do
	_G["SLASH_MAXCAM"..i] = "/"..v
end

function SlashCmdList.MAXCAM()
	if not ACD.OpenFrames.MaxCam then
		ACD:Open(NAME)
		UpdateDistanceACD()
	end
end

local dataobject = {
	type = "launcher",
	icon = "Interface\\Icons\\inv_misc_spyglass_03",
	text = NAME,
	OnClick = function()
		if ACD.OpenFrames.MaxCam then
			ACD:Close(NAME)
		else
			ACD:Open(NAME)
			UpdateDistanceACD()
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("|cffADFF2F"..NAME.."|r")
		tt:AddDoubleLine( MAX_FOLLOW_DIST, format("%.1f", GetCameraZoom()) )
	end,
}

LibStub("LibDataBroker-1.1"):NewDataObject(NAME, dataobject)
