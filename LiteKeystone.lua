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

local function debug(...)
    --@debug@
    printf(...)
    --@end-debug@
end

local regionStartTimes = {
    [1] = 1500390000,   -- US
    [2] = 1500390000,   -- EU (says 1500447600 but doesn't use it)
    [3] = 1500505200,   -- CN
}

-- Trivial callback system, it's terrible but good enough for just
-- updating the UI when new keys info is available.

function LiteKeystone:RegisterCallback(owner, func)
    self.callbacks[owner] = func
end

function LiteKeystone:UnregisterCallback(owner)
    self.callbacks[owner] = nil
end

function LiteKeystone:Fire()
    for owner, func in pairs(self.callbacks) do
        func(owner)
    end
end

function LiteKeystone:IsMyKey(key)
    return key.source == 'mine'
end

function LiteKeystone:IsFactionKey(key)
    return key.playerFaction == self.playerFaction
end

function LiteKeystone:IsGroupKey(key)
    local playerRealm = GetRealmName()
    if key.playerName == self.playerName then
        return true
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) do
            local name, realm = UnitName("raid"..i)
            local fullName = string.join('-', name, realm or playerRealm)
            if key.playerName == fullName then
                return true
            end
        end
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) - 1 do
            local name, realm = UnitName("party"..i)
            local fullName = string.join('-', name, realm or playerRealm)
            if key.playerName == fullName then
                return true
            end
        end
    else
        return false
    end
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

function LiteKeystone:IsNewKey(existingKey, newKey)
    if not existingKey then
        return true
    elseif not newKey then
        return false
    else
        return ( existingKey.mapID ~= newKey.mapID or existingKey.keyLevel ~= newKey.keyLevel )
    end
end

function LiteKeystone:IsNewBest(key, weekBest)
    return ( key and key.weekBest ~= weekBest )
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
        self:PushMyKeys()
        self:PushSyncKeys()
        return true
    end

    if arg1 == 'scan' then
        self:ScanAndPushKeys('commandline')
        return true
    end

    if arg1 == ('request'):sub(1,n) then
        self:RequestKeysFromGuild()
        self:RequestKeysFromFriends()
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

    self.callbacks = {}

    LiteKeystoneDB = LiteKeystoneDB or {}
    self.db = LiteKeystoneDB
    self.db.playerKeys = self.db.playerKeys or {}
    self.db.playerTimewalkingKeys = self.db.playerTimewalkingKeys or {}

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
    -- self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
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
    table.wipe(self.db.playerTimewalkingKeys)
    self:ScanAndPushKeys('Reset')
end

local mapTable

function LiteKeystone:GetUIMapIDByName(name)
    if not mapTable then
        mapTable = { }
        for mapID = 1, 1000 do
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name then mapTable[name] = mapID end
        end
    end
    return mapTable[name]
end

function LiteKeystone:GetMyKeyFromLink(link, weekBest)
    local fields = { string.split(':', link) }
    local itemID, mapID, keyLevel

    if fields[1]:find('keystone') then
        itemID = tonumber(fields[2])
        mapID = tonumber(fields[3])
        keyLevel = tonumber(fields[4])
    elseif fields[1]:find('item') then
        itemID = fields[2]
        local numBonus = tonumber(fields[14]) or 0
        local numModifiers = tonumber(fields[15+numBonus]) or 0
        for i = 0, numModifiers-1 do
            local k = tonumber(fields[16+numBonus+2*i])
            local v = tonumber(fields[16+numBonus+2*i+1])
            if k == 17 then
                mapID = v
            elseif k == 18 then
                keyLevel = v
            end
        end
    end

    local newKey = {
        itemID=itemID,
        playerName=self.playerName,
        playerClass=self.playerClass,
        playerFaction=self.playerFaction,
        mapID=mapID,
        mapName=C_ChallengeMode.GetMapUIInfo(mapID),
        weekBest=weekBest,
        keyLevel=keyLevel,
        weekNum=WeekNum(),
        weekTime=WeekTime(),
        link=link,
        source='mine',
    }

    return newKey
end

