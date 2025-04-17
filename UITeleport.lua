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

local dungeonMaps = {}

local function GetMapContinentInfo(mapID)
    while mapID do
        local mapInfo = C_Map.GetMapInfo(mapID)
        if not mapInfo then
            return nil
        elseif mapInfo.mapType == Enum.UIMapType.Continent then
            return mapInfo
        elseif mapID == mapInfo.parent then
            return nil
        else
            mapID = mapInfo.parentMapID
        end
    end
end

do
    for i = 1, 10000 do
        local info =  C_Map.GetMapInfo(i)
        if info and info.mapType == Enum.UIMapType.Dungeon and not dungeonMaps[info.name] then
            local cInfo = GetMapContinentInfo(i)
            info.continentName = cInfo and cInfo.name
            dungeonMaps[info.name] = info
        end
    end
end

-- Some dungeons have more than one spell, some can be known and some not

local function FindTeleportSpell(mapName)
    local notKnownSpellID
    for i = 1, GetNumFlyouts() do
        local flyoutID = GetFlyoutID(i)
        local _, _, numSlots, isKnownFlyout = GetFlyoutInfo(flyoutID)
        if isKnownFlyout then
            for slot = 1, numSlots do
                local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, slot)
                local spellDescription = C_Spell.GetSpellDescription(spellID)
                if spellDescription and spellDescription:find(mapName, nil, true) then
                    if isKnown then
                        return spellID, true
                    else
                        notKnownSpellID = spellID
                    end
                end
            end
        end
    end
    return notKnownSpellID, false
end

local function GetTeleports()
    local teleports = {}
    for _, info in pairs(dungeonMaps) do
        local spellID, isKnown = FindTeleportSpell(info.name)
        if spellID then
            table.insert(teleports, { info = info, spellID = spellID, isKnown = isKnown })
        end
    end
    table.sort(teleports,
        function (a, b)
            if a.info.continentName ~= b.info.continentName then
                return a.info.continentName < b.info.continentName
            else
                return a.info.name < b.info.name
            end
        end)
    return teleports
end

--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportButtonMixin = {}

function LiteKeystoneTeleportButtonMixin:OnEnter()
end

function LiteKeystoneTeleportButtonMixin:OnLeave()
    GameTooltip:Hide()
end

function LiteKeystoneTeleportButtonMixin:OnLoad()
    self:RegisterForClicks('AnyUp')
    self:SetAttribute("pressAndHoldAction", true)
    self:SetAttribute("type", "spell")
    self:SetAttribute("typerelease", "spell")
    self.Icon.cooldown:SetCountdownFont("GameFontHighlightSmall")
end

function LiteKeystoneTeleportButtonMixin:UpdateCooldown()
    if self.spellID then
        local info = C_Spell.GetSpellCooldown(self.spellID)
        if info then
            CooldownFrame_Set(self.Icon.cooldown, info.startTime, info.duration, info.isEnabled, false, info.modRate)
        else
            self.Icon.cooldown:Hide();
        end
    end
end

function LiteKeystoneTeleportButtonMixin:Initialize(node)
    local data = node:GetData()
    self.spellID = data.spellID
    self.Map:SetText(data.info.name)

    local info = C_Spell.GetSpellInfo(self.spellID)
    self.Icon:SetNormalTexture(info.iconID)
    if data.isKnown then
        self.Map:SetTextColor(0.784, 0.270, 0.980)
        self.Icon:SetEnabled(true)
    else
        self.Map:SetTextColor(0.66, 0.66, 0.66, 1)
        self.Icon:SetEnabled(false)
    end
    self:SetAttribute("spell", self.spellID)
    self:UpdateCooldown()
end


--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportInfoMixin = {}

function LiteKeystoneTeleportInfoMixin:Update()
    local teleports = GetTeleports()
    local dp = CreateTreeDataProvider()
    local subTrees = {}
    for _, t in ipairs(teleports) do
        if not subTrees[t.info.continentName] then
            local data = {
                isCategory = true,
                name = t.info.continentName
            }
            subTrees[t.info.continentName] = dp:Insert(data)
        end
        subTrees[t.info.continentName]:Insert(t)
    end
    self.ScrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
end

function LiteKeystoneTeleportInfoMixin:OnLoad()
    local view = CreateScrollBoxListTreeListView(8)
    view:SetElementFactory(
        function (factory, node)
            local data = node:GetData()
            if data.isCategory then
                factory("LiteKeystoneTeleportCategoryTemplate",
                    function (button, node)
                        button.Name:SetText(data.name)
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
end

function LiteKeystoneTeleportInfoMixin:OnShow()
    self:Update()
end
