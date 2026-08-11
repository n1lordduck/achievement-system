# DuckAchievements - Architecture

Global namespace: `DuckAch`. Global logger: `DuckAchLogger` (from the loader, not `DuckAch` itself - it's set up before anything else so early failures can still be logged).

## Load order

`lua/autorun/duck_achievements_loader.lua` is the only autorun file. It wraps every `include()` in `pcall` (a bad file logs an error via `DuckAchLogger.err` instead of taking the whole addon down) and loads in three fixed passes:

```
SHARED (both realms)
  shared_lang.lua              -- DuckAch.Lang: presets + per-key overrides + DuckAch.L()
  shared_config.lua            -- DuckAch.Config
  shared_rarities.lua          -- DuckAch.Rarities, DuckAch.GetRarity() (label resolved live via DuckAch.L)
  classes/achievement_class.lua-- Achievement OOP class + VALID_TYPES trigger whitelist
  classes/profile_class.lua    -- PlayerProfile OOP class
  shared_registry.lua          -- DuckAch.Registry (byId / byType indices)
  achievements/init.lua        -- includes achievements/{kills,social,playtime,spawn,misc}.lua

SERVER only
  server_lang.lua              -- persists active language + overrides, syncs to clients
  server_data.lua              -- profiles.txt persistence, owner-count cache, erase/get-all concommands
  server_api.lua               -- DuckAch.API: Grant/HasAchievement/GetStats/TriggerInteract
                                -- DuckAch.Webhooks: internal, admin-panel-only (not an extension point)
  server_thumbnails.lua        -- server-side HTTP fetch + cache + relay of achievement thumbnails
  net/server_net.lua           -- DuckAch.Net: SendFullData/SendProgress, all net.Receive handlers
  hooks/server_hooks.lua       -- one hook per trigger-type family, registered only if in use
  admin/server_admin.lua       -- custom achievement persistence, entity picker, marked-entity persistence

CLIENT only
  net/client_net.lua           -- DuckAch.Client cache, thumbnail material cache, connect banner
  net/client_lang.lua          -- personal language preference (file-persisted) + server sync
  ui/client_fonts.lua          -- fonts, palette (DuckAch.C), draw helpers, DuckAch.Icons
  ui/client_hud.lua            -- unlock toast notifications + floating progress bars
  ui/client_pin.lua            -- pinned-achievement tracker sidebar (local-only, file-persisted)
  ui/client_menu.lua           -- the !achievements grid + detail overlay
  ui/client_profile.lua        -- profile overlay (own or others')
  admin/client_admin.lua       -- !achmin panel (achievement CRUD, entity picker trigger)
  admin/client_admin_lang.lua  -- language editor panel (per-key override editor)
```

`achievements/*.lua` ship **empty** by design (just a comment) - this addon has zero achievements pre-registered. Server owners add their own via `!achmin`, which persists to `custom_achievements.txt` and is loaded back through `DuckAch.Registry.Register(def)` on boot.

## Data model

**`Achievement`** (`classes/achievement_class.lua`) - immutable once created; `Achievement.new(def)` validates against a hardcoded `VALID_TYPES` whitelist (id/name/description/rarity/triggerType all required) and returns `nil, err` on failure rather than throwing. `getPublicView(playerHasIt)` is what actually gets serialized to clients - for a secret achievement the player doesn't have, it returns a stub with `name = "???"` and `triggerType = nil` (deliberately omitted so the mechanic can't be reverse-engineered from network traffic).

