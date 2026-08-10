local PREFIX   = "[DuckAch]"
local debugCvar = CreateConVar("duck_ach_debug", "0", FCVAR_ARCHIVE, "Ativa logs de debug do DuckAchievements")

local Logger = {}

function Logger.info(msg)
    MsgC(Color(100, 200, 255), PREFIX .. " ", Color(220, 220, 220), tostring(msg) .. "\n")
end

function Logger.warn(msg)
    MsgC(Color(255, 200, 80), PREFIX .. " AVISO: ", Color(220, 220, 220), tostring(msg) .. "\n")
end

function Logger.err(msg)
    MsgC(Color(255, 80, 80), PREFIX .. " ERRO: ", Color(220, 220, 220), tostring(msg) .. "\n")
end

function Logger.debug(msg)
    if not debugCvar:GetBool() then return end
    MsgC(Color(150, 150, 150), PREFIX .. " DBG: ", Color(180, 180, 180), tostring(msg) .. "\n")
end

_G.DuckAchLogger = Logger

local sharedFiles = {
    "duck_achievements/shared_lang.lua",
    "duck_achievements/shared_config.lua",
    "duck_achievements/shared_rarities.lua",
    "duck_achievements/classes/achievement_class.lua",
    "duck_achievements/classes/profile_class.lua",
    "duck_achievements/shared_registry.lua",
    "duck_achievements/achievements/init.lua",
}

local serverFiles = {
    "duck_achievements/server_lang.lua",
    "duck_achievements/server_data.lua",
    "duck_achievements/server_api.lua",
    "duck_achievements/server_thumbnails.lua",
    "duck_achievements/net/server_net.lua",
    "duck_achievements/hooks/server_hooks.lua",
    "duck_achievements/admin/server_admin.lua",
}

local clientFiles = {
    "duck_achievements/net/client_net.lua",
    "duck_achievements/net/client_lang.lua",
    "duck_achievements/ui/client_fonts.lua",
    "duck_achievements/ui/client_hud.lua",
    "duck_achievements/ui/client_pin.lua",
    "duck_achievements/ui/client_menu.lua",
    "duck_achievements/ui/client_profile.lua",
    "duck_achievements/admin/client_admin.lua",
    "duck_achievements/admin/client_admin_lang.lua",
}

local function safeLoad(path, realm)
    local ok, err = pcall(function()
        if realm == "shared" then
            if SERVER then AddCSLuaFile(path) end
            include(path)
        elseif realm == "server" then
            if SERVER then include(path) end
        elseif realm == "client" then
            if SERVER then AddCSLuaFile(path) else include(path) end
        end
    end)

    if not ok then
        Logger.err("Falha ao carregar '" .. path .. "': " .. tostring(err))
    else
        Logger.debug("Carregado [" .. realm .. "]: " .. path)
    end
end

Logger.info("Iniciando...")
for _, f in ipairs(sharedFiles) do safeLoad(f, "shared") end
for _, f in ipairs(serverFiles) do safeLoad(f, "server") end
for _, f in ipairs(clientFiles) do safeLoad(f, "client") end
Logger.info("Pronto! " .. (DuckAch and DuckAch.Registry and DuckAch.Registry.Count() or 0) .. " conquistas carregadas.")
