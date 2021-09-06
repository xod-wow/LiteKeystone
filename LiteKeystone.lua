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

function LiteKeystone:IsMyKey(key)
    return key.source == 'mine'
end

function LiteKeystone:IsFactionKey(key)
    return key.playerFaction == self.playerFaction
end

function LiteKeystone:IsGuildKey(key)
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        if key.playerName == GetGuildRosterInfo(i) then
            return true
        end
    end
end

function LiteKeystone:IsMyGuildKey(key)
    return self:IsMyKey(key) or self:IsGuildKey(key)
end

function LiteKeystone:IsMyFactionKey(key)
    return self:IsMyKey(key) and self:IsFactionKey(key)
end

function LiteKeystone:IsNewKeyInfo(playerName, mapID, keyLevel, weekBest)
    local key = self.db.playerKeys[playerName]
    if not key then return true end
    if key.mapID ~= mapID then return true end
    if key.keyLevel ~= keyLevel then return true end
    if key.weekBest ~= weekBest then return true end
    return false
end

-- Astral Keys' idea of the week number
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

    if  arg1 == '' or arg1 == ('show'):sub(1,n) then
        LiteKeystoneInfo:Show()
        return true
    end

    if arg1 == ('push'):sub(1,n) then
        self:PushMyKey()
        self:PushSyncKeys()
        return true
    end

    if arg1 == ('request'):sub(1,n) then
        self:RequestKeysFromGuild()
        return true
    end

    if arg1 == ('report'):sub(1,n) then
        n = arg2 and arg2:len() or 0
        if not arg2 or arg2 == ('guild'):sub(1,n) then
            self:ReportKeys('IsMyFactionKey', 'GUILD')
        elseif arg2 == ('party'):sub(1,n) then
            self:ReportKeys('IsMyFactionKey', 'PARTY')
        elseif arg2 == ('raid'):sub(1,n) then
            self:ReportKeys('IsMyFactionKey', 'RAID')
        elseif arg2 == ('instance'):sub(1,n) then
            self:ReportKeys('IsMyFactionKey', 'INSTANCE')
        end
        return true
    end

    if arg1 == ('scan'):sub(1,n) then
        C_MythicPlus.RequestMapInfo()
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
    self:RegisterEvent('ITEM_CHANGED')

    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()

    printf('Initialized.')
end

function LiteKeystone:MyKey()
    return self.db.playerKeys[self.playerName]
end

function LiteKeystone:Reset()
    table.wipe(self.db.playerKeys)
    self:ScanForKey()
end

-- Don't call C_MythicPlus.RequestMapInfo here or it'll infinite loop
function LiteKeystone:ScanForKey()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return end

    local keyLevel =  C_MythicPlus.GetOwnedKeystoneLevel()
    if not keyLevel then return end

    local weekBest = 0
    for _, info in ipairs(C_MythicPlus.GetRunHistory(false, true)) do
        weekBest = max(weekBest, info.level)
    end

    if self:IsNewKeyInfo(self.playerName, mapID, keyLevel, weekBest) then
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
        return true
    end
end

function LiteKeystone:ScanAndPushKey()
    if self:ScanForKey() then
        self:PushMyKey()
    end
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

function LiteKeystone:PushMyKey()
    if not IsInGuild() then return end

    local key = self:MyKey()
    if key then
        local msg = 'updateV8 ' .. self:GetKeyUpdateString(key)
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
    end
end

function LiteKeystone:UpdateWeekly(playerName, weekBest)
    if self.db.playerKeys[playerName] then
        self.db.playerKeys[playerName].weekBest = weekBest
        self.db.playerKeys[playerName].weekTime = WeekTime()
    end
end

