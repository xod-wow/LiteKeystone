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

local addonName = ...

local printTag = ORANGE_FONT_COLOR_CODE.."LiteKeystone: "..FONT_COLOR_CODE_CLOSE

local function printf(fmt, ...)
    local msg = string.format(fmt, ...)
    SELECTED_CHAT_FRAME:AddMessage(printTag .. msg)
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

local function IsBNetWowAccount(gameAccountInfo)
    return gameAccountInfo ~= nil
        and gameAccountInfo.clientProgram == BNET_CLIENT_WOW
        and gameAccountInfo.wowProjectID == 1
        and gameAccountInfo.isInCurrentRegion == true
end

local function GetWoWGameAccountID(bnFriendIndex)
    for gameAccountIndex = 1, C_BattleNet.GetFriendNumGameAccounts(bnFriendIndex) do
        local info = C_BattleNet.GetFriendGameAccountInfo(bnFriendIndex, gameAccountIndex)
        if IsBNetWowAccount(info) then
            return info.gameAccountID
        end
    end
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
    [ 1] = 1500390000,  -- US
    [ 2] = 0,           -- KR
    [ 3] = 1500447600,  -- EU
    [ 4] = 1500505200,  -- TW
    [ 5] = 0,           -- CN
}

function LiteKeystone:Debug(...)
    --@debug@
    local ts = BetterDate(TIMESTAMP_FORMAT_HHMMSS_24HR, time())
    local msg = format(...)
    table.insert(self.messageLog, ts .. " " .. msg)
    self:Fire()
    --@end-debug@
end

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

function LiteKeystone:RequestData()
    lor.RequestKeystoneDataFromGuild()
    self:RequestKeysFromGuild()
    self:RequestKeysFromFriends()
end

local function GetRegion()
    local info = C_BattleNet.GetGameAccountInfoByGUID(UnitGUID('player'))
    return info and info.regionID or GetCurrentRegion()
end

-- Astral Keys' idea of the week number
local function WeekNum()
    local r = GetRegion()
    local startTime = regionStartTimes[r] or regionStartTimes[1]
    return math.floor( (GetServerTime() - startTime) / 604800 )
end

-- How many seconds we are into the current keystone week
local function WeekTime()
    local r = GetRegion()
    local startTime = regionStartTimes[r] or regionStartTimes[1]
    return math.floor( (GetServerTime() - startTime ) % 604800 )
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
        self:RequestData()
        return true
    end

    if arg1 == 'reset' then
        self:Reset()
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

-- In 11.1 Blizzard added (or enforced?) listing 5 affix numbers. This should
-- only be needed for transition and then I can delete it.

function LiteKeystone:FixDBKeyLinks()
    local function IsValid(link)
        return link and link:find("|Hkeystone:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+|h") ~= nil
    end
    for _, key in pairs(self.db.playerKeys) do
        if not IsValid(key.link) then
            key.link = self:GetKeystoneLink(key)
        end
    end
end

function LiteKeystone:Initialize()

    self.callbacks = {}

    LiteKeystoneDB = LiteKeystoneDB or {}
    self.db = LiteKeystoneDB
    self.db.playerKeys = self.db.playerKeys or {}
    self.db.uiScale = self.db.uiScale or 1.0

    self.messageLog = {}

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
    self:FixDBKeyLinks()
    EventUtil.ContinueOnAddOnLoaded('RaiderIO', function () self:UpdateKeyRatings() end)

    C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')

    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('BN_CHAT_MSG_ADDON')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
    self:RegisterEvent('CHALLENGE_MODE_START')
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

    self:DelayScan('Initialize')

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
            local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
            if mapName then mapTable[mapName] = mapID end
        end
    end
    return mapTable[name]
end

function LiteKeystone:GetMyKeyFromLink(link)
    local linkType, linkOptions = LinkUtil.ExtractLink(link)
    local fields = { string.split(':', linkOptions) }
    local itemID, mapID, keyLevel

    if linkType == 'keystone' then
        itemID = tonumber(fields[1])
        mapID = tonumber(fields[2])
        keyLevel = tonumber(fields[3])
    elseif linkType == 'item' then
        itemID = fields[1]
        local numBonus = tonumber(fields[13]) or 0
        local numModifiers = tonumber(fields[14+numBonus]) or 0
        for i = 0, numModifiers-1 do
            local k = tonumber(fields[15+numBonus+2*i])
            local v = tonumber(fields[15+numBonus+2*i+1])
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

