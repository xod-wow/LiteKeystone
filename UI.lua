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

LiteKeystoneInfoMixin = {}

function LiteKeystoneInfoMixin:UpdateTabs()
    local show = (self.selectedTab == 1)
    self.Tab1.leftSelectedTexture:SetShown(show)
    self.Tab1.midSelectedTexture:SetShown(show)
    self.Tab1.rightSelectedTexture:SetShown(show)

    show = (self.selectedTab == 2)
    self.Tab2.leftSelectedTexture:SetShown(show)
    self.Tab2.midSelectedTexture:SetShown(show)
    self.Tab2.rightSelectedTexture:SetShown(show)

    show = (self.selectedTab == 3)
    self.Tab3.leftSelectedTexture:SetShown(show)
    self.Tab3.midSelectedTexture:SetShown(show)
    self.Tab3.rightSelectedTexture:SetShown(show)

    show = (self.selectedTab == 4)
    self.Tab4.leftSelectedTexture:SetShown(show)
    self.Tab4.midSelectedTexture:SetShown(show)
    self.Tab4.rightSelectedTexture:SetShown(show)

    show = (self.selectedTab == 9)
    self.TabRight.leftSelectedTexture:SetShown(show)
    self.TabRight.midSelectedTexture:SetShown(show)
    self.TabRight.rightSelectedTexture:SetShown(show)
end

function LiteKeystoneInfoMixin:GetFilterMethod()
    if self.selectedTab == 2 then
        return 'IsGuildKey'
    elseif self.selectedTab == 3 then
        return 'IsGroupKey'
    elseif self.selectedTab == 4 then
        return 'IsMyKey'
    end
end

function LiteKeystoneInfoMixin:Update()
    if self.selectedTab == 9 then
        self.Key:Hide()
        self.Dungeon:Show()
        self.Dungeon:Update()
    else
        self.Dungeon:Hide()
        self.Key:Show()
        self.Key:Update()
        self.AnnounceButton:Show()
    end

    self.AnnounceButton:SetShown(tContains({2,3,4}, self.selectedTab))

    self:UpdateTabs()

    self:UpdateDungeonScore()
    self:UpdateRunHistory()
    self:UpdateActivities()

end

function LiteKeystoneInfoMixin:SetupAffixes()
    -- SetupAffixes, see ChallengesFrameWeeklyInfoMixin:SetUp
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if affixes then
        for i, info in ipairs(affixes) do
            local frame = CreateFrame("FRAME", nil, self.AffixesContainer)
            frame.affixID = info.id
            frame:SetSize(16, 16)
            frame:SetScript('OnEnter',
                function (...)
                    ChallengeMode_LoadUI()
                    ChallengesKeystoneFrameAffixMixin.OnEnter(...)
                end)
            frame:SetScript('OnLeave', GameTooltip_Hide)
            local name, _, filedataid = C_ChallengeMode.GetAffixInfo(info.id);
            local portrait = frame:CreateTexture();
            portrait:SetAllPoints()
            portrait:SetTexture(filedataid)
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            text:SetPoint("LEFT", frame, "RIGHT", 6, 0)
            text:SetText(name)
            frame.layoutIndex = i
            frame.align = "center"
        end
        self.AffixesContainer:Layout()
    end
end

function LiteKeystoneInfoMixin:OnLoad()
    tinsert(UISpecialFrames, self:GetName())
    self.selectedTab = 1

    -- The tooltips piggyback on Blizzard's code but unless the frame is shown
    -- they don't hide the expiration warning which is visible=true by default.
    WeeklyRewards_LoadUI()
    WeeklyRewardExpirationWarningDialog:Hide()

    -- SetupRunHistory
    self.RunHistoryTitle:SetText(string.format(WEEKLY_REWARDS_MYTHIC_TOP_RUNS, 8))

    -- SetupAffixes
    EventUtil.RegisterOnceFrameEventAndCallback('MYTHIC_PLUS_CURRENT_AFFIX_UPDATE', function () self:SetupAffixes() end)
    C_MythicPlus.RequestCurrentAffixes()

    -- SetupActivities
    for i = 1,3 do
        local frame = CreateFrame("FRAME", nil, self, "LiteKeystoneActivityTemplate")
        -- Can't do this in the XML as WeeklyRewards not loaded yet
        Mixin(frame, WeeklyRewardsActivityMixin)
        if i == 1 then
            frame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 20, 16)
        else
            -- Because there's a parentArray in the template as frames are created they
            -- are automatically appended to the Activities array.
            frame:SetPoint("BOTTOMLEFT", self.Activities[i-1], "TOPLEFT", 0, 0)
        end
    end

