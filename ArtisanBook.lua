-- ============================================================================
-- ArtisanBook.lua
-- Primary/Secondary Bottom Tabs, 10 Scaled Side Tabs, Back Button, and
-- "/artisan open" Spellbook-Style Profession Overview for Vanilla 1.12 / Turtle WoW
-- ============================================================================

local MAX_TABS = 10
local SIDE_TAB_SCALE = 0.78
local SIDE_TAB_GAP = -13

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
local spellBookCache = {}
local function ScanSpellBookCache()
    for k in pairs(spellBookCache) do spellBookCache[k] = nil end
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
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
local function ScanCharacterSkills()
    for k in pairs(skillLineCacheByName) do skillLineCacheByName[k] = nil end

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
            skillLineCacheByName[strlower(skillName)] = {
                name = skillName,
                rank = skillRank or 0,
                modifier = (skillModifier or 0) + (numTempPoints or 0),
                maxRank = skillMaxRank or 0,
            }
        end
    end

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
local PROFESSIONS = {
    -- PRIMARY PROFESSIONS (1)
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
        key = "SKINNING",
        category = 1,
        skillLineID = 393,
        defaultName = "Skinning",
        castSpellName = nil,
        spellIDs = { 8613, 8617, 8618, 10768 },
        icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        canOpenWindow = false,
    },

    -- SECONDARY & CLASS (2)
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

local function GetSpecializationTitle(profDef)
    if not profDef.specs then return nil end
    for _, spec in ipairs(profDef.specs) do
        if CheckSpellKnown(spec.spellID) then
            local locName = SafeGetSpellName(spec.spellID)
            return locName or spec.name
        end
        local cached = spellBookCache[strlower(spec.name)]
        if cached then
            return cached.name
        end
    end
    return nil
end

local function ResolveProfessionData(profDef)
    local skillName = profDef.defaultName
    if profDef.skillLineID and C_SpellBook and C_SpellBook.GetSkillLineName then
        local dbcName = C_SpellBook.GetSkillLineName(profDef.skillLineID)
        if dbcName and dbcName ~= "" then
            skillName = dbcName
        end
    end

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

    if not curRank or maxRank == 0 then
        return nil
    end

    local canOpen = profDef.canOpenWindow
    if canOpen and not sbEntry then
        canOpen = false
    end

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
    primaryAll = {},
    secondaryAll = {},
    primaryTabs = {},
    secondaryTabs = {},
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

local function SyncWindowPosition(sourceFrame, targetFrame)
    if not sourceFrame or not targetFrame then return end
    local left = sourceFrame:GetLeft()
    local top = sourceFrame:GetTop()
    if left and top then
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

-- Update SpellBookFrameTabButtonTemplate active/inactive visual state
local function UpdateSpellBookStyleTabs(tab1, tab2, activeID)
    if not tab1 or not tab2 then return end
    if activeID == 1 then
        tab1:Disable()
        tab2:Enable()
    else
        tab1:Enable()
        tab2:Disable()
    end
end

-- ============================================================================
-- Part 1 & 2: ArtisanFrame Bottom Tabs, 10 Scaled Right-Side Tabs & Back Arrow
-- ============================================================================

-- Keep original ArtisanFrameTab1..N alive in _G as CheckButtons so Artisan.lua:480
-- never errors on :SetChecked(), while preventing them from ever showing on screen.
local function SuppressOriginalArtisanSideTabs()
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
            if f and not f.isArtisanCustomSideTab then
                f:Hide()
                f.Show = function() end
            end
        end
    end
end

local function UpdateArtisanSideTabs()
    if not ArtisanFrame then return end
    SuppressOriginalArtisanSideTabs()

    local list = (ArtisanMod.activeBottomTab == 1) and ArtisanMod.primaryTabs or ArtisanMod.secondaryTabs
    local activeSkill = GetCurrentlyOpenSkillName()
    local activeLower = activeSkill and strlower(activeSkill) or nil

    for i = 1, MAX_TABS do
        local tab = ArtisanMod.sideTabs[i]
        local data = list[i]
        if tab then
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
    UpdateSpellBookStyleTabs(ArtisanMod.bottomTab1, ArtisanMod.bottomTab2, tabID)
    UpdateArtisanSideTabs()