function LiteKeystone:AnnounceNewKeystone(newKey)
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return
    elseif C_ChallengeMode.IsChallengeModeActive() then
        return
    else
        local msg = string.format("New <%s> %s", addonName, newKey.link)
        SendChatMessage(msg, 'PARTY')
    end
end

function LiteKeystone:ProcessItem(item)
    if item:GetItemID() ~= 180653 then
        return
    end

    local db = self.db.playerKeys

    local newKey = self:GetMyKeyFromLink(item:GetItemLink())

    self:Debug('Found key: mapid %d (%s), level %d, weekbest %d, rating %d.',
            newKey.mapID, newKey.mapName, newKey.keyLevel, newKey.weekBest, newKey.rating)

    local existingKey = db[self.playerName]

    if self:IsNewKey(existingKey, newKey) then
        self:Debug('New key, saving.')
        db[self.playerName] = newKey
        self:AnnounceNewKeystone(newKey)
        self:PushMyKeys(newKey)
        self:Fire()
    elseif self:IsNewPlayerData(existingKey, newKey) then
        self:Debug('New player data, saving.')
        db[self.playerName] = newKey
        self:PushMyKeys(newKey)
        self:Fire()
    elseif not self:IsMyKey(existingKey) then
        self:Debug('Replacing received key with new key.')
        db[self.playerName] = newKey
    else
        self:Debug('Same key, ignored.')
    end
end

-- Don't call C_MythicPlus.RequestMapInfo here or it'll infinite loop
function LiteKeystone:ScanAndPushKeys(reason)
    self:Debug('Scanning my keys: %s.', tostring(reason))
    self:Debug("> GetActiveChallengeMapID: %s", tostring(C_ChallengeMode.GetActiveChallengeMapID()))
    self:Debug("> HasSlottedKeystone: %s", tostring(C_ChallengeMode.HasSlottedKeystone()))
    self:Debug("> IsChallengeModeActive: %s", tostring(C_ChallengeMode.IsChallengeModeActive()))
    do
        local id, _, level = C_ChallengeMode.GetSlottedKeystoneInfo()
        self:Debug("> GetSlottedKeystoneInfo: id=%s, level=%s", tostring(id), tostring(level))
    end
    do
        local id, level, time, onTime, plusLevels = C_ChallengeMode.GetCompletionInfo()
        self:Debug("> GetCompletionInfo: id=%s level=%s time=%s onTime=%s plusLevels=%s",
            tostring(id), tostring(level), tostring(time), tostring(onTime), tostring(plusLevels))
    end

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

function LiteKeystone:GetKeyUpdateString(key, isGuild)
    -- UpdateV9 format, no faction included
    return format('%s:%s:%d:%d:%d:%d:%d',
                   key.playerName,
                   key.playerClass,
                   key.mapID,
                   key.keyLevel,
                   key.weekBest,
                   key.weekNum,
                   key.rating
                )
end

function LiteKeystone:GetKeySyncString(key, isGuild)
    if isGuild then
        return format('%s:%s:%d:%d:%d:%d:%d:%d',
                       key.playerName,
                       key.playerClass,
                       key.mapID,
                       key.keyLevel,
                       key.weekBest,
                       key.weekNum,
                       key.weekTime,
                       key.rating
                    )
    else
        return format('%s:%s:%d:%d:%d:%d:%d:%d:%d',
                       key.playerName,
                       key.playerClass,
                       key.mapID,
                       key.keyLevel,
                       key.weekNum,
                       key.weekTime,
                       key.playerFaction,
                       key.weekBest,
                       key.rating
                    )
    end
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
    for _,key in pairs(self.db.playerKeys) do
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

function LiteKeystone:RespondToPing(source)
    local msg = 'BNet_query response'
    if type(source) == 'number' then
        BNSendGameData(source, 'AstralKeys', msg)
    else
        C_ChatInfo.SendAddonMessage('AstralKeys', msg, 'WHISPER', nil, source)
    end
end

