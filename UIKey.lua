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

LiteKeystoneKeyButtonMixin = {}

function LiteKeystoneKeyButtonMixin:Update(index)
    if not self.key then
        self:Hide()
    else
        self.Mine:SetText(self.key.source == 'mine' and '*' or '')
        self.PlayerName:SetText(LiteKeystone:GetPlayerName(self.key, true))
        local plus = LiteKeystone:GetRatingIncreaseForTimingKey(self.key)
        if plus > 0 then
            self.Keystone.Text:SetText(LiteKeystone:GetKeyText(self.key) .. ' + ' .. tostring(plus))
        else
            self.Keystone.Text:SetText(LiteKeystone:GetKeyText(self.key))
        end
        self.Rating:SetText(self.key.rating or '?')
        self.Stripe:SetShown(index % 2 == 1)
        self:Show()
    end
end

LiteKeystoneKeyInfoMixin = {}

local sortType = 'KEYLEVEL'

local function UpdateKeyScroll(self)
    local offset = HybridScrollFrame_GetOffset(self)

    local filterMethod
    if LiteKeystoneInfo.selectedTab == 1 then
        filterMethod = nil
    elseif LiteKeystoneInfo.selectedTab == 2 then
        filterMethod = 'IsGuildKey'
    elseif LiteKeystoneInfo.selectedTab == 3 then
        filterMethod = 'IsGroupKey'
    elseif LiteKeystoneInfo.selectedTab == 4 then
        filterMethod = 'IsMyKey'
    end

    local keys = LiteKeystone:SortedKeys(filterMethod, sortType)

    for i, button in ipairs(self.buttons) do
        button.key = keys[offset + i]
        button:Update(offset + i)
    end

    local totalHeight = self.buttonHeight * #keys
    local shownHeight = self.buttonHeight * #self.buttons
    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

function LiteKeystoneKeyInfoMixin:Update()
    UpdateKeyScroll(self.Scroll)
end

function LiteKeystoneKeyInfoMixin:OnLoad()
    HybridScrollFrame_CreateButtons(self.Scroll,
                                    "LiteKeystoneKeyButtonTemplate",
                                    0, -1, "TOPLEFT", "TOPLEFT",
                                    0, -1, "TOP", "BOTTOM")

    local w = self.Scroll:GetWidth()
    for _,b in ipairs(self.Scroll.buttons) do
        b:SetWidth(w)
    end

    self.Scroll.update = UpdateKeyScroll
end

function LiteKeystoneKeyInfoMixin:OnShow()
    LiteKeystone:UpdateKeyRatings()
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('RAID_ROSTER_UPDATE')
    LiteKeystone:RegisterCallback(self, function () self:Update() end)
    self:Update()
end

function LiteKeystoneKeyInfoMixin:OnHide()
    self:UnregisterAllEvents()
    LiteKeystone:UnregisterCallback(self)
end

function LiteKeystoneKeyInfoMixin:OnEvent(event, ...)
    self:Update()
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
    self:GetParent():GetParent():Update()
end
