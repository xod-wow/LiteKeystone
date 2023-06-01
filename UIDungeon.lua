--[[----------------------------------------------------------------------------

  Copyright 2011-2020 Mike Battersby

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

local function UpdateDungeonButton(self, index)
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
        self:Show()
    end
end

local function UpdateDungeonScroll(self)
    local offset = HybridScrollFrame_GetOffset(self)

    local dungeons = LiteKeystone:SortedDungeons()

    for i, button in ipairs(self.buttons) do
        button.dungeon = dungeons[offset + i]
        UpdateDungeonButton(button, offset + i)
    end

    local totalHeight = self.buttonHeight * #dungeons
    local shownHeight = self.buttonHeight * #self.buttons
    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

LiteKeystoneDungeonInfoMixin = {}

function LiteKeystoneDungeonInfoMixin:Update()
    UpdateDungeonScroll(self.Scroll)

    local dungeonScore = C_ChallengeMode.GetOverallDungeonScore() or 0

    local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore);
    self.OverallScore:SetVertexColor(color.r, color.g, color.b);
    self.OverallScore:SetText(dungeonScore)
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

function LiteKeystoneDungeonInfoMixin:OnHide()
end

function LiteKeystoneDungeonInfoMixin:OnEvent(event, ...)
    self:Update()
end
