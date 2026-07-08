local ADDON, T = ...
local L = {}

local function Init()
	local frame = EnumerateFrames()
	while frame 
	do
		if frame.IsProtected and frame:IsProtected() and frame.GetObjectType and frame:GetObjectType() == "CheckButton" and frame.action and frame.Count and frame.Name
		then
			local name = frame:GetName()
			if string.find(name, "^ActionButton%d+$") or string.find(name, "^MultiBar()Button%d+$") or string.find(name, "^MultiBarBottomRightButton%d+$") or string.find(name, "^MultiBarLeftButton%d+$") or string.find(name, "^MultiBarRightButton%d+$")
			then
				local c = frame.Count
				local n = frame.Name
				hooksecurefunc(frame, "Update", function() if c:IsShown() and c:GetText() then n:Hide() end  end)
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
