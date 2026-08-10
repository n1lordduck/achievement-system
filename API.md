# DuckAchievements - API Documentation

> Achievement addon for Garry's Mod.
> Global prefix: `DuckAch` | Debug: `duck_ach_debug 1` in the server console

---

## Table of Contents

1. [Registering Achievements](#1-registering-achievements)
2. [DuckAch.API - Server](#2-duckachapi---server)
3. [DuckAch.Registry - Shared](#3-duckachregistry---shared)
4. [DuckAch.Data - Server](#4-duckachdata---server)
5. [DuckAch.Client - Client](#5-duckachclient---client)
6. [Classes](#6-classes)
7. [Hooks](#7-hooks)
8. [Configuration](#8-configuration)
9. [Rarities](#9-rarities)
10. [Trigger Types](#10-trigger-types)
11. [Console Commands](#11-console-commands)

---

## 1. Registering Achievements

Create a file in `lua/duck_achievements/achievements/` and add it to `init.lua`.

```lua
DuckAch.Registry.Register({
    id          = "my_achievement",        -- unique string, no spaces
    name        = "My Achievement",
    description = "Description of what to do.",
    rarity      = "rare",                  -- see section 9
    thumbnail   = "https://i.imgur.com/abc.png",  -- optional
    secret      = false,                   -- true = hidden from players who don't have it
    triggerType = "get_x_killstreak",      -- see section 10
    params      = { kills = 10 },          -- depends on triggerType
})
```

**Required fields:** `id`, `name`, `description`, `rarity`, `triggerType`

---

## 2. DuckAch.API - Server

### `DuckAch.API.Grant(ply, achId)` -> `boolean`

Grants an achievement to a player. Returns `false` if the player already has it, the achievement doesn't exist, or `ply` is invalid.

On grant: saves the profile, sends a HUD notification to the player, broadcasts a colored message in chat to everyone, and resends the player's full data (updates the grid in real time).

```lua
-- SERVER
DuckAch.API.Grant(ply, "my_achievement")
```

---

### `DuckAch.API.HasAchievement(ply, achId)` -> `boolean`

Checks whether the player already has the achievement.

```lua
if DuckAch.API.HasAchievement(ply, "killstreak_5") then
    -- player has the achievement
end
```

---

### `DuckAch.API.GetProfile(ply)` -> `PlayerProfile`

Returns the player's `PlayerProfile` object. See section 6 for available methods.

```lua
local profile = DuckAch.API.GetProfile(ply)
print(profile.kills, profile.deaths, profile.killstreak)
```

---

### `DuckAch.API.GetStats(achId)` -> `table`

Returns ownership statistics for the achievement across all registered players.

```lua
local stats = DuckAch.API.GetStats("killstreak_5")
-- stats.total   = total players in the database
-- stats.owners  = how many have the achievement
-- stats.pct     = percentage (0-100, rounded to 1 decimal)
```

---

### `DuckAch.API.TriggerInteract(ply, entId)`

Manually triggers the entity-interaction logic. Normally called by the internal `PlayerUse` hook, but can be called by other addons.

- `entId` - string set via the stool or `duck_ach_setentid`

```lua
-- To integrate with a custom door addon, for example:
DuckAch.API.TriggerInteract(ply, "my_special_door")
```

---

## 3. DuckAch.Registry - Shared

Available on SERVER and CLIENT.

### `DuckAch.Registry.Register(def)` -> `boolean`

Registers an achievement. Returns `false` if invalid or duplicate.

### `DuckAch.Registry.Get(id)` -> `Achievement | nil`

Returns the `Achievement` object by ID.

### `DuckAch.Registry.GetAll()` -> `table`

Returns the `{ [id] = Achievement }` table with all achievements.

### `DuckAch.Registry.GetByType(triggerType)` -> `table`

Returns the list of achievements of a specific type.

```lua
local streakAchs = DuckAch.Registry.GetByType("get_x_killstreak")
for _, ach in ipairs(streakAchs) do
    print(ach.id, ach:getParam("kills"))
end
```

### `DuckAch.Registry.HasAnyOfType(triggerType)` -> `boolean`

Useful for checking before registering heavy hooks.

### `DuckAch.Registry.HasAnyKillRelated()` -> `boolean`

Returns `true` if there's any kill/death-related achievement (killstreak, die_by, killed_by).

### `DuckAch.Registry.Count()` -> `number`

Total number of registered achievements.

### `DuckAch.Registry.Remove(id)`

Removes an achievement from the registry at runtime. Used by the admin panel.

### `DuckAch.Registry.SerializeForPlayer(profile)` -> `table`

Serializes all achievements respecting `secret` - secret achievements the player doesn't have appear as `???`. Used internally by `SendFullData`.

---

## 4. DuckAch.Data - Server

Persistence layer. Saves to `data/duck_achievements/profiles.txt` (compressed).

### `DuckAch.Data.GetProfile(ply)` -> `PlayerProfile`

Returns the player's profile, creating a new one if it doesn't exist.

### `DuckAch.Data.GetProfileBySteamId(sid)` -> `PlayerProfile | nil`

Looks up a profile by SteamID string (e.g. `"STEAM_0:1:12345"`). Returns `nil` if the player never joined.

### `DuckAch.Data.Save()`

Forces an immediate save of all profiles. Called automatically every `SaveInterval` seconds and on `ShutDown`.

### `DuckAch.Data.Load()`

Loads profiles from disk. Called automatically on `Initialize`.

### `DuckAch.Data.GetTotalPlayers()` -> `number`

Total number of players in the database.

### `DuckAch.Data.GetAchievementOwnerCount(achId)` -> `number`

How many players own a specific achievement.

### `DuckAch.Data.SetOptOut(ply, state)`

Sets whether the player opted out of the thumbnail cache. `state = true` = opt out.

### `DuckAch.Data.ClearPlayerCache(ply)`

Resets the player's opt-out (re-enables cache).

---

## 5. DuckAch.Client - Client

Available on CLIENT only.

### `DuckAch.Client.achievements`

Table with all achievements in the public `{ [id] = view }` format. Secret achievements not yet owned appear with `name = "???"` and `locked = true`.

### `DuckAch.Client.profile`

Table with the local player's data:
```lua
{
    kills       = number,
    deaths      = number,
    unlocked    = { [achId] = unixTimestamp },
    optOutCache = boolean,
}
```

### `DuckAch.Client.stats`

Table `{ [achId] = pct }` with the percentage of players who own each achievement.

### `DuckAch.Client.GetThumbnail(url, callback)`

Loads a material from a URL and caches it. The callback receives the `IMaterial` or `nil`.

```lua
DuckAch.Client.GetThumbnail("https://i.imgur.com/abc.png", function(mat)
    if mat and not mat:IsError() then
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(x, y, w, h)
    end
end)
```

### `DuckAch.Client.GetCachedMat(url)` -> `IMaterial | nil`

Callback-free version for use inside `Paint` (called every frame). Returns `nil` if not loaded yet.

```lua
-- Inside panel.Paint:
local mat = DuckAch.Client.GetCachedMat(view.thumbnail)
if mat and not mat:IsError() then
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x, y, 64, 64)
end
```

### `DuckAch.Client.FetchStats(achId)`

Asks the server for the up-to-date percentage of an achievement. The result arrives via `DuckAch.Client.stats[achId]`.

### `DuckAch.Client.SetOptOut(state)`

Sends the opt-out flag to the server. `true` = disable thumbnail cache.

### `DuckAch.Client.ClearCache()`

Asks the server to reset the cache and resend the full data.

---

## 6. Classes

### Achievement

Object returned by `DuckAch.Registry.Get()` and `DuckAch.Registry.GetAll()`.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Displayed name |
| `description` | string | Description |
| `rarity` | string | Rarity ID |
| `thumbnail` | string\|nil | Image URL |
| `secret` | boolean | Whether it's a secret achievement |
| `triggerType` | string | Trigger type |
| `params` | table | Trigger parameters |

**Methods:**

```lua
ach:getParam("kills")          -- returns params[key]
ach:isType("get_x_killstreak") -- boolean
ach:getPublicView(playerHasIt) -- table to send to the client
```

---

### PlayerProfile

Object returned by `DuckAch.API.GetProfile()` and `DuckAch.Data.GetProfile()`.

| Field | Type | Description |
|---|---|---|
| `steamId` | string | Player's SteamID |
| `unlocked` | table | `{ [achId] = unixTimestamp }` |
| `counters` | table | Progress counters |
| `killstreak` | number | Current killstreak (resets on death) |
| `kills` | number | Total kills |
| `deaths` | number | Total deaths |
| `optOutCache` | boolean | Thumbnail cache opt-out |

**Methods:**

```lua
profile:hasAchievement(achId)        -- boolean
profile:unlock(achId)                -- boolean (false if already had it)
profile:getCounter(key)              -- number
profile:incrementCounter(key, amt)   -- number (new value)
profile:setCounter(key, value)
profile:addKill()                    -- +1 kill, +1 killstreak
profile:addDeath()                   -- +1 death, resets killstreak
profile:resetKillstreak()
profile:unlockedCount()              -- total achievements unlocked
profile:serialize()                  -- table for saving to disk
```

---

## 7. Hooks

### SERVER

#### `AchievementSystem.API.OnGrant` `(ply, achDef, profile)`

Fired after an achievement is successfully granted. Use it to integrate with other systems.

```lua
hook.Add("AchievementSystem.API.OnGrant", "MyAddon.OnGrant", function(ply, achDef, profile)
    -- achDef is the Achievement object
    -- profile is the updated PlayerProfile
    if achDef.id == "killstreak_25" then
        -- give a special reward
    end
end)
```

#### `AchievementSystem.Admin.HooksRebuild`

Fired when achievements are created/deleted through the admin panel. The system rebuilds its own hooks automatically, but other addons can listen if they need to react.

```lua
hook.Add("AchievementSystem.Admin.HooksRebuild", "MyAddon.Rebuild", function()
    -- rebuild your own cache if needed
end)
```

#### `DuckAch.Admin.PickerSelected` `(ply, ent, entId)`

Fired when a superadmin clicks an entity with the Entity Picker stool.

### CLIENT

#### `AchievementSystem.Client.DataReady`

Fired when the full data arrives from the server (on connect and on achievement unlock). Use it to update external UIs.

```lua
hook.Add("AchievementSystem.Client.DataReady", "MyAddon.Refresh", function()
    -- DuckAch.Client.achievements, .profile, and .stats are up to date
end)
```

#### `AchievementSystem.Client.OnUnlock` `(view)`

Fired when the local player unlocks an achievement. `view` is the achievement's public table including `view.pct`.

```lua
hook.Add("AchievementSystem.Client.OnUnlock", "MyAddon.OnUnlock", function(view)
    print("Unlocked:", view.name, view.rarity)
end)
```

---

## 8. Configuration

Edit `lua/duck_achievements/shared_config.lua`:

| Key | Default | Description |
|---|---|---|
| `DataDir` | `"duck_achievements/"` | Folder under `data/` |
| `SaveInterval` | `300` | Seconds between auto-saves |
| `ChatPrefix` | `"[Achievements]"` | Chat prefix |
| `ChatCommand` | `"achievements"` | `!achievements` command |
| `NotifDuration` | `6` | Seconds the notification stays on screen |
| `NotifSlideTime` | `0.35` | Slide-in duration (seconds) |
| `NotifFadeTime` | `0.5` | Fade-out duration (seconds) |
| `NotifWidth` | `320` | HUD notification width |
| `NotifHeight` | `80` | HUD notification height |
| `ConfettiEnabled` | `true` | Enables the confetti effect |
| `ConfettiCount` | `65` | Confetti particles per unlock |
| `ConfettiLifetime` | `2.8` | Maximum confetti lifetime |
| `MaxStoredNotifs` | `3` | Max notifications on screen at once |
| `SuperadminGroups` | `{ "superadmin" }` | Groups with access to `!achmin` |

---

## 9. Rarities

| ID | Label | Color |
|---|---|---|
| `common` | Common | Gray `(160,160,160)` |
| `uncommon` | Uncommon | Green `(100,200,100)` |
| `rare` | Rare | Blue `(80,140,255)` |
| `epic` | Epic | Purple `(180,80,255)` |
| `legendary` | Legendary | Gold `(255,180,30)` |
| `secret` | Secret | Cyan `(193,235,233)` |

```lua
-- Programmatic access:
local rar = DuckAch.GetRarity("legendary")
-- rar.id, rar.label, rar.color, rar.order
```

---

## 10. Trigger Types

All triggers are processed automatically by the internal hooks. The `PlayerUse` hook is only registered if there are achievements of the `interact_*` types. The `PlayerDeath` hook is only registered if there are kill-related achievements. Etc.

### `get_killed_by_x`
Fired when the player is killed by a specific person.
```lua
params = {
    steamid = "STEAM_0:1:12345",  -- killer's SteamID
    -- or: steamid = "ADMIN"      -- any admin/superadmin
}
```

### `spawn_x_entity`
Fired the first time the player spawns the entity.
```lua
params = { classname = "npc_combine_s" }
```

### `spawn_x_entity_y_times`
Fired after spawning the entity N times.
```lua
params = { classname = "npc_combine_s", times = 100 }
```

### `get_x_usergroup`
Fired when the player enters the specified usergroup. Detected via `EntityNetworkedVarChanged` (compatible with ULX, ServerGuard, and base GMod).
```lua
params = { usergroup = "admin" }
```

### `die_by_x_entity`
Fired when the player dies and the inflictor has the specified classname.
```lua
params = { classname = "prop_physics" }
```

### `interact_with_x_entity`
Fired when the player presses E on an entity with the given `entId`. The `entId` is set via the stool or `duck_ach_setentid`.
```lua
params = { entId = "my_special_door" }
```

### `get_x_killstreak`
Fired when the player racks up N kills without dying.
```lua
params = { kills = 10 }
```

### `get_x_killstreak_with_y_weapon`
Consecutive kills using only the specified weapon. Resets when another weapon is used.
```lua
params = { kills = 5, weapon = "weapon_pistol" }
```

### `say_specific_phrase`
Fired when the player sends the exact phrase in chat.
```lua
params = {
    phrase        = "supreme duck",
    caseSensitive = false,   -- optional, defaults to false
}
```

---

## 11. Console Commands

| Command | Realm | Access | Description |
|---|---|---|---|
| `duck_ach_debug 1` | SERVER | Everyone | Enables debug logging in the console |
| `duck_ach_setentid <entIndex> <entId>` | SERVER | Superadmin | Manually sets an entity's EntId by index |
| `!achievements` (chat) | CLIENT | Everyone | Opens the achievements menu |
| `!achmin` (chat) | CLIENT | Superadmin | Opens the admin panel |

### Integrating entities via code

To mark an entity from your own addon without using the stool:

```lua
-- SERVER: on any valid entity
ent:SetNWString("DuckAch_EntId", "my_addon_door_1")

-- When the player presses E on it, the system fires automatically.
-- To trigger it manually (e.g. from another event):
DuckAch.API.TriggerInteract(ply, "my_addon_door_1")
```
