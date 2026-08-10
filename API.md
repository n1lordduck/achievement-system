# DuckAchievements — Documentação da API

> Addon de conquistas para Garry's Mod.  
> Prefixo global: `DuckAch` | Debug: `duck_ach_debug 1` no console do servidor

---

## Índice

1. [Registrar Conquistas](#1-registrar-conquistas)
2. [DuckAch.API — Servidor](#2-duckachapi--servidor)
3. [DuckAch.Registry — Shared](#3-duckachregistry--shared)
4. [DuckAch.Data — Servidor](#4-duckachdata--servidor)
5. [DuckAch.Client — Cliente](#5-duckachclient--cliente)
6. [Classes](#6-classes)
7. [Hooks](#7-hooks)
8. [Configuração](#8-configuração)
9. [Raridades](#9-raridades)
10. [Tipos de Gatilho](#10-tipos-de-gatilho)
11. [Comandos de Console](#11-comandos-de-console)

---

## 1. Registrar Conquistas

Crie um arquivo em `lua/duck_achievements/achievements/` e adicione-o ao `init.lua`.

```lua
DuckAch.Registry.Register({
    id          = "minha_conquista",       -- string única, sem espaços
    name        = "Minha Conquista",
    description = "Descrição do que fazer.",
    rarity      = "rare",                  -- ver seção 9
    thumbnail   = "https://i.imgur.com/abc.png",  -- opcional
    secret      = false,                   -- true = oculta pra quem não tem
    triggerType = "get_x_killstreak",      -- ver seção 10
    params      = { kills = 10 },          -- depende do triggerType
})
```

**Campos obrigatórios:** `id`, `name`, `description`, `rarity`, `triggerType`

---

## 2. DuckAch.API — Servidor

### `DuckAch.API.Grant(ply, achId)` → `boolean`

Concede uma conquista a um jogador. Retorna `false` se o jogador já tiver, se a conquista não existir ou se `ply` for inválido.

Ao conceder: salva o perfil, envia notificação HUD ao jogador, broadcast colorido no chat de todos, e reenvia os dados completos pro jogador (atualiza grid em tempo real).

```lua
-- SERVER
DuckAch.API.Grant(ply, "minha_conquista")
```

---

### `DuckAch.API.HasAchievement(ply, achId)` → `boolean`

Checa se o jogador já possui a conquista.

```lua
if DuckAch.API.HasAchievement(ply, "killstreak_5") then
    -- jogador tem a conquista
end
```

---

### `DuckAch.API.GetProfile(ply)` → `PlayerProfile`

Retorna o objeto `PlayerProfile` do jogador. Ver seção 6 para os métodos disponíveis.

```lua
local profile = DuckAch.API.GetProfile(ply)
print(profile.kills, profile.deaths, profile.killstreak)
```

---

### `DuckAch.API.GetStats(achId)` → `table`

Retorna estatísticas de posse da conquista entre todos os jogadores registrados.

```lua
local stats = DuckAch.API.GetStats("killstreak_5")
-- stats.total   = total de jogadores no banco
-- stats.owners  = quantos têm a conquista
-- stats.pct     = porcentagem (0-100, arredondado em 1 decimal)
```

---

### `DuckAch.API.TriggerInteract(ply, entId)`

Aciona manualmente a lógica de interação com entidade. Normalmente chamado pelo hook `PlayerUse` interno, mas pode ser chamado por outros addons.

- `entId` — string definida via stool ou `duck_ach_setentid`

```lua
-- Para integrar com um addon de porta customizada, por exemplo:
DuckAch.API.TriggerInteract(ply, "minha_porta_especial")
```

---

## 3. DuckAch.Registry — Shared

Disponível em SERVER e CLIENT.

### `DuckAch.Registry.Register(def)` → `boolean`

Registra uma conquista. Retorna `false` se inválida ou duplicada.

### `DuckAch.Registry.Get(id)` → `Achievement | nil`

Retorna o objeto `Achievement` pelo ID.

### `DuckAch.Registry.GetAll()` → `table`

Retorna a tabela `{ [id] = Achievement }` com todas as conquistas.

### `DuckAch.Registry.GetByType(triggerType)` → `table`

Retorna lista de conquistas de um tipo específico.

```lua
local streakAchs = DuckAch.Registry.GetByType("get_x_killstreak")
for _, ach in ipairs(streakAchs) do
    print(ach.id, ach:getParam("kills"))
end
```

### `DuckAch.Registry.HasAnyOfType(triggerType)` → `boolean`

Útil para checar antes de registrar hooks pesados.

### `DuckAch.Registry.HasAnyKillRelated()` → `boolean`

Retorna `true` se há qualquer conquista de kill/death (killstreak, die_by, killed_by).

### `DuckAch.Registry.Count()` → `number`

Total de conquistas registradas.

### `DuckAch.Registry.Remove(id)`

Remove uma conquista do registro em tempo de execução. Usado pelo painel admin.

### `DuckAch.Registry.SerializeForPlayer(profile)` → `table`

Serializa todas as conquistas respeitando `secret` — conquistas secretas que o jogador não tem aparecem como `???`. Usado internamente pelo `SendFullData`.

---

## 4. DuckAch.Data — Servidor

Camada de persistência. Salva em `data/duck_achievements/profiles.txt` (comprimido).

### `DuckAch.Data.GetProfile(ply)` → `PlayerProfile`

Retorna o perfil do jogador, criando um novo se não existir.

### `DuckAch.Data.GetProfileBySteamId(sid)` → `PlayerProfile | nil`

Busca perfil por SteamID string (ex: `"STEAM_0:1:12345"`). Retorna `nil` se o jogador nunca entrou.

### `DuckAch.Data.Save()`

Força salvamento imediato de todos os perfis. Chamado automaticamente a cada `SaveInterval` segundos e no `ShutDown`.

### `DuckAch.Data.Load()`

Carrega perfis do disco. Chamado automaticamente no `Initialize`.

### `DuckAch.Data.GetTotalPlayers()` → `number`

Total de jogadores no banco de dados.

### `DuckAch.Data.GetAchievementOwnerCount(achId)` → `number`

Quantos jogadores possuem uma conquista específica.

### `DuckAch.Data.SetOptOut(ply, state)`

Define se o jogador optou por sair do cache de thumbnails. `state = true` = opt out.

### `DuckAch.Data.ClearPlayerCache(ply)`

Reseta o opt-out do jogador (reativa cache).

---

## 5. DuckAch.Client — Cliente

Disponível apenas no CLIENT.

### `DuckAch.Client.achievements`

Tabela com todas as conquistas no formato público `{ [id] = view }`. Conquistas secretas não possuídas aparecem com `name = "???"` e `locked = true`.

### `DuckAch.Client.profile`

Tabela com dados do jogador local:
```lua
{
    kills       = number,
    deaths      = number,
    unlocked    = { [achId] = unixTimestamp },
    optOutCache = boolean,
}
```

### `DuckAch.Client.stats`

Tabela `{ [achId] = pct }` com a porcentagem de jogadores que possuem cada conquista.

### `DuckAch.Client.GetThumbnail(url, callback)`

Carrega um material de URL e armazena em cache. O callback recebe o `IMaterial` ou `nil`.

```lua
DuckAch.Client.GetThumbnail("https://i.imgur.com/abc.png", function(mat)
    if mat and not mat:IsError() then
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(x, y, w, h)
    end
end)
```

### `DuckAch.Client.GetCachedMat(url)` → `IMaterial | nil`

Versão sem callback para uso dentro de `Paint` (chamado todo frame). Retorna `nil` se ainda não carregado.

```lua
-- Dentro de panel.Paint:
local mat = DuckAch.Client.GetCachedMat(view.thumbnail)
if mat and not mat:IsError() then
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x, y, 64, 64)
end
```

### `DuckAch.Client.FetchStats(achId)`

Pede ao servidor a porcentagem atualizada de uma conquista. Resultado chega via `DuckAch.Client.stats[achId]`.

### `DuckAch.Client.SetOptOut(state)`

Envia opt-out ao servidor. `true` = desativar cache de thumbnails.

### `DuckAch.Client.ClearCache()`

Pede ao servidor para resetar o cache e reenvia os dados completos.

---

## 6. Classes

### Achievement

Objeto retornado por `DuckAch.Registry.Get()` e `DuckAch.Registry.GetAll()`.

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | string | Identificador único |
| `name` | string | Nome exibido |
| `description` | string | Descrição |
| `rarity` | string | ID da raridade |
| `thumbnail` | string\|nil | URL da imagem |
| `secret` | boolean | Se é conquista secreta |
| `triggerType` | string | Tipo de gatilho |
| `params` | table | Parâmetros do gatilho |

**Métodos:**

```lua
ach:getParam("kills")          -- retorna params[key]
ach:isType("get_x_killstreak") -- boolean
ach:getPublicView(playerHasIt) -- tabela para envio ao client
```

---

### PlayerProfile

Objeto retornado por `DuckAch.API.GetProfile()` e `DuckAch.Data.GetProfile()`.

| Campo | Tipo | Descrição |
|---|---|---|
| `steamId` | string | SteamID do jogador |
| `unlocked` | table | `{ [achId] = unixTimestamp }` |
| `counters` | table | Contadores de progresso |
| `killstreak` | number | Killstreak atual (reseta ao morrer) |
| `kills` | number | Total de kills |
| `deaths` | number | Total de mortes |
| `optOutCache` | boolean | Opt-out de thumbnail cache |

**Métodos:**

```lua
profile:hasAchievement(achId)        -- boolean
profile:unlock(achId)                -- boolean (false se já tinha)
profile:getCounter(key)              -- number
profile:incrementCounter(key, amt)   -- number (novo valor)
profile:setCounter(key, value)
profile:addKill()                    -- +1 kill, +1 killstreak
profile:addDeath()                   -- +1 death, reseta killstreak
profile:resetKillstreak()
profile:unlockedCount()              -- total de conquistas desbloqueadas
profile:serialize()                  -- tabela para salvar em disco
```

---

## 7. Hooks

### SERVER

#### `AchievementSystem.API.OnGrant` `(ply, achDef, profile)`

Disparado após uma conquista ser concedida com sucesso. Use para integrar com outros sistemas.

```lua
hook.Add("AchievementSystem.API.OnGrant", "MeuAddon.OnGrant", function(ply, achDef, profile)
    -- achDef é o objeto Achievement
    -- profile é o PlayerProfile atualizado
    if achDef.id == "killstreak_25" then
        -- dar recompensa especial
    end
end)
```

#### `AchievementSystem.Admin.HooksRebuild`

Disparado quando conquistas são criadas/deletadas pelo painel admin. O sistema reconstrói os hooks automaticamente, mas outros addons podem ouvir se precisarem reagir.

```lua
hook.Add("AchievementSystem.Admin.HooksRebuild", "MeuAddon.Rebuild", function()
    -- reconstrói cache próprio se necessário
end)
```

#### `DuckAch.Admin.PickerSelected` `(ply, ent, entId)`

Disparado quando um superadmin clica em uma entidade com a Entity Picker stool.

### CLIENT

#### `AchievementSystem.Client.DataReady`

Disparado quando os dados completos chegam do servidor (ao conectar e ao desbloquear conquistas). Use para atualizar UIs externas.

```lua
hook.Add("AchievementSystem.Client.DataReady", "MeuAddon.Refresh", function()
    -- DuckAch.Client.achievements, .profile e .stats estão atualizados
end)
```

#### `AchievementSystem.Client.OnUnlock` `(view)`

Disparado quando o jogador local desbloqueia uma conquista. `view` é a tabela pública da conquista incluindo `view.pct`.

```lua
hook.Add("AchievementSystem.Client.OnUnlock", "MeuAddon.OnUnlock", function(view)
    print("Desbloqueei:", view.name, view.rarity)
end)
```

---

## 8. Configuração

Edite `lua/duck_achievements/shared_config.lua`:

| Chave | Padrão | Descrição |
|---|---|---|
| `DataDir` | `"duck_achievements/"` | Pasta em `data/` |
| `SaveInterval` | `300` | Segundos entre auto-saves |
| `ChatPrefix` | `"[Conquistas]"` | Prefixo no chat |
| `ChatCommand` | `"conquistas"` | Comando `!conquistas` |
| `NotifDuration` | `6` | Segundos que a notificação fica |
| `NotifSlideTime` | `0.35` | Duração do slide-in (segundos) |
| `NotifFadeTime` | `0.5` | Duração do fade-out (segundos) |
| `NotifWidth` | `320` | Largura da notificação HUD |
| `NotifHeight` | `80` | Altura da notificação HUD |
| `ConfettiEnabled` | `true` | Ativa efeito de confetti |
| `ConfettiCount` | `65` | Partículas de confetti por unlock |
| `ConfettiLifetime` | `2.8` | Tempo de vida máximo do confetti |
| `MaxStoredNotifs` | `3` | Máximo de notificações na tela ao mesmo tempo |
| `SuperadminGroups` | `{ "superadmin" }` | Grupos com acesso ao `!achmin` |

---

## 9. Raridades

| ID | Label | Cor |
|---|---|---|
| `common` | Comum | Cinza `(160,160,160)` |
| `uncommon` | Incomum | Verde `(100,200,100)` |
| `rare` | Raro | Azul `(80,140,255)` |
| `epic` | Épico | Roxo `(180,80,255)` |
| `legendary` | Lendário | Dourado `(255,180,30)` |
| `secret` | Secreto | Ciano `(193,235,233)` |

```lua
-- Acesso programático:
local rar = DuckAch.GetRarity("legendary")
-- rar.id, rar.label, rar.color, rar.order
```

---

## 10. Tipos de Gatilho

Todos os triggers são processados automaticamente pelos hooks internos. O hook `PlayerUse` só é registrado se houver conquistas dos tipos `interact_*`. O hook `PlayerDeath` só é registrado se houver conquistas kill-related. Etc.

### `get_killed_by_x`
Disparado quando o jogador é morto por alguém específico.
```lua
params = {
    steamid = "STEAM_0:1:12345",  -- SteamID do killer
    -- ou: steamid = "ADMIN"      -- qualquer admin/superadmin
}
```

### `spawn_x_entity`
Disparado na primeira vez que o jogador spawna a entidade.
```lua
params = { classname = "npc_combine_s" }
```

### `spawn_x_entity_y_times`
Disparado após spawnar a entidade N vezes.
```lua
params = { classname = "npc_combine_s", times = 100 }
```

### `get_x_usergroup`
Disparado quando o jogador entra no usergroup especificado. Detectado via `EntityNetworkedVarChanged` (compatível com ULX, ServerGuard e GMod base).
```lua
params = { usergroup = "admin" }
```

### `die_by_x_entity`
Disparado quando o jogador morre e o inflictor tem o classname especificado.
```lua
params = { classname = "prop_physics" }
```

### `interact_with_x_entity`
Disparado quando o jogador aperta E em uma entidade com o `entId` definido. O `entId` é configurado via stool ou `duck_ach_setentid`.
```lua
params = { entId = "minha_porta_especial" }
```

### `get_x_killstreak`
Disparado quando o jogador acumula N kills sem morrer.
```lua
params = { kills = 10 }
```

### `get_x_killstreak_with_y_weapon`
Kills consecutivas usando apenas a arma especificada. Resetado ao usar outra arma.
```lua
params = { kills = 5, weapon = "weapon_pistol" }
```

### `say_specific_phrase`
Disparado quando o jogador manda a frase exata no chat.
```lua
params = {
    phrase        = "duck supremo",
    caseSensitive = false,   -- opcional, padrão false
}
```

---

## 11. Comandos de Console

| Comando | Realm | Acesso | Descrição |
|---|---|---|---|
| `duck_ach_debug 1` | SERVER | Todos | Ativa logs de debug no console |
| `duck_ach_setentid <entIndex> <entId>` | SERVER | Superadmin | Define manualmente o EntId de uma entidade pelo índice |
| `!conquistas` (chat) | CLIENT | Todos | Abre o menu de conquistas |
| `!achmin` (chat) | CLIENT | Superadmin | Abre o painel de administração |

### Integração com entidades via código

Para marcar uma entidade de um addon próprio sem usar a stool:

```lua
-- SERVER: em qualquer entidade válida
ent:SetNWString("DuckAch_EntId", "meu_addon_porta_1")

-- Quando o jogador apertar E nela, o sistema dispara automaticamente.
-- Para triggerar manualmente (ex: por outro evento):
DuckAch.API.TriggerInteract(ply, "meu_addon_porta_1")
```
