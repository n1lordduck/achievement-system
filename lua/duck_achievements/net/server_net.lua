DuckAch.Net = {}

local u = util
local addNetwork = u.AddNetworkString

addNetwork("DuckAch.SendUnlock")
addNetwork("DuckAch.SendFullData")
addNetwork("DuckAch.RequestFullData")
addNetwork("DuckAch.RequestStats")
addNetwork("DuckAch.SendStats")
addNetwork("DuckAch.SetOptOut")
addNetwork("DuckAch.ClearCache")
addNetwork("DuckAch.ChatBroadcast")
addNetwork("DuckAch.Admin.Save")
addNetwork("DuckAch.Admin.Delete")
addNetwork("DuckAch.Admin.SetEntId")
addNetwork("DuckAch.Admin.RequestList")
addNetwork("DuckAch.Admin.SendList")
addNetwork("DuckAch.Admin.PickerResult")
addNetwork("DuckAch.Admin.EquipPicker")
addNetwork("DuckAch.OpenMenu")
addNetwork("DuckAch.OpenAdmin")
addNetwork("DuckAch_Banner")
addNetwork("DuckAch.ResetProgress")
addNetwork("DuckAch.SendProgress")
addNetwork("DuckAch.Admin.Webhook.RequestList")
addNetwork("DuckAch.Admin.Webhook.List")
addNetwork("DuckAch.Admin.Webhook.Add")
addNetwork("DuckAch.Admin.Webhook.Remove")
addNetwork("DuckAch.Admin.Webhook.SetEnabled")
addNetwork("DuckAch.Admin.Webhook.ActionResult")

hook.Add("PlayerInitialSpawn", "DuckAch.BannerSpawn", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            net.Start("DuckAch_Banner")
            net.Send(ply)
        end
    end)
end)

local function isSuperAdmin(ply)
    for _, g in ipairs(DuckAch.Config.SuperadminGroups) do
        if ply:IsUserGroup(g) or ply:IsSuperAdmin() then return true end
    end
    return false
end

function DuckAch.Net.SendUnlock(ply, view)
    net.Start("DuckAch.SendUnlock")
        net.WriteString(util.TableToJSON(view))
    net.Send(ply)
end

--// ── BuildProgress ──────────────────────────────────────────────────────
--// Calcula dict de progresso completo. Reutilizado pelo SendFullData e
--// pelo SendProgress leve chamado a cada kill/spawn em tempo real.
--// Conquistas secretas não desbloqueadas nunca aparecem aqui.

local SUB_LABEL_KEYS = {
    reach_playtime_hours   = "sublabel.reach_playtime_hours",
    total_kills_x          = "sublabel.total_kills_x",
    total_killbind_x       = "sublabel.total_killbind_x",
    spawn_x_entity_y_times = "sublabel.spawn_x_entity_y_times",
    kill_x_with_weapon     = "sublabel.kill_x_with_weapon",
}

function DuckAch.Net.BuildProgress(profile, ply)
    local lang = DuckAch.Lang.EffectiveFor(ply)
    local progress = {}

    for id, ach in pairs(DuckAch.Registry.GetAll()) do
        if profile:hasAchievement(id) or ach.secret then continue end

        local t = ach.triggerType

        if t == "spawn_x_entity_y_times" then
            local cur = profile:getCounter(id)
            progress[id] = { current = cur, needed = ach:getParam("times") or 1 }

        elseif t == "kill_x_with_weapon" or t == "kill_x_loners" then
            local cur = profile:getCounter(id)
            progress[id] = { current = cur, needed = ach:getParam("kills") or 1 }

        elseif t == "total_kills_x" then
            progress[id] = { current = profile.kills, needed = ach:getParam("kills") or 1 }

        elseif t == "total_killbind_x" then
            progress[id] = { current = profile.killbindCount, needed = ach:getParam("count") or 1 }

        elseif t == "reach_playtime_hours" then
            progress[id] = {
                current = math.floor(profile.playtime / 3600 * 10) / 10,
                needed  = ach:getParam("hours") or 1,
                unit    = "h",
            }

        elseif t == "multi_requirement" then
            local subReqs = ach:getParam("requirements") or {}
            if #subReqs == 0 then continue end

            local completed = 0
            local details   = {}

            for _, sub in ipairs(subReqs) do
                local st  = sub.type
                local sp  = sub.params or {}
                local cur, needed, unit = 0, 1, ""

                if st == "reach_playtime_hours" then
                    cur    = math.floor(profile.playtime / 3600 * 10) / 10
                    needed = sp.hours or 1
                    unit   = "h"
                elseif st == "total_kills_x" then
                    cur    = profile.kills
                    needed = sp.kills or 1
                elseif st == "total_killbind_x" then
                    cur    = profile.killbindCount
                    needed = sp.count or 1
                elseif st == "spawn_x_entity_y_times" then
                    local cn  = sp.classname or ""
                    local key = (cn == "" or cn == "any") and "_multireq_spawn_any" or ("_multireq_spawn_" .. cn)
                    cur    = profile:getCounter(key)
                    needed = sp.times or 1
                elseif st == "kill_x_with_weapon" then
                    cur    = profile:getCounter("_multireq_weapon_" .. (sp.weapon or ""))
                    needed = sp.kills or 1
                end

                local met = cur >= needed
                if met then completed = completed + 1 end
                table.insert(details, {
                    label   = SUB_LABEL_KEYS[st] and DuckAch.Lang.GetIn(lang, SUB_LABEL_KEYS[st]) or st,
                    current = cur,
                    needed  = needed,
                    unit    = unit,
                    met     = met,
                })
            end

            --// Manda sempre — mesmo com 0 completos o cliente precisa dos
            --// detalhes pra mostrar barras individuais desde o início
            progress[id] = {
                current = completed,
                needed  = #subReqs,
                unit    = "req",
                details = details,
            }
        end
    end

    return progress
