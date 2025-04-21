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

do
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

    for i = 1, 10000 do
        local info =  C_Map.GetMapInfo(i)
        if info and info.mapType == Enum.UIMapType.Dungeon and not dungeonMaps[info.name] then
            local cInfo = GetMapContinentInfo(i)
            info.continentName = cInfo and cInfo.name
            local parentInfo = C_Map.GetMapInfo(info.parentMapID)
            info.parentName = parentInfo and parentInfo.name
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
            elseif a.info.parentName ~= b.info.parentName then
                return a.info.parentName < b.info.parentName
            else
                return a.info.name < b.info.name
            end
        end)
    return teleports
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
    self:SetAttribute("spell", self.spellID)
    self:UpdateCooldown()
end

function LiteKeystoneTeleportIconMixin:FindAndSetSpell(text)
    local spellID, isKnown = FindTeleportSpell(text)
    self:SetSpell(spellID, isKnown)
    return spellID, isKnown
end

--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportButtonMixin = {}

function LiteKeystoneTeleportButtonMixin:Initialize(node)
    local data = node:GetData()
    self.spellID = data.spellID
    self.Dungeon:SetText(data.info.name)
    self.Zone:SetText(data.info.parentName)

    if data.isKnown then
        self.Dungeon:SetTextColor(0.784, 0.270, 0.980)
        self.Zone:SetTextColor(0.784, 0.270, 0.980)
    else
        self.Dungeon:SetTextColor(0.66, 0.66, 0.66, 1)
        self.Zone:SetTextColor(0.66, 0.66, 0.66, 1)
    end
    self.Icon:SetSpell(self.spellID, data.isKnown)
end


--[[------------------------------------------------------------------------]]--

LiteKeystoneTeleportInfoMixin = {}

function LiteKeystoneTeleportInfoMixin:Update()
    local teleports = GetTeleports()
    local dp = CreateTreeDataProvider()
    local subTrees = {}
    for _, t in ipairs(teleports) do
        if t.isKnown or self.ShowAll:GetChecked() then
            if not subTrees[t.info.continentName] then
                local data = {
                    isCategory = true,
                    name = t.info.continentName
                }
                subTrees[t.info.continentName] = dp:Insert(data)
            end
            subTrees[t.info.continentName]:Insert(t)
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
    self.ShowAll:SetScript('OnClick', function () self:Update() end)
end

function LiteKeystoneTeleportInfoMixin:OnShow()
    self:Update()
end
