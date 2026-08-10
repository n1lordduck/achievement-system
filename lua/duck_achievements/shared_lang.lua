--// ── DuckAch.Lang ──────────────────────────────────────────────────────────
--// Sistema de idiomas do addon. Cobre APENAS os textos da INTERFACE (menus,
--// HUD, painel admin, chat). Conquistas custom continuam sendo cadastradas
--// pelo admin no idioma que ele quiser (não são traduzidas automaticamente).
--//
--// Dois níveis:
--//   - Lang.Current     -> idioma PADRÃO DO SERVIDOR, definido pelo admin,
--//                         sincronizado do servidor pra todo mundo.
--//   - Lang.PlayerPref   -> idioma PESSOAL do jogador (só existe no client,
--//                         salvo localmente), tem prioridade sobre o padrão
--//                         do servidor quando o jogador escolhe um.
--//
--// Resolução de idioma efetivo (client): PlayerPref -> Current -> Default(en)
--// Resolução de idioma efetivo (server, por jogador): via Lang.EffectiveFor(ply)
--//
--// Camadas de texto (prioridade decrescente) dentro de um idioma:
--//   1. Overrides   -> editados por admin no painel, persistidos em data/
--//   2. Presets     -> traduções que vêm junto com o addon (en/es/pt-br)
--//   3. Fallback    -> preset do idioma padrão (en), depois a própria key
--//
--// Uso:  DuckAch.L("menu.title")
--//       DuckAch.L("menu.page_info", page, totalPages, totalCount)

DuckAch = DuckAch or {}
DuckAch.Lang = DuckAch.Lang or {}

local Lang = DuckAch.Lang

Lang.Available = { "en", "es", "pt-br" }   --// idiomas com preset embutido
Lang.Default   = "en"                      --// padrão de fábrica: inglês
Lang.Current   = Lang.Current or Lang.Default  --// padrão do servidor (admin)
Lang.PlayerPref = Lang.PlayerPref or nil       --// idioma pessoal (só CLIENT)

Lang.Presets   = Lang.Presets   or {}      --// [langcode][key] = string
Lang.Overrides = Lang.Overrides or {}      --// [langcode][key] = string (persistente)

--// Registra (ou mescla) um bloco de traduções para um idioma.
function Lang.RegisterPreset(langcode, tbl)
    Lang.Presets[langcode] = Lang.Presets[langcode] or {}
    for k, v in pairs(tbl) do
        Lang.Presets[langcode][k] = v
    end
end

function Lang.IsValidLanguage(langcode)
    for _, l in ipairs(Lang.Available) do
        if l == langcode then return true end
    end
    return false
end

--// Idioma que deve ser usado agora, nesta realm.
--// CLIENT: preferência pessoal do jogador (se escolhida) > padrão do servidor
--// SERVER: sempre o padrão do servidor (use Lang.EffectiveFor(ply) pra um jogador específico)
function Lang.EffectiveLanguage()
    if CLIENT and Lang.PlayerPref and Lang.IsValidLanguage(Lang.PlayerPref) then
        return Lang.PlayerPref
    end
    return Lang.Current
end

--// Todas as keys conhecidas (união de todos os presets) — usado pelo painel admin
function Lang.GetAllKeys()
    local seen, keys = {}, {}
    for _, tbl in pairs(Lang.Presets) do
        for k in pairs(tbl) do
            if not seen[k] then
                seen[k] = true
                table.insert(keys, k)
            end
        end
    end
    table.sort(keys)
    return keys
end

--// Valor cru (sem string.format) de uma key, num idioma específico ou no efetivo.
function Lang.Raw(key, langcode)
    langcode = langcode or Lang.EffectiveLanguage()

    local ov = Lang.Overrides[langcode]
    if ov and ov[key] ~= nil then return ov[key] end

    local pr = Lang.Presets[langcode]
    if pr and pr[key] ~= nil then return pr[key] end

    if langcode ~= Lang.Default then
        local ovD = Lang.Overrides[Lang.Default]
        if ovD and ovD[key] ~= nil then return ovD[key] end

        local prD = Lang.Presets[Lang.Default]
        if prD and prD[key] ~= nil then return prD[key] end
    end

    return nil