end

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

    SuppressOriginalArtisanSideTabs()

    -- 1. Bottom Tabs on ArtisanFrame using Spellbook/Pet tab artwork & template
    -- Attach the bottom tab strip cropped from UI-SpellbookPanel-BotLeft right under ArtisanFrame's bottom border
    local tabStrip = ArtisanFrame:CreateTexture("ArtisanFrameBottomTabStrip", "ARTWORK")
    tabStrip:SetWidth(256)
    tabStrip:SetHeight(38)
    tabStrip:SetPoint("TOPLEFT", ArtisanFrame, "BOTTOMLEFT", 0, 32)
    tabStrip:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-BotLeft")
    tabStrip:SetTexCoord(0, 1, 179 / 256, 217 / 256)

    local tab1 = CreateFrame("Button", "ArtisanBottomTab1", ArtisanFrame, "SpellBookFrameTabButtonTemplate")
    tab1:SetID(1)
    tab1:SetText("Primary")
    tab1:ClearAllPoints()
    tab1:SetPoint("CENTER", tabStrip, "BOTTOMLEFT", 79, 22)
    tab1:SetScript("OnEnter", nil)
    tab1:SetScript("OnLeave", nil)
    tab1:SetScript("OnClick", function()
        PlaySound("igAbiliityPageTurn")
        SetArtisanBottomTab(1)
    end)

    local tab2 = CreateFrame("Button", "ArtisanBottomTab2", ArtisanFrame, "SpellBookFrameTabButtonTemplate")
    tab2:SetID(2)
    tab2:SetText("Secondary")
    tab2:ClearAllPoints()
    tab2:SetPoint("LEFT", tab1, "RIGHT", -20, 0)
    tab2:SetScript("OnEnter", nil)
    tab2:SetScript("OnLeave", nil)
    tab2:SetScript("OnClick", function()
        PlaySound("igAbiliityPageTurn")
        SetArtisanBottomTab(2)
    end)

    ArtisanMod.bottomTab1 = tab1
    ArtisanMod.bottomTab2 = tab2
    UpdateSpellBookStyleTabs(tab1, tab2, 1)

    -- 2. Unscaled anchor frame pinned flush to ArtisanFrame's visible right edge (-33px from TOPRIGHT)
    local sideAnchor = CreateFrame("Frame", "ArtisanSideTabAnchor", ArtisanFrame)
    sideAnchor:SetWidth(1)
    sideAnchor:SetHeight(1)
    sideAnchor:SetPoint("TOPLEFT", ArtisanFrame, "TOPRIGHT", -33, -28)

    for i = 1, MAX_TABS do
        local sideTab = CreateFrame("CheckButton", "ArtisanCustomSideTab" .. i, ArtisanFrame, "SpellBookSkillLineTabTemplate")
        sideTab.isArtisanCustomSideTab = true
        sideTab:SetID(i)
        sideTab:SetScale(SIDE_TAB_SCALE)
        sideTab:ClearAllPoints()

        if i == 1 then
            sideTab:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, 0)
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

    -- 3. Scale down and replace the Top-Right Close Button with a Back Arrow
    local closeBtn = _G["ArtisanFrameCloseButton"]
    if not closeBtn then
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
        -- Preserve exact center inside the top-right box while shrinking from 32x32 to 20x20
        local cx, cy = closeBtn:GetCenter()
        local rx, ry = ArtisanFrame:GetRight(), ArtisanFrame:GetTop()
        closeBtn:SetWidth(20)
        closeBtn:SetHeight(20)
        if cx and cy and rx and ry then
            closeBtn:ClearAllPoints()
            closeBtn:SetPoint("CENTER", ArtisanFrame, "TOPRIGHT", cx - rx, cy - ry)
        end

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

    local origOnShow = ArtisanFrame:GetScript("OnShow")
    ArtisanFrame:SetScript("OnShow", function()
        if origOnShow then origOnShow() end
        if ArtisanBookFrame and ArtisanBookFrame:IsShown() then
            SyncWindowPosition(ArtisanBookFrame, ArtisanFrame)
            ArtisanBookFrame:Hide()
        end
        AutoSyncBottomTabToOpenSkill()
    end)
end

-- ============================================================================
-- Part 3: "/artisan open" Spellbook-Style Overview Window (ArtisanBookFrame)
-- ============================================================================

