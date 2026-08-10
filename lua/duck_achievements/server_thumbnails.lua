DuckAch.Thumbnails = {}

local thumbDir   = DuckAch.Config.DataDir .. "thumbnails/"
local _cache     = {}  --// url -> { path, pending, callbacks }
local _netQueue  = {}  --// plyId -> { url, ... } esperando envio

util.AddNetworkString("DuckAch.SendThumbnail")
util.AddNetworkString("DuckAch.RequestThumbnail")

local function thumbFilename(url)
    return thumbDir .. util.CRC(url) .. ".dat"
end

local function ensureDir()
    if not file.IsDir(thumbDir, "DATA") then
        file.CreateDir(thumbDir)
    end
end

local function sendThumbToPlayer(ply, url, rawBytes)
    if not IsValid(ply) then return end
    if ply:GetNWBool("DuckAch_OptOut", false) then return end

    local encoded = util.Base64Encode(rawBytes)
    if #encoded > 250000 then
        DuckAchLogger.warn("Thumbnail muito grande para enviar via net: " .. url)
        return
    end

    net.Start("DuckAch.SendThumbnail")
        net.WriteString(url)
        net.WriteString(encoded)
    net.Send(ply)
    DuckAchLogger.debug("Thumbnail enviada para " .. ply:Name() .. ": " .. url)
end

local function downloadAndCache(url, onDone)
    if _cache[url] then
        if _cache[url].ready then
            if onDone then onDone(_cache[url].rawBytes) end
            return
        end
        --// Já baixando — encadeia callback
        table.insert(_cache[url].callbacks, onDone or function() end)
        return
    end

    _cache[url] = { ready = false, rawBytes = nil, callbacks = { onDone or function() end } }

    local path = thumbFilename(url)
    if file.Exists(path, "DATA") then
        local raw = file.Read(path, "DATA")
        if raw and raw ~= "" then
            _cache[url].ready    = true
            _cache[url].rawBytes = raw
            DuckAchLogger.debug("Thumbnail do disco: " .. url)
            for _, cb in ipairs(_cache[url].callbacks) do cb(raw) end
            _cache[url].callbacks = {}
            return
        end
    end

    DuckAchLogger.debug("Baixando thumbnail: " .. url)
    HTTP({
        url     = url,
        method  = "GET",
        success = function(code, body, headers)
            if code ~= 200 or not body or body == "" then
                DuckAchLogger.warn("Thumbnail HTTP " .. code .. ": " .. url)
                _cache[url] = nil
                return
            end
            ensureDir()
            file.Write(path, body)
            _cache[url].ready    = true
            _cache[url].rawBytes = body
            DuckAchLogger.info("Thumbnail baixada e salva: " .. url)
            for _, cb in ipairs(_cache[url].callbacks) do cb(body) end
            _cache[url].callbacks = {}
        end,
        failed = function(reason)
            DuckAchLogger.warn("Thumbnail falhou (" .. reason .. "): " .. url)
            _cache[url] = nil
        end,
    })
end

function DuckAch.Thumbnails.Preload(url)
    if not url or url == "" then return end
    downloadAndCache(url, nil)
end

function DuckAch.Thumbnails.SendToPlayer(ply, url)
    if not url or url == "" then return end
    if not IsValid(ply) then return end
    if ply:GetNWBool("DuckAch_OptOut", false) then return end

    downloadAndCache(url, function(rawBytes)
        sendThumbToPlayer(ply, url, rawBytes)
    end)
end

function DuckAch.Thumbnails.SendAllToPlayer(ply)
    if not IsValid(ply) then return end
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        for _, ach in pairs(DuckAch.Registry.GetAll()) do
            if ach.thumbnail and ach.thumbnail ~= "" then
                DuckAch.Thumbnails.SendToPlayer(ply, ach.thumbnail)
            end
        end
    end)
end

--// Cliente pede thumbnail específica (ex: ao abrir modal)
net.Receive("DuckAch.RequestThumbnail", function(_, ply)
    local url = net.ReadString()
    if not url or url == "" then return end
    DuckAch.Thumbnails.SendToPlayer(ply, url)
end)

--// Pré-carrega todas as thumbnails conhecidas ao iniciar
hook.Add("Initialize", "AchievementSystem.Thumbnails.PreloadAll", function()
    timer.Simple(2, function()
        for _, ach in pairs(DuckAch.Registry.GetAll()) do
            if ach.thumbnail and ach.thumbnail ~= "" then
                DuckAch.Thumbnails.Preload(ach.thumbnail)
            end
        end
    end)
end)

--// Quando conquista é criada/editada via admin, baixa a thumbnail nova
hook.Add("AchievementSystem.Admin.HooksRebuild", "AchievementSystem.Thumbnails.OnRebuild", function()
    for _, ach in pairs(DuckAch.Registry.GetAll()) do
        if ach.thumbnail and ach.thumbnail ~= "" then
            local path = thumbFilename(ach.thumbnail)
            if not file.Exists(path, "DATA") then
                DuckAch.Thumbnails.Preload(ach.thumbnail)
            end
        end
    end
end)

--// Envia thumbnails ao jogador conectar (com delay pra não sobrecarregar o join)
hook.Add("PlayerInitialSpawn", "AchievementSystem.Thumbnails.OnJoin", function(ply)
    timer.Simple(4, function()
        DuckAch.Thumbnails.SendAllToPlayer(ply)
    end)
end)

--// Aplica opt-out no NW para o servidor checar sem precisar do perfil
hook.Add("PlayerInitialSpawn", "AchievementSystem.Thumbnails.SetOptOut", function(ply)
    timer.Simple(2.5, function()
        if not IsValid(ply) then return end
        local profile = DuckAch.Data.GetProfile(ply)
        ply:SetNWBool("DuckAch_OptOut", profile.optOutCache or false)
    end)
end)
