local addonName, ns = ...

-- Default SavedVariables configuration
local defaults = {
    showItems = true,
    showNPCs = true,
    highlightVendors = true,
    highlightBags = true,
    showDialogBadges = true,
    compactTooltips = true,
    useInfinitySymbol = false,
    previewMode = false,
    autoLogUnknowns = true,
    badgeColor = { r = 0.0, g = 0.82, b = 0.70 }, -- Default Teal (#00d1b2)
    discoveredItems = {},
    discoveredNPCs = {},
}

-- Helper: Get formatted hex color string from SavedVariables
local function GetBadgeHex()
    local c = (ForeverBadgeDB and ForeverBadgeDB.badgeColor) or defaults.badgeColor
    return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

local function GetBadgePrefix()
    local label = (ForeverBadgeDB and ForeverBadgeDB.useInfinitySymbol) and "[∞ Forever]" or "[Forever Exclusive]"
    return GetBadgeHex() .. label .. "|r"
end

-- Helper: Check if an Item ID belongs to WoW: Forever
local function IsForeverItem(itemID)
    if not itemID then return false, nil end
    if ForeverBadgeDB and ForeverBadgeDB.previewMode then
        return true, "Preview Mode"
    end
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

-- Helper: Check if an NPC ID belongs to WoW: Forever
local function IsForeverNPC(npcID)
    if not npcID then return false, nil end
    if ForeverBadgeDB and ForeverBadgeDB.previewMode then
        return true, "Preview Mode"
    end
    if ns.ForeverNPCs[npcID] then
        return true, ns.ForeverNPCs[npcID]
    elseif npcID >= ns.FOREVER_MIN_NPC_ID then
        return true, "New Forever NPC"
    end
    return false, nil
end

-- Helper: Apply or remove the clean colored border glow on any item slot button (No corner icon)
local function ApplyForeverSlotHighlight(button, isForever)
    if not button then return end
    local c = (ForeverBadgeDB and ForeverBadgeDB.badgeColor) or defaults.badgeColor

    if not button.ForeverGlowFrame then
        local glowFrame = CreateFrame("Frame", nil, button)
        glowFrame:SetAllPoints(button)
        glowFrame:SetFrameLevel((button:GetFrameLevel() or 1) + 5)

        local glow = glowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", glowFrame, "CENTER", 0, 0)
        glow:SetSize((button:GetWidth() or 37) * 1.65, (button:GetHeight() or 37) * 1.65)
        glowFrame.glow = glow
        glowFrame:Hide()

        button.ForeverGlowFrame = glowFrame
    end

    button.ForeverGlowFrame.glow:SetVertexColor(c.r, c.g, c.b, 1.0)
    button.ForeverGlowFrame:SetShown(isForever)
end

-- Initialize SavedVariables safely on login
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_PROGRESS")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            ForeverBadgeDB = ForeverBadgeDB or {}
            for k, v in pairs(defaults) do
                if ForeverBadgeDB[k] == nil then
                    if type(v) == "table" then
                        ForeverBadgeDB[k] = CopyTable(v)
                    else
                        ForeverBadgeDB[k] = v
                    end
                end
            end
            ns:RegisterSettings()
            ns:InitBaganatorSupport()
        elseif arg1 == "Baganator" then
            ns:InitBaganatorSupport()
        end
    elseif event == "PLAYER_LOGIN" then
        ns:InitBaganatorSupport()
        ns:EnsureBaganatorCornerActive()
    elseif event == "BAG_UPDATE_DELAYED" then
        ns:UpdateAllBagHighlights()
    elseif event == "GOSSIP_SHOW" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        ns:UpdateDialogBadge()
    end
end)

-- 1. Hook Item & Recipe Tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not ForeverBadgeDB or not ForeverBadgeDB.showItems then return end
    if not data or not data.id then return end

    local itemID = data.id
    local isForever, label = IsForeverItem(itemID)

    if isForever then
        if not ForeverBadgeDB.previewMode and not ns.ForeverItems[itemID] and ForeverBadgeDB.autoLogUnknowns and not ForeverBadgeDB.discoveredItems[itemID] then
            local itemName = C_Item.GetItemNameByID(itemID) or "Unknown Item"
            ForeverBadgeDB.discoveredItems[itemID] = itemName
        end

        if not ForeverBadgeDB.compactTooltips then
            tooltip:AddLine(" ")
        end
        tooltip:AddLine(GetBadgePrefix() .. " |cffffffff" .. label .. "|r")
        tooltip:Show()
    end
end)