end

function LiteKeystoneInfoMixin:OnShow()
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    C_MythicPlus.RequestMapInfo()
    self:Update()
    LiteKeystone:UpdateKeyRatings()
    self:Update()
end

function LiteKeystoneInfoMixin:OnHide()
    self:UnregisterAllEvents()
end

local RunColors = {
    BLUE_FONT_COLOR,
    GREEN_FONT_COLOR,
    GREEN_FONT_COLOR,
    GREEN_FONT_COLOR,
    YELLOW_FONT_COLOR,
    YELLOW_FONT_COLOR,
    YELLOW_FONT_COLOR,
    YELLOW_FONT_COLOR,
}

local function GetRunHistoryText()
    local runLevels = {}
    for _, info in ipairs(C_MythicPlus.GetRunHistory(false, true)) do
        table.insert(runLevels, info.level)
    end
    table.sort(runLevels, function (a, b) return a > b end)
    for i = 9, #runLevels do runLevels[i] = nil end
    for i = 1, 8 do
        runLevels[i] = RunColors[i]:WrapTextInColorCode(runLevels[i] or 'x')
    end
    return table.concat(runLevels, ' ')
end

function LiteKeystoneInfoMixin:UpdateDungeonScore()
    local dungeonScore = C_ChallengeMode.GetOverallDungeonScore() or 0
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore)
    self.OverallScore:SetVertexColor(color.r, color.g, color.b)
    self.OverallScore:SetText(dungeonScore)
end

function LiteKeystoneInfoMixin:UpdateRunHistory()
    local runHistory = GetRunHistoryText()
    self.RunHistory:SetText(runHistory)
end

function LiteKeystoneInfoMixin:UpdateActivities()
    local activityType = Enum.WeeklyRewardChestThresholdType.Activities
    local activities = C_WeeklyRewards.GetActivities(activityType)
    local runs = C_MythicPlus.GetRunHistory(false, true)

    for i, info in ipairs(activities) do
        local frame = self.Activities[i]
        frame.info = info
        frame.Threshold:SetFormattedText(WEEKLY_REWARDS_THRESHOLD_MYTHIC, info.threshold)
        if #runs >= info.threshold then
            frame.Progress:SetFormattedText('+%d', info.level)
            local itemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(info.id)
            local itemLevel = itemLink and GetDetailedItemLevelInfo(itemLink)
            if itemLevel then
                frame.ItemLevel:SetFormattedText("%d", itemLevel or 0)
            else
                frame.ItemLevel:SetText("")
            end
        else
            frame.Progress:SetFormattedText(GENERIC_FRACTION_STRING, #runs, info.threshold)
            frame.ItemLevel:SetText("")
        end
    end
end

function LiteKeystoneInfoMixin:OnEvent(event, ...)
    self:Update()
end

function LiteKeystoneInfoMixin:Announce()
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        LiteKeystone:ReportKeys(self:GetFilterMethod(), "PARTY")
    else
        LiteKeystone:ReportKeys(self:GetFilterMethod(), "GUILD")
    end
end

LiteKeystoneTabButtonMixin = {}

function LiteKeystoneTabButtonMixin:OnLoad()
    self:RegisterForClicks('AnyUp')
    self:RegisterForDrag('LeftButton')
end

function LiteKeystoneTabButtonMixin:OnClick()
    local parent = self:GetParent()
    parent.selectedTab = self:GetID()
    parent:Update()
end

