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

    if self.TabLog then
        show = (self.selectedTab == 7)
        self.TabLog.leftSelectedTexture:SetShown(show)
        self.TabLog.midSelectedTexture:SetShown(show)
        self.TabLog.rightSelectedTexture:SetShown(show)
    end

    show = (self.selectedTab == 8)
    self.TabRight2.leftSelectedTexture:SetShown(show)
    self.TabRight2.midSelectedTexture:SetShown(show)
    self.TabRight2.rightSelectedTexture:SetShown(show)

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

function LiteKeystoneInfoMixin:UpdateScale()
    self:SetScale(LiteKeystone.db.uiScale)
end

function LiteKeystoneInfoMixin:Update()
    self.Key:Hide()
    self.Log:Hide()
    self.Dungeon:Hide()
    self.Teleport:Hide()

    if self.selectedTab == 7 then
        self.Log:Show()
        self.Log:Update()
    elseif self.selectedTab == 8 then
        self.Teleport:Show()
        self.Teleport:Update()
    elseif self.selectedTab == 9 then
        self.Dungeon:Show()
        self.Dungeon:Update()
    else
        self.Key:Show()
        self.Key:Update()
        self.AnnounceButton:Show()
    end

    self.AnnounceButton:SetShown(tContains({2,3,4}, self.selectedTab))

    self:UpdateTabs()

    self:UpdateAffixes()
    self:UpdateDungeonScore()
    self:UpdateRunHistory()
    self:UpdateActivities()
end

function LiteKeystoneInfoMixin:GetAffixFrame(i)
    -- I am assuming these are in order
    for _, frame in ipairs(self.AffixesContainer:GetLayoutChildren()) do
        if frame.layoutIndex == i then
            return frame
        end
    end

    local frame = CreateFrame("FRAME", nil, self.AffixesContainer)
    frame:SetSize(250, 16)
    frame:SetScript('OnEnter',
        function (...)
            ChallengeMode_LoadUI()
            ChallengesKeystoneFrameAffixMixin.OnEnter(...)
        end)
    frame:SetScript('OnLeave', GameTooltip_Hide)
    frame.portrait = frame:CreateTexture();
    frame.portrait:SetSize(16, 16)
    frame.portrait:SetPoint("LEFT", frame, "LEFT", 32, 0)
    frame.level = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.level:SetPoint("RIGHT", frame.portrait, "LEFT", -6, 0)
    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.text:SetPoint("LEFT", frame.portrait, "RIGHT", 8, 0)
    frame.layoutIndex = i
    frame.align = "center"
    self.AffixesContainer:Layout()
    return frame
end

local AffixKeyLevel = { [1] = 4, [2] = 7, [3] = 10, [4] = 12 }

function LiteKeystoneInfoMixin:UpdateAffixes()
    -- see ChallengesFrameWeeklyInfoMixin:SetUp
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if affixes then
        for i, info in ipairs(affixes) do
            local frame = self:GetAffixFrame(i)
            frame.affixID = info.id
            local name, _, filedataid = C_ChallengeMode.GetAffixInfo(info.id);
            frame.portrait:SetTexture(filedataid)
            frame.text:SetText(name)
            frame.level:SetText(format('+%d', AffixKeyLevel[i]))
        end
    end
end

function LiteKeystoneInfoMixin:OnLoad()
    -- Stop you from dragging it off the screen where you can't get it back. Or worse,
    -- rescale doing it for you.
    local w, h = self:GetSize()
    self:SetClampRectInsets(0.75*w, -0.75*w, 24, h-24)
    self:SetClampedToScreen(true)

    tinsert(UISpecialFrames, self:GetName())
    self.selectedTab = 1

    -- The tooltips piggyback on Blizzard's code via WeeklyRewardsActivityMixin
    C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")

    -- SetupRunHistory
    self.RunHistoryTitle:SetText(string.format(WEEKLY_REWARDS_MYTHIC_TOP_RUNS, 8))

    -- SetupAffixes
    self:RegisterEvent('MYTHIC_PLUS_CURRENT_AFFIX_UPDATE')
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
    self:UpdateScale()
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()
    LiteKeystone:RequestData()
    LiteKeystone:UpdateKeyRatings()
    self:Update()
end

function LiteKeystoneInfoMixin:OnHide()
    self:UnregisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
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
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore) or HIGHLIGHT_FONT_COLOR
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
            local itemLevel = itemLink and C_Item.GetDetailedItemLevelInfo(itemLink)
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
    if event == 'MYTHIC_PLUS_CURRENT_AFFIX_UPDATE' then
        self:UpdateAffixes()
    else
        self:Update()
    end
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

