local ADDON, T = ...
local L = {}

local GL = nil
local RollerUI = { Window = nil }

local function Init()
	GL = _G["Gargul"]
	-- Replacing RollerUI
	GL.RollerUI = RollerUI
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

------------------------------
-- RollerUI implementation ---
------------------------------


function RollerUI:show(time, itemLink, itemIcon, note, SupportedRolls)
    GL:debug("RollerUI:show")

    if (self.Window and self.Window:IsShown()) then
        return false

    end

    -- Make sure we can adjust the roller UI accordingly when a player can't use the item
    GL:canUserUseItem(itemLink, function (userCanUseItem)
        if (not userCanUseItem
            and GL.Settings:get("Rolling.dontShowOnUnusableItems", false)
        ) then
            return false

        end

        self:draw(time, itemLink, itemIcon, note, SupportedRolls, userCanUseItem)

    end)

    return true

end

function RollerUI:draw(time, itemLink, itemIcon, note, SupportedRolls, userCanUseItem)
    GL:debug("RollerUI:draw")

	local itemName = GL:getItemNameFromLink(itemLink)
	
	-- FrameXML\LootFrame.xml GroupLootFrameTemplate as base
	
    local Window = CreateFrame("Frame", "GargulUI_RollerUI_Window", UIParent, "BackdropTemplate")

    Window:Hide()

    Window:SetPoint(GL.Interface:getPosition("Roller"))

    Window:SetMovable(true)

    Window:EnableMouse(true)

    Window:SetClampedToScreen(true)

    Window:SetFrameStrata("DIALOG")

	-- toplevel="true"
    Window:SetSize(275, 84)

	Window:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background", 
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", 
		tile = true, 
		tileSize = 32, 
		edgeSize = 32, 
		insets = { left = 11, right = 12, top = 12, bottom = 11 } 
	})

    Window:RegisterForDrag("LeftButton")

    Window:SetScript("OnDragStart", Window.StartMoving)

    Window:SetScript("OnDragStop", function()
        Window:StopMovingOrSizing()

        GL.Interface:storePosition(Window, "Roller")

    end)

    Window:SetScript("OnMouseDown", function (_, button)
        -- Close the roll window on right-click
        if (button == "RightButton") then
            self:hide()

        end
    end)

    self.Window = Window

	Window.SlotTexture = Window:CreateTexture(nil, "ARTWORK")
	Window.SlotTexture:SetSize(64, 64)

	Window.SlotTexture:SetPoint("TOPLEFT", 3, -3)

	Window.SlotTexture:SetTexture("Interface\\Buttons\\UI-EmptySlot")

	Window.IconFrame = CreateFrame("Button", nil, Window)
    Window.IconFrame:EnableMouse(true)

	Window.IconFrame:SetSize(34, 34)

	Window.IconFrame:SetPoint("TOPLEFT", Window.SlotTexture, "TOPLEFT", 15, -15)

	Window.IconFrame:SetScript("OnEnter", 
		function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

			GameTooltip:SetHyperlink(itemLink)

			GameTooltip:Show()

			CursorUpdate(self)

		end)
	Window.IconFrame:SetScript("OnLeave", 
		function(self)
			GameTooltip:Hide()

			ResetCursor()

		end)
	Window.IconFrame:SetScript("OnUpdate", 
		function(self)
			if ( GameTooltip:IsOwned(self) ) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

				GameTooltip:SetHyperlink(itemLink)

			end
			CursorOnUpdate(self)

		end)
	Window.IconFrame:SetScript("OnClick", 
		function(self)
			HandleModifiedItemClick(itemLink)

		end)
	
	Window.IconFrame.Icon = Window.IconFrame:CreateTexture(nil, "ARTWORK")
	Window.IconFrame.Icon:SetSize(34, 34)

	Window.IconFrame.Icon:SetPoint("TOPLEFT")
	Window.IconFrame.Icon:SetTexture(itemIcon)

	Window.NameFrame = Window:CreateTexture(nil, "ARTWORK")
	Window.NameFrame:SetSize(128, 64)

	Window.NameFrame:SetPoint("LEFT", Window.SlotTexture, "RIGHT", -9, -10)

	Window.NameFrame:SetTexture("Interface\\MerchantFrame\\UI-Merchant-LabelSlots")

	Window.Name = Window:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Window.Name:SetText(itemName)

	Window.Name:SetJustifyH("LEFT")

	Window.Name:SetSize(90, 30)

	Window.Name:SetPoint("LEFT", Window.SlotTexture, "RIGHT", -5, 5)

	GL:onItemLoadDo(itemLink, 
		function(data) 
			local quality = data.quality or data[1].quality
			local color = ITEM_QUALITY_COLORS[quality]

			Window.Name:SetVertexColor(color.r, color.g, color.b)

		end)
	
	Window.Decoration = Window:CreateTexture(nil, "OVERLAY")
	Window.Decoration:SetSize(120, 120)

	Window.Decoration:SetPoint("TOPLEFT", -30, 15)

	Window.Decoration:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Dragon")

	Window.Corner = Window:CreateTexture(nil, "OVERLAY")
	Window.Corner:SetSize(32, 32)

	Window.Corner:SetPoint("TOPRIGHT", -9, -7)

	Window.Corner:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Corner")

	-- if not userCanUseItem disable buttons
	
    local RollButtons = {}

    local numberOfButtons = #SupportedRolls

	if numberOfButtons > 3
	then
		local h = Window:GetHeight()
		h = h + (numberOfButtons - 3) * 21
		Window:SetHeight(h)
	end

    for i = 1, numberOfButtons do
        local RollDetails = SupportedRolls[i] or {}

        local identifier = string.sub(RollDetails[1] or "", 1, 3)

        local min = math.floor(tonumber(RollDetails[2]) or 0)

        local max = math.floor(tonumber(RollDetails[3]) or 0)

        -- There are no more buttons to display
        if (GL:empty(identifier)) then
            break

        end

        -- Roll button
        local Button = CreateFrame("Button", nil, Window, "GameMenuButtonTemplate")

        Button:SetSize(66, 20)

        Button:SetText(identifier)

        Button:SetNormalFontObject("GameFontNormal")

        Button:SetHighlightFontObject("GameFontNormal")

        if (not userCanUseItem) then
            Button:Disable()

            Button:SetMotionScriptsWhileDisabled(true)

            -- Make sure rolling is still possible in case something was amiss!
            Button:SetScript("OnEnter", function()
                Button:Enable()

            end)

            Button:SetScript("OnLeave", function()
                Button:Disable()

            end)

        end

        Button:SetScript("OnClick", function ()
            RandomRoll(min, max)

            if (GL.Settings:get("Rolling.closeAfterRoll")) then
                self:hide()

            else
                local RollAcceptedNotification = GL.AceGUI:Create("InlineGroup")

                RollAcceptedNotification:SetLayout("Fill")

                RollAcceptedNotification:SetWidth(150)

                RollAcceptedNotification:SetHeight(50)

                RollAcceptedNotification.frame:SetParent(Window)

                RollAcceptedNotification.frame:SetPoint("BOTTOMLEFT", Window, "TOPLEFT", 14, 4)

                local Text = GL.AceGUI:Create("Label")

                Text:SetText("Roll accepted!")

                RollAcceptedNotification:AddChild(Text)

                Text:SetJustifyH("MIDDLE")

                self.RollAcceptedTimer = GL.Ace:ScheduleTimer(function ()
                    RollAcceptedNotification.frame:Hide()

                end, 2)

            end
        end)

        if (i == 1) then
            Button:SetPoint("TOPRIGHT", Window, "TOPRIGHT", -36, -10)

        else
            Button:SetPoint("TOPRIGHT", RollButtons[i - 1], "BOTTOMRIGHT", 0, -1)

        end

        tinsert(RollButtons, Button)

    end
	
	Window.RollButtons = RollButtons

    Window.PassButton = CreateFrame("Button", "GargulUI_RollerUI_Pass", Window, "UIPanelCloseButton")

    Window.PassButton:SetPoint("TOPRIGHT", Window, "TOPRIGHT", -5, -3)

    Window.PassButton:SetScript("OnClick", function ()
        self:hide()

    end)

    self:drawCountdownBar(time, itemLink, itemIcon, note, userCanUseItem)

    Window:Show()

