--[[----------------------------------------------------------------------------

  Copyright 2020 Mike Battersby

  LiteKeystone is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License, version 2, as published by
  the Free Software Foundation.

  LiteKeystone is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  The file LICENSE.txt included with LiteKeystone contains a copy of the
  license. If the LICENSE.txt file is missing, you can find a copy at
  http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

----------------------------------------------------------------------------]]--

-- This was originally dynamic, but there are enough cases that don't quite
-- match, and it was super slow, that it's easier to hardcode and hope I can
-- keep updated. Combined from encounter journal, C_Map and C_ChallengeMode.
-- Plus also EJ is not stateless so it involved dangerous mucking about.

-- Note: .name here is for edit convenience only and shouldn't be used.

-- Some dungeons have more than one spell, some can be known and some not
-- depending on faction and other stuff I don't know. Probably need to handle
-- that.


local teleports = {
    {
        challengeModeID = { 200 },
        continentMapID = 619,
        instanceID = 721,
        mapID = 704,
        name = "Halls of Valor",
        parentMapID = 634,
        spellID = { 393764, },
    },
    {
        challengeModeID = { 206 },
        continentMapID = 619,
        instanceID = 767,
        mapID = 731,
        name = "Neltharion's Lair",
        parentMapID = 650,
        spellID = { 410078, },
    },
    {
        challengeModeID = { 210 },
        continentMapID = 619,
        instanceID = 800,
        mapID = 761,
        name = "Court of Stars",
        parentMapID = 680,
        spellID = { 393766, },
    },
    {
        challengeModeID = { 199 },
        continentMapID = 619,
        instanceID = 740,
        mapID = 751,
        name = "Black Rook Hold",
        parentMapID = 641,
        spellID = { 424153, },
    },
    {
        challengeModeID = { 198 },
        continentMapID = 619,
        instanceID = 762,
        mapID = 733,
        name = "Darkheart Thicket",
        parentMapID = 641,
        spellID = { 424163, },
    },
    {
        challengeModeID = { 163 },
        continentMapID = 572,
        instanceID = 385,
        mapID = 573,
        name = "Bloodmaul Slag Mines",
        parentMapID = 525,
        spellID = { 159895, },
    },
    {
        challengeModeID = { 166 },
        continentMapID = 572,
        instanceID = 536,
        mapID = 606,
        name = "Grimrail Depot",
        parentMapID = 543,
        spellID = { 159900, },
    },
    {
        challengeModeID = { 169 },
        continentMapID = 572,
        instanceID = 558,
        mapID = 595,
        name = "Iron Docks",
        parentMapID = 543,
        spellID = { 159896, },
    },
    {
        challengeModeID = { 168 },
        continentMapID = 572,
        instanceID = 556,
        mapID = 620,
        name = "The Everbloom",
        parentMapID = 543,
        spellID = { 159901, },
    },
    {
        challengeModeID = { 165 },
        continentMapID = 572,
        instanceID = 537,
        mapID = 574,
        name = "Shadowmoon Burial Grounds",
        parentMapID = 539,
        spellID = { 159899, },
    },
    {
        challengeModeID = { 161 },
        continentMapID = 572,
        instanceID = 476,
        mapID = 601,
        name = "Skyreach",
        parentMapID = 542,
        spellID = { 159898, },
    },
    {
        challengeModeID = { 164 },
        continentMapID = 572,
        instanceID = 547,
        mapID = 593,
        name = "Auchindoun",
        parentMapID = 535,
        spellID = { 159897, },
    },
    {
        challengeModeID = { 400 },
        continentMapID = 1978,
        instanceID = 1198,
        mapID = 2093,
        name = "The Nokhud Offensive",
        parentMapID = 2023,
        spellID = { 393262, },
    },
    {
        challengeModeID = { 402 },
        continentMapID = 1978,
        instanceID = 1201,
        mapID = 2097,
        name = "Algeth'ar Academy",
        parentMapID = 2025,
        spellID = { 393273, },
    },
    {
        challengeModeID = { 463, 464 },
        continentMapID = 1978,
        instanceID = 1209,
        mapID = 2198,
        name = "Dawn of the Infinite",
        parentMapID = 2025,
        spellID = { 424197, },
    },
    {
        challengeModeID = { 406 },
        continentMapID = 1978,
        instanceID = 1204,
        mapID = 2082,
        name = "Halls of Infusion",
        parentMapID = 2025,
        spellID = { 393283, },
    },
    {
        challengeModeID = { 405 },
        continentMapID = 1978,
        instanceID = 1196,
        mapID = 2096,
        name = "Brackenhide Hollow",
        parentMapID = 2024,
        spellID = { 393267, },
    },
    {
        challengeModeID = { 401 },
        continentMapID = 1978,
        instanceID = 1203,
        mapID = 2073,
        name = "The Azure Vault",
        parentMapID = 2024,
        spellID = { 393279, },
    },
    {
        challengeModeID = { 404 },
        continentMapID = 1978,
        instanceID = 1199,
        mapID = 2080,
        name = "Neltharus",
        parentMapID = 2022,
        spellID = { 393276, },
    },
    {
        challengeModeID = { 399 },
        continentMapID = 1978,
        instanceID = 1202,
        mapID = 2095,
        name = "Ruby Life Pools",
        parentMapID = 2022,
        spellID = { 393256, },
    },
    {
        challengeModeID = { 456 },
        continentMapID = 13,
        instanceID = 65,
        mapID = 323,
        name = "Throne of the Tides",
        parentMapID = 204,
        spellID = { 424142, },
    },
    {
        challengeModeID = { 403 },
        continentMapID = 13,
        instanceID = 1197,
        mapID = 2071,
        name = "Uldaman: Legacy of Tyr",
        parentMapID = 15,
        spellID = { 393222, },
    },
    {
        challengeModeID = { 167 },
        continentMapID = 13,
        instanceID = 559,
        mapID = 617,
        name = "Upper Blackrock Spire",
        parentMapID = 36,
        spellID = { 159902, },
    },
    {
        challengeModeID = { 227, 234 },
        continentMapID = 13,
        instanceID = 860,
        mapID = 812,
        name = "Return to Karazhan",
        parentMapID = 42,
        spellID = { 373262, },
    },
    {
        challengeModeID = { 507 },
        continentMapID = 13,
        instanceID = 71,
        mapID = 293,
        name = "Grim Batol",
        parentMapID = 241,
        spellID = { 445424, },
    },
    {
        challengeModeID = { 438 },
        continentMapID = 12,
        instanceID = 68,
        mapID = 325,
        name = "The Vortex Pinnacle",
        parentMapID = 249,
        spellID = { 410080, },
    },
    {
        challengeModeID = { 503 },
        continentMapID = 2274,
        instanceID = 1271,
        mapID = 2357,
        name = "Ara-Kara, City of Echoes",
        parentMapID = 2255,
        spellID = { 445417, },
    },
    {
        challengeModeID = { 502 },
        continentMapID = 2274,
        instanceID = 1274,
        mapID = 2343,
        name = "City of Threads",
        parentMapID = 2255,
        spellID = { 445416, },
    },
    {
        challengeModeID = { 499 },
        continentMapID = 2274,
        instanceID = 1267,
        mapID = 2308,
        name = "Priory of the Sacred Flame",
        parentMapID = 2215,
        spellID = { 445444, },
    },
    {
        challengeModeID = { 505 },
        continentMapID = 2274,
        instanceID = 1270,
        mapID = 2359,
        name = "The Dawnbreaker",
        parentMapID = 2215,
        spellID = { 445414, },
    },
    {
        challengeModeID = { 506 },
        continentMapID = 2274,
        instanceID = 1272,
        mapID = 2335,
        name = "Cinderbrew Meadery",
        parentMapID = 2248,
        spellID = { 445440, },
    },
    {
        challengeModeID = { 500 },
        continentMapID = 2274,
        instanceID = 1268,
        mapID = 2316,
        name = "The Rookery",
        parentMapID = 2248,
        spellID = { 445443, },
    },
    {
        challengeModeID = { 504 },
        continentMapID = 2274,
        instanceID = 1210,
        mapID = 2303,
        name = "Darkflame Cleft",
        parentMapID = 2214,
        spellID = { 445441, },
    },
    {
        challengeModeID = { 525 },
        continentMapID = 2274,
        instanceID = 1298,
        mapID = 2387,
        name = "Operation: Floodgate",
        parentMapID = 2214,
        spellID = { 1216786, },
    },
    {
        challengeModeID = { 501 },
        continentMapID = 2274,
        instanceID = 1269,
        mapID = 2341,
        name = "The Stonevault",
        parentMapID = 2214,
        spellID = { 445269, },
    },
    {
        challengeModeID = { 248 },
        continentMapID = 876,
        instanceID = 1021,
        mapID = 1015,
        name = "Waycrest Manor",
        parentMapID = 896,
        spellID = { 424167, },
    },
    {
        challengeModeID = { 369, 370 },
        continentMapID = 876,
        instanceID = 1178,
        mapID = 1491,
        name = "Operation: Mechagon",
        parentMapID = 1462,
        spellID = { 373274, },
    },
    {
        challengeModeID = { 245 },
        continentMapID = 876,
        instanceID = 1001,
        mapID = 936,
        name = "Freehold",
        parentMapID = 895,
        spellID = { 410071, },
    },
    {
        challengeModeID = { 353 },
        continentMapID = 876,
        instanceID = 1023,
        mapID = 1162,
        name = "Siege of Boralus",
        parentMapID = 895,
        spellID = { 464256, },
    },
    {
        challengeModeID = { 247 },
        continentMapID = 948,
        instanceID = 1012,
        mapID = 1010,
        name = "The MOTHERLODE!!",
        parentMapID = 194,
        spellID = { 467555, },
    },
    {
        challengeModeID = { 377 },
        continentMapID = 1550,
        instanceID = 1188,
        mapID = 1679,
        name = "De Other Side",
        parentMapID = 1565,
        spellID = { 354468, },
    },
    {
        challengeModeID = { 375 },
        continentMapID = 1550,
        instanceID = 1184,
        mapID = 1669,
        name = "Mists of Tirna Scithe",
        parentMapID = 1565,
        spellID = { 354464, },
    },
    {
        challengeModeID = { 381 },
        continentMapID = 1550,
        instanceID = 1186,
        mapID = 1693,
        name = "Spires of Ascension",
        parentMapID = 1533,
        spellID = { 354466, },
    },
    {
        challengeModeID = { 376 },
        continentMapID = 1550,
        instanceID = 1182,
        mapID = 1666,
        name = "The Necrotic Wake",
        parentMapID = 1533,
        spellID = { 354462, },
    },
    {
        challengeModeID = { 379 },
        continentMapID = 1550,
        instanceID = 1183,
        mapID = 1674,
        name = "Plaguefall",
        parentMapID = 1536,
        spellID = { 354463, },
    },
    {
        challengeModeID = { 382 },
        continentMapID = 1550,
        instanceID = 1187,
        mapID = 1683,
        name = "Theater of Pain",
        parentMapID = 1536,
        spellID = { 354467, },
    },
    {
        challengeModeID = { 378 },
        continentMapID = 1550,
        instanceID = 1185,
        mapID = 1663,
        name = "Halls of Atonement",
        parentMapID = 1525,
        spellID = { 354465, },
    },
    {
        challengeModeID = { 380 },
        continentMapID = 1550,
        instanceID = 1189,
        mapID = 1675,
        name = "Sanguine Depths",
        parentMapID = 1525,
        spellID = { 354469, },
    },
    {
        challengeModeID = { 391, 392 },
        continentMapID = 1550,
        instanceID = 1194,
        mapID = 1989,
        name = "Tazavesh, the Veiled Market",
        parentMapID = 1989,
        spellID = { 367416, },
    },
    {
        challengeModeID = { 251 },
        continentMapID = 875,
        instanceID = 1022,
        mapID = 1041,
        name = "The Underrot",
        parentMapID = 863,
        spellID = { 410074, },
    },
    {
        challengeModeID = { 244 },
        continentMapID = 875,
        instanceID = 968,
        mapID = 934,
        name = "Atal'Dazar",
        parentMapID = 862,
        spellID = { 424187, },
    },
    {
        challengeModeID = { 542 },
        continentMapID = 2274,
        instanceID = 2830,
        mapID = 2449,
        name = "Eco-Dome Al'dani",
        parentMapID = 2371,
        spellID = { 1237215, },
    },
}

