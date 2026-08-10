--// Language Panel
--// Separate section from the achievement panel: switches the active preset
--// (en/es/pt-br) and lets you edit any interface string, one at a time, with
--// server-side persistence. Follows the same DFrame pattern as the addon's
--// other windows (MakePopup + X button) to open on top and close properly.

DuckAch.UI = DuckAch.UI or {}

local C    = DuckAch.C
local fill = DuckAch.fillC
local out  = DuckAch.outlineC
local Lang = DuckAch.Lang

local LANG_NAMES = {
    ["en"]    = "English",
    ["es"]    = "Español",
    ["pt-br"] = "Português (BR)",
}

local _frame = nil

local function isSuperAdmin()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    return ply:IsSuperAdmin()
end

local function keyHasOverride(langcode, key)
    return Lang.Overrides[langcode] and Lang.Overrides[langcode][key] ~= nil
end

local function buildRow(parent, key, y, search)
    local row = vgui.Create("DPanel", parent)
    row:SetPos(0, y)
    row:SetSize(parent:GetWide() - 24, 62)
    row.Paint = function(_, w, h)
        fill(0, 0, w, h, C.card)
        out(0, 0, w, h, C.border)
    end

    DuckAch.drawText(key, "DA_Tiny", 10, 6, C.muted2)

    local override = keyHasOverride(Lang.Current, key)
    local current   = Lang.Raw(key, Lang.Current) or ""

    local entry = vgui.Create("DTextEntry", row)
    entry:SetPos(10, 20)
    entry:SetSize(row:GetWide() - 190, 26)
    entry:SetFont("DA_Sub")
    entry:SetText(current)
    entry:SetTextColor(C.white)
    entry.Paint = function(self, w, h)
        fill(0, 0, w, h, C.bg)
        out(0, 0, w, h, override and C.accent or C.border)
        self:DrawTextEntryText(C.white, C.accent, C.white)
    end

    local saveBtn = vgui.Create("DButton", row)
    saveBtn:SetPos(row:GetWide() - 172, 20)
    saveBtn:SetSize(78, 26)
    saveBtn:SetText("")
    saveBtn.Paint = function(_, w, h)
        fill(0, 0, w, h, C.accent, 40)
        out(0, 0, w, h, C.accent)
        DuckAch.drawText(DuckAch.L("admin.lang_save"), "DA_Badge", w / 2, h / 2 - 5, C.accent, TEXT_ALIGN_CENTER)
    end
    saveBtn.DoClick = function()
        local val = entry:GetValue()
        DuckAch.Lang.RequestSetOverride(Lang.Current, key, val)
        surface.PlaySound("buttons/button15.wav")
    end

    local resetBtn = vgui.Create("DButton", row)
    resetBtn:SetPos(row:GetWide() - 88, 20)
    resetBtn:SetSize(78, 26)
    resetBtn:SetText("")
    resetBtn:SetEnabled(override)
    resetBtn.Paint = function(_, w, h)
        local a = override and 255 or 90
        fill(0, 0, w, h, C.red, 30)
        out(0, 0, w, h, C.red, a)
        DuckAch.drawText(DuckAch.L("admin.lang_reset"), "DA_Badge", w / 2, h / 2 - 5, ColorAlpha(C.red, a), TEXT_ALIGN_CENTER)
    end
    resetBtn.DoClick = function()
        DuckAch.Lang.RequestResetOverride(Lang.Current, key)
        surface.PlaySound("buttons/button14.wav")
    end

    return row
end

local function refreshList(scroll, search)
    scroll:Clear()
    local y = 0

    local keys = Lang.GetAllKeys()
    for _, key in ipairs(keys) do
        if search == "" or string.find(string.lower(key), search, 1, true)
            or string.find(string.lower(Lang.Raw(key, Lang.Current) or ""), search, 1, true) then
            buildRow(scroll, key, y, search)
            y = y + 68
        end
    end
end

