local PlayerProfile = {}
PlayerProfile.__index = PlayerProfile

function PlayerProfile.new(steamId)
    local self = setmetatable({}, PlayerProfile)

    self.steamId      = steamId
    self.unlocked     = {}
    self.counters     = {}
    self.killstreak   = 0
    self.kills        = 0
    self.deaths       = 0
    self.optOutCache  = false
    self.playtime     = 0       --// total playtime in seconds
    self.killbindCount = 0      --// total killbinds
    self.lastDeathTime = 0      --// CurTime() at death (for respawn_after)
    self.pacifistSince = 0      --// CurTime() when pacifist mode started

    return self
end

function PlayerProfile.fromTable(steamId, t)
    local self = PlayerProfile.new(steamId)

    self.unlocked      = t.unlocked      or {}
    self.counters      = t.counters      or {}
    self.killstreak    = t.killstreak    or 0
    self.kills         = t.kills         or 0
    self.deaths        = t.deaths        or 0
    self.optOutCache   = t.optOutCache   or false
    self.playtime      = t.playtime      or 0
    self.killbindCount = t.killbindCount or 0
    self.lastDeathTime = 0
    self.pacifistSince = 0

    return self
end

function PlayerProfile:hasAchievement(achId)
    return self.unlocked[achId] ~= nil
end

function PlayerProfile:unlock(achId)
    if self:hasAchievement(achId) then return false end
    self.unlocked[achId] = os.time()
    return true
end

function PlayerProfile:getCounter(achId)
    return self.counters[achId] or 0
end

function PlayerProfile:incrementCounter(achId, amount)
    self.counters[achId] = (self.counters[achId] or 0) + (amount or 1)
    return self.counters[achId]
end

function PlayerProfile:setCounter(achId, value)
    self.counters[achId] = value
end

function PlayerProfile:resetKillstreak()
    self.killstreak = 0
end

function PlayerProfile:addKill()
    self.kills      = self.kills + 1
    self.killstreak = self.killstreak + 1
end

function PlayerProfile:addDeath()
    self.deaths     = self.deaths + 1
    self.killstreak = 0
end

function PlayerProfile:serialize()
    return {
        unlocked       = self.unlocked,
        counters       = self.counters,
        kills          = self.kills,
        deaths         = self.deaths,
        optOutCache    = self.optOutCache,
        playtime       = self.playtime,
        killbindCount  = self.killbindCount,
    }
end

function PlayerProfile:unlockedCount()
    local n = 0
    for _ in pairs(self.unlocked) do n = n + 1 end
    return n
end

DuckAch.PlayerProfile = PlayerProfile