function LiteKeystone:PushMyKeys(key, recipient)

    key = key or self:MyKey()

    if not key then return end

    local msgWhisper = 'update5 ' .. self:GetKeyUpdateString(key, false)
    local msgGuild = 'updateV9 ' .. self:GetKeyUpdateString(key, true)

    if recipient then
        if type(recipient) == 'number' then
            BNSendGameData(recipient, 'AstralKeys', msgWhisper)
        else
            C_ChatInfo.SendAddonMessage('AstralKeys', msgWhisper, 'WHISPER', recipient)
        end
    else
        if IsInGuild() then
            C_ChatInfo.SendAddonMessage('AstralKeys', msgGuild, 'GUILD')
        end

        local numFriends = BNGetNumFriends()
        for i = 1, numFriends do
            local gameAccountID = GetWoWGameAccountID(i)
            if gameAccountID then
                BNSendGameData(gameAccountID, 'AstralKeys', msgWhisper)
            end
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
        self:Debug('%s via %s: %s %s', newKey.source, action, newKey.playerName, newKey.link or UNKNOWN)
    end

    self.db.playerKeys[newKey.playerName] = newKey

    self:Fire()

    return true
end

function LiteKeystone:GetKeyFromUpdate5(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, playerFaction, rating = string.split(':', content)

    -- Make sure we got all the fields.
    if not rating or not tonumber(rating) then return end

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
        rating=tonumber(rating),
        source=source
    }

    newKey.link = self:GetKeystoneLink(newKey)

    self:UpdateKeyRating(newKey)

    return newKey
end

-- There are two incompatible sync6 packets coming from AstralKeys
-- GUILD   playerName playerClass mapID keyLevel weekBest weekNum  weekTime rating
-- WHISPER playerName playerClass mapID keyLevel weekNum  weekTime faction  weekBest rating

function LiteKeystone:GetKeyFromSync6(content, source)
    local fields = { string.split(':', content) }

    local playerName, playerClass, mapID, keyLevel, weekNum, weekTime, playerFaction, weekBest, rating
    if #fields == 9 then
        playerName, playerClass, mapID, keyLevel, weekNum, weekTime, playerFaction, weekBest, rating = unpack(fields)
    else
        playerName, playerClass, mapID, keyLevel, weekBest, weekNum, weekTime, rating = unpack(fields)
    end

    -- Make sure we got all the fields.
    if not rating or not tonumber(rating) then return end

    local newKey = {
        itemID=180653,
        playerName=playerName,
        playerClass=playerClass,
        playerFaction=playerFaction or self.playerFaction,
        mapID=tonumber(mapID),
        mapName=C_ChallengeMode.GetMapUIInfo(tonumber(mapID)),
        keyLevel=tonumber(keyLevel),
        weekBest=tonumber(weekBest),
        weekNum=tonumber(weekNum),
        weekTime=tonumber(weekTime),
        rating=tonumber(rating),
        source=source
    }

    newKey.link = self:GetKeystoneLink(newKey)

    self:UpdateKeyRating(newKey)

    return newKey
end

-- AK still sending V8 and V9 where V9 has faction appended. V8 is a broken
-- format because we can no longer assume guild members are the same faction
-- as we are. LiteKeystone doesn't use faction for anything anyway.

function LiteKeystone:GetKeyFromUpdateV(content, source)
    local playerName, playerClass, mapID, keyLevel, weekBest, weekNum, rating, playerFaction = string.split(':', content)

    if not rating then return end

    local newKey = {
        itemID=180653,
        playerName=playerName,
        playerClass=playerClass,
        playerFaction=playerFaction or self.playerFaction,
        mapID=tonumber(mapID),
        mapName=C_ChallengeMode.GetMapUIInfo(tonumber(mapID)),
        keyLevel=tonumber(keyLevel),
        weekBest=tonumber(weekBest),
        weekNum=tonumber(weekNum),
        weekTime=WeekTime(),
        rating=tonumber(rating),
        source=source
    }

    newKey.link = self:GetKeystoneLink(newKey)

    self:UpdateKeyRating(newKey)

    return newKey
end

