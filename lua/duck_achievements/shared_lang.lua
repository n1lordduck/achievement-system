--// DuckAch.Lang
--// The addon's language system. Covers ONLY the INTERFACE text (menus,
--// HUD, admin panel, chat). Custom achievements are still registered by
--// the admin in whatever language they want (not auto-translated).
--//
--// Two levels:
--//   - Lang.Current     -> the SERVER DEFAULT language, set by the admin,
--//                         synced from the server to everyone.
--//   - Lang.PlayerPref   -> the player's PERSONAL language (only exists on the
--//                         client, saved locally), takes priority over the
--//                         server default when the player picks one.
--//
--// Effective-language resolution (client): PlayerPref -> Current -> Default(en)
--// Effective-language resolution (server, per player): via Lang.EffectiveFor(ply)
--//
--// Text layers (descending priority) within a language:
--//   1. Overrides   -> edited by the admin in the panel, persisted to data/
--//   2. Presets     -> translations shipped with the addon (en/es/pt-br)
--//   3. Fallback    -> the default language's preset (en), then the key itself
--//
--// Usage:  DuckAch.L("menu.title")
--//         DuckAch.L("menu.page_info", page, totalPages)

DuckAch = DuckAch or {}
DuckAch.Lang = DuckAch.Lang or {}

local Lang = DuckAch.Lang

Lang.Available = { "en", "es", "pt-br" }   --// languages with a built-in preset
Lang.Default   = "en"                      --// factory default: English
Lang.Current   = Lang.Current or Lang.Default  --// server default (admin)
Lang.PlayerPref = Lang.PlayerPref or nil       --// personal language (CLIENT only)

Lang.Presets   = Lang.Presets   or {}      --// [langcode][key] = string
Lang.Overrides = Lang.Overrides or {}      --// [langcode][key] = string (persisted)

--// Registers (or merges) a block of translations for a language.
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

--// The language that should be used right now, in this realm.
--// CLIENT: player's personal preference (if set) > server default
--// SERVER: always the server default (use Lang.EffectiveFor(ply) for a specific player)
function Lang.EffectiveLanguage()
    if CLIENT and Lang.PlayerPref and Lang.IsValidLanguage(Lang.PlayerPref) then
        return Lang.PlayerPref
    end
    return Lang.Current
end

--// All known keys (union of every preset) - used by the admin panel
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

--// Raw value (no string.format) of a key, in a specific language or the effective one.
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

--// Final string, already with string.format applied if varargs were passed.
--// If the key doesn't exist in any language, returns "[[key]]" to make debugging easier.
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

--// Same as Get, but forcing a specific language (used by the server to
--// send text already translated into ONE specific player's personal language).
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

--// Short global shortcut
DuckAch.L = Lang.Get

