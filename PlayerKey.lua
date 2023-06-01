local _, LK = ...

LK.PlayerKey = {}

function LK.PlayerKey:IsMyKey()
    return self.source == 'mine'
end

function LK.PlayerKey:IsFactionKey(faction)
    return self.playerFaction == faction
end

function LK.PlayerKey:IsGroupKey(playerName)
    if self.playerName == playerName then
        return true
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) do
            local name, realm = UnitName("raid"..i)
            local fullName = string.join('-', name, realm or self.playerRealm)
            if self.playerName == fullName then
                return true
            end
        end
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        for i = 1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) - 1 do
            local name, realm = UnitName("party"..i)
            local fullName = string.join('-', name, realm or self.playerRealm)
            if self.playerName == fullName then
                return true
            end
        end
    else
        return self:IsGuildKey(self, true)
    end
end

function LK.PlayerKey:IsGuildKey()
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if self.playerName == name and ( isOnline or not requireOnline ) then
            return true
        end
    end
end

function LK.PlayerKey:IsMyGuildKey()
    return self:IsMyKey() or self:IsGuildKey()
end

function LK.PlayerKey:IsMyFactionKey(faction)
    return self:IsMyKey() and self:IsFactionKey(faction)
end

function LK.PlayerKey:IsNewKey(newKey)
    if not newKey then
        return false
    else
        return ( self.mapID ~= newKey.mapID or self.keyLevel ~= newKey.keyLevel )
    end
end

function LK.PlayerKey:IsNewBest(weekBest)
    return ( key and ( weekBest or 0 ) > ( self.weekBest or 0  ) )
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

function LK.PlayerKey:CreateFromLink(link, source, weekBest)
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
        source=source,
    }

    setmetatable(newKey, { __index = self })

    newKey:UpdateKeyRating()

    return newKey
end

function LK.PlayerKey:GetKeyUpdateString()
    return format('%s:%s:%d:%d:%d:%d:%s',
                   self.playerName,
                   self.playerClass,
                   self.mapID,
                   self.keyLevel,
                   self.weekBest,
                   self.weekNum,
                   self.playerFaction
                )
end

function LK.PlayerKey:GetKeySyncString()
    return format('%s:%s:%d:%d:%d:%d:%s',
                   self.playerName,
                   self.playerClass,
                   self.mapID,
                   self.keyLevel,
                   self.weekBest,
                   self.weekNum,
                   self.weekTime
                )
end

function LK.PlayerKey:UpdateKeyRating(playerName)
    if playerName == self.playerName then
        self.rating = C_ChallengeMode.GetMapUIInfo(tonumber(mapID))
        local n, r = string.split('-', self.playerName)
        local p = RaiderIO.GetProfile(n, r)
        if p and p.mythicKeystoneProfile.mplusCurrent then
            self.rating = max(self.rating or 0, p.mythicKeystoneProfile.mplusCurrent.score)
        end
    end
end

function LK.PlayerKey:IsExpired()
    return self.weekNum == WeekNum()
end

function LK.PlayerKey:UpdateWeekBest(weekBest)
    self.weekBest = weekBest
    self.weekTime = WeekTime()
end

function LK.PlayerKey:CreateFromSync(content, source)
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

    setmetatable(newKey, { __index = self })

    newKey:UpdateLink()
    newKey:UpdateKeyRating()

    return newKey
end

function LK.PlayerKey:CreateFromUpdate(content, source)
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

    setmetatable(newKey, { __index = self })

    newKey:UpdateLink()
    newKey:UpdateKeyRating()

    return newKey
end

function LK.PlayerKey:CreateFromOpenRaid(unitName, info)
    if not unitName:find('-') then
        unitName = unitName .. '-' .. GetRealmName()
    end

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

    setmetatable(newKey, { __index = self })

    newKey:UpdateLink()

    return newKey
end

function LK.PlayerKey:GetKeyText()
    return string.format('|cffa335ee%s (%d)|r', self.mapName, self.keyLevel)
end


local function GetAffixes()
    local affixInfo = C_MythicPlus.GetCurrentAffixes()
    if not affixInfo then return end

    local affixes = { }
    for _, info in ipairs(affixInfo) do
        table.insert(affixes, info.id)
    end
    return affixes
end

function LK.PlayerKey:UpdateLink()
    local affixes = GetAffixes()

    -- Sometimes this is called at long before the affix info is available.
    if not affixes then return end

    local affixFormat
    if self.keyLevel > 9 then
        affixFormat = '%d:%d:%d:%d'
    elseif self.keyLevel > 6 then
        affixFormat = '%d:%d:%d:0'
    elseif self.keyLevel > 3 then
        affixFormat = '%d:%d:0:0'
    else
        affixFormat = '%d:0:0:0'
    end

    local affixString = string.format(affixFormat, unpack(affixes))
    self.link = string.format(
            '|cffa335ee|Hkeystone:180653:%d:%d:%s|h[Keystone: %s (%d)]|h|r',
            self.mapID, self.keyLevel, affixString, self.mapName, self.keyLevel
        )
end

function LiteKeystone:GetPlayerString(useColor)
    local p = self.playerName:gsub('-'..self.playerRealm, '')
    if useColor then
        return RAID_CLASS_COLORS[self.playerClass]:WrapTextInColorCode(p)
    else
        return p
    end
end

function LK.PlayerKey:GetPrintString(useColor)
    local player = self:GetPlayerString(useColor)
    return string.format('%s : %s : best %d', player, self.link, self.weekBest)
end