end

function RollerUI:drawCountdownBar(time, itemLink, itemIcon, note, userCanUseItem)
    GL:debug("RollerUI:drawCountdownBar")

    -- This shouldn't be possible but you never know!
    if (not self.Window) then
        return false

    end
	
	local Window = self.Window
	
	Window.Timer = CreateFrame("StatusBar", nil, Window)
	Window.Timer:SetSize(152, 10)

	Window.Timer:SetPoint("TOPLEFT", Window.SlotTexture, "BOTTOMLEFT", 13, 10)

	Window.Timer:SetMinMaxValues(0, 60000)

	Window.Timer:SetValue(0)

	Window.Timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
	Window.Timer:SetStatusBarColor(1, 1, 0)

	Window.Timer.Bar = Window.Timer:GetStatusBarTexture()
	Window.Timer.Bar:SetDrawLayer("ARTWORK")
	
	Window.Timer.Background = Window.Timer:CreateTexture(nil, "BACKGROUND")
	Window.Timer.Background:SetAllPoints(Window.Timer)
	Window.Timer.Background:SetColorTexture(0, 0, 0)
	
	Window.Timer.Border = Window.Timer:CreateTexture(nil, "BORDER")
	Window.Timer.Border:SetSize(156, 20)

	Window.Timer.Border:SetPoint("TOP", 0, 5)

	Window.Timer.Border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")

	Window.Timer.start = GetTime()
	Window.Timer:SetMinMaxValues(0, time)


	Window.Timer:SetScript("OnUpdate", 
		function(self)
			local left = self.start and (GetTime()-self.start) or 0
			local min, max = self:GetMinMaxValues()
			if ( (left < min) or (left > max) ) then
				left = min
			end
			self:SetValue(max-left)
		end)