end

--// String final, já com string.format aplicado se vararg for passado.
--// Se a key não existir em nenhum idioma, retorna "[[key]]" pra facilitar debug.
function Lang.Get(key, ...)
    local str = Lang.Raw(key)
    if not str then return "[[" .. tostring(key) .. "]]" end

    local n = select("#", ...)
    if n > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end

    return str
end

--// Igual a Get, mas forçando um idioma específico (usado pelo servidor pra
--// mandar texto já traduzido no idioma pessoal de UM jogador específico).
function Lang.GetIn(langcode, key, ...)
    local str = Lang.Raw(key, langcode)
    if not str then return "[[" .. tostring(key) .. "]]" end

    local n = select("#", ...)
    if n > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end

    return str
end

--// Atalho global curto
DuckAch.L = Lang.Get

--// ── Presets embutidos ────────────────────────────────────────────────────
--// pt-br é a tradução "original" do addon (a mesma coisa que já existia).
--// en é o idioma padrão. es é a tradução pro espanhol.

Lang.RegisterPreset("en", {
    -- menu
    ["chat.command"]               = "achievements",
    ["menu.title"]                 = "ACHIEVEMENTS",
    ["menu.my_profile"]            = "MY PROFILE",
    ["menu.staff_panel"]           = "STAFF PANEL",
    ["menu.use_server_default"]    = "Use server default",
    ["profile.language"]           = "LANGUAGE",
    ["menu.search_placeholder"]    = "Search achievement...",
    ["menu.badge_unlocked"]        = "UNLOCKED",
    ["menu.badge_locked"]          = "LOCKED",
    ["menu.requirements"]          = "REQUIREMENTS",
    ["menu.percent_have_players"]  = "%.1f%% of players have this achievement",
    ["menu.page_info"]             = "Page %d / %d  (%d achievements)",
    ["filter.rarity.all"]          = "ALL",
    ["filter.rarity.common"]       = "COMMON",
    ["filter.rarity.uncommon"]     = "UNCOMMON",
    ["filter.rarity.rare"]         = "RARE",
    ["filter.rarity.epic"]         = "EPIC",
    ["filter.rarity.legendary"]    = "LEGENDARY",
    ["filter.rarity.secret"]       = "SECRET",
    ["filter.state.all"]           = "ALL",
    ["filter.state.unlocked"]      = "HAVE",
    ["filter.state.locked"]        = "MISSING",

    -- rarity display labels (cards, badges)
    ["rarity.common"]              = "Common",
    ["rarity.uncommon"]            = "Uncommon",
    ["rarity.rare"]                = "Rare",
    ["rarity.epic"]                = "Epic",
    ["rarity.legendary"]           = "Legendary",
    ["rarity.secret"]              = "Secret",

    -- hud
    ["hud.unlocked_title"]         = "ACHIEVEMENT UNLOCKED",
    ["hud.percent_have_short"]     = "%.1f%% of players",

    -- chat broadcast
    ["chat.prefix"]                = "[Achievements]",
    ["chat.secret_got_named"]      = " unlocked a secret achievement: ",
    ["chat.secret_got_hidden"]     = " unlocked a secret achievement!",
    ["chat.unlocked"]              = " unlocked: ",

    -- profile
    ["profile.kills"]              = "KILLS",
    ["profile.deaths"]             = "DEATHS",
    ["profile.unlocked_section"]   = "UNLOCKED ACHIEVEMENTS",
    ["profile.none_unlocked"]      = "No achievements unlocked yet.",
    ["profile.cache_privacy"]      = "CACHE & PRIVACY",
    ["profile.cache_on"]           = "Cache: ON",
    ["profile.cache_off"]          = "Cache: OFF",
    ["profile.clear_cache"]        = "CLEAR CACHE",
    ["profile.reset_confirm"]      = "CONFIRM RESET? (click again)",
    ["profile.reset_progress"]     = "RESET PROGRESS",

    -- admin panel chrome
    ["admin.panel_title"]          = "ADMIN · ACHIEVEMENTS",
    ["admin.tab_achievements"]     = "ACHIEVEMENTS",
    ["admin.new_achievement"]      = "+ NEW ACHIEVEMENT",
    ["admin.id_label"]             = "Achievement ID",
    ["admin.name_label"]           = "Name",
    ["admin.name_placeholder"]     = "E.g: On Fire",
    ["admin.desc_label"]           = "Description",
    ["admin.desc_placeholder"]     = "E.g: Get 5 kills in a row",
    ["admin.thumb_label"]          = "Thumbnail URL (optional)",
    ["admin.rarity_label"]         = "Rarity",
    ["admin.secret_label"]         = "Secret?",
    ["admin.trigger_type_label"]   = "Trigger Type",
    ["admin.sub_requirements"]     = "Sub-Requirements (all must be met)",
    ["admin.remove"]               = "✕ REMOVE",
    ["admin.add_sub_requirement"]  = "+  ADD SUB-REQUIREMENT",
    ["admin.select_entity_world"]  = "⊕  SELECT ENTITY IN WORLD",
    ["admin.set_id_first"]         = "[DuckAch] Set the ID first.",
    ["admin.save_achievement"]     = "✓  SAVE ACHIEVEMENT",
    ["admin.id_name_required"]     = "[DuckAch] ID and Name are required.",
    ["admin.edit"]                 = "EDIT",
    ["admin.delete_short"]         = "DEL",

    -- admin field hints (trigger param editor)
    ["admin.hint.steamid_killer"]  = "Killer's SteamID (or ADMIN)",
    ["admin.hint.model_path"]      = "Model path",
    ["admin.hint.model_path_any"]  = "Model path (empty/any = any prop)",
    ["admin.hint.quantity_number"] = "Amount (number)",
    ["admin.hint.quantity"]        = "Amount",
    ["admin.hint.usergroup_name"]  = "Usergroup name",
    ["admin.hint.classname_killer"]= "Killer's classname",
    ["admin.hint.entid_picker"]    = "EntId (use the picker below)",
    ["admin.hint.kills_needed"]    = "Kills needed (number)",
    ["admin.hint.kills_number"]    = "Kills (number)",
    ["admin.hint.weapon_classname"]= "Weapon classname",
    ["admin.hint.weapon_classname_ex"] = "Weapon classname (e.g: weapon_crowbar)",
    ["admin.hint.exact_phrase"]    = "Exact phrase",
    ["admin.hint.case_sensitive"]  = "Case sensitive? (true/false)",
    ["admin.hint.playtime_hours"]  = "Playtime hours",
    ["admin.hint.total_kills"]     = "Total kills",
    ["admin.hint.total_killbinds"] = "Total killbinds",
    ["admin.hint.minutes_no_kill_die"] = "Minutes without killing/dying",
    ["admin.hint.total_kills_loners"] = "Total loner kills",
    ["admin.hint.minutes_dead"]    = "Minutes dead before respawning",
    ["admin.hint.hours_allowed"]   = "Allowed hours (e.g: 3,6)",
    ["admin.hint.hours_short"]     = "Hours",
    ["admin.webhook_button"]           = "DISCORD",
    ["admin.webhook_title"]            = "DISCORD WEBHOOKS",
    ["admin.webhook_add_label"]        = "Add a new webhook",
    ["admin.webhook_url_hint"]         = "Once you save a webhook you won't be able to view its URL again — you can only activate, deactivate, or delete it.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "ADD",
    ["admin.webhook_requires_reqwest"] = "Requires the reqwest binary module on the server.",
    ["admin.webhook_list_label"]       = "Configured webhooks",
    ["admin.webhook_empty"]            = "No webhooks configured yet.",
    ["admin.webhook_added_by"]         = "Added by %s",
    ["admin.webhook_active"]           = "Active",
    ["admin.webhook_inactive"]         = "Inactive",
    ["admin.webhook_activate"]         = "ACTIVATE",
    ["admin.webhook_deactivate"]       = "DEACTIVATE",
    ["admin.webhook_delete"]           = "DELETE",
    ["admin.webhook_delete_confirm"]   = "Delete this webhook? This can't be undone.",
    ["admin.webhook_invalid_url"]      = "That doesn't look like a Discord webhook URL.",
    ["admin.webhook_action_failed"]    = "That didn't work. Try again.",
    ["admin.lang_button"]          = "LANGUAGE",
    ["admin.lang_panel_title"]     = "LANGUAGE",
    ["admin.lang_panel_subtitle"]  = "Choose the addon's default language and edit any string manually.",
    ["admin.lang_search_placeholder"] = "Search by key or text...",
    ["admin.lang_save"]            = "SAVE",
    ["admin.lang_reset"]           = "DEFAULT",
    ["admin.lang_selector_title"]  = "SERVER DEFAULT LANGUAGE",
    ["admin.lang_selector_hint"]   = "This applies to EVERY player on the server who has not picked a personal language in their own Profile.",
    ["admin.lang_current_status"]  = "The server default is currently set to: %s",

    -- sub-labels de progresso (BuildProgress no servidor)
    ["sublabel.reach_playtime_hours"]   = "Playtime hours",
    ["sublabel.total_kills_x"]          = "Total kills",
    ["sublabel.total_killbind_x"]       = "Killbinds used",
    ["sublabel.spawn_x_entity_y_times"] = "Props spawned",
    ["sublabel.kill_x_with_weapon"]     = "Weapon kills",
})

