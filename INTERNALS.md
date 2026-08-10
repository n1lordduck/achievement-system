# DuckAchievements — Mapeamento Interno & Checklist

## Fluxo geral de dados

```
SERVIDOR                                    CLIENTE
─────────────────────────────────────────────────────────────────
Initialize
  └─ Data.Load()                            InitPostEntity + timer(3s)
       └─ profiles.txt (comprimido)           └─ RequestFullData ──►
                                                                    ◄── SendFullData (comprimido)
PlayerInitialSpawn + timer(2s)                                          └─ DataReady hook
  └─ SendFullData(ply) ──────────────────►                                  └─ rebuildGrid() (se menu aberto)

Grant(ply, achId)
  ├─ profile:unlock(achId)
  ├─ ChatBroadcast ──────────────────────► chat.AddText (colorido por raridade)
  ├─ SendUnlock(ply) ────────────────────► OnUnlock hook → pushNotif → HUD + som + confetti
  ├─ SendFullData(ply) ──────────────────► DataReady → rebuildGrid
  └─ Data.Save()
```

---

## Camadas e arquivos

### Shared (server + client)

| Arquivo | O que faz |
|---|---|
| `shared_config.lua` | Todas as constantes configuráveis em `DuckAch.Config` |
| `shared_rarities.lua` | Tabela `DuckAch.Rarities` com id/label/color/order. `DuckAch.GetRarity(id)` |
| `classes/achievement_class.lua` | Classe `Achievement` com `new()`, `validate()`, `getPublicView(hasIt)`, `getParam()`, `isType()` |
| `classes/profile_class.lua` | Classe `PlayerProfile` com `unlock()`, `hasAchievement()`, `incrementCounter()`, `addKill()`, `addDeath()`, `serialize()` |
| `shared_registry.lua` | `DuckAch.Registry` — mapa `_byId` e `_byType`. `Register()`, `Get()`, `GetAll()`, `GetByType()`, `Remove()`, `SerializeForPlayer()` |
| `achievements/init.lua` | Carrega os 4 arquivos de definição de conquistas |

### Server

| Arquivo | O que faz |
|---|---|
| `server_data.lua` | `DuckAch.Data` — carrega/salva `profiles.txt` com `util.Compress`. Auto-save a cada `SaveInterval`s. `GetProfile()`, `GetAchievementOwnerCount()`. Comandos `duckachiv_erase_*` |
| `server_api.lua` | `DuckAch.API` — `Grant()`, `HasAchievement()`, `GetStats()`, `TriggerInteract()`. Orquestra broadcast + notif + save |
| `net/server_net.lua` | Registra todas as netstrings. `SendFullData()` (comprime payload). Handlers de `RequestFullData`, `Admin.Save`, `Admin.Delete` (ambos fazem `SendFullData` pra **todos**), `Admin.SetEntId` |
| `hooks/server_hooks.lua` | `setupHooks()` — registra só hooks para triggers que existem no registry. Rebuild via `AchievementSystem.Admin.HooksRebuild` |
| `admin/server_admin.lua` | `DuckAch.Admin` — `LoadCustomAchievements()` (carrega `custom_achievements.txt`), `PersistCustomAchievements()`, `StartEntityPicker()`. Sistema de marcação de entidades: `marked_entities.txt` por `MapCreationID`, restaurado no `InitPostEntity` |

### Client

| Arquivo | O que faz |
|---|---|
| `net/client_net.lua` | `DuckAch.Client` — cache local de `achievements`, `stats`, `profile`, `thumbnails`. Handlers de `SendFullData`, `SendUnlock`, `ChatBroadcast`. `GetThumbnail()` / `GetCachedMat()` |
| `ui/client_fonts.lua` | Define 9 fontes `DA_*`, paleta `DuckAch.C`, helpers `fillC`, `outlineC`, `drawText`, `ease` |
| `ui/client_hud.lua` | Notificação top-right: slide-in + fade-out, confetti com física, som por raridade, glow de raridade, sombra |
| `ui/client_menu.lua` | `!conquistas` — grid com `rebuildGrid()` chamado no `DataReady`. Cards ordenados por raridade. Botão STAFF PANEL (superadmin). Modal com word-wrap |
| `ui/client_profile.lua` | Perfil: AvatarImage + overlay de borda, stats K/D, lista de unlocked com data, toggle cache + limpar cache |
| `admin/client_admin.lua` | `!achmin` — lista esquerda (ordenada por id) + form direita dinâmico por triggerType. Receivers globais `SendList` e `PickerResult` via hooks bridge |

