local C    = DuckAch.C
local cfg  = DuckAch.Config
local ease = DuckAch.ease
local fill = DuckAch.fillC
local out  = DuckAch.outlineC

local NOTIF_W  = cfg.NotifWidth
local NOTIF_H  = cfg.NotifHeight
local MARGIN   = 14
local SLIDE    = cfg.NotifSlideTime
local FADE     = cfg.NotifFadeTime
local DURATION = cfg.NotifDuration

local notifQueue = {}
local confettis  = {}

local SOUNDS = {
    common    = "buttons/button14.wav",
    uncommon  = "buttons/button15.wav",
    rare      = "ambient/water/drip3.wav",
    epic      = "ambient/levels/labs/electric_explosion1.wav",
    legendary = "ambient/levels/labs/electric_explosion4.wav",
    secret    = "ambient/levels/labs/electric_explosion4.wav",
}

local function playUnlockSound(rarity)
    local snd = SOUNDS[rarity] or SOUNDS.common
    surface.PlaySound(snd)
end

local function spawnConfetti(cx, cy)
    if not cfg.ConfettiEnabled then return end
    local cols = { C.accent, C.amber, C.cream, C.success, C.red,
                   Color(180, 120, 255), Color(120, 200, 255) }
    for _ = 1, cfg.ConfettiCount do
        table.insert(confettis, {
            x       = cx + math.random(-30, 30),
            y       = cy,
            vx      = math.Rand(-100, 100),
            vy      = math.Rand(-220, -80),
            w       = math.random(4, 10),
            h       = math.random(3, 6),
            col     = cols[math.random(#cols)],
            life    = 0,
            maxLife = math.Rand(1.8, cfg.ConfettiLifetime),
        })
    end
end

local function pushNotif(view)
    if #notifQueue >= cfg.MaxStoredNotifs then
        table.remove(notifQueue, 1)
    end
    table.insert(notifQueue, {
        view      = view,
        born      = RealTime(),
        mat       = nil,
    })

    playUnlockSound(view.rarity)

    if view.thumbnail and view.thumbnail ~= "" then
        DuckAch.Client.GetThumbnail(view.thumbnail, function(mat)
            local n = notifQueue[#notifQueue]
            if n and n.view.id == view.id then n.mat = mat end
        end)
    end
end

hook.Add("AchievementSystem.Client.OnUnlock", "AchievementSystem.HUD.ShowNotif", function(view)
    pushNotif(view)
end)

hook.Add("HUDPaint", "AchievementSystem.HUD.Paint", function()
    local sw, sh = ScrW(), ScrH()
    local now    = RealTime()
    local dt     = FrameTime()

    for i = #confettis, 1, -1 do
        local c = confettis[i]
        c.life  = c.life + dt
        if c.life >= c.maxLife then
            table.remove(confettis, i)
        else
            c.vy = c.vy + 320 * dt
            c.x  = c.x  + c.vx * dt
            c.y  = c.y  + c.vy * dt
            local a = math.Clamp(1 - c.life / c.maxLife, 0, 1) * 230
            surface.SetDrawColor(c.col.r, c.col.g, c.col.b, a)
            surface.DrawRect(math.floor(c.x), math.floor(c.y), c.w, c.h)
        end
    end

    for idx = #notifQueue, 1, -1 do
        local notif   = notifQueue[idx]
        local elapsed = now - notif.born
        local total   = SLIDE + DURATION + FADE

        if elapsed > total then
            table.remove(notifQueue, idx)
        end
    end

    for idx, notif in ipairs(notifQueue) do
        local elapsed   = now - notif.born
        local slideF    = ease(math.Clamp(elapsed / SLIDE, 0, 1))
        local fadeStart = SLIDE + DURATION
        local fadeF     = 1 - ease(math.Clamp((elapsed - fadeStart) / FADE, 0, 1))
        local alpha     = math.floor(fadeF * 255)
        local ox        = math.floor((1 - slideF) * (NOTIF_W + MARGIN + 10))

        local nx = sw - NOTIF_W - MARGIN + ox
        local ny = MARGIN + (idx - 1) * (NOTIF_H + 6)

        if not notif.confettiSpawned and slideF >= 1 then
            notif.confettiSpawned = true
            spawnConfetti(nx + NOTIF_W * 0.5, ny + NOTIF_H * 0.5)
        end

        local rar    = DuckAch.GetRarity(notif.view.rarity)
        local rarCol = rar.color
        local radius = 8

        DuckAch.dropShadow(nx, ny, NOTIF_W, NOTIF_H, radius, math.floor(alpha * 0.55), 4)
        DuckAch.panelBG(nx, ny, NOTIF_W, NOTIF_H, radius, C.panel, alpha, rarCol, math.floor(alpha * 0.5), 1)

        surface.SetDrawColor(rarCol.r, rarCol.g, rarCol.b, math.floor(alpha * 0.12))
        surface.DrawRect(nx + 1, ny + 1, NOTIF_W - 2, NOTIF_H - 2)

        DuckAch.roundedFillEx(nx, ny, 4, NOTIF_H, radius, rarCol, alpha, true, false, true, false)

        local thumbSz = NOTIF_H - 16
        local thumbX  = nx + 12
        local thumbY  = ny + 8

        local mat = notif.mat
        if not mat and notif.view.thumbnail and notif.view.thumbnail ~= "" then
            mat = DuckAch.Client.GetCachedMat(notif.view.thumbnail)
        end

        if mat and not mat:IsError() then
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRect(thumbX, thumbY, thumbSz, thumbSz)
        else
            DuckAch.roundedFill(thumbX, thumbY, thumbSz, thumbSz, 5, C.border, alpha)
            DuckAch.drawText("?", "DA_Modal",
                thumbX + math.floor(thumbSz * 0.5),
                thumbY + math.floor(thumbSz * 0.5),
                Color(rarCol.r, rarCol.g, rarCol.b, math.floor(alpha * 0.7)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local textX = thumbX + thumbSz + 9

        DuckAch.drawText(DuckAch.L("hud.unlocked_title"), "DA_Badge",
            textX, ny + 8,
            Color(rarCol.r, rarCol.g, rarCol.b, math.floor(alpha * 0.9)))

        draw.SimpleTextOutlined(notif.view.name, "DA_Name",
            textX, ny + 20,
            Color(C.cream.r, C.cream.g, C.cream.b, alpha),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP,
            1, Color(0, 0, 0, math.floor(alpha * 0.5)))

        local desc = notif.view.description or ""
        if #desc > 46 then desc = desc:sub(1, 43) .. "..." end
        DuckAch.drawText(desc, "DA_Tiny",
            textX, ny + 38,
            Color(C.muted2.r, C.muted2.g, C.muted2.b, math.floor(alpha * 0.85)))

        if notif.view.pct then
            DuckAch.drawText(DuckAch.L("hud.percent_have_short", notif.view.pct), "DA_Mono",
                nx + NOTIF_W - 8, ny + NOTIF_H - 10,
                Color(C.muted.r, C.muted.g, C.muted.b, math.floor(alpha * 0.65)),
                TEXT_ALIGN_RIGHT)
        end
    end
end)

local PROGRESS_TYPES = {
    ["kill_x_with_weapon"]                   = true,
    ["kill_x_loners"]                        = true,
    ["spawn_x_entity_y_times"]               = true,
    ["reach_playtime_hours"]                 = true,
    ["total_kills_x"]                        = true,
    ["total_killbind_x"]                     = true,
    ["multi_requirement"]                    = true,
}

local BAR_W  = 200
local BAR_H  = 18
local BAR_X  = 14
local BAR_GAP = 4

local barStates = {}
local DISPLAY_TIME = 3.0
local SLIDE_TIME = 0.4

hook.Add("HUDPaint", "AchievementSystem.HUD.ProgressBars", function()
    local progress = DuckAch.Client.progress
    if not progress or table.Count(progress) == 0 then return end

    local achs = DuckAch.Client.achievements
    local sw, sh = ScrW(), ScrH()

    local bars = {}
    for achId, prog in pairs(progress) do
        local view = achs and achs[achId]
        if not view then continue end
        if not PROGRESS_TYPES[view.triggerType or ""] then continue end
        if prog.current <= 0 then continue end

        local state = barStates[achId]
        if not state then
            state = { val = prog.current, time = SysTime() }
            barStates[achId] = state
        elseif state.val ~= prog.current then
            state.val = prog.current
            state.time = SysTime()
        end

        local age = SysTime() - state.time
        if age > (DISPLAY_TIME + SLIDE_TIME) then continue end

        table.insert(bars, { id = achId, view = view, prog = prog, age = age })
    end

    if #bars == 0 then return end

    local totalH = #bars * (BAR_H + BAR_GAP)
    local startY = sh - totalH - 60

    for i, bar in ipairs(bars) do
        local rar    = DuckAch.GetRarity(bar.view.rarity or "common")
        local rarCol = rar.color
        local prog   = bar.prog
        local pct    = math.Clamp(prog.current / prog.needed, 0, 1)
        local y      = startY + (i - 1) * (BAR_H + BAR_GAP)

        local alphaMult = 1
        local curX = BAR_X

        if bar.age > DISPLAY_TIME then
            local animPct = math.Clamp((bar.age - DISPLAY_TIME) / SLIDE_TIME, 0, 1)
            animPct = animPct ^ 2
            alphaMult = 1 - animPct
            curX = BAR_X - (animPct * (BAR_W + BAR_X + 20))
        end

        DuckAch.dropShadow(curX, y, BAR_W, BAR_H, 5, 60 * alphaMult, 2)
        DuckAch.panelBG(curX, y, BAR_W, BAR_H, 5, Color(30, 38, 55), 220 * alphaMult, rarCol, 90 * alphaMult, 1)

        local fillW = math.floor(BAR_W * pct)
        if fillW > 6 then
            DuckAch.roundedFillEx(curX, y, fillW, BAR_H, 5, rarCol, 170 * alphaMult, true, false, true, false)
        end

        local unit     = prog.unit or ""
        local valStr   = unit ~= "" and (prog.current .. unit .. " / " .. prog.needed .. unit)
                         or (prog.current .. " / " .. prog.needed)
        local nameShort = bar.view.name or bar.id
        if #nameShort > 22 then nameShort = nameShort:sub(1, 19) .. "..." end

        draw.SimpleText(nameShort, "DA_Tiny",
            curX + 8, y + math.floor(BAR_H * 0.5),
            Color(220, 225, 235, 230 * alphaMult),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText(valStr, "DA_Mono",
            curX + BAR_W - 6, y + math.floor(BAR_H * 0.5),
            Color(rarCol.r, rarCol.g, rarCol.b, 200 * alphaMult),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end)
