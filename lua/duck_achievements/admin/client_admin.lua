DuckAch.UI = DuckAch.UI or {}

local C    = DuckAch.C
local fill = DuckAch.fillC
local out  = DuckAch.outlineC

local TRIGGER_TYPES = {
    "get_killed_by_x",
    "spawn_x_entity",
    "spawn_x_entity_y_times",
    "get_x_usergroup",
    "die_by_x_entity",
    "interact_with_x_entity",
    "get_x_killstreak",
    "get_x_killstreak_with_y_weapon",
    "say_specific_phrase",
    "reach_playtime_hours",
    "total_kills_x",
    "total_killbind_x",
    "kill_revenge_leaver",
    "kill_x_with_weapon",
    "kill_with_same_weapon",
    "headshot_airborne",
    "kill_with_low_health",
    "not_kill_or_die_x_minutes",
    "get_all_achievements",
    "first_join_hour",
    "respawn_after_x_minutes_dead",
    "kill_x_loners",
    "kill_streak_then_suicide",
    "survive_explosion_at_1hp",
    "die_by_all_present_no_retaliation",
    "complete_rarity_x",
    "noscope_360_kill",
    "multi_requirement",
}

local RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "secret" }

--// labelKey é resolvido em tempo real via DuckAch.L() nos pontos de uso
--// (não em cache aqui), então acompanha o idioma ativo/overrides.
local PARAM_FIELDS = {
    ["get_killed_by_x"]     = { { key = "steamid",  labelKey = "admin.hint.steamid_killer" } },
    ["spawn_x_entity"]      = { { key = "classname", labelKey = "admin.hint.model_path" } },
    ["spawn_x_entity_y_times"] = {
        { key = "classname", labelKey = "admin.hint.model_path" },
        { key = "times",     labelKey = "admin.hint.quantity_number" },
    },
    ["get_x_usergroup"]     = { { key = "usergroup", labelKey = "admin.hint.usergroup_name" } },
    ["die_by_x_entity"]     = { { key = "classname", labelKey = "admin.hint.classname_killer" } },
    ["interact_with_x_entity"] = { { key = "entId", labelKey = "admin.hint.entid_picker", picker = true } },
    ["get_x_killstreak"]    = { { key = "kills", labelKey = "admin.hint.kills_needed" } },
    ["get_x_killstreak_with_y_weapon"] = {
        { key = "kills",  labelKey = "admin.hint.kills_number" },
        { key = "weapon", labelKey = "admin.hint.weapon_classname" },
    },
    ["say_specific_phrase"] = {
        { key = "phrase",        labelKey = "admin.hint.exact_phrase" },
        { key = "caseSensitive", labelKey = "admin.hint.case_sensitive" },
    },
    ["reach_playtime_hours"]     = { { key = "hours",   labelKey = "admin.hint.playtime_hours" } },
    ["total_kills_x"]            = { { key = "kills",   labelKey = "admin.hint.total_kills" } },
    ["total_killbind_x"]         = { { key = "count",   labelKey = "admin.hint.total_killbinds" } },
    ["kill_x_with_weapon"]       = {
        { key = "kills",  labelKey = "admin.hint.total_kills" },
        { key = "weapon", labelKey = "admin.hint.weapon_classname_ex" },
    },
    ["not_kill_or_die_x_minutes"] = { { key = "minutes", labelKey = "admin.hint.minutes_no_kill_die" } },
    ["kill_x_loners"]            = { { key = "kills",   labelKey = "admin.hint.total_kills_loners" } },
    ["respawn_after_x_minutes_dead"] = { { key = "minutes", labelKey = "admin.hint.minutes_dead" } },
    ["first_join_hour"]          = { { key = "hours",   labelKey = "admin.hint.hours_allowed" } },
    ["complete_rarity_x"]        = { { key = "rarity",  labelKey = "admin.rarity_label", options = RARITIES } },
}

local _adminOpen    = false
local _adminList    = {}
local _formSnapshot = nil
local _adminFrame   = nil
local _webhookList  = {}

local function isSuperAdmin()
    return LocalPlayer():IsSuperAdmin()
end

