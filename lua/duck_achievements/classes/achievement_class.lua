local Achievement = {}
Achievement.__index = Achievement

local VALID_TYPES = {
    ["get_killed_by_x"]                      = true,
    ["spawn_x_entity"]                       = true,
    ["spawn_x_entity_y_times"]               = true,
    ["get_x_usergroup"]                      = true,
    ["die_by_x_entity"]                      = true,
    ["interact_with_x_entity"]               = true,
    ["get_x_killstreak"]                     = true,
    ["get_x_killstreak_with_y_weapon"]       = true,
    ["say_specific_phrase"]                  = true,
    ["reach_playtime_hours"]                 = true,
    ["total_kills_x"]                        = true,
    ["total_killbind_x"]                     = true,
    ["kill_streak_then_suicide"]             = true,
    ["multi_requirement"]                    = true,
    ["kill_revenge_leaver"]                  = true,
    ["kill_x_with_weapon"]                   = true,
    ["headshot_airborne"]                    = true,
    ["kill_with_low_health"]                 = true,
    ["not_kill_or_die_x_minutes"]            = true,
    ["get_all_achievements"]                 = true,
    ["first_join_hour"]                      = true,
    ["respawn_after_x_minutes_dead"]         = true,
    ["kill_x_loners"]                        = true,
    ["kill_with_same_weapon"]                = true,
    ["survive_explosion_at_1hp"]             = true,
    ["die_by_all_present_no_retaliation"]    = true,
    ["complete_rarity_x"]                    = true,
    ["noscope_360_kill"]                     = true,
}

function Achievement.new(def)
    local self = setmetatable({}, Achievement)

    self.id          = def.id
    self.name        = def.name
    self.description = def.description
    self.rarity      = def.rarity      or "common"
    self.thumbnail   = def.thumbnail   or nil
    self.secret      = def.secret      or false
    self.triggerType = def.triggerType
    self.params      = def.params      or {}

    local ok, err = self:validate()
    if not ok then return nil, err end

    return self
end

function Achievement:validate()
    if not self.id or self.id == ""          then return false, "id ausente" end
    if not self.name or self.name == ""      then return false, "name ausente" end
    if not self.description                  then return false, "description ausente" end
    if not DuckAch.Rarities[self.rarity]     then return false, "rarity inválida: " .. tostring(self.rarity) end
    if not self.triggerType                  then return false, "triggerType ausente" end
    if not VALID_TYPES[self.triggerType]     then return false, "triggerType desconhecido: " .. self.triggerType end

    return true
end

function Achievement:getPublicView(playerHasIt)
    if self.secret and not playerHasIt then
        return {
            id          = self.id,
            name        = "???",
            description = "Conquista secreta. Descubra como desbloqueá-la.",
            rarity      = self.rarity,
            thumbnail   = nil,
            secret      = true,
            locked      = true,
            triggerType = nil,  --// propositalmente omitido: não vaza mecânica de secretas
        }
    end

    return {
        id          = self.id,
        name        = self.name,
        description = self.description,
        rarity      = self.rarity,
        thumbnail   = self.thumbnail,
        secret      = self.secret,
        locked      = false,
        triggerType = self.triggerType,
    }
end

function Achievement:isType(t)
    return self.triggerType == t
end

function Achievement:getParam(key)
    return self.params[key]
end

DuckAch.Achievement = Achievement
