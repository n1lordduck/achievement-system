# DuckAchievements - Internal Map & Checklist

## General data flow

```
SERVER                                      CLIENT
─────────────────────────────────────────────────────────────────
Initialize
  └─ Data.Load()                            InitPostEntity + timer(3s)
       └─ profiles.txt (compressed)           └─ RequestFullData ──►
                                                                    ◄── SendFullData (compressed)
PlayerInitialSpawn + timer(2s)                                          └─ DataReady hook
  └─ SendFullData(ply) ──────────────────►                                  └─ rebuildGrid() (if menu is open)

Grant(ply, achId)
  ├─ profile:unlock(achId)
  ├─ ChatBroadcast ──────────────────────► chat.AddText (colored by rarity)
  ├─ SendUnlock(ply) ────────────────────► OnUnlock hook → pushNotif → HUD + sound + confetti
  ├─ SendFullData(ply) ──────────────────► DataReady → rebuildGrid
  └─ Data.Save()
```

---

## Layers and files

### Shared (server + client)

| File | What it does |
|---|---|
| `shared_config.lua` | All configurable constants in `DuckAch.Config` |
| `shared_rarities.lua` | `DuckAch.Rarities` table with id/label/color/order. `DuckAch.GetRarity(id)` |
| `classes/achievement_class.lua` | `Achievement` class with `new()`, `validate()`, `getPublicView(hasIt)`, `getParam()`, `isType()` |
| `classes/profile_class.lua` | `PlayerProfile` class with `unlock()`, `hasAchievement()`, `incrementCounter()`, `addKill()`, `addDeath()`, `serialize()` |
| `shared_registry.lua` | `DuckAch.Registry` - `_byId` and `_byType` maps. `Register()`, `Get()`, `GetAll()`, `GetByType()`, `Remove()`, `SerializeForPlayer()` |
| `achievements/init.lua` | Loads the 4 achievement-definition files |

### Server

| File | What it does |
|---|---|
| `server_data.lua` | `DuckAch.Data` - loads/saves `profiles.txt` with `util.Compress`. Auto-saves every `SaveInterval`s. `GetProfile()`, `GetAchievementOwnerCount()`. `duckachiv_erase_*` commands |
| `server_api.lua` | `DuckAch.API` - `Grant()`, `HasAchievement()`, `GetStats()`, `TriggerInteract()`. Orchestrates broadcast + notif + save |
| `net/server_net.lua` | Registers all netstrings. `SendFullData()` (compresses the payload). Handlers for `RequestFullData`, `Admin.Save`, `Admin.Delete` (both call `SendFullData` for **everyone**), `Admin.SetEntId` |
| `hooks/server_hooks.lua` | `setupHooks()` - only registers hooks for trigger types that exist in the registry. Rebuilds via `AchievementSystem.Admin.HooksRebuild` |
| `admin/server_admin.lua` | `DuckAch.Admin` - `LoadCustomAchievements()` (loads `custom_achievements.txt`), `PersistCustomAchievements()`, `StartEntityPicker()`. Entity-marking system: `marked_entities.txt` keyed by `MapCreationID`, restored on `InitPostEntity` |

### Client

| File | What it does |
|---|---|
| `net/client_net.lua` | `DuckAch.Client` - local cache of `achievements`, `stats`, `profile`, `thumbnails`. Handlers for `SendFullData`, `SendUnlock`, `ChatBroadcast`. `GetThumbnail()` / `GetCachedMat()` |
| `ui/client_fonts.lua` | Defines 9 `DA_*` fonts, the `DuckAch.C` palette, helpers `fillC`, `outlineC`, `drawText`, `ease` |
| `ui/client_hud.lua` | Top-right notification: slide-in + fade-out, physics-based confetti, per-rarity sound, rarity glow, drop shadow |
| `ui/client_menu.lua` | `!achievements` - grid with `rebuildGrid()` called on `DataReady`. Cards sorted by rarity. STAFF PANEL button (superadmin). Modal with real word-wrap |
| `ui/client_profile.lua` | Profile: AvatarImage + border overlay, K/D stats, unlocked list with dates, cache toggle + clear cache |
| `admin/client_admin.lua` | `!achmin` - left list (sorted by id) + dynamic right-side form per triggerType. Global `SendList` and `PickerResult` receivers via a hooks bridge |

