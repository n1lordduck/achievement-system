DuckAch.API = {}

local cfg = DuckAch.Config

local function broadcastUnlockColored(ply, achDef)
    local rar = DuckAch.GetRarity(achDef.rarity)
    net.Start("DuckAch.ChatBroadcast")
        net.WriteString(ply:Name())
        net.WriteString(achDef.secret and "???" or achDef.name)
        net.WriteString(achDef.rarity)
        net.WriteBool(achDef.secret or false)
        net.WriteString(ply:SteamID())
    net.Broadcast()
end

local function buildNotifPayload(achDef, pct)
    local view = achDef:getPublicView(true)
    view.pct   = pct
    return view
end

local WEBHOOK_URL_FILE   = cfg.DataDir .. "webhook.txt"
local WEBHOOK_STATE_FILE = cfg.DataDir .. "webhook_state.txt"

local function ensureDataDir()
    if not file.IsDir(cfg.DataDir, "DATA") then file.CreateDir(cfg.DataDir) end
end

local function loadWebhookURL()
    if not file.Exists(WEBHOOK_URL_FILE, "DATA") then return nil end
    local url = file.Read(WEBHOOK_URL_FILE, "DATA")
    if not url then return nil end
    url = url:Trim()
    return url ~= "" and url or nil
end

local function loadWebhookEnabled()
    if not file.Exists(WEBHOOK_STATE_FILE, "DATA") then return cfg.WebhookEnabledDefault end
    return file.Read(WEBHOOK_STATE_FILE, "DATA") == "1"
end

local function isValidWebhookURL(url)
    return type(url) == "string"
        and (url:match("^https://discord%.com/api/webhooks/") ~= nil
            or url:match("^https://discordapp%.com/api/webhooks/") ~= nil)
end

local WebhookURL     = loadWebhookURL()
local WebhookEnabled = loadWebhookEnabled()

function DuckAch.API.SetWebhookURL(url)
    if not isValidWebhookURL(url) then return false, "invalid_url" end
    ensureDataDir()
    file.Write(WEBHOOK_URL_FILE, url)
    WebhookURL = url
    return true
end

function DuckAch.API.ClearWebhookURL()
    if file.Exists(WEBHOOK_URL_FILE, "DATA") then file.Delete(WEBHOOK_URL_FILE) end
    WebhookURL = nil
    return true
end

function DuckAch.API.SetWebhookEnabled(state)
    ensureDataDir()
    state = state and true or false
    file.Write(WEBHOOK_STATE_FILE, state and "1" or "0")
    WebhookEnabled = state
    return true
end

function DuckAch.API.GetWebhookStatus()
    return { enabled = WebhookEnabled, configured = WebhookURL ~= nil }
end

function DuckAch.API.WebhookSend(ply, achId)
    if not WebhookEnabled or not WebhookURL then return false end

    if not reqwest then
        DuckAchLogger.warn("Webhook integration depends on reqwest")
        return false
    end

    local achDef = DuckAch.Registry.Get(achId)
    if not achDef then return false end

    local totalPlayers = DuckAch.Data.GetTotalPlayers()
    local ownerCount   = DuckAch.Data.GetAchievementOwnerCount(achId)

    local pct = totalPlayers > 0
        and math.Round((ownerCount / totalPlayers) * 100, 1)
        or 0

    local rarity = DuckAch.GetRarity(achDef.rarity)

    local achName = achDef.secret and "???" or achDef.name
    local achDesc = achDef.secret and "Conquista Secreta" or (achDef.description or "")

    local color = 0xA0A0A0

    if rarity and rarity.color then
        color = bit.lshift(rarity.color.r, 16)
              + bit.lshift(rarity.color.g, 8)
              + rarity.color.b
    end

    local embed = {
        title = "🏆 Conquista Desbloqueada: " .. achName,
        description =
            "**Jogador:** " .. ply:Nick() .. "\n" ..
            "** *" .. achDesc .. "***\n" ..
            "**Raridade:** " .. rarity.label .. "\n" ..
            "**Obtida por:** " .. pct .. "% dos jogadores",
        color = color,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    reqwest({
        url = WebhookURL,
        method = "POST",
        type = "application/json",
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "DuckAchievements"
        },
        body = util.TableToJSON({
            embeds = { embed }
        }),
        failed = function(err)
            DuckAchLogger.error("Webhook falhou: " .. tostring(err))
        end
    })

    DuckAchLogger.info("Sent webook")
    return true
end

function DuckAch.API.Grant(ply, achId)
    if not IsValid(ply) then return false end

    local achDef = DuckAch.Registry.Get(achId)
    if not achDef then
        DuckAchLogger.warn("Grant: conquista inexistente: " .. tostring(achId))
        return false
    end

    local profile = DuckAch.Data.GetProfile(ply)
    if not profile:unlock(achId) then return false end

    DuckAchLogger.info(ply:Name() .. " desbloqueou: " .. achId)

    local totalPlayers = DuckAch.Data.GetTotalPlayers()
    local ownerCount   = DuckAch.Data.GetAchievementOwnerCount(achId)
    local pct = totalPlayers > 0 and math.Round((ownerCount / totalPlayers) * 100, 1) or 0

    broadcastUnlockColored(ply, achDef)
    DuckAch.API.WebhookSend(ply, achId)

    local payload = buildNotifPayload(achDef, pct)
    DuckAch.Net.SendUnlock(ply, payload)

    DuckAch.Net.SendFullData(ply)

    DuckAch.Data.InvalidateOwnerCount(achId)

    if achDef.thumbnail and achDef.thumbnail ~= "" then
        DuckAch.Thumbnails.SendToPlayer(ply, achDef.thumbnail)
    end

    hook.Call("AchievementSystem.API.OnGrant", nil, ply, achDef, profile)
    DuckAch.Data.Save()
    return true
end

function DuckAch.API.HasAchievement(ply, achId)
    if not IsValid(ply) then return false end
    return DuckAch.Data.GetProfile(ply):hasAchievement(achId)
end

function DuckAch.API.GetProfile(ply)
    return DuckAch.Data.GetProfile(ply)
end

function DuckAch.API.GetStats(achId)
    local total  = DuckAch.Data.GetTotalPlayers()
    local owners = DuckAch.Data.GetAchievementOwnerCount(achId)
    local pct    = total > 0 and math.Round((owners / total) * 100, 1) or 0
    return { total = total, owners = owners, pct = pct }
end

local _interactDebounce = {}

timer.Create("AchievementSystem.API.DebounceCleanup", 60, 0, function()
    local now     = CurTime()
    local removed = 0
    for k, t in pairs(_interactDebounce) do
        if now - t > 2 then
            _interactDebounce[k] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        DuckAchLogger.debug("DebounceCleanup: removidas " .. removed .. " entradas")
    end
end)

function DuckAch.API.TriggerInteract(ply, entId)
    if not IsValid(ply) then return end

    local debounceKey = ply:SteamID() .. "_" .. entId
    local now         = CurTime()
    if _interactDebounce[debounceKey] and now - _interactDebounce[debounceKey] < 0.5 then
        return
    end
    _interactDebounce[debounceKey] = now

    local profile = DuckAch.Data.GetProfile(ply)

    for _, ach in ipairs(DuckAch.Registry.GetByType("interact_with_x_entity")) do
        if ach:getParam("entId") == entId and not profile:hasAchievement(ach.id) then
            DuckAch.API.Grant(ply, ach.id)
        end
    end
end
