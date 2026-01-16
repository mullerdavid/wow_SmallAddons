--[[ Globals ]]--

LootHex_Addon = "LootHex"
SLASH_LootHex1 = "/lh"

--[[ SAVED VARIABLES ]]--

LootHex_Profile = nil

--[[ Snipe database ]]--

local vendors = {
    ["Qia"] = {
        ["Pattern: Runecloth Gloves"] = false,
        ["Pattern: Runecloth Bag"] = false,
    },
    ["Jandia"] = {
        ["Design: Pendant of the Agate Shield"] = false
    },
    ["Lhara"] = {
		["_gossip"] = 1,
        ["Mana Thistle"] = false,
        ["Fel Lotus"] = false,
        ["Netherbloom"] = false,
        ["Thick Clefthoof Leather"] = false,
        ["Heavy Knothide Leather"] = false,
        ["Black Lotus"] = false,
        ["Terocone"] = false,
        ["Nightmare Vine"] = false,
    },
    ["Professor Thaddeus Paleo"] = {
		["_gossip"] = 1,
        ["Living Ruby"] = false,
        ["Scroll of Agility V"] = false,
        ["Scroll of Strength V"] = false,	
        ["Scroll of Protection V"] = false,
        ["Mote of Air"] = false,
        ["Mote of Fire"] = false,
        ["Mote of Mana"] = false,
        ["Mote of Life"] = false,
        ["Mote of Shadow"] = false,
    },
    ["Field Repair Bot 110G"] = {
        ["Scroll of Agility V"] = true,
        ["Scroll of Strength V"] = true,	
    },
    ["Kulwia"] = {
        ["Formula: Enchant Cloak - Minor Agility"] = false,
        ["Formula: Enchant Bracer - Lesser Strength"] = false,	
    },
    ["Lorelae Wintersong"] = {
        ["Formula: Runed Arcanite Rod"] = false,
        ["Formula: Enchant Cloak - Superior Defense"] = false,	
    },
}

--[[ DeleteCursorItem Frame ]]--

local del = CreateFrame("Button", "LootHex_DeleteCursorItem")
del:SetScript("OnClick", function() DeleteCursorItem() ClearCursor() end)

--[[ Sooul Shard Helper ]]--

function LootHex_PickLastSoulShard(maxshards)
	maxshards = maxshards or 0
	local first = nil
	local n = 0
	ClearCursor()
	for bag=0,4 do 
		for slot=C_Container.GetContainerNumSlots(bag),1,-1 do 
			local id = C_Container.GetContainerItemID(bag,slot)
			if id==6265 then 
				n = n+1
				if first == nil then
					first = {bag, slot}
				end
				if maxshards < n then break end
			end
		end
		if maxshards < n then break end
	end
	if first and maxshards < n then
		local bag, slot = unpack(first)
		C_Container.PickupContainerItem(bag,slot)
	end
end

--[[ Event and command handling ]]--

local frame = CreateFrame("Frame")
local event_registered = false
local addon_loaded = false

local function LootHex_PrintState()
	if LootHex_Profile then
		local autoloot = GetCVar("autoLootDefault") == "1"
		if LootHex_Profile.AutoSnipe and autoloot then
			print("AutoLoot and AutoSnipe is turned on!")
		elseif LootHex_Profile.AutoSnipe then
			print("AutoSnipe is turned on!")
		elseif autoloot then
			print("AutoLoot is turned on!")
		end
	end
end

local function IsModifierDown(mod)
	if mod == "SHIFT" then return IsShiftKeyDown()
	elseif mod == "ALT" then return IsAltKeyDown()
	elseif mod == "CONTROL" then return IsControlKeyDown()
	end
	return false
end

