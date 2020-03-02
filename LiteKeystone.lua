--[[----------------------------------------------------------------------------

  LiteKeystone/LiteKeystone.lua

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

LiteKeystone = CreateFrame('Frame')
LiteKeystone:SetScript('OnEvent',
        function (self, e, ...)
            if self[e] then self[e](self, ...) end
        end)
LiteKeystone:RegisterEvent('PLAYER_LOGIN')

local printTag = ORANGE_FONT_COLOR_CODE.."LiteKeystone: "..FONT_COLOR_CODE_CLOSE

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

function LiteKeystone:SlashCommand(arg)
    local arg1, arg2 = string.split(' ', arg)
    local n = arg1:len()

    if  arg1 == '' or arg1 == ('list'):sub(1,n) then
        self:PrintKeys()
        return true
    end

    if arg1 == ('push'):sub(1,n) then
        self:SendAstralKey()
        return true
    end

    if arg1 == ('request'):sub(1,n) then
        self:RequestKeysFromGuild()
        return true
    end

    if arg1 == ('send'):sub(1,n) and arg2 then
        n = arg2:len()
        if arg2 == ('guild'):sub(1,n) then
            self:PrintKeys('GUILD')
        elseif arg2 == ('party'):sub(1,n) then
            self:PrintKeys('PARTY')
        elseif arg2 == ('say'):sub(1,n) then
            self:PrintKeys('SAY')
        else
            self:PrintKeys('WHISPER', arg2)
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

function LiteKeystone:Initialize()

    LiteKeystoneDB = LiteKeystoneDB or {}
    self.db = LiteKeystoneDB
    self.db.playerKeys = self.db.playerKeys or {}

    SlashCmdList.LiteKeystone = function (...) self:SlashCommand(...) end
    _G.SLASH_LiteKeystone1 = "/litekeystone"
    _G.SLASH_LiteKeystone2 = "/lk"

    self.playerName = string.join('-', UnitFullName('player'))
    self.playerClass = select(2, UnitClass('player'))

    if UnitFactionGroup('player') == 'Alliance' then
        self.playerFaction = 0
    else
        self.playerFaction = 1
    end

    self:RemoveExpiredKeys()

    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()
    C_MythicPlus.RequestRewards()

    C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')

    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('BN_CHAT_MSG_ADDON')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
    self:RegisterEvent('MYTHIC_PLUS_CURRENT_AFFIX_UPDATE')
    self:RegisterEvent('ITEM_PUSH')

    self:ScanForKey()

    printf('Initialized.')
end

function LiteKeystone:Reset()
    table.wipe(self.db.playerKeys)
    self:ScanForKey()
end

function LiteKeystone:ScanForKey()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return end

    local weekBest, weekItemLevel = C_MythicPlus.GetWeeklyChestRewardLevel()
    if weekBest == 0 and weekItemLevel < 0 then return end

    local keyLevel =  C_MythicPlus.GetOwnedKeystoneLevel()

    if C_MythicPlus.IsWeeklyRewardAvailable() then
        weekBest = 0
    end

    self.db.playerKeys[self.playerName] = {
            playerName=self.playerName,
            playerClass=self.playerClass,
            playerFaction=self.playerFaction,
            mapID=tonumber(mapID),
            keyLevel=tonumber(keyLevel),
            weekBest=tonumber(weekBest),
            weekTime=WeekTime(),
            source='mine'
        }
end

function LiteKeystone:GetKeyUpdateString(key)
    return format('%s:%s:%d:%d:%d:%d:%s',
                   key.playerName,
                   key.playerClass,
                   key.mapID,
                   key.keyLevel,
                   key.weekBest,
                   key.weekNum,
                   key.playerFaction
                )
end

function LiteKeystone:GetKeySyncString(key)
    return format('%s:%s:%d:%d:%d:%d:%s',
                   key.playerName,
                   key.playerClass,
                   key.mapID,
                   key.keyLevel,
                   key.weekBest,
                   key.weekNum,
                   key.weekTime
                )
end

function LiteKeystone:RemoveExpiredKeys()
    for i = #self.db.playerKeys, 1, -1 do
        if self.db.playerKeys[i].weekTime >= 604800 then
            table.remove(self.db.playerKeys, i)
        end
    end
end

function LiteKeystone:SendAstralKey()
    local key = self.db.playerKeys[self.playerName]
    if key then
        local msg = 'updateV8 ' .. self:GetKeyUpdateString(key)
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
    end
end

function LiteKeystone:ReceiveAstralKey(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction = string.split(':', content)

    if not playerName then return end

    -- Don't accept our own keys back from other people
    if self.db.playerKeys[playerName] and
       self.db.playerKeys[playerName].source == 'mine' then
        return
    end

    local weekTime = WeekTime()

    playerFaction = tonumber(playerFaction)

    -- sync5 sends a weekTime in the last argument instead of faction
    if playerFaction > 1 then
        if self.db.playerKeys[playerName] and self.db.playerKeys[playerName].weekTime >= playerFaction then
            return
        end
        weekTime = playerFaction
        playerFaction = self.playerFaction
    end

    self.db.playerKeys[playerName] = {
            playerName=playerName,
            playerClass=playerClass,
            playerFaction=playerFaction,
            mapID=tonumber(mapID),
            keyLevel=tonumber(keyLevel),
            weekBest=tonumber(weekBest),
            weekTime=weekTime
        }

    if playerName ~= self.playerName then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        printf('Got key: %s %s (%d)', playerName, mapName, keyLevel)
    end
end

function LiteKeystone:GuildPush(recipient)
    local guildKeys = {}

    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if self.db.playerKeys[name] then
            local msg = GetKeySyncString(self.db.playerKeys[name])
            guildKeys.append(msg)
        end
    end
    if #guildKeys > 0 then
        local msg = 'sync5 ' .. string.join('_', guildKeys)
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'WHISPER', nil, recipient)
    end
end

function LiteKeystone:RequestKeysFromGuild()
    C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'GUILD')

    local numGuild, numGuildOnline = GetNumGuildMembers()
    for i = 1, numGuild do
        local n = GetGuildRosterInfo(i)
        C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'WHISPER', nil, n)
    end
