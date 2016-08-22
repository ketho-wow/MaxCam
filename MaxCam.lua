-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

local disable = {
	DynamicCam = "DynamicCam is more advanced",
	FasterCamera = "FasterCamera is MaxCam",
}

for k, v in pairs(disable) do
	if IsAddOnLoaded(k) then
		print(v..", disabling MaxCam...")
		DisableAddOn("MaxCam")
		return
	end
end

local NAME, S = ...
local L = S.L

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local db

-- anything bigger than 1 could be a custom zoom increment from another addon
-- @param func		the prehooked function to call
-- @param increment	the increment in yards to zoom
local function CameraZoom(func, increment)
	local isCloseUp = GetCameraZoom() < 4
	func(increment > 1 and increment or isCloseUp and 2 or db.increment)
end

local oldZoomIn = CameraZoomIn
local oldZoomOut = CameraZoomOut

function CameraZoomIn(v)
	CameraZoom(oldZoomIn, v)
end

function CameraZoomOut(v)
	CameraZoom(oldZoomOut, v)
end

-- multi-passenger mounts / quest vehicles
local oldVehicleZoomIn = VehicleCameraZoomIn
local oldVehicleZoomOut = VehicleCameraZoomOut

function VehicleCameraZoomIn(v)
	CameraZoom(oldVehicleZoomIn, v)
end

function VehicleCameraZoomOut(v)
	CameraZoom(oldVehicleZoomOut, v)
end

local base = 15
local maxfactor = 2.6

-- update the Blizzard slider from 1.9 to 2.6; also prevents clamping the cvar to 1.9
CameraPanelOptions.cameraDistanceMaxFactor.maxValue = maxfactor
InterfaceOptionsCameraPanelMaxDistanceSlider.Low:SetText(base) -- Near -> 15
InterfaceOptionsCameraPanelMaxDistanceSlider.High:SetText(base * maxfactor) -- Far -> 39

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
					set = function(i, v) db.speed = v; SetCVar("cameraDistanceMoveSpeed", v) end,
					min = 1, max = 50, step = 1,
				},
				spacing2 = {type = "description", order = 4, name = "\n"},
				distance = {
					type = "range", order = 5,
					width = "double", desc = OPTION_TOOLTIP_MAX_FOLLOW_DIST,
					name = MAX_FOLLOW_DIST,
					get = function(i) return GetCVar("cameraDistanceMaxFactor") * base end,
					set = function(i, v)
						local value = v / base
						db.distance = value
						SetCVar("cameraDistanceMaxFactor", value)
						-- when using the Blizzard Options window
						if InterfaceOptionsFrame:IsShown() then
							InterfaceOptionsCameraPanelMaxDistanceSlider:SetValue(value)
						end
					end,
					min = base, max = base * maxfactor, step = 1.5, -- cameraDistanceMaxFactor gets rounded to 1 decimal
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
		
		C_Timer.After(1, function()
			-- not actually necessary to override from savedvars
			-- but better to do this if other addons also set it
			SetCVar("cameraDistanceMaxFactor", db.distance)
			SetCVar("cameraDistanceMoveSpeed", db.speed)
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
