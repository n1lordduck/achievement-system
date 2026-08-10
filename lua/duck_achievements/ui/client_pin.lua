DuckAch.UI = DuckAch.UI or {}

local C    = DuckAch.C
local fill = DuckAch.fillC
local out  = DuckAch.outlineC

local _pinnedIds = {}
local pinFile    = "duck_achievements_pin.txt"

local function loadPins()
    if not file.Exists(pinFile, "DATA") then return end
    local raw = file.Read(pinFile, "DATA")
    if not raw or raw == "" then return end
    local list = util.JSONToTable(raw)
    if type(list) == "table" then _pinnedIds = list end
end

local function savePins()
    file.Write(pinFile, util.TableToJSON(_pinnedIds))
end

function DuckAch.UI.IsPinned(achId)
    for _, id in ipairs(_pinnedIds) do
        if id == achId then return true end
    end
    return false
end

function DuckAch.UI.TogglePin(achId, view)
    if view and view.secret and view.locked then return end
    for i, id in ipairs(_pinnedIds) do
        if id == achId then
            table.remove(_pinnedIds, i)
            savePins()
            return
        end
    end
    table.insert(_pinnedIds, achId)
    savePins()
end

function DuckAch.UI.ClearPin(achId)
    for i, id in ipairs(_pinnedIds) do
        if id == achId then table.remove(_pinnedIds, i); savePins(); return end
    end
end

function DuckAch.UI.ClearAllPins()
    _pinnedIds = {}
    savePins()
end

loadPins()

--// ── HUD: coluna de pins no canto superior esquerdo ─────────────────────────

local PIN_X   = 14
local PIN_Y   = 14
local PIN_W   = 250
local PIN_GAP = 8

local function drawPinCard(x, y, achId, view, prog)
    local rar    = DuckAch.GetRarity(view.rarity or "common")
    local rarCol = rar.color
    local isMulti = view.triggerType == "multi_requirement"
    local details = (prog and prog.details) or {}

    --// Linhas de conteúdo: nome + descrição (até 2 linhas) + progresso
    local descLines = {}
    if view.description and view.description ~= "" then
        local desc = view.description
        local maxW = PIN_W - 16
        surface.SetFont("DA_Tiny")
        local words = {}
        for w in desc:gmatch("%S+") do table.insert(words, w) end
        local line = ""
        for _, word in ipairs(words) do
            local test = line == "" and word or (line .. " " .. word)
            if surface.GetTextSize(test) > maxW and line ~= "" then
                table.insert(descLines, line)
                if #descLines >= 2 then break end
                line = word
            else
                line = test
            end
        end
        if line ~= "" and #descLines < 2 then
            table.insert(descLines, line)
        end
    end

    local headerH   = 28
    local descH     = #descLines * 14
    local rowH      = 20
    local progRows  = isMulti and #details or (prog and 1 or 0)
    local totalH    = headerH + descH + (progRows > 0 and (progRows * rowH + 6) or 0) + 6

    surface.SetDrawColor(10, 12, 18, 220)
    surface.DrawRect(x, y, PIN_W, totalH)
    surface.SetDrawColor(rarCol.r, rarCol.g, rarCol.b, 200)
    surface.DrawOutlinedRect(x, y, PIN_W, totalH, 1)
    surface.SetDrawColor(rarCol.r, rarCol.g, rarCol.b, 230)
    surface.DrawRect(x, y, 3, totalH)

    --// Nome
    local nameShort = view.name or achId
    if #nameShort > 26 then nameShort = nameShort:sub(1, 24) .. ".." end
    draw.SimpleText(nameShort, "DA_Sub", x + 10, y + 6,
        Color(235, 235, 240, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    --// Raridade pequena
    draw.SimpleText(rar.label, "DA_Tiny", x + 10, y + 20,
        Color(rarCol.r, rarCol.g, rarCol.b, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local ry = y + headerH

    --// Descrição (até 2 linhas)
    for _, dl in ipairs(descLines) do
        draw.SimpleText(dl, "DA_Tiny", x + 10, ry,
            Color(160, 165, 175, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        ry = ry + 14
    end

    if progRows > 0 then
        ry = ry + 4

        if isMulti and #details > 0 then
            for _, det in ipairs(details) do
                local rowCol = det.met and Color(120, 220, 140) or Color(170, 175, 190)
                local lbl    = det.label
                if #lbl > 16 then lbl = lbl:sub(1, 14) .. "." end
                draw.SimpleText(lbl, "DA_Tiny", x + 10, ry + 1,
                    det.met and Color(225, 230, 235) or Color(155, 160, 170),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                local barW   = PIN_W - 20
                local barY   = ry + 12
                local filled = math.Clamp(det.current / math.max(det.needed, 1), 0, 1)
                fill(x + 10, barY, barW, 4, C.border)
                fill(x + 10, barY, math.floor(barW * filled), 4, rowCol, 220)

                ry = ry + rowH
            end
        elseif prog then
            local filled = math.Clamp(prog.current / math.max(prog.needed, 1), 0, 1)
            local barW   = PIN_W - 20
            draw.SimpleText(prog.current .. " / " .. prog.needed, "DA_Tiny",
                x + PIN_W - 10, ry + 1, Color(rarCol.r, rarCol.g, rarCol.b, 220),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            local barY = ry + 12
            fill(x + 10, barY, barW, 4, C.border)
            fill(x + 10, barY, math.floor(barW * filled), 4, rarCol, 220)
        end
    end

    return totalH
end

hook.Add("HUDPaint", "AchievementSystem.HUD.PinnedAchievements", function()
    if #_pinnedIds == 0 then return end

    local achs     = DuckAch.Client.achievements
    local unlocked = DuckAch.Client.profile.unlocked or {}
    local y        = PIN_Y
    local toRemove = {}

    for _, achId in ipairs(_pinnedIds) do
        local view = achs and achs[achId]
        if not view then continue end

        if unlocked[achId] then
            table.insert(toRemove, achId)
            continue
        end

        if view.secret and view.locked then
            table.insert(toRemove, achId)
            continue
        end

        local prog = DuckAch.Client.progress and DuckAch.Client.progress[achId]
        local h    = drawPinCard(PIN_X, y, achId, view, prog)
        y = y + h + PIN_GAP
    end

    for _, id in ipairs(toRemove) do DuckAch.UI.ClearPin(id) end
end)
