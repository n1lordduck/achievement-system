DuckAch.UI = DuckAch.UI or {}

local C    = DuckAch.C
local fill = DuckAch.fillC
local out  = DuckAch.outlineC

local function makeToggleBtn(parent, labelOn, labelOff, state, onChange)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(LEFT)
    btn:DockMargin(0, 0, 8, 0)
    btn:SetWide(150)
    btn:SetText("")

    local _state = state
    btn.Paint = function(self, w, h)
        local col = _state and C.success or C.red
        DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, 45)
        DuckAch.drawText(_state and labelOn or labelOff, "DA_Btn",
            math.floor(w*0.5), math.floor(h*0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        _state = not _state
        onChange(_state)
    end
    return btn
end

local function buildProfileContent(parent, targetPly, W, H)
    local isMe = targetPly == LocalPlayer()
    local prof = DuckAch.Client.profile
    local name = targetPly:Name()
    local sid  = targetPly:SteamID()

    local header = vgui.Create("DPanel", parent)
    header:SetPos(0, 0)
    header:SetSize(W, 72)
    header.Paint = function(self, w, h)
        DuckAch.roundedFill(0, 0, w, h, 8, C.panel, 255)
        fill(0, h - 1, w, 1, C.sep)
    end

    local pfpSz = 48
    local avatar = vgui.Create("AvatarImage", header)
    avatar:SetPos(12, math.floor((72 - pfpSz) * 0.5))
    avatar:SetSize(pfpSz, pfpSz)
    avatar:SetPlayer(targetPly, 64)

    local avatarBorder = vgui.Create("DPanel", header)
    avatarBorder:SetPos(12, math.floor((72 - pfpSz) * 0.5))
    avatarBorder:SetSize(pfpSz, pfpSz)
    avatarBorder.Paint = function(self, w, h)
        local glowA = DuckAch.pulse(1.2, 60, 120)
        out(-2, -2, w + 4, h + 4, C.brand, glowA, 1)
        out(0, 0, w, h, C.accent, 90, 1)
    end

    local infoX = 12 + pfpSz + 10
    local info  = vgui.Create("DPanel", header)
    info:SetPos(infoX, 0)
    info:SetSize(W - infoX - 40, 72)
    info.Paint = function(self, w, h)
        local total     = table.Count(DuckAch.Client.achievements)
        local nUnlocked = 0
        for _ in pairs(prof.unlocked or {}) do nUnlocked = nUnlocked + 1 end
        local pct = total > 0 and math.Round((nUnlocked / total) * 100, 0) or 0

        DuckAch.drawText(name, "DA_Sub", 0, 8, C.cream)
        DuckAch.drawText(sid, "DA_Tiny", 0, 26,
            Color(C.muted.r, C.muted.g, C.muted.b))
        DuckAch.drawText(nUnlocked .. " / " .. total .. "  (" .. pct .. "%)", "DA_Tiny", 0, 42,
            Color(C.muted2.r, C.muted2.g, C.muted2.b))
    end

    local statsWrap = vgui.Create("DPanel", parent)
    statsWrap:SetPos(0, 80)
    statsWrap:SetSize(W, 56)
    statsWrap.Paint = function(self, w, h)
        local kills  = prof.kills  or 0
        local deaths = prof.deaths or 0
        local kd     = deaths > 0 and string.format("%.2f", kills / deaths) or "-"

        local statDefs = {
            { label = DuckAch.L("profile.kills"),  val = tostring(kills) },
            { label = DuckAch.L("profile.deaths"), val = tostring(deaths) },
            { label = DuckAch.L("profile.kd_ratio"), val = kd },
        }

        local cw = math.floor(w / #statDefs)
        for i, s in ipairs(statDefs) do
            local sx = math.floor((i - 0.5) * cw)
            DuckAch.drawText(s.val, "DA_Sub", sx, 4, C.cream, TEXT_ALIGN_CENTER)
            DuckAch.drawText(s.label, "DA_Tiny", sx, 30,
                Color(C.muted.r, C.muted.g, C.muted.b), TEXT_ALIGN_CENTER)

            if i < #statDefs then
                fill(i * cw, 6, 1, 36, C.sep)
            end
        end
    end

    local sepA = vgui.Create("DPanel", parent)
    sepA:SetPos(8, 140)
    sepA:SetSize(W - 16, 1)
    sepA.Paint = function(self, w, h) fill(0, 0, w, h, C.sep) end

    local achLbl = vgui.Create("DPanel", parent)
    achLbl:SetPos(12, 147)
    achLbl:SetSize(W - 24, 16)
    achLbl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("profile.unlocked_section"), "DA_Badge", 0, math.floor(h*0.5),
            Color(C.muted.r, C.muted.g, C.muted.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local listBottom = isMe and (H - 200) or H
    local scrollH    = listBottom - 168

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(8, 168)
    scroll:SetSize(W - 16, scrollH)

    local sbar = scroll:GetVBar()
    sbar:SetHideButtons(true)
    sbar.Paint         = function(self, w, h) fill(0, 0, w, h, C.border) end
    sbar.btnGrip.Paint = function(self, w, h) fill(0, 0, w, h, C.accent, 90) end

    local unlockList = prof.unlocked or {}
    local hasAny     = false
    local rowY       = 0
    local rowH       = 36

    local sorted = {}
    for achId, ts in pairs(unlockList) do
        table.insert(sorted, { id = achId, ts = ts })
    end
    table.sort(sorted, function(a, b) return (tonumber(a.ts) or 0) > (tonumber(b.ts) or 0) end)

    for _, entry in ipairs(sorted) do
        local view = DuckAch.Client.achievements[entry.id]
        if view then
            hasAny = true
            local rar    = DuckAch.GetRarity(view.rarity)
            local rarCol = rar.color
            local _ts    = entry.ts
            local _view  = view

            local row = vgui.Create("DPanel", scroll)
            row:SetPos(0, rowY)
            row:SetSize(scroll:GetWide() - 6, rowH)

            row.Paint = function(self, w, h)
                DuckAch.panelBG(0, 0, w, h, 6, C.card, 255, C.border, 55, 1)
                DuckAch.roundedFillEx(0, 0, 3, h, 6, rarCol, 200, true, false, true, false)

                DuckAch.drawText(_view.name, "DA_Tiny", 10, 6, C.cream)
                DuckAch.drawText(rar.label, "DA_Tiny", 10, 20,
                    Color(rarCol.r, rarCol.g, rarCol.b))

                local dateStr = os.date("%d/%m %H:%M", tonumber(_ts) or 0)
                DuckAch.drawText(dateStr, "DA_Tiny", w - 8, math.floor(h*0.5),
                    Color(C.muted.r, C.muted.g, C.muted.b),
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            rowY = rowY + rowH + 3
        end
    end

    if not hasAny then
        local empty = vgui.Create("DPanel", scroll)
        empty:SetPos(0, 0)
        empty:SetSize(scroll:GetWide() - 6, 36)
        empty.Paint = function(self, w, h)
            DuckAch.drawText(DuckAch.L("profile.none_unlocked"), "DA_Tiny",
                math.floor(w*0.5), math.floor(h*0.5),
                Color(C.muted.r, C.muted.g, C.muted.b),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if not isMe then return end

    local sepLang = vgui.Create("DPanel", parent)
    sepLang:SetPos(8, H - 200)
    sepLang:SetSize(W - 16, 1)
    sepLang.Paint = function(self, w, h) fill(0, 0, w, h, C.sep) end

    local langLbl = vgui.Create("DPanel", parent)
    langLbl:SetPos(12, H - 190)
    langLbl:SetSize(W - 24, 14)
    langLbl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("profile.language"), "DA_Badge", 0, 0,
            Color(C.muted.r, C.muted.g, C.muted.b))
    end

    local LANG_LABELS = { ["en"] = "ENGLISH", ["es"] = "ESPAÑOL", ["pt-br"] = "PORTUGUÊS" }

    local langRow = vgui.Create("DPanel", parent)
    langRow:SetPos(12, H - 170)
    langRow:SetSize(W - 24, 22)
    langRow.Paint = function() end

    for _, code in ipairs(DuckAch.Lang.Available) do
        local btn = vgui.Create("DButton", langRow)
        btn:Dock(LEFT)
        btn:DockMargin(0, 0, 8, 0)
        btn:SetWide(math.floor((W - 24 - 16) / 3))
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local active = (DuckAch.Lang.EffectiveLanguage() == code)
            local col    = active and C.accent or C.muted
            local fillA  = active and 70 or (self:IsHovered() and 24 or 12)
            DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, fillA)
            DuckAch.drawText(LANG_LABELS[code] or code, "DA_Btn",
                math.floor(w*0.5), math.floor(h*0.5),
                Color(col.r, col.g, col.b, active and 255 or 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            DuckAch.Lang.SetPlayerLanguage(code)
        end
    end

    local resetLangBtn = vgui.Create("DButton", parent)
    resetLangBtn:SetPos(12, H - 144)
    resetLangBtn:SetSize(W - 24, 18)
    resetLangBtn:SetText("")
    resetLangBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and C.muted2 or C.muted
        DuckAch.drawText(DuckAch.L("menu.use_server_default"), "DA_Tiny",
            math.floor(w*0.5), math.floor(h*0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    resetLangBtn.DoClick = function()
        DuckAch.Lang.SetPlayerLanguage(nil)
    end

    local sepB = vgui.Create("DPanel", parent)
    sepB:SetPos(8, H - 110)
    sepB:SetSize(W - 16, 1)
    sepB.Paint = function(self, w, h) fill(0, 0, w, h, C.sep) end

    local privLbl = vgui.Create("DPanel", parent)
    privLbl:SetPos(12, H - 100)
    privLbl:SetSize(W - 24, 14)
    privLbl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("profile.cache_privacy"), "DA_Badge", 0, 0,
            Color(C.muted.r, C.muted.g, C.muted.b))
    end

    local btnCol1 = vgui.Create("DPanel", parent)
    btnCol1:SetPos(12, H - 80)
    btnCol1:SetSize(W - 24, 22)
    btnCol1.Paint = function() end

    local optOut = prof.optOutCache or false
    makeToggleBtn(btnCol1, DuckAch.L("profile.cache_on"), DuckAch.L("profile.cache_off"), not optOut, function(state)
        DuckAch.Client.SetOptOut(not state)
    end)

    local clearBtn = vgui.Create("DButton", parent)
    clearBtn:SetPos(12, H - 52)
    clearBtn:SetSize(W - 24, 22)
    clearBtn:SetText("")
    clearBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and C.amber or C.muted
        DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, self:IsHovered() and 45 or 20)
        DuckAch.drawText(DuckAch.L("profile.clear_cache"), "DA_Btn", math.floor(w*0.5), math.floor(h*0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    clearBtn.DoClick = function()
        DuckAch.Client.ClearCache()
        clearBtn:SetDisabled(true)
    end

    local resetBtn = vgui.Create("DButton", parent)
    resetBtn:SetPos(12, H - 24)
    resetBtn:SetSize(W - 24, 22)
    resetBtn:SetText("")
    local _confirmReset = false
    local _confirmTimer = nil
    resetBtn.Paint = function(self, w, h)
        local col = _confirmReset and C.red or (self:IsHovered() and C.red or C.muted)
        DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, _confirmReset and 70 or 20)
        local lbl = _confirmReset and DuckAch.L("profile.reset_confirm") or DuckAch.L("profile.reset_progress")
        DuckAch.drawText(lbl, "DA_Btn", math.floor(w*0.5), math.floor(h*0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    resetBtn.DoClick = function()
        if not _confirmReset then
            _confirmReset = true
            if _confirmTimer then timer.Remove(_confirmTimer) end
            _confirmTimer = "DuckAch.ResetConfirm." .. tostring(resetBtn)
            timer.Create(_confirmTimer, 3, 1, function()
                _confirmReset = false
                _confirmTimer = nil
            end)
        else
            _confirmReset = false
            if _confirmTimer then timer.Remove(_confirmTimer); _confirmTimer = nil end
            net.Start("DuckAch.ResetProgress")
            net.SendToServer()
            resetBtn:SetDisabled(true)
        end
    end
end

function DuckAch.UI.ShowProfileOverlay(targetPly)
    if not IsValid(targetPly) then return end
    if not DuckAch.UI.GetOverlayPanel then return end

    local W, H = 420, math.min(610, ScrH() - 80)
    local panel = DuckAch.UI.GetOverlayPanel(W, H)
    if not panel then return end

    for _, child in ipairs(panel:GetChildren()) do
        if child ~= panel.DA_CloseBtn then child:Remove() end
    end

    panel.Paint = function(self, w, h)
        DuckAch.dropShadow(0, 0, w, h, 0, 150, 6)
        DuckAch.panelBG(0, 0, w, h, 0, C.bg, 255, C.border, 255, 1)
        DuckAch.roundedFillEx(1, 1, w - 2, 4, 0, C.brand, DuckAch.pulse(1, 150, 220), true, true, false, false)
    end

    local content = vgui.Create("DPanel", panel)
    content:SetPos(0, 30)
    content:SetSize(W, H - 30)
    content.Paint = function() end

    buildProfileContent(content, targetPly, W, H - 30)
end

function DuckAch.UI.OpenProfile(targetPly)
    DuckAch.UI.ShowProfileOverlay(targetPly)
end
