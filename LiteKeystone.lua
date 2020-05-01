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

local factionLookup = {
    [0] = 'Alliance',
    [1] = 'Horde',
    ['Alliance'] = 0,
    ['Horde'] = 1,
}

local function IsMyKey(key)
    return key.source == 'mine'
end

function IsMyFactionKey(key)
    local faction = UnitFactionGroup('player')
    if factionLookup[key.playerFaction] ~= faction then return end
    return key.source == 'mine'
end

local function IsGuildKey(key)
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        if key.playerName == GetGuildRosterInfo(i) then
            return true
        end
    end
end

local function IsMyGuildKey(key)
    if key.source ~= 'mine' then return false end
    return IsGuildKey(key)
end

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
        n = arg2 and arg2:len() or 0
        if not arg2 or arg2 == ('guild'):sub(1,n) then
            self:ShowKeys('guild')
        elseif arg2 == ('all'):sub(1,n) then
            self:ShowKeys('all')
        elseif arg2 == ('mine'):sub(1,n) then
            self:ShowKeys('mine')
        end
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

    if arg1 == ('report'):sub(1,n) then
        n = arg2 and arg2:len() or 0
        if not arg2 or arg2 == ('guild'):sub(1,n) then
            self:ReportKeys(IsMyGuildKey, 'GUILD')
        elseif arg2 == ('party'):sub(1,n) then
            self:ReportKeys(IsMyFactionKey, 'PARTY')
        elseif arg2 == ('raid'):sub(1,n) then
            self:ReportKeys(IsMyFactionKey, 'RAID')
        elseif arg2 == ('instance'):sub(1,n) then
            self:ReportKeys(IsMyFactionKey, 'INSTANCE')
        end
        return true
    end

    if arg1 == ('scan'):sub(1,n) then
        C_MythicPlus.RequestRewards()
        return true
    end

    printf('Usage:')
    printf(' /lk list')
    printf(' /lk push')
    printf(' /lk report [party]')
    printf(' /lk request')
    printf(' /lk scan')
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

    C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')

    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('BN_CHAT_MSG_ADDON')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
    self:RegisterEvent('ITEM_PUSH')

    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()
    C_MythicPlus.RequestRewards()

    printf('Initialized.')
end

function LiteKeystone:Reset()
    table.wipe(self.db.playerKeys)
    self:ScanForKey()
end

-- Don't call C_MythicPlus.RequestRewards here or it'll infinite loop
function LiteKeystone:ScanForKey()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return end

    local keyLevel =  C_MythicPlus.GetOwnedKeystoneLevel()
    if not keyLevel then return end

    local weekBest, weekItemLevel = C_MythicPlus.GetWeeklyChestRewardLevel()
    if C_MythicPlus.IsWeeklyRewardAvailable() then
        weekBest = 0
    end

    self.db.playerKeys[self.playerName] = {
            playerName=self.playerName,
            playerClass=self.playerClass,
            playerFaction=self.playerFaction,
            mapID=mapID,
            keyLevel=keyLevel,
            weekBest=weekBest,
            weekNum=WeekNum(),
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
    local thisWeek = WeekNum()
    for player,key in pairs(self.db.playerKeys) do
        if key.weekNum ~= thisWeek then
            self.db.playerKeys[player] = nil
        end
    end
end

function LiteKeystone:SendAstralKey()
    for _, key in pairs(self.db.playerKeys) do
        if key.source == 'mine' then
            local msg = 'updateV8 ' .. self:GetKeyUpdateString(key)
            C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
        end
    end
end

function LiteKeystone:ReceiveAstralKey(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction = string.split(':', content)

    -- Sometimes we seem to get trunkated messages from AstralKeys so make
    -- sure we got all the fields.
    if not playerFaction then return end

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
            weekNum=tonumber(weekNum),
            weekTime=weekTime,
            source=source
        }

    if playerName ~= self.playerName then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        printf('Got key: %s %s (%d)', playerName, mapName, keyLevel)
    end
end

function LiteKeystone:GuildPush(recipient)
    if not IsInGuild() then return end

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
    if not IsInGuild() then return end

    C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'GUILD')

    local numGuild, numGuildOnline = GetNumGuildMembers()
    for i = 1, numGuildOnline do
        local n = GetGuildRosterInfo(i)
        C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'WHISPER', nil, n)
    end
end

function LiteKeystone:RequestKeysFromFriends()
    local numFriends, numFriendsOnline = BNGetNumFriends()
    for i = 1, numFriendsOnline do
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

function LiteKeystone:ShowKeys(what)
    local sortedKeys = {}
    local filter
    if what == 'guild' then
        filter = function (k) return IsMyKey(k) or IsGuildKey(k) end
    elseif what == 'mine' then
        filter = IsMyKey
    end

    for _,key in pairs(self.db.playerKeys) do
        if not filter or filter(key) then
            table.insert(sortedKeys, key)
        end
    end

    table.sort(sortedKeys, function (a,b) return a.keyLevel < b.keyLevel end)

    if #sortedKeys == 0 then return end

    local text = format("Keystones (%s):\n\n", what)

    for _,key in ipairs(sortedKeys) do
        local msg = self:GetPrintString(key, true)
        if key.source == 'mine' then
            text = text .. '* ' .. msg .. "\n"
        else
            text = text .. msg .. "\n"
        end
    end

    LiteKeystoneInfo.Scroll.Edit:SetText(text)
    LiteKeystoneInfo:Show()
    
end

function LiteKeystone:ReportKeys(filterFunc, chatType, chatArg)
    local sortedKeys = {}
    for _,key in pairs(self.db.playerKeys) do
        if not filterFunc or filterFunc(key) then
            table.insert(sortedKeys, key)
        end
    end
    table.sort(sortedKeys, function (a,b) return a.keyLevel < b.keyLevel end)

    for _,key in ipairs(sortedKeys) do
        local msg = self:GetPrintString(key)
        SendChatMessage(msg, chatType, nil, chatArg)
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

-- This is fired after C_MythicPlus.RequestRewards() is called, which
-- we will use as our primary way to force a keystone scan. It's also returned
-- for like 50 other things, which is weird as hell.

function LiteKeystone:CHALLENGE_MODE_MAPS_UPDATE()
    self:ScanForKey()
    self:SendAstralKey()
end

function LiteKeystone:CHALLENGE_MODE_COMPLETED()
    C_MythicPlus.RequestRewards()
end

function LiteKeystone:ITEM_PUSH(bag, iconID)
    if iconID == 525134 then
        C_MythicPlus.RequestRewards()
    end
end