-- Fill names in local language
do
    for _, t in ipairs(teleports) do
        local mapInfo = C_Map.GetMapInfo(t.mapID)
        t.mapName = mapInfo.name
        local parentInfo = C_Map.GetMapInfo(t.parentMapID)
        t.parentMapName = parentInfo and parentInfo.name
        local continentInfo = C_Map.GetMapInfo(t.continentMapID)
        t.continentMapName = continentInfo and continentInfo.name
    end
end

local function FindBestSpell(info)
    for _, spellID in ipairs(info.spellID) do
        if IsPlayerSpell(spellID) then
            return spellID, true
        end
    end
    return info.spellID[1], false
end

local function GetSortedTeleports()
    local out = GetValuesArray(teleports)

    table.sort(out,
        function (a, b)
            if a.continentMapName ~= b.continentMapName then
                return a.continentMapName < b.continentMapName
            elseif a.parentMapName ~= b.parentMapName then
                return a.parentMapName < b.parentMapName
            else
                return a.mapName < b.mapName
            end
        end)
    return out
end

--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportIconMixin = {}

function LiteKeystoneTeleportIconMixin:OnLoad()
    self:RegisterForClicks('AnyUp')
    self:SetAttribute("pressAndHoldAction", true)
    self:SetAttribute("type", "spell")
    self:SetAttribute("typerelease", "spell")
    self.cooldown:SetCountdownFont("GameFontHighlightSmall")
