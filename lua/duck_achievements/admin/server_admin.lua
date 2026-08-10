DuckAch.Admin = {}

local customFile    = DuckAch.Config.DataDir .. "custom_achievements.txt"
local _pickerPending = {}

function DuckAch.Admin.GetSerializedList()
    local out = {}
    for id, ach in pairs(DuckAch.Registry.GetAll()) do
        out[id] = {
            id          = ach.id,
            name        = ach.name,
            description = ach.description,
            rarity      = ach.rarity,
            thumbnail   = ach.thumbnail,
            secret      = ach.secret,
            triggerType = ach.triggerType,
            params      = ach.params,
        }
    end
    return out
end

function DuckAch.Admin.PersistCustomAchievements()
    if not file.IsDir(DuckAch.Config.DataDir, "DATA") then
        file.CreateDir(DuckAch.Config.DataDir)
    end
    file.Write(customFile, util.TableToJSON(DuckAch.Admin.GetSerializedList(), true))
    DuckAchLogger.debug("Achievements saved.")
end

function DuckAch.Admin.LoadCustomAchievements()
    if not file.Exists(customFile, "DATA") then return end
    local raw = file.Read(customFile, "DATA")
    if not raw or raw == "" then return end
    local data = util.JSONToTable(raw)
    if not data then return end
    for _, def in pairs(data) do
        DuckAch.Registry.Register(def)
    end
    DuckAchLogger.info("Custom achievements loaded.")
end

--// Inicia picker: equipa a stool no jogador e aguarda ele clicar em algo
function DuckAch.Admin.StartEntityPicker(ply, achId)
    if not IsValid(ply) then return end
    _pickerPending[ply:SteamID()] = achId

    --// Sinaliza o cliente: ele fecha os menus, equipa a toolgun e troca pra entity_picker
    net.Start("DuckAch.Admin.EquipPicker")
        net.WriteString(achId)
    net.Send(ply)

    --// Hook de clique da stool vem via TOOL:LeftClick → chama DuckAch_PickerSelect no server
    hook.Add("DuckAch.Admin.PickerSelected", "AchievementSystem.Admin.PickerCb_" .. ply:SteamID(), function(player, ent, entId)
        if player ~= ply then return end

        hook.Remove("DuckAch.Admin.PickerSelected", "AchievementSystem.Admin.PickerCb_" .. ply:SteamID())

        local aId = _pickerPending[ply:SteamID()]
        _pickerPending[ply:SteamID()] = nil

        if not aId then return end

        local ach = DuckAch.Registry.Get(aId)
        if ach then
            ach.params.entId = entId
            DuckAch.Admin.PersistCustomAchievements()
            ply:ChatPrint("[DuckAch Admin] Entity '" .. entId .. "' linked to achievement '" .. aId .. "'!")
        end

        net.Start("DuckAch.Admin.PickerResult")
            net.WriteString(aId)
            net.WriteString(entId)
        net.Send(ply)
    end)
end

concommand.Add("duck_ach_setentid", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local entIndex = tonumber(args[1])
    local entId    = args[2]
    if not entIndex or not entId then
        ply:ChatPrint("Usage: duck_ach_setentid <entIndex> <entId>")
        return
    end
    local ent = Entity(entIndex)
    if not IsValid(ent) then ply:ChatPrint("Invalid entity.") return end
    ent:SetNWString("DuckAch_EntId", entId)
    ply:ChatPrint("[DuckAch] EntId '" .. entId .. "' set on entity " .. entIndex)
end)

DuckAch.Admin.LoadCustomAchievements()

--// ── Persistência de entidades marcadas no mundo ───────────────────────────
--// Salva { mapName -> { mapCreationId -> entId } } para restaurar entre restarts

local markedFile = DuckAch.Config.DataDir .. "marked_entities.txt"
local _markedEntities = {}

local function loadMarkedEntities()
    if not file.Exists(markedFile, "DATA") then return end
    local raw = file.Read(markedFile, "DATA")
    if not raw or raw == "" then return end
    _markedEntities = util.JSONToTable(raw) or {}
    DuckAchLogger.info("Marked entities loaded.")
end

local function saveMarkedEntities()
    if not file.IsDir(DuckAch.Config.DataDir, "DATA") then
        file.CreateDir(DuckAch.Config.DataDir)
    end
    file.Write(markedFile, util.TableToJSON(_markedEntities))
end

local function applyMarkedEntities()
    local mapName = game.GetMap()
    local mapData = _markedEntities[mapName]
    if not mapData then return end

    --// Percorre entidades do mapa e aplica o entId salvo
    for _, ent in ipairs(ents.GetAll()) do
        local mapId = tostring(ent:MapCreationID())
        if mapData[mapId] then
            ent:SetNWString("DuckAch_EntId", mapData[mapId])
            DuckAchLogger.debug("EntId restaurado: " .. mapData[mapId] .. " -> " .. ent:GetClass())
        end
    end
end

--// Chamado pela stool ao marcar uma entidade
hook.Add("DuckAch.Admin.PickerSelected", "AchievementSystem.Admin.PersistEntId", function(ply, ent, entId)
    local mapId = tostring(ent:MapCreationID())
    if mapId == "-1" then return end --// Props spawnados não têm MapCreationID, não persistem via esse sistema

    local mapName = game.GetMap()
    _markedEntities[mapName] = _markedEntities[mapName] or {}
    _markedEntities[mapName][mapId] = entId
    saveMarkedEntities()
    DuckAchLogger.debug("EntId salvo: mapa=" .. mapName .. " mapId=" .. mapId .. " entId=" .. entId)
end)

hook.Add("InitPostEntity", "AchievementSystem.Admin.RestoreEntIds", function()
    timer.Simple(1, applyMarkedEntities)
end)

loadMarkedEntities()
