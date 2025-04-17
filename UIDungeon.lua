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

local function FindTeleportSpell(mapName)
    for i = 1, GetNumFlyouts() do
        local flyoutID = GetFlyoutID(i)
        local _, _, numSlots, isKnownFlyout = GetFlyoutInfo(flyoutID)
        if isKnownFlyout then
            for slot = 1, numSlots do
                local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, slot)
                local spellDescription = C_Spell.GetSpellDescription(spellID)
                if isKnown and spellDescription and spellDescription:find(mapName, nil, true) then
                    return spellID
                end
            end
        end
    end
end

--[[------------------------------------------------------------------------]]--

LiteKeystoneDungeonButtonMixin = {}

function LiteKeystoneDungeonButtonMixin:OnEnter()
    local gains = {}
    for i = 2, 27 do
        if #gains >= 10 then break end
        local fakeKey = { mapID = self.dungeon.mapID, keyLevel = i }
        local gain = LiteKeystone:GetRatingIncreaseForTimingKey(fakeKey)
        if gain > 0 then
            table.insert(gains, { i, format('+%d', math.floor(gain+0.5)) })
        end
    end

    if next(gains) == nil then return end

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", self, "RIGHT", -30, 0)
    GameTooltip:AddLine(self.dungeon.mapName)
    GameTooltip:AddLine(" ")
    for i, info in ipairs(gains) do
        GameTooltip:AddDoubleLine('+' .. info[1], format(PVP_RATING_CHANGE, info[2]), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

function LiteKeystoneDungeonButtonMixin:OnLeave()
    GameTooltip:Hide()
end

function LiteKeystoneDungeonButtonMixin:OnLoad()
    self.TeleportButton:RegisterForClicks('AnyUp')
    self.TeleportButton:SetAttribute("pressAndHoldAction", true)
    self.TeleportButton:SetAttribute("type", "spell")
    self.TeleportButton:SetAttribute("typerelease", "spell")
    self.TeleportButton.cooldown:SetCountdownFont("GameFontHighlightSmall")
end

function LiteKeystoneDungeonButtonMixin:UpdateCooldown()
    if self.TeleportButton.spellID then
        local cooldown = self.TeleportButton.cooldown
        local info = C_Spell.GetSpellCooldown(self.TeleportButton.spellID)
        if info then
            CooldownFrame_Set(cooldown, info.startTime, info.duration, info.isEnabled, false, info.modRate)
        else
            cooldown:Hide();
        end
    end
end

local DurationFormatter = CreateFromMixins(SecondsFormatterMixin)
DurationFormatter:Init(0, SecondsFormatter.Abbreviation.OneLetter, false, true, true)
DurationFormatter:SetStripIntervalWhitespace(true)

function LiteKeystoneDungeonButtonMixin:Initialize(dungeon)
    self.dungeon = dungeon

    self.Map:SetText(dungeon.mapName)
    self.OverallScore:SetText(dungeon.overallScore)
    self.KeyLevel:SetText(dungeon.level)
    if dungeon.durationSec then
        local timeText = DurationFormatter:Format(dungeon.durationSec)
        self.KeyTimer:SetText(timeText)
        local diff = dungeon.durationSec - dungeon.mapTimer
        local diffText
        if diff < 0 then
            diffText = '-' .. DurationFormatter:Format(-diff)
        else
            diffText = '+' .. DurationFormatter:Format(diff)
        end
        self.KeyTimerDiff:SetText(diffText)
    else
        self.KeyTimer:SetText(nil)
        self.KeyTimerDiff:SetText(nil)
    end
    self.MapTimer:SetText(DurationFormatter:Format(dungeon.mapTimer))
    local spellID = FindTeleportSpell(dungeon.mapName)
    if spellID then
        self.TeleportButton.spellID = spellID
        local info = C_Spell.GetSpellInfo(spellID)
        self.TeleportButton:SetNormalTexture(info.iconID)
        self.TeleportButton:SetAttribute("spell", spellID)
        self:UpdateCooldown()
        self.TeleportButton:Show()
    else
        self.TeleportButton:Hide()
    end
end

LiteKeystoneDungeonInfoMixin = {}

function LiteKeystoneDungeonInfoMixin:Update()
    local dungeons = LiteKeystone:SortedDungeons()
    local dp = CreateDataProvider(dungeons)
    self.ScrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
end

function LiteKeystoneDungeonInfoMixin:OnLoad()
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("LiteKeystoneDungeonButtonTemplate",
        function (button, elementData)
            button:Initialize(elementData)
        end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    ScrollUtil.RegisterAlternateRowBehavior(self.ScrollBox,
        function (button, isAlternate)
            button.Stripe:SetShown(isAlternate)
        end)
end

function LiteKeystoneDungeonInfoMixin:OnShow()
    self:Update()
end
