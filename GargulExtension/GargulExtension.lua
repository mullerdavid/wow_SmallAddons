local ADDON, T = ...
local L = {}

local GetContainerNumSlots = _G.GetContainerNumSlots or C_Container.GetContainerNumSlots
local GetContainerItemInfo = _G.GetContainerItemInfo or C_Container.GetContainerItemInfo

local GL = nil
local GargulDB = nil
local RollerUI = { Window = nil }

local function GetCurrentHash()
	local DB = _G["GargulDB"]
	--DB.TMB.MetaData.hash
	if DB.TMB and DB.TMB.MetaData and DB.TMB.MetaData.importedAt
	then
		return DB.TMB.MetaData.importedAt
	end
end

local function TMBImport(self, data, triedToDecompress)
	local firstLine = data:match("[^\n]+")
	print()

	-- TMB Tooltip format
	if (GL:strStartsWith(strtrim(firstLine), 'type,raid_group_name,member_name,character_name')) then
		
		local datatable =  {
			["groups"] = { ["1"] = "Placeholder" },
			["loot"] = "",
			["notes"] = {},
			["tiers"] = {},
			["wishlists"] = {},
			["received"] = {},
			["stats"] = {},
		}
		
		local first = true
		for line in data:gmatch("[^\n]+") do
			-- Skip headers
			if (not first) then
				(function ()
					
					local CSVParts

					CSVParts = GL:explode(line, ",")

					-- We can't handle this line it seems
					if (not CSVParts[2] or CSVParts[1] ~= "wishlist") then
						return

					end
					
					local characterName = CSVParts[4]:lower()
					local order = CSVParts[9]
					local typ = GL.Data.Constants.tmbTypeWish -- tmbTypePrio
					local raidGroupID = CSVParts[2] or "1"
					local itemID = CSVParts[11]
					local received = CSVParts[14] ~= ""
					local offspec = CSVParts[12] == "1"
					
					if offspec
					then
						characterName = characterName .. "(OS)"
					end
					
					if (not itemID) then
						return

					end
					
					local key = received and "received" or "wishlists"
					
					local entry = table.concat({characterName, order, raidGroupID, typ}, "|")
					
					if not datatable[key][itemID]
					then
						datatable[key][itemID] = {}
					end
					table.insert(datatable[key][itemID], entry)
					
					if not datatable["stats"][characterName]
					then
						datatable["stats"][characterName] = { ["received"] = 0, ["wishlists"] = 0 }
					end
					datatable["stats"][characterName][key] = datatable["stats"][characterName][key] + 1
				end)()
			end
			first = false
		end
		
		local jsonEncodeSucceeded, WebsiteData = pcall(function () return GL.JSON:encode(datatable); end)

		if jsonEncodeSucceeded
		then
			local ret = L.TMBImportOriginal(self, WebsiteData, true)
			GargulDB.stats = datatable.stats
			GargulDB.hash = GetCurrentHash()
			return ret
		end
	end
	local ret = L.TMBImportOriginal(self, data, triedToDecompress)
	GargulDB.stats = nil
	GargulDB.hash = nil
	return ret
end

local function CountForItem(itemID)
	local count = 0

    for bag = 0, 10 do
        for slot = 1, GetContainerNumSlots(bag) do
            local _, itemCount, locked, _, _, _, _, _, _, bagItemID = GetContainerItemInfo(bag, slot)

            if (bagItemID == itemID
                and not locked -- The item is locked, aka it can not be put in the window
                and (GL:inventoryItemTradeTimeRemaining(bag, slot) > 0) -- The item is tradeable
            ) then
                count = count + itemCount
            end
        end
    end

    return count

end