local function labelPanel(parent, text, x, y, w, h)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h or 16)
    p.Paint = function(self, pw, ph)
        DuckAch.drawText(text, "DA_Badge", 0, math.floor(ph * 0.5),
            Color(C.muted.r, C.muted.g, C.muted.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return p
end

local function styledEntry(parent, x, y, w, h, placeholder)
    local wrap = vgui.Create("DPanel", parent)
    wrap:SetPos(x, y)
    wrap:SetSize(w, h or 26)
    wrap.Paint = function(self, pw, ph)
        fill(0, 0, pw, ph, C.card)
        out(0, 0, pw, ph, C.border, 120)
    end
    local entry = vgui.Create("DTextEntry", wrap)
    entry:SetPos(4, 3)
    entry:SetSize(w - 8, (h or 26) - 6)
    entry:SetPlaceholderText(placeholder or "")
    entry:SetFont("DA_Sub")
    entry.Paint = function(self, ew, eh)
        surface.SetDrawColor(0, 0, 0, 0)
        surface.DrawRect(0, 0, ew, eh)
        self:DrawTextEntryText(C.cream, C.accent, C.cream)
    end
    return entry, wrap
end

local function styledCombo(parent, x, y, w, h)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetPos(x, y)
    combo:SetSize(w, h or 26)
    combo:SetFont("DA_Sub")
    combo.Paint = function(self, cw, ch)
        fill(0, 0, cw, ch, C.card)
        out(0, 0, cw, ch, C.border, 120)
        self:DrawTextEntryText(C.cream, C.accent, C.cream)
        DuckAch.drawText("▾", "DA_Sub", cw - 14, math.floor(ch * 0.5),
            Color(C.muted.r, C.muted.g, C.muted.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return combo
end

local function actionBtn(parent, x, y, w, h, label, col, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.Paint = function(self, bw, bh)
        local c = self:IsHovered() and col or C.muted
        fill(0, 0, bw, bh, c, 22)
        out(0, 0, bw, bh, c, 100)
        DuckAch.drawText(label, "DA_Btn", math.floor(bw * 0.5), math.floor(bh * 0.5),
            Color(c.r, c.g, c.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick or function() end
    return btn
end

local function buildEditForm(parent, existingDef, onSave)
    local yOff         = 0
    local fields       = {}
    local paramEntries = {}
    local _pickedEntId = (existingDef and existingDef.params and existingDef.params.entId) or nil
    local _reanchorSave = nil  --// setado depois que anchSave existir, usado por buildSubRequirementUI

    local function nextY(h) yOff = yOff + h end

    labelPanel(parent, DuckAch.L("admin.id_label"), 0, yOff, 340) nextY(18)
    fields.id, _ = styledEntry(parent, 0, yOff, 340, 26, "ex: killstreak_5")
    if existingDef then fields.id:SetValue(existingDef.id or "") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.name_label"), 0, yOff, 340) nextY(18)
    fields.name, _ = styledEntry(parent, 0, yOff, 340, 26, DuckAch.L("admin.name_placeholder"))
    if existingDef then fields.name:SetValue(existingDef.name or "") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.desc_label"), 0, yOff, 340) nextY(18)
    fields.desc, _ = styledEntry(parent, 0, yOff, 340, 26, DuckAch.L("admin.desc_placeholder"))
    if existingDef then fields.desc:SetValue(existingDef.description or "") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.thumb_label"), 0, yOff, 340) nextY(18)
    fields.thumb, _ = styledEntry(parent, 0, yOff, 340, 26, "https://i.imgur.com/...")
    if existingDef then fields.thumb:SetValue(existingDef.thumbnail or "") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.rarity_label"), 0, yOff, 340) nextY(18)
    fields.rarity = styledCombo(parent, 0, yOff, 200)
    for _, r in ipairs(RARITIES) do fields.rarity:AddChoice(r) end
    if existingDef then fields.rarity:SetValue(existingDef.rarity or "common") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.secret_label"), 0, yOff, 340) nextY(18)
    fields.secret = styledCombo(parent, 0, yOff, 120)
    fields.secret:AddChoice("false") fields.secret:AddChoice("true")
    if existingDef then fields.secret:SetValue(existingDef.secret and "true" or "false") end
    nextY(32)

    labelPanel(parent, DuckAch.L("admin.trigger_type_label"), 0, yOff, 340) nextY(18)
    fields.triggerType = styledCombo(parent, 0, yOff, 340)
    for _, t in ipairs(TRIGGER_TYPES) do fields.triggerType:AddChoice(t) end
    nextY(32)

    local paramContainer = vgui.Create("DPanel", parent)
    paramContainer:SetPos(0, yOff)
    paramContainer:SetSize(340, 10)
    paramContainer.Paint = function() end

    --// ── Estado dos sub-requisitos (apenas para triggerType = multi_requirement) ──
    --// Cada entrada: { type = "total_kills_x", params = { kills = 5000 }, label = "..." }
    local SUB_REQ_TYPES = {
        "reach_playtime_hours", "total_kills_x", "total_killbind_x",
        "spawn_x_entity_y_times", "kill_x_with_weapon",
    }
    local SUB_REQ_PARAM_FIELDS = {
        ["reach_playtime_hours"]   = { { key = "hours",     labelKey = "admin.hint.hours_short" } },
        ["total_kills_x"]          = { { key = "kills",     labelKey = "admin.hint.total_kills" } },
        ["total_killbind_x"]       = { { key = "count",     labelKey = "admin.hint.total_killbinds" } },
        ["spawn_x_entity_y_times"] = { { key = "classname",  labelKey = "admin.hint.model_path_any" },
                                        { key = "times",      labelKey = "admin.hint.quantity" } },
        ["kill_x_with_weapon"]     = { { key = "weapon",     labelKey = "admin.hint.weapon_classname" },
                                        { key = "kills",      labelKey = "admin.hint.quantity" } },
    }

    local _subRequirements = (existingDef and existingDef.params and existingDef.params.requirements) or {}
    --// Deep copy pra não mutar o objeto original antes de salvar
    do
        local copy = {}
        for _, r in ipairs(_subRequirements) do
            local pcopy = {}
            for k, v in pairs(r.params or {}) do pcopy[k] = v end
            table.insert(copy, { type = r.type, params = pcopy })
        end
        _subRequirements = copy
    end

    local function gatherDef()
        local params = {}
        for key, entry in pairs(paramEntries) do
            local val = entry:GetValue()
            if key == "kills" or key == "times" or key == "total" or key == "hours"
            or key == "count" or key == "members" or key == "minutes" then
                params[key] = tonumber(val) or 0
            elseif key == "caseSensitive" then
                params[key] = (val == "true")
            elseif key == "entId" then
                params[key] = (val ~= "" and val) or _pickedEntId or ""
            else
                params[key] = val
            end
        end

        if fields.triggerType:GetValue() == "multi_requirement" then
            params.requirements = _subRequirements
        end

        return {
            id          = fields.id:GetValue(),
            name        = fields.name:GetValue(),
            description = fields.desc:GetValue(),
            thumbnail   = fields.thumb:GetValue() ~= "" and fields.thumb:GetValue() or nil,
            rarity      = fields.rarity:GetValue(),
            secret      = fields.secret:GetValue() == "true",
            triggerType = fields.triggerType:GetValue(),
            params      = params,
        }
    end

    --// UI especial para multi_requirement: lista de sub-requisitos repetível
    local function buildSubRequirementUI()
        paramContainer:Clear()
        paramEntries = {}
        local py = 0

        labelPanel(paramContainer, DuckAch.L("admin.sub_requirements"), 0, py, 340)
        py = py + 22

        for idx, sub in ipairs(_subRequirements) do
            local _idx = idx
            local subFieldsForHeight = SUB_REQ_PARAM_FIELDS[sub.type] or {}
            --// header (combo + remover) + N campos (label + entry + respiro) + padding inferior
            local HEADER_H    = 38
            local FIELD_H     = 52   --// 16 (label) + 26 (entry) + 10 (respiro entre campos)
            local BOTTOM_PAD  = 14
            local rowH = HEADER_H + (#subFieldsForHeight * FIELD_H) + BOTTOM_PAD

            local row = vgui.Create("DPanel", paramContainer)
            row:SetPos(0, py)
            row:SetSize(340, rowH)
            row.Paint = function(self, w, h)
                fill(0, 0, w, h, C.card, 60)
                out(0, 0, w, h, C.amber, 60)
            end

            local typeCombo = styledCombo(row, 6, 6, 220, 22)
            for _, t in ipairs(SUB_REQ_TYPES) do typeCombo:AddChoice(t) end
            typeCombo:SetValue(sub.type)
            typeCombo.OnSelect = function(_, _, val)
                _subRequirements[_idx].type   = val
                _subRequirements[_idx].params = {}
                buildSubRequirementUI()
            end

            actionBtn(row, 232, 6, 102, 22, DuckAch.L("admin.remove"), C.red, function()
                table.remove(_subRequirements, _idx)
                buildSubRequirementUI()
            end)

            local subFields = SUB_REQ_PARAM_FIELDS[sub.type] or {}
            local subY = HEADER_H
            for _, sf in ipairs(subFields) do
                labelPanel(row, DuckAch.L(sf.labelKey), 6, subY, 328, 14)
                subY = subY + 18
                local sEntry, _ = styledEntry(row, 6, subY, 328, 26)
                if sub.params[sf.key] ~= nil then
                    sEntry:SetValue(tostring(sub.params[sf.key]))
                end
                sEntry.OnChange = function(self)
                    local v = self:GetValue()
                    if sf.key == "kills" or sf.key == "times" or sf.key == "count" then
                        _subRequirements[_idx].params[sf.key] = tonumber(v) or 0
                    else
                        _subRequirements[_idx].params[sf.key] = v
                    end
                end
                subY = subY + FIELD_H - 18
            end

            py = py + rowH + 14
        end

        actionBtn(paramContainer, 0, py, 340, 28, DuckAch.L("admin.add_sub_requirement"), C.success, function()
            table.insert(_subRequirements, { type = SUB_REQ_TYPES[1], params = {} })
            buildSubRequirementUI()
        end)
        py = py + 36

        paramContainer:SetTall(math.max(py, 10))
        parent:SetTall(yOff + py + 60)
        if _reanchorSave then _reanchorSave() end
    end

    local function rebuildParams(triggerType)
        if triggerType == "multi_requirement" then
            buildSubRequirementUI()
            return
        end

        paramContainer:Clear()
        paramEntries = {}
        local defs = PARAM_FIELDS[triggerType] or {}
        local py   = 0

        for _, pd in ipairs(defs) do
            labelPanel(paramContainer, DuckAch.L(pd.labelKey), 0, py, 340) py = py + 18

            local entry
            if pd.options then
                entry = styledCombo(paramContainer, 0, py, 340)
                for _, opt in ipairs(pd.options) do entry:AddChoice(opt) end
                entry:SetValue((existingDef and existingDef.params and existingDef.params[pd.key]) or pd.options[1])
            else
                entry, _ = styledEntry(paramContainer, 0, py, 340, 26)
                if existingDef and existingDef.params then
                    local val = existingDef.params[pd.key]
                    if val ~= nil then
                        entry:SetValue(type(val) == "table" and table.concat(val, ",") or tostring(val))
                    end
                end
            end

            paramEntries[pd.key] = entry
            py = py + 32

            if pd.picker then
                local entEntry = entry
                actionBtn(paramContainer, 0, py, 280, 26, DuckAch.L("admin.select_entity_world"), C.amber, function()
                    local achId = fields.id:GetValue()
                    if achId == "" then
                        chat.AddText(Color(255, 100, 100), DuckAch.L("admin.set_id_first"))
                        return
                    end
                    _formSnapshot = gatherDef()
                    if IsValid(_adminFrame) then _adminFrame:Close() end
                    net.Start("DuckAch.Admin.SetEntId")
                        net.WriteString(achId)
                    net.SendToServer()
                end)
                py = py + 34

                hook.Add("AchievementSystem.Admin.PickerDone", "DuckAch.Form.PickerFill_" .. tostring(parent), function(achId, entId)
                    _pickedEntId = entId
                    if IsValid(entEntry) then entEntry:SetValue(entId) end
                end)
            end
        end

        paramContainer:SetTall(math.max(py, 10))
        parent:SetTall(yOff + py + 60)
    end

    local saveBtn = actionBtn(parent, 0, 0, 200, 30, DuckAch.L("admin.save_achievement"), C.success, function()
        local def = gatherDef()
        if def.id == "" or def.name == "" then
            chat.AddText(Color(255, 100, 100), DuckAch.L("admin.id_name_required"))
            return
        end
        net.Start("DuckAch.Admin.Save")
            net.WriteString(util.TableToJSON(def))
        net.SendToServer()
        if onSave then onSave() end
    end)

    local function anchSave()
        local py = paramContainer:GetY() + paramContainer:GetTall() + 10
        saveBtn:SetPos(0, py)
        parent:SetTall(py + 40)
    end
    _reanchorSave = anchSave

    local origRebuild = rebuildParams
    rebuildParams = function(t)
        origRebuild(t)
        timer.Simple(0, anchSave)
    end

    local initialType = (existingDef and existingDef.triggerType) or TRIGGER_TYPES[1]
    fields.triggerType:SetValue(initialType)
    rebuildParams(initialType)
    fields.triggerType.OnSelect = function(_, _, val) rebuildParams(val) end

    timer.Simple(0, anchSave)
end

local function buildAdminList(listPanel, onEdit)
    listPanel:Clear()
    local lw   = listPanel:GetWide()
    local rowH = 56
    local gap  = 4
    local btnW = 46
    local btnH = 24
    local y    = 0

    local sorted = {}
    for _, def in pairs(_adminList) do table.insert(sorted, def) end
    table.sort(sorted, function(a, b) return a.id < b.id end)

    for _, def in ipairs(sorted) do
        local rar    = DuckAch.GetRarity(def.rarity or "common")
        local rarCol = rar.color
        local _def   = def

        local row = vgui.Create("DPanel", listPanel)
        row:SetPos(0, y)
        row:SetSize(lw, rowH)
        row.Paint = function(self, w, h)
            fill(0, 0, w, h, C.card)
            fill(0, 0, 3, h, rarCol, 220)
            out(0, 0, w, h, C.border, 50)
            DuckAch.drawText(_def.id, "DA_Sub", 12, 8, C.cream)
            DuckAch.drawText(_def.triggerType or "?", "DA_Tiny", 12, 24,
                Color(C.muted.r, C.muted.g, C.muted.b))
            DuckAch.drawText(rar.label, "DA_Badge", 12, 38,
                Color(rarCol.r, rarCol.g, rarCol.b))
        end

        local bx1 = lw - (btnW * 2 + 4 + 8)
        local bx2 = lw - (btnW + 8)
        local by  = math.floor((rowH - btnH) * 0.5)

        actionBtn(row, bx1, by, btnW, btnH, DuckAch.L("admin.edit"), C.accent, function() onEdit(_def) end)
        actionBtn(row, bx2, by, btnW, btnH, DuckAch.L("admin.delete_short"), C.red, function()
            net.Start("DuckAch.Admin.Delete")
                net.WriteString(_def.id)
            net.SendToServer()
        end)

        y = y + rowH + gap
    end
    listPanel:SetTall(math.max(y, 1))
end

local _webhookPanel = nil
local _webhookListPanel = nil

local function formatWebhookTimestamp(ts)
    if not ts or ts == 0 then return "?" end
    return os.date("%Y-%m-%d %H:%M:%S", ts)
end

local function wrapTextLines(text, font, maxW)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines = {}
    local cur   = ""
    for _, word in ipairs(words) do
        local test = cur == "" and word or (cur .. " " .. word)
        local tw = surface.GetTextSize(test)
        if tw > maxW and cur ~= "" then
            table.insert(lines, cur)
            cur = word
        else
            cur = test
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return lines
end

local function buildWebhookCards()
    if not IsValid(_webhookListPanel) then return end
    _webhookListPanel:Clear()

    local lw   = _webhookListPanel:GetWide()
    local rowH = 62
    local gap  = 6
    local y    = 0

    if #_webhookList == 0 then
        local empty = vgui.Create("DPanel", _webhookListPanel)
        empty:SetPos(0, 0)
        empty:SetSize(lw, 28)
        empty.Paint = function(self, w, h)
            DuckAch.drawText(DuckAch.L("admin.webhook_empty"), "DA_Sub", 0, 0, C.muted)
        end
        _webhookListPanel:SetTall(28)
        return
    end

    for _, wh in ipairs(_webhookList) do
        local _wh = wh
        local card = vgui.Create("DPanel", _webhookListPanel)
        card:SetPos(0, y)
        card:SetSize(lw, rowH)
        card.Paint = function(self, w, h)
            fill(0, 0, w, h, C.card)
            fill(0, 0, 3, h, _wh.enabled and C.success or C.muted, 220)
            out(0, 0, w, h, C.border, 60)

            local statusCol = _wh.enabled and C.success or C.muted
            DuckAch.drawText(_wh.enabled and DuckAch.L("admin.webhook_active") or DuckAch.L("admin.webhook_inactive"),
                "DA_Badge", 12, 8, statusCol)

            DuckAch.drawText(string.format(DuckAch.L("admin.webhook_added_by"), _wh.createdByNick or "?"),
                "DA_Sub", 12, 22, C.cream)
            DuckAch.drawText(
                (_wh.createdBySteamID or "?") .. "  ·  " .. formatWebhookTimestamp(_wh.createdAt),
                "DA_Tiny", 12, 40, C.muted)
        end

        local btnW, btnH = 84, 22
        local toggleBtn = actionBtn(card, lw - (btnW * 2 + 4 + 10), math.floor((rowH - btnH) * 0.5), btnW, btnH,
            _wh.enabled and DuckAch.L("admin.webhook_deactivate") or DuckAch.L("admin.webhook_activate"),
            _wh.enabled and C.muted or C.success, function()
                net.Start("DuckAch.Admin.Webhook.SetEnabled")
                    net.WriteString(_wh.id)
                    net.WriteBool(not _wh.enabled)
                net.SendToServer()
            end)

        local deleteBtn = actionBtn(card, lw - (btnW + 10), math.floor((rowH - btnH) * 0.5), btnW, btnH,
            DuckAch.L("admin.webhook_delete"), C.red, function()
                Derma_Query(DuckAch.L("admin.webhook_delete_confirm"), DuckAch.L("admin.webhook_title"),
                    "Yes", function()
                        net.Start("DuckAch.Admin.Webhook.Remove")
                            net.WriteString(_wh.id)
                        net.SendToServer()
                    end, "Cancel", function() end)
            end)

        y = y + rowH + gap
    end
    _webhookListPanel:SetTall(math.max(y, 1))
end

local function openWebhookSettings()
    if IsValid(_webhookPanel) then _webhookPanel:Close() end

    local W, H = 420, 480
    local win = vgui.Create("DFrame")
    win:SetSize(W, H)
    win:Center()
    win:SetTitle("")
    win:SetDraggable(true)
    win:MakePopup()
    win.btnClose:SetSize(0, 0)
    win.btnClose.Paint = function() end
    win.btnMinim:SetSize(0, 0)
    win.btnMinim.Paint = function() end
    win.btnMaxim:SetSize(0, 0)
    win.btnMaxim.Paint = function() end
    _webhookPanel = win

    win.Paint = function(self, w, h)
        fill(0, 0, w, h, C.bg)
        fill(0, 0, w, 3, C.amber, 200)
        out(0, 0, w, h, C.border)
        DuckAch.drawText(DuckAch.L("admin.webhook_title"), "DA_Title", 14, 14, C.amber)
    end

    local closeBtn = vgui.Create("DButton", win)
    closeBtn:SetPos(W - 28, 8)
    closeBtn:SetSize(20, 20) closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then fill(0, 0, w, h, C.red, 60) end
        out(0, 0, w, h, C.red, self:IsHovered() and 180 or 70)
        DuckAch.drawText("✕", "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.red.r, C.red.g, C.red.b, self:IsHovered() and 255 or 160),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() win:Close() end

    local addLabel = vgui.Create("DPanel", win)
    addLabel:SetPos(14, 40) addLabel:SetSize(W - 28, 16)
    addLabel.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("admin.webhook_add_label"), "DA_Sub", 0, 0, C.cream)
    end

    local urlEntry = styledEntry(win, 14, 60, W - 28 - 76, 26, DuckAch.L("admin.webhook_url_placeholder"))

    local addBtn = actionBtn(win, W - 14 - 68, 60, 68, 26, DuckAch.L("admin.webhook_add"), C.success, function()
        local v = urlEntry:GetValue():Trim()
        if v == "" then return end
        net.Start("DuckAch.Admin.Webhook.Add")
            net.WriteString(v)
        net.SendToServer()
        urlEntry:SetValue("")
    end)

    local urlHint = vgui.Create("DPanel", win)
    urlHint:SetPos(14, 92) urlHint:SetSize(W - 28, 32)
    urlHint.Paint = function(self, w, h)
        local lines = wrapTextLines(DuckAch.L("admin.webhook_url_hint"), "DA_Tiny", w)
        for i, line in ipairs(lines) do
            DuckAch.drawText(line, "DA_Tiny", 0, (i - 1) * 14, C.muted)
        end
    end

    local hintPnl = vgui.Create("DPanel", win)
    hintPnl:SetPos(14, 128) hintPnl:SetSize(W - 28, 16)
    hintPnl.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("admin.webhook_requires_reqwest"), "DA_Tiny", 0, 0, C.muted)
    end

    local listLabel = vgui.Create("DPanel", win)
    listLabel:SetPos(14, 152) listLabel:SetSize(W - 28, 16)
    listLabel.Paint = function(self, w, h)
        DuckAch.drawText(DuckAch.L("admin.webhook_list_label"), "DA_Sub", 0, 0, C.cream)
    end

    local scroll = vgui.Create("DScrollPanel", win)
    scroll:SetPos(14, 174)
    scroll:SetSize(W - 28, H - 174 - 14)
    _webhookListPanel = scroll
    buildWebhookCards()

    local hookName = "AchievementSystem.Admin.WebhookPanel_" .. tostring(win)
    hook.Add("AchievementSystem.Admin.WebhookListUpdated", hookName, function()
        if not IsValid(win) then
            hook.Remove("AchievementSystem.Admin.WebhookListUpdated", hookName)
            hook.Remove("AchievementSystem.Admin.WebhookActionResult", hookName)
            return
        end
        buildWebhookCards()
    end)
    hook.Add("AchievementSystem.Admin.WebhookActionResult", hookName, function(ok, err)
        if not IsValid(win) then return end
        if not ok then
            local msg = err == "invalid_url" and DuckAch.L("admin.webhook_invalid_url") or DuckAch.L("admin.webhook_action_failed")
            Derma_Message(msg, DuckAch.L("admin.webhook_title"), "OK")
        end
    end)

    net.Start("DuckAch.Admin.Webhook.RequestList")
    net.SendToServer()
end

function DuckAch.UI.OpenAdmin()
    if not isSuperAdmin() then return end
    if _adminOpen then return end
    _adminOpen = true

    local sw, sh = ScrW(), ScrH()
    local W      = math.min(sw - 40, 960)
    local H      = math.min(sh - 40, 660)
    local listW  = 330
    local divX   = listW + 16
    local formX  = divX + 9
    local formW  = W - formX - 8
    local topY   = 38
    local botH   = 42

    local frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.OnClose = function()
        _adminOpen = false
        if _adminFrame == frame then _adminFrame = nil end
    end
    _adminFrame = frame

    frame.Paint = function(self, w, h)
        fill(0, 0, w, h, C.bg)
        fill(0, 0, w, 3, C.amber, 200)
        out(0, 0, w, h, C.border)
        fill(0, 3, w, topY - 3, C.panel)
        fill(0, topY - 1, w, 1, C.sep)
        DuckAch.drawText(DuckAch.L("admin.panel_title"), "DA_Title", 16, math.floor(topY * 0.5),
            C.amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        fill(divX, topY, 1, h - topY, C.sep)
    end

    frame.btnClose:SetSize(0, 0)
    frame.btnClose.Paint = function() end
    frame.btnMinim:SetSize(0, 0)
    frame.btnMinim.Paint = function() end
    frame.btnMaxim:SetSize(0, 0)
    frame.btnMaxim.Paint = function() end

    local adminClose = vgui.Create("DButton", frame)
    adminClose:SetPos(W - 28, math.floor((topY - 20) * 0.5))
    adminClose:SetSize(20, 20) adminClose:SetText("")
    adminClose.Paint = function(self, w, h)
        if self:IsHovered() then fill(0, 0, w, h, C.red, 60) end
        out(0, 0, w, h, C.red, self:IsHovered() and 180 or 70)
        DuckAch.drawText("✕", "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(C.red.r, C.red.g, C.red.b, self:IsHovered() and 255 or 160),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    adminClose.DoClick = function() frame:Close() end

    local webhookBtn = vgui.Create("DButton", frame)
    webhookBtn:SetPos(W - 120, math.floor((topY - 20) * 0.5))
    webhookBtn:SetSize(88, 20) webhookBtn:SetText("")
    webhookBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and C.accent or C.muted
        fill(0, 0, w, h, col, 18)
        out(0, 0, w, h, col, 90)
        DuckAch.drawText(DuckAch.L("admin.webhook_button"), "DA_Btn", math.floor(w * 0.5), math.floor(h * 0.5),
            Color(col.r, col.g, col.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    webhookBtn.DoClick = function() openWebhookSettings() end

    local listScroll = vgui.Create("DScrollPanel", frame)
    listScroll:SetPos(8, topY) listScroll:SetSize(listW, H - topY - botH)
    local sbar = listScroll:GetVBar()
    sbar:SetHideButtons(true)
    sbar.Paint = function(self, w, h) fill(0, 0, w, h, C.border) end
    sbar.btnGrip.Paint = function(self, w, h) fill(0, 0, w, h, C.amber, 90) end

    local listInner = vgui.Create("DPanel", listScroll)
    listInner:SetSize(listW - 8, 100) listInner.Paint = function() end

    local newBtn = actionBtn(frame, 8, H - botH + 7, listW, 28, DuckAch.L("admin.new_achievement"), C.success, function() end)

    local formScroll = vgui.Create("DScrollPanel", frame)
    formScroll:SetPos(formX, topY) formScroll:SetSize(formW, H - topY)
    local sbar2 = formScroll:GetVBar()
    sbar2:SetHideButtons(true)
    sbar2.Paint = function(self, w, h) fill(0, 0, w, h, C.border) end
    sbar2.btnGrip.Paint = function(self, w, h) fill(0, 0, w, h, C.amber, 90) end

    local formInner = vgui.Create("DPanel", formScroll)
    formInner:SetPos(12, 12) formInner:SetSize(formW - 24, 900)
    formInner.Paint = function() end

    local function requestList()
        net.Start("DuckAch.Admin.RequestList") net.SendToServer()
    end

    local function openEdit(def)
        formInner:Clear()
        buildEditForm(formInner, def, function() timer.Simple(0.4, requestList) end)
    end

    local function openNew()
        formInner:Clear()
        buildEditForm(formInner, nil, function() timer.Simple(0.4, requestList) end)
    end

    newBtn.DoClick = openNew

    hook.Add("AchievementSystem.Admin.ListUpdated", "AchievementSystem.Admin.RefreshOpen", function()
        if not IsValid(frame) then
            hook.Remove("AchievementSystem.Admin.ListUpdated", "AchievementSystem.Admin.RefreshOpen")
            hook.Remove("AchievementSystem.Admin.PickerDone", "AchievementSystem.Admin.PickerOpen")
            return
        end
        buildAdminList(listInner, openEdit)
    end)

    hook.Add("AchievementSystem.Admin.PickerDone", "AchievementSystem.Admin.PickerOpen", function(achId, entId)
        if IsValid(frame) then
            local def = _formSnapshot or _adminList[achId] or { id = achId }
            def.params = def.params or {}
            def.params.entId = entId
            _formSnapshot = nil
            local cached = _adminList[achId]
            if cached then cached.params = cached.params or {}; cached.params.entId = entId end
            openEdit(def)
            return
        end

        _adminOpen = false
        DuckAch.UI.OpenAdmin()
        timer.Simple(0.1, function()
            hook.Run("AchievementSystem.Admin.PickerDone", achId, entId)
        end)
    end)

    requestList()
    openNew()
end

net.Receive("DuckAch.Admin.SendList", function()
    _adminList = util.JSONToTable(net.ReadString()) or {}
    hook.Run("AchievementSystem.Admin.ListUpdated")
end)

net.Receive("DuckAch.Admin.PickerResult", function()
    hook.Run("AchievementSystem.Admin.PickerDone", net.ReadString(), net.ReadString())
end)

net.Receive("DuckAch.OpenAdmin", function()
    DuckAch.UI.OpenAdmin()
end)

net.Receive("DuckAch.Admin.Webhook.List", function()
    local count = net.ReadUInt(16)
    local list = {}
    for i = 1, count do
        table.insert(list, {
            id               = net.ReadString(),
            enabled          = net.ReadBool(),
            createdByNick    = net.ReadString(),
            createdBySteamID = net.ReadString(),
            createdAt        = net.ReadUInt(32),
        })
    end
    _webhookList = list
    hook.Run("AchievementSystem.Admin.WebhookListUpdated")
end)

net.Receive("DuckAch.Admin.Webhook.ActionResult", function()
    local ok  = net.ReadBool()
    local err = net.ReadString()
    hook.Run("AchievementSystem.Admin.WebhookActionResult", ok, err ~= "" and err or nil)
end)