local function LootHex_OnLootReady()
	local player = UnitName("player")
	local masterloot = C_PartyInfo.GetLootMethod() == "master"
	local modifier = IsModifierDown(GetModifiedClick("AUTOLOOTTOGGLE"))
	local autoloot = GetCVar("autoLootDefault") == "1"
	local inraid = IsInRaid()
	for i = GetNumLootItems(),1,-1
	do
		if (LootSlotHasItem(i)) 
		then
			local iteminfo = GetLootSlotLink(i);
			if (autoloot and not modifier)
			then
				local itemName, itemLink, itemQuality, itemLevel, _, _, _, itemStackCount = (function() if iteminfo then return GetItemInfo(iteminfo) end end)()
				local ITEM_QUALITY_LEGENDARY = 5
				local skip = false
				skip = skip or (inraid and itemQuality and ITEM_QUALITY_LEGENDARY <= itemQuality and itemStackCount and 1 < itemStackCount)
				if not skip
				then
					if (masterloot)
					then
						for ci = 1, 40 
						do
							if GetMasterLootCandidate(i, ci) == player
							then 
								GiveMasterLoot(i, ci)
								break 
							end
						end
					end
					if (LootSlotHasItem(i)) -- LootFrame.selectedItemName ??
					then
						LootSlot(i)
					end
					ConfirmLootSlot(i)
				end
			end
		else
			LootSlot(i)
		end
    end
end

local function LootHex_OnMerchantDialog()
	if not LootHex_Profile.AutoSnipe then return end
	if IsShiftKeyDown() then return end
	
	local target = UnitName("target")
    if not target then return end 
	
	local vendor = vendors[target]
    if not vendor then return end
	
	if vendor["_gossip"] then
		pcall(function() SelectGossipOption(vendor["_gossip"]) end)
	end
end

local function LootHex_OnMerchant()
	if not LootHex_Profile.AutoSnipe then return end
	if IsShiftKeyDown() then return end
	
	local target = UnitName("target")
    if not target then return end 
	
	local vendor = vendors[target]
    if not vendor then return end

    local numItems = GetMerchantNumItems()
    for i = numItems, 1, -1 do
        local name, _, _, _, numAvailable = GetMerchantItemInfo(i)
        if vendor[name] and numAvailable>0 then
            print("Buying: " .. name .. " x" .. numAvailable)
			for j = 1,numAvailable do
				pcall(function() BuyMerchantItem(i) end)
			end
        end
    end
    
    local count = 0
    frame:SetScript("OnUpdate", function(self)
        count = count + 1
        if count > 10 then
            CloseMerchant()
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function ProcessCommand(msg)
	local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
	if cmd
	then
		cmd = cmd:lower()
	end
	if cmd == "print"
	then
		LootHex_PrintState()
	elseif cmd == "autoloot" 
	then
		if (args=="on")
		then
			SetCVar("autoLootDefault", "1")
		else
			SetCVar("autoLootDefault", "0")
		end
		LootHex_PrintState()
	elseif cmd == "snipe" or cmd == "autosnipe" 
	then
		if (args=="on")
		then
			LootHex_Profile.AutoSnipe = true
		else
			LootHex_Profile.AutoSnipe = false
		end
		LootHex_PrintState()
	else
		print("Syntax: " .. SLASH_LootHex1 .. " ( print | autoloot on/off | snipe on/off )")
		print(SLASH_LootHex1 .. " ( print | autoloot on/off | snipe on/off )")
		print("/run LootHex_PickLastSoulShard(numshards)")
		print("/click LootHex_DeleteCursorItem")
		print("");
	end
end

local function Init()
	if (not addon_loaded)
	then
		addon_loaded = true
		LootHex_Profile = LootHex_Profile or {}
		LootHex_PrintState()
		SlashCmdList[LootHex_Addon] = ProcessCommand
	end
end

local function OnReadyCheck()
	SlackerCore.DoRecording("Ready Check")
end

local function OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == LootHex_Addon
	then
		Init()
    elseif event == "LOOT_READY" 
	then
        LootHex_OnLootReady()
    elseif event == "MERCHANT_SHOW" 
	then
        LootHex_OnMerchant()
    elseif event == "GOSSIP_SHOW" 
	then
        LootHex_OnMerchantDialog()
	end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("GOSSIP_SHOW")
frame:SetScript("OnEvent", OnEvent)



