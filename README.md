# Duck Achievements

<p align="center">
  <img src="https://img.shields.io/badge/language-Lua-blue?style=for-the-badge&logo=lua">
  <img src="https://img.shields.io/badge/status-in%20development-yellow?style=for-the-badge">
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/platform-GMod-lightgrey?style=for-the-badge">
</p>

A full-featured achievement system for Garry's Mod. Players unlock achievements by triggering server-tracked conditions - kills, killstreaks, spawning specific entities, playtime milestones, interacting with marked world entities, and more - with real-time progress tracking, rarity tiers, and a HUD notification on unlock.

## Mysterious features or weird stuff

This project wasn't public originally, and had many, many changes before coming to the actual version it is right now, so stuff that might seem weird or that is "impossible to exist" in some way is pretty normal, although i tried to manually find those cases and remove them from the codebase.

^ This addon was private and made for my server only, therefore there was a bunch of "ugly" workarounds so i could deliver features on time and other stuff - but they should be gone by now.

## Features

- 21+ built-in trigger types (killstreaks, entity spawns, playtime, entity interaction, multi-requirement combos, and more), plus a fully in-game achievement editor for creating custom ones without touching code.
- Six rarity tiers with configurable colors, and a dedicated "secret" achievement type that hides its name and mechanic from players until unlocked.
- Real-time progress bars on achievement cards and a floating HUD indicator, without spamming the network - full state syncs only happen on unlock; incremental progress updates use a separate, lightweight payload.
- Server-relayed thumbnails: the server downloads and caches achievement images once, then relays the bytes to clients. No per-client HTTP requests, no `html`/`DHTML` panel dependency.
- Full multi-language support (English, Portuguese, Spanish out of the box) with three-tier resolution: per-key admin override, then shipped translation, then English fallback. Players can also set a personal language preference that persists across servers and always wins over the server default.
- Pinned achievements - right-click any locked achievement to keep a persistent progress tracker on your HUD.
- Achievement grid with search, rarity/state filters, and pagination.
- Optional Discord webhook integration, with support for multiple webhooks at once - post an embed to one or more channels whenever someone unlocks an achievement. Configured entirely in-game (`!achmin` -> DISCORD) as a card list showing who added each webhook and when; once saved, a webhook's URL can't be viewed again, only activated, deactivated, or deleted. Requires the [reqwest](https://github.com/williamvenner/gmsv_reqwest) binary module on the server; the feature is off by default and simply no-ops if the module isn't installed.

## Installation

Clone (or download and extract) this repository into your server's `garrysmod/addons/` folder - the addon's `lua/` folder needs to sit directly at the addon's root.

```bash
git clone https://github.com/n1lordduck/achievement-system.git garrysmod/addons/duck-achievements
```

## Usage

- `!achievements` (the exact command is per-language and admin-configurable) opens the achievement grid.
- `!achmin` (superadmin only) opens the achievement editor, including the Discord webhook settings.
- `duck_ach_debug 1` in the server console enables debug logging.
- The Discord webhook feature needs the [reqwest](https://github.com/williamvenner/gmsv_reqwest) binary module installed server-side. Everything else works without it.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for how the addon is structured internally, its data model, and the public extension points (`DuckAch.API`, hooks) other addons can hook into.

## Directory Structure

* `lua/duck_achievements/achievements` - achievement definitions. Ships empty by design; achievements are added per-server through the in-game editor.
* `lua/duck_achievements/admin` - the in-game achievement editor and its language panel.
* `lua/duck_achievements/classes` - the `Achievement` and `PlayerProfile` classes.
* `lua/duck_achievements/hooks` - the engine hooks that detect trigger conditions.
* `lua/duck_achievements/net` - client-server networking.
* `lua/duck_achievements/ui` - the achievement grid, profile view, and HUD.
* `lua/weapons/gmod_tool/stools` - the entity-picker tool used to bind world entities to achievements.

## License

This project is licensed under the MIT License - see [LICENSE](./LICENSE).
