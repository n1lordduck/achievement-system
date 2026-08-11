TOOL.Category    = "Duck Achievements"
TOOL.Name        = "Entity Picker"
TOOL.Information = { { name = "left" }, { name = "right" } }

--// Admin-only: links world entities to achievement definitions and to
--// marked_entities.txt persistence. Never let a non-superadmin trigger this.
local function isSuperAdmin(ply)
    for _, g in ipairs(DuckAch.Config.SuperadminGroups) do
        if ply:IsUserGroup(g) or ply:IsSuperAdmin() then return true end
    end
    return false
end

--// Generates a robust, unique entId for any entity:
--// Map entities use MapCreationID (stable across restarts).
--// Spawned props use a hash of: spawn time, entIndex, owner steamid,
--// owner name, map name hash, and position - guarantees uniqueness even without a MapCreationID.
local function makeEntId(ent)
    local mapId = ent:MapCreationID()
    if mapId and mapId ~= -1 then
        return "map_" .. game.GetMap() .. "_" .. tostring(mapId)
    end

    local owner    = ent.CPPIGetOwner and ent:CPPIGetOwner()
    local ownerSid = IsValid(owner) and owner:SteamID() or "world"
    local ownerNm  = IsValid(owner) and owner:Name() or "world"
    local pos      = ent:GetPos()
    local posStr   = string.format("%.0f_%.0f_%.0f", pos.x, pos.y, pos.z)
    local mapHash  = util.CRC(game.GetMap())
    local spawnT   = string.format("%.4f", SysTime())
    local entIdx   = tostring(ent:EntIndex())

    local raw = table.concat({ spawnT, entIdx, ownerSid, ownerNm, mapHash, posStr }, "|")
    return "prop_" .. util.CRC(raw)
end

function TOOL:LeftClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:IsPlayer() then return false end

    if SERVER then
        local ply = self:GetOwner()
        if not isSuperAdmin(ply) then
            ply:ChatPrint(DuckAch.LFor(ply, "admin.picker_no_permission"))
            return false
        end

        local mapId    = ent:MapCreationID()
        local isMapEnt = mapId and mapId ~= -1
        local entId    = makeEntId(ent)

        ent:SetNWString("DuckAch_EntId", entId)

        --// Different color: green = map entity (persists), orange = spawned prop
        if isMapEnt then
            ent:SetColor(Color(80, 220, 120))
        else
            ent:SetColor(Color(255, 160, 40))
            ply:ChatPrint(DuckAch.LFor(ply, "admin.picker_warning_prop"))
            ply:ChatPrint(DuckAch.LFor(ply, "admin.picker_warning_permaprops"))
        end

        timer.Simple(2, function()
            if IsValid(ent) then ent:SetColor(Color(255, 255, 255)) end
        end)

        hook.Run("DuckAch.Admin.PickerSelected", ply, ent, entId)

        timer.Simple(0.15, function()
            if IsValid(ply) then ply:ConCommand("lastinv") end
        end)
    end

    return true
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or not SERVER then return false end
    local ply = self:GetOwner()
    if not isSuperAdmin(ply) then
        ply:ChatPrint(DuckAch.LFor(ply, "admin.picker_no_permission"))
        return false
    end

    local entId = ent:GetNWString("DuckAch_EntId", "")
    local msg   = entId ~= "" and DuckAch.LFor(ply, "admin.picker_id_known", entId) or DuckAch.LFor(ply, "admin.picker_id_unknown")
    ply:ChatPrint(msg)
    return true
end

if CLIENT then
    net.Receive("DuckAch.Admin.EquipPicker", function()
        local achId = net.ReadString()

        timer.Simple(0.05, function()
            RunConsoleCommand("use", "gmod_tool")
            timer.Simple(0.1, function()
                RunConsoleCommand("gmod_toolmode", "entity_picker")

                local template       = DuckAch.L("admin.picker_link_prompt")
                local before, after  = template:match("^(.-)%%s(.*)$")
                chat.AddText(
                    Color(220, 220, 220), before or template,
                    Color(255, 200, 50), achId,
                    Color(220, 220, 220), after or ""
                )
            end)
        end)
    end)


    language.Add("tool.entity_picker.name",  "Entity Picker (DuckAch)")
    language.Add("tool.entity_picker.desc",  "Links world entities to achievements.")
    language.Add("tool.entity_picker.left",  "Selects and links to the pending achievement")
    language.Add("tool.entity_picker.right", "Shows the entity's current EntId")
end
