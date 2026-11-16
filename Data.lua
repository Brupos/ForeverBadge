local addonName, ns = ...

-- Minimum ID thresholds where WoW: Forever custom content begins.
-- Anything at or above these numbers is flagged even if not explicitly listed below.
ns.FOREVER_MIN_ITEM_ID = 245000
ns.FOREVER_MIN_NPC_ID  = 210000

-- Curated Items & Recipes added in WoW: Forever
-- Format: [ItemID] = "Source or Category"
ns.ForeverItems = {
    -- Example entries (replace/expand with real Forever IDs)
    [250001] = "Forever Exclusive Item",
    [250002] = "Forever Exclusive Recipe",
}

-- Curated NPCs, Vendors, Trainers & Rare Spawns added in WoW: Forever
-- Format: [NPC_ID] = "Role or Tag"
ns.ForeverNPCs = {
    [213795] = "Forever Rare / Tamable", -- Gharrik (Badlands)
}