Lang.RegisterPreset("pt-br", {
    -- menu
    ["chat.command"]               = "conquistas",
    ["menu.title"]                 = "CONQUISTAS",
    ["menu.my_profile"]            = "MEU PERFIL",
    ["menu.staff_panel"]           = "PAINEL STAFF",
    ["menu.use_server_default"]    = "Usar padrão do servidor",
    ["profile.language"]           = "IDIOMA",
    ["menu.search_placeholder"]    = "Buscar conquista...",
    ["menu.badge_unlocked"]        = "DESBLOQUEADA",
    ["menu.badge_locked"]          = "BLOQUEADA",
    ["menu.requirements"]          = "REQUISITOS",
    ["menu.percent_have_players"]  = "%.1f%% dos jogadores possuem esta conquista",
    ["menu.page_info"]             = "Pagina %d / %d  (%d conquistas)",
    ["filter.rarity.all"]          = "TODAS",
    ["filter.rarity.common"]       = "COMUM",
    ["filter.rarity.uncommon"]     = "INCOMUM",
    ["filter.rarity.rare"]         = "RARO",
    ["filter.rarity.epic"]         = "EPICO",
    ["filter.rarity.legendary"]    = "LENDARIO",
    ["filter.rarity.secret"]       = "SECRETO",
    ["filter.state.all"]           = "TODOS",
    ["filter.state.unlocked"]      = "TENHO",
    ["filter.state.locked"]        = "FALTAM",

    ["rarity.common"]              = "Comum",
    ["rarity.uncommon"]            = "Incomum",
    ["rarity.rare"]                = "Raro",
    ["rarity.epic"]                = "Épico",
    ["rarity.legendary"]           = "Lendário",
    ["rarity.secret"]              = "Secreto",

    ["hud.unlocked_title"]         = "CONQUISTA DESBLOQUEADA",
    ["hud.percent_have_short"]     = "%.1f%% dos jogadores",

    ["chat.prefix"]                = "[Conquistas]",
    ["chat.secret_got_named"]      = " pegou uma conquista secreta: ",
    ["chat.secret_got_hidden"]     = " pegou uma conquista secreta!",
    ["chat.unlocked"]              = " desbloqueou: ",

    ["profile.kills"]              = "KILLS",
    ["profile.deaths"]             = "MORTES",
    ["profile.unlocked_section"]   = "CONQUISTAS DESBLOQUEADAS",
    ["profile.none_unlocked"]      = "Nenhuma conquista desbloqueada ainda.",
    ["profile.cache_privacy"]      = "CACHE & PRIVACIDADE",
    ["profile.cache_on"]           = "Cache: ATIVO",
    ["profile.cache_off"]          = "Cache: OFF",
    ["profile.clear_cache"]        = "LIMPAR CACHE",
    ["profile.reset_confirm"]      = "CONFIRMAR RESET? (clique de novo)",
    ["profile.reset_progress"]     = "RESETAR PROGRESSO",

    ["admin.panel_title"]          = "ADMIN · CONQUISTAS",
    ["admin.tab_achievements"]     = "CONQUISTAS",
    ["admin.new_achievement"]      = "+ NOVA CONQUISTA",
    ["admin.id_label"]             = "ID da Conquista",
    ["admin.name_label"]           = "Nome",
    ["admin.name_placeholder"]     = "Ex: Em Chamas",
    ["admin.desc_label"]           = "Descrição",
    ["admin.desc_placeholder"]     = "Ex: Consiga 5 kills seguidas",
    ["admin.thumb_label"]          = "Thumbnail URL (opcional)",
    ["admin.rarity_label"]         = "Raridade",
    ["admin.secret_label"]         = "Secreta?",
    ["admin.trigger_type_label"]   = "Tipo de Gatilho",
    ["admin.sub_requirements"]     = "Sub-Requisitos (todos precisam ser cumpridos)",
    ["admin.remove"]               = "✕ REMOVER",
    ["admin.add_sub_requirement"]  = "+  ADICIONAR SUB-REQUISITO",
    ["admin.select_entity_world"]  = "⊕  SELECIONAR ENTIDADE NO MUNDO",
    ["admin.set_id_first"]         = "[DuckAch] Defina o ID primeiro.",
    ["admin.save_achievement"]     = "✓  SALVAR CONQUISTA",
    ["admin.id_name_required"]     = "[DuckAch] ID e Nome são obrigatórios.",
    ["admin.edit"]                 = "EDITAR",
    ["admin.delete_short"]         = "DEL",

    ["admin.hint.steamid_killer"]  = "SteamID do killer (ou ADMIN)",
    ["admin.hint.model_path"]      = "Path do modelo",
    ["admin.hint.model_path_any"]  = "Path do modelo (vazio/any = qualquer prop)",
    ["admin.hint.quantity_number"] = "Quantidade (número)",
    ["admin.hint.quantity"]        = "Quantidade",
    ["admin.hint.usergroup_name"]  = "Nome do usergroup",
    ["admin.hint.classname_killer"]= "Classname do killer",
    ["admin.hint.entid_picker"]    = "EntId (usar picker abaixo)",
    ["admin.hint.kills_needed"]    = "Kills necessárias (número)",
    ["admin.hint.kills_number"]    = "Kills (número)",
    ["admin.hint.weapon_classname"]= "Weapon classname",
    ["admin.hint.weapon_classname_ex"] = "Weapon classname (ex: weapon_crowbar)",
    ["admin.hint.exact_phrase"]    = "Frase exata",
    ["admin.hint.case_sensitive"]  = "Case sensitive? (true/false)",
    ["admin.hint.playtime_hours"]  = "Horas de playtime",
    ["admin.hint.total_kills"]     = "Total de kills",
    ["admin.hint.total_killbinds"] = "Total de killbinds",
    ["admin.hint.minutes_no_kill_die"] = "Minutos sem matar/morrer",
    ["admin.hint.total_kills_loners"] = "Total de kills loners",
    ["admin.hint.minutes_dead"]    = "Minutos morto antes de respawnar",
    ["admin.hint.hours_allowed"]   = "Horas permitidas (ex: 3,6)",
    ["admin.hint.hours_short"]     = "Horas",
    ["admin.webhook_button"]           = "DISCORD",
    ["admin.webhook_title"]            = "WEBHOOKS DO DISCORD",
    ["admin.webhook_add_label"]        = "Adicionar novo webhook",
    ["admin.webhook_url_hint"]         = "Depois de salvar um webhook você não conseguirá ver a URL dele de novo — só é possível ativar, desativar ou excluir.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "ADICIONAR",
    ["admin.webhook_requires_reqwest"] = "Requer o módulo binário reqwest no servidor.",
    ["admin.webhook_list_label"]       = "Webhooks configurados",
    ["admin.webhook_empty"]            = "Nenhum webhook configurado ainda.",
    ["admin.webhook_added_by"]         = "Adicionado por %s",
    ["admin.webhook_active"]           = "Ativo",
    ["admin.webhook_inactive"]         = "Inativo",
    ["admin.webhook_activate"]         = "ATIVAR",
    ["admin.webhook_deactivate"]       = "DESATIVAR",
    ["admin.webhook_delete"]           = "EXCLUIR",
    ["admin.webhook_delete_confirm"]   = "Excluir este webhook? Isso não pode ser desfeito.",
    ["admin.webhook_invalid_url"]      = "Isso não parece uma URL de webhook do Discord.",
    ["admin.webhook_action_failed"]    = "Isso não funcionou. Tente novamente.",
    ["admin.lang_button"]          = "IDIOMA",
    ["admin.lang_panel_title"]     = "IDIOMA",
    ["admin.lang_panel_subtitle"]  = "Escolha o idioma padrão do addon e edite qualquer string manualmente.",
    ["admin.lang_search_placeholder"] = "Buscar por chave ou texto...",
    ["admin.lang_save"]            = "SALVAR",
    ["admin.lang_reset"]           = "PADRÃO",
    ["admin.lang_selector_title"]  = "IDIOMA PADRÃO DO SERVIDOR",
    ["admin.lang_selector_hint"]   = "Isso vale pra TODO jogador do servidor que não escolheu um idioma pessoal no próprio Profile dele.",
    ["admin.lang_current_status"]  = "O idioma padrão do servidor está definido como: %s",

    ["sublabel.reach_playtime_hours"]   = "Horas de playtime",
    ["sublabel.total_kills_x"]          = "Total de kills",
    ["sublabel.total_killbind_x"]       = "Killbinds usadas",
    ["sublabel.spawn_x_entity_y_times"] = "Props spawnados",
    ["sublabel.kill_x_with_weapon"]     = "Kills com arma",
})

