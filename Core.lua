local addonName, ns = ...

local BADGE_PREFIX = "|cff00d1b2[Forever Exclusive]|r"

-- Default SavedVariables configuration
local defaults = {
    showItems = true,
    showNPCs = true,
    highlightVendors = true,
    autoLogUnknowns = true,
    discoveredItems = {},
    discoveredNPCs = {},
}

-- Helper: Check if an Item ID belongs to WoW: Forever
local function IsForeverItem(itemID)
    if not itemID then return false, nil end
    if ns.ForeverItems[itemID] then
        return true, ns.ForeverItems[itemID]
    elseif itemID >= ns.FOREVER_MIN_ITEM_ID then
        return true, "New Forever Content"
    end
    return false, nil
end

-- Helper: Extracts NPC ID from a Unit GUID
local function GetNPCIDFromGUID(guid)
    local isSecret = _G["issecretvalue"]
    if not guid or (isSecret and isSecret(guid)) then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end


-- Initialize SavedVariables safely on login
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    ForeverBadgeDB = ForeverBadgeDB or {}
    for k, v in pairs(defaults) do
        if ForeverBadgeDB[k] == nil then
            ForeverBadgeDB[k] = (type(v) == "table") and {} or v
        end
    end

    ns:RegisterSettings()
    self:UnregisterEvent("ADDON_LOADED")
end)

-- 1. Hook Item & Recipe Tooltips (Bags, Vendors, Loot, Chat Links, AH)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not ForeverBadgeDB or not ForeverBadgeDB.showItems then return end
    if not data or not data.id then return end

    local itemID = data.id
    local isForever, label = IsForeverItem(itemID)

    if isForever then
        if not ns.ForeverItems[itemID] and ForeverBadgeDB.autoLogUnknowns and not ForeverBadgeDB.discoveredItems[itemID] then
            local itemName = C_Item.GetItemNameByID(itemID) or "Unknown Item"
            ForeverBadgeDB.discoveredItems[itemID] = itemName
        end

        tooltip:AddLine(" ")
        tooltip:AddLine(BADGE_PREFIX .. " |cffffffff" .. label .. "|r")
        tooltip:Show()
    end
end)

-- 2. Hook Unit / NPC Mouseover Tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not ForeverBadgeDB or not ForeverBadgeDB.showNPCs then return end
    if not data or not data.guid then return end

    local npcID = GetNPCIDFromGUID(data.guid)
    if not npcID then return end

    local label = ns.ForeverNPCs[npcID]

    if not label and npcID >= ns.FOREVER_MIN_NPC_ID then
        label = "New Forever NPC"
        if ForeverBadgeDB.autoLogUnknowns and not ForeverBadgeDB.discoveredNPCs[npcID] then
            local unitName = UnitName("mouseover") or "Unknown NPC"
            ForeverBadgeDB.discoveredNPCs[npcID] = unitName
        end
    end

    if label then
        tooltip:AddLine(BADGE_PREFIX .. " |cffffffff" .. label .. "|r")
        tooltip:Show()
    end
end)

-- 3. Vendor Window Teal Border Highlighting
local function UpdateMerchantHighlights()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    local numItems = GetMerchantNumItems()
    local page = MerchantFrame.page or 1
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10

    for i = 1, perPage do
        local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
        if itemButton then
            if not itemButton.ForeverGlow then
                local glow = itemButton:CreateTexture(nil, "OVERLAY")
                glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                glow:SetBlendMode("ADD")
                glow:SetVertexColor(0.0, 0.82, 0.70, 0.95) -- Signature Teal Glow
                glow:SetPoint("CENTER", itemButton, "CENTER", 0, 0)
                glow:SetSize(itemButton:GetWidth() * 1.65, itemButton:GetHeight() * 1.65)
                glow:Hide()
                itemButton.ForeverGlow = glow
            end

            local index = ((page - 1) * perPage) + i
            if ForeverBadgeDB and ForeverBadgeDB.highlightVendors and index <= numItems then
                local itemID = GetMerchantItemID(index)
                local isForever = IsForeverItem(itemID)
                itemButton.ForeverGlow:SetShown(isForever)
            else
                itemButton.ForeverGlow:Hide()
            end
        end
    end
