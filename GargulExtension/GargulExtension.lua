local ADDON, T = ...
local L = {}

local GetContainerNumSlots = _G.GetContainerNumSlots or C_Container.GetContainerNumSlots
local GetContainerItemInfo = _G.GetContainerItemInfo or C_Container.GetContainerItemInfo

local GL = nil
local GargulDB = nil

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
