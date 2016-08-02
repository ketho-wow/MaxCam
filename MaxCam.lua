-- License: Public Domain

local NAME, S = ...
local L = S.L

local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local db

local GetCameraZoom = GetCameraZoom
local target, isZoomIn

local defaults = {
	db_version = 1.0,
	increment = 4,
	speed = 2,
	distance = 50,
}

local options = {
	type = "group",
	name = format("%s |cffADFF2Fv%s|r", NAME, GetAddOnMetadata(NAME, "Version")),
	args = {
		group1 = {
			type = "group", order = 1,
			name = " ",	
			inline = true,
			get = function(i) return db[i[#i]] end,
			set = function(i,v) db[i[#i]] = v end,
			args = {
				increment = {
					type = "range", order = 1,
					width = "double", descStyle = "",
					name = L.ZOOM_INCREMENT,
					min = 1, max = 100, softMax = 10, step = .5,
				},
				spacing1 = {type = "description", order = 2, name = "\n"},
				speed = {
					type = "range", order = 3,
					width = "double", descStyle  = "",
					name = L.ZOOM_SPEED,
					min = 1, max = 50, softMax = 5, step = .5,
				},
				spacing2 = {type = "description", order = 4, name = "\n"},
				distance = {
					type = "range", order = 5,
					width = "double", desc = OPTION_TOOLTIP_MAX_FOLLOW_DIST,
					name = MAX_FOLLOW_DIST,
					min = 15, max = 1000, softMax = 50, step = 1,
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
		
		-- cameraDistanceMoveSpeed affects MoveView
		C_Timer.After(2, function()
			SetCVar("cameraDistanceMoveSpeed", GetCVarDefault("cameraDistanceMoveSpeed"))
		end)
		
		self:UnregisterEvent(event)
		self:SetScript("OnUpdate", f.CameraZoom)
		self:Hide()
	end
end

function f:CameraZoom() -- OnUpdate
	local zoom = GetCameraZoom()
	if (isZoomIn and (zoom<target or zoom==0)) or (not isZoomIn and zoom>target) then
		MoveViewInStop()
		self:Hide()
		if ACD.OpenFrames.MaxCam then
			ACR:NotifyChange(NAME) -- show current distance
		end
	end
end

function CameraZoomIn()
	target = min(GetCameraZoom()-db.increment, db.distance)
	MoveViewInStart(db.speed)
	isZoomIn = true
	f:Show()
end

function CameraZoomOut()
	target = min(GetCameraZoom()+db.increment, db.distance)
	MoveViewInStart(-db.speed) -- bug
	isZoomIn = false
	f:Show()
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)

for i, v in pairs({"mc", "maxcam"}) do
	_G["SLASH_MAXCAM"..i] = "/"..v
end

SlashCmdList.MAXCAM = function()
	ACD:Open(NAME)
end

local dataobject = {
	type = "launcher",
	icon = "Interface\\Icons\\inv_misc_spyglass_03",
	text = NAME,
	OnClick = function()
		ACD[ACD.OpenFrames.MaxCam and "Close" or "Open"](ACD, NAME)
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("|cffADFF2F"..NAME.."|r")
		tt:AddDoubleLine(MAX_FOLLOW_DIST, format("%.1f", GetCameraZoom()))
	end,
}

LibStub("LibDataBroker-1.1"):NewDataObject(NAME, dataobject)