local function buildLangSelector(parent, onChange)
    local titleLbl = vgui.Create("DPanel", parent)
    titleLbl:SetPos(0, 0)
    titleLbl:SetSize(parent:GetWide(), 16)
    titleLbl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("admin.lang_selector_title"), "DA_Badge", 0, 0, C.accent)
    end

    local hintLbl = vgui.Create("DPanel", parent)
    hintLbl:SetPos(0, 16)
    hintLbl:SetSize(parent:GetWide(), 28)
    hintLbl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("admin.lang_selector_hint"), "DA_Tiny", 0, 0, C.muted2)
    end

    local wrap = vgui.Create("DPanel", parent)
    wrap:SetPos(0, 46)
    wrap:SetSize(parent:GetWide(), 36)
    wrap.Paint = function() end

    local x = 0
    for _, code in ipairs(Lang.Available) do
        local btn = vgui.Create("DButton", wrap)
        btn:SetPos(x, 0)
        btn:SetSize(160, 36)
        btn:SetText("")
        btn.Paint = function(_, w, h)
            local active = (Lang.Current == code)
            fill(0, 0, w, h, active and C.accent or C.card, active and 220 or 255)
            out(0, 0, w, h, C.accent, active and 255 or 90)
            local lbl = LANG_NAMES[code] or code
            DuckAch.drawText(lbl, "DA_Btn", w / 2, h / 2 - 6,
                active and C.bg or C.accent, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            DuckAch.Lang.RequestSetActive(code)
            timer.Simple(0.15, function() if IsValid(wrap) then onChange() end end)
        end
        x = x + 168
    end

    local statusLbl = vgui.Create("DPanel", parent)
    statusLbl:SetPos(0, 88)
    statusLbl:SetSize(parent:GetWide(), 16)
    statusLbl.Paint = function(self, w, h)
        local txt = DuckAch.L("admin.lang_current_status", LANG_NAMES[Lang.Current] or Lang.Current)
        DuckAch.drawText(txt, "DA_Sub", 0, 0, C.success)
    end

    return wrap
end

function DuckAch.UI.OpenLangPanel()
    if not isSuperAdmin() then return end
    if IsValid(_frame) then _frame:Close() return end

    local W, H = 720, 680

    local frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        fill(0, 0, w, h, C.bg)
        out(0, 0, w, h, C.accent, 40)
    end
    frame.OnClose = function() _frame = nil end
    _frame = frame

    DuckAch.drawText(DuckAch.L("admin.lang_panel_title"), "DA_Title", 20, 16, C.accent)
    DuckAch.drawText(DuckAch.L("admin.lang_panel_subtitle"), "DA_Tiny", 20, 42, C.muted2)

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(W - 28, 14)
    closeBtn:SetSize(20, 20)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then fill(0, 0, w, h, C.red, 60) end
        out(0, 0, w, h, C.red, self:IsHovered() and 180 or 70)
        DuckAch.drawText("X", "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.red.r, C.red.g, C.red.b, self:IsHovered() and 255 or 160),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Close() end

    local body = vgui.Create("DPanel", frame)
    body:SetPos(20, 70)
    body:SetSize(W - 40, H - 90)
    body.Paint = function() end

    local scroll = vgui.Create("DScrollPanel", body)
    local search  = ""

    buildLangSelector(body, function() refreshList(scroll, search) end)

    local searchEntry = vgui.Create("DTextEntry", body)
    searchEntry:SetPos(0, 118)
    searchEntry:SetSize(body:GetWide(), 30)
    searchEntry:SetFont("DA_Sub")
    searchEntry:SetPlaceholderText(DuckAch.L("admin.lang_search_placeholder"))
    searchEntry.Paint = function(self, w, h)
        fill(0, 0, w, h, C.card)
        out(0, 0, w, h, C.border)
        self:DrawTextEntryText(C.white, C.accent, C.white)
    end
    searchEntry.OnValueChange = function(self)
        search = string.lower(self:GetValue() or "")
        refreshList(scroll, search)
    end

    scroll:SetPos(0, 158)
    scroll:SetSize(body:GetWide(), body:GetTall() - 158)

    refreshList(scroll, search)

    hook.Add("DuckAch.Lang.Updated", "DuckAch.LangPanel.Refresh", function()
        if IsValid(scroll) then refreshList(scroll, search) end
    end)

    frame.OnRemove = function()
        hook.Remove("DuckAch.Lang.Updated", "DuckAch.LangPanel.Refresh")
    end
end

concommand.Add("duck_ach_lang", function()
    DuckAch.UI.OpenLangPanel()
end)
