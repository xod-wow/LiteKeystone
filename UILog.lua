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

LiteKeystoneLogInfoMixin = {}

function LiteKeystoneLogInfoMixin:Update()
    local text = table.concat(LiteKeystone.messageLog, "\n")
    local editBox = self.EditScroll:GetEditBox()
    if text ~= editBox:GetText() then
        local scrollBox = self.EditScroll:GetScrollBox()
        local atEnd = scrollBox:IsAtEnd()
        self.EditScroll:SetText(text)
        if atEnd then
            C_Timer.After(0, function () scrollBox:ScrollToEnd() end)
        end
    end
end

function LiteKeystoneLogInfoMixin:OnShow()
    self:Update()
    LiteKeystone:RegisterCallback(self, function () self:Update() end)
end

function LiteKeystoneLogInfoMixin:OnHide()
    LiteKeystone:UnregisterCallback(self)
end