### Stool

| File | What it does |
|---|---|
| `weapons/gmod_tool/stools/entity_picker.lua` | `LeftClick`: generates an entId from `MapCreationID` or a position CRC, sets `NWString DuckAch_EntId`, fires `DuckAch.Admin.PickerSelected`, switches back to the previous weapon. Client: receives `EquipPicker` → closes DFrames → `use gmod_tool` + `gmod_toolmode entity_picker`. Receives `PickerResult` → reopens the admin panel |

---

## Persistence

| File under `data/duck_achievements/` | Contents | Format |
|---|---|---|
| `profiles.txt` | All player profiles | Compressed JSON (`util.Compress`) |
| `custom_achievements.txt` | Achievements created/edited via the admin panel | Pretty-printed JSON |
| `marked_entities.txt` | `{ mapName: { mapCreationId: entId } }` | JSON |

**Killstreak is not persisted** - it's a field on `PlayerProfile` but `serialize()` doesn't include it. Resets on server restart. Intentional, since killstreak is volatile session state.

---

## Internal hooks

| Hook | Registered in | Fires when |
|---|---|---|
| `PlayerDeath` | `server_hooks` | Kill/death tracking (killstreak, die_by, killed_by) |
| `OnEntityCreated` | `server_hooks` | A player spawns an entity |
| `EntityNetworkedVarChanged` | `server_hooks` | Usergroup change via an NW2 var |
| `PlayerSpawn` | `server_hooks` | Usergroup fallback (players who already had it on connect) |
| `PlayerSay` | `server_hooks` | Chat phrase detection |
| `PlayerUse` | `server_hooks` | Player presses E on an entity with `DuckAch_EntId` |
| `AchievementSystem.Admin.HooksRebuild` | `server_hooks` | Admin creates/deletes an achievement → rebuilds all hooks |
| `DuckAch.Admin.PickerSelected` | `server_admin` (x2) | Stool click: persists the entId + sends `PickerResult` to the client |
| `AchievementSystem.Client.DataReady` | `client_menu` | `SendFullData` received → `rebuildGrid()` |
| `AchievementSystem.Client.OnUnlock` | `client_hud` | `SendUnlock` received → HUD notification |
| `AchievementSystem.Admin.ListUpdated` | `client_admin` | `SendList` received → refreshes the achievement list in the panel |
| `AchievementSystem.Admin.PickerDone` | `client_admin` | `PickerResult` received → opens the edit form |
| `AchievementSystem.API.OnGrant` | External | After a successful `Grant()` - for integration with other addons |

---

## Implementation checklist

### Implemented and working

- [x] Achievement registration via `DuckAch.Registry.Register(def)`
- [x] OOP `Achievement` and `PlayerProfile` classes
- [x] Compressed profile persistence under `data/`
- [x] Timer-based auto-save + save on shutdown
- [x] `Grant()` with a colored chat broadcast (gold prefix, achievement name colored by rarity)
- [x] Top-right HUD notification: slide-in, fade-out, physics-based confetti, per-rarity sound, glow, shadow
- [x] `!achievements` grid with cards sorted by rarity, rarity glow, thumbnail via `GetCachedMat`
- [x] Real-time grid updates on unlock or when an admin saves/deletes an achievement
- [x] Achievement modal with real word-wrap and "% of players"
- [x] Profile: avatar, name, SteamID, kills/deaths/K:D, unlocked list with date/time
- [x] Cache toggle + clear cache on the profile
- [x] `!achmin` admin panel: list + dynamic form per triggerType, EDIT/DEL, new achievement
- [x] STAFF PANEL button visible only to superadmins in `!achievements`
- [x] Entity picker: closes DFrames, equips the stool via `gmod_toolmode`, reopens admin after selection
- [x] Marked-entity persistence keyed by `MapCreationID` in `marked_entities.txt`, restored on boot
- [x] Usergroup detection via `EntityNetworkedVarChanged` (works with ULX and ServerGuard)
- [x] Secret achievements: `???` thumbnail for players who don't have them, chat reveals the name only to players who do
- [x] `duckachiv_erase_everything` and `duckachiv_erase_all_profiles` (console + in-game superadmin)
- [x] Debug logs via `duck_ach_debug 1`
- [x] ASCII banner on client connect
- [x] Hook rebuild when achievements are created/deleted via admin

