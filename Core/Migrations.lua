local _, ts = ...

local ipairs = ipairs

ts.Migrations = {}
ts.Migrations.CURRENT_VERSION = 3

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

-- v1 -> v2: Add spellId to each talent entry from TalentResolver
RegisterMigration(1, function(sequence)
    if not ts.TalentResolver or not sequence.classToken then return false end

    for _, talent in ipairs(sequence.talents) do
        if not talent.spellId then
            talent.spellId = ts.TalentResolver.GetSpellId(
                sequence.classToken, talent.tab, talent.index, talent.rank)
        end
    end
    return true
end)

-- v2 -> v3: Add stable sequence ids for per-spec assignments
RegisterMigration(2, function(sequence)
    if not sequence.id then
        sequence.id = ts.DB.GetNextSequenceId()
    end
    return true
end)