-- 2. Hook Unit / NPC Mouseover Tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not ForeverBadgeDB or not ForeverBadgeDB.showNPCs then return end
    if not data or not data.guid then return end

    local npcID = GetNPCIDFromGUID(data.guid)
    if not npcID then return end

    local isForever, label = IsForeverNPC(npcID)

    if isForever then
        if not ForeverBadgeDB.previewMode and not ns.ForeverNPCs[npcID] and ForeverBadgeDB.autoLogUnknowns and not ForeverBadgeDB.discoveredNPCs[npcID] then
            local unitName = UnitName("mouseover") or "Unknown NPC"
            ForeverBadgeDB.discoveredNPCs[npcID] = unitName
        end

        tooltip:AddLine(GetBadgePrefix() .. " |cffffffff" .. label .. "|r")
        tooltip:Show()
    end
end)

-- 3. NPC Gossip & Quest Dialog Header Badge
function ns:UpdateDialogBadge()
    if not ForeverBadgeDB or not ForeverBadgeDB.showDialogBadges then return end

    local npcGUID = UnitGUID("npc")
    local npcID = GetNPCIDFromGUID(npcGUID)
    local isForever = IsForeverNPC(npcID)
    if not isForever then return end

    local tag = GetBadgeHex() .. (ForeverBadgeDB.useInfinitySymbol and "[∞] |r" or "[Forever] |r")

    if GossipFrame and GossipFrame:IsShown() and GossipFrameTitleText then
        local text = GossipFrameTitleText:GetText()
        if text and not text:find("%[Forever%]") and not text:find("%[∞%]") then
            GossipFrameTitleText:SetText(tag .. text)
        end
    end

    if QuestFrame and QuestFrame:IsShown() and QuestFrameTitleText then
        local text = QuestFrameTitleText:GetText()
        if text and not text:find("%[Forever%]") and not text:find("%[∞%]") then
            QuestFrameTitleText:SetText(tag .. text)
        end
    end
end

-- 4. Vendor Window Border Highlighting
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

-- 5. Inventory / Bag Border Highlighting (Blizzard Bags + Baganator)
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
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        UpdateContainerFrame(ContainerFrameCombinedBags)
    end

    local maxBags = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
    for i = 1, maxBags + 8 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            UpdateContainerFrame(frame)
        end
    end

    local baganator = _G["Baganator"]
    if baganator and baganator.API and baganator.API.RequestItemButtonsRefresh then
        baganator.API.RequestItemButtonsRefresh()
    end

    UpdateMerchantHighlights()
end

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

-- Ensure Baganator places "forever_badge" in top_left even on existing user profiles
function ns:EnsureBaganatorCornerActive()
    local baganator = _G["Baganator"]
    if not baganator or not baganator.Config or not baganator.Config.Get then return end

    local corners = baganator.Config.Get("icon_corners")
    if type(corners) == "table" then
        local alreadyPlaced = false
        for _, list in pairs(corners) do
            if type(list) == "table" then
                for _, id in ipairs(list) do
                    if id == "forever_badge" then
                        alreadyPlaced = true
                        break
                    end
                end
            end
        end
        if not alreadyPlaced then
            corners.top_left = corners.top_left or {}
            table.insert(corners.top_left, 1, "forever_badge")
            if baganator.API and baganator.API.RequestItemButtonsRefresh then
                baganator.API.RequestItemButtonsRefresh()
            end
        end
    end
end

-- Baganator Border-Only Integration (No corner diamond icon)
local baganatorRegistered = false
function ns:InitBaganatorSupport()
    if baganatorRegistered then return end
    local baganator = _G["Baganator"]
    if baganator and baganator.API and baganator.API.RegisterCornerWidget then
        baganatorRegistered = true
        baganator.API.RegisterCornerWidget("Forever Badge", "forever_badge",
            function(cornerFrame, details)
                local enabled = ForeverBadgeDB and ForeverBadgeDB.highlightBags
                local isForever = enabled and IsForeverItem(details and details.itemID)
                local btn = cornerFrame.parentButton
                if btn then
                    ApplyForeverSlotHighlight(btn, isForever)
                end
                return isForever
            end,
            function(itemButton)
                local frame = CreateFrame("Frame", nil, itemButton)
                frame:SetSize(1, 1)
                frame.parentButton = itemButton

                itemButton:HookScript("OnHide", function(self)
                    if self.ForeverGlowFrame then
                        self.ForeverGlowFrame:Hide()
                    end
                end)

                return frame
            end,
            { corner = "top_left", priority = 2 }
        )
    end
end

-- 6. Copyable Export Frame (/fb export)
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

-- 7. Color Picker Helper (/fb color or Settings button)
local function OpenHighlightColorPicker()
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
    local c = ForeverBadgeDB.badgeColor or defaults.badgeColor

    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        ForeverBadgeDB.badgeColor = { r = newR, g = newG, b = newB }
        ns:UpdateAllBagHighlights()
    end

    local function OnCancel(previousValues)
        if previousValues then
            ForeverBadgeDB.badgeColor = { r = previousValues.r, g = previousValues.g, b = previousValues.b }
            ns:UpdateAllBagHighlights()
        end
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = c.r,
        g = c.g,
        b = c.b,
        swatchFunc = OnColorChanged,
        cancelFunc = OnCancel,
    })
