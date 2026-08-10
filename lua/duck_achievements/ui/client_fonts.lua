local fonts = {
    { name = "DA_Title",  font = "Roboto",      size = 21, weight = 900 },
    { name = "DA_Sub",    font = "Roboto",      size = 13, weight = 500 },
    { name = "DA_Tiny",   font = "Roboto",      size = 10, weight = 500 },
    { name = "DA_Btn",    font = "Roboto",      size = 12, weight = 700 },
    { name = "DA_Big",    font = "Courier New", size = 28, weight = 900 },
    { name = "DA_Badge",  font = "Courier New", size = 9,  weight = 700 },
    { name = "DA_Name",   font = "Roboto",      size = 17, weight = 800 },
    { name = "DA_Rarity", font = "Courier New", size = 10, weight = 700 },
    { name = "DA_Modal",  font = "Roboto",      size = 15, weight = 700 },
    { name = "DA_Mono",   font = "Courier New", size = 11, weight = 700 },
}

for _, f in ipairs(fonts) do
    surface.CreateFont(f.name, {
        font      = f.font,
        size      = f.size,
        weight    = f.weight,
        antialias = true,
    })
end

DuckAch.C = {
    bg      = Color(24,  27,  36,  255),
    panel   = Color(32,  37,  49,  255),
    card    = Color(40,  46,  60,  255),
    cardHov = Color(50,  57,  74,  255),
    border  = Color(60,  69,  90,  255),
    accent  = Color(193, 235, 233, 255),
    cream   = Color(255, 250, 217, 255),
    amber   = Color(248, 186, 100, 255),
    red     = Color(226, 133, 133, 255),
    muted   = Color(150, 167, 191, 255),
    muted2  = Color(183, 200, 222, 255),
    neutral = Color(128, 138, 155, 255),
    sep     = Color(193, 235, 233,  16),
    white   = Color(238, 242, 250, 255),
    success = Color(122, 230, 150, 255),
}

DuckAch.C.brand = DuckAch.C.amber

local C = DuckAch.C

DuckAch.Icons = {
    lock  = Material("icon16/lock.png"),
    medal = Material("icon16/medal_gold_1.png"),
}

local _floor     = math.floor
local _sSetColor = surface.SetDrawColor
local _sRect     = surface.DrawRect
local _dText     = draw.SimpleText

function DuckAch.fillC(x, y, w, h, col, a)
    _sSetColor(col.r, col.g, col.b, a or col.a or 255)
    _sRect(x, y, w, h)
end

function DuckAch.outlineC(x, y, w, h, col, a, t)
    t = t or 1
    _sSetColor(col.r, col.g, col.b, a or 255)
    _sRect(x,      y,      w, t)
    _sRect(x,      y+h-t,  w, t)
    _sRect(x,      y,      t, h)
    _sRect(x+w-t,  y,      t, h)
end

function DuckAch.drawText(txt, font, x, y, col, ax, ay)
    _dText(txt, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

function DuckAch.ease(t)
    t = math.Clamp(t, 0, 1)
    return t < 0.5 and 2*t*t or -1 + (4 - 2*t) * t
end

function DuckAch.roundedFill(x, y, w, h, radius, col, a)
    draw.RoundedBox(radius, x, y, w, h, Color(col.r, col.g, col.b, a or col.a or 255))
end

function DuckAch.roundedFillEx(x, y, w, h, radius, col, a, tl, tr, bl, br)
    draw.RoundedBoxEx(radius, x, y, w, h, Color(col.r, col.g, col.b, a or col.a or 255), tl, tr, bl, br)
end

function DuckAch.panelBG(x, y, w, h, radius, bgCol, bgA, borderCol, borderA, borderT)
    if borderCol and (borderA or 255) > 0 then
        borderT = borderT or 1
        draw.RoundedBox(radius, x, y, w, h, Color(borderCol.r, borderCol.g, borderCol.b, borderA or 255))
        local ix, iy = x + borderT, y + borderT
        local iw, ih = w - borderT * 2, h - borderT * 2
        if iw > 0 and ih > 0 then
            draw.RoundedBox(math.max(radius - borderT, 0), ix, iy, iw, ih,
                Color(bgCol.r, bgCol.g, bgCol.b, bgA or bgCol.a or 255))
        end
    else
        draw.RoundedBox(radius, x, y, w, h, Color(bgCol.r, bgCol.g, bgCol.b, bgA or bgCol.a or 255))
    end
end

function DuckAch.dropShadow(x, y, w, h, radius, strength, offsetY)
    strength = strength or 110
    offsetY  = offsetY or 4
    local layers = 4
    for i = layers, 1, -1 do
        local grow = i * 2
        local a    = _floor(strength * (1 - (i - 1) / layers) * 0.22)
        draw.RoundedBox(radius + grow, x - grow, y - grow + offsetY, w + grow * 2, h + grow * 2, Color(0, 0, 0, a))
    end
end

function DuckAch.pulse(speed, lo, hi)
    local t = (math.sin(RealTime() * (speed or 2)) + 1) * 0.5
    return Lerp(t, lo or 0, hi or 1)
end
