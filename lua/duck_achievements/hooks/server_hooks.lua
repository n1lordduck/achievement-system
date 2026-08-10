local function setupHooks()
    local reg = DuckAch.Registry
    local api = DuckAch.API

    local GetByType    = function(t) return reg.GetByType(t) end
    local HasAnyOfType = function(t) return reg.HasAnyOfType(t) end
    local GetProfile   = DuckAch.Data.GetProfile
    local SendProgress = DuckAch.Net.SendProgress
    local playerGetAll = player.GetAll
    local IsValid      = IsValid
    local CurTime      = CurTime

    local function grantAllIfComplete(ply, profile)
        if not HasAnyOfType("get_all_achievements") then return end
        local total = DuckAch.Registry.Count()
        local have  = profile:unlockedCount()
        for _, ach in ipairs(GetByType("get_all_achievements")) do
            if have >= total and not profile:hasAchievement(ach.id) then
                api.Grant(ply, ach.id)
            end
        end
    end

    local function readSubRequirementValue(ply, profile, subType, subParams)
        if subType == "reach_playtime_hours" then
            return profile.playtime / 3600, (subParams.hours or 1)
        elseif subType == "total_kills_x" then
            return profile.kills, (subParams.kills or 1)
        elseif subType == "total_killbind_x" then
            return profile.killbindCount, (subParams.count or 1)
        elseif subType == "spawn_x_entity_y_times" then
            local classname = subParams.classname or ""
            local key = (classname == "" or classname == "any")
                and "_multireq_spawn_any"
                or  "_multireq_spawn_" .. classname
            return profile:getCounter(key), (subParams.times or 1)
        elseif subType == "kill_x_with_weapon" then
            return profile:getCounter("_multireq_weapon_" .. (subParams.weapon or "")), (subParams.kills or 1)
        elseif subType == "not_kill_or_die_x_minutes" then
            if profile.pacifistSince <= 0 then return 0, (subParams.minutes or 1) end
            return (CurTime() - profile.pacifistSince) / 60, (subParams.minutes or 1)
        end
        return 0, 1
    end

    local function checkMultiRequirement(ply, profile)
        if not HasAnyOfType("multi_requirement") then return end
        for _, ach in ipairs(GetByType("multi_requirement")) do
            if profile:hasAchievement(ach.id) then continue end
            local subReqs = ach:getParam("requirements") or {}
            if #subReqs == 0 then continue end
            local allMet = true
            for _, sub in ipairs(subReqs) do
                local current, needed = readSubRequirementValue(ply, profile, sub.type, sub.params or {})
                if current < needed then allMet = false; break end
            end
            if allMet then api.Grant(ply, ach.id) end
        end
    end

    local hasKillHooks = HasAnyOfType("get_x_killstreak")
        or HasAnyOfType("total_kills_x")
        or HasAnyOfType("kill_revenge_leaver")
        or HasAnyOfType("headshot_airborne")
        or HasAnyOfType("kill_with_low_health")
        or HasAnyOfType("kill_x_with_weapon")
        or HasAnyOfType("kill_x_loners")
        or HasAnyOfType("not_kill_or_die_x_minutes")
        or HasAnyOfType("respawn_after_x_minutes_dead")
        or reg.HasAnyKillRelated()

    if hasKillHooks then
        hook.Add("PlayerDeath", "AchievementSystem.PlayerDeath.TrackAll", function(victim, inflictor, attacker)
            local victimProfile = GetProfile(victim)
            --// Saves killstreak BEFORE addDeath() resets it - used by
            --// TrackKillbind to check kill_streak_then_suicide
            victimProfile._ksBeforeDeath = victimProfile.killstreak
            victimProfile:addDeath()
            victimProfile.pacifistSince = 0
            victimProfile.lastDeathTime = CurTime()

            local weapClass = IsValid(inflictor) and inflictor:GetClass() or ""

            --// Only processes kill achievements when the attacker is ANOTHER player.
            --// Suicides (attacker == victim or attacker invalid) are handled
            --// exclusively in the TrackKillbind hook below.
            local isRealKill = IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim

            if isRealKill then
                local atkProfile = GetProfile(attacker)
                atkProfile:addKill()
                atkProfile.pacifistSince = 0

                local ks = atkProfile.killstreak

                for _, ach in ipairs(GetByType("get_x_killstreak")) do
                    if ks >= ach:getParam("kills") and not atkProfile:hasAchievement(ach.id) then
                        api.Grant(attacker, ach.id)
                    end
                end

                for _, ach in ipairs(GetByType("get_x_killstreak_with_y_weapon")) do
                    if weapClass == ach:getParam("weapon") then
                        atkProfile:incrementCounter(ach.id)
                        if atkProfile:getCounter(ach.id) >= (ach:getParam("kills") or 1) and not atkProfile:hasAchievement(ach.id) then
                            api.Grant(attacker, ach.id)
                        end
                    else
                        atkProfile:setCounter(ach.id, 0)
                    end
                end

                for _, ach in ipairs(GetByType("get_killed_by_x")) do
                    if not victimProfile:hasAchievement(ach.id) then
                        local targetSid = ach:getParam("steamid")
                        local isAdmin   = attacker:IsAdmin() or attacker:IsSuperAdmin()
                        if targetSid == attacker:SteamID() or (targetSid == "ADMIN" and isAdmin) then
                            api.Grant(victim, ach.id)
                        end
                    end
                end

                for _, ach in ipairs(GetByType("total_kills_x")) do
                    if atkProfile.kills >= (ach:getParam("kills") or 1) and not atkProfile:hasAchievement(ach.id) then
                        api.Grant(attacker, ach.id)
                    end
                end

                for _, ach in ipairs(GetByType("kill_x_with_weapon")) do
                    if weapClass == ach:getParam("weapon") and not atkProfile:hasAchievement(ach.id) then
                        if atkProfile:incrementCounter(ach.id) >= (ach:getParam("kills") or 1) then
                            api.Grant(attacker, ach.id)
                        end
                    end
                end

                --// Weapon counters for multi_requirement sub-requirements
                if HasAnyOfType("multi_requirement") then
                    for _, ach in ipairs(GetByType("multi_requirement")) do
                        for _, sub in ipairs(ach:getParam("requirements") or {}) do
                            if sub.type == "kill_x_with_weapon" then
                                local subWeapon = (sub.params or {}).weapon
                                if subWeapon and weapClass == subWeapon then
                                    atkProfile:incrementCounter("_multireq_weapon_" .. subWeapon)
                                end
                            end
                        end
                    end
                end

                --// headshot_airborne: victim airborne (not touching the ground)
                if HasAnyOfType("headshot_airborne") and victim:GetGroundEntity() == NULL then
                    for _, ach in ipairs(GetByType("headshot_airborne")) do
                        if not atkProfile:hasAchievement(ach.id) then
                            api.Grant(attacker, ach.id)
                        end
                    end
                end

                --// kill_with_low_health: attacker at <= 10 HP when getting the kill
                if HasAnyOfType("kill_with_low_health") then
                    if attacker:Health() <= 10 then
                        for _, ach in ipairs(GetByType("kill_with_low_health")) do
                            if not atkProfile:hasAchievement(ach.id) then
                                api.Grant(attacker, ach.id)
                            end
                        end
                    end
                end

                --// kill_x_loners: no one else within radius of the death
                if HasAnyOfType("kill_x_loners") then
                    local LONER_RADIUS_SQR = 1500 * 1500
                    local deathPos = victim:GetPos()
                    local isolated = true
                    for _, p in ipairs(playerGetAll()) do
                        if IsValid(p) and p ~= attacker and p ~= victim and p:Alive() then
                            if p:GetPos():DistToSqr(deathPos) <= LONER_RADIUS_SQR then
                                isolated = false
                                break
                            end
                        end
                    end
                    if isolated then
                        for _, ach in ipairs(GetByType("kill_x_loners")) do
                            if not atkProfile:hasAchievement(ach.id) then
                                if atkProfile:incrementCounter(ach.id) >= (ach:getParam("kills") or 1) then
                                    api.Grant(attacker, ach.id)
                                end
                            end
                        end
                    end
                end

                --// kill_revenge_leaver
                if HasAnyOfType("kill_revenge_leaver") then
                    local victimSid = victim:SteamID()
                    if attacker:GetNWString("DuckAch_RevengeTarget", "") == victimSid then
                        for _, ach in ipairs(GetByType("kill_revenge_leaver")) do
                            if not atkProfile:hasAchievement(ach.id) then
                                api.Grant(attacker, ach.id)
                            end
                        end
                        attacker:SetNWString("DuckAch_RevengeTarget", "")
                    end
                end

                attacker:SetNWFloat("DuckAch_LastKillTime", CurTime())
                grantAllIfComplete(attacker, atkProfile)
                checkMultiRequirement(attacker, atkProfile)
                SendProgress(attacker)
            end

            --// die_by_x_entity (doesn't depend on being killed by another player)
            for _, ach in ipairs(GetByType("die_by_x_entity")) do
                local infClass = IsValid(inflictor) and inflictor:GetClass() or ""
                if infClass == ach:getParam("classname") and not victimProfile:hasAchievement(ach.id) then
                    api.Grant(victim, ach.id)
                end
            end

            grantAllIfComplete(victim, victimProfile)
            checkMultiRequirement(victim, victimProfile)
            SendProgress(victim)
        end)

        if HasAnyOfType("respawn_after_x_minutes_dead") then
            hook.Add("PlayerSpawn", "AchievementSystem.Player.TrackRespawnTime", function(ply)
                local profile   = GetProfile(ply)
                local deathTime = profile.lastDeathTime
                if deathTime <= 0 then return end
                local deadSecs = CurTime() - deathTime
                for _, ach in ipairs(GetByType("respawn_after_x_minutes_dead")) do
                    if deadSecs >= (ach:getParam("minutes") or 30) * 60 and not profile:hasAchievement(ach.id) then
                        api.Grant(ply, ach.id)
                    end
                end
                profile.lastDeathTime = 0
            end)
        end
    end

    if HasAnyOfType("kill_revenge_leaver") then
        hook.Add("PlayerDisconnected", "AchievementSystem.Player.TrackRevenge", function(ply)
            local sid = ply:SteamID()
            timer.Simple(10, function()
                for _, p in ipairs(playerGetAll()) do
                    if IsValid(p) and p:GetNWString("DuckAch_RevengeTarget", "") == sid then
                        p:SetNWString("DuckAch_RevengeTarget", "")
                    end
                end
            end)
            local lastVictimSid = ply:GetNWString("DuckAch_LastVictim", "")
            if lastVictimSid == "" then return end
            for _, p in ipairs(playerGetAll()) do
                if IsValid(p) and p:SteamID() == lastVictimSid then
                    p:SetNWString("DuckAch_RevengeTarget", sid)
                    timer.Simple(10, function()
                        if IsValid(p) then p:SetNWString("DuckAch_RevengeTarget", "") end
                    end)
                    break
                end
            end
        end)
    end

    if HasAnyOfType("spawn_x_entity") or HasAnyOfType("spawn_x_entity_y_times") or HasAnyOfType("multi_requirement") then
        hook.Add("OnEntityCreated", "AchievementSystem.Entity.TrackSpawn", function(ent)
            timer.Simple(0.05, function()
                if not IsValid(ent) then return end
                local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
                if not IsValid(owner) or not owner:IsPlayer() then return end

                local model    = (ent:GetModel() or ""):lower()
                local entClass = ent:GetClass():lower()
                local isProp   = entClass == "prop_physics" or entClass == "prop_physics_multiplayer"
                local profile  = GetProfile(owner)

                for _, ach in ipairs(GetByType("spawn_x_entity")) do
                    local target  = (ach:getParam("classname") or ""):lower()
                    local isMatch = (target ~= "" and model == target) or (target == "any" and isProp)
                    if isMatch and not profile:hasAchievement(ach.id) then
                        api.Grant(owner, ach.id)
                    end
                end

                local isWire = entClass:find("^wire_") or entClass:find("^gmod_wire_") or entClass:find("^sent_wire")

                for _, ach in ipairs(GetByType("spawn_x_entity_y_times")) do
                    local target  = (ach:getParam("classname") or ""):lower()
                    local isMatch = (target ~= "" and model == target)
                        or (target == "any" and isProp)
                        or (target == "any_wire" and isWire)
                    if isMatch and not profile:hasAchievement(ach.id) then
                        if profile:incrementCounter(ach.id) >= (ach:getParam("times") or 1) then
                            api.Grant(owner, ach.id)
                        end
                    end
                end

                if HasAnyOfType("multi_requirement") then
                    for _, ach in ipairs(GetByType("multi_requirement")) do
                        if profile:hasAchievement(ach.id) then continue end
                        for _, sub in ipairs(ach:getParam("requirements") or {}) do
                            if sub.type ~= "spawn_x_entity_y_times" then continue end
                            local target  = ((sub.params or {}).classname or ""):lower()
                            local isMatch = (target == "any" and isProp) or (target ~= "" and model == target)
                            if not isMatch then continue end
                            local counterKey = (target == "any") and "_multireq_spawn_any" or ("_multireq_spawn_" .. target)
                            profile:incrementCounter(counterKey)
                        end
                    end
                    checkMultiRequirement(owner, profile)
                    SendProgress(owner)
                end
            end)
        end)
    end

    if HasAnyOfType("get_x_usergroup") then
        local function checkUsergroup(ply)
            if not IsValid(ply) then return end
            local profile  = GetProfile(ply)
            local curGroup = ply:GetUserGroup()
            for _, ach in ipairs(GetByType("get_x_usergroup")) do
                if curGroup == ach:getParam("usergroup") and not profile:hasAchievement(ach.id) then
                    api.Grant(ply, ach.id)
                end
            end
        end

        hook.Add("EntityNetworkedVarChanged", "AchievementSystem.Player.TrackUsergroup", function(ent, name, old, new)
            if name ~= "UserGroup" or not IsValid(ent) or not ent:IsPlayer() or old == new then return end
            checkUsergroup(ent)
        end)

        hook.Add("PlayerSpawn", "AchievementSystem.Player.UsergroupOnSpawn", function(ply)
            timer.Simple(0.5, function() checkUsergroup(ply) end)
        end)
    end

    hook.Add("PlayerSay", "AchievementSystem.Chat.Commands", function(ply, text)
        local cmd = DuckAch.LFor(ply, "chat.command")
        if text:lower() == "!" .. cmd:lower() then
            net.Start("DuckAch.OpenMenu"); net.Send(ply)
            return ""
        end
        if text == "!achmin" and (ply:IsSuperAdmin() or ply:IsUserGroup("superadmin")) then
            net.Start("DuckAch.OpenAdmin"); net.Send(ply)
            return ""
        end
    end)

    if HasAnyOfType("say_specific_phrase") then
        hook.Add("PlayerSay", "AchievementSystem.Chat.TrackPhrase", function(ply, text)
            local profile = GetProfile(ply)
            for _, ach in ipairs(GetByType("say_specific_phrase")) do
                if profile:hasAchievement(ach.id) then continue end
                local phrase    = ach:getParam("phrase") or ""
                local cs        = ach:getParam("caseSensitive")
                local cmp       = cs and text or text:lower()
                local phraseCmp = cs and phrase or phrase:lower()
                if cmp == phraseCmp then api.Grant(ply, ach.id) end
            end
        end)
    end

    if HasAnyOfType("interact_with_x_entity") then
        hook.Add("PlayerUse", "AchievementSystem.Entity.TrackInteract", function(ply, ent)
            if not IsValid(ent) or not IsValid(ply) then return end
            local entId = ent:GetNWString("DuckAch_EntId", "")
            if entId == "" then return end
            api.TriggerInteract(ply, entId)
        end)
    end

    if HasAnyOfType("reach_playtime_hours") or HasAnyOfType("multi_requirement") then
        timer.Create("AchievementSystem.Player.PlaytimeTick", 60, 0, function()
            for _, ply in ipairs(playerGetAll()) do
                if not IsValid(ply) then continue end
                local profile = GetProfile(ply)
                profile.playtime = profile.playtime + 60
                local hours = profile.playtime / 3600
                for _, ach in ipairs(GetByType("reach_playtime_hours")) do
                    if hours >= (ach:getParam("hours") or 1) and not profile:hasAchievement(ach.id) then
                        api.Grant(ply, ach.id)
                    end
                end
                checkMultiRequirement(ply, profile)
            end
        end)
    end

    --// Killbind / suicide - the ONLY place that counts voluntary deaths.
    --// kill_streak_then_suicide is the only achievement that uses suicide
    --// as an intentional mechanic.
    if HasAnyOfType("total_killbind_x") or HasAnyOfType("kill_streak_then_suicide") then
        hook.Add("PlayerDeath", "AchievementSystem.Player.TrackKillbind", function(victim, inflictor, attacker)
            --// Only counts pure suicide (no other player as attacker)
            if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then return end

            local profile   = GetProfile(victim)
            --// _ksBeforeDeath was saved by TrackAll before addDeath()
            --// If TrackAll hasn't run yet (hook order), use killstreak directly
            local ksAtDeath = profile._ksBeforeDeath or profile.killstreak
            profile._ksBeforeDeath = nil  --// clear the temp field

            profile.killbindCount = profile.killbindCount + 1

            for _, ach in ipairs(GetByType("total_killbind_x")) do
                if profile.killbindCount >= (ach:getParam("count") or 1) and not profile:hasAchievement(ach.id) then
                    api.Grant(victim, ach.id)
                end
            end

            for _, ach in ipairs(GetByType("kill_streak_then_suicide")) do
                if ksAtDeath >= (ach:getParam("kills") or 10) and not profile:hasAchievement(ach.id) then
                    api.Grant(victim, ach.id)
                end
            end

            SendProgress(victim)
        end)
    end

    if HasAnyOfType("not_kill_or_die_x_minutes") then
        timer.Create("AchievementSystem.Player.PacifistTick", 30, 0, function()
            for _, ply in ipairs(playerGetAll()) do
                if not IsValid(ply) then continue end
                local profile = GetProfile(ply)
                if profile.pacifistSince <= 0 then continue end
                local elapsed = CurTime() - profile.pacifistSince
                for _, ach in ipairs(GetByType("not_kill_or_die_x_minutes")) do
                    if elapsed >= (ach:getParam("minutes") or 30) * 60 and not profile:hasAchievement(ach.id) then
                        api.Grant(ply, ach.id)
                    end
                end
            end
        end)

        hook.Add("PlayerSpawn", "AchievementSystem.Player.PacifistStart", function(ply)
            local profile = GetProfile(ply)
            if profile.pacifistSince <= 0 then
                profile.pacifistSince = CurTime()
            end
        end)
    end

    if HasAnyOfType("first_join_hour") then
        hook.Add("PlayerInitialSpawn", "AchievementSystem.Player.TrackFirstJoinHour", function(ply)
            local profile = GetProfile(ply)
            local hour    = tonumber(os.date("%H"))
            for _, ach in ipairs(GetByType("first_join_hour")) do
                if profile:hasAchievement(ach.id) then continue end
                local hoursStr = ach:getParam("hours") or ""
                for h in tostring(hoursStr):gmatch("[^,]+") do
                    if tonumber(h) == hour then api.Grant(ply, ach.id); break end
                end
            end
        end)
    end

    --// kill_with_same_weapon: kill with the same weapon that killed you
    --// Stores the last weapon that killed the player via NW; when they kill
    --// someone, checks whether the weapon matches the one the attacker last died to.

    if HasAnyOfType("kill_with_same_weapon") then
        hook.Add("PlayerDeath", "AchievementSystem.PlayerDeath.TrackSameWeapon", function(victim, inflictor, attacker)
            local isRealKill = IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim
            if not isRealKill then return end

            local weapClass = IsValid(inflictor) and inflictor:GetClass() or ""

            --// Marks the weapon that killed the victim (so they can use it later for revenge)
            victim:SetNWString("DuckAch_KilledByWeapon", weapClass)

            --// Checks whether the attacker is killing with the weapon that killed them before
            local revengeWeapon = attacker:GetNWString("DuckAch_KilledByWeapon", "")
            if revengeWeapon ~= "" and weapClass == revengeWeapon then
                local profile = GetProfile(attacker)
                for _, ach in ipairs(GetByType("kill_with_same_weapon")) do
                    if not profile:hasAchievement(ach.id) then
                        api.Grant(attacker, ach.id)
                    end
                end
            end
        end)
    end

    --// survive_explosion_at_1hp: take an explosion and end up at 1 HP
    --// EntityTakeDamage fires BEFORE the damage is actually applied by the engine,
    --// so computing "Health() - GetDamage()" by hand isn't reliable (armor,
    --// multipliers from other addons, etc. can change the final applied value).
    --// Instead, we wait 1 tick and read the REAL, already-processed Health().

    if HasAnyOfType("survive_explosion_at_1hp") then
        hook.Add("EntityTakeDamage", "AchievementSystem.Player.TrackExplosionSurvive", function(target, dmginfo)
            if not IsValid(target) or not target:IsPlayer() then return end
            if not dmginfo:IsExplosionDamage() then return end
            if dmginfo:GetDamage() <= 0 then return end

            timer.Simple(0, function()
                if not IsValid(target) or not target:Alive() then return end
                if target:Health() ~= 1 then return end

                local profile = GetProfile(target)
                for _, ach in ipairs(GetByType("survive_explosion_at_1hp")) do
                    if not profile:hasAchievement(ach.id) then
                        api.Grant(target, ach.id)
                    end
                end
            end)
        end)
    end

    --// die_by_all_present_no_retaliation: die to everyone without retaliating
    --// Tracked per session (per player life): which online players have already
    --// killed you. Reset when you deal any damage to a player, when you die to
    --// the last remaining player (grant moment), or when you respawn.

    if HasAnyOfType("die_by_all_present_no_retaliation") then
        --// _pacifistDeaths[steamid] = set of steamids that have already killed the player
        --// _pacifistCaused[steamid] = true if they dealt damage (invalidates the session)
        local _pacifistDeaths = {}
        local _pacifistCaused = {}

        local function resetPacifistSession(sid)
            _pacifistDeaths[sid] = nil
            _pacifistCaused[sid] = nil
        end

        hook.Add("PlayerSpawn", "AchievementSystem.Player.ResetPacifistDeaths", function(ply)
            resetPacifistSession(ply:SteamID())
        end)

        hook.Add("EntityTakeDamage", "AchievementSystem.Player.TrackPacifistDamage", function(target, dmginfo)
            if not IsValid(target) or not target:IsPlayer() then return end
            local attacker = dmginfo:GetAttacker()
            if not IsValid(attacker) or not attacker:IsPlayer() then return end
            if attacker == target then return end

            --// If the player dealt damage, invalidate their session
            local sid = attacker:SteamID()
            if _pacifistDeaths[sid] then
                _pacifistCaused[sid] = true
            end
        end)

        hook.Add("PlayerDeath", "AchievementSystem.PlayerDeath.TrackPacifistKilled", function(victim, inflictor, attacker)
            local isRealKill = IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim
            if not isRealKill then return end

            local sid = victim:SteamID()
            if _pacifistCaused[sid] then return end  -- already dealt damage, session invalid

            _pacifistDeaths[sid] = _pacifistDeaths[sid] or {}
            _pacifistDeaths[sid][attacker:SteamID()] = true

            --// Checks whether every human present has already killed the victim
            local humans = player.GetHumans()
            local allKilled = true
            for _, p in ipairs(humans) do
                if IsValid(p) and p ~= victim then
                    if not _pacifistDeaths[sid][p:SteamID()] then
                        allKilled = false
                        break
                    end
                end
            end

            if allKilled and table.Count(_pacifistDeaths[sid]) >= 1 then
                local profile = GetProfile(victim)
                for _, ach in ipairs(GetByType("die_by_all_present_no_retaliation")) do
                    if not profile:hasAchievement(ach.id) then
                        api.Grant(victim, ach.id)
                    end
                end
                resetPacifistSession(sid)
            end
        end)
    end

    --// complete_rarity_x: complete 100% of a rarity's achievements
    --// Checked on Grant - if after unlocking an achievement the player has
    --// every achievement of a given rarity, grants the corresponding medal.

    if HasAnyOfType("complete_rarity_x") then
        hook.Add("AchievementSystem.API.OnGrant", "AchievementSystem.Player.TrackRarityComplete", function(ply, achDef, profile)
            local rarities = {}
            for _, ach in pairs(DuckAch.Registry.GetAll()) do
                if ach.triggerType ~= "complete_rarity_x" then
                    rarities[ach.rarity] = rarities[ach.rarity] or { total = 0, have = 0 }
                    rarities[ach.rarity].total = rarities[ach.rarity].total + 1
                    if profile:hasAchievement(ach.id) then
                        rarities[ach.rarity].have = rarities[ach.rarity].have + 1
                    end
                end
            end

            for _, ach in ipairs(GetByType("complete_rarity_x")) do
                if profile:hasAchievement(ach.id) then continue end
                local targetRarity = ach:getParam("rarity")
                local stats = rarities[targetRarity]
                if stats and stats.total > 0 and stats.have >= stats.total then
                    api.Grant(ply, ach.id)
                end
            end
        end)
    end

    if HasAnyOfType("noscope_360_kill") then
        local SNIPER_WEAPONS = {
            ["m9k_intervention"] = true,
            ["m9k_barret_m82"]   = true,
            ["m9k_m98b"]         = true,
            ["m9k_m24"]          = true,
        }

        local _lastShotYaw  = {}
        local _yawAccum     = {}
        local _lastMoveTime = {}

        local WINDOW_TIME = 1.5

        hook.Add("PlayerTick", "AchievementSystem.Player.Track360Accumulate", function(ply)
            if not IsValid(ply) or not ply:Alive() then return end

            local weapon = ply:GetActiveWeapon()
            if not IsValid(weapon) or not SNIPER_WEAPONS[weapon:GetClass()] then
                _lastShotYaw[ply]  = nil
                _yawAccum[ply]     = nil
                _lastMoveTime[ply] = nil
                return
            end

            local curYaw = ply:EyeAngles().y

            if not _lastShotYaw[ply] then
                _lastShotYaw[ply]  = curYaw
                _yawAccum[ply]     = 0
                _lastMoveTime[ply] = CurTime()
                return
            end

            local delta = math.AngleDifference(curYaw, _lastShotYaw[ply])
            local absDelta = math.abs(delta)

            if absDelta > 1 then
                _yawAccum[ply] = (_yawAccum[ply] or 0) + absDelta
                _lastMoveTime[ply] = CurTime()
            else

                if _lastMoveTime[ply] and (CurTime() - _lastMoveTime[ply]) > WINDOW_TIME then
                    _yawAccum[ply] = 0
                end
            end

            _lastShotYaw[ply] = curYaw
        end)

        hook.Add("PlayerDeath", "AchievementSystem.PlayerDeath.Track360Kill", function(victim, inflictor, attacker)
            local isRealKill = IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim
            if not isRealKill then return end

            local weapon = attacker:GetActiveWeapon()
            if not IsValid(weapon) or not SNIPER_WEAPONS[weapon:GetClass()] then return end


            if _lastMoveTime[attacker] and (CurTime() - _lastMoveTime[attacker]) <= WINDOW_TIME then
                local accum = _yawAccum[attacker] or 0

                DuckAchLogger.debug(string.format(
                    "[360] %s killed %s - accumulated spin: %.2f deg",
                    attacker:Nick(), victim:Nick(), accum
                ))

                if accum >= 360 then
                    local profile = GetProfile(attacker)
                    for _, ach in ipairs(GetByType("noscope_360_kill")) do
                        if not profile:hasAchievement(ach.id) then
                            api.Grant(attacker, ach.id)
                        end
                    end
                end
            end

            if _yawAccum[attacker] then _yawAccum[attacker] = 0 end
        end)

        hook.Add("PlayerDisconnected", "AchievementSystem.Player.Track360Clean", function(ply)
            _lastShotYaw[ply]  = nil
            _yawAccum[ply]     = nil
            _lastMoveTime[ply] = nil
        end)
    end

    hook.Add("AchievementSystem.Admin.HooksRebuild", "AchievementSystem.Hooks.RebuildAll", function()
        local hooksToRemove = {
            { "PlayerDeath",               "AchievementSystem.PlayerDeath.TrackAll"              },
            { "PlayerSpawn",               "AchievementSystem.Player.TrackRespawnTime"            },
            { "PlayerSpawn",               "AchievementSystem.Player.UsergroupOnSpawn"            },
            { "PlayerSpawn",               "AchievementSystem.Player.PacifistStart"               },
            { "PlayerSpawn",               "AchievementSystem.Player.ResetPacifistDeaths"         },
            { "PlayerDisconnected",        "AchievementSystem.Player.TrackRevenge"                },
            { "PlayerInitialSpawn",        "AchievementSystem.Player.TrackFirstJoinHour"          },
            { "OnEntityCreated",           "AchievementSystem.Entity.TrackSpawn"                  },
            { "EntityNetworkedVarChanged", "AchievementSystem.Player.TrackUsergroup"              },
            { "EntityTakeDamage",          "AchievementSystem.Player.TrackExplosionSurvive"       },
            { "EntityTakeDamage",          "AchievementSystem.Player.TrackPacifistDamage"         },
            { "PlayerSay",                 "AchievementSystem.Chat.Commands"                      },
            { "PlayerSay",                 "AchievementSystem.Chat.TrackPhrase"                   },
            { "PlayerUse",                 "AchievementSystem.Entity.TrackInteract"               },
            { "PlayerDeath",               "AchievementSystem.Player.TrackKillbind"               },
            { "PlayerDeath",               "AchievementSystem.PlayerDeath.TrackSameWeapon"        },
            { "PlayerDeath",               "AchievementSystem.PlayerDeath.TrackPacifistKilled"    },
            { "AchievementSystem.API.OnGrant", "AchievementSystem.Player.TrackRarityComplete"     },
            { "WeaponFired",               "AchievementSystem.Player.Track360"                   },
            { "Think",                     "AchievementSystem.Player.Track360Accumulate"          },
            { "PlayerDeath",               "AchievementSystem.PlayerDeath.Track360Kill"           },
        }
        for _, r in ipairs(hooksToRemove) do hook.Remove(r[1], r[2]) end

        timer.Remove("AchievementSystem.Player.PlaytimeTick")
        timer.Remove("AchievementSystem.Player.PacifistTick")

        setupHooks()
        DuckAchLogger.info("Hooks rebuilt.")
    end)
end

setupHooks()