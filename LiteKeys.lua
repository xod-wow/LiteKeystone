--[[----------------------------------------------------------------------------

  LiteKeys/LiteKeys.lua

  Copyright 2011-2020 Mike Battersby

  LiteMount is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License, version 2, as published by
  the Free Software Foundation.

  LiteMount is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  The file LICENSE.txt included with LiteMount contains a copy of the
  license. If the LICENSE.txt file is missing, you can find a copy at
  http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

----------------------------------------------------------------------------]]--

LiteKeys = CreateFrame('Frame')
LiteKeys:SetScript('OnEvent',
        function (self, e, ...)
            if self[e] then self[e](self, ...) end
        end)
LiteKeys:RegisterEvent('PLAYER_LOGIN')

local printTag = ORANGE_FONT_COLOR_CODE.."LiteKeys: "..FONT_COLOR_CODE_CLOSE

local function printf(fmt, ...)
    local msg = string.format(fmt, ...)
    SELECTED_CHAT_FRAME:AddMessage(printTag .. msg)
end

local regionStartTimes = {
    [1] = 1500390000,   -- US
    [2] = 1500390000,   -- EU (says 1500447600 but doesn't use it)
    [3] = 1500505200,   -- CN
}

-- Astral Key's idea of the week number
local function WeekNum()
    local r = GetCurrentRegion()
    return math.floor( (GetServerTime() - regionStartTimes[r]) / 604800 )

end

-- How many seconds we are into the current keystone week
local function WeekTime()
    local r = GetCurrentRegion()
    return math.floor( (GetServerTime() - regionStartTimes[r] ) % 604800 )
end

function LiteKeys:SlashCommand(arg)
    local arg1, arg2 = string.split(' ', arg)
    local n = arg1:len()

    if  arg1 == '' or arg1 == ('list'):sub(1,n) then
        self:PrintAstralKeys()
        return true
    end

    if arg1 == ('push'):sub(1,n) then
        self:SendAstralKey()
        return true
    end

    if arg1 == ('request'):sub(1,n) then
        self:RequestKeysFromFriends()
        return true
    end

    if arg1 == ('send'):sub(1,n) and arg2 then
        n = arg2:len()
        if arg2 == ('guild'):sub(1,n) then
            self:PrintAstralKeys('GUILD')
        elseif arg2 == ('say'):sub(1,n) then
            self:PrintAstralKeys('SAY')
        else
            self:PrintAstralKeys('WHISPER', arg2)
        end
        return true
    end

    printf('Usage:')
    printf(' /lk list')
    printf(' /lk push')
    printf(' /lk request')
    printf(' /lk send guild')
    printf(' /lk send <player>')
    return true
end

function LiteKeys:PLAYER_LOGIN()

    LiteKeysDB = LiteKeysDB or {}
    self.db = LiteKeysDB

    SlashCmdList.LiteKeys = function (...) self:SlashCommand(...) end
    _G.SLASH_LiteKeys1 = "/litekeys"
    _G.SLASH_LiteKeys2 = "/lk"

    if UnitFactionGroup('player') == 'Alliance' then
        self.playerFaction = 0
    else
        self.playerFaction = 1
    end

    printf('Initialized.')

    self.db.astralKeys = self.db.astralKeys or {}

    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()
    C_MythicPlus.RequestRewards()

    C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')
    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('BN_CHAT_MSG_ADDON')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')

end

function LiteKeys:GetKeyInfo()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return end

    local weekBest, weekItemLevel = C_MythicPlus.GetWeeklyChestRewardLevel()
    if weekBest == 0 and weekItemLevel < 0 then return end

    local keyLevel =  C_MythicPlus.GetOwnedKeystoneLevel()

    if C_MythicPlus.IsWeeklyRewardAvailable() then
        weekBest = 0
    end

    local playerName = string.join('-', UnitFullName('player'))
    local playerClass = select(2, UnitClass('player'))

    return format('updateV8 %s:%s:%d:%d:%d:%d:%s',
                    playerName,
                    playerClass,
                    mapID,
                    keyLevel,
                    weekBest,
                    WeekNum(),
                    self.playerFaction
                )
end

function LiteKeys:SendAstralKey()
    local msg = self:GetKeyInfo()
    if msg then 
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
    end
end

function LiteKeys:ReceiveAstralKey(content)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction = string.split(':', content)

    if not playerName then return end

    local weekTime = WeekTime()

    playerFaction = tonumber(playerFaction)

    -- sync5 sends a weekTime in the last argument instead of faction
    if playerFaction > 1 then
        if self.db.astralKeys[playerName] and self.db.astralKeys[playerName].when >= playerFaction then
            return
        end
        weekTime = playerFaction
        playerFaction = self.playerFaction
    end

    self.db.astralKeys[playerName] = {
            playerName=playerName,
            playerClass=playerClass,
            playerFaction=playerFaction,
            mapID=tonumber(mapID),
            keyLevel=tonumber(keyLevel),
            weekBest=tonumber(weekBest),
            when=weekTime
        }

    local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
    printf('Got key: %s %s (%d)', playerName, mapName, keyLevel)
end

function LiteKeys:RequestKeysFromFriends()
    local numFriends, numFriendsOnline = BNGetNumFriends()

    C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'GUILD')