end

--// ── SendProgress (leve) ──────────────────────────────────────────────────
--// Envia APENAS o progresso — sem views nem stats. Chamado a cada kill/
--// spawn para manter as barras em tempo real sem sobrecarregar a rede.

function DuckAch.Net.SendProgress(ply)
    local profile    = DuckAch.Data.GetProfile(ply)
    local progress   = DuckAch.Net.BuildProgress(profile, ply)
    local compressed = util.Compress(util.TableToJSON(progress))
    net.Start("DuckAch.SendProgress")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end

function DuckAch.Net.SendFullData(ply)
    local profile  = DuckAch.Data.GetProfile(ply)
    local achViews = DuckAch.Registry.SerializeForPlayer(profile)
    local stats    = {}
    for id in pairs(achViews) do
        local s = DuckAch.API.GetStats(id)
        stats[id] = s.pct
    end

    local progress = DuckAch.Net.BuildProgress(profile, ply)

    local payload = {
        achievements = achViews,
        stats        = stats,
        progress     = progress,
        profile = {
            kills         = profile.kills,
            deaths        = profile.deaths,
            unlocked      = profile.unlocked,
            optOutCache   = profile.optOutCache,
            playtime      = profile.playtime,
            killbindCount = profile.killbindCount,
        },
    }

    local compressed = util.Compress(util.TableToJSON(payload))
    net.Start("DuckAch.SendFullData")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end
net.Receive("DuckAch.RequestFullData", function(_, ply)
    DuckAch.Net.SendFullData(ply)
end)

net.Receive("DuckAch.RequestStats", function(_, ply)
    local achId = net.ReadString()
    local s     = DuckAch.API.GetStats(achId)
    net.Start("DuckAch.SendStats")
        net.WriteString(achId)
        net.WriteFloat(s.pct)
        net.WriteUInt(s.owners, 16)
    net.Send(ply)
end)

net.Receive("DuckAch.SetOptOut", function(_, ply)
    local state = net.ReadBool()
    DuckAch.Data.SetOptOut(ply, state)
end)

net.Receive("DuckAch.ClearCache", function(_, ply)
    DuckAch.Data.ClearPlayerCache(ply)
    DuckAch.Net.SendFullData(ply)
end)

net.Receive("DuckAch.Admin.Save", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local def = util.JSONToTable(net.ReadString())
    if not def then return end

    DuckAch.Registry.Remove(def.id)
    local ok = DuckAch.Registry.Register(def)
    DuckAchLogger.debug("Admin.Save: " .. tostring(def.id) .. " ok=" .. tostring(ok))

    if ok then
        DuckAch.Admin.PersistCustomAchievements()
        hook.Run("AchievementSystem.Admin.HooksRebuild")
    end

    net.Start("DuckAch.Admin.SendList")
        net.WriteString(util.TableToJSON(DuckAch.Admin.GetSerializedList()))
    net.Send(ply)

    --// Atualiza grid de TODOS os jogadores conectados
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAchLogger.debug("Admin.Save: enviando SendFullData para " .. p:Name())
            DuckAch.Net.SendFullData(p)
        end
    end
end)

