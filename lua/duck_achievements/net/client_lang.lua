--// ── DuckAch.Lang (cliente) ───────────────────────────────────────────────
--// Recebe o idioma PADRÃO DO SERVIDOR + overrides do servidor.
--// Guarda a preferência PESSOAL do jogador localmente (arquivo em data/,
--// no PC do próprio jogador — segue ele em qualquer servidor) e avisa o
--// servidor sobre ela (pra texto gerado server-side, tipo sub-labels de
--// progresso, também sair traduzido).

local Lang = DuckAch.Lang
local PREF_FILE = "duckach_lang_pref.txt"

net.Receive("DuckAch.Lang.Sync", function()
    local active    = net.ReadString()
    local overrides = util.JSONToTable(net.ReadString()) or {}

    if Lang.IsValidLanguage(active) then
        Lang.Current = active
    end
    Lang.Overrides = overrides

    hook.Run("DuckAch.Lang.Updated")
end)

local function sendPlayerPrefToServer()
    net.Start("DuckAch.Lang.SetPlayerPref")
        net.WriteBool(Lang.PlayerPref ~= nil)
        if Lang.PlayerPref then net.WriteString(Lang.PlayerPref) end
    net.SendToServer()
end

local function loadPlayerPref()
    if file.Exists(PREF_FILE, "DATA") then
        local v = file.Read(PREF_FILE, "DATA")
        if v and Lang.IsValidLanguage(v) then
            Lang.PlayerPref = v
        end
    end
end
loadPlayerPref()

--// Define (ou limpa, passando nil) o idioma PESSOAL do jogador.
--// Isso tem prioridade sobre o padrão do servidor, só nesta máquina.
function DuckAch.Lang.SetPlayerLanguage(langcode)
    if langcode ~= nil and not Lang.IsValidLanguage(langcode) then return end

    Lang.PlayerPref = langcode

    if langcode then
        file.Write(PREF_FILE, langcode)
    elseif file.Exists(PREF_FILE, "DATA") then
        file.Delete(PREF_FILE)
    end

    sendPlayerPrefToServer()
    hook.Run("DuckAch.Lang.Updated")
end

hook.Add("InitPostEntity", "DuckAch.Lang.RequestSyncOnInit", function()
    timer.Simple(0.5, function()
        net.Start("DuckAch.Lang.RequestSync")
        net.SendToServer()

        if Lang.PlayerPref then
            sendPlayerPrefToServer()
        end
    end)
end)

--// Helpers de envio pro painel admin (idioma PADRÃO DO SERVIDOR + strings)
function DuckAch.Lang.RequestSetActive(langcode)
    net.Start("DuckAch.Lang.SetActive")
        net.WriteString(langcode)
    net.SendToServer()
end

function DuckAch.Lang.RequestSetOverride(langcode, key, value)
    net.Start("DuckAch.Lang.SetOverride")
        net.WriteString(langcode)
        net.WriteString(key)
        net.WriteString(value)
    net.SendToServer()
end

function DuckAch.Lang.RequestResetOverride(langcode, key)
    net.Start("DuckAch.Lang.ResetOverride")
        net.WriteString(langcode)
        net.WriteString(key)
    net.SendToServer()
end
