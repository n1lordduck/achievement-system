DuckAch.Data = {}

local dataDir   = DuckAch.Config.DataDir
local profilesFile = dataDir .. "profiles.txt"

local _profiles = {}

local function ensureDir()
    if not file.IsDir(dataDir, "DATA") then
        file.CreateDir(dataDir)
    end
end

local function serializeAll()
    local out = {}
    for sid, profile in pairs(_profiles) do
        out[sid] = profile:serialize()
    end
    return util.Compress(util.TableToJSON(out))
end

local function deserializeAll(raw)
    if not raw or raw == "" then return {} end
    local decompressed = util.Decompress(raw)
    if not decompressed then
        DuckAchLogger.warn("Failed to decompress data, trying as raw JSON")
        decompressed = raw
    end
    return util.JSONToTable(decompressed) or {}
end

function DuckAch.Data.Load()
    ensureDir()

    local raw = file.Read(profilesFile, "DATA")
    local tableData = deserializeAll(raw)

    for sid, t in pairs(tableData) do
        _profiles[sid] = DuckAch.PlayerProfile.fromTable(sid, t)
    end

    DuckAchLogger.info("Profiles loaded: " .. table.Count(_profiles))
end

function DuckAch.Data.Save()
    ensureDir()
    file.Write(profilesFile, serializeAll())
    DuckAchLogger.debug("Profiles saved.")
end

function DuckAch.Data.GetProfile(ply)
    local sid = ply:SteamID()
    if not _profiles[sid] then
        _profiles[sid] = DuckAch.PlayerProfile.new(sid)
        DuckAchLogger.debug("New profile created: " .. sid)
    end
    return _profiles[sid]
end

function DuckAch.Data.GetProfileBySteamId(sid)
    return _profiles[sid]
end

function DuckAch.Data.GetTotalPlayers()
    return table.Count(_profiles)
end

--// Owner-count cache per achId - invalidated when Grant is called (see server_api)
--// Avoids an O(n) scan on every GetStats call.
local _ownerCountCache = {}

function DuckAch.Data.InvalidateOwnerCount(achId)
    _ownerCountCache[achId] = nil
end

function DuckAch.Data.GetAchievementOwnerCount(achId)
    if _ownerCountCache[achId] then
        return _ownerCountCache[achId]
    end

    local n = 0
    for _, profile in pairs(_profiles) do
        if profile:hasAchievement(achId) then n = n + 1 end
    end

    _ownerCountCache[achId] = n
    return n
end

function DuckAch.Data.ClearPlayerCache(ply)
    local profile = DuckAch.Data.GetProfile(ply)
    profile.optOutCache = false
    DuckAch.Data.Save()
end

function DuckAch.Data.SetOptOut(ply, state)
    local profile = DuckAch.Data.GetProfile(ply)
    profile.optOutCache = state
    DuckAch.Data.Save()
end

hook.Add("Initialize", "AchievementSystem.Data.Load", function()
    DuckAch.Data.Load()
end)

hook.Add("ShutDown", "AchievementSystem.Data.SaveOnShutdown", function()
    DuckAch.Data.Save()
end)

timer.Create("AchievementSystem.Data.AutoSave", DuckAch.Config.SaveInterval, 0, function()
    DuckAch.Data.Save()
end)


--// Comandos administrativos

concommand.Add("duckachiv_erase_all_profiles", function(ply, cmd, args)
    local isConsole = not IsValid(ply)
    if not isConsole and not ply:IsSuperAdmin() then return end

    local count = table.Count(_profiles)
    _profiles = {}
    DuckAch.Data.Save()

    DuckAchLogger.info("All profiles erased (" .. count .. " players).")
    if not isConsole then ply:ChatPrint(DuckAch.LFor(ply, "admin.erase_all_profiles_done", count)) end

    --// Resend zeroed-out data to whoever's online
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAch.Net.SendFullData(p)
        end
    end
end)

concommand.Add("duckachiv_erase_everything", function(ply, cmd, args)
    local isConsole = not IsValid(ply)
    if not isConsole and not ply:IsSuperAdmin() then return end

    --// Erase profiles
    _profiles = {}

    --// Delete data files
    local dataDir = DuckAch.Config.DataDir
    local filesToDelete = {
        dataDir .. "profiles.txt",
        dataDir .. "custom_achievements.txt",
        dataDir .. "marked_entities.txt",
    }
    for _, f in ipairs(filesToDelete) do
        if file.Exists(f, "DATA") then
            file.Delete(f)
            DuckAchLogger.info("Deleted: " .. f)
        end
    end

    --// Reset the owner-count cache
    _ownerCountCache = {}

    --// Remove custom achievements from the registry at runtime
    for id in pairs(DuckAch.Registry.GetAll()) do
        DuckAch.Registry.Remove(id)
    end

    --// Rebuild hooks (no achievements left, removes all of them)
    hook.Run("AchievementSystem.Admin.HooksRebuild")

    DuckAchLogger.info("Everything erased: profiles, custom achievements, marked entities.")
    if not isConsole then ply:ChatPrint(DuckAch.LFor(ply, "admin.erase_everything_done")) end

    --// Resend zeroed-out data to everyone
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAch.Net.SendFullData(p)
        end
    end
end)

--// Grants ALL registered achievements to the player. Useful for testing
--// the get_all_achievements achievement and validating the UI with everything unlocked.
--// Restricted to superadmin, console, or in-game.
concommand.Add("duckachiv_get_all", function(ply, cmd, args)
    local isConsole = not IsValid(ply)
    if not isConsole and not ply:IsSuperAdmin() then return end

    local targetPly = ply
    if isConsole then
        local name = args[1]
        if not name then
            DuckAchLogger.warn("Usage: duckachiv_get_all <player_name> (console) or run in-game to target yourself")
            return
        end
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Nick():lower():find(name:lower(), 1, true) then
                targetPly = p
                break
            end
        end
        if not IsValid(targetPly) then
            DuckAchLogger.warn("Player not found: " .. name)
            return
        end
    end

    if not IsValid(targetPly) then return end

    local granted = 0
    for id in pairs(DuckAch.Registry.GetAll()) do
        if DuckAch.API.Grant(targetPly, id) then
            granted = granted + 1
        end
    end

    DuckAchLogger.info(granted .. " achievement(s) granted to " .. targetPly:Name() .. ".")
    if not isConsole then ply:ChatPrint(DuckAch.LFor(ply, "admin.grant_all_done", granted, targetPly:Name())) end
end)