function LiteKeystone:ProcessItem(item)
    local db, changed

    if item:GetItemID() == 187786 then
        db = self.db.playerTimewalkingKeys
    elseif item:GetItemID() == 180653 then
        db = self.db.playerKeys
    else
        return
    end

    local weekBest = 0
    for _, info in ipairs(C_MythicPlus.GetRunHistory(false, true)) do
        weekBest = max(weekBest, info.level)
    end

    local newKey = self:GetMyKeyFromLink(item:GetItemLink(), weekBest)

    debug('Found key: mapid %d (%s), level %d, weekbest %d.', newKey.mapID, newKey.mapName, newKey.keyLevel, weekBest)

    local existingKey = db[self.playerName]

    if self:IsNewKey(existingKey, newKey) then
        debug('New key, saving.')
        newKey.weekBest = weekBest
        db[self.playerName] = newKey
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage('New keystone: ' .. newKey.link, 'PARTY')
        end
        self:PushMyKeys(newKey)
        self:Fire()
    elseif self:IsNewBest(existingKey, weekBest) then
        debug('New best, updating.')
        existingKey.weekBest = weekBest
        self:PushMyKeys(existingKey)
        self:Fire()
    else
        debug('Same key, ignored.')
    end
end

-- Don't call C_MythicPlus.RequestMapInfo here or it'll infinite loop
function LiteKeystone:ScanAndPushKeys(reason)
    debug('Scanning my keys: %s.', tostring(reason))

    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = Item:CreateFromBagAndSlot(bag, slot)
            if not item:IsItemEmpty() then
                item:ContinueOnItemLoad(
                    function () self:ProcessItem(item) end)
            end
        end
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
    for player,key in pairs(self.db.playerTimewalkingKeys) do
        if key.weekNum ~= thisWeek then
            self.db.playerTimewalkingKeys[player] = nil
        end
    end
    self:Fire()
end

function LiteKeystone:PushMyKeys(key)

    local key = key or self:MyKey()

    -- AstralKeys only supports non-timewalking keystones
    if not key or key.itemID ~= 180653 then return end

    local msg = 'updateV8 ' .. self:GetKeyUpdateString(key)

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
    end

    local _, numFriendsOnline = BNGetNumFriends()
    for i = 1, numFriendsOnline do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAcccountInfo and info.gameAccountInfo.clientProgram == 'WoW' then
            BNSendGameData(info.gameAccountInfo.gameAccountID, 'AstralKeys', msg)
        end
    end
end

function LiteKeystone:UpdateWeekly(playerName, weekBest)
    if self.db.playerKeys[playerName] then
        self.db.playerKeys[playerName].weekBest = weekBest
        self.db.playerKeys[playerName].weekTime = WeekTime()
        self:Fire()
    end
end

function LiteKeystone:ReceiveKey(newKey, action)
    local existingKey = self.db.playerKeys[newKey.playerName]

    -- Don't accept our own keys back from other people
    if existingKey and existingKey.source == 'mine' then
        return
    elseif newKey.playerName == self.playerName then
        return
    end

    -- Third party reports are unreliable, try to make sure we don't
    -- overwrite better info.

    if not self:IsNewKey(existingKey, newKey) and
       not self:IsNewBest(existingKey, newKey.weekBest) then
        return
    end

    if existingKey and newKey.weekTime <= existingKey.weekTime then
        existingKey.weekBest = math.max(existingKey.weekBest, newKey.weekBest)
        self:Fire()
        return
    end

    self.db.playerKeys[newKey.playerName] = newKey

    debug('Got key from %s via %s: %s %s', newKey.source, action, newKey.playerName, newKey.link)

    self:Fire()

    return true
end

