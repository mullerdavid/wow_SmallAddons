--[[ Globals ]]--

BossTimer_Addon = "BossTimer"

--[[ SAVED VARIABLES ]]--

--[[ Code ]]--

local addon_loaded = false

function SecondsToClock(seconds)
	local seconds = tonumber(seconds)
	if seconds <= 0 then
		return "00:00";
	else
		hours = string.format("%02.f", math.floor(seconds/3600));
		mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
		secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
		if hours ~= "00"
		then
			return hours..":"..mins..":"..secs
		else
			return mins..":"..secs
		end
	end
end

local start = 0
local timer = nil

function BossTimer_OnUpdate()
	if start ~= 0
	then
		BossTimerMiniMapFrame.Timer:SetText(SecondsToClock(difftime(time(), start)))
	end
end

local function StartTimer()
	BossTimerMiniMapFrame:Show()
	start = time()
end

local function StopTimer()
	BossTimerMiniMapFrame:Hide()
	start = 0
end

local function DBMCallback(event, mod)
	local name = "Unknown"
	local action = strsub(event, 5)
	if mod and mod["id"]
	then
		name = mod["id"]
	end
	if action == "Pull"
	then
		StartTimer()
	elseif action == "Wipe" or action == "Kill"
	then
		StopTimer()
	end
end

local function RegisterDBM()
	if (not dbm_loaded) and (DBM)
	then
		dbm_loaded = true
		DBM:RegisterCallback("DBM_Pull", DBMCallback)
		DBM:RegisterCallback("DBM_Wipe", DBMCallback)
		DBM:RegisterCallback("DBM_Kill", DBMCallback)
	end
end

local function Init()
	if (not addon_loaded)
	then
		addon_loaded = true
		RegisterDBM()
	end
end

local function OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == BossTimer_Addon
	then
		Init()
	elseif event == "ADDON_LOADED" and arg1 == "DBM-Core"
	then
		RegisterDBM()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
