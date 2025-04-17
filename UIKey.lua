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

function LiteKeystoneKeyButtonMixin:Initialize(key)
    self.key = key

    self.Mine:SetText(key.source == 'mine' and '*' or '')
    self.PlayerName:SetText(LiteKeystone:GetPlayerName(key, true))
    local plus = LiteKeystone:GetRatingIncreaseForTimingKey(key)
    if plus > 0 then
        self.Keystone.Text:SetText(LiteKeystone:GetKeyText(key) .. ' + ' .. tostring(plus))
    else
        self.Keystone.Text:SetText(LiteKeystone:GetKeyText(key))
    end
    self.Rating:SetText(key.rating or '?')
end

function LiteKeystoneKeyButtonMixin:OnClick()
    if mouseButton == 'LeftButton' and IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(LiteKeystone:GetKeyText(self.key))
    end
end

LiteKeystoneKeyInfoMixin = {}

local sortType = 'KEYLEVEL'

function LiteKeystoneKeyInfoMixin:Update()
    LiteKeystone:UpdateKeyRatings()
    local keys = LiteKeystone:SortedKeys(LiteKeystoneInfo:GetFilterMethod(), sortType)
    local dp = CreateDataProvider(keys)
    self.ScrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
end

function LiteKeystoneKeyInfoMixin:OnLoad()
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("LiteKeystoneKeyButtonTemplate",
        function (button, elementData)
            button:Initialize(elementData)
        end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    ScrollUtil.RegisterAlternateRowBehavior(self.ScrollBox,
        function (button, isAlternate)
            button.Stripe:SetShown(isAlternate)
        end)
end

function LiteKeystoneKeyInfoMixin:OnShow()
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('RAID_ROSTER_UPDATE')
    LiteKeystone:RegisterCallback(self, function () self:Update() end)
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
