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

local function IsKeystoneItem(item)
    if type(item) == 'string' then
        if LinkUtil.IsLinkType(item, "keystone") then
            return true
        end
        item = GetItemInfoFromHyperlink(item)
    elseif type(item) == 'table' then
        item = item:GetItemID()
    end
    return item == 187786 or item == 180653
end

local lor = LibStub('LibOpenRaid-1.0', true)

--[[------------------------------------------------------------------------]]--

LiteKeystone = CreateFrame('Frame')
LiteKeystone:SetScript('OnEvent',
        function (self, e, ...)
            if self[e] then self[e](self, ...) end
        end)
LiteKeystone:RegisterEvent('PLAYER_LOGIN')
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
    if key.playerName == self.playerName then
        return true
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) do
            local name, realm = UnitName("raid"..i)
            local fullName = string.join('-', name, realm or self.playerRealm)
            if key.playerName == fullName then
                return true
            end
        end
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) - 1 do
            local name, realm = UnitName("party"..i)
            local fullName = string.join('-', name, realm or self.playerRealm)
            if key.playerName == fullName then
                return true
            end
        end
    else
        return self:IsGuildKey(key, true)
    end
end

function LiteKeystone:IsGuildKey(key, requireOnline)
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if key.playerName == name and ( isOnline or not requireOnline ) then
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
    if not newKey then
        return false
    elseif not existingKey then
        return true
    else
        return (
            existingKey.mapID ~= newKey.mapID or
            existingKey.keyLevel ~= newKey.keyLevel
        )
    end
end

function LiteKeystone:IsNewPlayerData(existingKey, newKey)
    if not newKey then
        return false
    elseif not existingKey then
        return true
    else
        return (
            existingKey.weekBest ~= newKey.weekBest or
            existingKey.rating ~= newKey.rating
        )
    end
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

    if arg1 == 'push' then
        self:PushMyKeys()
        self:PushSyncKeys()
        return true
    end

    if arg1 == 'scan' then
        self:ScanAndPushKeys('COMMANDLINE')
        return true
    end

    if arg1 == ('request'):sub(1,n) then
        lor.RequestKeystoneDataFromGuild()
        self:RequestKeysFromGuild()
        self:RequestKeysFromFriends()
        return true
    end

    if arg1 == 'reset' then
        lor.RequestKeystoneDataFromGuild()
        self:RequestKeysFromGuild()
        self:RequestKeysFromFriends()
        return true
    end

    if arg1 == ('keys'):sub(1,n) then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            self:ReportKeys('IsGroupKey', 'PARTY')
        end
        return true
    end

    if arg1 == ('mykeys'):sub(1,n) then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            self:ReportKeys('IsMyKey', 'PARTY')
        end
        return true
    end

    if arg1 == ('report'):sub(1,n) then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            self:ReportKeys('IsMyFactionKey', 'PARTY')
        elseif IsInGuild() then
            self:ReportKeys('IsMyFactionKey', 'GUILD')
        end
        return true
    end

    if arg1 == 'scale' and tonumber(arg2) then
        local scale = Clamp(tonumber(arg2), 0.5, 1.5)
        self.db.uiScale = scale
        LiteKeystoneInfo:UpdateScale()
        return true
    end

    printf('Usage:')
    printf(' /lk keys')
    printf(' /lk mykeys')
    printf(' /lk push')
    printf(' /lk request')
    printf(' /lk scan')
    printf(' /lk scale 0.5 - 1.5')
    return true
end

function LiteKeystone:Initialize()

    self.callbacks = {}

    LiteKeystoneDB = LiteKeystoneDB or {}
    self.db = LiteKeystoneDB
    self.db.playerKeys = self.db.playerKeys or {}
    self.db.uiScale = self.db.uiScale or 1.0

    SlashCmdList.LiteKeystone = function (...) self:SlashCommand(...) end
    _G.SLASH_LiteKeystone1 = "/litekeystone"
    _G.SLASH_LiteKeystone2 = "/lk"

    self.playerName = string.join('-', UnitFullName('player'))
    self.playerRealm = GetRealmName()
    self.playerClass = select(2, UnitClass('player'))

    if UnitFactionGroup('player') == 'Alliance' then
        self.playerFaction = 0
    else
        self.playerFaction = 1
    end
    self:RemoveExpiredKeys()
    EventUtil.ContinueOnAddOnLoaded('RaiderIO', function () self:UpdateKeyRatings() end)

    C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')

    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('BN_CHAT_MSG_ADDON')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
    self:RegisterEvent('ITEM_PUSH')
    self:RegisterEvent('ITEM_COUNT_CHANGED')
    self:RegisterEvent('ITEM_CHANGED')
    self:RegisterEvent('CHAT_MSG_PARTY')
    self:RegisterEvent('CHAT_MSG_PARTY_LEADER')
    self:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')

    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()

    lor.RegisterCallback(self, 'KeystoneUpdate', 'UpdateOpenRaidKeys')
    lor.RequestKeystoneDataFromGuild()

    printf('Initialized.')
