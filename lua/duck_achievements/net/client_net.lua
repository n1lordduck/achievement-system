DuckAch.Client = DuckAch.Client or {}

DuckAch.Client.achievements = {}
DuckAch.Client.stats        = {}
DuckAch.Client.progress     = {}
DuckAch.Client.profile      = {}
DuckAch.Client.thumbnails   = {}  --// url -> IMaterial

local function requestFullData()
    net.Start("DuckAch.RequestFullData")
    net.SendToServer()
end

net.Receive("DuckAch.SendFullData", function()
    local size = net.ReadUInt(32)
    local raw  = net.ReadData(size)
    local json = util.Decompress(raw)
    if not json then return end

    local data = util.JSONToTable(json)
    if not data then return end

    DuckAch.Client.achievements = data.achievements or {}
    DuckAch.Client.stats        = data.stats        or {}
    DuckAch.Client.progress     = data.progress     or {}
    DuckAch.Client.profile      = data.profile      or {}

    --// Ensures newer fields exist on the local profile
    DuckAch.Client.profile.playtime      = DuckAch.Client.profile.playtime      or 0
    DuckAch.Client.profile.killbindCount = DuckAch.Client.profile.killbindCount or 0

    --// Ensures unlocked exists and its keys are strings
    if not DuckAch.Client.profile.unlocked then
        DuckAch.Client.profile.unlocked = {}
    end

    DuckAchLogger.debug("SendFullData received: " .. table.Count(DuckAch.Client.achievements) .. " achievements")
    hook.Run("AchievementSystem.Client.DataReady")
    DuckAchLogger.debug("DataReady fired")
end)

--// Lightweight progress update - called on every kill/spawn without resending
--// the whole achievement structure. Only updates DuckAch.Client.progress and
--// fires ProgressUpdated so card/overlay/pin repaints stay in sync.
net.Receive("DuckAch.SendProgress", function()
    local size = net.ReadUInt(32)
    local raw  = net.ReadData(size)
    local json = util.Decompress(raw)
    if not json then return end
    local progress = util.JSONToTable(json)
    if not progress then return end
    DuckAch.Client.progress = progress
    hook.Run("AchievementSystem.Client.ProgressUpdated")
end)

net.Receive("DuckAch.SendUnlock", function()
    local json = net.ReadString()
    local view = util.JSONToTable(json)
    if not view then return end

    --// Updates or inserts the achievement in the local cache
    local existing = DuckAch.Client.achievements[view.id]
    if existing then
        existing.locked      = false
        existing.name        = view.name
        existing.description = view.description
        existing.thumbnail   = view.thumbnail
        existing.rarity      = view.rarity
    else
        DuckAch.Client.achievements[view.id] = {
            id          = view.id,
            name        = view.name,
            description = view.description,
            thumbnail   = view.thumbnail,
            rarity      = view.rarity,
            secret      = view.secret,
            locked      = false,
        }
    end

    --// Clears the thumbnail cache to force a reload
    if view.thumbnail and view.thumbnail ~= "" then
        DuckAch.Client.thumbnails[view.thumbnail] = nil
    end

    if not DuckAch.Client.profile.unlocked then
        DuckAch.Client.profile.unlocked = {}
    end
    DuckAch.Client.profile.unlocked[view.id] = os.time()

    hook.Run("AchievementSystem.Client.OnUnlock", view)
end)

--// Colored chat: gold prefix, "name" in white, achievement in the rarity's color
net.Receive("DuckAch.ChatBroadcast", function()
    local plyName  = net.ReadString()
    local achName  = net.ReadString()
    local rarity   = net.ReadString()
    local isSecret = net.ReadBool()
    local sid      = net.ReadString()

    local rar    = DuckAch.GetRarity(rarity)
    local rarCol = rar.color
    local gold   = Color(255, 200, 50)

    local prefix = DuckAch.L("chat.prefix") .. " "

    if isSecret then
        local hasIt = DuckAch.Client.profile.unlocked and DuckAch.Client.profile.unlocked[sid]
        if hasIt or LocalPlayer():SteamID() == sid then
            chat.AddText(
                gold, prefix,
                Color(230, 235, 245), plyName,
                Color(130, 155, 180), DuckAch.L("chat.secret_got_named"),
                rarCol, achName .. "!"
            )
        else
            chat.AddText(
                gold, prefix,
                Color(230, 235, 245), plyName,
                Color(130, 155, 180), DuckAch.L("chat.secret_got_hidden")
            )
        end
    else
        chat.AddText(
            gold, prefix,
            Color(230, 235, 245), plyName,
            Color(130, 155, 180), DuckAch.L("chat.unlocked"),
            rarCol, achName .. "!"
        )
    end
end)

