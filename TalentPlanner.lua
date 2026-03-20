local addonName, ts = ...

local hooksecurefunc = hooksecurefunc
IsTalentPlannerExpanded = false
TalentPlannerTalents = {}

local DEFAULT_CONFIG = {
    talentFrameName = "PlayerTalentFrame",
    trackerAnchors = {
        {"TOPLEFT", "TOPRIGHT", -36, -12},
        {"BOTTOMLEFT", "BOTTOMRIGHT", 0, 72},
    },
    trackerBackdrop = {
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    },
    showButtonAnchor = {"TOPRIGHT", -120, -16},
    showButtonHeight = 18,
}

local initRun = false
local function init(frameConfig)
    if (initRun) then return end
    ts.FrameConfig = frameConfig
    if (not TalentPlannerTalents) then TalentPlannerTalents = {} end
    if (not TalentPlannerSavedSequences) then
        TalentPlannerSavedSequences = {}
    end
    ts.DB.GetSequenceStore()
    ts.DB.GetCollapsedClassStore()
    ts.DB.GetActiveSequenceAssignmentStore()
    ts.DB.MigrateSavedSequences()
    if (#TalentPlannerTalents > 0 and #ts.DB.GetSequenceStore() == 0) then
        ts.DB.InsertSequence(TalentPlannerTalents, ts.DB.GetPlayerClassToken())
    end
    ts.Talents = {}
    if (IsTalentPlannerExpanded == 0) then IsTalentPlannerExpanded = false end
    if (ts.MainFrame == nil) then ts.CreateMainFrame() end
    ts:LoadAssignedSequenceForCurrentSpec()
    initRun = true
end

hooksecurefunc("ToggleTalentFrame", function(...)
    if (PlayerTalentFrame == nil) then return end
    if (initRun) then return end
    init(DEFAULT_CONFIG)
end)