-- XXX I should turn this into a proper iterator
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
            local msg = self:GetKeySyncString(self.db.playerKeys[name], true)
            table.insert(guildKeys, msg)
        end
    end

    if #guildKeys == 0 then return end

    for _,msg in ipairs(batch(guildKeys, 240)) do
        C_ChatInfo.SendAddonMessage('AstralKeys', 'sync6 ' .. msg, 'GUILD')
    end
end

-- Assumes LibOpenraid-1.0 and LibStub exist, don't call unless true

-- LibOpenRaid doesn't pass self even though it insists on a method
function LiteKeystone.UpdateOpenRaidKeys()
    local self = LiteKeystone

    for unitName, info in pairs(lor.GetAllKeystonesInfo()) do
        if not unitName:find('-', nil, true) then
            unitName = unitName .. '-' .. self.playerRealm
        end
        if info.challengeMapID ~= 0 then
            local newKey = {
                itemID=180653,
                playerName=unitName,
                playerClass=select(2, GetClassInfo(info.classID)),
                playerFaction=self.playerFaction,
                mapID=info.challengeMapID,
                mapName=C_ChallengeMode.GetMapUIInfo(info.challengeMapID),
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

function LiteKeystone:RequestKeysFromFriends()
    local numFriends = BNGetNumFriends()
    for i = 1, numFriends do
        local gameAccountID = GetWoWGameAccountID(i)
        if gameAccountID then
            BNSendGameData(gameAccountID, 'AstralKeys', 'BNet_query ping')
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

function LiteKeystone:GetPlayerName(key, useColor, hideRealm)
    local p = key.playerName
    if hideRealm then
        p = strsplit('-', p)
    else
        p = p:gsub('-.*'..self.playerRealm, '')
    end
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
    -- Everything is in the same week so just assume current affixes
    local affixes = self:GetAffixes()

    -- Sometimes this is called at long before the affix info is available.
    if not affixes then return end

    local affixFormat
    if key.keyLevel >= 12 then
        affixFormat = '%d:%d:%d:%d:0'
    elseif key.keyLevel >= 10 then
        affixFormat = '%d:%d:%d:0:0'
    elseif key.keyLevel >= 7 then
        affixFormat = '%d:%d:0:0:0'
    elseif key.keyLevel >= 4 then
        affixFormat = '%d:0:0:0:0'
    else
        affixFormat = '0:0:0:0:0'
    end

    local affixString = string.format(affixFormat, unpack(affixes))

    return string.format(
            '|cffa335ee|Hkeystone:180653:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            key.mapID, key.keyLevel, affixString, key.mapName, key.keyLevel
    )
end

function LiteKeystone:GetPrintString(key, useColor, hideRealm)
    local player = self:GetPlayerName(key, useColor, hideRealm)
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
        local msg = self:GetPrintString(key, false, chatType == 'PARTY')
        SendChatMessage(msg, chatType, nil, chatArg)
    end
end

function LiteKeystone:ProcessAddonMessage(text, source)
    local action, content = string.split(' ', text, 2)


    if source == self.playerName then return end

    if action == 'updateV9' or action == 'updateV8' then
        self:Debug('DATA %s: %s %s', tostring(source), action, content)
        local newKey = self:GetKeyFromUpdateV(content, source)
        if newKey then
            self:ReceiveKey(newKey, action, true)
        end
    elseif action == 'update5' then
        self:Debug('DATA %s: %s %s', tostring(source), action, content)
        local newKey = self:GetKeyFromUpdate5(content, source)
        if newKey then
            self:ReceiveKey(newKey, action, true)
        end
    elseif action == 'sync6' then
        for entry in content:gmatch('[^_]+') do
            self:Debug('DATA %s: %s %s', tostring(source), action, entry)
            local newKey = self:GetKeyFromSync6(entry, source)
            if newKey then
                self:ReceiveKey(newKey, action)
            end
        end
    elseif action == 'updateWeekly' then
        self:Debug('DATA %s: %s %s', tostring(source), action, content)
        self:UpdateWeekly(source, tonumber(content))
    elseif action == 'BNet_query' then
        self:Debug('DATA %s: %s %s', tostring(source), action, content)
        if content == 'ping' then
            self:RespondToPing(source)
        elseif content == 'response' then
            self:PushMyKeys(nil, source)
        end
    elseif action == 'request' then
        self:Debug('DATA %s: %s', tostring(source), action)
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
    local gameAccountInfo = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
    if IsBNetWowAccount(gameAccountInfo) then
        self:ProcessAddonMessage(text, gameAccountID)
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
    if trigger then self:Debug('DelayScan ' .. trigger) end
    C_Timer.After(delay or 1, function () self:ScanAndPushKeys(trigger) end)
end

-- This used to be reliably fired every time C_MythicPlus.RequestMapInfo() was
-- called and used to be the primary scan trigger. At some point Blizzard
-- started caching the data locally and not re-triggering unless something
-- changed so that doesn't work any more.

function LiteKeystone:CHALLENGE_MODE_MAPS_UPDATE()
    self:DelayScan('CHALLENGE_MODE_MAPS_UPDATE')
end

-- As soon as you start a keystone the key level lowers by one but you don't
-- get an ITEM_CHANGED event. I used not to care about this but LibOpenRaid
-- updates it right away which can cause issues. It's equaly annoying that
-- AstralKeys also has this issue and then we keep flipflopping between
-- believing AstralKeys and LibOpenRaid.

function LiteKeystone:CHALLENGE_MODE_START()
    self:DelayScan('CHALLENGE_MODE_START')
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

function LiteKeystone:GetKeyScore(key)
    local _, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(key.mapID)
    return overallScore or 0
end

local function GetAffixRatingBonus(key)
    local bonus = 0
    if key.keyLevel >= 4 then bonus = bonus + 15 end
    if key.keyLevel >= 7 then bonus = bonus + 15 end
    if key.keyLevel >= 10 then bonus = bonus + 15 end
    if key.keyLevel >= 12 then bonus = bonus + 15 end
    return bonus
end

function LiteKeystone:GetRatingIncreaseForTimingKey(key)
    local curTotal = self:GetKeyScore(key)
    local newTotal = 125 + 15*key.keyLevel + GetAffixRatingBonus(key)
    return max(newTotal-curTotal, 0)
end

local function GetSeasonBestForMap(mapID)
    local inTimeInfo, overTimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
    if not inTimeInfo then
        return overTimeInfo
    elseif not overTimeInfo then
        return inTimeInfo
    elseif inTimeInfo.dungeonScore >= overTimeInfo.dungeonScore then
        return inTimeInfo
    else
        return overTimeInfo
    end
end

function LiteKeystone:GetResilienceLevel()
    local levels = {}
    for _, mapID in pairs(C_ChallengeMode.GetMapTable()) do
        local inTimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        if inTimeInfo then
            table.insert(levels, inTimeInfo.level)
        else
            return  -- at least one with no timed score, bail out
        end
    end
    local minAllTimed = math.min(unpack(levels))
    if minAllTimed >= 12 then
        return minAllTimed
    end
end

function LiteKeystone:SortedDungeons()
    local output = { }

    for _, mapID in pairs(C_ChallengeMode.GetMapTable()) do
        local mapName, _, mapTimer = C_ChallengeMode.GetMapUIInfo(mapID)
        local info = GetSeasonBestForMap(mapID)
        local outputRow = {
            mapID = mapID,
            mapName = mapName,
            mapTimer = mapTimer
        }
        if info then
            -- Challenger's Peril adds 90s to timer (not scaled for + rating)
            local extraTime = info.level >= 12 and 90 or 0
            outputRow.mapTimer = mapTimer + extraTime
            outputRow.overallScore = info.dungeonScore
            local stars
            if info.durationSec < mapTimer * 0.6 + extraTime then
                stars = '+++'
            elseif info.durationSec < mapTimer * 0.8 + extraTime then
                stars = '++'
            elseif info.durationSec < mapTimer + extraTime then
                stars = '+'
            else
                stars= ''
            end
            outputRow.level = format('%s%d', stars, info.level)
            outputRow.durationSec = info.durationSec
        end
        table.insert(output, outputRow)
    end

    table.sort(output,
        function (a, b)
            if a.overallScore ~= b.overallScore then
                return (a.overallScore or 0) > (b.overallScore or 0)
            else
                return a.mapName < b.mapName
            end
        end)
    return output
end

LiteKeystone_AddonCompartmentFunc = function () LiteKeystoneInfo:Show() end