end

function LiteKeystone:MyKey()
    return self.db.playerKeys[self.playerName]
end

function LiteKeystone:Reset()
    table.wipe(self.db.playerKeys)
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

function LiteKeystone:GetMyKeyFromLink(link)
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
        weekBest=0,
        keyLevel=keyLevel,
        weekNum=WeekNum(),
        weekTime=WeekTime(),
        link=link,
        source='mine',
    }

    for _, info in ipairs(C_MythicPlus.GetRunHistory(false, true)) do
        newKey.weekBest = max(newKey.weekBest or 0, info.level)
    end

    self:UpdateKeyRating(newKey)

    return newKey
end

function LiteKeystone:ProcessItem(item)
    local db, changed

    if item:GetItemID() == 180653 then
        db = self.db.playerKeys
    else
        return
    end

    local newKey = self:GetMyKeyFromLink(item:GetItemLink())

    debug('Found key: mapid %d (%s), level %d, weekbest %d, rating %d.',
            newKey.mapID, newKey.mapName, newKey.keyLevel, newKey.weekBest, newKey.rating)

    local existingKey = db[self.playerName]

    if self:IsNewKey(existingKey, newKey) then
        debug('New key, saving.')
        db[self.playerName] = newKey
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage('New keystone: ' .. newKey.link, 'PARTY')
        end
        self:PushMyKeys(newKey)
        self:Fire()
    elseif self:IsNewPlayerData(existingKey, newKey) then
        debug('New player data, saving.')
        db[self.playerName] = newKey
        self:PushMyKeys(newKey)
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

function LiteKeystone:UpdateKeyRating(key)
    if key.playerName == self.playerName then
        key.rating = C_ChallengeMode.GetOverallDungeonScore()
    elseif RaiderIO and RaiderIO.GetProfile then
        local n, r = string.split('-', key.playerName)
        local p = RaiderIO.GetProfile(n, r)
        if p and p.mythicKeystoneProfile and p.mythicKeystoneProfile.mplusCurrent then
            key.rating = max(key.rating or 0, p.mythicKeystoneProfile.mplusCurrent.score)
        end
    end
end

function LiteKeystone:UpdateKeyRatings()
    for player,key in pairs(self.db.playerKeys) do
        self:UpdateKeyRating(key)
    end
end

function LiteKeystone:RemoveExpiredKeys()
    local thisWeek = WeekNum()
    for player,key in pairs(self.db.playerKeys) do
        if key.weekNum ~= thisWeek then
            self.db.playerKeys[player] = nil
        end
    end
    self:Fire()
end

function LiteKeystone:PushMyKeys(key)

    local key = key or self:MyKey()

    if not key then return end

    local msg = 'updateV8 ' .. self:GetKeyUpdateString(key)

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'GUILD')
    end

    local _, numFriendsOnline = BNGetNumFriends()
    for i = 1, numFriendsOnline do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.clientProgram == 'WoW' then
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

function LiteKeystone:ReceiveKey(newKey, action, isReliable)
    local existingKey = self.db.playerKeys[newKey.playerName]

    -- Don't accept our own keys back from other people
    if existingKey and existingKey.source == 'mine' then
        return
    elseif newKey.playerName == self.playerName then
        return
    end

    if existingKey and not isReliable and existingKey.weekTime >= newKey.weekTime then
        return
    end

    if existingKey then
        newKey.weekBest = math.max(existingKey.weekBest or 0, newKey.weekBest or 0)
        newKey.rating = math.max(existingKey.rating or 0, newKey.rating or 0)
    end

    if self:IsNewKey(existingKey, newKey) then
        debug('%s via %s: %s %s', newKey.source, action, newKey.playerName, newKey.link)
    end

    self.db.playerKeys[newKey.playerName] = newKey

    self:Fire()

    return true
