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
        local numSlots = select(3, GetFlyoutInfo(flyoutID))
        for slot = 1, numSlots do
            local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, slot)
            local spellDescription = C_Spell.GetSpellDescription(spellID)
            if spellDescription and spellDescription:find(mapName, nil, true) then
                return spellID, isKnown
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
DurationFormatter:Init(SECONDS_PER_MIN, SecondsFormatter.Abbreviation.OneLetter, false)
DurationFormatter:SetStripIntervalWhitespace(true)

function LiteKeystoneDungeonButtonMixin:Update(index)
    if not self.dungeon then
        self:Hide()
    else
        self.Map:SetText(self.dungeon.mapName)
        self.OverallScore:SetText(self.dungeon.overallScore)
        self.KeyLevel:SetText(self.dungeon.level)
        if self.dungeon.durationSec then
            local timeText = DurationFormatter:Format(self.dungeon.durationSec)
            local diff = self.dungeon.durationSec - self.dungeon.mapTimer
            local diffText = DurationFormatter:Format(diff)
            local text = format('%s (%ds)', timeText, diff)
            self.KeyTimer:SetText(text)
        else
            self.KeyTimer:SetText(nil)
        end
        self.MapTimer:SetText(DurationFormatter:Format(self.dungeon.mapTimer))
        self.Stripe:SetShown(index % 2 == 1)
        local spellID, isKnown = FindTeleportSpell(self.dungeon.mapName)
        if spellID and isKnown then
            self.TeleportButton.spellID = spellID
            local info = C_Spell.GetSpellInfo(spellID)
            self.TeleportButton:SetNormalTexture(info.iconID)
            self.TeleportButton:SetAttribute("spell", spellID)
            self:UpdateCooldown()
            self.TeleportButton:Show()
        else
            self.TeleportButton:Hide()
        end
        self:Show()
    end
end

local function UpdateDungeonScroll(self)
    local offset = HybridScrollFrame_GetOffset(self)

    local dungeons = LiteKeystone:SortedDungeons()

    for i, button in ipairs(self.buttons) do
        button.dungeon = dungeons[offset + i]
        button:Update(offset+i)
    end

    local totalHeight = self.buttonHeight * #dungeons
    local shownHeight = self.buttonHeight * #self.buttons
    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

LiteKeystoneDungeonInfoMixin = {}

function LiteKeystoneDungeonInfoMixin:Update()
    UpdateDungeonScroll(self.Scroll)
end

function LiteKeystoneDungeonInfoMixin:OnLoad()
    HybridScrollFrame_CreateButtons(self.Scroll,
                                    "LiteKeystoneDungeonButtonTemplate",
                                    0, -1, "TOPLEFT", "TOPLEFT",
                                    0, -1, "TOP", "BOTTOM")

    local w = self.Scroll:GetWidth()
    for _,b in ipairs(self.Scroll.buttons) do
        b:SetWidth(w)
    end

    self.Scroll.update = UpdateDungeonScroll
end

function LiteKeystoneDungeonInfoMixin:OnShow()
    self:Update()
end
