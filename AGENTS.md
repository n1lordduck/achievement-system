# AGENTS.md

Guidance for anyone (human or AI) writing code in this repo. The goal is a codebase that stays readable and cheap to change as it grows, not one that's clever.

## This is a multiplayer addon, not a script

Every net message is bandwidth spent against every connected player. Before adding or touching networking:

- Send the smallest payload that does the job. `DuckAch.Net.SendProgress` (`net/server_net.lua`) exists specifically so a kill or spawn doesn't have to re-send the whole achievement list, stats, and profile just to move a progress bar - it carries only the progress dict. `DuckAch.Net.SendFullData` is reserved for moments that actually need the full state: join, unlock, admin edit.
- Don't broadcast what one player needs. Text resolved via `DuckAch.LFor(ply, key, ...)` is sent to that one player in their language, not broadcast to everyone in the server's default language.
- Don't add a new net string if an existing one can carry the data. Check `net/server_net.lua` / `net/client_net.lua` first.
- Debounce or rate-limit anything that can fire from repeated player actions (see `_interactDebounce` in `server_api.lua`) - a naive implementation that fires a net message per frame or per hit will work fine solo and fall over with a full server.

## Keep it simple

- Don't build an abstraction, config option, or generic system for a problem that has exactly one real use case today. Three similar lines beat a premature helper.
- Don't add error handling for situations that can't happen given how the code is actually called. Validate at real boundaries (network input, file reads, user text) - not everywhere defensively.
- If a feature can be done with the patterns already in the codebase (the trigger-type registry, the three-tier language system, the hook-based extension points), use those instead of inventing a parallel mechanism.

## Functions

- One function, one job. If a function's name is a verb phrase ("Grant", "SendProgress", "IsReqwestAvailable"), it should only do what that phrase says - no surprise side effects bolted on because it was convenient to put them there.
- If a function is doing more than one distinct thing, split it. A function that's grown past what fits on one screen is a signal to break it down, not a signal to add another `--` section header inside it.
- Name things for what they do, not how they're currently implemented.

## Comments

- Minimal. Default to none.
- The one exception is a hidden constraint, a non-obvious workaround, or a WHY that the code itself can't express - e.g. why `EntityTakeDamage` needs a one-tick delay before reading `Health()` (`hooks/server_hooks.lua`), or why `killstreak` is deliberately excluded from `serialize()`.
- Never comment WHAT the code does. If a comment is just restating the next line in English, delete it.
- No decorative separators (`──────`, `======`, banner-style dividers) in comments. A plain one-line comment header is enough; the box-drawing style was removed from this codebase for exactly this reason. Don't reintroduce it.
- No em-dashes. Use a plain hyphen or restructure the sentence.

## Bug fixes vs. features

- A bug fix changes exactly what's needed to fix the bug, in the files where the bug lives. Nothing else.
- If you notice an unrelated improvement, cleanup opportunity, or a feature idea while fixing something, don't fold it into the same change. Fix the bug first, ship that, then do the improvement as its own separate change with its own reasoning. Bundling makes both harder to review and harder to revert independently.

## Localization

- Any string a player can see goes through `DuckAch.L` / `DuckAch.LFor` / `shared_lang.lua`'s presets, never hardcoded in a single language. This addon ships in English, Spanish, and Portuguese, and a hardcoded string only ever appears in one of them.

## Maintainability signals worth noticing

- A trigger type that needs special-casing in five different files instead of just adding a branch to the existing tables (`VALID_TYPES`, `PARAM_FIELDS`, `TRIGGER_TYPES`) is a sign the abstraction is being fought instead of used.
- If achieving something requires reading three files to understand what one function does, that function is doing too much or is misnamed.
