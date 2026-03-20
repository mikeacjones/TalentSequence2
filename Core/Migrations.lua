local _, ts = ...

local ipairs = ipairs
local GetTalentInfo = GetTalentInfo

ts.Migrations = {}
ts.Migrations.CURRENT_VERSION = 2

local CURRENT_VERSION = ts.Migrations.CURRENT_VERSION

local stages = {}

local function RegisterMigration(fromVersion, fn)
    stages[fromVersion] = fn
end

function ts.Migrations.Run(sequence)
    if not sequence or not sequence.talents then return end
    local version = sequence.version or 1
    while version < CURRENT_VERSION do
        local migrate = stages[version]
        if not migrate then break end
        if not migrate(sequence) then break end
        version = version + 1
        sequence.version = version
    end
end

function ts.Migrations.RunAll()
    for _, sequence in ipairs(ts.DB.GetSequenceStore()) do
        ts.Migrations.Run(sequence)
    end
end

-- v1 -> v2: Add spellId to each talent entry from WowheadData
-- Only runs for sequences matching the current player's class since
-- GetTalentInfo only returns names for the logged-in class. Other-class
-- sequences will be migrated when that class logs in.
RegisterMigration(1, function(sequence)
    if not ts.WowheadData or not sequence.classToken then return false end
    if sequence.classToken ~= ts.DB.GetPlayerClassToken() then return false end

    local flavorKey = nil
    for key in pairs(ts.WowheadData) do
        if ts.WowheadData[key][sequence.classToken] then
            flavorKey = key
            break
        end
    end
    if not flavorKey then return false end

    local classMap = ts.WowheadData[flavorKey][sequence.classToken]
    if not classMap then return false end

    -- Build reverse lookup: (tab, talentName) -> wowhead entry
    local nameLookup = {}
    for tab, talents in pairs(classMap) do
        nameLookup[tab] = {}
        for _, entry in pairs(talents) do
            nameLookup[tab][entry.name] = entry
        end
    end

    for _, talent in ipairs(sequence.talents) do
        if not talent.spellId then
            local tabLookup = nameLookup[talent.tab - 1]
            if tabLookup then
                local name = GetTalentInfo(talent.tab, talent.index)
                if name then
                    local entry = tabLookup[name]
                    if entry and entry.ranks and entry.ranks[talent.rank] then
                        talent.spellId = entry.ranks[talent.rank]
                    end
                end
            end
        end
    end
    return true
end)
