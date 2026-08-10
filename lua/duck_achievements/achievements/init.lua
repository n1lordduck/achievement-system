local achFiles = {
    "duck_achievements/achievements/kills.lua",
    "duck_achievements/achievements/social.lua",
    "duck_achievements/achievements/playtime.lua",
    "duck_achievements/achievements/spawn.lua",
    "duck_achievements/achievements/explore.lua",
    "duck_achievements/achievements/misc.lua",
}

for _, f in ipairs(achFiles) do
    if SERVER then AddCSLuaFile(f) end
    include(f)
end

DuckAchLogger.info("Achievements defined: " .. DuckAch.Registry.Count())
