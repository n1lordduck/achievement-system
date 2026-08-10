--// DuckAch.Lang (client)
--// Receives the SERVER DEFAULT language + overrides from the server.
--// Stores the player's PERSONAL preference locally (a file in data/,
--// on the player's own PC - follows them to any server) and tells the
--// server about it (so server-generated text, like progress sub-labels,
--// also comes out translated).

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

--// Sets (or clears, by passing nil) the player's PERSONAL language.
--// This takes priority over the server default, only on this machine.
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

--// Send helpers for the admin panel (SERVER DEFAULT language + strings)
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
