TOOL.Category    = "Duck Achievements"
TOOL.Name        = "Entity Picker"
TOOL.Information = { { name = "left" }, { name = "right" } }

--// Gera um entId robusto e único para qualquer entidade:
--// Entidades de mapa usam MapCreationID (estável entre restarts).
--// Props spawnados usam hash de: tempo de spawn, entIndex, owner steamid,
--// owner name, map name hash, e posição — garante unicidade mesmo sem MapCreationID.
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
        local mapId    = ent:MapCreationID()
        local isMapEnt = mapId and mapId ~= -1
        local entId    = makeEntId(ent)
        local ply      = self:GetOwner()

        ent:SetNWString("DuckAch_EntId", entId)

        --// Cor diferente: verde = entidade de mapa (persiste), laranja = prop spawnado
        if isMapEnt then
            ent:SetColor(Color(80, 220, 120))
        else
            ent:SetColor(Color(255, 160, 40))
            ply:ChatPrint("[DuckAch] WARNING: This is a spawned prop. The link will NOT persist across server restarts.")
            ply:ChatPrint("[DuckAch] Use the PermaProp addon to make it permanent before linking.")
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
    local entId = ent:GetNWString("DuckAch_EntId", "")
    local msg   = entId ~= "" and ("ID: " .. entId) or "No ID yet. Left click to set one."
    self:GetOwner():ChatPrint("[DuckAch] " .. msg)
    return true
end

if CLIENT then
    net.Receive("DuckAch.Admin.EquipPicker", function()
        local achId = net.ReadString()

        timer.Simple(0.05, function()
            RunConsoleCommand("use", "gmod_tool")
            timer.Simple(0.1, function()
                RunConsoleCommand("gmod_toolmode", "entity_picker")
                chat.AddText(
                    Color(193, 235, 233), "[DuckAch Admin] ",
                    Color(220, 220, 220), "Left click an entity to link it to achievement ",
                    Color(255, 200, 50), achId,
                    Color(220, 220, 220), ". Right click = check current ID."
                )
            end)
        end)
    end)


    language.Add("tool.entity_picker.name",  "Entity Picker (DuckAch)")
    language.Add("tool.entity_picker.desc",  "Links world entities to achievements.")
    language.Add("tool.entity_picker.left",  "Selects and links to the pending achievement")
    language.Add("tool.entity_picker.right", "Shows the entity's current EntId")
end
