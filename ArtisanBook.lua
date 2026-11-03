-- ============================================================================
-- ArtisanBook.lua
-- Primary/Secondary Bottom Tabs, 10 Scaled Side Tabs, Back Button, and
-- "/artisan open" Spellbook-Style Profession Overview for Vanilla 1.12 / Turtle WoW
-- ============================================================================

local MAX_TABS = 10
local SIDE_TAB_SCALE = 0.80
local SIDE_TAB_GAP = -6

-- ClassicAPI Fast-Path Wrappers with Safe 1.12 Fallbacks
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook

local function CheckSpellKnown(spellID)
    if not spellID then return false end
    if _G.IsSpellKnown and IsSpellKnown(spellID) then return true end
    if _G.IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then return true end
    return false
end

local function SafeGetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" and info.name then
            return info.name, info.iconID
        elseif type(info) == "string" then
            local name, _, icon = C_Spell.GetSpellInfo(spellID)
            return name, icon
        end
    end
    if _G.GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellID)
        if name then return name, icon end
    end
    return nil, nil
end

local function SafeGetSpellTexture(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then return tex end
    end
    local _, icon = SafeGetSpellName(spellID)
    return icon
end

-- Find a spell in the player's 1.12 Spellbook by localized name
-- Returns: spellBookSlot, iconTexture, rankSubtext
local spellBookCache = {}
local function ScanSpellBookCache()
    for k in pairs(spellBookCache) do spellBookCache[k] = nil end
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
        -- Keep highest rank slot encountered
        spellBookCache[strlower(name)] = {
            slot = i,
            name = name,
            rank = rank or "",
            icon = tex,
        }
        i = i + 1
    end
end

-- Scan Character SkillLines (Preserves collapsed header states)
local skillLineCacheByName = {}
local skillLineCacheByID = {}
local function ScanCharacterSkills()
    for k in pairs(skillLineCacheByName) do skillLineCacheByName[k] = nil end
    for k in pairs(skillLineCacheByID) do skillLineCacheByID[k] = nil end

    -- Expand collapsed headers temporarily only if needed, then restore in reverse
    local collapsedHeaders = {}
    local numSkills = GetNumSkillLines()
    for i = numSkills, 1, -1 do
        local skillName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then
            collapsedHeaders[skillName] = true
            ExpandSkillHeader(i)
        end
    end

    local total = GetNumSkillLines()
    for i = 1, total do
        local skillName, isHeader, _, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(i)
        if skillName and not isHeader then
            local entry = {
                name = skillName,
                rank = skillRank or 0,
                modifier = (skillModifier or 0) + (numTempPoints or 0),
                maxRank = skillMaxRank or 0,
            }
            skillLineCacheByName[strlower(skillName)] = entry
        end
    end

    -- Restore any headers the player had collapsed
    for i = GetNumSkillLines(), 1, -1 do
        local skillName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and isExpanded and collapsedHeaders[skillName] then
            CollapseSkillHeader(i)
        end
    end
end

-- ============================================================================
-- Profession Definitions (Vanilla 1.12 + Turtle WoW)
-- ============================================================================
-- category: 1 = Primary, 2 = Secondary / Class
-- canOpenWindow: true = shows on ArtisanFrame right-side tabs & clickable in Overview
--                false = passive tracker only in Overview, hidden from right-side tabs

local PROFESSIONS = {
    -- =========================
    -- PRIMARY PROFESSIONS (1)
    -- =========================
    {
        key = "ALCHEMY",
        category = 1,
        skillLineID = 171,
        defaultName = "Alchemy",
        castSpellName = "Alchemy",
        spellIDs = { 11611, 3464, 3101, 2259 },
        icon = "Interface\\Icons\\Trade_Alchemy",
        canOpenWindow = true,
    },
    {
        key = "BLACKSMITHING",
        category = 1,
        skillLineID = 164,
        defaultName = "Blacksmithing",
        castSpellName = "Blacksmithing",
        spellIDs = { 9785, 3538, 3100, 2018 },
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        canOpenWindow = true,
        -- Checked in priority order: Masteries first, then Weaponsmith/Armorsmith
        specs = {
            { spellID = 17039, name = "Master Swordsmith" },
            { spellID = 17040, name = "Master Axesmith" },
            { spellID = 17041, name = "Master Hammersmith" },
            { spellID = 9787,  name = "Weaponsmith" },
            { spellID = 9788,  name = "Armorsmith" },
        },
    },
    {
        key = "ENCHANTING",
        category = 1,
        skillLineID = 333,
        defaultName = "Enchanting",
        castSpellName = "Enchanting",
        spellIDs = { 13920, 7413, 7412, 7411 },
        icon = "Interface\\Icons\\Trade_Engraving",
        canOpenWindow = true,
    },
    {
        key = "ENGINEERING",
        category = 1,
        skillLineID = 202,
        defaultName = "Engineering",
        castSpellName = "Engineering",
        spellIDs = { 12656, 4038, 4037, 4036 },
        icon = "Interface\\Icons\\Trade_Engineering",
        canOpenWindow = true,
        specs = {
            { spellID = 20219, name = "Gnomish Engineer" },
            { spellID = 20222, name = "Goblin Engineer" },
        },
    },
    {
        key = "JEWELCRAFTING",
        category = 1,
        skillLineID = 755,
        defaultName = "Jewelcrafting",
        altNames = { "Jewelcrafting", "Goldsmithing" },
        castSpellName = "Jewelcrafting",
        spellIDs = { 25229, 25230, 28894, 28895, 28897 },
        icon = "Interface\\Icons\\INV_Misc_Gem_01",
        canOpenWindow = true,
    },
    {
        key = "LEATHERWORKING",
        category = 1,
        skillLineID = 165,
        defaultName = "Leatherworking",
        castSpellName = "Leatherworking",
        spellIDs = { 10662, 3811, 3104, 2108 },
        icon = "Interface\\Icons\\INV_Misc_ArmorKit_17",
        canOpenWindow = true,
        specs = {
            { spellID = 10656, name = "Dragonscale Leatherworking" },
            { spellID = 10658, name = "Elemental Leatherworking" },
            { spellID = 10660, name = "Tribal Leatherworking" },
        },
    },
    {
        key = "TAILORING",
        category = 1,
        skillLineID = 197,
        defaultName = "Tailoring",
        castSpellName = "Tailoring",
        spellIDs = { 12180, 3910, 3909, 3908 },
        icon = "Interface\\Icons\\Trade_Tailoring",
        canOpenWindow = true,
    },
    {
        -- Displays "Mining" skill bar in Overview, but opens "Smelting" window!
        key = "MINING",
        category = 1,
        skillLineID = 186,
        defaultName = "Mining",
        castSpellName = "Smelting",
        spellIDs = { 2656 },
        icon = "Interface\\Icons\\Trade_Mining",
        canOpenWindow = true,
    },
    {
        -- Passive tracker only in Overview, hidden from right-side tabs
        key = "HERBALISM",
        category = 1,
        skillLineID = 182,
        defaultName = "Herbalism",
        castSpellName = nil,
        spellIDs = { 2383 },
        icon = "Interface\\Icons\\Trade_Herbalism",
        canOpenWindow = false,
    },
    {
        -- Passive tracker only in Overview, hidden from right-side tabs
        key = "SKINNING",
        category = 1,
        skillLineID = 393,
        defaultName = "Skinning",
        castSpellName = nil,
        spellIDs = { 8613, 8617, 8618, 10768 },
        icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        canOpenWindow = false,
    },

    -- =========================
    -- SECONDARY & CLASS (2)
    -- =========================
    {
        key = "COOKING",
        category = 2,
        skillLineID = 185,
        defaultName = "Cooking",
        castSpellName = "Cooking",
        spellIDs = { 18260, 3413, 3102, 2550 },
        icon = "Interface\\Icons\\INV_Misc_Food_15",
        canOpenWindow = true,
    },
    {
        key = "FIRSTAID",
        category = 2,
        skillLineID = 129,
        defaultName = "First Aid",
        castSpellName = "First Aid",
        spellIDs = { 10846, 7924, 3274, 3273 },
        icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
        canOpenWindow = true,
    },
    {
        key = "SURVIVAL",
        category = 2,
        skillLineID = 142,
        defaultName = "Survival",
        altNames = { "Survival" },
        castSpellName = "Survival",
        spellIDs = {},
        icon = "Interface\\Icons\\Spell_Fire_Fire",
        canOpenWindow = true,
    },
    {
        -- Passive tracker only in Overview, hidden from right-side tabs
        key = "FISHING",
        category = 2,
        skillLineID = 356,
        defaultName = "Fishing",
        castSpellName = nil,
        spellIDs = { 18248, 7732, 7731, 7620 },
        icon = "Interface\\Icons\\Trade_Fishing",
        canOpenWindow = false,
    },
    {
        key = "POISONS",
        category = 2,
        skillLineID = 40,
        defaultName = "Poisons",
        castSpellName = "Poisons",
        spellIDs = { 2842 },
        icon = "Interface\\Icons\\Trade_BrewPoison",
        canOpenWindow = true,
    },
    {
        -- Hunter Beast Training (CraftFrame hook)
        key = "BEASTTRAINING",
        category = 2,
        skillLineID = nil,
        defaultName = "Beast Training",
        castSpellName = "Beast Training",
        spellIDs = { 5149 },
        icon = "Interface\\Icons\\Ability_Hunter_BeastCall02",
        canOpenWindow = true,
        noSkillBar = true,
    },
    {
        -- Passive tracker in Overview for Rogue Lockpicking
        key = "LOCKPICKING",
        category = 2,
        skillLineID = 633,
        defaultName = "Lockpicking",
        castSpellName = nil,
        spellIDs = { 1804 },
        icon = "Interface\\Icons\\Spell_Nature_MoonKey",
        canOpenWindow = false,
    },
}

-- Derive training rank label from maxRank if subtext is empty
local function GetRankTitleFromMax(maxRank)
    if not maxRank or maxRank <= 0 then return "" end
    if maxRank <= 75 then
        return "Apprentice"
    elseif maxRank <= 150 then
        return "Journeyman"
    elseif maxRank <= 225 then
        return "Expert"
    else
        return "Artisan"
    end
end

-- Check if the player knows a specialization for this profession
local function GetSpecializationTitle(profDef)
    if not profDef.specs then return nil end
    for _, spec in ipairs(profDef.specs) do
        if CheckSpellKnown(spec.spellID) then
            local locName = SafeGetSpellName(spec.spellID)
            return locName or spec.name
        end
        -- Fallback check in spellbook cache by name
        local cached = spellBookCache[strlower(spec.name)]
        if cached then
            return cached.name
        end
    end
    return nil
end

-- Resolve live player data for a single profession definition
local function ResolveProfessionData(profDef)
    -- 1. Determine localized skill name
    local skillName = profDef.defaultName
    if profDef.skillLineID and C_SpellBook and C_SpellBook.GetSkillLineName then
        local dbcName = C_SpellBook.GetSkillLineName(profDef.skillLineID)
        if dbcName and dbcName ~= "" then
            skillName = dbcName
        end
    end

    -- 2. Look up rank/maxRank/modifier via ClassicAPI first, then Character Skills cache
    local curRank, maxRank, modifier
    if profDef.skillLineID and C_SpellBook and C_SpellBook.GetSkillLineRank then
        local r, m, mod = C_SpellBook.GetSkillLineRank(profDef.skillLineID)
        if r and m and m > 0 then
            curRank, maxRank, modifier = r, m, mod or 0
        end
    end

    if not curRank then
        local skillEntry = skillLineCacheByName[strlower(skillName)]
        if not skillEntry and profDef.altNames then
            for _, alt in ipairs(profDef.altNames) do
                skillEntry = skillLineCacheByName[strlower(alt)]
                if skillEntry then
                    skillName = skillEntry.name
                    break
                end
            end
        end
        if skillEntry then
            curRank = skillEntry.rank
            maxRank = skillEntry.maxRank
            modifier = skillEntry.modifier
        end
    end

    -- 3. Check spellbook for the crafting spell & icon
    local castName = profDef.castSpellName or skillName
    local sbEntry = spellBookCache[strlower(castName)]
    if not sbEntry and profDef.spellIDs then
        for _, id in ipairs(profDef.spellIDs) do
            if CheckSpellKnown(id) then
                local sName, sIcon = SafeGetSpellName(id)
                if sName then
                    sbEntry = spellBookCache[strlower(sName)] or {
                        name = sName,
                        icon = sIcon or SafeGetSpellTexture(id),
                        rank = "",
                    }
                    break
                end
            end
        end
    end

    -- Special case for Beast Training (no skill bar in SkillFrame, learned as spell)
    if profDef.noSkillBar then
        if not sbEntry and not CheckSpellKnown(5149) then
            return nil
        end
        return {
            def = profDef,
            name = (sbEntry and sbEntry.name) or skillName,
            castSpell = (sbEntry and sbEntry.name) or castName,
            icon = (sbEntry and sbEntry.icon) or profDef.icon,
            subTitle = (sbEntry and sbEntry.rank ~= "" and sbEntry.rank) or "Class Skill",
            rank = 0,
            maxRank = 0,
            modifier = 0,
            noSkillBar = true,
            canOpenWindow = profDef.canOpenWindow,
        }
    end

    -- If neither skill line nor spell is known, player doesn't have this profession
    if not curRank or maxRank == 0 then
        return nil
    end

    -- If this is a crafting profession (e.g., Mining -> Smelting), verify the craft spell is known
    local canOpen = profDef.canOpenWindow
    if canOpen and not sbEntry then
        -- Player might have learned Mining but not Smelting yet, or Survival without recipe book
        canOpen = false
    end

    -- 4. Resolve subtitle: Specialization overrides Training Rank
    local specTitle = GetSpecializationTitle(profDef)
    local subTitle = specTitle
    if not subTitle or subTitle == "" then
        if sbEntry and sbEntry.rank and sbEntry.rank ~= "" then
            subTitle = sbEntry.rank
        else
            subTitle = GetRankTitleFromMax(maxRank)
        end
    end

    local iconTexture = (sbEntry and sbEntry.icon) or profDef.icon

    return {
        def = profDef,
        name = skillName,
        castSpell = (sbEntry and sbEntry.name) or castName,
        icon = iconTexture,
        subTitle = subTitle or "",
        rank = curRank,
        maxRank = maxRank,
        modifier = modifier or 0,
        noSkillBar = false,
        canOpenWindow = canOpen,
    }
end

-- State tables
local ArtisanMod = {
    activeBottomTab = 1, -- 1 = Primary, 2 = Secondary (on ArtisanFrame)
    bookBottomTab = 1,   -- 1 = Primary, 2 = Secondary (on ArtisanBookFrame)
    primaryAll = {},     -- All learned Primary professions (for Overview)
    secondaryAll = {},   -- All learned Secondary/Class professions (for Overview)
    primaryTabs = {},    -- Window-opening Primary professions (for right-side tabs)
    secondaryTabs = {},  -- Window-opening Secondary professions (for right-side tabs)
    sideTabs = {},
    bookButtons = {},
}

local function RefreshProfessionLists()
    ScanSpellBookCache()
    ScanCharacterSkills()

    for k in pairs(ArtisanMod.primaryAll) do ArtisanMod.primaryAll[k] = nil end
    for k in pairs(ArtisanMod.secondaryAll) do ArtisanMod.secondaryAll[k] = nil end
    for k in pairs(ArtisanMod.primaryTabs) do ArtisanMod.primaryTabs[k] = nil end
    for k in pairs(ArtisanMod.secondaryTabs) do ArtisanMod.secondaryTabs[k] = nil end

    for _, profDef in ipairs(PROFESSIONS) do
        local data = ResolveProfessionData(profDef)
        if data then
            if profDef.category == 1 then
                if table.getn(ArtisanMod.primaryAll) < MAX_TABS then
                    table.insert(ArtisanMod.primaryAll, data)
                end
                if data.canOpenWindow and table.getn(ArtisanMod.primaryTabs) < MAX_TABS then
                    table.insert(ArtisanMod.primaryTabs, data)
                end
            else
                if table.getn(ArtisanMod.secondaryAll) < MAX_TABS then
                    table.insert(ArtisanMod.secondaryAll, data)
                end
                if data.canOpenWindow and table.getn(ArtisanMod.secondaryTabs) < MAX_TABS then
                    table.insert(ArtisanMod.secondaryTabs, data)
                end
            end
        end
    end
end

-- Helper to get currently open TradeSkill or Craft name
local function GetCurrentlyOpenSkillName()
    if GetTradeSkillLine then
        local name = GetTradeSkillLine()
        if name and name ~= "UNKNOWN" and name ~= "" then
            return name
        end
    end
    if GetCraftDisplaySkillLine then
        local name = GetCraftDisplaySkillLine()
        if name and name ~= "UNKNOWN" and name ~= "" then
            return name
        end
    end
    if GetCraftName then
        local name = GetCraftName()
        if name and name ~= "UNKNOWN" and name ~= "" then
            return name
        end
    end
    return nil
end

-- Sync screen position between Overview (ArtisanBookFrame) and ArtisanFrame
local function SyncWindowPosition(sourceFrame, targetFrame)
    if not sourceFrame or not targetFrame then return end
    local left = sourceFrame:GetLeft()
    local top = sourceFrame:GetTop()
    if left and top then
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

-- ============================================================================
-- Part 1 & 2: ArtisanFrame Bottom Tabs, 10 Scaled Right-Side Tabs & Back Arrow
-- ============================================================================

-- Hide any built-in side tabs that original Artisan created so they don't overlap
local function HideOriginalArtisanSideTabs()
    if not ArtisanFrame then return end
    local prefixes = {
        "ArtisanFrameTab",
        "ArtisanTab",
        "ArtisanSkillTab",
        "ArtisanFrameSideTab",
    }
    for _, prefix in ipairs(prefixes) do
        for i = 1, 16 do
            local f = _G[prefix .. i]
            if f and f ~= ArtisanMod.bottomTab1 and f ~= ArtisanMod.bottomTab2 then
                f:Hide()
                f:SetScript("OnShow", function() this:Hide() end)
            end
        end
    end
    -- Also inspect unnamed/child CheckButtons anchored to TOPRIGHT of ArtisanFrame
    local children = { ArtisanFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child ~= ArtisanMod.bottomTab1 and child ~= ArtisanMod.bottomTab2 and not child.isArtisanCustomSideTab then
            local objType = child:GetObjectType()
            if objType == "CheckButton" then
                local point, _, relPoint = child:GetPoint(1)
                if point == "TOPLEFT" and relPoint == "TOPRIGHT" then
                    child:Hide()
                    child:SetScript("OnShow", function() this:Hide() end)
                end
            end
        end
    end
end

local function UpdateArtisanSideTabs()
    if not ArtisanFrame then return end
    HideOriginalArtisanSideTabs()

    local list = (ArtisanMod.activeBottomTab == 1) and ArtisanMod.primaryTabs or ArtisanMod.secondaryTabs
    local activeSkill = GetCurrentlyOpenSkillName()
    local activeLower = activeSkill and strlower(activeSkill) or nil

    for i = 1, MAX_TABS do
        local tab = ArtisanMod.sideTabs[i]
        local data = list[i]
        if tab then
            -- Keep identical scale across Primary and Secondary
            tab:SetScale(SIDE_TAB_SCALE)
            if data then
                tab.profData = data
                tab:SetNormalTexture(data.icon)
                local isCurrent = false
                if activeLower then
                    if strlower(data.name) == activeLower or strlower(data.castSpell) == activeLower then
                        isCurrent = true
                    end
                end
                tab:SetChecked(isCurrent and 1 or nil)
                tab:Show()
            else
                tab.profData = nil
                tab:SetChecked(nil)
                tab:Hide()
            end
        end
    end
end

local function SetArtisanBottomTab(tabID)
    ArtisanMod.activeBottomTab = tabID
    if ArtisanFrame and ArtisanFrame.numTabs then
        PanelTemplates_SetTab(ArtisanFrame, tabID)
    end
    UpdateArtisanSideTabs()
end

-- Auto-detect whether the newly opened profession belongs to Primary or Secondary
local function AutoSyncBottomTabToOpenSkill()
    RefreshProfessionLists()
    local activeSkill = GetCurrentlyOpenSkillName()
    if activeSkill then
        local activeLower = strlower(activeSkill)
        for _, data in ipairs(ArtisanMod.primaryTabs) do
            if strlower(data.name) == activeLower or strlower(data.castSpell) == activeLower then
                ArtisanMod.activeBottomTab = 1
                break
            end
        end
        for _, data in ipairs(ArtisanMod.secondaryTabs) do
            if strlower(data.name) == activeLower or strlower(data.castSpell) == activeLower then
                ArtisanMod.activeBottomTab = 2
                break
            end
        end
    end
    SetArtisanBottomTab(ArtisanMod.activeBottomTab)
end

local function SetupArtisanFrameEnhancements()
    if not ArtisanFrame or ArtisanMod.isArtisanEnhanced then return end
    ArtisanMod.isArtisanEnhanced = true

    -- 1. Create Bottom Tabs (Primary & Secondary) using stock CharacterFrameTabButtonTemplate
    local tab1 = CreateFrame("Button", "ArtisanFrameBottomTab1", ArtisanFrame, "CharacterFrameTabButtonTemplate")
    tab1:SetID(1)
    tab1:SetText("Primary")
    tab1:SetPoint("TOPLEFT", ArtisanFrame, "BOTTOMLEFT", 11, 2)
    tab1:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        SetArtisanBottomTab(1)
    end)

    local tab2 = CreateFrame("Button", "ArtisanFrameBottomTab2", ArtisanFrame, "CharacterFrameTabButtonTemplate")
    tab2:SetID(2)
    tab2:SetText("Secondary")
    tab2:SetPoint("LEFT", tab1, "RIGHT", -15, 0)
    tab2:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        SetArtisanBottomTab(2)
    end)

    ArtisanMod.bottomTab1 = tab1
    ArtisanMod.bottomTab2 = tab2

    -- Register with Blizzard PanelTemplates so stock UI and pfUI Nostalgia skin them properly
    _G["ArtisanFrameTab1"] = tab1
    _G["ArtisanFrameTab2"] = tab2
    PanelTemplates_SetNumTabs(ArtisanFrame, 2)
    PanelTemplates_SetTab(ArtisanFrame, 1)

    -- 2. Create 10 Scaled Right-Side Tabs aligned flush to ArtisanFrame's right side
    for i = 1, MAX_TABS do
        local sideTab = CreateFrame("CheckButton", "ArtisanCustomSideTab" .. i, ArtisanFrame, "SpellBookSkillLineTabTemplate")
        sideTab.isArtisanCustomSideTab = true
        sideTab:SetID(i)
        sideTab:SetScale(SIDE_TAB_SCALE)
        sideTab:ClearAllPoints()

        if i == 1 then
            -- Flush against the right edge of ArtisanFrame
            sideTab:SetPoint("TOPLEFT", ArtisanFrame, "TOPRIGHT", 0, -36)
        else
            sideTab:SetPoint("TOPLEFT", ArtisanMod.sideTabs[i - 1], "BOTTOMLEFT", 0, SIDE_TAB_GAP)
        end

        sideTab:SetScript("OnEnter", function()
            if this.profData then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(this.profData.name, 1.0, 1.0, 1.0)
                if not this.profData.noSkillBar and this.profData.maxRank > 0 then
                    if this.profData.modifier > 0 then
                        GameTooltip:AddLine(format("%d (+%d) / %d", this.profData.rank, this.profData.modifier, this.profData.maxRank), 0.8, 0.8, 0.8)
                    else
                        GameTooltip:AddLine(format("%d / %d", this.profData.rank, this.profData.maxRank), 0.8, 0.8, 0.8)
                    end
                end
                GameTooltip:Show()
            end
        end)

        sideTab:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        sideTab:SetScript("OnClick", function()
            if this.profData and this.profData.castSpell then
                local activeSkill = GetCurrentlyOpenSkillName()
                if activeSkill and (strlower(activeSkill) == strlower(this.profData.name) or strlower(activeSkill) == strlower(this.profData.castSpell)) then
                    this:SetChecked(1)
                    return
                end
                PlaySound("igAbiliityPageTurn")
                CastSpellByName(this.profData.castSpell)
            end
        end)

        ArtisanMod.sideTabs[i] = sideTab
    end

    -- 3. Replace the Top-Right "X" Close Button with a Back Arrow to return to Overview
    local closeBtn = _G["ArtisanFrameCloseButton"]
    if not closeBtn then
        -- Locate the close button among children if unnamed
        local children = { ArtisanFrame:GetChildren() }
        for _, child in ipairs(children) do
            if child:GetObjectType() == "Button" then
                local norm = child:GetNormalTexture()
                if norm and norm:GetTexture() and strfind(strlower(norm:GetTexture()), "uipanel-minimizebutton") then
                    closeBtn = child
                    break
                end
            end
        end
    end

    if closeBtn then
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        closeBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        closeBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        closeBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Back to Professions Overview", 1.0, 1.0, 1.0)
            GameTooltip:Show()
        end)
        closeBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        closeBtn:SetScript("OnClick", function()
            PlaySound("igSpellBookClose")
            if ArtisanBookFrame then
                SyncWindowPosition(ArtisanFrame, ArtisanBookFrame)
                ArtisanMod.bookBottomTab = ArtisanMod.activeBottomTab
            end
            CloseTradeSkill()
            CloseCraft()
            if ArtisanFrame:IsShown() then
                HideUIPanel(ArtisanFrame)
            end
            ArtisanMod.OpenOverviewWindow()
        end)
    end

    -- Hook OnShow of ArtisanFrame to sync tabs & close Overview window seamlessly
    local origOnShow = ArtisanFrame:GetScript("OnShow")
    ArtisanFrame:SetScript("OnShow", function()
        if origOnShow then origOnShow() end
        if ArtisanBookFrame and ArtisanBookFrame:IsShown() then
            SyncWindowPosition(ArtisanBookFrame, ArtisanFrame)
            ArtisanBookFrame:Hide()
        end
        AutoSyncBottomTabToOpenSkill()
    end)

    -- Apply pfUI Nostalgia skinning hooks if pfUI is active
    if _G.pfUI and pfUI.api and pfUI.api.SkinTab then
        pfUI.api.SkinTab(tab1)
        pfUI.api.SkinTab(tab2)
    end