end

function LiteKeystone:RequestKeysFromFriends()
    local numFriends, numFriendsOnline = BNGetNumFriends()
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
end

function LiteKeystone:GetAffixes()
    if not self.keystoneAffixes then
        self.keystoneAffixes = {}
        local affixInfo = C_MythicPlus.GetCurrentAffixes()
        for _, ai in ipairs(affixInfo) do
            table.insert(self.keystoneAffixes, ai.id)
        end
    end
    return self.keystoneAffixes
end

function LiteKeystone:GetPrintString(key, useColor)
    local mapName = C_ChallengeMode.GetMapUIInfo(key.mapID)

    local affixFormat
    if key.keyLevel > 9 then
        affixFormat = '%d:%d:%d:%d'
    elseif key.keyLevel > 6 then
        affixFormat = '%d:%d:%d:0'
    elseif key.keyLevel > 3 then
        affixFormat = '%d:%d:0:0'
    else
        affixFormat = '%d:0:0:0'
    end

    local affixes = self:GetAffixes()

    local affixString = string.format(affixFormat, unpack(affixes))

    local link = string.format(
            '|cffa335ee|Hkeystone:158923:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            key.mapID, key.keyLevel, affixString, mapName, key.keyLevel
        )

    local p = key.playerName:gsub('-'..GetRealmName(), '')
    if useColor then
        local c = RAID_CLASS_COLORS[key.playerClass]
        p = c:WrapTextInColorCode(p)
    end

    return string.format('%s : %s : best %d', p, link, key.weekBest)
end

function LiteKeystone:PrintKeys(chatType, chatArg)
    local sortedKeys = {}
    for k in pairs(self.db.playerKeys) do table.insert(sortedKeys, k) end
    table.sort(sortedKeys)

    for _, k in ipairs(sortedKeys) do
        local key = self.db.playerKeys[k]
        if chatType then
            local msg = self:GetPrintString(key)
            SendChatMessage(msg, chatType, nil, chatArg)
        else
            local msg = self:GetPrintString(key, true)
            printf(msg)
        end
    end
end

function LiteKeystone:ProcessAddonMessage(text, source)
    local action, content = text:match('^(%S+)%s+(.-)$')

    if action == 'updateV8' or action == 'update4' then
        self:ReceiveAstralKey(content, source)
    elseif action == 'sync5' then
        for entry in content:gmatch('[^_]+') do
            self:ReceiveAstralKey(entry, source)
        end
    end
end

function LiteKeystone:PLAYER_LOGIN()
    self:Initialize()
end

function LiteKeystone:CHAT_MSG_ADDON(prefix, text, chatType, sender)
    if prefix ~= 'AstralKeys' then return end
    -- print(format("%s - %s - %s - %s", prefix, text, chatType, sender))
    if chatType == 'WHISPER' or chatType == 'BN_WHISPER' then
        self:ProcessAddonMessage(text, sender)
    else
        self:ProcessAddonMessage(text, chatType)
    end
end

LiteKeystone.BN_CHAT_MSG_ADDON = LiteKeystone.CHAT_MSG_ADDON

function LiteKeystone:GUILD_ROSTER_UPDATE()
    local elapsed = GetServerTime() - (self.lastKeyBroadcast or 0)
    if elapsed > 30 then
        self.lastKeyBroadcast = GetServerTime()
        self:SendAstralKey()
    end
end

function LiteKeystone:CHALLENGE_MODE_COMPLETED()
    self:ScanForKey()
    self:SendAstralKey()
end

function LiteKeystone:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
    self:ScanForKey()
    self:SendAstralKey()
end

function LiteKeystone:ITEM_PUSH(bag, itemID)
    if itemID == 525134 then
        self:ScanForKey()
        self:SendAstralKey()
    end
end

