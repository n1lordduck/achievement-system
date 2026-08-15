DuckAch.UI = DuckAch.UI or {}

local C        = DuckAch.C
local fill     = DuckAch.fillC
local out      = DuckAch.outlineC
local CARD_S   = 130
local CARD_PAD = 8

local _menuFrame    = nil
local _overlayPanel  = nil
local _overlayW      = 460
local _overlayH      = 460
local _activeFilter = { text = "", rarity = "all", state = "all" }

local function achMatchesFilter(achId, view, hasIt)
    if _activeFilter.text ~= "" then
        local q = _activeFilter.text:lower()
        if not view.name:lower():find(q, 1, true)
        and not achId:lower():find(q, 1, true) then
            return false
        end
    end
    if _activeFilter.rarity ~= "all" and view.rarity ~= _activeFilter.rarity then
        return false
    end
    if _activeFilter.state == "unlocked" and not hasIt then return false end
    if _activeFilter.state == "locked"   and hasIt     then return false end
    return true
end

local _wrapper   = nil
local _scrollW   = 0
local _page      = 1
local PAGE_SIZE  = 24
local _onPageChange = nil

local function buildAchList()
    local profile  = DuckAch.Client.profile
    local unlocked = profile.unlocked or {}
    local achList  = {}
    for achId, view in pairs(DuckAch.Client.achievements) do
        local hasIt = unlocked[achId] ~= nil
        if achMatchesFilter(achId, view, hasIt) then
            table.insert(achList, { id = achId, view = view, hasIt = hasIt })
        end
    end
    table.sort(achList, function(a, b)
        local ra = DuckAch.GetRarity(a.view.rarity).order or 0
        local rb = DuckAch.GetRarity(b.view.rarity).order or 0
        return ra > rb
    end)
    return achList
end

