local addonName, ns = ...

local BADGE_PREFIX = "|cff00d1b2[Forever Exclusive]|r"

-- Default SavedVariables configuration
local defaults = {
    showItems = true,
    showNPCs = true,
    highlightVendors = true,
    highlightBags = true,
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

-- Helper: Apply or remove the teal glow + corner diamond on any item slot button
local function ApplyForeverSlotHighlight(button, isForever)
    if not button then return end

    if not button.ForeverGlow then
        local glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(0.0, 0.82, 0.70, 0.95) -- Signature Teal Glow
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        glow:SetSize((button:GetWidth() or 37) * 1.65, (button:GetHeight() or 37) * 1.65)
        glow:Hide()
        button.ForeverGlow = glow

        -- Small corner badge icon so it's readable even without hovering
        local badge = button:CreateTexture(nil, "OVERLAY", nil, 2)
        badge:SetTexture("Interface\\COMMON\\Indicator-Diamond")
        badge:SetVertexColor(0.0, 0.95, 0.82, 1.0)
        badge:SetSize(14, 14)
        badge:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        badge:Hide()
        button.ForeverCornerBadge = badge
    end

    button.ForeverGlow:SetShown(isForever)
    if button.ForeverCornerBadge then
        button.ForeverCornerBadge:SetShown(isForever)
    end
end

-- Initialize SavedVariables safely on login
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ForeverBadgeDB = ForeverBadgeDB or {}
        for k, v in pairs(defaults) do
            if ForeverBadgeDB[k] == nil then
                ForeverBadgeDB[k] = (type(v) == "table") and {} or v
            end
        end

        ns:RegisterSettings()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "BAG_UPDATE_DELAYED" then
        ns:UpdateAllBagHighlights()
    end
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
            local index = ((page - 1) * perPage) + i
            local isForever = false
            if ForeverBadgeDB and ForeverBadgeDB.highlightVendors and index <= numItems then
                local itemID = GetMerchantItemID(index)
                isForever = IsForeverItem(itemID)
            end
            ApplyForeverSlotHighlight(itemButton, isForever)
        end
    end
end

if MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", UpdateMerchantHighlights)
end

-- 4. Inventory / Bag Teal Border Highlighting (Combined Bags + Classic Individual Bags)
local function UpdateContainerFrame(frame)
    if not frame or not frame.EnumerateValidItems then return end
    local enabled = ForeverBadgeDB and ForeverBadgeDB.highlightBags

    for _, itemButton in frame:EnumerateValidItems() do
        local isForever = false
        if enabled then
            local bagID = itemButton:GetBagID()
            local slotID = itemButton:GetID()
            local itemID = C_Container.GetContainerItemID(bagID, slotID)
            isForever = IsForeverItem(itemID)
        end
        ApplyForeverSlotHighlight(itemButton, isForever)
    end
end

function ns:UpdateAllBagHighlights()
    -- Combined Backpack frame (modern UI)
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        UpdateContainerFrame(ContainerFrameCombinedBags)
    end

    -- Individual Bag frames (ContainerFrame1 .. ContainerFrame13)
    local maxBags = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
    for i = 1, maxBags + 8 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            UpdateContainerFrame(frame)
        end
    end
end

-- Hook Blizzard's native bag item update methods so highlights persist across opens/closes/moves
if ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function(self)
        UpdateContainerFrame(self)
    end)
end

for i = 1, 13 do
    local frame = _G["ContainerFrame" .. i]
    if frame and frame.UpdateItems then
        hooksecurefunc(frame, "UpdateItems", function(self)
            UpdateContainerFrame(self)
        end)
    end
end

-- 5. Copyable Export Frame (/fb export)
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

-- 6. Native Blizzard Settings Menu (Options > AddOns > Forever Badge)
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
    AddCheckbox("highlightBags", "Glow Forever Items in Bags", "Adds a teal border glow and corner marker to Forever items in your inventory.")
    AddCheckbox("highlightVendors", "Glow Forever Items at Vendors", "Adds a teal border glow to Forever-exclusive items inside merchant windows.")
    AddCheckbox("autoLogUnknowns", "Auto-Log Newly Discovered IDs", "Saves uncategorized high-ID Forever items and NPCs to your local database.")

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategoryID = category:GetID()
end

-- 7. Slash Commands (/fb, /fb export, /fb inspect, /fb stats)
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