### Stool

| Arquivo | O que faz |
|---|---|
| `weapons/gmod_tool/stools/entity_picker.lua` | `LeftClick`: gera entId por `MapCreationID` ou CRC de posição, seta `NWString DuckAch_EntId`, dispara `DuckAch.Admin.PickerSelected`, volta pra última arma. Client: recebe `EquipPicker` → fecha DFrames → `use gmod_tool` + `gmod_toolmode entity_picker`. Recebe `PickerResult` → reabre admin |

---

## Persistência

| Arquivo em `data/duck_achievements/` | Conteúdo | Formato |
|---|---|---|
| `profiles.txt` | Todos os perfis de jogadores | JSON comprimido (`util.Compress`) |
| `custom_achievements.txt` | Conquistas criadas/editadas via painel admin | JSON legível (pretty) |
| `marked_entities.txt` | `{ mapName: { mapCreationId: entId } }` | JSON |

**Killstreak não é persistido** — é campo do `PlayerProfile` mas `serialize()` não o inclui. Reseta ao reiniciar o servidor. Intencional pois killstreak é estado volátil de sessão.

---

## Hooks internos

| Hook | Registrado em | Dispara quando |
|---|---|---|
| `PlayerDeath` | `server_hooks` | Kill/death tracking (killstreak, die_by, killed_by) |
| `OnEntityCreated` | `server_hooks` | Spawn de entidade por jogador |
| `EntityNetworkedVarChanged` | `server_hooks` | Mudança de usergroup via NW2 var |
| `PlayerSpawn` | `server_hooks` | Fallback de usergroup (quem já tinha ao conectar) |
| `PlayerSay` | `server_hooks` | Detecção de frase no chat |
| `PlayerUse` | `server_hooks` | Jogador aperta E em entidade com `DuckAch_EntId` |
| `AchievementSystem.Admin.HooksRebuild` | `server_hooks` | Admin cria/deleta conquista → reconstrói todos os hooks |
| `DuckAch.Admin.PickerSelected` | `server_admin` (x2) | Stool clicada: persiste entId + envia `PickerResult` ao cliente |
| `AchievementSystem.Client.DataReady` | `client_menu` | `SendFullData` recebido → `rebuildGrid()` |
| `AchievementSystem.Client.OnUnlock` | `client_hud` | `SendUnlock` recebido → notificação HUD |
| `AchievementSystem.Admin.ListUpdated` | `client_admin` | `SendList` recebido → atualiza lista de conquistas no painel |
| `AchievementSystem.Admin.PickerDone` | `client_admin` | `PickerResult` recebido → abre form de edição |
| `AchievementSystem.API.OnGrant` | Externo | Após `Grant()` com sucesso — para integração de outros addons |

---

## Checklist de implementação

### ✅ Implementado e funcional

- [x] Registro de conquistas via `DuckAch.Registry.Register(def)`
- [x] Classes OOP `Achievement` e `PlayerProfile`
- [x] Persistência de perfis comprimida em `data/`
- [x] Auto-save por timer + save no shutdown
- [x] `Grant()` com broadcast colorido no chat (prefix dourado, nome da conquista na cor da raridade)
- [x] Notificação HUD top-right: slide-in, fade-out, confetti com física, som por raridade, glow, sombra
- [x] Grid `!conquistas` com cards ordenados por raridade, glow de raridade, thumbnail via `GetCachedMat`
- [x] Atualização em tempo real do grid ao desbloquear ou admin salvar/deletar conquista
- [x] Modal de conquista com word-wrap real e `% de jogadores`
- [x] Perfil: avatar, nome, SteamID, kills/mortes/K:D, lista de desbloqueadas com data/hora
- [x] Toggle cache + limpar cache no perfil
- [x] Painel admin `!achmin`: lista + form dinâmico por triggerType, EDIT/DEL, nova conquista
- [x] Botão STAFF PANEL visível só pra superadmin no `!conquistas`
- [x] Entity picker: fecha DFrames, equipa stool via `gmod_toolmode`, reabre admin após seleção
- [x] Persistência de entidades marcadas por `MapCreationID` em `marked_entities.txt`, restaurada no boot
- [x] Usergroup via `EntityNetworkedVarChanged` (funciona com ULX e serverguard)
- [x] Conquistas secretas: thumbnail `???` pra quem não tem, chat revela nome só pra quem tem
- [x] `duckachiv_erase_everything` e `duckachiv_erase_all_profiles` (console + superadmin in-game)
- [x] Debug logs com `duck_ach_debug 1`
- [x] Banner ASCII no connect do cliente
- [x] Rebuild de hooks ao criar/deletar conquistas via admin

