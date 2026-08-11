DuckAch.Registry = {}

local _byId   = {}
local _byType = {}

function DuckAch.Registry.Register(def)
    local ach, err = DuckAch.Achievement.new(def)
    if not ach then
        DuckAchLogger.warn("Invalid achievement '" .. tostring(def.id) .. "': " .. tostring(err))
        return false
    end

    if _byId[ach.id] then
        DuckAchLogger.warn("Duplicate achievement ignored: " .. ach.id)
        return false
    end

    _byId[ach.id] = ach

    _byType[ach.triggerType] = _byType[ach.triggerType] or {}
    table.insert(_byType[ach.triggerType], ach)

    DuckAchLogger.debug("Registered: " .. ach.id)
    return true
end

function DuckAch.Registry.Get(id)
    return _byId[id]
end

function DuckAch.Registry.GetAll()
    return _byId
end

function DuckAch.Registry.GetByType(triggerType)
    return _byType[triggerType] or {}
end

function DuckAch.Registry.HasAnyOfType(triggerType)
    return (_byType[triggerType] and #_byType[triggerType] > 0)
end

function DuckAch.Registry.HasAnyKillRelated()
    return DuckAch.Registry.HasAnyOfType("get_x_killstreak")
        or DuckAch.Registry.HasAnyOfType("get_x_killstreak_with_y_weapon")
        or DuckAch.Registry.HasAnyOfType("die_by_x_entity")
        or DuckAch.Registry.HasAnyOfType("get_killed_by_x")
end

function DuckAch.Registry.Count()
    local n = 0
    for _ in pairs(_byId) do n = n + 1 end
    return n
end

function DuckAch.Registry.Remove(id)
    local ach = _byId[id]
    if not ach then return end
    _byId[id] = nil
    local list = _byType[ach.triggerType]
    if list then
        for i, a in ipairs(list) do
            if a.id == id then table.remove(list, i) break end
        end
    end
end

--// Serializes every achievement to send to the client (respects secret)
function DuckAch.Registry.SerializeForPlayer(profile, ply)
    local out = {}
    for id, ach in pairs(_byId) do
        local hasIt = profile and profile:hasAchievement(id)
        out[id] = ach:getPublicView(hasIt, ply)
    end
    return out
end