local function LinkItem(itemLink)
	local itemID = GL:getItemIDFromLink(itemLink)
	local TMBInfo = GL.TMB:byItemLink(itemLink)
	
	if (GL:empty(TMBInfo)) then
		return
	end

	--if GargulDB.hash ~= GetCurrentHash() 
	--then
	--	print("Warning: DB mismatch, might be outdated import")
	--end
	
	local WishListEntries = {}
	local itemIsOnSomeonesWishlist = false
	for _, Entry in pairs(TMBInfo) do
		local playerName = GL:capitalize(Entry.character)
		local prio = Entry.prio
		local sortingOrder = prio
		local stats = GargulDB.stats and GargulDB.stats[Entry.character:lower()]
		stats = (stats and IsModifierKeyDown()) and string.format(" (%d/%d)", stats["received"], stats["wishlists"]+stats["received"]) or ""
		table.insert(WishListEntries, {sortingOrder, string.format("%s[%s]%s", playerName, prio, stats)})
		itemIsOnSomeonesWishlist = true

	end

	if itemIsOnSomeonesWishlist
	then
		local join = {}
		local count = CountForItem(itemID)
		table.sort(WishListEntries, function (a, b)
			return a[1] < b[1]

		end)

		for _, Entry in pairs(WishListEntries) do
			join[#join+1]=Entry[2]
		end
		if count > 1
		then
			itemLink = itemLink .. "x" .. count
		end
		local msg = itemLink .. " " .. table.concat(join, ", ")
		if #msg>250
		then
			msg = string.sub(msg,0,250)
		end
		GL:sendChatMessage(msg, "OFFICER", nil, nil, false, false)
	end
end


local function MasterLooterUIDraw(self, itemLink)
	local ret = L.MasterLooterUIDrawOriginal(self, itemLink)

    local ItemIcon = GL.Interface:get(self, "Icon.Item")
	if ItemIcon
	then
		ItemIcon:SetCallback("OnClick", function() 
			LinkItem(itemLink)
		end )
	end
				
	return ret
end

local function AwardDraw(self, itemLink)
	local ret = L.AwardDrawOriginal(self, itemLink)
	
    local ItemIcon = GL.Interface:get(self, "Icon.Item")
	if ItemIcon
	then
		ItemIcon:SetCallback("OnClick", function() 
			LinkItem(itemLink)
		end )
	end
				
	return ret
end

local function StartCooldownReopenMasterLooterUIButton()
	local Button = GL.Interface:get(GL.MasterLooterUI, "Frame.OpenMasterLooterButton")
	
	if Button
	then
		local ButtonCooldown = Button.Cooldown or CreateFrame("Cooldown", nil, Button, "CooldownFrameTemplate")
		ButtonCooldown:SetAllPoints()
		Button.Cooldown = ButtonCooldown
		
		if GL.RollOff.inProgress and GL.RollOff.CurrentRollOff.start and GL.RollOff.CurrentRollOff.time
		then
			ButtonCooldown:SetCooldown(GL.RollOff.CurrentRollOff.start, GL.RollOff.CurrentRollOff.time)
		end
	end
end

local function RollOffStart(self, CommMessage)
	local ret = L.RollOffStartOriginal(self, CommMessage)
	self.CurrentRollOff.start = GetTime()
	
	StartCooldownReopenMasterLooterUIButton()
	
	return ret
end

local function ReopenMasterLooterUIButtonDraw(self)
	local ret = L.ReopenMasterLooterUIButtonDrawOriginal(self)
	
	local Button = GL.Interface:get(self, "Frame.OpenMasterLooterButton")

	if Button
	then
		local ButtonOverlay = Button:CreateTexture(nil, "OVERLAY")
		ButtonOverlay:SetSize(16,16)
		ButtonOverlay:SetPoint("TOPRIGHT", 5, 5)
		ButtonOverlay:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
		Button.ButtonOverlay = ButtonOverlay
	end
	
	StartCooldownReopenMasterLooterUIButton()
	
	return ret
end

local function SendChatMessage(self, message, chatType, language, channel, stw, pretend)
	if message=="."
	then
		-- Source tampering check in Settings:_init(), checks if message=. chatType=SAY, stw=true starts with Gargul prefix
		return "{rt3} Gargul : "
	end
	if message == "Stop your rolls!"
	then
		chatType = GL.User.isInRaid and "RAID" or "PARTY"
	end
	local ret = L.SendChatMessageOriginal(self, message, chatType, language, channel, false, false)
	return ret
end

local function Empty()
end

local function ImporterDraw(self, ...)
	ret = L.ImporterDrawOriginal(self, ...)
	pcall(function () 
		print("ImporterDraw")
		local Window = self.InterfaceItems.Frame.Window
		local TMBBox = nil
		for _, child in ipairs(Window.children) do
			if child.type == "MultiLineEditBox" then
				TMBBox = child
			end
		end
		--TMBBox.editBox:SetMultiLine(False)
	end)
	return ret
end

local function Init()
	GL = _G["Gargul"]
	_G["GargulDBExtension"] = _G["GargulDBExtension"] or {}
	GargulDB = _G["GargulDBExtension"]
	-- Patching Importer UI
	-- L.ImporterDrawOriginal = GL.Interface.TMB.Importer.draw
	-- GL.Interface.TMB.Importer.draw = ImporterDraw
	-- Patching Import function
	L.TMBImportOriginal = GL.TMB.import
	GL.TMB.import = TMBImport
	-- Patching MasterLooterUI
	L.RollOffStartOriginal = GL.RollOff.start
	L.MasterLooterUIDrawOriginal = GL.MasterLooterUI.draw
	L.AwardDrawOriginal = GL.Interface.Award.draw
	L.ReopenMasterLooterUIButtonDrawOriginal = GL.MasterLooterUI.drawReopenMasterLooterUIButton
	GL.RollOff.start = RollOffStart
	GL.MasterLooterUI.draw = MasterLooterUIDraw
	GL.Interface.Award.draw = AwardDraw
	GL.MasterLooterUI.drawReopenMasterLooterUIButton = ReopenMasterLooterUIButtonDraw
	-- Patching Chat function
	L.SendChatMessageOriginal = GL.sendChatMessage
	GL.sendChatMessage = SendChatMessage
	-- Patching Conflicting Addon Message
	GL.announceConflictingAddons = Empty
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

function RollerUI:hide()
    GL:debug("RollerUI:hide")

    if (not self.Window) then
        return

    end

    self.Window:Hide()

    self.Window = nil

end
