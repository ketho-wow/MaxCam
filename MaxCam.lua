-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

if IsAddOnLoaded("FasterCamera") then
	print("MaxCam is FasterCamera, disabling MaxCam...")
	DisableAddOn("MaxCam")
	return
end

local NAME, S = ...
local L = S.L

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local db

-- anything bigger than 1 could be a custom zoom increment from another addon
-- @param func		the prehooked function to call
-- @param increment	the increment in yards to zoom
-- @param isCustom	whether another addon is passing a custom increment
local function CameraZoom(func, increment, isCustom)
	func(increment > 1 and increment or db.increment, isCustom)
end

local oldZoomIn = CameraZoomIn
local oldZoomOut = CameraZoomOut

function CameraZoomIn(v, b)
	CameraZoom(oldZoomIn, v, b)
end

function CameraZoomOut(v, b)
	CameraZoom(oldZoomOut, v, b)
end

-- multi-passenger mounts / quest vehicles
local oldVehicleZoomIn = VehicleCameraZoomIn
local oldVehicleZoomOut = VehicleCameraZoomOut

function VehicleCameraZoomIn(v, b)
	CameraZoom(oldVehicleZoomIn, v, b)
end

function VehicleCameraZoomOut(v, b)
	CameraZoom(oldVehicleZoomOut, v, b)
end

local base = 15
local maxfactor = 2.6

-- update the Blizzard slider from 1.9 to 2.6
CameraPanelOptions.cameraDistanceMaxFactor.maxValue = maxfactor

local defaults = {
	db_version = 2.1,
	increment = 4,
	speed = 20,
	distance = maxfactor,
}

local options = {
	type = "group",
	name = format("%s |cffADFF2Fv%s|r", NAME, GetAddOnMetadata(NAME, "Version")),
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
					get = function(i) return tonumber(GetCVar("cameraDistanceMoveSpeed")) end,
					set = function(i, v) SetCVar("cameraDistanceMoveSpeed", v); db.speed = v end,
					min = 1, max = 50, step = 1,
				},
				spacing2 = {type = "description", order = 4, name = "\n"},
				distance = {
					type = "range", order = 5,
					width = "double", desc = OPTION_TOOLTIP_MAX_FOLLOW_DIST,
					name = MAX_FOLLOW_DIST,
					get = function(i) return GetCVar("cameraDistanceMaxFactor") * base end,
					set = function(i, v) SetCVar("cameraDistanceMaxFactor", v / base); db.distance = v / base end,
					min = base, max = base * maxfactor, step = 1,
				},
			},
		},
		info = {
			type = "description", order = 2,
			name = function() return format(" %s = |cffADFF2F%.1f|r", L.DISTANCE, GetCameraZoom()) end,
			fontSize = "medium",
		},
	},
}

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == NAME then
		if not MaxCamDB or MaxCamDB.db_version < defaults.db_version then
			MaxCamDB = CopyTable(defaults)
		end
		db = MaxCamDB
		
		ACR:RegisterOptionsTable(NAME, options)
		ACD:AddToBlizOptions(NAME, NAME)
		ACD:SetDefaultSize(NAME, 420, 320)
		
		hooksecurefunc("BlizzardOptionsPanel_SetupControl", function(control)
			if control == InterfaceOptionsCameraPanelMaxDistanceSlider then
				SetCVar("cameraDistanceMaxFactor", db.distance)
				SetCVar("cameraDistanceMoveSpeed", db.speed)
			end
		end)
		
		InterfaceOptionsCameraPanelMaxDistanceSlider:HookScript("OnValueChanged", function(self, value)
			db.distance = value
		end)
		
		self:UnregisterEvent(event)
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

local function ShowDistance()
	ACR:NotifyChange(NAME) -- hide that initial flicker
	C_Timer.NewTicker(.5, function(self)
		if ACD.OpenFrames.MaxCam then
			if not ACD.OpenFrames.MaxCam.frame:IsMouseOver() and not GetCurrentKeyBoardFocus() then
				ACR:NotifyChange(NAME)
			end
		else
			self:Cancel()
		end
	end)
end

for i, v in pairs({"mc", "maxcam"}) do
	_G["SLASH_MAXCAM"..i] = "/"..v
end

function SlashCmdList.MAXCAM()
	if not ACD.OpenFrames.MaxCam  then
		ACD:Open(NAME)
		ShowDistance()
	end
end

local dataobject = {
	type = "launcher",
	icon = "Interface\\Icons\\inv_misc_spyglass_03",
	text = NAME,
	OnClick = function()
		if ACD.OpenFrames.MaxCam  then
			ACD:Close(NAME)
		else
			ACD:Open(NAME)
			ShowDistance()
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("|cffADFF2F"..NAME.."|r")
		tt:AddDoubleLine( MAX_FOLLOW_DIST, format("%.1f", GetCameraZoom()) )
	end,
}

LibStub("LibDataBroker-1.1"):NewDataObject(NAME, dataobject)