--[[
    for i = 1, BNGetNumFriends() do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'BN_WHISPER', nil, info.accountName)
    end

    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info.connected and not info.mobile then
            C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'WHISPER', nil, info.name)
        end
    end
]]
end

function LiteKeys:PrintAstralKeys(chatType, chatArg)
    if not self.keystoneAffixes then
        self.keystoneAffixes = {}
        local affixInfo = C_MythicPlus.GetCurrentAffixes()
        for _, ai in ipairs(affixInfo) do
            table.insert(self.keystoneAffixes, ai.id)
        end
    end

    local sortedKeys = {}
    for k in pairs(self.db.astralKeys) do table.insert(sortedKeys, k) end
    table.sort(sortedKeys)

    for _, k in ipairs(sortedKeys) do
        local info = self.db.astralKeys[k]
        local mapName = C_ChallengeMode.GetMapUIInfo(info.mapID)
        local affixFormat
        if info.keyLevel > 9 then
            affixFormat = '%d:%d:%d:%d'
        elseif info.keyLevel > 6 then
            affixFormat = '%d:%d:%d:0'
        elseif info.keyLevel > 3 then
            affixFormat = '%d:%d:0:0'
        else
            affixFormat = '%d:0:0:0'
        end
        local afstr = string.format(affixFormat, unpack(self.keystoneAffixes))
        local link = string.format(
                '|cffa335ee|Hkeystone:158923:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
                info.mapID, info.keyLevel, afstr, mapName, info.keyLevel
            )

        local p = info.playerName:gsub('-'..GetRealmName(), '')
        if not chatType then
            local c = RAID_CLASS_COLORS[info.playerClass]
            p = c:WrapTextInColorCode(p)
        end

        local msg = string.format('%s : %s : best %d', p, link, info.weekBest)

        if chatType then
            SendChatMessage(msg, chatType, nil, chatArg)
        else
            printf(msg)
        end
    end
end

function LiteKeys:CHAT_MSG_ADDON(prefix, text, chatType, sender)
    if prefix ~= 'AstralKeys' then return end

    -- print(format("%s - %s - %s - %s", prefix, text, chatType, sender))

    local action, content = text:match('^(%S+)%s+(.-)$')
    if action == 'updateV8' or action == 'update4' then
        self:ReceiveAstralKey(content)
    elseif action == 'sync5' then
        local entries = string.split('_', content)
        for entry in content:gmatch('[^_]+') do
            self:ReceiveAstralKey(entry)
        end
    end
end

LiteKeys.BN_CHAT_MSG_ADDON = LiteKeys.CHAT_MSG_ADDON

function LiteKeys:GUILD_ROSTER_UPDATE()
    local elapsed = GetServerTime() - (self.lastKeyBroadcast or 0)
    if elapsed > 30 then
        self.lastKeyBroadcast = GetServerTime()
        self:SendAstralKey()
    end
end

function LiteKeys:CHALLENGE_MODE_MAPS_UPDATE()
    self:SendAstralKey()
end

function LiteKeys:CHALLENGE_MODE_COMPLETED()
    self:SendAstralKey()
end