end

function RollerUI:createRollRow()
    GL:debug("RollerUI:createRollRow")
end

function RollerUI:fillRollRow()
    GL:debug("RollerUI:fillRollRow")
end

function RollerUI:fillGearWidgets()
    GL:debug("RollerUI:fillGearWidgets")
end

function RollerUI:drawRollTracker()
    GL:debug("RollerUI:drawRollTracker")
end

function RollerUI:positionRollTrackerControls()
    GL:debug("RollerUI:positionRollTrackerControls")
end

function RollerUI:refreshRollTracker()
    GL:debug("RollerUI:refreshRollTracker")
end

function RollerUI:toggleRollTracker()
    GL:debug("RollerUI:toggleRollTracker")
end

function RollerUI:toggleRollTracker()
    GL:debug("RollerUI:toggleRollTracker")
end

function RollerUI:scrollRollTracker()
    GL:debug("RollerUI:scrollRollTracker")
end

function RollerUI:showRollAcceptedNotification()
    GL:debug("RollerUI:showRollAcceptedNotification")
end

function RollerUI:rollOffStopped()
    GL:debug("RollerUI:rollOffStopped")
    self:hide();
end

function RollerUI:markRollOffEnded()
    GL:debug("RollerUI:markRollOffEnded")
    self:hide();
end

function RollerUI:reopen()
    GL:debug("RollerUI:reopen")
    self:hide();
end


function RollerUI:closeIfRollOffEnded()
    GL:debug("RollerUI:closeIfRollOffEnded")
    self:hide();
end

function RollerUI:hide()
    GL:debug("RollerUI:hide")

    if (not self.Window) then
        return

    end

    self.Window:Hide()

    self.Window = nil

end