function LiteKeystone:ReceiveSyncKey(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, weekTime = string.split(':', content)

    mapID = tonumber(mapID)
    keyLevel = tonumber(keyLevel)
    weekNum = tonumber(weekNum)
    weekBest = tonumber(weekBest)
    weekTime = tonumber(weekTime)

    -- Sometimes we seem to get truncated messages from AstralKeys so make
    -- sure we got all the fields.
    if not weekTime then return end

    -- Don't accept our own keys back from other people
    if self.db.playerKeys[playerName] and
       self.db.playerKeys[playerName].source == 'mine' then
        return
    end

    if not self:IsNewKeyInfo(playerName, mapID, keyLevel, weekBest) then
        return
    end

    -- Third party reports are unreliable, try to make sure we don't
    -- overwrite better info.

    local existingKey = self.db.playerKeys[playerName]

    if existingKey then
        if existingKey.weekBest > weekBest then
            weekBest = existingKey.weekBest
        end
        if existingKey.weekTime >= weekTime then
            self.db.playerKeys[playerName].weekBest = weekBest
            return
        end
    end

    self.db.playerKeys[playerName] = {
            playerName=playerName,
            playerClass=playerClass,
            playerFaction=self.playerFaction,
            mapID=mapID,
            keyLevel=keyLevel,
            weekBest=weekBest,
            weekNum=weekNum,
            weekTime=weekTime,
            source=source
        }

    if playerName ~= self.playerName then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        printf('Sync key: %s %s (%d)', playerName, mapName, keyLevel)
    end
end

function LiteKeystone:ReceiveAstralKey(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction = string.split(':', content)

    mapID = tonumber(mapID)
    keyLevel = tonumber(keyLevel)
    weekNum = tonumber(weekNum)
    weekBest = tonumber(weekBest)
    playerFaction = tonumber(playerFaction)

    -- Don't accept our own keys back from other people
    if self.db.playerKeys[playerName] and
       self.db.playerKeys[playerName].source == 'mine' then
        return
    end

    if not self:IsNewKeyInfo(playerName, mapID, keyLevel, weekBest) then
        return
    end

    self.db.playerKeys[playerName] = {
            playerName=playerName,
            playerClass=playerClass,
            playerFaction=playerFaction,
            mapID=mapID,
            keyLevel=keyLevel,
            weekBest=weekBest,
            weekNum=weekNum,
            weekTime=WeekTime(),
            source=source
        }

    if playerName ~= self.playerName then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        printf('Got key: %s %s (%d)', playerName, mapName, keyLevel)
    end
end

local function batch(keyList, max)
    local batches = { }
    local msg

    for _,k in ipairs(keyList) do
       if not msg then
            msg = k
        elseif msg:len() + k:len() + 1 > max then
            table.insert(batches, msg)
            msg = k
        else
            msg = msg .. '_' .. k
        end
    end
    if msg then
        table.insert(batches, msg)
    end
    return batches
end

function LiteKeystone:PushSyncKeys(recipient)
    if not IsInGuild() then return end

    local guildKeys = {}

    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if self.db.playerKeys[name] then
            local msg = self:GetKeySyncString(self.db.playerKeys[name])
            table.insert(guildKeys, msg)
        end
    end

    if #guildKeys == 0 then return end

    for _,msg in ipairs(batch(guildKeys, 240)) do
        C_ChatInfo.SendAddonMessage('AstralKeys', 'sync5 ' .. msg, 'GUILD')
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

function LiteKeystone:GetPlayerName(key, useColor)
    local p = key.playerName:gsub('-'..GetRealmName(), '')
    if useColor then
        local c = RAID_CLASS_COLORS[key.playerClass]
        p = c:WrapTextInColorCode(p)
    end
    return p
end

function LiteKeystone:GetKeystone(key)
    local mapName = C_ChallengeMode.GetMapUIInfo(key.mapID)
    return string.format('|cffa335ee%s (%d)|r', mapName, key.keyLevel)
end

function LiteKeystone:GetKeystoneLink(key)
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

    return string.format(
            '|cffa335ee|Hkeystone:158923:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            key.mapID, key.keyLevel, affixString, mapName, key.keyLevel
        )
end

function LiteKeystone:GetPrintString(key, useColor)
    local link = self:GetKeystoneLink(key)
    local player = self:GetPlayerName(key, useColor)
    return string.format('%s : %s : best %d', player, link, key.weekBest)
end

local sorts = {
    KEYLEVEL = function (a, b)
        if a.keyLevel == b.keyLevel then
            return a.playerName < b.playerName
        else
            return a.keyLevel > b.keyLevel
        end
    end,
    PLAYERNAME = function (a, b)
        return a.playerName < b.playerName
    end,
    WEEKBEST = function (a, b)
        if a.weekBest == b.weekBest then
            return a.playerName < b.playerName
        else
            return a.weekBest > b.weekBest
        end
    end,
}

function LiteKeystone:SortedKeys(filterMethod, sortType)

    local filter
    if filterMethod then
        filter = self[filterMethod]
    end

    local sortedKeys = {}

    for _,key in pairs(self.db.playerKeys) do
        if not filter or filter(self, key) then
            table.insert(sortedKeys, key)
        end
    end

    table.sort(sortedKeys, sorts[sortType] or sorts.KEYLEVEL)

    return sortedKeys
end

-- Other than correctly formatted hyperlinks you can't send colors in chat
-- messages. It doesn't cause an error, the message is just silently discarded

function LiteKeystone:ReportKeys(filterMethod, chatType, chatArg)
    local sortedKeys = self:SortedKeys(filterMethod)
    for _,key in ipairs(sortedKeys) do
        local msg = self:GetPrintString(key)
        SendChatMessage(msg, chatType, nil, chatArg)
    end
end

function LiteKeystone:ProcessAddonMessage(text, source)
    local action, content = text:match('^(%S+)%s+(.-)$')

    if source == self.playerName then return end

    if action == 'updateV8' or action == 'update4' then
        self:ReceiveAstralKey(content, source)
    elseif action == 'sync5' then
        for entry in content:gmatch('[^_]+') do
            self:ReceiveSyncKey(entry, source)
        end
    elseif action == 'updateWeekly' then
        self:UpdateWeekly(source, tonumber(content))
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
        self:PushMyKey()
    end
end

-- This is fired after C_MythicPlus.RequestMapInfo() is called, which
-- we will use as our primary way to force a keystone scan. It's also returned
-- for like 50 other things, which is weird as hell.

function LiteKeystone:CHALLENGE_MODE_MAPS_UPDATE()
    self:ScanAndPushKey()
end

function LiteKeystone:CHALLENGE_MODE_COMPLETED()
    self:ScanAndPushKey()
end

function LiteKeystone:ITEM_PUSH(bag, iconID)
    if iconID == 525134 then
        self:ScanAndPushKey()
    end
end

-- Keystone trader at the end of finishing a M+
function LiteKeystone:ITEM_CHANGED(fromLink, toLink)
    if C_ChallengeMode.IsChallengeModeActive() then
        local fromID = GetItemInfoFromHyperlink(fromLink)
        if fromID == 138019 then
            self:ScanAndPushKey()
        end
    end
end