function LiteKeystone:GetKeyFromSync(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, weekTime = string.split(':', content)

    -- AstralKeys splitting is garbage and the last entry is often truncated,
    -- so make sure we got all the fields.
    if not weekTime or not tonumber(weekTime) then return end

    local newKey = {
        itemID=180653,
        playerName=playerName,
        playerClass=playerClass,
        playerFaction=self.playerFaction,
        mapID=tonumber(mapID),
        mapName=C_ChallengeMode.GetMapUIInfo(tonumber(mapID)),
        keyLevel=tonumber(keyLevel),
        weekBest=tonumber(weekBest),
        weekNum=tonumber(weekNum),
        weekTime=tonumber(weekTime),
        source=source
    }

    newKey.link = self:GetKeystoneLink(newKey)

    return newKey
end

function LiteKeystone:GetKeyFromUpdate(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction = string.split(':', content)

    local newKey = {
        itemID=180653,
        playerName=playerName,
        playerClass=playerClass,
        playerFaction=playerFaction,
        mapID=tonumber(mapID),
        mapName=C_ChallengeMode.GetMapUIInfo(tonumber(mapID)),
        keyLevel=tonumber(keyLevel),
        weekBest=tonumber(weekBest),
        weekNum=tonumber(weekNum),
        weekTime=WeekTime(),
        source=source
    }

    newKey.link = self:GetKeystoneLink(newKey)

    return newKey
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

function LiteKeystone:PushSyncKeys()
    if not IsInGuild() then return end

    local guildKeys = {}

    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name ~= self.playerName and self.db.playerKeys[name] then
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
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage('AstralKeys', 'request', 'GUILD')
    end
end

-- this is a dumb protocol, why not just use 'request'

function LiteKeystone:RequestKeysFromFriends()
    local numFriends, numFriendsOnline = BNGetNumFriends()
    for i = 1, numFriendsOnline do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAcccountInfo and info.gameAccountInfo.clientProgram == 'WoW' then
            BNSendGameData(info.gameAccountInfo.gameAccountID, 'AstralKeys', 'BNet_query ping')
        end
    end

    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info.connected and not info.mobile then
            C_ChatInfo.SendAddonMessage('AstralKeys', 'BNet_query ping', 'WHISPER', nil, info.name)
        end
    end
end

function LiteKeystone:GetAffixes()
    if not self.keystoneAffixes then
        self.keystoneAffixes = {}
        local affixInfo = C_MythicPlus.GetCurrentAffixes()
        for _, info in ipairs(affixInfo) do
            table.insert(self.keystoneAffixes, info.id)
        end
    end
    return self.keystoneAffixes
end

function LiteKeystone:GetPlayerName(key, useColor)
    local p = key.playerName:gsub('-'..GetRealmName(), '')
    if useColor then
        return RAID_CLASS_COLORS[key.playerClass]:WrapTextInColorCode(p)
    else
        return p
    end
end

function LiteKeystone:GetKeyText(key)
    return string.format('|cffa335ee%s (%d)|r', key.mapName, key.keyLevel)
end

function LiteKeystone:GetKeystoneLink(key)
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
            '|cffa335ee|Hkeystone:180653:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            key.mapID, key.keyLevel, affixString, key.mapName, key.keyLevel
        )
end

function LiteKeystone:GetPrintString(key, useColor)
    local player = self:GetPlayerName(key, useColor)
    return string.format('%s : %s : best %d', player, key.link, key.weekBest)
end

local sorts = {}
do
    sorts.KEYLEVEL = function (a, b)
        if a.keyLevel ~= b.keyLevel then
            return a.keyLevel > b.keyLevel
        end
        if a.mapID ~= b.mapID then
            local aName = C_ChallengeMode.GetMapUIInfo(a.mapID)
            local bName = C_ChallengeMode.GetMapUIInfo(b.mapID)
            return aName < bName
        end
        if a.playerName ~= b.playerName then
            return a.playerName < b.playerName
        end
    end
    sorts.KEYNAME = function (a, b)
        if a.mapID ~= b.mapID then
            local aName = C_ChallengeMode.GetMapUIInfo(a.mapID)
            local bName = C_ChallengeMode.GetMapUIInfo(b.mapID)
            return aName < bName
        end
        if a.keyLevel ~= b.keyLevel then
            return a.keyLevel > b.keyLevel
        end
        if a.playerName ~= b.playerName then
            return a.playerName < b.playerName
        end
    end
    sorts.PLAYERNAME = function (a, b)
        if a.playerName ~= b.playerName then
            return a.playerName < b.playerName
        end
        if a.mapID ~= b.mapID then
            local aName = C_ChallengeMode.GetMapUIInfo(a.mapID)
            local bName = C_ChallengeMode.GetMapUIInfo(b.mapID)
            return aName < bName
        end
        if a.keyLevel ~= b.keyLevel then
            return a.keyLevel > b.keyLevel
        end
    end
    sorts.WEEKBEST = function (a, b)
        if a.weekBest ~= b.weekBest then
            return a.weekBest > b.weekBest
        end
        return sorts.KEYLEVEL(a, b)
    end
end

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

    for _,key in pairs(self.db.playerTimewalkingKeys) do
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
        local newKey = self:GetKeyFromUpdate(content, source)
        self:ReceiveKey(newKey, action)
    elseif action == 'sync5' then
        for entry in content:gmatch('[^_]+') do
            local newKey = self:GetKeyFromSync(entry, source)
            if newKey then
                self:ReceiveKey(newKey, action)
            end
        end
    elseif action == 'updateWeekly' then
        self:UpdateWeekly(source, tonumber(content))
    elseif event == 'BNet_query_ping' then
        -- ignore
    elseif event == 'request' then
        self:PushMyKeys()
        self:PushSyncKeys()
    end
end

function LiteKeystone:PLAYER_LOGIN()
    self:Initialize()
end

function LiteKeystone:CHAT_MSG_ADDON(prefix, text, chatType, sender)
    if prefix ~= 'AstralKeys' then return end
    self:ProcessAddonMessage(text, sender)
end

function LiteKeystone:BN_CHAT_MSG_ADDON(prefix, text, chatType, gameAccountID)
    if prefix ~= 'AstralKeys' then return end
    local gameInfo = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
    if gameInfo and gameInfo.clientProgram == 'WoW' and gameInfo.playerGuid then
        -- local sender = string.format('%s-%s', info.characterName, info.realmName)
        -- self:ProcessAddonMessage(text, sender)
        local playerInfo = C_BattleNet.GetAccountInfoByGUID(gameInfo.playerGuid)
        self:ProcessAddonMessage(text, playerInfo.battleTag)
    end
end


function LiteKeystone:GUILD_ROSTER_UPDATE()
    local elapsed = GetServerTime() - (self.lastKeyBroadcast or 0)
    if elapsed > 30 then
        self.lastKeyBroadcast = GetServerTime()
        self:PushMyKeys()
    end
end

-- This is fired after C_MythicPlus.RequestMapInfo() is called, which
-- we will use as our primary way to force a keystone scan. It's also returned
-- for like 50 other things, which is weird as hell.

function LiteKeystone:CHALLENGE_MODE_MAPS_UPDATE()
    self:ScanAndPushKeys('CHALLENGE_MODE_MAPS_UPDATE')
end

function LiteKeystone:CHALLENGE_MODE_COMPLETED()
    self:ScanAndPushKeys('CHALLENGE_MODE_COMPLETED')
end

function LiteKeystone:ITEM_PUSH(bag, iconID)
    if iconID == 525134 or iconID == 531324 or iconID == 4352494 then
        self:RegisterEvent('BAG_UPDATE_DELAYED')
    end
end

function LiteKeystone:BAG_UPDATE_DELAYED()
    self:UnregisterEvent('BAG_UPDATE_DELAYED')
    self:ScanAndPushKeys('BAG_UPDATE_DELAYED')
end

-- Keystone trader at the end of finishing a M+ or the keystone downgrader.
-- The link could be keystone:itemid or item:itemid. There is a delay between
-- ITEM_CHANGED firing and GetContainerItemInfo returning the new keystone,
-- which is why this doesn't just call ScanAndPushKeys.

function LiteKeystone:ITEM_CHANGED(fromLink, toLink)
    local item = Item:CreateFromItemLink(toLink)
    if not item:IsItemEmpty() then
        item:ContinueOnItemLoad(function () self:ProcessItem(item) end)
    end
end
