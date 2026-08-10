--// Labels aren't hardcoded here: they're resolved via DuckAch.L("rarity.<id>")
--// in DuckAch.GetRarity(), so they follow the server's active language.
DuckAch.Rarities = {
    common = {
        id    = "common",
        color = Color(160, 160, 160),
        order = 1,
    },
    uncommon = {
        id    = "uncommon",
        color = Color(100, 200, 100),
        order = 2,
    },
    rare = {
        id    = "rare",
        color = Color(80, 140, 255),
        order = 3,
    },
    epic = {
        id    = "epic",
        color = Color(180, 80, 255),
        order = 4,
    },
    legendary = {
        id    = "legendary",
        color = Color(255, 180, 30),
        order = 5,
    },
    secret = {
        id    = "secret",
        color = Color(193, 235, 233),
        order = 6,
    },
}

--// Returns a { id, label, color, order } table with the label already translated
--// into the language that's active at call time.
function DuckAch.GetRarity(id)
    local base = DuckAch.Rarities[id] or DuckAch.Rarities.common
    return {
        id    = base.id,
        label = DuckAch.L("rarity." .. base.id),
        color = base.color,
        order = base.order,
    }
end