### ⚠️ Implementado com limitação conhecida

- [x] **Killstreak não persiste entre restarts** — intencional (estado de sessão), mas pode surpreender admins
- [x] **Thumbnail de URL** — `Material()` no GMod é síncrono mas o download HTTP é assíncrono; o material pode aparecer com alguns frames de delay. Sem solução nativa melhor no GMod.
- [x] **Entity picker em props spawnados** — `MapCreationID` retorna `-1`, então o entId é gerado por CRC de posição e não é persistido em `marked_entities.txt`. Funciona na sessão mas perde o bind ao reiniciar.

### ✅ Resolvidos (v6-v7)

- [x] **`entId` persiste ao salvar via form** — `buildEditForm` captura `_pickedEntId` localmente. Hook `AchievementSystem.Admin.PickerDone` popula o campo de texto e a variável interna. O `saveBtn` usa `_pickedEntId` como fallback se o campo estiver vazio. Também popula o campo com o `entId` existente ao editar conquista já configurada.
- [x] **Thumbnail via `surface.GetURL`** — substituído `Material()` por `surface.GetURL(url, 128, 128, callback)`. Carregamento assíncrono real. Cache com entrada `{ mat, loadedAt }` e TTL respeitando `ThumbnailCacheTTL` do config. `GetCachedMat()` retorna `nil` enquanto carrega.
- [x] **Visualização de progresso** — `SendFullData` inclui campo `progress = { [achId] = { current, needed } }` para conquistas `spawn_x_entity_y_times` com progresso parcial. Card exibe barra colorida + contador `X / Y` no lugar da rarity label. Modal também exibe barra + porcentagem.
- [x] **`entId` robusto na stool** — props sem `MapCreationID` usam hash de: `SysTime`, `EntIndex`, `SteamID do dono`, `nome do dono`, `CRC do mapa`, e `posição XYZ`. Garante unicidade mesmo sem ID nativo.

### ✅ Resolvidos adicionalmente (v7)

- [x] **`GetAchievementOwnerCount` O(n) → cache** — `_ownerCountCache[achId]` invalidado no `Grant`. Primeira leitura faz o scan, subsequentes são O(1).
- [x] **Debounce em `TriggerInteract`** — `_interactDebounce[steamid_entId]` com janela de 0.5s. Evita chamadas redundantes sem afetar UX.
- [x] **Opt-out de cache real** — `GetThumbnail` retorna `nil` imediatamente se `optOutCache = true`, sem chamar `GetURL`.
- [x] **Chat command server-side** — `PlayerSay` retorna `""` para `!conquistas` e `!achmin`, suprimindo a mensagem antes de aparecer. Client recebe sinal via `net.Receive("DuckAch.OpenMenu")` / `DuckAch.OpenAdmin`.
- [x] **Filtro no grid** — barra abaixo do topBar com: campo de busca por nome/id, filtro de raridade (botões por cor), filtro de estado (TODOS/TENHO/FALTAM). `_activeFilter` compartilhado, `rebuildGrid` aplica na montagem.
- [x] **entId robusto para props** — hash de 6 fatores: SysTime, EntIndex, SteamID do dono, nome do dono, CRC do mapa, posição XYZ.

### ❌ Ainda não implementado

- [ ] **Sem paginação no grid** — scroll funciona mas pode ficar pesado com muitas conquistas.
- [ ] **Sem menu de abertura animado para `!conquistas`** — abre direto no grid.
- [ ] **`GridColumns` e `GridCardSize` no config não são usados** — `client_menu.lua` usa `CARD_S = 130` local.
