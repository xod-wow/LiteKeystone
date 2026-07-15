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

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

local function OnClick(_self, _mouseButton)
    local shown = LiteKeystoneInfo:IsShown()
    LiteKeystoneInfo:SetShown(not shown)
end

local function OnTooltipShow(tooltip)
    local score = C_ChallengeMode.GetOverallDungeonScore()
    tooltip:AddDoubleLine("LiteKeystone", score, 1, 1, 1)
    for _, dungeon in ipairs(LiteKeystone:SortedDungeons()) do
        tooltip:AddDoubleLine(dungeon.mapName, dungeon.level or "-")
    end
end

local dataSpec = {
    type            = "data source",
    text            = NONE,
    label           = "LK",
    icon            = "Interface\\Icons\\Inv_relics_hourglass",
    OnClick         = OnClick,
    OnTooltipShow   = OnTooltipShow,
}

local dataObj = ldb:NewDataObject("LiteKeystone", dataSpec)

local function Update()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if mapID then
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        dataObj.text = string.format("%s (%d)", name, level)
    else
        dataObj.text = NONE
    end
end

EventUtil.ContinueOnPlayerLogin(
    function ()
        LiteKeystone:RegisterCallback(dataObj, Update)
    end)
