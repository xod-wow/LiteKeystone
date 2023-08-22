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

local function GetRunHistoryText()
    local runLevels = {}
    for _, info in ipairs(C_MythicPlus.GetRunHistory(false, true)) do
        table.insert(runLevels, info.level)
    end
    table.sort(runLevels, function (a, b) return a > b end)
    for i = 9, #runLevels do runLevels[i] = nil end
    return table.concat(runLevels, ' ')
end

LiteKeystoneDungeonInfoMixin = {}

function LiteKeystoneDungeonInfoMixin:Update()
    UpdateDungeonScroll(self.Scroll)

    local dungeonScore = C_ChallengeMode.GetOverallDungeonScore() or 0

    local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore)
    self.OverallScore:SetVertexColor(color.r, color.g, color.b)
    self.OverallScore:SetText(dungeonScore)

    local runHistory = GetRunHistoryText()
    self.RunHistory:SetText(runHistory)
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

    self.RunHistoryTitle:SetText(string.format(WEEKLY_REWARDS_MYTHIC_TOP_RUNS, 8))
end

function LiteKeystoneDungeonInfoMixin:OnShow()
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    C_MythicPlus.RequestMapInfo()
    self:Update()
end

function LiteKeystoneDungeonInfoMixin:OnHide()
    self:UnregisterAllEvents()
end

function LiteKeystoneDungeonInfoMixin:OnEvent(event, ...)
    self:Update()
end