local function UpdateBookWindow()
    if not ArtisanBookFrame or not ArtisanBookFrame:IsShown() then return end

    RefreshProfessionLists()
    UpdateSpellBookStyleTabs(ArtisanMod.bookTab1, ArtisanMod.bookTab2, ArtisanMod.bookBottomTab)

    local list = (ArtisanMod.bookBottomTab == 1) and ArtisanMod.primaryAll or ArtisanMod.secondaryAll

    for i = 1, MAX_TABS do
        local slot = ArtisanMod.bookButtons[i]
        local data = list[i]
        if data then
            slot.profData = data
            slot.iconTexture:SetTexture(data.icon)
            slot.titleText:SetText(data.name)
            slot.subText:SetText(data.subTitle or "")

            -- Active crafting profession vs. Passive gathering tracker (no stuck hover overlay)
            if data.canOpenWindow then
                slot.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                slot.button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
                slot.titleText:SetTextColor(1.0, 0.82, 0.0)
            else
                slot.button:SetHighlightTexture("")
                slot.button:SetPushedTexture("")
                slot.titleText:SetTextColor(0.85, 0.85, 0.85)
            end

            if data.noSkillBar then
                slot.statusBar:Hide()
            else
                slot.statusBar:Show()
                slot.statusBar:SetMinMaxValues(0, data.maxRank > 0 and data.maxRank or 1)
                slot.statusBar:SetValue(data.rank)

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

    table.insert(UISpecialFrames, "ArtisanBookFrame")

    -- Stock 1.12 SpellBook Portrait & 4-Quadrant Panel Textures
    local portrait = f:CreateTexture("ArtisanBookFramePortrait", "BACKGROUND")
    portrait:SetWidth(58)
    portrait:SetHeight(58)
    portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    portrait:SetTexture("Interface\\Spellbook\\Spellbook-Icon")

    local topLeft = f:CreateTexture(nil, "ARTWORK")
    topLeft:SetWidth(256)
    topLeft:SetHeight(256)
    topLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    topLeft:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-TopLeft")

    local topRight = f:CreateTexture(nil, "ARTWORK")
    topRight:SetWidth(128)
    topRight:SetHeight(256)
    topRight:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    topRight:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-TopRight")

    local botLeft = f:CreateTexture(nil, "ARTWORK")
    botLeft:SetWidth(256)
    botLeft:SetHeight(256)
    botLeft:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    botLeft:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-BotLeft")

    local botRight = f:CreateTexture(nil, "ARTWORK")
    botRight:SetWidth(128)
    botRight:SetHeight(256)
    botRight:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT", 0, 0)
    botRight:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-BotRight")

    -- Window Title
    local title = f:CreateFontString("ArtisanBookFrameTitleText", "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", f, "TOP", 6, -18)
    title:SetText("Professions")

    -- Top-Right Close Button
    local closeBtn = CreateFrame("Button", "ArtisanBookFrameCloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("CENTER", f, "TOPRIGHT", -44, -26)

    -- Bottom Tabs matching Blizzard Spellbook/Pet tabs (aligned over UI-SpellbookPanel-BotLeft)
    local bTab1 = CreateFrame("Button", "ArtisanBookFrameTab1", f, "SpellBookFrameTabButtonTemplate")
    bTab1:SetID(1)
    bTab1:SetText("Primary")
    bTab1:ClearAllPoints()
    bTab1:SetPoint("CENTER", f, "BOTTOMLEFT", 79, 61)
    bTab1:SetScript("OnEnter", nil)
    bTab1:SetScript("OnLeave", nil)
    bTab1:SetScript("OnClick", function()
        PlaySound("igAbiliityPageTurn")
        ArtisanMod.bookBottomTab = 1
        UpdateBookWindow()
    end)

    local bTab2 = CreateFrame("Button", "ArtisanBookFrameTab2", f, "SpellBookFrameTabButtonTemplate")
    bTab2:SetID(2)
    bTab2:SetText("Secondary")
    bTab2:ClearAllPoints()
    bTab2:SetPoint("LEFT", bTab1, "RIGHT", -20, 0)
    bTab2:SetScript("OnEnter", nil)
    bTab2:SetScript("OnLeave", nil)
    bTab2:SetScript("OnClick", function()
        PlaySound("igAbiliityPageTurn")
        ArtisanMod.bookBottomTab = 2
        UpdateBookWindow()
    end)

    ArtisanMod.bookTab1 = bTab1
    ArtisanMod.bookTab2 = bTab2
    UpdateSpellBookStyleTabs(bTab1, bTab2, 1)

    -- 2 Columns x 5 Rows Grid aligned to SpellBookFrame parchment pages
    for i = 1, MAX_TABS do
        local col = math.mod(i - 1, 2)       -- 0 = left page, 1 = right page
        local row = math.floor((i - 1) / 2)  -- 0..4

        local xOffset = (col == 0) and 34 or 191
        local yOffset = -85 - (row * 60)

        local container = CreateFrame("Frame", "ArtisanBookSlot" .. i, f)
        container:SetWidth(142)
        container:SetHeight(52)
        container:SetPoint("TOPLEFT", f, "TOPLEFT", xOffset, yOffset)

        -- 37x37 Spellbook Icon Button
        local btn = CreateFrame("Button", "ArtisanBookButton" .. i, container)
        btn:SetWidth(37)
        btn:SetHeight(37)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

        -- Empty Slot Background aligned at (-3, 3) to match Blizzard's SpellButtonTemplate
        local slotBg = btn:CreateTexture(nil, "BACKGROUND")
        slotBg:SetWidth(64)
        slotBg:SetHeight(64)
        slotBg:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
        slotBg:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")

        local iconTex = btn:CreateTexture(nil, "BORDER")
        iconTex:SetAllPoints(btn)

        -- 1. Profession Title
        local titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, 1)
        titleText:SetWidth(96)
        titleText:SetJustifyH("LEFT")

        -- 2. Training Level / Specialization Subtitle
        local subText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -1)
        subText:SetWidth(96)
        subText:SetJustifyH("LEFT")
        subText:SetTextColor(0.35, 0.20, 0.05) -- Dark parchment subtext color (readable on Spellbook background)

        -- 3. Progress Bar with Current / Max (+Modifier)
        local statusBar = CreateFrame("StatusBar", "ArtisanBookStatusBar" .. i, container)
        statusBar:SetWidth(92)
        statusBar:SetHeight(12)
        statusBar:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -3)
        statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusBar:SetStatusBarColor(0.0, 0.45, 0.9)

        local barBg = statusBar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(statusBar)
        barBg:SetTexture(0.05, 0.05, 0.05, 0.80)

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
            if not slotData or not slotData.canOpenWindow then
                return
            end

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
-- Event Driver
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