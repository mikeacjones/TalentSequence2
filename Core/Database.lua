local _, ts = ...

local tinsert = tinsert
local UnitClass = UnitClass
local GetActiveTalentGroup = GetActiveTalentGroup
local GetNumTalentGroups = GetNumTalentGroups

ts.DB = {}

ts.tooltip = CreateFrame("GameTooltip", "TalentPlannerTooltip", UIParent,
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
    if (not TalentPlannerAccountSavedSequences) then
        TalentPlannerAccountSavedSequences = {}
    end
    return TalentPlannerAccountSavedSequences
end

function ts.DB.GetCollapsedClassStore()
    if (not TalentPlannerAccountCollapsedClasses) then
        TalentPlannerAccountCollapsedClasses = {}
    end
    return TalentPlannerAccountCollapsedClasses
end

function ts.DB.GetNextSequenceId()
    if (not TalentPlannerAccountNextSequenceId or TalentPlannerAccountNextSequenceId < 1) then
        TalentPlannerAccountNextSequenceId = 1
    end
    local nextId = TalentPlannerAccountNextSequenceId
    TalentPlannerAccountNextSequenceId = nextId + 1
    return nextId
end

function ts.DB.GetActiveSequenceAssignmentStore()
    if (type(TalentPlannerActiveSequenceIds) ~= "table") then
        TalentPlannerActiveSequenceIds = {}
    end
    return TalentPlannerActiveSequenceIds
end

function ts.DB.GetNumSpecSlots()
    if (type(GetNumTalentGroups) == "function") then
        local groups = GetNumTalentGroups()
        if (type(groups) == "number" and groups > 0) then
            return groups
        end
    end
    return 1
end

function ts.DB.GetActiveSpecSlot()
    if (type(GetActiveTalentGroup) == "function") then
        local activeGroup = GetActiveTalentGroup()
        if (type(activeGroup) == "number" and activeGroup > 0) then
            return activeGroup
        end
    end
    return 1
end

function ts.DB.GetSequenceById(sequenceId)
    if (not sequenceId) then return nil end
    for _, sequence in ipairs(ts.DB.GetSequenceStore()) do
        if (sequence.id == sequenceId) then
            return sequence
        end
    end
    return nil
end

function ts.DB.FindSequenceByTalents(talents)
    if (type(talents) ~= "table") then return nil end
    for _, sequence in ipairs(ts.DB.GetSequenceStore()) do
        if (ts.DB.SequencesEqual(sequence.talents, talents)) then
            return sequence
        end
    end
    return nil
end

function ts.DB.GetAssignedSequenceId(specSlot)
    return ts.DB.GetActiveSequenceAssignmentStore()[specSlot or ts.DB.GetActiveSpecSlot()]
end

function ts.DB.GetAssignedSequence(specSlot)
    return ts.DB.GetSequenceById(ts.DB.GetAssignedSequenceId(specSlot))
end

function ts.DB.AssignSequenceToSpec(sequence, specSlot)
    if (not sequence or not sequence.id) then return end
    ts.DB.GetActiveSequenceAssignmentStore()[specSlot or ts.DB.GetActiveSpecSlot()] = sequence.id
end

function ts.DB.ClearAssignedSequence(specSlot)
    ts.DB.GetActiveSequenceAssignmentStore()[specSlot or ts.DB.GetActiveSpecSlot()] = nil
end

function ts.DB.ClearSequenceAssignments(sequenceId)
    if (not sequenceId) then return end
    local assignments = ts.DB.GetActiveSequenceAssignmentStore()
    for specSlot, assignedId in pairs(assignments) do
        if (assignedId == sequenceId) then
            assignments[specSlot] = nil
        end
    end
end

function ts.DB.GetSequenceAssignedSpecSlots(sequenceId)
    local assignedSlots = {}
    if (not sequenceId) then return assignedSlots end
    for specSlot = 1, ts.DB.GetNumSpecSlots() do
        if (ts.DB.GetAssignedSequenceId(specSlot) == sequenceId) then
            tinsert(assignedSlots, specSlot)
        end
    end
    return assignedSlots
end

function ts.DB.GetSequenceAssignmentLabel(sequenceId)
    local specSlots = ts.DB.GetSequenceAssignedSpecSlots(sequenceId)
    if (#specSlots == 0 or ts.DB.GetNumSpecSlots() <= 1) then
        return nil
    end

    local labels = {}
    for _, specSlot in ipairs(specSlots) do
        tinsert(labels, "S" .. specSlot)
    end
    return table.concat(labels, ",")
end

function ts.DB.EnsureSequenceMetadata(sequence, defaultClassToken)
    if (type(sequence) ~= "table") then return end
    if (not sequence.id) then
        sequence.id = ts.DB.GetNextSequenceId()
    end
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

    if (TalentPlannerSavedSequences and #TalentPlannerSavedSequences > 0) then
        for _, sequence in ipairs(TalentPlannerSavedSequences) do
            ts.DB.EnsureSequenceMetadata(sequence, playerClassToken)
            tinsert(sequenceStore, sequence)
        end
        TalentPlannerSavedSequences = {}
    end

    for _, sequence in ipairs(sequenceStore) do
        ts.DB.EnsureSequenceMetadata(sequence, playerClassToken)
    end

    ts.Migrations.RunAll()

    local assignmentStore = ts.DB.GetActiveSequenceAssignmentStore()
    local hasAssignments = false
    for _, assignedId in pairs(assignmentStore) do
        if (assignedId) then
            hasAssignments = true
            break
        end
    end

    if (not hasAssignments and TalentPlannerTalents and #TalentPlannerTalents > 0) then
        local activeSequence = ts.DB.FindSequenceByTalents(TalentPlannerTalents)
        if (not activeSequence) then
            activeSequence = ts.DB.InsertSequence(TalentPlannerTalents, playerClassToken)
        end
        if (activeSequence) then
            ts.DB.AssignSequenceToSpec(activeSequence, ts.DB.GetActiveSpecSlot())
        end
    end

    if (TalentPlannerTalents and #TalentPlannerTalents > 0) then
        for _, sequence in ipairs(sequenceStore) do
            if (ts.DB.SequencesEqual(sequence.talents, TalentPlannerTalents)) then
                TalentPlannerTalents = sequence.talents
                break
            end
        end
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
        classToken = classToken or ts.DB.GetPlayerClassToken(),
        id = ts.DB.GetNextSequenceId(),
        version = ts.Migrations and ts.Migrations.CURRENT_VERSION or 1
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
