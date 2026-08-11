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

--// Starts the picker: equips the stool on the player and waits for them to click something
function DuckAch.Admin.StartEntityPicker(ply, achId)
    if not IsValid(ply) then return end
    _pickerPending[ply:SteamID()] = achId

    --// Signals the client: it closes its menus, equips the toolgun, and switches to entity_picker
    net.Start("DuckAch.Admin.EquipPicker")
        net.WriteString(achId)
    net.Send(ply)

    --// The stool's click hook comes via TOOL:LeftClick -> calls DuckAch_PickerSelect on the server
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

--// Persistence of world-marked entities
--// Saves { mapName -> { mapCreationId -> entId } } to restore across restarts

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

    --// Walks the map's entities and applies the saved entId
    for _, ent in ipairs(ents.GetAll()) do
        local mapId = tostring(ent:MapCreationID())
        if mapData[mapId] then
            ent:SetNWString("DuckAch_EntId", mapData[mapId])
            DuckAchLogger.debug("EntId restored: " .. mapData[mapId] .. " -> " .. ent:GetClass())
        end
    end
end

--// Called by the stool when marking an entity
hook.Add("DuckAch.Admin.PickerSelected", "AchievementSystem.Admin.PersistEntId", function(ply, ent, entId)
    local mapId = tostring(ent:MapCreationID())
    if mapId == "-1" then return end --// Spawned props don't have a MapCreationID, they don't persist through this system

    local mapName = game.GetMap()
    _markedEntities[mapName] = _markedEntities[mapName] or {}
    _markedEntities[mapName][mapId] = entId
    saveMarkedEntities()
    DuckAchLogger.debug("EntId saved: map=" .. mapName .. " mapId=" .. mapId .. " entId=" .. entId)
end)

hook.Add("InitPostEntity", "AchievementSystem.Admin.RestoreEntIds", function()
    timer.Simple(1, applyMarkedEntities)
end)

loadMarkedEntities()

--// Noscope 360 weapon whitelist - which weapons count for noscope_360_kill.
--// Mutated in place (never reassigned) so hooks/server_hooks.lua can hold
--// a direct reference and see live updates without re-reading a file.

local DEFAULT_NOSCOPE_WEAPONS = {
    "m9k_intervention",
    "m9k_barret_m82",
    "m9k_m98b",
    "m9k_m24",
}

local noscopeFile = DuckAch.Config.DataDir .. "noscope_weapons.txt"

DuckAch.Admin.NoscopeWeapons = {}

local function saveNoscopeWeapons()
    if not file.IsDir(DuckAch.Config.DataDir, "DATA") then
        file.CreateDir(DuckAch.Config.DataDir)
    end
    local list = {}
    for class in pairs(DuckAch.Admin.NoscopeWeapons) do
        table.insert(list, class)
    end
    table.sort(list)
    file.Write(noscopeFile, util.TableToJSON(list))
end

local function loadNoscopeWeapons()
    table.Empty(DuckAch.Admin.NoscopeWeapons)

    if file.Exists(noscopeFile, "DATA") then
        local raw  = file.Read(noscopeFile, "DATA")
        local list = raw and raw ~= "" and util.JSONToTable(raw) or nil
        if list then
            for _, class in ipairs(list) do
                DuckAch.Admin.NoscopeWeapons[class] = true
            end
            DuckAchLogger.info("Noscope weapon whitelist loaded.")
            return
        end
    end

    for _, class in ipairs(DEFAULT_NOSCOPE_WEAPONS) do
        DuckAch.Admin.NoscopeWeapons[class] = true
    end
    saveNoscopeWeapons()
    DuckAchLogger.info("Noscope weapon whitelist initialized with M9K defaults.")
end

--// Every weapon class currently registered on the server, for the admin picker
function DuckAch.Admin.GetAllWeaponClasses()
    local out = {}
    for _, swep in pairs(weapons.GetList()) do
        if swep.ClassName then
            table.insert(out, { class = swep.ClassName, name = swep.PrintName or swep.ClassName })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function DuckAch.Admin.SetNoscopeWeapons(list)
    table.Empty(DuckAch.Admin.NoscopeWeapons)
    for _, class in ipairs(list) do
        if isstring(class) then
            DuckAch.Admin.NoscopeWeapons[class] = true
        end
    end
    saveNoscopeWeapons()
end

loadNoscopeWeapons()