net.Receive("DuckAch.Admin.Delete", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local achId = net.ReadString()
    DuckAchLogger.debug("Admin.Delete: removendo " .. tostring(achId))
    DuckAch.Registry.Remove(achId)
    DuckAch.Admin.PersistCustomAchievements()
    hook.Run("AchievementSystem.Admin.HooksRebuild")

    net.Start("DuckAch.Admin.SendList")
        net.WriteString(util.TableToJSON(DuckAch.Admin.GetSerializedList()))
    net.Send(ply)

    --// Atualiza grid de TODOS os jogadores conectados
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            DuckAchLogger.debug("Admin.Delete: enviando SendFullData para " .. p:Name())
            DuckAch.Net.SendFullData(p)
        end
    end
end)

net.Receive("DuckAch.Admin.RequestList", function(_, ply)
    if not isSuperAdmin(ply) then return end
    net.Start("DuckAch.Admin.SendList")
        net.WriteString(util.TableToJSON(DuckAch.Admin.GetSerializedList()))
    net.Send(ply)
end)

--// Picker: equipa a stool no jogador e registra o achId pendente
net.Receive("DuckAch.Admin.SetEntId", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local achId = net.ReadString()
    DuckAch.Admin.StartEntityPicker(ply, achId)
end)

local function sendWebhookList(ply)
    local list = DuckAch.API.GetWebhookList()
    net.Start("DuckAch.Admin.Webhook.List")
        net.WriteBool(DuckAch.API.IsReqwestAvailable())
        net.WriteUInt(#list, 16)
        for _, wh in ipairs(list) do
            net.WriteString(wh.id)
            net.WriteBool(wh.enabled)
            net.WriteString(wh.createdByNick or "")
            net.WriteString(wh.createdBySteamID or "")
            net.WriteUInt(wh.createdAt or 0, 32)
        end
    net.Send(ply)
end

local function sendWebhookResult(ply, ok, err)
    net.Start("DuckAch.Admin.Webhook.ActionResult")
        net.WriteBool(ok)
        net.WriteString(err or "")
    net.Send(ply)
    sendWebhookList(ply)
end

net.Receive("DuckAch.Admin.Webhook.RequestList", function(_, ply)
    if not isSuperAdmin(ply) then return end
    sendWebhookList(ply)
end)

net.Receive("DuckAch.Admin.Webhook.Add", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local url = net.ReadString()
    local ok, err = DuckAch.API.AddWebhook(ply, url)
    sendWebhookResult(ply, ok, err)
end)

net.Receive("DuckAch.Admin.Webhook.Remove", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local id = net.ReadString()
    local ok, err = DuckAch.API.RemoveWebhook(id)
    sendWebhookResult(ply, ok, err)
end)

net.Receive("DuckAch.Admin.Webhook.SetEnabled", function(_, ply)
    if not isSuperAdmin(ply) then return end
    local id    = net.ReadString()
    local state = net.ReadBool()
    local ok, err = DuckAch.API.SetWebhookEnabled(id, state)
    sendWebhookResult(ply, ok, err)
end)

hook.Add("PlayerInitialSpawn", "AchievementSystem.Net.OnSpawn", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then DuckAch.Net.SendFullData(ply) end
    end)
end)

--// Reseta todos os counters e campos de progresso do perfil, preservando
--// as conquistas já desbloqueadas. Tem cooldown de 60s para evitar spam.
local _resetCooldown = {}
net.Receive("DuckAch.ResetProgress", function(_, ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    local now = CurTime()
    if _resetCooldown[sid] and now - _resetCooldown[sid] < 60 then
        DuckAchLogger.warn("ResetProgress: cooldown ativo para " .. ply:Name())
        return
    end
    _resetCooldown[sid] = now

    local profile = DuckAch.Data.GetProfile(ply)

    --// Limpa counters (progresso de conquistas incrementais)
    profile.counters       = {}
    --// Zera campos de progresso geral (kills, mortes, playtime, killbinds)
    --// mas preserva unlocked (conquistas já ganhas)
    profile.kills          = 0
    profile.deaths         = 0
    profile.playtime       = 0
    profile.killbindCount  = 0
    profile.killstreak     = 0
    profile.lastDeathTime  = 0
    profile.pacifistSince  = 0

    DuckAch.Data.Save()
    DuckAch.Net.SendFullData(ply)

    DuckAchLogger.info("Progress reset for: " .. ply:Name())
    ply:ChatPrint("[DuckAch] Progress reset. Your unlocked achievements were kept.")
end)