**`PlayerProfile`** (`classes/profile_class.lua`) - per-SteamID, in-memory (`server_data.lua`'s `_profiles` table), persisted as a whole compressed blob (not per-player files). Holds `unlocked` (achId → unix timestamp), `counters` (generic key→number bag used by nearly every incremental trigger type), `kills`/`deaths`/`killstreak`, `playtime`, `killbindCount`. `killstreak` is deliberately **not** in `serialize()` - resets on restart, by design (session-scoped state, not meant to persist).

**`DuckAch.Registry`** - two indices over the same `Achievement` objects: `_byId` (lookup) and `_byType` (so hooks can ask "does anything care about `spawn_x_entity`?" in O(1) rather than scanning everything). `HasAnyOfType`/`HasAnyKillRelated` exist specifically so `hooks/server_hooks.lua` can skip registering a hook entirely when no achievement needs it.

## Persistence

All under `data/duck_achievements/`:

| File | Written by | Contents |
|---|---|---|
| `profiles.txt` | `server_data.lua` | `util.Compress(json({sid: profile:serialize()}))`, all profiles in one blob |
| `custom_achievements.txt` | `admin/server_admin.lua` | pretty-printed JSON, one entry per admin-created achievement definition |
| `marked_entities.txt` | `admin/server_admin.lua` | `{mapName: {mapCreationId: entId}}`, restored on `InitPostEntity` so world-entity bindings survive restarts |
| `lang_data.txt` | `server_lang.lua` | `{active, overrides}` - the server's chosen language + every per-key admin edit |
| `noscope_weapons.txt` | `admin/server_admin.lua` | JSON array of weapon classes that count for `noscope_360_kill`. Defaults to the M9K sniper rifles on first boot, then whatever the admin picks in `!achmin` -> NOSCOPE |
| `thumbnails/<crc>.dat` | `server_thumbnails.lua` | raw downloaded image bytes, keyed by CRC of the URL |

Client-side (per-player, on their own machine, survive across servers): `duckach_lang_pref.txt` (personal language override) and `duck_achievements_pin.txt` (pinned achievements).

Auto-save timers: profiles every `Config.SaveInterval` (300s default) plus on `ShutDown`; language changes save immediately on every admin edit.

## Achievement lifecycle

```
Admin registers via !achmin  ──►  DuckAch.Registry.Register(def)
                                        │
                                        ▼
                          hook.Run("AchievementSystem.Admin.HooksRebuild")
                                        │
                                        ▼
                    hooks/server_hooks.lua rebuilds - for each trigger-type
                    family, checks HasAnyOfType(...) and (re)adds the one
                    hook that watches for it (PlayerDeath, PlayerUse, etc.)

Gameplay event fires the relevant engine hook
        │
        ▼
DuckAch.API.Grant(ply, achId)
        │
        ├─► profile:unlock(achId) + DuckAch.Data.Save()
        ├─► broadcastChat (colored by rarity, to everyone)
        ├─► DuckAch.Net.SendUnlock(ply, view) ──► client HUD toast + confetti
        ├─► DuckAch.Net.SendFullData(ply)       ──► grid refreshes live
        └─► hook.Run("AchievementSystem.API.OnGrant", ply, achDef, profile)
              (this is the integration point for other addons)
```

This "rebuild hooks only for trigger types actually in use" pattern is why adding a single `spawn_x_entity` achievement doesn't mean the server is now scanning every player kill for something unrelated - each engine hook is opt-in per trigger-type family, not blanket-registered.

Between full unlocks, `DuckAch.Net.SendProgress(ply)` pushes a **lightweight** update (progress numbers only, no achievement views/stats) on every relevant kill/spawn, so the HUD progress bars and card progress fills feel live without re-sending the entire achievement list on every kill.

## Networking

Two payload types, both `util.Compress`'d before sending:

- **`SendFullData`** - achievement views (secret-respecting) + stats (% ownership per achievement) + progress + the player's own profile summary. Sent on join and after any unlock/admin edit.
- **`SendProgress`** - just the `progress` table, built by the same `BuildProgress` function `SendFullData` uses internally. Sent frequently (every relevant kill/spawn), which is exactly why it's kept minimal.

Thumbnails are **not** fetched client-side. `server_thumbnails.lua` downloads via `HTTP{}`, caches the raw bytes to disk, and relays them to clients as base64 over `DuckAch.SendThumbnail` - clients build a `Material` locally from the received bytes (`net/client_net.lua`). This means a broken/slow image host only costs the *server* one HTTP request per unique URL (cached to disk after that), never each individual client, and clients need zero HTTP permissions of their own. Players can opt out via `DuckAch.Client.SetOptOut(true)`, tracked both in their profile and as an `NWBool` the server checks before even attempting a send.

## Localization

Three-tier resolution per key, **unlike** the sibling Sandbox Factions addon - this one keeps genuinely separate storage per language rather than bulk-overwriting a single active table:

```
DuckAch.L(key, ...)  ─►  Lang.Get(key, ...)  ─►  Lang.Raw(key, langcode)
                                                        │
                                     1. Overrides[langcode][key]   (admin-edited, persisted)
                                     2. Presets[langcode][key]     (shipped translation)
                                     3. Overrides[Default][key] / Presets[Default][key]  (English fallback)
```

Two independent "current language" concepts, resolved differently per realm:
- **Server default** (`Lang.Current`) - admin-set via `!achmin` → Language panel, synced to everyone, used for anything the server formats (sub-requirement labels sent in `progress` payloads, etc.).
- **Personal preference** (`Lang.PlayerPref`, client-only) - stored in a local file so it follows the player between servers, always wins over the server default when set. `Lang.EffectiveLanguage()` is `PlayerPref or Current`.

`DuckAch.LFor(ply, key, ...)` (server-side) resolves using **that specific player's** preference if the client has told the server what it is (sent via `DuckAch.Lang.SetPlayerPref` on join and on every change) - this is how server-generated per-player text (like sub-requirement labels) still respects personal preference despite being formatted server-side.

The admin language panel (`admin/client_admin_lang.lua`) edits **one key at a time**, each edit becoming a distinct `Overrides[langcode][key]` entry - so switching the server's active language later doesn't clobber a translation someone already fixed for a *different* language, which is the structural difference from Sandbox Factions' simpler (but lossier) single-table-overwrite model.

## Client-side caches

- **Thumbnail materials** (`client_net.lua`) - keyed by URL, built once from the bytes the server relays.
- **Progress bar debounce** (`client_hud.lua`) - a `PROGRESS_TYPES` allowlist decides which trigger types are worth showing a floating progress bar for at all (deliberately excludes killstreak-style counters that would spam the screen).
- **Pinned achievements** (`client_pin.lua`) - entirely local, no server round-trip; auto-unpins itself once the achievement unlocks or if it's a secret that got re-locked.

## UI structure

Two top-level entry points, both DFrames:

- **`!achievements`** (configurable per-language via the `chat.command` lang key, see below) → `client_menu.lua`'s grid: search + rarity/state filter pills, paginated cards, click for a detail overlay with full progress breakdown. "My Profile" and (superadmin-only) "Staff Panel" / "Language" buttons live in the top bar.
- **`!achmin`** (superadmin only, hardcoded - not currently localized) → `admin/client_admin.lua`: single-column achievement list + dynamic edit form whose fields are generated from a `PARAM_FIELDS[triggerType]` table, so adding a new trigger type's admin UI is a data change, not new form-building code. The "select entity in world" flow closes the panel immediately (client has a direct reference to its own frame - see Sandbox Factions' `ARCHITECTURE.md` for why routing this through a blind panel search is the wrong pattern), equips the entity-picker stool, and reopens the panel with the picked entity filled in once the server confirms the pick.

