local ADDON, T = ...
local L = {}

local function Init()
	local frame = EnumerateFrames()
	while frame 
	do
		if frame.IsProtected and frame:IsProtected() and frame.GetObjectType and frame:GetObjectType() == "CheckButton" and frame.action and frame.HotKey
		then
			local name = frame:GetName()
			if string.find(name, "^MultiBarBottomLeftButton%d+$") or string.find(name, "^MultiBarBottomRightButton%d+$") or string.find(name, "^MultiBarLeftButton%d+$") or string.find(name, "^MultiBarRightButton%d+$")
			then
				local hk = frame.HotKey
				hk:Hide()
				hooksecurefunc(frame.HotKey, "Show", function() hk:Hide() end)
			end
		end
		frame = EnumerateFrames(frame)
	end
end

local function OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON
	then
		self:UnregisterEvent("ADDON_LOADED")
		Init()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
