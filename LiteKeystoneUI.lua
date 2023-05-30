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

local sortType = 'KEYLEVEL'

local function UpdateKeyButton(self, index)
    if not self.key then
        self:Hide()
    else
        self.Mine:SetText(self.key.source == 'mine' and '*' or '')
        self.PlayerName:SetText(LiteKeystone:GetPlayerName(self.key, true))
        self.Keystone.Text:SetText(LiteKeystone:GetKeyText(self.key))
        self.Rating:SetText(self.key.rating or '?')
        self.Stripe:SetShown(index % 2 == 1)
        self:Show()
    end
end

local function UpdateKeyScroll(self)
    local offset = HybridScrollFrame_GetOffset(self)

    local filterMethod
    if self:GetParent().selectedTab == 1 then
        filterMethod = nil
    elseif self:GetParent().selectedTab == 2 then
        filterMethod = 'IsGuildKey'
    elseif self:GetParent().selectedTab == 3 then
        filterMethod = 'IsGroupKey'
    elseif self:GetParent().selectedTab == 4 then
        filterMethod = 'IsMyKey'
    end

    local keys = LiteKeystone:SortedKeys(filterMethod, sortType)

    for i, button in ipairs(self.buttons) do
        button.key = keys[offset + i]
        UpdateKeyButton(button, offset + i)
    end

    local totalHeight = self.buttonHeight * #keys
    local shownHeight = self.buttonHeight * #self.buttons
    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

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

function LiteKeystoneInfoMixin:Update()
    if self.selectedTab == 9 then
        self.Scroll:Hide()
        self.KeyHeader:Hide()
        self.DungeonScroll:Show()
        self.DungeonHeader:Show()
        UpdateDungeonScroll(self.DungeonScroll)
    else
        self.Scroll:Show()
        self.KeyHeader:Show()
        self.DungeonScroll:Hide()
        self.DungeonHeader:Hide()
        UpdateKeyScroll(self.Scroll)
    end
    self:UpdateTabs()
end

function LiteKeystoneInfoMixin:OnLoad()
    tinsert(UISpecialFrames, self:GetName())

    HybridScrollFrame_CreateButtons(self.Scroll,
                                    "LiteKeystoneKeyButtonTemplate",
                                    0, -1, "TOPLEFT", "TOPLEFT",
                                    0, -1, "TOP", "BOTTOM")

    local w = self.Scroll:GetWidth()
    for _,b in ipairs(self.Scroll.buttons) do
        b:SetWidth(w)
    end

    HybridScrollFrame_CreateButtons(self.DungeonScroll,
                                    "LiteKeystoneDungeonButtonTemplate",
                                    0, -1, "TOPLEFT", "TOPLEFT",
                                    0, -1, "TOP", "BOTTOM")

    local w = self.DungeonScroll:GetWidth()
    for _,b in ipairs(self.DungeonScroll.buttons) do
        b:SetWidth(w)
    end

    self.DungeonScroll.update = UpdateDungeonScroll

    self.selectedTab = 1
    self:UpdateTabs()
end

function LiteKeystoneInfoMixin:OnShow()
    LiteKeystone:UpdateKeyRatings()
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('RAID_ROSTER_UPDATE')
    LiteKeystone:RegisterCallback(self, function () self:Update() end)
    self:Update()
end

function LiteKeystoneInfoMixin:OnHide()
    self:UnregisterAllEvents()
    LiteKeystone:UnregisterCallback(self)
end

function LiteKeystoneInfoMixin:OnEvent(event, ...)
    self:Update()
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

LiteKeystoneKeyHeaderButtonMixin = {}

function LiteKeystoneKeyHeaderButtonMixin:OnClick()
    if self:GetText() == 'Keystone' then
        if sortType == 'KEYLEVEL' then
            sortType = 'KEYNAME'
        else
            sortType = 'KEYLEVEL'
        end
    elseif self:GetText() == 'Player' then
        sortType = 'PLAYERNAME'
    elseif self:GetText() == RATING then
        sortType = 'RATING'
    end
    LiteKeystoneInfo:Update()
end