The chat command itself is localized - `chat.command` is a normal lang key (`"achievements"` / `"conquistas"` / `"logros"`), resolved server-side per-player via `DuckAch.LFor(ply, "chat.command")` in the `PlayerSay` hook, so it doesn't need special-casing outside the language system at all.

## Discord webhook integration

Optional, opt-in, supports multiple simultaneous webhooks. Requires the [reqwest](https://github.com/williamvenner/gmsv_reqwest) binary module server-side. `server_api.lua` calls `pcall(require, "reqwest")` once at load - a binary module dropped into `lua/bin/` doesn't auto-populate the `reqwest` global the way a normal Lua file does via `include()`, it has to be explicitly `require()`'d, so this call is what actually makes the module usable. `DuckAch.Webhooks.IsReqwestAvailable()` reports whether that succeeded; `DuckAch.Webhooks.Send` checks it before every send and logs a warning (rather than erroring) if it's missing. The admin panel's webhook card list also surfaces this to superadmins directly: a red warning banner in the "DISCORD" popup when the module isn't loaded, plus a one-time popup when a webhook is added while it's still missing - so servers without the module get told, not just silently skipped.

Webhook management (`Add`/`Remove`/`SetEnabled`/`GetList`/`Send`/`IsReqwestAvailable`) lives in `DuckAch.Webhooks`, not `DuckAch.API` - unlike `DuckAch.API`, this is internal to the addon's own admin panel (`net/server_net.lua`) and isn't part of the supported extension surface for other addons to call.

Configuration happens entirely through `!achmin` → the "DISCORD" button in the top bar, which opens a card-list panel: an "add webhook" field at the top, and one card per configured webhook below. Each card shows whether it's active, who added it (Steam name + SteamID64), and exactly when (date and time down to the second), with its own activate/deactivate and delete controls. A webhook's URL is treated as a secret and is **never sent back to any client once saved, including the superadmin who added it** - the `DuckAch.Admin.Webhook.List` net message that populates the cards only ever carries `id`, `enabled`, `createdByNick`, `createdBySteamID`, `createdAt`, never `url`. There's no code path, server or client, that reads a stored URL back out over the network; if you need to change one, delete it and add a new one.

Every currently-enabled entry gets its own POST when an achievement unlocks - `DuckAch.Webhooks.Send` iterates the enabled subset and fires one `reqwest` call per destination.

Persistence is a single JSON array at `data/duck_achievements/webhooks.json`, outside the addon's own `lua/` folder so it can never end up in this repository regardless of git history. Each entry:

| Field | Contents |
|---|---|
| `id` | generated on add (`"wh_" .. os.time() .. "_" .. random`), used to target activate/deactivate/delete actions. |
| `url` | the raw webhook URL. Validated on add against `^https://discord%.com/api/webhooks/` / `^https://discordapp%.com/api/webhooks/`. Never leaves the server after this. |
| `enabled` | per-entry on/off switch. |
| `createdByNick` / `createdBySteamID` | who added it. |
| `createdAt` | `os.time()` at the moment it was added. |

If you're setting this up fresh: create a webhook in your Discord channel's integration settings, then paste the URL into `!achmin` → DISCORD → the add field. There is intentionally no way to view a saved URL again through the UI - if you need to rotate it, delete the card and add the new one.

## Extension points for other addons

- `hook.Add("AchievementSystem.API.OnGrant", "MyAddon", function(ply, achDef, profile) ... end)` - react to any unlock.
- `DuckAch.API.Grant(ply, achId)` - grant directly.
- `ent:SetNWString("DuckAch_EntId", "my_addon_door_1")` + `DuckAch.API.TriggerInteract(ply, entId)` - wire a custom entity into the `interact_with_x_entity` trigger type without needing the stool.

## Known gaps

- `admin/client_admin.lua`'s `GridColumns`/`GridCardSize` config values are defined in `shared_config.lua` but unused - the grid computes its own column count from available width at runtime instead.
- No pagination-aware virtualization - the grid is fine at normal achievement counts but every card still gets a live `DPanel` even off-screen.