local function rebuildGrid()
    if not IsValid(_wrapper) then return end

    local achList  = buildAchList()
    local total    = #achList
    local maxPages = math.max(1, math.ceil(total / PAGE_SIZE))
    _page          = math.Clamp(_page, 1, maxPages)
    _wrapper:Clear()

    local PAD    = 14
    local availW = _scrollW - PAD * 2
    local cols   = math.max(1, math.floor(availW / (CARD_S + CARD_PAD)))
    local rowH   = CARD_S + 24 + CARD_PAD

    local startI = (_page - 1) * PAGE_SIZE + 1
    local endI   = math.min(_page * PAGE_SIZE, total)
    local pageList = {}
    for i = startI, endI do table.insert(pageList, achList[i]) end

    local rows   = math.ceil(#pageList / cols)
    local totalH = math.max(rows * rowH + PAD * 2, 1)
    _wrapper:SetSize(_scrollW, totalH)

    for i, entry in ipairs(pageList) do
        local ci  = (i - 1) % cols
        local ri  = math.floor((i - 1) / cols)
        local cx  = PAD + ci * (CARD_S + CARD_PAD)
        local cy  = PAD + ri * rowH
        local card = buildCard(_wrapper, entry.id, entry.view, entry.hasIt)
        card:SetPos(cx, cy)
    end

    if _onPageChange then _onPageChange(_page, maxPages, total) end
end

local function getProgLines(prog, view)
    if not prog then return nil end
    local isMulti = view and view.triggerType == "multi_requirement"
    if isMulti and prog.details and #prog.details > 0 then
        return { type = "multi", details = prog.details }
    end
    local filled = math.Clamp(prog.current / math.max(prog.needed, 1), 0, 1)
    local unit   = prog.unit or ""
    return { type = "single", current = prog.current, needed = prog.needed, unit = unit, filled = filled }
end

local CARD_RADIUS = 0
local _isHighRarity = { legendary = true, secret = true }

function buildCard(parent, achId, view, unlocked)
    local rar     = DuckAch.GetRarity(view.rarity)
    local rarCol  = rar.color
    local hovered = false

    local prog      = DuckAch.Client.progress and DuckAch.Client.progress[achId]
    local progLines = not unlocked and getProgLines(prog, view) or nil
    local extraRows = (progLines and progLines.type == "multi") and #progLines.details or 0
    local cardH     = CARD_S + 24 + (extraRows * 14)

    local card = vgui.Create("DPanel", parent)
    card:SetSize(CARD_S, cardH)
    card:SetCursor("hand")

    local TILT_RADIUS = 75
    local tiltX, tiltY = 0, 0
    local targetTiltX, targetTiltY = 0, 0

    card.OnCursorMoved = function(self, mx, my)
        local cw, ch = self:GetSize()
        targetTiltX = math.Clamp((mx - cw * 0.5) / TILT_RADIUS, -1, 1)
        targetTiltY = math.Clamp((my - ch * 0.5) / TILT_RADIUS, -1, 1)
    end

    card.Paint = function(self, w, h)
        local smooth = 1 - math.exp(-FrameTime() * 14)
        tiltX = Lerp(smooth, tiltX, hovered and targetTiltX or 0)
        tiltY = Lerp(smooth, tiltY, hovered and targetTiltY or 0)

        local tilting = hovered and (math.abs(tiltX) > 0.001 or math.abs(tiltY) > 0.001)

        DuckAch.dropShadow(0, 0, w, h, CARD_RADIUS, hovered and 90 or 45, 3)

        local bg        = hovered and C.cardHov or C.card
        local borderCol = hovered and rarCol or C.border
        local borderA   = hovered and 200 or 55
        DuckAch.panelBG(0, 0, w, h, CARD_RADIUS, bg, 255, borderCol, borderA, 1)

        local topStripA = unlocked and 220 or 50
        if unlocked and _isHighRarity[view.rarity] then
            topStripA = DuckAch.pulse(1.6, 150, 255)
        end
        DuckAch.roundedFillEx(1, 1, w - 2, 4, CARD_RADIUS, rarCol, topStripA, true, true, false, false)

        if unlocked then
            surface.SetDrawColor(rarCol.r, rarCol.g, rarCol.b, 18)
            surface.DrawRect(1, 4, w - 2, h - 5)
        else
            surface.SetDrawColor(0, 0, 0, 50)
            surface.DrawRect(1, 4, w - 2, h - 5)
        end

        if not unlocked and DuckAch.UI.IsPinned(achId) then
            DuckAch.roundedFill(w - 16, 5, 10, 10, 0, C.amber, 220)
        elseif not unlocked then
            surface.SetMaterial(DuckAch.Icons.lock)
            surface.SetDrawColor(C.muted.r, C.muted.g, C.muted.b, 130)
            surface.DrawTexturedRect(w - 16, 6, 10, 10)
        end

        local iconSz = 48
        local iconX  = math.floor((w - iconSz) * 0.5)
        local iconY  = 12

        local mat = DuckAch.Client.GetCachedMat(view.thumbnail)
        if not mat and view.thumbnail and view.thumbnail ~= "" then
            DuckAch.Client.GetThumbnail(view.thumbnail, function() end)
            mat = DuckAch.Client.GetCachedMat(view.thumbnail)
        end

        local iconCx = iconX + iconSz * 0.5 - tiltX * 5
        local iconCy = iconY + iconSz * 0.5 - tiltY * 5

        if mat and not mat:IsError() then
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, unlocked and 255 or 70)
            surface.DrawTexturedRectRotated(iconCx, iconCy, iconSz, iconSz, tiltX * 8)
        else
            DuckAch.panelBG(iconX, iconY, iconSz, iconSz, 0, C.border, 255, rarCol, unlocked and 90 or 28, 1)
            DuckAch.drawText(unlocked and "★" or "?", "DA_Modal",
                iconCx, iconCy,
                Color(rarCol.r, rarCol.g, rarCol.b, unlocked and 220 or 60),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if tilting and mat and not mat:IsError() then
            local shineX = iconCx + tiltX * (iconSz * 0.35)
            local shineY = iconCy + tiltY * (iconSz * 0.35)
            for i = 3, 1, -1 do
                local rad = i * 9
                local a   = (4 - i) * 12
                DuckAch.roundedFill(shineX - rad, shineY - rad, rad * 2, rad * 2, rad, C.white, a)
            end
        end

        local nameCol = unlocked and C.cream or C.muted
        local nameY   = iconY + iconSz + 5
        draw.SimpleTextOutlined(view.name, "DA_Badge",
            math.floor(w * 0.5), nameY,
            Color(nameCol.r, nameCol.g, nameCol.b),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
            1, Color(0, 0, 0, 100))

        local pl = not unlocked and getProgLines(DuckAch.Client.progress and DuckAch.Client.progress[achId] or nil, view) or nil
        if pl then
            local barW = w - 16
            local barX = 8

            if pl.type == "multi" then
                local by = nameY + 18
                for _, det in ipairs(pl.details) do
                    local col    = det.met and C.success or rarCol
                    local filled = math.Clamp(det.current / math.max(det.needed, 1), 0, 1)

                    local lbl = det.label
                    if #lbl > 14 then lbl = lbl:sub(1, 12) .. ".." end
                    DuckAch.drawText(lbl, "DA_Tiny", barX, by,
                        Color(col.r, col.g, col.b, 180), TEXT_ALIGN_LEFT)

                    fill(barX, by + 10, barW, 3, C.border)
                    fill(barX, by + 10, math.floor(barW * filled), 3, col, det.met and 220 or 170)

                    by = by + 14
                end
            else
                local barY   = h - 26
                local filled = pl.filled
                DuckAch.roundedFill(barX, barY, barW, 4, 2, C.border, 255)
                if filled > 0 then
                    DuckAch.roundedFill(barX, barY, math.max(math.floor(barW * filled), 4), 4, 2, rarCol, 200)
                end
                DuckAch.drawText(pl.current .. " / " .. pl.needed, "DA_Mono",
                    math.floor(w * 0.5), barY - 8,
                    Color(rarCol.r, rarCol.g, rarCol.b, 180), TEXT_ALIGN_CENTER)
            end
        else
            DuckAch.drawText(rar.label, "DA_Badge",
                math.floor(w * 0.5), h - 20,
                Color(rarCol.r, rarCol.g, rarCol.b, unlocked and 190 or 45),
                TEXT_ALIGN_CENTER)
        end

        local pct = DuckAch.Client.stats[achId] or 0
        DuckAch.drawText(string.format("%.1f%%", pct), "DA_Mono",
            math.floor(w * 0.5), h - 10,
            Color(C.muted.r, C.muted.g, C.muted.b), TEXT_ALIGN_CENTER)
    end

    card.OnCursorEntered = function() hovered = true end
    card.OnCursorExited  = function() hovered = false end
    card.OnMousePressed  = function(self, mcode)
        if mcode == MOUSE_RIGHT then
            local hasIt = (DuckAch.Client.profile.unlocked or {})[achId] ~= nil
            if hasIt then return end
            DuckAch.UI.TogglePin(achId, view)
            return
        end
        local pct   = DuckAch.Client.stats[achId] or 0
        local hasIt = (DuckAch.Client.profile.unlocked or {})[achId] ~= nil
        DuckAch.UI.ShowDetail(achId, view, hasIt, pct)
    end

    return card
end


local OVERLAY_ANIM_TIME = 0.18

local function killOverlayAnim(panel)
    if panel and panel.DA_AnimThink then
        hook.Remove("Think", panel.DA_AnimThink)
        panel.DA_AnimThink = nil
    end
end

local function ensureOverlayPanel()
    if IsValid(_overlayPanel) then return _overlayPanel end

    local sw, sh = ScrW(), ScrH()

    local dim = vgui.Create("DPanel")
    dim:SetPos(0, 0)
    dim:SetSize(sw, sh)
    dim:SetMouseInputEnabled(true)
    dim:MakePopup()
    dim.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 140)
        surface.DrawRect(0, 0, w, h)
    end
    dim.OnMousePressed = function() DuckAch.UI.CloseOverlay() end

    local panel = vgui.Create("DPanel", dim)
    panel:SetSize(_overlayW, _overlayH)
    panel:SetPos(math.floor((sw - _overlayW) * 0.5), math.floor((sh - _overlayH) * 0.5))
    panel.Paint = function(self, w, h)
        DuckAch.dropShadow(0, 0, w, h, 0, 160, 6)
        DuckAch.panelBG(0, 0, w, h, 0, C.bg, 255, C.border, 255, 1)
    end
    panel.OnMousePressed = function() end

    panel.DA_Dim = dim

    local closeBtn = vgui.Create("DButton", panel)
    closeBtn:SetPos(_overlayW - 30, 8)
    closeBtn:SetSize(22, 22)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        local hov = self:IsHovered()
        DuckAch.panelBG(0, 0, w, h, 0, C.red, hov and 55 or 22, C.red, hov and 200 or 90, 1)
        DuckAch.drawText("X", "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.red.r, C.red.g, C.red.b, hov and 255 or 170),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() DuckAch.UI.CloseOverlay() end
    panel.DA_CloseBtn = closeBtn

    _overlayPanel = panel
    return panel
end

local function animateOverlayOpen(panel, targetW, targetH)
    killOverlayAnim(panel)

    local sw, sh = ScrW(), ScrH()
    local startW = 8
    local startH = math.floor(targetH * 0.15)
    local t0     = SysTime()

    local function applySize(w, h)
        if not IsValid(panel) then return end
        local fw = math.floor(w)
        local fh = math.floor(h)
        panel:SetSize(fw, fh)
        panel:SetPos(math.floor((sw - fw) * 0.5), math.floor((sh - fh) * 0.5))
        if IsValid(panel.DA_CloseBtn) then
            panel.DA_CloseBtn:SetPos(fw - 26, 6)
        end
    end

    applySize(startW, startH)

    local animId = "DuckAch.Overlay.Anim." .. tostring(panel)
    panel.DA_AnimThink = animId

    hook.Add("Think", animId, function()
        if not IsValid(panel) then hook.Remove("Think", animId) return end
        local t      = math.Clamp((SysTime() - t0) / OVERLAY_ANIM_TIME, 0, 1)
        local eased  = 1 - (1 - t) * (1 - t)
        applySize(Lerp(eased, startW, targetW), Lerp(eased, startH, targetH))
        if t >= 1 then hook.Remove("Think", animId); panel.DA_AnimThink = nil end
    end)
end

function DuckAch.UI.CloseOverlay()
    if IsValid(_overlayPanel) then
        killOverlayAnim(_overlayPanel)
        if IsValid(_overlayPanel.DA_Dim) then
            _overlayPanel.DA_Dim:Remove()
        else
            _overlayPanel:Remove()
        end
    end
    _overlayPanel = nil
end

function DuckAch.UI.GetOverlayPanel(targetW, targetH)
    local panel = ensureOverlayPanel()
    animateOverlayOpen(panel, targetW or _overlayW, targetH or _overlayH)
    return panel
end

function DuckAch.UI.ShowDetail(achId, view, unlocked, pct)
    local prog    = DuckAch.Client.progress and DuckAch.Client.progress[achId]
    local isMulti = view.triggerType == "multi_requirement"
    local details = (prog and prog.details) or {}

    local baseH  = 400
    local extraH = isMulti and (#details * 32 + 30) or 0
    local W, H   = 460, math.min(baseH + extraH, ScrH() - 80)

    local panel = DuckAch.UI.GetOverlayPanel(W, H)
    if not panel then return end

    for _, child in ipairs(panel:GetChildren()) do
        if child ~= panel.DA_CloseBtn then child:Remove() end
    end

    local rar    = DuckAch.GetRarity(view.rarity)
    local rarCol = rar.color

    panel.Paint = function(self, w, h)
        DuckAch.dropShadow(0, 0, w, h, 0, 150, 6)
        DuckAch.panelBG(0, 0, w, h, 0, C.bg, 255, C.border, 255, 1)
        DuckAch.roundedFillEx(1, 1, w - 2, 4, 0, rarCol, 255, true, true, false, false)
        if unlocked then
            surface.SetDrawColor(rarCol.r, rarCol.g, rarCol.b, 12)
            surface.DrawRect(1, 4, w - 2, h - 5)
        end
    end

    if not unlocked then
        local pinBtn = vgui.Create("DButton", panel)
        pinBtn:SetPos(8, 6)
        pinBtn:SetSize(20, 20)
        pinBtn:SetText("")
        pinBtn.Paint = function(self, w, h)
            local pinnedNow = DuckAch.UI.IsPinned(achId)
            local col = pinnedNow and C.amber or C.muted
            DuckAch.panelBG(0, 0, w, h, 0, col, pinnedNow and 200 or 0, col, self:IsHovered() and 220 or 130, 1)
        end
        pinBtn.DoClick = function() DuckAch.UI.TogglePin(achId, view) end
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:SetPos(0, 36)
    scroll:SetSize(W, H - 36)
    local sbar = scroll:GetVBar()
    sbar:SetHideButtons(true)
    sbar.Paint         = function(self, w, h) fill(0, 0, w, h, C.border) end
    sbar.btnGrip.Paint = function(self, w, h) fill(0, 0, w, h, C.accent, 90) end

    local body = vgui.Create("DPanel", scroll)
    body:SetSize(W - 8, 600)
    body.Paint = function(self, w, h)
        local PAD     = 18
        local thumbSz = 80
        local tx, ty  = PAD, PAD

        local mat = DuckAch.Client.GetCachedMat(view.thumbnail)
        if not mat and view.thumbnail and view.thumbnail ~= "" then
            DuckAch.Client.GetThumbnail(view.thumbnail, function() end)
            mat = DuckAch.Client.GetCachedMat(view.thumbnail)
        end

        if mat and not mat:IsError() then
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, unlocked and 255 or 80)
            surface.DrawTexturedRect(tx, ty, thumbSz, thumbSz)
        else
            DuckAch.panelBG(tx, ty, thumbSz, thumbSz, 8, C.card, 255, rarCol, 60, 1)
            DuckAch.drawText(unlocked and "★" or "?", "DA_Big",
                tx + math.floor(thumbSz * 0.5), ty + math.floor(thumbSz * 0.5),
                Color(rarCol.r, rarCol.g, rarCol.b, unlocked and 200 or 60),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local ix = tx + thumbSz + 14
        local iy = ty
        DuckAch.drawText(view.name, "DA_Modal", ix, iy, C.cream)
        DuckAch.drawText(rar.label, "DA_Badge", ix, iy + 22,
            Color(rarCol.r, rarCol.g, rarCol.b))
        local sCol = unlocked and C.success or C.red
        DuckAch.drawText(unlocked and DuckAch.L("menu.badge_unlocked") or DuckAch.L("menu.badge_locked"), "DA_Badge",
            ix, iy + 36, sCol)

        local sepY = ty + thumbSz + 14
        fill(PAD, sepY, w - PAD * 2, 1, C.sep)

        local desc  = view.description or ""
        local maxW  = w - PAD * 2
        local dy    = sepY + 14
        local words = {}
        for word in desc:gmatch("%S+") do table.insert(words, word) end
        local line  = ""
        surface.SetFont("DA_Sub")
        for _, word in ipairs(words) do
            local test = line == "" and word or (line .. " " .. word)
            if surface.GetTextSize(test) > maxW and line ~= "" then
                DuckAch.drawText(line, "DA_Sub", PAD, dy,
                    Color(C.muted2.r, C.muted2.g, C.muted2.b))
                dy   = dy + 16
                line = word
            else
                line = test
            end
        end
        if line ~= "" then
            DuckAch.drawText(line, "DA_Sub", PAD, dy,
                Color(C.muted2.r, C.muted2.g, C.muted2.b))
            dy = dy + 16
        end
        dy = dy + 20

        if isMulti and #details > 0 then
            fill(PAD, dy, w - PAD * 2, 1, C.sep)
            dy = dy + 12

            DuckAch.drawText(DuckAch.L("menu.requirements") .. "  (" .. (prog and prog.current or 0) .. " / " .. #details .. ")",
                "DA_Badge", PAD, dy, Color(C.muted.r, C.muted.g, C.muted.b))
            dy = dy + 20

            for _, det in ipairs(details) do
                local rowCol = det.met and C.success or C.muted2
                DuckAch.drawText(det.label, "DA_Sub", PAD, dy,
                    Color(det.met and C.cream.r or C.muted2.r,
                          det.met and C.cream.g or C.muted2.g,
                          det.met and C.cream.b or C.muted2.b))
                dy = dy + 16
                local barW   = w - PAD * 2
                local filled = math.Clamp(det.current / math.max(det.needed, 1), 0, 1)
                DuckAch.roundedFill(PAD, dy, barW, 6, 3, C.border, 255)
                if filled > 0 then
                    DuckAch.roundedFill(PAD, dy, math.max(math.floor(barW * filled), 6), 6, 3, rowCol, 210)
                end
                local valStr = string.format("%.0f%s / %.0f%s", det.current, det.unit or "", det.needed, det.unit or "")
                DuckAch.drawText(valStr, "DA_Mono", PAD + barW, dy - 1,
                    Color(rowCol.r, rowCol.g, rowCol.b), TEXT_ALIGN_RIGHT)
                dy = dy + 24
            end
        elseif prog and not unlocked then
            fill(PAD, dy, w - PAD * 2, 1, C.sep)
            dy = dy + 16
            local barW   = w - PAD * 2
            local filled = math.Clamp(prog.current / math.max(prog.needed, 1), 0, 1)
            DuckAch.roundedFill(PAD, dy, barW, 6, 3, C.border, 255)
            if filled > 0 then
                DuckAch.roundedFill(PAD, dy, math.max(math.floor(barW * filled), 6), 6, 3, rarCol, 210)
            end
            DuckAch.drawText(
                prog.current .. " / " .. prog.needed .. "  (" .. math.floor(filled * 100) .. "%)",
                "DA_Mono", PAD, dy - 16,
                Color(rarCol.r, rarCol.g, rarCol.b, 200))
            dy = dy + 24
        end

        dy = dy + 8
        fill(PAD, dy, w - PAD * 2, 1, C.sep)
        dy = dy + 12
        DuckAch.drawText(
            DuckAch.L("menu.percent_have_players", pct or 0),
            "DA_Tiny", PAD, dy, Color(C.muted.r, C.muted.g, C.muted.b))

        self.DA_ContentH = dy + 24
    end

    timer.Simple(0, function()
        if IsValid(body) and body.DA_ContentH then body:SetTall(body.DA_ContentH) end
    end)
end

function DuckAch.UI.OpenMenu()
    if IsValid(_menuFrame) then _menuFrame:Close() return end

    local sw, sh  = ScrW(), ScrH()
    local W       = math.min(sw - 60, 980)
    local H       = math.min(sh - 60, 660)
    local topH    = 40
    local filterH = 36

    local frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.OnClose = function()
        _menuFrame = nil
        DuckAch.UI.CloseOverlay()
        _wrapper  = nil
        _scrollW  = 0
    end
    _menuFrame = frame

    frame.Paint = function(self, w, h)
        DuckAch.panelBG(0, 0, w, h, 0, C.bg, 255, C.border, 255, 1)
    end
    frame.btnClose:SetSize(0, 0)
    frame.btnClose.Paint = function() end
    frame.btnMinim:SetSize(0, 0)
    frame.btnMinim.Paint = function() end
    frame.btnMaxim:SetSize(0, 0)
    frame.btnMaxim.Paint = function() end

    local topBar = vgui.Create("DPanel", frame)
    topBar:SetPos(0, 0)
    topBar:SetSize(W, topH)
    topBar.Paint = function(self, w, h)
        fill(0, 0, w, h, C.panel)
        local glowA = DuckAch.pulse(1, 140, 220)
        fill(0, h - 3, w, 3, C.brand, glowA)
        fill(0, h - 1, w, 1, C.sep)

        surface.SetMaterial(DuckAch.Icons.medal)
        surface.SetDrawColor(C.brand.r, C.brand.g, C.brand.b, 255)
        surface.DrawTexturedRect(16, math.floor((h - 16) * 0.5), 16, 16)

        local total     = table.Count(DuckAch.Client.achievements)
        local nUnlocked = table.Count(DuckAch.Client.profile.unlocked or {})
        local titleText = DuckAch.L("menu.title")

        DuckAch.drawText(titleText, "DA_Title", 38, math.floor(h * 0.5),
            C.cream, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        surface.SetFont("DA_Title")
        local titleW = surface.GetTextSize(titleText)
        DuckAch.drawText(nUnlocked .. " / " .. total, "DA_Mono", 38 + titleW + 14, math.floor(h * 0.5),
            Color(C.muted2.r, C.muted2.g, C.muted2.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(W - 30, math.floor((topH - 22) * 0.5))
    closeBtn:SetSize(22, 22)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        local hov = self:IsHovered()
        DuckAch.panelBG(0, 0, w, h, 0, C.red, hov and 55 or 22, C.red, hov and 200 or 90, 1)
        DuckAch.drawText("X", "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.red.r, C.red.g, C.red.b, hov and 255 or 170),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Close() end

    local profileBtn = vgui.Create("DButton", frame)
    profileBtn:SetPos(W - 140, math.floor((topH - 26) * 0.5))
    profileBtn:SetSize(102, 26)
    profileBtn:SetText("")
    profileBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and C.accent or C.muted
        DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, 26)
        DuckAch.drawText(DuckAch.L("menu.my_profile"), "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    profileBtn.DoClick = function()
        DuckAch.UI.ShowProfileOverlay(LocalPlayer())
    end

    if LocalPlayer():IsSuperAdmin() then
        local staffBtn = vgui.Create("DButton", frame)
        staffBtn:SetPos(W - 256, math.floor((topH - 26) * 0.5))
        staffBtn:SetSize(108, 26)
        staffBtn:SetText("")
        staffBtn.Paint = function(self, w, h)
            local col = self:IsHovered() and C.amber or C.muted
            DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, 26)
            DuckAch.drawText(DuckAch.L("menu.staff_panel"), "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
                Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        staffBtn.DoClick = function()
            frame:Close()
            DuckAch.UI.OpenAdmin()
        end

        local langBtn = vgui.Create("DButton", frame)
        langBtn:SetPos(W - 368, math.floor((topH - 26) * 0.5))
        langBtn:SetSize(104, 26)
        langBtn:SetText("")
        langBtn.Paint = function(self, w, h)
            local col = self:IsHovered() and C.accent or C.muted
            DuckAch.roundedFill(0, 0, w, h, math.floor(h * 0.5), col, 26)
            DuckAch.drawText(DuckAch.L("admin.lang_button"), "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
                Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        langBtn.DoClick = function()
            frame:Close()
            DuckAch.UI.OpenLangPanel()
        end
    end

    local filterBar = vgui.Create("DPanel", frame)
    filterBar:SetPos(0, topH)
    filterBar:SetSize(W, filterH)
    filterBar.Paint = function(self, w, h)
        fill(0, 0, w, h, Color(15, 18, 28))
        fill(0, h - 1, w, 1, C.sep)
    end

    local searchWrap = vgui.Create("DPanel", filterBar)
    searchWrap:SetPos(10, 6)
    searchWrap:SetSize(200, 24)
    searchWrap.Paint = function(self, w, h)
        DuckAch.panelBG(0, 0, w, h, math.floor(h * 0.5), C.card, 255, C.border, 130, 1)
    end

    local searchEntry = vgui.Create("DTextEntry", searchWrap)
    searchEntry:SetPos(10, 3)
    searchEntry:SetSize(184, 18)
    searchEntry:SetFont("DA_Sub")
    searchEntry:SetPlaceholderText(DuckAch.L("menu.search_placeholder"))
    searchEntry.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 0)
        surface.DrawRect(0, 0, w, h)
        self:DrawTextEntryText(C.cream, C.accent, C.cream)
    end
    searchEntry.OnChange = function(self)
        _activeFilter.text = self:GetValue()
        _page = 1
        rebuildGrid()
    end

    local rarities  = { "all", "common", "uncommon", "rare", "epic", "legendary", "secret" }
    local rarLabels = {
        DuckAch.L("filter.rarity.all"), DuckAch.L("filter.rarity.common"),
        DuckAch.L("filter.rarity.uncommon"), DuckAch.L("filter.rarity.rare"),
        DuckAch.L("filter.rarity.epic"), DuckAch.L("filter.rarity.legendary"),
        DuckAch.L("filter.rarity.secret"),
    }
    local rarX      = 218

    for i, rid in ipairs(rarities) do
        local bw   = i == 1 and 50 or 72
        local rar  = rid ~= "all" and DuckAch.GetRarity(rid) or nil
        local col  = rar and rar.color or C.neutral
        local _rid = rid
        local _col = col
        local _lbl = rarLabels[i]
        local rb   = vgui.Create("DButton", filterBar)
        rb:SetPos(rarX, 6)
        rb:SetSize(bw, 24)
        rb:SetText("")
        rb.Paint = function(self, w, h)
            local active = _activeFilter.rarity == _rid
            local fillA  = active and 70 or (self:IsHovered() and 24 or 12)
            local radius = math.floor(h * 0.5)
            DuckAch.roundedFill(0, 0, w, h, radius, _col, fillA)
            DuckAch.drawText(_lbl, "DA_Badge", math.floor(w * 0.5), math.floor(h * 0.5),
                Color(_col.r, _col.g, _col.b, active and 255 or 150),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        rb.DoClick = function() _activeFilter.rarity = _rid; _page = 1; rebuildGrid() end
        rarX = rarX + bw + 4
    end

    local states      = { "all", "unlocked", "locked" }
    local stateLabels = {
        DuckAch.L("filter.state.all"), DuckAch.L("filter.state.unlocked"), DuckAch.L("filter.state.locked"),
    }
    local stateCols   = { C.neutral, C.success, C.red }
    local stateX      = rarX + 8

    for i, sid in ipairs(states) do
        local bw   = i == 1 and 50 or 66
        local _sid = sid
        local _col = stateCols[i]
        local _lbl = stateLabels[i]
        local sb   = vgui.Create("DButton", filterBar)
        sb:SetPos(stateX, 6)
        sb:SetSize(bw, 24)
        sb:SetText("")
        sb.Paint = function(self, w, h)
            local active = _activeFilter.state == _sid
            local fillA  = active and 70 or (self:IsHovered() and 24 or 12)
            local radius = math.floor(h * 0.5)
            DuckAch.roundedFill(0, 0, w, h, radius, _col, fillA)
            DuckAch.drawText(_lbl, "DA_Badge", math.floor(w * 0.5), math.floor(h * 0.5),
                Color(_col.r, _col.g, _col.b, active and 255 or 150),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        sb.DoClick = function() _activeFilter.state = _sid; _page = 1; rebuildGrid() end
        stateX = stateX + bw + 4
    end

    local pageBarH = 36
    local scroll   = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, topH + filterH)
    scroll:SetSize(W, H - topH - filterH - pageBarH)

    local sbar = scroll:GetVBar()
    sbar:SetHideButtons(true)
    sbar.Paint         = function(self, w, h) fill(0, 0, w, h, C.border) end
    sbar.btnGrip.Paint = function(self, w, h) fill(0, 0, w, h, C.accent, 90) end

    local wrapper = vgui.Create("DPanel", scroll)
    wrapper:SetSize(W, 100)
    wrapper.Paint = function() end
    _wrapper = wrapper
    _scrollW = W

    local pageBar = vgui.Create("DPanel", frame)
    pageBar:SetPos(0, H - pageBarH)
    pageBar:SetSize(W, pageBarH)
    pageBar.Paint = function(self, w, h)
        fill(0, 0, w, h, C.panel)
        fill(0, 0, w, 1, C.sep)
    end

    local _pageLabel   = ""
    local _currentPage = 1
    local _maxPages    = 1

    local prevBtn = vgui.Create("DButton", pageBar)
    prevBtn:SetPos(math.floor(W * 0.5) - 120, 6)
    prevBtn:SetSize(40, 24)
    prevBtn:SetText("")
    prevBtn.Paint = function(self, bw, bh)
        local canPrev = _currentPage > 1
        local col = canPrev and (self:IsHovered() and C.accent or C.muted2) or C.muted
        DuckAch.panelBG(0, 0, bw, bh, math.floor(bh * 0.5), col, canPrev and 22 or 10, col, canPrev and 100 or 35, 1)
        DuckAch.drawText("<", "DA_Btn", math.floor(bw * 0.5), math.floor(bh * 0.5),
            Color(col.r, col.g, col.b, canPrev and 220 or 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    prevBtn.DoClick = function()
        if _currentPage > 1 then _page = _page - 1; rebuildGrid() end
    end

    local pageInfoPanel = vgui.Create("DPanel", pageBar)
    pageInfoPanel:SetPos(math.floor(W * 0.5) - 76, 6)
    pageInfoPanel:SetSize(152, 24)
    pageInfoPanel.Paint = function(self, w, h)
        DuckAch.drawText(_pageLabel, "DA_Mono", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.muted2.r, C.muted2.g, C.muted2.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local nextBtn = vgui.Create("DButton", pageBar)
    nextBtn:SetPos(math.floor(W * 0.5) + 80, 6)
    nextBtn:SetSize(40, 24)
    nextBtn:SetText("")
    nextBtn.Paint = function(self, bw, bh)
        local canNext = _currentPage < _maxPages
        local col = canNext and (self:IsHovered() and C.accent or C.muted2) or C.muted
        DuckAch.panelBG(0, 0, bw, bh, math.floor(bh * 0.5), col, canNext and 22 or 10, col, canNext and 100 or 35, 1)
        DuckAch.drawText(">", "DA_Btn", math.floor(bw * 0.5), math.floor(bh * 0.5),
            Color(col.r, col.g, col.b, canNext and 220 or 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    nextBtn.DoClick = function()
        if _currentPage < _maxPages then _page = _page + 1; rebuildGrid() end
    end

    _onPageChange = function(page, maxPages, total)
        _currentPage = page
        _maxPages    = maxPages
        _pageLabel   = DuckAch.L("menu.page_info", page, maxPages)
        pageInfoPanel:InvalidateLayout(true)
    end

    rebuildGrid()

    hook.Add("AchievementSystem.Client.DataReady", "AchievementSystem.Menu.Refresh", function()
        if not IsValid(_wrapper) then
            hook.Remove("AchievementSystem.Client.DataReady", "AchievementSystem.Menu.Refresh")
            hook.Remove("AchievementSystem.Client.ProgressUpdated", "AchievementSystem.Menu.ProgressRefresh")
            return
        end
        rebuildGrid()
        topBar:InvalidateLayout(true)
    end)

    hook.Add("AchievementSystem.Client.ProgressUpdated", "AchievementSystem.Menu.ProgressRefresh", function()
        if not IsValid(_wrapper) then
            hook.Remove("AchievementSystem.Client.ProgressUpdated", "AchievementSystem.Menu.ProgressRefresh")
            return
        end
        rebuildGrid()
    end)
end

net.Receive("DuckAch.OpenMenu", function()
    DuckAch.UI.OpenMenu()
end)