--// Built-in presets
--// pt-br is the addon's "original" translation (the same thing that already existed).
--// en is the default language. es is the Spanish translation.

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
    ["menu.page_info"]             = "%d / %d",
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
    ["achievement.secret_name"]        = "???",
    ["achievement.secret_description"] = "Secret achievement. Figure out how to unlock it.",
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
    ["profile.reset_done"]         = "[DuckAch] Progress reset. Your unlocked achievements were kept.",
    ["profile.kd_ratio"]           = "K/D",

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
    ["admin.picker_link_prompt"]   = "[DuckAch Admin] Left click an entity to link it to achievement %s. Right click = check current ID.",
    ["admin.picker_warning_prop"]  = "[DuckAch] WARNING: This is a spawned prop. The link will NOT persist across server restarts.",
    ["admin.picker_warning_permaprops"] = "[DuckAch] Use the PermaProp addon to make it permanent before linking.",
    ["admin.picker_id_known"]      = "[DuckAch] ID: %s",
    ["admin.picker_id_unknown"]    = "[DuckAch] No ID yet. Left click to set one.",
    ["admin.picker_no_permission"] = "[DuckAch] You don't have permission to use this tool.",
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
    ["admin.webhook_url_hint"]         = "Once you save a webhook you won't be able to view its URL again - you can only activate, deactivate, or delete it.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "ADD",
    ["admin.webhook_requires_reqwest"] = "Requires the reqwest binary module on the server.",
    ["admin.webhook_reqwest_missing"]  = "The reqwest module wasn't found on this server. Webhooks are saved but won't send anything until it's installed.",
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
    ["admin.noscope_button"]       = "NOSCOPE",
    ["admin.noscope_title"]        = "NOSCOPE 360 - VALID WEAPONS",
    ["admin.noscope_subtitle"]     = "Choose which weapons count for the Noscope 360 achievement.",
    ["admin.noscope_search_placeholder"] = "Search weapon...",
    ["admin.noscope_save"]         = "SAVE",
    ["admin.noscope_empty"]        = "No weapons found on this server.",
    ["admin.noscope_saved"]        = "Noscope weapon list saved.",
    ["admin.erase_all_profiles_done"] = "[DuckAch] All profiles erased (%d players).",
    ["admin.erase_everything_done"]   = "[DuckAch] Everything erased: profiles, custom achievements, marked entities.",
    ["admin.grant_all_done"]          = "[DuckAch] %d achievement(s) granted to %s.",

    -- generic dialog buttons
    ["common.yes"]                 = "Yes",
    ["common.cancel"]              = "Cancel",
    ["common.ok"]                  = "OK",

    -- progress sub-labels (BuildProgress on the server)
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
    ["menu.page_info"]             = "%d / %d",
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
    ["achievement.secret_name"]        = "???",
    ["achievement.secret_description"] = "Conquista secreta. Descubra como desbloqueá-la.",
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
    ["profile.reset_done"]         = "[DuckAch] Progresso resetado. Suas conquistas desbloqueadas foram mantidas.",
    ["profile.kd_ratio"]           = "K/D",

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
    ["admin.picker_link_prompt"]   = "[DuckAch Admin] Clique com o botão esquerdo em uma entidade para vinculá-la à conquista %s. Botão direito = ver o ID atual.",
    ["admin.picker_warning_prop"]  = "[DuckAch] AVISO: Isso é um prop spawnado. O vínculo NÃO vai persistir após reiniciar o servidor.",
    ["admin.picker_warning_permaprops"] = "[DuckAch] Use o addon PermaProp para torná-lo permanente antes de vincular.",
    ["admin.picker_id_known"]      = "[DuckAch] ID: %s",
    ["admin.picker_id_unknown"]    = "[DuckAch] Ainda sem ID. Clique com o botão esquerdo para definir um.",
    ["admin.picker_no_permission"] = "[DuckAch] Você não tem permissão para usar essa ferramenta.",
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
    ["admin.webhook_url_hint"]         = "Depois de salvar um webhook você não conseguirá ver a URL dele de novo - só é possível ativar, desativar ou excluir.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "ADICIONAR",
    ["admin.webhook_requires_reqwest"] = "Requer o módulo binário reqwest no servidor.",
    ["admin.webhook_reqwest_missing"]  = "O módulo reqwest não foi encontrado neste servidor. Os webhooks são salvos, mas não vão enviar nada até ele ser instalado.",
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
    ["admin.noscope_button"]       = "NOSCOPE",
    ["admin.noscope_title"]        = "NOSCOPE 360 - ARMAS VÁLIDAS",
    ["admin.noscope_subtitle"]     = "Escolha quais armas contam para a conquista Noscope 360.",
    ["admin.noscope_search_placeholder"] = "Buscar arma...",
    ["admin.noscope_save"]         = "SALVAR",
    ["admin.noscope_empty"]        = "Nenhuma arma encontrada neste servidor.",
    ["admin.noscope_saved"]        = "Lista de armas do noscope salva.",
    ["admin.erase_all_profiles_done"] = "[DuckAch] Todos os perfis foram apagados (%d jogadores).",
    ["admin.erase_everything_done"]   = "[DuckAch] Tudo apagado: perfis, conquistas customizadas, entidades marcadas.",
    ["admin.grant_all_done"]          = "[DuckAch] %d conquista(s) concedida(s) a %s.",

    ["common.yes"]                 = "Sim",
    ["common.cancel"]              = "Cancelar",
    ["common.ok"]                  = "OK",

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
    ["menu.page_info"]             = "%d / %d",
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
    ["achievement.secret_name"]        = "???",
    ["achievement.secret_description"] = "Logro secreto. Descubre cómo desbloquearlo.",
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
    ["profile.reset_done"]         = "[DuckAch] Progreso reiniciado. Tus logros desbloqueados se mantuvieron.",
    ["profile.kd_ratio"]           = "K/D",

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
    ["admin.picker_link_prompt"]   = "[DuckAch Admin] Clic izquierdo en una entidad para vincularla al logro %s. Clic derecho = ver el ID actual.",
    ["admin.picker_warning_prop"]  = "[DuckAch] ADVERTENCIA: Esto es un prop generado. El vínculo NO persistirá tras reiniciar el servidor.",
    ["admin.picker_warning_permaprops"] = "[DuckAch] Usa el addon PermaProp para hacerlo permanente antes de vincularlo.",
    ["admin.picker_id_known"]      = "[DuckAch] ID: %s",
    ["admin.picker_id_unknown"]    = "[DuckAch] Todavía no tiene ID. Clic izquierdo para asignar uno.",
    ["admin.picker_no_permission"] = "[DuckAch] No tienes permiso para usar esta herramienta.",
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
    ["admin.webhook_url_hint"]         = "Después de guardar un webhook no podrás ver su URL de nuevo - solo puedes activarlo, desactivarlo o eliminarlo.",
    ["admin.webhook_url_placeholder"]  = "https://discord.com/api/webhooks/...",
    ["admin.webhook_add"]              = "AGREGAR",
    ["admin.webhook_requires_reqwest"] = "Requiere el módulo binario reqwest en el servidor.",
    ["admin.webhook_reqwest_missing"]  = "No se encontró el módulo reqwest en este servidor. Los webhooks se guardan, pero no enviarán nada hasta que se instale.",
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
    ["admin.noscope_button"]       = "NOSCOPE",
    ["admin.noscope_title"]        = "NOSCOPE 360 - ARMAS VÁLIDAS",
    ["admin.noscope_subtitle"]     = "Elige qué armas cuentan para el logro Noscope 360.",
    ["admin.noscope_search_placeholder"] = "Buscar arma...",
    ["admin.noscope_save"]         = "GUARDAR",
    ["admin.noscope_empty"]        = "No se encontraron armas en este servidor.",
    ["admin.noscope_saved"]        = "Lista de armas del noscope guardada.",
    ["admin.erase_all_profiles_done"] = "[DuckAch] Todos los perfiles fueron borrados (%d jugadores).",
    ["admin.erase_everything_done"]   = "[DuckAch] Todo borrado: perfiles, logros personalizados, entidades marcadas.",
    ["admin.grant_all_done"]          = "[DuckAch] %d logro(s) otorgado(s) a %s.",

    ["common.yes"]                 = "Sí",
    ["common.cancel"]              = "Cancelar",
    ["common.ok"]                  = "OK",

    ["sublabel.reach_playtime_hours"]   = "Horas de juego",
    ["sublabel.total_kills_x"]          = "Total de bajas",
    ["sublabel.total_killbind_x"]       = "Killbinds usadas",
    ["sublabel.spawn_x_entity_y_times"] = "Props generados",
    ["sublabel.kill_x_with_weapon"]     = "Bajas con arma",
})