end

-- ============================================================================
-- Part 3: "/artisan open" Spellbook-Style Overview Window (ArtisanBookFrame)
-- ============================================================================

local function UpdateBookWindow()
    if not ArtisanBookFrame or not ArtisanBookFrame:IsShown() then return end

    RefreshProfessionLists()
    PanelTemplates_SetTab(ArtisanBookFrame, ArtisanMod.bookBottomTab)

    local list = (ArtisanMod.bookBottomTab == 1) and ArtisanMod.primaryAll or ArtisanMod.secondaryAll

    for i = 1, MAX_TABS do
        local slot = ArtisanMod.bookButtons[i]
        local data = list[i]
        if data then
            slot.profData = data
            slot.iconTexture:SetTexture(data.icon)
            slot.titleText:SetText(data.name)
            slot.subText:SetText(data.subTitle or "")

            -- Active crafting profession vs. Passive gathering tracker
            if data.canOpenWindow then
                slot.button:EnableMouse(true)
                slot.normalBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                slot.normalBorder:SetWidth(64)
                slot.normalBorder:SetHeight(64)
                slot.passiveBorder:Hide()
                slot.titleText:SetTextColor(1.0, 0.82, 0.0) -- Standard Normal Gold
            else
                slot.button:EnableMouse(true) -- Keep mouse for tooltip only
                slot.normalBorder:SetTexture("")
                slot.passiveBorder:Show()
                slot.titleText:SetTextColor(0.85, 0.85, 0.85)
            end

            -- Skill Progress Bar & Blizzard SkillFrame-style Modifier Text
            if data.noSkillBar then
                slot.statusBar:Hide()
            else
                slot.statusBar:Show()
                slot.statusBar:SetMinMaxValues(0, data.maxRank > 0 and data.maxRank or 1)
                slot.statusBar:SetValue(data.rank)

                -- Format identically to Blizzard Character SkillFrame:
                -- Base rank/maxRank stays white; only the +n modifier is colored green
                if data.modifier > 0 then
                    slot.statusText:SetText(format("%d (%s+%d|r) / %d", data.rank, GREEN_FONT_COLOR_CODE, data.modifier, data.maxRank))
                elseif data.modifier < 0 then
                    slot.statusText:SetText(format("%d (%s%d|r) / %d", data.rank, RED_FONT_COLOR_CODE, data.modifier, data.maxRank))
                else
                    slot.statusText:SetText(format("%d / %d", data.rank, data.maxRank))
                end
            end

            slot.container:Show()
        else
            slot.profData = nil
            slot.container:Hide()
        end
    end
