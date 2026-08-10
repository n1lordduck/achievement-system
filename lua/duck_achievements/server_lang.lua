--// ── DuckAch.Lang (servidor) ──────────────────────────────────────────────
--// Persiste o idioma ativo + overrides de string em data/, e sincroniza com
--// os clientes. Só superadmin (ou grupo listado em Config.SuperadminGroups)
--// pode alterar.

local Lang = DuckAch.Lang

local langFile = DuckAch.Config.DataDir .. "lang_data.txt"

util.AddNetworkString("DuckAch.Lang.Sync")
util.AddNetworkString("DuckAch.Lang.SetActive")
util.AddNetworkString("DuckAch.Lang.SetOverride")
util.AddNetworkString("DuckAch.Lang.ResetOverride")
util.AddNetworkString("DuckAch.Lang.RequestSync")
util.AddNetworkString("DuckAch.Lang.SetPlayerPref")

--// Preferência PESSOAL de cada jogador (não é persistida no servidor — o
--// client já guarda isso localmente e reenvia toda vez que entra).
Lang.PlayerPrefs = Lang.PlayerPrefs or {}

--// Idioma efetivo pra ESTE jogador: preferência pessoal dele, senão o padrão do servidor.
function Lang.EffectiveFor(ply)
    if IsValid(ply) then
        local pref = Lang.PlayerPrefs[ply:SteamID64()]
        if pref and Lang.IsValidLanguage(pref) then return pref end
    end
    return Lang.Current
end

--// Atalho: texto já traduzido no idioma pessoal de um jogador específico.
function DuckAch.LFor(ply, key, ...)
    return Lang.GetIn(Lang.EffectiveFor(ply), key, ...)
end

local function isSuperAdmin(ply)
    if not IsValid(ply) then return false end
    for _, g in ipairs(DuckAch.Config.SuperadminGroups) do
        if ply:IsUserGroup(g) then return true end
    end
    return ply:IsSuperAdmin()
end

function DuckAch.Lang.Persist()
    if not file.IsDir(DuckAch.Config.DataDir, "DATA") then
        file.CreateDir(DuckAch.Config.DataDir)
    end

    local data = {
        active    = Lang.Current,
        overrides = Lang.Overrides,
    }

    file.Write(langFile, util.TableToJSON(data, true))
    DuckAchLogger.debug("Language configuration saved.")
end

function DuckAch.Lang.LoadPersisted()
    if not file.Exists(langFile, "DATA") then return end

    local raw = file.Read(langFile, "DATA")
    if not raw or raw == "" then return end

    local data = util.JSONToTable(raw)
    if not data then return end

    if data.active and Lang.IsValidLanguage(data.active) then
        Lang.Current = data.active
    end

    if data.overrides then
        Lang.Overrides = data.overrides
    end

    DuckAchLogger.info("Language loaded: " .. Lang.Current)
end

--// Manda o estado completo (idioma ativo + overrides) pro(s) cliente(s)
function DuckAch.Lang.SendSync(target)
    net.Start("DuckAch.Lang.Sync")
        net.WriteString(Lang.Current)
        net.WriteString(util.TableToJSON(Lang.Overrides))
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

DuckAch.Lang.LoadPersisted()

hook.Add("PlayerInitialSpawn", "DuckAch.Lang.SyncOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            DuckAch.Lang.SendSync(ply)
        end
    end)
end)

net.Receive("DuckAch.Lang.RequestSync", function(_, ply)
    DuckAch.Lang.SendSync(ply)
end)

net.Receive("DuckAch.Lang.SetActive", function(_, ply)
    if not isSuperAdmin(ply) then return end

    local langcode = net.ReadString()
    if not Lang.IsValidLanguage(langcode) then return end

    Lang.Current = langcode
    DuckAch.Lang.Persist()
    DuckAch.Lang.SendSync(nil)

    DuckAchLogger.info(ply:Nick() .. " mudou o idioma do addon para: " .. langcode)
end)

net.Receive("DuckAch.Lang.SetOverride", function(_, ply)
    if not isSuperAdmin(ply) then return end

    local langcode = net.ReadString()
    local key      = net.ReadString()
    local value    = net.ReadString()

    if not Lang.IsValidLanguage(langcode) or key == "" then return end

    Lang.Overrides[langcode] = Lang.Overrides[langcode] or {}
    Lang.Overrides[langcode][key] = value

    DuckAch.Lang.Persist()
    DuckAch.Lang.SendSync(nil)
end)

net.Receive("DuckAch.Lang.ResetOverride", function(_, ply)
    if not isSuperAdmin(ply) then return end

    local langcode = net.ReadString()
    local key      = net.ReadString()

    if Lang.Overrides[langcode] then
        Lang.Overrides[langcode][key] = nil
    end

    DuckAch.Lang.Persist()
    DuckAch.Lang.SendSync(nil)
end)

--// Qualquer jogador pode escolher seu idioma pessoal (não precisa ser admin).
net.Receive("DuckAch.Lang.SetPlayerPref", function(_, ply)
    if not IsValid(ply) then return end

    local has = net.ReadBool()
    if has then
        local langcode = net.ReadString()
        if Lang.IsValidLanguage(langcode) then
            Lang.PlayerPrefs[ply:SteamID64()] = langcode
        end
    else
        Lang.PlayerPrefs[ply:SteamID64()] = nil
    end
end)

hook.Add("PlayerDisconnect", "DuckAch.Lang.CleanupPref", function(ply)
    if IsValid(ply) then
        Lang.PlayerPrefs[ply:SteamID64()] = nil
    end
end)