end

function LiteKeystone:GetKeyFromSync(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, weekTime = string.split(':', content)

    -- Make sure we got all the fields.
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

    self:UpdateKeyRating(newKey)

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

    self:UpdateKeyRating(newKey)

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

-- Assumes LibOpenraid-1.0 and LibStub exist, don't call unless true

-- LibOpenRaid doesn't pass self even though it insists on a method
function LiteKeystone.UpdateOpenRaidKeys()
    local self = LiteKeystone

    for unitName, info in pairs(lor.GetAllKeystonesInfo()) do
        if not unitName:find('-') then
            unitName = unitName .. '-' .. self.playerRealm
        end
        if info.mythicPlusMapID ~= 0 then
            local newKey = {
                itemID=180653,
                playerName=unitName,
                playerClass=select(2, GetClassInfo(info.classID)),
                playerFaction=self.playerFaction,
                mapID=info.mythicPlusMapID,
                mapName=C_ChallengeMode.GetMapUIInfo(info.mythicPlusMapID),
                keyLevel=info.level,
                weekBest=0,
                rating=info.rating,
                weekNum=WeekNum(),
                weekTime=WeekTime(),
                source=unitName,
            }
            newKey.link = self:GetKeystoneLink(newKey)
            if self:IsGuildKey(newKey) then
                self:ReceiveKey(newKey, 'LibOpenRaid', true)
            end
        end
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
        if info and info.gameAccountInfo and info.gameAccountInfo.clientProgram == 'WoW' then
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
        if not affixInfo then return end
        for _, info in ipairs(affixInfo) do
            table.insert(self.keystoneAffixes, info.id)
        end
    end
    return self.keystoneAffixes
end

function LiteKeystone:GetPlayerName(key, useColor)
    local p = key.playerName:gsub('-'..self.playerRealm, '')
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
    local affixes = self:GetAffixes()

    -- Sometimes this is called at long before the affix info is available.
    if not affixes then return end

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

    local affixString = string.format(affixFormat, unpack(affixes))
    return string.format(
            '|cffa335ee|Hkeystone:180653:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            key.mapID, key.keyLevel, affixString, key.mapName, key.keyLevel
    )
end

function LiteKeystone:GetPrintString(key, useColor)
    local player = self:GetPlayerName(key, useColor)
    return string.format('%s : %s', player, key.link)
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
    sorts.RATING = function (a, b)
        if a.rating == b.rating then
            return sorts.KEYLEVEL(a, b)
        elseif not a.rating then
            return false
        elseif not b.rating then
            return true
        else
            return a.rating > b.rating
        end
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
        self:ReceiveKey(newKey, action, true)
    elseif action == 'sync5' then
        for entry in content:gmatch('[^_]+') do
            local newKey = self:GetKeyFromSync(entry, source)
            if newKey then
                self:ReceiveKey(newKey, action)
            end
        end
    elseif action == 'updateWeekly' then
        self:UpdateWeekly(source, tonumber(content))
    elseif action == 'BNet_query ping' then
        -- XXX limit to sender? XXX
        self:PushMyKeys()
    elseif action == 'request' then
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

function LiteKeystone:CHAT_MSG_PARTY(text)
    if text == '!keys' then
        local key = self:MyKey()
        if key then
            SendChatMessage(key.link, 'PARTY', nil)
        end
    end
end

LiteKeystone.CHAT_MSG_PARTY_LEADER = LiteKeystone.CHAT_MSG_PARTY

function LiteKeystone:GUILD_ROSTER_UPDATE()
    local elapsed = GetServerTime() - (self.lastKeyBroadcast or 0)
    if elapsed > 30 then
        self.lastKeyBroadcast = GetServerTime()
        self:PushMyKeys()
    end
end

function LiteKeystone:DelayScan(trigger, delay)
    if trigger then debug('DelayScan ' .. trigger) end
    C_Timer.After(delay or 1, function () self:ScanAndPushKeys(trigger) end)
end

-- This used to be reliably fired every time C_MythicPlus.RequestMapInfo() was
-- called and used to be the primary scan trigger. At some point Blizzard
-- started caching the data locally and not re-triggering unless something
-- changed so that doesn't work any more.

function LiteKeystone:CHALLENGE_MODE_MAPS_UPDATE()
    self:DelayScan('CHALLENGE_MODE_MAPS_UPDATE')
end

function LiteKeystone:CHALLENGE_MODE_COMPLETED()
    -- This is to try to force new data for weekbest, but if there is no new
    -- data it won't trigger CHALLENGE_MODE_MAPS_UPDATE and I have no idea how
    -- this is actually meant to work.
    C_MythicPlus.RequestMapInfo()
end

function LiteKeystone:ITEM_PUSH(bag, iconID)
    if iconID == 525134 or iconID == 531324 or iconID == 4352494 then
        self:DelayScan('ITEM_PUSH')
    end
end

-- Not getting ITEM_PUSH for opening the Great Vault since DF.
function LiteKeystone:ITEM_COUNT_CHANGED(itemID)
    if IsKeystoneItem(itemID) then
        self:DelayScan('ITEM_COUNT_CHANGED')
    end
end

-- Keystone trader at the end of finishing a M+ or the keystone downgrader.
-- The link could be keystone:itemid or item:itemid. This used to use
-- ProcessItem on an item created from toLink but item: style keystone
-- links don't have any details in them.

function LiteKeystone:ITEM_CHANGED(fromLink, toLink)
    local itemID = GetItemInfoFromHyperlink(toLink)
    if IsKeystoneItem(itemID) then
        self:DelayScan('ITEM_CHANGED')
    end
end

-- For putting the keystone in the hole. Seems to be a legit typo from
-- Blizzard that it says receptable instead of receptacle.

function LiteKeystone:CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN()
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = Item:CreateFromBagAndSlot(bag, slot)
            if not item:IsItemEmpty() then
                item:ContinueOnItemLoad(
                    function ()
                        if IsKeystoneItem(item) then
                            C_Container.UseContainerItem(bag, slot)
                        end
                    end)
            end
        end
    end
end

function LiteKeystone:GetKeyScores(key)
    local scores, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(key.mapID)
    if not scores then return 0, 0, 0 end

    local fortScore, tyrScore = 0, 0
    for _,info in ipairs(scores) do
        if info.name == "Tyrannical" then
            tyrScore = info.score
        else
            fortScore = info.score
        end
    end
    return overallScore, fortScore, tyrScore
end

function LiteKeystone:GetRatingIncreaseForTimingKey(key)
    local curTotal, fort, tyr = self:GetKeyScores(key)
    local nAffix = key.keyLevel >= 14 and 3 or key.keyLevel >= 7 and 2 or 1

    local newScore = 20 + key.keyLevel*5 + max(key.keyLevel-10,0)*2 + nAffix*10

    if C_MythicPlus.GetCurrentAffixes()[1].id == 10 then
        fort = newScore
    else
        tyr = newScore
    end
    local newTotal = max(fort, tyr)*1.5 + min(fort,tyr)*0.5
    return max(newTotal-curTotal, 0)
end

function LiteKeystone:SortedDungeons()
    local output = { }

    for _, mapID in pairs(C_ChallengeMode.GetMapTable()) do
        local mapName, _, mapTimer = C_ChallengeMode.GetMapUIInfo(mapID)
        local scores, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
        local outputRow = {
            mapID = mapID,
            mapName = mapName,
            mapTimer = mapTimer,
            overallScore = overallScore or 0,
            scores = {}
        }

        for _, info in ipairs(scores or {}) do
            local stars
            if info.durationSec < mapTimer * 0.6 then
                stars = '+++'
            elseif info.durationSec < mapTimer * 0.8 then
                stars = '++'
            elseif info.durationSec < mapTimer then
                stars = '+'
            else
                stars= ''
            end
            outputRow.scores[info.name] = { score=info.score, level=format('%s%d', stars, info.level) }
        end
        table.insert(output, outputRow)
    end

    table.sort(output,
        function (a, b)
            if a.overallScore ~= b.overallScore then
                return a.overallScore > b.overallScore
            else
                return a.mapName < b.mapName
            end
        end)
    return output
end

LiteKeystone_AddonCompartmentFunc = function () LiteKeystoneInfo:Show() end
