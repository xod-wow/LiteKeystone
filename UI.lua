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
        self.Key:Hide()
        self.Dungeon:Show()
        self.Dungeon:Update()
    else
        self.Dungeon:Hide()
        self.Key:Show()
        self.Key:Update()
    end
    self:UpdateTabs()
end

function LiteKeystoneInfoMixin:OnLoad()
    tinsert(UISpecialFrames, self:GetName())
    self.selectedTab = 1
end

function LiteKeystoneInfoMixin:OnShow()
    LiteKeystone:UpdateKeyRatings()
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
