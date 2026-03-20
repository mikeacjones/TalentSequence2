local addonName, ts = ...

local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame

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
    managerParentToTalentFrame = false,
    raiseManagerOnShow = false,
}

local TALENTED_CONFIG = {
    talentFrameName = "TalentedFrame",
    trackerAnchors = {
        {"TOPLEFT", "TOPRIGHT", 0, 0},
        {"BOTTOMLEFT", "TOPRIGHT", 0, -450},
    },
    trackerBackdrop = {
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 3, right = 5, top = 3, bottom = 5},
    },
    showButtonAnchor = {"TOPRIGHT", -100, -4},
    showButtonHeight = nil,
    managerParentToTalentFrame = true,
    raiseManagerOnShow = true,
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
    ts.DB.MigrateSavedSequences()
    if (#TalentPlannerTalents > 0 and #ts.DB.GetSequenceStore() == 0) then
        ts.DB.InsertSequence(TalentPlannerTalents, ts.DB.GetPlayerClassToken())
    end
    ts.Talents = TalentPlannerTalents
    if (IsTalentPlannerExpanded == 0) then IsTalentPlannerExpanded = false end
    if (ts.MainFrame == nil) then ts.CreateMainFrame() end
    initRun = true
end

local function hookTalented(Talented)
    if Talented then
        hooksecurefunc(Talented, "ToggleTalentFrame", function()
            if (initRun) then return end
            init(TALENTED_CONFIG)
        end)
    end
end

-- C_AddOns was introduced in Classic 1.15.x; fall back to the old globals for
-- older clients so the same file works across patch versions.
local _GetAddOnInfo        = (C_AddOns and C_AddOns.GetAddOnInfo)        or GetAddOnInfo
local _GetAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or GetAddOnEnableState
local _IsAddOnLoaded       = (C_AddOns and C_AddOns.IsAddOnLoaded)       or IsAddOnLoaded

local _,_,_,talented_loadable, talented_error = _GetAddOnInfo("Talented")
if talented_loadable and not (talented_error == "MISSING" or talented_error == "DISABLED") then
    local Talented
    if _GetAddOnEnableState((GetUnitName("player")),"Talented") == 2 then
        local loaded, finished = _IsAddOnLoaded("Talented")
        if loaded and finished then
            Talented = LibStub("AceAddon-3.0"):GetAddon("Talented",true)
            hookTalented(Talented)
        else
            local talented_loader = CreateFrame("Frame")
            talented_loader:SetScript("OnEvent", function(self,event,...)
                if (...) == "Talented" then
                    self:UnregisterEvent("ADDON_LOADED")
                    Talented = LibStub("AceAddon-3.0"):GetAddon("Talented",true)
                    hookTalented(Talented)
                end
            end)
            talented_loader:RegisterEvent("ADDON_LOADED")
        end
    end
else
    hooksecurefunc("ToggleTalentFrame", function(...)
        if (PlayerTalentFrame == nil) then return end
        if (initRun) then return end
        init(DEFAULT_CONFIG)
    end)
end
