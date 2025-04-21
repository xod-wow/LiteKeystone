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
    local _, isKnown = self.Icon:FindAndSetSpell(dungeon.mapName)
    self.Icon:SetShown(isKnown)
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