end

if MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", UpdateMerchantHighlights)
end

-- 4. Copyable Export Frame (/fb export)
local exportFrame
local function ShowExportWindow()
    if not exportFrame then
        exportFrame = CreateFrame("Frame", "ForeverBadgeExportFrame", UIParent, "BasicFrameTemplateWithInset")
        exportFrame:SetSize(460, 320)
        exportFrame:SetPoint("CENTER")
        exportFrame:SetMovable(true)
        exportFrame:EnableMouse(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
        exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)

        exportFrame.TitleText:SetText("Forever Badge - Discovered IDs (Ctrl+C to Copy)")

        local scroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -32)
        scroll:SetPoint("BOTTOMRIGHT", -32, 14)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(400)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
        scroll:SetScrollChild(editBox)
        exportFrame.editBox = editBox
    end

    local lines = { "-- Paste these directly into Data.lua:", "-- ITEMS:" }
    for id, name in pairs(ForeverBadgeDB.discoveredItems) do
        table.insert(lines, string.format('    [%d] = "Forever Exclusive", -- %s', id, name))
    end
    table.insert(lines, "\n-- NPCS:")
    for id, name in pairs(ForeverBadgeDB.discoveredNPCs) do
        table.insert(lines, string.format('    [%d] = "Forever NPC", -- %s', id, name))
    end

    exportFrame.editBox:SetText(table.concat(lines, "\n"))
    exportFrame:Show()
    exportFrame.editBox:HighlightText()
end

-- 5. Native Blizzard Settings Menu (Options > AddOns > Forever Badge)
function ns:RegisterSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local category = Settings.RegisterVerticalLayoutCategory("Forever Badge")

    local function AddCheckbox(variable, name, tooltipText)
        local setting = Settings.RegisterAddOnSetting(
            category,
            addonName .. "_" .. variable,
            variable,
            ForeverBadgeDB,
            Settings.VarType.Boolean,
            name,
            defaults[variable]
        )
        Settings.CreateCheckbox(category, setting, tooltipText)
    end

    AddCheckbox("showItems", "Show Badges on Forever Items", "Displays the Forever Exclusive tag on new items and recipes.")
    AddCheckbox("showNPCs", "Show Badges on Forever NPCs", "Displays the Forever Exclusive tag when mousing over new NPCs and vendors.")
    AddCheckbox("highlightVendors", "Glow Forever Items at Vendors", "Adds a teal border glow to Forever-exclusive items inside merchant windows.")
    AddCheckbox("autoLogUnknowns", "Auto-Log Newly Discovered IDs", "Saves uncategorized high-ID Forever items and NPCs to your local database.")

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategoryID = category:GetID()
end

-- 6. Slash Commands (/fb, /fb export, /fb inspect, /fb stats)
SLASH_FOREVERBADGE1 = "/fb"
SlashCmdList["FOREVERBADGE"] = function(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "export" then
        ShowExportWindow()
    elseif msg == "inspect" then
        local targetGUID = UnitGUID("target")
        local npcID = GetNPCIDFromGUID(targetGUID)
        if npcID then
            print(BADGE_PREFIX .. " Target NPC ID: |cffffff00" .. npcID .. "|r (" .. (UnitName("target") or "Unknown") .. ")")
        else
            print(BADGE_PREFIX .. " Target an NPC first, then type |cffffff00/fb inspect|r.")
        end
    elseif msg == "stats" then
        local itemCount, npcCount = 0, 0
        for _ in pairs(ForeverBadgeDB.discoveredItems) do itemCount = itemCount + 1 end
        for _ in pairs(ForeverBadgeDB.discoveredNPCs) do npcCount = npcCount + 1 end
        print(BADGE_PREFIX .. " Discovered so far: |cffffff00" .. itemCount .. "|r items, |cffffff00" .. npcCount .. "|r NPCs.")
    else
        if ns.settingsCategoryID and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.settingsCategoryID)
        else
            print(BADGE_PREFIX .. " Commands: |cffffff00/fb export|r | |cffffff00/fb inspect|r | |cffffff00/fb stats|r")
        end
    end
end