end

function LiteKeystoneTeleportIconMixin:OnShow()
    self:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
end

function LiteKeystoneTeleportIconMixin:OnHide()
    self:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED')
end

function LiteKeystoneTeleportIconMixin:OnEvent()
    self:UpdateCooldown()
end

function LiteKeystoneTeleportIconMixin:OnEnter()
    if self.spellID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:Show()
    end
end

function LiteKeystoneTeleportIconMixin:UpdateCooldown()
    if self.spellID then
        local info = C_Spell.GetSpellCooldown(self.spellID)
        if info then
            CooldownFrame_Set(self.cooldown, info.startTime, info.duration, info.isEnabled, false, info.modRate)
        else
            self.cooldown:Hide();
        end
    end
end

function LiteKeystoneTeleportIconMixin:SetSpell(spellID, isKnown)
    self.spellID = spellID
    if self.spellID then
        local info = C_Spell.GetSpellInfo(self.spellID)
        self:SetNormalTexture(info.iconID)
    end
    self:SetEnabled(isKnown)
    self:GetNormalTexture():SetDesaturated(not isKnown)
    self:SetAttribute("spell", self.spellID)
    self:UpdateCooldown()
    return spellID, isKnown
end

function LiteKeystoneTeleportIconMixin:SetByID(id)
    local info = FindValueInTableIf(teleports, function (v) return tContains(v.challengeModeID, id) end)
    if info then
        local spellID, isKnown = FindBestSpell(info)
        return self:SetSpell(spellID, isKnown)
    end
