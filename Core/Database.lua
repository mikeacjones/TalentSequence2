local _, ts = ...

local tinsert = tinsert
local UnitClass = UnitClass

ts.DB = {}

ts.tooltip = CreateFrame("GameTooltip", "TalentSequenceTooltip", UIParent,
                          "GameTooltipTemplate")

function ts.DB.GetPlayerClassToken()
    local _, classToken = UnitClass("player")
    return classToken
end

function ts.DB.GetClassDisplayName(classToken)
    if (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) then
        return LOCALIZED_CLASS_NAMES_MALE[classToken]
    end
    if (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken]) then
        return LOCALIZED_CLASS_NAMES_FEMALE[classToken]
    end
    return classToken or "Unknown"
end

function ts.DB.GetSequenceStore()
    if (not TalentSequenceAccountSavedSequences) then
        TalentSequenceAccountSavedSequences = {}
    end
    return TalentSequenceAccountSavedSequences
end

function ts.DB.GetCollapsedClassStore()
    if (not TalentSequenceAccountCollapsedClasses) then
        TalentSequenceAccountCollapsedClasses = {}
    end
    return TalentSequenceAccountCollapsedClasses
end

function ts.DB.EnsureSequenceMetadata(sequence, defaultClassToken)
    if (type(sequence) ~= "table") then return end
    if (not sequence.classToken) then
        sequence.classToken = defaultClassToken
    end
    if (not sequence.className) then
        sequence.className = ts.DB.GetClassDisplayName(sequence.classToken)
    end
end

function ts.DB.MigrateSavedSequences()
    local playerClassToken = ts.DB.GetPlayerClassToken()
    local sequenceStore = ts.DB.GetSequenceStore()

    if (TalentSequenceSavedSequences and #TalentSequenceSavedSequences > 0) then
        for _, sequence in ipairs(TalentSequenceSavedSequences) do
            ts.DB.EnsureSequenceMetadata(sequence, playerClassToken)
            tinsert(sequenceStore, sequence)
        end
        TalentSequenceSavedSequences = {}
    end

    for _, sequence in ipairs(sequenceStore) do
        ts.DB.EnsureSequenceMetadata(sequence, playerClassToken)
    end
end

function ts.DB.InsertSequence(talentSequence, classToken)
    local tabTotals = {0, 0, 0}
    for _, talent in ipairs(talentSequence) do
        tabTotals[talent.tab] = tabTotals[talent.tab] + 1
    end
    local points = string.format("%d/%d/%d", unpack(tabTotals))
    local sequence = {
        name = "<unnamed>",
        talents = talentSequence,
        points = points,
        classToken = classToken or ts.DB.GetPlayerClassToken()
    }
    ts.DB.EnsureSequenceMetadata(sequence, ts.DB.GetPlayerClassToken())
    tinsert(ts.DB.GetSequenceStore(), 1, sequence)
    return sequence
end

function ts.DB.SequencesEqual(left, right)
    if (left == right) then return true end
    if (type(left) ~= "table" or type(right) ~= "table") then return false end
    if (#left ~= #right) then return false end
    for index = 1, #left do
        local l = left[index]
        local r = right[index]
        if (type(l) ~= "table" or type(r) ~= "table") then return false end
        if (l.tab ~= r.tab or l.index ~= r.index or l.rank ~= r.rank or l.level ~= r.level) then
            return false
        end
    end
    return true
end
