--// Os labels não ficam fixos aqui: são resolvidos via DuckAch.L("rarity.<id>")
--// em DuckAch.GetRarity(), então acompanham o idioma ativo do servidor.
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

--// Retorna uma tabela { id, label, color, order } com o label já traduzido
--// no idioma ativo no momento da chamada.
function DuckAch.GetRarity(id)
    local base = DuckAch.Rarities[id] or DuckAch.Rarities.common
    return {
        id    = base.id,
        label = DuckAch.L("rarity." .. base.id),
        color = base.color,
        order = base.order,
    }
end
