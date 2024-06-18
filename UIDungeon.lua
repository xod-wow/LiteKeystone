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
            local spellDescription = GetSpellDescription(spellID)
            if spellDescription and spellDescription:find(mapName) then
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
        if #gains > 5 then break end
        local fakeKey = { mapID = self.dungeon.mapID, keyLevel = i }
        local gain = LiteKeystone:GetRatingIncreaseForTimingKey(fakeKey)
        if gain > 0 then
            table.insert(gains, { i, format('+%d', math.floor(gain+0.5)) })
        end
    end

    if next(gains) == nil then return end

    local baseAffixID = C_MythicPlus.GetCurrentAffixes()[1].id
    local baseAffixName = C_ChallengeMode.GetAffixInfo(baseAffixID)

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", self, "RIGHT", -30, 0)
    GameTooltip:AddLine(self.dungeon.mapName)
    GameTooltip:AddLine(" ")
    for i, info in ipairs(gains) do
        GameTooltip:AddDoubleLine(baseAffixName .. ' +' .. info[1], format(PVP_RATING_CHANGE, info[2]), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

function LiteKeystoneDungeonButtonMixin:OnLeave()
    GameTooltip:Hide()
end

function LiteKeystoneDungeonButtonMixin:OnLoad()
    self.TeleportButton:RegisterForClicks('AnyDown', 'AnyUp')
    self.TeleportButton:SetAttribute("pressAndHoldAction", true)
    self.TeleportButton:SetAttribute("type", "spell")
    self.TeleportButton:SetAttribute("typerelease", "spell")
    self.TeleportButton.cooldown:SetCountdownFont("GameFontHighlightSmall")
end

function LiteKeystoneDungeonButtonMixin:UpdateCooldown()
    if self.TeleportButton.spellID then
        local cooldown = self.TeleportButton.cooldown
        local start, duration, enable, modRate = GetSpellCooldown(self.TeleportButton.spellID)
        if cooldown and start and duration then
            if enable then
                cooldown:Hide();
            else
                cooldown:Show();
            end
            CooldownFrame_Set(cooldown, start, duration, enable, false, modRate);
        else
            cooldown:Hide();
        end
    end
end

function LiteKeystoneDungeonButtonMixin:Update(index)
    if not self.dungeon then
        self:Hide()
    else
        self.Map:SetText(self.dungeon.mapName)
        self.OverallScore:SetText(self.dungeon.overallScore)
        local fort, tyr = self.dungeon.scores.Fortified, self.dungeon.scores.Tyrannical
        self.FortifiedLevel:SetText(fort and fort.level or "")
        self.FortifiedScore:SetText(fort and fort.score or "")
        self.TyrannicalLevel:SetText(tyr and tyr.level or "")
        self.TyrannicalScore:SetText(tyr and tyr.score or "")
        self.Stripe:SetShown(index % 2 == 1)
        local spellID, isKnown = FindTeleportSpell(self.dungeon.mapName)
        if spellID and isKnown then
            self.TeleportButton.spellID = spellID
            local _, _, tex = GetSpellInfo(spellID)
            self.TeleportButton:SetNormalTexture(tex)
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
