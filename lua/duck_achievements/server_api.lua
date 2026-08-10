DuckAch.API = {}
DuckAch.Webhooks = {}

local cfg = DuckAch.Config

if not reqwest and util.IsBinaryModuleInstalled("reqwest") then
    pcall(require, "reqwest")
end

function DuckAch.Webhooks.IsReqwestAvailable()
    return reqwest ~= nil
end

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

local WEBHOOKS_FILE = cfg.DataDir .. "webhooks.json"

local function ensureDataDir()
    if not file.IsDir(cfg.DataDir, "DATA") then file.CreateDir(cfg.DataDir) end
end

local function isValidWebhookURL(url)
    return type(url) == "string"
        and (url:match("^https://discord%.com/api/webhooks/") ~= nil
            or url:match("^https://discordapp%.com/api/webhooks/") ~= nil)
end

local function loadWebhooks()
    if not file.Exists(WEBHOOKS_FILE, "DATA") then return {} end
    local raw = file.Read(WEBHOOKS_FILE, "DATA")
    if not raw or raw == "" then return {} end
    return util.JSONToTable(raw) or {}
end

local Webhooks = loadWebhooks()

local function saveWebhooks()
    ensureDataDir()
    file.Write(WEBHOOKS_FILE, util.TableToJSON(Webhooks, true))
end

function DuckAch.Webhooks.Add(ply, url)
    if not isValidWebhookURL(url) then return false, "invalid_url" end
    table.insert(Webhooks, {
        id               = "wh_" .. os.time() .. "_" .. math.random(1000, 9999),
        url              = url,
        enabled          = true,
        createdByNick    = IsValid(ply) and ply:Nick() or "console",
        createdBySteamID = IsValid(ply) and ply:SteamID() or "",
        createdAt        = os.time(),
    })
    saveWebhooks()
    return true
end

function DuckAch.Webhooks.Remove(id)
    for i, wh in ipairs(Webhooks) do
        if wh.id == id then
            table.remove(Webhooks, i)
            saveWebhooks()
            return true
        end
    end
    return false, "not_found"
end

function DuckAch.Webhooks.SetEnabled(id, state)
    for _, wh in ipairs(Webhooks) do
        if wh.id == id then
            wh.enabled = state and true or false
            saveWebhooks()
            return true
        end
    end
    return false, "not_found"
end

function DuckAch.Webhooks.GetList()
    local out = {}
    for _, wh in ipairs(Webhooks) do
        table.insert(out, {
            id               = wh.id,
            enabled          = wh.enabled,
            createdByNick    = wh.createdByNick,
            createdBySteamID = wh.createdBySteamID,
            createdAt        = wh.createdAt,
        })
    end
    return out
end

function DuckAch.Webhooks.Send(ply, achId)
    local activeHooks = {}
    for _, wh in ipairs(Webhooks) do
        if wh.enabled then table.insert(activeHooks, wh) end
    end
    if #activeHooks == 0 then return false end

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
    local achDesc = achDef.secret and "Secret Achievement" or (achDef.description or "")

    local color = 0xA0A0A0

    if rarity and rarity.color then
        color = bit.lshift(rarity.color.r, 16)
              + bit.lshift(rarity.color.g, 8)
              + rarity.color.b
    end

    local embed = {
        title = "🏆 Achievement Unlocked: " .. achName,
        description =
            "**Player:** " .. ply:Nick() .. "\n" ..
            "** *" .. achDesc .. "***\n" ..
            "**Rarity:** " .. rarity.label .. "\n" ..
            "**Owned by:** " .. pct .. "% of players",
        color = color,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local body = util.TableToJSON({ embeds = { embed } })

    for _, wh in ipairs(activeHooks) do
        local hookId = wh.id
        reqwest({
            url = wh.url,
            method = "POST",
            type = "application/json",
            headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "DuckAchievements"
            },
            body = body,
            failed = function(err)
                DuckAchLogger.err("Webhook failed (" .. hookId .. "): " .. tostring(err))
            end
        })
    end

    DuckAchLogger.info("Sent webhook to " .. #activeHooks .. " destination(s)")
    return true
end

function DuckAch.API.Grant(ply, achId)
    if not IsValid(ply) then return false end

    local achDef = DuckAch.Registry.Get(achId)
    if not achDef then
        DuckAchLogger.warn("Grant: nonexistent achievement: " .. tostring(achId))
        return false
    end

    local profile = DuckAch.Data.GetProfile(ply)
    if not profile:unlock(achId) then return false end

    DuckAchLogger.info(ply:Name() .. " unlocked: " .. achId)

    local totalPlayers = DuckAch.Data.GetTotalPlayers()
    local ownerCount   = DuckAch.Data.GetAchievementOwnerCount(achId)
    local pct = totalPlayers > 0 and math.Round((ownerCount / totalPlayers) * 100, 1) or 0

    broadcastUnlockColored(ply, achDef)
    DuckAch.Webhooks.Send(ply, achId)

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