end

--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportButtonMixin = {}

function LiteKeystoneTeleportButtonMixin:Initialize(node)
    local data = node:GetData()
    self.spellID = data.bestSpellID
    self.Dungeon:SetText(data.mapName)
    self.Zone:SetText(data.parentMapName)

    if data.isKnown then
        self.Dungeon:SetTextColor(0.784, 0.270, 0.980)
        self.Zone:SetTextColor(0.784, 0.270, 0.980)
    else
        self.Dungeon:SetTextColor(0.66, 0.66, 0.66, 1)
        self.Zone:SetTextColor(0.66, 0.66, 0.66, 1)
    end
    self.Icon:SetSpell(data.bestSpellID, data.isKnown)
end


--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportInfoMixin = {}

function LiteKeystoneTeleportInfoMixin:Update()
    local teleports = GetSortedTeleports()
    local dp = CreateTreeDataProvider()
    local subTrees = {}
    for _, t in ipairs(teleports) do
        t.bestSpellID, t.isKnown = FindBestSpell(t)
        if t.isKnown or self.ShowAll:GetChecked() then
            if not subTrees[t.continentMapName] then
                local data = {
                    isCategory = true,
                    categoryName = t.continentMapName
                }
                subTrees[t.continentMapName] = dp:Insert(data)
            end
            subTrees[t.continentMapName]:Insert(t)
        end
    end
    self.ScrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
end

function LiteKeystoneTeleportInfoMixin:OnLoad()
    local indent = 8
    local view = CreateScrollBoxListTreeListView(indent)
    view:SetElementFactory(
        function (factory, node)
            local data = node:GetData()
            if data.isCategory then
                factory("LiteKeystoneTeleportCategoryTemplate",
                    function (button, node)
                        button.Name:SetText(data.categoryName)
                    end)
            else
                factory("LiteKeystoneTeleportButtonTemplate",
                    function (button, node)
                        button:Initialize(node)
                    end)
            end
        end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    ScrollUtil.RegisterAlternateRowBehavior(self.ScrollBox,
        function (button, isAlternate)
            button.Stripe:SetShown(isAlternate)
        end)
    self.ShowAll:SetScript('OnClick', function () self:Update() end)
end

function LiteKeystoneTeleportInfoMixin:OnShow()
    self:Update()
end
