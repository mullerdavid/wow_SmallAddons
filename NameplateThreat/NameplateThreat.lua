local ADDON, T = ...
local L = {}

local ThreatStatusColors = {
    [0] = {0.69, 0.69, 0.69},
    [1] = {1, 1, 0.47},
    [2] = {1, 0.6, 0},
    [3] = {1, 0, 0},
}

function CreateThreatIndicator(unitframe)
    local frame = CreateFrame("Frame", nil, unitframe)
    frame:SetSize(35, 13)
    frame:SetPoint("LEFT", unitframe, "RIGHT", -6, -6.5)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bg:SetPoint("TOP", -0, -3)
    frame.bg:SetSize(27, 9)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.text:SetPoint("TOP", 0, -1.25)
    frame.text:SetText("0%")

    frame.border1 = frame:CreateTexture(nil, "ARTWORK")
    frame.border1:SetTexture("Interface\\TargetingFrame\\NumericThreatBorder")
    frame.border1:SetTexCoord(0, 0.765625, 0, 0.28125)
    frame.border1:SetPoint("TOPLEFT", frame ,"TOPLEFT", 0, 0)
    frame.border1:SetPoint("BOTTOMRIGHT", frame ,"RIGHT", 0, 0)

    frame.border2 = frame:CreateTexture(nil, "ARTWORK")
    frame.border2:SetTexture("Interface\\TargetingFrame\\NumericThreatBorder")
    frame.border2:SetTexCoord(0, 0.765625, 0.28125, 0)
    frame.border2:SetPoint("TOPLEFT", frame ,"LEFT", 0, 0)
    frame.border2:SetPoint("BOTTOMRIGHT", frame ,"BOTTOMRIGHT", 0, 0)

    return frame
end


local function UpdateThreatForPlate(self)
    local unit = self.unit
    if not unit or not UnitExists(unit) then
        if self.ThreatNumber then self.ThreatNumber:Hide() end
        return
    end

    local tanking, status, _, percent = UnitDetailedThreatSituation("player", unit)
    local r, g, b = unpack(ThreatStatusColors[status or 0])

    if tanking then
        percent = UnitThreatPercentageOfLead("player", unit) or 0
    end

    if percent and percent > 0 then
        if not self.ThreatNumber then
            local frame = CreateThreatIndicator(self)
            self.ThreatNumber = frame
        end

        self.ThreatNumber.bg:SetVertexColor(r, g, b)
        self.ThreatNumber.text:SetFormattedText("%.0f%%", percent)
        self.ThreatNumber:Show()
    else
        if self.ThreatNumber then
            self.ThreatNumber:Hide()
        end
    end
end

local function OnThreatEvent(self, event, unit)
    if unit and self.unit == unit then
        UpdateThreatForPlate(self)
    end
end

local function HookNameplate(frame)
    if frame._threatHooked then return end
    frame._threatHooked = true

    frame:HookScript("OnShow", function(self)
        UpdateThreatForPlate(self)
    end)

    frame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", frame.unit or "none")
    frame:SetScript("OnEvent", OnThreatEvent)
end

local function IsNameplateFrame(frame)
    local name = frame:GetName()
    if not name then return false end
    return name:match("NamePlate") or (frame.unit and frame.unit:match("^nameplate"))
end

local function ScanForNameplates()
    for _, frame in ipairs({ WorldFrame:GetChildren() }) do
        if IsNameplateFrame(frame) then
            HookNameplate(frame)
        end
    end
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        ScanForNameplates()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        local frame = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if frame then
            frame.unit = unit
            HookNameplate(frame)
            UpdateThreatForPlate(frame)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        local frame = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if frame and frame.ThreatNumber then
            frame.ThreatNumber:Hide()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ScanForNameplates()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

frame:SetScript("OnEvent", OnEvent)