end

-- 8. Native Blizzard Settings Menu (Options > AddOns > Forever Badge)
function ns:RegisterSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Forever Badge")

    local function AddCheckbox(variable, name, tooltipText, onValueChanged)
        local setting = Settings.RegisterAddOnSetting(
            category,
            addonName .. "_" .. variable,
            variable,
            ForeverBadgeDB,
            Settings.VarType.Boolean,
            name,
            defaults[variable]
        )
        if onValueChanged then
            setting:SetValueChangedCallback(onValueChanged)
        end
        Settings.CreateCheckbox(category, setting, tooltipText)
    end

    AddCheckbox("showItems", "Show Badges on Forever Items", "Displays the Forever Exclusive tag on new items and recipes.")
    AddCheckbox("showNPCs", "Show Badges on Forever NPCs", "Displays the Forever Exclusive tag when mousing over new NPCs and vendors.")
    AddCheckbox("showDialogBadges", "Show [Forever] Tag in NPC Dialogs", "Adds a [Forever] badge to quest and gossip window titles for new NPCs.")
    AddCheckbox("highlightBags", "Glow Forever Items in Bags", "Adds a colored border glow to Forever items in your bags (including Baganator).", function() ns:UpdateAllBagHighlights() end)
    AddCheckbox("highlightVendors", "Glow Forever Items at Vendors", "Adds a colored border glow to Forever-exclusive items inside merchant windows.", function() ns:UpdateAllBagHighlights() end)
    AddCheckbox("useInfinitySymbol", "Use Compact [∞ Forever] Symbol", "Replaces [Forever Exclusive] with the shorter [∞ Forever] icon tag.")
    AddCheckbox("compactTooltips", "Compact Tooltip Line (No Extra Space)", "Keeps the tooltip tag on a single compact line without an extra blank spacer.")
    AddCheckbox("autoLogUnknowns", "Auto-Log Newly Discovered IDs", "Saves uncategorized high-ID Forever items and NPCs to your local database.")
    AddCheckbox("previewMode", "Preview Mode (Highlight Everything)", "Temporarily highlights all items so you can test colors and appearance.", function() ns:UpdateAllBagHighlights() end)

    if CreateSettingsButtonInitializer and layout then
        local colorBtn = CreateSettingsButtonInitializer(
            "Highlight & Badge Color",
            "Pick Color",
            OpenHighlightColorPicker,
            "Choose a custom color for bag borders, vendor highlights, and tooltip badges.",
            true
        )
        layout:AddInitializer(colorBtn)
    end

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategoryID = category:GetID()
end

-- 9. Slash Commands (/fb, /fb color, /fb preview, /fb status, /fb export, /fb inspect, /fb stats)
SLASH_FOREVERBADGE1 = "/fb"
SlashCmdList["FOREVERBADGE"] = function(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "color" then
        OpenHighlightColorPicker()
    elseif msg == "preview" then
        ForeverBadgeDB.previewMode = not ForeverBadgeDB.previewMode
        ns:UpdateAllBagHighlights()
        print(GetBadgePrefix() .. " Preview Mode: " .. (ForeverBadgeDB.previewMode and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
    elseif msg == "status" then
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"
        print(GetBadgePrefix() .. " v" .. version .. " | Item Cutoff: >= " .. ns.FOREVER_MIN_ITEM_ID .. " | NPC Cutoff: >= " .. ns.FOREVER_MIN_NPC_ID .. " | Baganator: " .. (baganatorRegistered and "|cff00ff00Hooked|r" or "|cffaaaaaaNot Installed|r"))
    elseif msg == "export" then
        ShowExportWindow()
    elseif msg == "inspect" then
        local targetGUID = UnitGUID("target")
        local npcID = GetNPCIDFromGUID(targetGUID)
        if npcID then
            print(GetBadgePrefix() .. " Target NPC ID: |cffffff00" .. npcID .. "|r (" .. (UnitName("target") or "Unknown") .. ")")
        else
            print(GetBadgePrefix() .. " Target an NPC first, then type |cffffff00/fb inspect|r.")
        end
    elseif msg == "stats" then
        local itemCount, npcCount = 0, 0
        for _ in pairs(ForeverBadgeDB.discoveredItems) do itemCount = itemCount + 1 end
        for _ in pairs(ForeverBadgeDB.discoveredNPCs) do npcCount = npcCount + 1 end
        print(GetBadgePrefix() .. " Discovered so far: |cffffff00" .. itemCount .. "|r items, |cffffff00" .. npcCount .. "|r NPCs.")
    else
        if ns.settingsCategoryID and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.settingsCategoryID)
        else
            print(GetBadgePrefix() .. " Commands: |cffffff00/fb color|r | |cffffff00/fb preview|r | |cffffff00/fb status|r | |cffffff00/fb export|r | |cffffff00/fb inspect|r")
        end
    end
end