### Implemented with a known limitation

- [x] **Killstreak doesn't persist across restarts** - intentional (session state), but can surprise admins
- [x] **URL thumbnails** - `Material()` in GMod is synchronous but the HTTP download is async; the material can appear a few frames late. No better native solution in GMod.
- [x] **Entity picker on spawned props** - `MapCreationID` returns `-1`, so the entId is generated from a position CRC and isn't persisted in `marked_entities.txt`. Works for the session but loses the bind on restart.

### Resolved (v6-v7)

- [x] **`entId` persists when saving via the form** - `buildEditForm` captures `_pickedEntId` locally. The `AchievementSystem.Admin.PickerDone` hook populates the text field and the internal variable. `saveBtn` falls back to `_pickedEntId` if the field is empty. Also pre-fills the field with the existing `entId` when editing an already-configured achievement.
- [x] **Thumbnails via `surface.GetURL`** - replaced `Material()` with `surface.GetURL(url, 128, 128, callback)`. Real async loading. Cache entries are `{ mat, loadedAt }` with a TTL respecting the config's `ThumbnailCacheTTL`. `GetCachedMat()` returns `nil` while loading.
- [x] **Progress display** - `SendFullData` includes a `progress = { [achId] = { current, needed } }` field for `spawn_x_entity_y_times` achievements with partial progress. The card shows a colored bar + `X / Y` counter in place of the rarity label. The modal also shows a bar + percentage.
- [x] **Robust `entId` in the stool** - props without a `MapCreationID` use a hash of: `SysTime`, `EntIndex`, owner SteamID, owner name, map CRC, and XYZ position. Guarantees uniqueness even without a native ID.

### Additionally resolved (v7)

- [x] **`GetAchievementOwnerCount` O(n) → cache** - `_ownerCountCache[achId]` invalidated on `Grant`. First read scans, subsequent reads are O(1).
- [x] **Debounce on `TriggerInteract`** - `_interactDebounce[steamid_entId]` with a 0.5s window. Avoids redundant calls without affecting UX.
- [x] **Real cache opt-out** - `GetThumbnail` returns `nil` immediately if `optOutCache = true`, without calling `GetURL`.
- [x] **Server-side chat command** - `PlayerSay` returns `""` for `!achievements` and `!achmin`, suppressing the message before it appears. The client gets the signal via `net.Receive("DuckAch.OpenMenu")` / `DuckAch.OpenAdmin`.
- [x] **Grid filtering** - a bar below the top bar with: a name/id search field, rarity filter (color-coded buttons), state filter (ALL/OWNED/MISSING). `_activeFilter` is shared, `rebuildGrid` applies it on build.
- [x] **Robust entId for props** - hash of 6 factors: SysTime, EntIndex, owner SteamID, owner name, map CRC, XYZ position.

### Not yet implemented

- [ ] **No pagination in the grid** - scrolling works but can get heavy with a lot of achievements.
- [ ] **No animated opening menu for `!achievements`** - it opens straight into the grid.
- [ ] **`GridColumns` and `GridCardSize` in the config aren't used** - `client_menu.lua` uses a local `CARD_S = 130`.