Lang.RegisterPreset("es", {
    -- menu
    ["chat.command"]               = "logros",
    ["menu.title"]                 = "LOGROS",
    ["menu.my_profile"]            = "MI PERFIL",
    ["menu.staff_panel"]           = "PANEL DE STAFF",
    ["menu.use_server_default"]    = "Usar idioma predeterminado del servidor",
    ["profile.language"]           = "IDIOMA",
    ["menu.search_placeholder"]    = "Buscar logro...",
    ["menu.badge_unlocked"]        = "DESBLOQUEADO",
    ["menu.badge_locked"]          = "BLOQUEADO",
    ["menu.requirements"]          = "REQUISITOS",
    ["menu.percent_have_players"]  = "%.1f%% de los jugadores tienen este logro",
    ["menu.page_info"]             = "Página %d / %d  (%d logros)",
    ["filter.rarity.all"]          = "TODAS",
    ["filter.rarity.common"]       = "COMÚN",
    ["filter.rarity.uncommon"]     = "POCO COMÚN",
    ["filter.rarity.rare"]         = "RARO",
    ["filter.rarity.epic"]         = "ÉPICO",
    ["filter.rarity.legendary"]    = "LEGENDARIO",
    ["filter.rarity.secret"]       = "SECRETO",
    ["filter.state.all"]           = "TODOS",
    ["filter.state.unlocked"]      = "TENGO",
    ["filter.state.locked"]        = "FALTAN",

    ["rarity.common"]              = "Común",
    ["rarity.uncommon"]            = "Poco común",
    ["rarity.rare"]                = "Raro",
    ["rarity.epic"]                = "Épico",
    ["rarity.legendary"]           = "Legendario",
    ["rarity.secret"]              = "Secreto",

    ["hud.unlocked_title"]         = "LOGRO DESBLOQUEADO",
    ["hud.percent_have_short"]     = "%.1f%% de jugadores",

    ["chat.prefix"]                = "[Logros]",
    ["chat.secret_got_named"]      = " desbloqueó un logro secreto: ",
    ["chat.secret_got_hidden"]     = " ¡desbloqueó un logro secreto!",
    ["chat.unlocked"]              = " desbloqueó: ",

    ["profile.kills"]              = "BAJAS",
    ["profile.deaths"]             = "MUERTES",
    ["profile.unlocked_section"]   = "LOGROS DESBLOQUEADOS",
    ["profile.none_unlocked"]      = "Aún no hay logros desbloqueados.",
    ["profile.cache_privacy"]      = "CACHÉ Y PRIVACIDAD",
    ["profile.cache_on"]           = "Caché: ACTIVO",
    ["profile.cache_off"]          = "Caché: DESACTIVADO",
    ["profile.clear_cache"]        = "LIMPIAR CACHÉ",
    ["profile.reset_confirm"]      = "¿CONFIRMAR REINICIO? (clic de nuevo)",
    ["profile.reset_progress"]     = "REINICIAR PROGRESO",

    ["admin.panel_title"]          = "ADMIN · LOGROS",
    ["admin.tab_achievements"]     = "LOGROS",
    ["admin.new_achievement"]      = "+ NUEVO LOGRO",
    ["admin.id_label"]             = "ID del Logro",
    ["admin.name_label"]           = "Nombre",
    ["admin.name_placeholder"]     = "Ej: En Llamas",
    ["admin.desc_label"]           = "Descripción",
    ["admin.desc_placeholder"]     = "Ej: Consigue 5 bajas seguidas",
    ["admin.thumb_label"]          = "URL de miniatura (opcional)",
    ["admin.rarity_label"]         = "Rareza",
    ["admin.secret_label"]         = "¿Secreto?",
    ["admin.trigger_type_label"]   = "Tipo de Disparador",
    ["admin.sub_requirements"]     = "Sub-Requisitos (todos deben cumplirse)",
    ["admin.remove"]               = "✕ QUITAR",
    ["admin.add_sub_requirement"]  = "+  AGREGAR SUB-REQUISITO",
    ["admin.select_entity_world"]  = "⊕  SELECCIONAR ENTIDAD EN EL MUNDO",
    ["admin.set_id_first"]         = "[DuckAch] Define el ID primero.",
    ["admin.save_achievement"]     = "✓  GUARDAR LOGRO",
    ["admin.id_name_required"]     = "[DuckAch] ID y Nombre son obligatorios.",
    ["admin.edit"]                 = "EDITAR",
    ["admin.delete_short"]         = "DEL",

    ["admin.hint.steamid_killer"]  = "SteamID del asesino (o ADMIN)",
    ["admin.hint.model_path"]      = "Ruta del modelo",
    ["admin.hint.model_path_any"]  = "Ruta del modelo (vacío/any = cualquier prop)",
    ["admin.hint.quantity_number"] = "Cantidad (número)",
    ["admin.hint.quantity"]        = "Cantidad",
    ["admin.hint.usergroup_name"]  = "Nombre del usergroup",
    ["admin.hint.classname_killer"]= "Classname del asesino",
    ["admin.hint.entid_picker"]    = "EntId (usa el picker abajo)",
    ["admin.hint.kills_needed"]    = "Bajas necesarias (número)",
    ["admin.hint.kills_number"]    = "Bajas (número)",
    ["admin.hint.weapon_classname"]= "Weapon classname",
    ["admin.hint.weapon_classname_ex"] = "Weapon classname (ej: weapon_crowbar)",
    ["admin.hint.exact_phrase"]    = "Frase exacta",
    ["admin.hint.case_sensitive"]  = "¿Distingue mayúsculas? (true/false)",
    ["admin.hint.playtime_hours"]  = "Horas de juego",
    ["admin.hint.total_kills"]     = "Total de bajas",
    ["admin.hint.total_killbinds"] = "Total de killbinds",
    ["admin.hint.minutes_no_kill_die"] = "Minutos sin matar/morir",
    ["admin.hint.total_kills_loners"] = "Total de bajas a solitarios",
    ["admin.hint.minutes_dead"]    = "Minutos muerto antes de reaparecer",
    ["admin.hint.hours_allowed"]   = "Horas permitidas (ej: 3,6)",
    ["admin.hint.hours_short"]     = "Horas",
    ["admin.webhook_button"]           = "DISCORD",
    ["admin.webhook_title"]            = "WEBHOOKS DE DISCORD",
    ["admin.webhook_add_label"]        = "Agregar nuevo webhook",
    ["admin.webhook_url_hint"]         = "Después de guardar un webhook no podrás ver su URL de nuevo — solo puedes activarlo, desactivarlo o eliminarlo.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "AGREGAR",
    ["admin.webhook_requires_reqwest"] = "Requiere el módulo binario reqwest en el servidor.",
    ["admin.webhook_list_label"]       = "Webhooks configurados",
    ["admin.webhook_empty"]            = "Aún no hay webhooks configurados.",
    ["admin.webhook_added_by"]         = "Agregado por %s",
    ["admin.webhook_active"]           = "Activo",
    ["admin.webhook_inactive"]         = "Inactivo",
    ["admin.webhook_activate"]         = "ACTIVAR",
    ["admin.webhook_deactivate"]       = "DESACTIVAR",
    ["admin.webhook_delete"]           = "ELIMINAR",
    ["admin.webhook_delete_confirm"]   = "¿Eliminar este webhook? Esto no se puede deshacer.",
    ["admin.webhook_invalid_url"]      = "Eso no parece una URL de webhook de Discord.",
    ["admin.webhook_action_failed"]    = "Eso no funcionó. Intenta de nuevo.",
    ["admin.lang_button"]          = "IDIOMA",
    ["admin.lang_panel_title"]     = "IDIOMA",
    ["admin.lang_panel_subtitle"]  = "Elige el idioma predeterminado del addon y edita cualquier string manualmente.",
    ["admin.lang_search_placeholder"] = "Buscar por clave o texto...",
    ["admin.lang_save"]            = "GUARDAR",
    ["admin.lang_reset"]           = "PREDETERMINADO",
    ["admin.lang_selector_title"]  = "IDIOMA PREDETERMINADO DEL SERVIDOR",
    ["admin.lang_selector_hint"]   = "Esto aplica a TODOS los jugadores del servidor que no hayan elegido un idioma personal en su propio Profile.",
    ["admin.lang_current_status"]  = "El idioma predeterminado del servidor está en: %s",

    ["sublabel.reach_playtime_hours"]   = "Horas de juego",
    ["sublabel.total_kills_x"]          = "Total de bajas",
    ["sublabel.total_killbind_x"]       = "Killbinds usadas",
    ["sublabel.spawn_x_entity_y_times"] = "Props generados",
    ["sublabel.kill_x_with_weapon"]     = "Bajas con arma",
})
