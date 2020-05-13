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

local function UpdateButton(self, index)
    if not self.key then
        self:Hide()
    else
        self.Mine:SetText(self.key.source == 'mine' and '*' or '')
        self.PlayerName:SetText(LiteKeystone:GetPlayerName(self.key, true))
        self.Keystone.Text:SetText(LiteKeystone:GetKeystone(self.key))
        self.WeekBest:SetText(self.key.weekBest)

        self.Stripe:SetShown(index % 2 == 1)
        self:Show()
    end
end

local function Update(self)
    local offset = HybridScrollFrame_GetOffset(self)
    local keys = LiteKeystone:SortedKeys('IsMyGuildKey')

    for i, button in ipairs(self.buttons) do
        button.key = keys[offset + i]
        UpdateButton(button, offset + i)
    end

    local totalHeight = self.buttonHeight * #keys
    local shownHeight = self.buttonHeight * #self.buttons
    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

LiteKeystoneInfoMixin = {}

function LiteKeystoneInfoMixin:OnLoad()
    self:SetBackdropColor(0, 0, 0, 1)
    tinsert(UISpecialFrames, self:GetName())

    HybridScrollFrame_CreateButtons(self.Scroll,
                                    "LiteKeystoneInfoButtonTemplate",
                                    0, -1, "TOPLEFT", "TOPLEFT",
                                    0, -1, "TOP", "BOTTOM")

    local w = self.Scroll:GetWidth()
    for _,b in ipairs(self.Scroll.buttons) do
        b:SetWidth(w)
    end

    self.Scroll.update = Update
end

function LiteKeystoneInfoMixin:OnShow()
    Update(self.Scroll)
end