end

local function CreateArtisanBookFrame()
    if _G.ArtisanBookFrame then return _G.ArtisanBookFrame end

    local f = CreateFrame("Frame", "ArtisanBookFrame", UIParent)
    f:SetWidth(384)
    f:SetHeight(512)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    -- Allow closing with ESC
    table.insert(UISpecialFrames, "ArtisanBookFrame")

    -- Stock SpellBook Portrait & 4-Quadrant Parchment Textures
    local portrait = f:CreateTexture("ArtisanBookFramePortrait", "BACKGROUND")
    portrait:SetWidth(58)
    portrait:SetHeight(58)
    portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    portrait:SetTexture("Interface\\Spellbook\\Spellbook-Icon")

    local topLeft = f:CreateTexture(nil, "ARTWORK")
    topLeft:SetWidth(256)
    topLeft:SetHeight(256)
    topLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    topLeft:SetTexture("Interface\\Spellbook\\UI-SpellBook-TopLeft")

    local topRight = f:CreateTexture(nil, "ARTWORK")
    topRight:SetWidth(128)
    topRight:SetHeight(256)
    topRight:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    topRight:SetTexture("Interface\\Spellbook\\UI-SpellBook-TopRight")

    local botLeft = f:CreateTexture(nil, "ARTWORK")
    botLeft:SetWidth(256)
    botLeft:SetHeight(256)
    botLeft:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    botLeft:SetTexture("Interface\\Spellbook\\UI-SpellBook-BotLeft")

    local botRight = f:CreateTexture(nil, "ARTWORK")
    botRight:SetWidth(128)
    botRight:SetHeight(256)
    botRight:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT", 0, 0)
    botRight:SetTexture("Interface\\Spellbook\\UI-SpellBook-BotRight")

    -- Window Title
    local title = f:CreateFontString("ArtisanBookFrameTitleText", "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", f, "TOP", 6, -18)
    title:SetText("Professions")

    -- Top-Right Close Button (Standard X on Overview Window)
    local closeBtn = CreateFrame("Button", "ArtisanBookFrameCloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("CENTER", f, "TOPRIGHT", -44, -26)

    -- Bottom Tabs: Primary and Secondary
    local bTab1 = CreateFrame("Button", "ArtisanBookFrameTab1", f, "CharacterFrameTabButtonTemplate")
    bTab1:SetID(1)
    bTab1:SetText("Primary")
    bTab1:SetPoint("CENTER", f, "BOTTOMLEFT", 60, 61)
    bTab1:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        ArtisanMod.bookBottomTab = 1
        UpdateBookWindow()
    end)

    local bTab2 = CreateFrame("Button", "ArtisanBookFrameTab2", f, "CharacterFrameTabButtonTemplate")
    bTab2:SetID(2)
    bTab2:SetText("Secondary")
    bTab2:SetPoint("LEFT", bTab1, "RIGHT", -15, 0)
    bTab2:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        ArtisanMod.bookBottomTab = 2
        UpdateBookWindow()
    end)

    PanelTemplates_SetNumTabs(f, 2)
    PanelTemplates_SetTab(f, 1)

    -- 2 Columns x 5 Rows Grid (10 Professions Max per Tab)
    for i = 1, MAX_TABS do
        local col = math.mod(i - 1, 2)       -- 0 = left column, 1 = right column
        local row = math.floor((i - 1) / 2)  -- 0..4

        local xOffset = 34 + (col * 150)
        local yOffset = -82 - (row * 64)

        local container = CreateFrame("Frame", "ArtisanBookSlot" .. i, f)
        container:SetWidth(144)
        container:SetHeight(56)
        container:SetPoint("TOPLEFT", f, "TOPLEFT", xOffset, yOffset)

        -- Empty Slot Background (matches SpellBookButtonTemplate parchment slot)
        local slotBg = container:CreateTexture(nil, "BACKGROUND")
        slotBg:SetWidth(64)
        slotBg:SetHeight(64)
        slotBg:SetPoint("TOPLEFT", container, "TOPLEFT", -13, 13)
        slotBg:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")

        -- 37x37 Spellbook-sized Icon Button
        local btn = CreateFrame("Button", "ArtisanBookButton" .. i, container)
        btn:SetWidth(37)
        btn:SetHeight(37)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

        local iconTex = btn:CreateTexture(nil, "BORDER")
        iconTex:SetAllPoints(btn)

        local normalBorder = btn:CreateTexture(nil, "ARTWORK")
        normalBorder:SetWidth(64)
        normalBorder:SetHeight(64)
        normalBorder:SetPoint("CENTER", btn, "CENTER", 0, -1)
        normalBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")

        -- Passive Border for Gathering Professions (Herbalism, Skinning, Fishing, Lockpicking)
        local passiveBorder = btn:CreateTexture(nil, "OVERLAY")
        passiveBorder:SetWidth(43)
        passiveBorder:SetHeight(43)
        passiveBorder:SetPoint("CENTER", btn, "CENTER", 0, 0)
        passiveBorder:SetTexture("Interface\\Spellbook\\Spellbook-PassiveBorder")
        passiveBorder:Hide()

        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

        -- 1. Profession Title
        local titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, 1)
        titleText:SetWidth(98)
        titleText:SetJustifyH("LEFT")

        -- 2. Training Level / Specialization Subtitle
        local subText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -1)
        subText:SetWidth(98)
        subText:SetJustifyH("LEFT")
        subText:SetTextColor(0.85, 0.75, 0.55)

        -- 3. Progress Bar with Current / Max (+Modifier)
        local statusBar = CreateFrame("StatusBar", "ArtisanBookStatusBar" .. i, container)
        statusBar:SetWidth(96)
        statusBar:SetHeight(12)
        statusBar:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -3)
        statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusBar:SetStatusBarColor(0.0, 0.45, 0.9)

        local barBg = statusBar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(statusBar)
        barBg:SetTexture(0.05, 0.05, 0.05, 0.75)

        local barBorder = CreateFrame("Frame", nil, statusBar)
        barBorder:SetPoint("TOPLEFT", statusBar, "TOPLEFT", -2, 2)
        barBorder:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 2, -2)
        barBorder:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })
        barBorder:SetBackdropBorderColor(0.6, 0.6, 0.6, 1.0)

        local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusText:SetPoint("CENTER", statusBar, "CENTER", 0, 0)

        -- Button Click & Tooltip Handlers
        local slotIndex = i
        btn:SetScript("OnEnter", function()
            local slotData = ArtisanMod.bookButtons[slotIndex].profData
            if not slotData then return end
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(slotData.name, 1.0, 1.0, 1.0)
            if slotData.subTitle and slotData.subTitle ~= "" then
                GameTooltip:AddLine(slotData.subTitle, 0.85, 0.75, 0.55)
            end
            if slotData.canOpenWindow then
                GameTooltip:AddLine("Click to open " .. slotData.castSpell, 0.2, 1.0, 0.2)
            else
                GameTooltip:AddLine("Passive skill tracker", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            local slotData = ArtisanMod.bookButtons[slotIndex].profData
            if not slotData then return end
            if not slotData.canOpenWindow then
                -- Passive gathering tracker: do not open a window
                return
            end

            -- Sync position & active tab, close Overview, and open the clicked profession in ArtisanFrame
            ArtisanMod.activeBottomTab = ArtisanMod.bookBottomTab
            if ArtisanFrame then
                SyncWindowPosition(ArtisanBookFrame, ArtisanFrame)
            end
            PlaySound("igAbiliityPageTurn")
            ArtisanBookFrame:Hide()
            CastSpellByName(slotData.castSpell)
        end)

        ArtisanMod.bookButtons[i] = {
            container = container,
            button = btn,
            iconTexture = iconTex,
            normalBorder = normalBorder,
            passiveBorder = passiveBorder,
            titleText = titleText,
            subText = subText,
            statusBar = statusBar,
            statusText = statusText,
        }
    end

    f:SetScript("OnShow", function()
        PlaySound("igSpellBookOpen")
        UpdateBookWindow()
    end)

    f:SetScript("OnHide", function()
        PlaySound("igSpellBookClose")
    end)

    -- Apply pfUI Nostalgia skinning to bottom tabs if available
    if _G.pfUI and pfUI.api and pfUI.api.SkinTab then
        pfUI.api.SkinTab(bTab1)
        pfUI.api.SkinTab(bTab2)
    end

    return f
end

function ArtisanMod.OpenOverviewWindow()
    local book = CreateArtisanBookFrame()
    if ArtisanFrame and ArtisanFrame:IsShown() then
        SyncWindowPosition(ArtisanFrame, book)
        ArtisanMod.bookBottomTab = ArtisanMod.activeBottomTab
        CloseTradeSkill()
        CloseCraft()
        if ArtisanFrame:IsShown() then
            HideUIPanel(ArtisanFrame)
        end
    end
    book:Show()
    UpdateBookWindow()
end

-- ============================================================================
-- Slash Command Hook: "/artisan open"
-- ============================================================================

local function HookArtisanSlashCommand()
    if ArtisanMod.slashHooked then return end
    local origHandler = SlashCmdList["ARTISAN"]
    SlashCmdList["ARTISAN"] = function(msg)
        local clean = msg and strlower(gsub(msg, "^%s*(.-)%s*$", "%1")) or ""
        if clean == "open" then
            if ArtisanBookFrame and ArtisanBookFrame:IsShown() then
                ArtisanBookFrame:Hide()
            else
                ArtisanMod.OpenOverviewWindow()
            end
            return
        end
        if origHandler then
            origHandler(msg)
        end
    end
    ArtisanMod.slashHooked = true
end

-- ============================================================================
-- Event Driver (Zero OnUpdate Polling)
-- ============================================================================

local eventFrame = CreateFrame("Frame", "ArtisanBookEventFrame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CRAFT_SHOW")
eventFrame:RegisterEvent("CRAFT_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        SetupArtisanFrameEnhancements()
        CreateArtisanBookFrame()
        HookArtisanSlashCommand()
        RefreshProfessionLists()
    elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
        SetupArtisanFrameEnhancements()
        if ArtisanBookFrame and ArtisanBookFrame:IsShown() and ArtisanFrame then
            SyncWindowPosition(ArtisanBookFrame, ArtisanFrame)
            ArtisanBookFrame:Hide()
        end
        AutoSyncBottomTabToOpenSkill()
    elseif event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
        RefreshProfessionLists()
        if ArtisanFrame and ArtisanFrame:IsShown() then
            UpdateArtisanSideTabs()
        end
        if ArtisanBookFrame and ArtisanBookFrame:IsShown() then
            UpdateBookWindow()
        end
    end
end)