net.Receive("DuckAch.SendStats", function()
    local achId = net.ReadString()
    local pct   = net.ReadFloat()
    DuckAch.Client.stats[achId] = pct
end)

function DuckAch.Client.SetOptOut(state)
    net.Start("DuckAch.SetOptOut")
        net.WriteBool(state)
    net.SendToServer()
    DuckAch.Client.profile.optOutCache = state
end

function DuckAch.Client.ClearCache()
    net.Start("DuckAch.ClearCache")
    net.SendToServer()
end

function DuckAch.Client.FetchStats(achId)
    net.Start("DuckAch.RequestStats")
        net.WriteString(achId)
    net.SendToServer()
end

--// Server-relayed thumbnail system
--// The server downloads the images via HTTP and sends the bytes to the client via net.
--// Client never makes an HTTP request itself - zero dependency on GetURL or HTML panels.

local _thumbCallbacks = {}  --// url -> list of waiting callbacks

--// Receives a thumbnail from the server as base64 bytes
net.Receive("DuckAch.SendThumbnail", function()
    local url     = net.ReadString()
    local encoded = net.ReadString()
    if not url or encoded == "" then return end

    local rawBytes = util.Base64Decode(encoded)
    if not rawBytes or rawBytes == "" then
        DuckAchLogger.warn("Invalid thumbnail bytes: " .. url)
        return
    end

    --// Saves to the client's local cache (raw PNG -> temp file -> Material)
    local tmpPath = "duck_achievements/tmp_" .. util.CRC(url) .. ".png"
    file.CreateDir("duck_achievements")
    file.Write(tmpPath, rawBytes)

    local mat = Material("data/" .. tmpPath, "noclamp smooth")
    if mat and not mat:IsError() then
        DuckAch.Client.thumbnails[url] = mat
        DuckAchLogger.debug("Thumbnail received from server: " .. url)

        --// Resolves pending callbacks
        if _thumbCallbacks[url] then
            for _, cb in ipairs(_thumbCallbacks[url]) do cb(mat) end
            _thumbCallbacks[url] = nil
        end
    else
        DuckAchLogger.warn("Invalid material after receiving thumbnail: " .. url)
        DuckAch.Client.thumbnails[url] = false
    end
end)

--// Requests a thumbnail from the server if it doesn't have one yet
function DuckAch.Client.GetThumbnail(url, callback)
    if not url or url == "" then if callback then callback(nil) end return end
    if DuckAch.Client.profile.optOutCache then if callback then callback(nil) end return end

    local cached = DuckAch.Client.thumbnails[url]
    if cached and cached ~= false then
        if callback then callback(cached) end
        return
    end

    --// Chains the callback
    if callback then
        _thumbCallbacks[url] = _thumbCallbacks[url] or {}
        table.insert(_thumbCallbacks[url], callback)
    end

    --// If it's already being fetched (false = pending), don't request again
    if cached == false then return end

    DuckAch.Client.thumbnails[url] = false
    net.Start("DuckAch.RequestThumbnail")
        net.WriteString(url)
    net.SendToServer()
    DuckAchLogger.debug("Requisitando thumbnail: " .. url)
end

--// Returns the cached material immediately (for use inside Paint)
function DuckAch.Client.GetCachedMat(url)
    if not url or url == "" then return nil end
    local m = DuckAch.Client.thumbnails[url]
    if not m or m == false then return nil end
    return m
end

hook.Add("InitPostEntity", "AchievementSystem.Client.Init", function()
    timer.Simple(3, requestFullData)
end)

local function printBanner()
    MsgC(Color(100, 0, 100), [[

    ██████╗ ██╗   ██╗ ██████╗██╗  ██╗ █████╗  ██████╗██╗  ██╗
    ██╔══██╗██║   ██║██╔════╝██║ ██╔╝██╔══██╗██╔════╝██║  ██║
    ██║  ██║██║   ██║██║     █████╔╝ ███████║██║     ███████║
    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══██║██║     ██╔══██║
    ██████╔╝╚██████╔╝╚██████╗██║  ██╗██║  ██║╚██████╗██║  ██║
    ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
    ACHIEVEMENTS  v1.1  ~  n1lordduck

]])
end

net.Receive("DuckAch_Banner", function()
    printBanner()
end)
