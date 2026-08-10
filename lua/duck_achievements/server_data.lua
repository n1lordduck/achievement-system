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
        DuckAchLogger.debug("Novo perfil criado: " .. sid)
    end
    return _profiles[sid]
end

function DuckAch.Data.GetProfileBySteamId(sid)
    return _profiles[sid]
end

function DuckAch.Data.GetTotalPlayers()
    return table.Count(_profiles)
end

--// Cache de contagem por achId — invalidado ao chamar Grant (ver server_api)
--// Evita O(n) scan a cada GetStats. Usa tabela sorted implicitamente por achId string.
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


--// ── Comandos administrativos ───────────────────────────────────────────────

concommand.Add("duckachiv_erase_all_profiles", function(ply, cmd, args)
    local isConsole = not IsValid(ply)
    if not isConsole and not ply:IsSuperAdmin() then return end

    local count = table.Count(_profiles)
    _profiles = {}
    DuckAch.Data.Save()

    local msg = "[DuckAch] All profiles erased (" .. count .. " players)."
    DuckAchLogger.info(msg)
    if not isConsole then ply:ChatPrint(msg) end

    --// Reenvia dados zerados pra quem está online
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAch.Net.SendFullData(p)
        end
    end
end)

concommand.Add("duckachiv_erase_everything", function(ply, cmd, args)
    local isConsole = not IsValid(ply)
    if not isConsole and not ply:IsSuperAdmin() then return end

    --// Apaga perfis
    _profiles = {}

    --// Apaga arquivos de dados
    local dataDir = DuckAch.Config.DataDir
    local filesToDelete = {
        dataDir .. "profiles.txt",
        dataDir .. "custom_achievements.txt",
        dataDir .. "marked_entities.txt",
    }
    for _, f in ipairs(filesToDelete) do
        if file.Exists(f, "DATA") then
            file.Delete(f)
            DuckAchLogger.info("Deletado: " .. f)
        end
    end

    --// Reseta cache de contagem
    _ownerCountCache = {}

    --// Apaga conquistas customizadas do registry em runtime
    for id in pairs(DuckAch.Registry.GetAll()) do
        DuckAch.Registry.Remove(id)
    end

    --// Reconstrói hooks (sem conquistas, remove todos)
    hook.Run("AchievementSystem.Admin.HooksRebuild")

    local msg = "[DuckAch] Everything erased: profiles, custom achievements, marked entities."
    DuckAchLogger.info(msg)
    if not isConsole then ply:ChatPrint(msg) end

    --// Reenvia dados zerados pra todos
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAch.Net.SendFullData(p)
        end
    end
end)

--// Concede TODAS as conquistas registradas ao jogador. Útil para testar a
--// conquista get_all_achievements e validar a UI com tudo desbloqueado.
--// Restrito a superadmin, console ou in-game.
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

    local msg = "[DuckAch] " .. granted .. " achievement(s) granted to " .. targetPly:Name() .. "."
    DuckAchLogger.info(msg)
    if not isConsole then ply:ChatPrint(msg) end
end)
