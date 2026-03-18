local addonName, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local LearnTalent = LearnTalent
local CreateFrame = CreateFrame
local IsAddOnLoaded = IsAddOnLoaded
local StaticPopup_Show = StaticPopup_Show
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local hooksecurefunc = hooksecurefunc
local format = format
local ceil = ceil
local strfind = strfind
local tinsert = tinsert
local tremove = tremove
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local TALENT_ROW_HEIGHT = 38
local MAX_TALENT_ROWS = 10
local SEQUENCES_ROW_HEIGHT = 26
local MAX_SEQUENCE_ROWS = 5
local SCROLLING_WIDTH = 102
local NONSCROLLING_WIDTH = 84
local IMPORT_DIALOG = "TALENTSEQUENCEIMPORTDIALOG"
local LEVEL_WIDTH = 20
local UsingTalented = false

IsTalentSequenceExpanded = false
TalentSequenceTalents = {}

local CLASS_TOKENS = {
    "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST",
    "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"
}

StaticPopupDialogs[IMPORT_DIALOG] = {
    text = ts.L.IMPORT_DIALOG,
    hasEditBox = true,
    button1 = ts.L.OK,
    button2 = ts.L.CANCEL,
    OnShow = function(self) _G[self:GetName() .. "EditBox"]:SetText("") end,
    OnAccept = function(self)
        local editBox = self.editBox or self.EditBox or _G[self:GetName() .. "EditBox"]
        if not editBox then
            return
        end
        local talentsString = editBox:GetText()
        ts:ImportTalents(talentsString)
    end,
    EditBoxOnEnterPressed = function(self)
        local talentsString =
            _G[self:GetParent():GetName() .. "EditBox"]:GetText()
        ts:ImportTalents(talentsString)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

local tooltip = CreateFrame("GameTooltip", "TalentSequenceTooltip", UIParent,
                            "GameTooltipTemplate")

local function GetPlayerClassToken()
    local _, classToken = UnitClass("player")
    return classToken
end

local function GetSequenceStore()
    if (not TalentSequenceAccountSavedSequences) then
        TalentSequenceAccountSavedSequences = {}
    end
    return TalentSequenceAccountSavedSequences
end

local function GetCollapsedClassStore()
    if (not TalentSequenceAccountCollapsedClasses) then
        TalentSequenceAccountCollapsedClasses = {}
    end
    return TalentSequenceAccountCollapsedClasses
end

local function GetClassDisplayName(classToken)
    if (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) then
        return LOCALIZED_CLASS_NAMES_MALE[classToken]
    end
    if (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken]) then
        return LOCALIZED_CLASS_NAMES_FEMALE[classToken]
    end
    return classToken or "Unknown"
end

local function EnsureSequenceMetadata(sequence, defaultClassToken)
    if (type(sequence) ~= "table") then return end
    if (not sequence.classToken) then
        sequence.classToken = defaultClassToken
    end
    if (not sequence.className) then
        sequence.className = GetClassDisplayName(sequence.classToken)
    end
end

local function BuildSequenceDisplayRows()
    local currentClassToken = GetPlayerClassToken()
    local collapsedClasses = GetCollapsedClassStore()
    local groupedSequences = {}
    local classTokens = {currentClassToken}
    local seenClassTokens = {[currentClassToken] = true}
    local rows = {}

    for index, sequence in ipairs(GetSequenceStore()) do
        EnsureSequenceMetadata(sequence, currentClassToken)
        if (not groupedSequences[sequence.classToken]) then
            groupedSequences[sequence.classToken] = {}
            if (not seenClassTokens[sequence.classToken]) then
                tinsert(classTokens, sequence.classToken)
                seenClassTokens[sequence.classToken] = true
            end
        end
        tinsert(groupedSequences[sequence.classToken], {
            type = "sequence",
            classToken = sequence.classToken,
            sequence = sequence,
            sequenceIndex = index
        })
    end

    table.sort(classTokens, function(left, right)
        if (left == currentClassToken) then return true end
        if (right == currentClassToken) then return false end
        return GetClassDisplayName(left) < GetClassDisplayName(right)
    end)

    for _, classToken in ipairs(classTokens) do
        tinsert(rows, {
            type = "header",
            classToken = classToken,
            className = GetClassDisplayName(classToken),
            isCurrentClass = (classToken == currentClassToken)
        })
        if (classToken == currentClassToken or not collapsedClasses[classToken]) then
            for _, sequenceRow in ipairs(groupedSequences[classToken] or {}) do
                tinsert(rows, sequenceRow)
            end
        end
    end

    return rows
end

local function FindDisplayRowIndexForSequence(displayRows, targetSequence)
    for index, entry in ipairs(displayRows) do
        if (entry.type == "sequence" and entry.sequence == targetSequence) then
            return index
        end
    end
end

local function MigrateSavedSequences()
    local playerClassToken = GetPlayerClassToken()
    local sequenceStore = GetSequenceStore()

    if (TalentSequenceSavedSequences and #TalentSequenceSavedSequences > 0) then
        for _, sequence in ipairs(TalentSequenceSavedSequences) do
            EnsureSequenceMetadata(sequence, playerClassToken)
            tinsert(sequenceStore, sequence)
        end
        TalentSequenceSavedSequences = {}
    end

    for _, sequence in ipairs(sequenceStore) do
        EnsureSequenceMetadata(sequence, playerClassToken)
    end
end

function ts.FindFirstUnlearnedIndex()
    for index, talent in pairs(ts.Talents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
        if (talent.rank > currentRank) then return index end
    end
end

function ts.ScrollFirstUnlearnedTalentIntoView(frame)
    local scrollBar = frame.scrollBar

    local numTalents = #ts.Talents
    if (numTalents <= MAX_TALENT_ROWS) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end

    local nextTalentIndex = ts.FindFirstUnlearnedIndex()
    if (not nextTalentIndex) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end
    if (nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end
    local nextTalentOffset = nextTalentIndex - 1
    if (nextTalentOffset > numTalents - MAX_TALENT_ROWS) then
        nextTalentOffset = numTalents - MAX_TALENT_ROWS
    end
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset)
    FauxScrollFrame_OnVerticalScroll(scrollBar, ceil(
                                         nextTalentOffset * TALENT_ROW_HEIGHT -
                                             0.5), TALENT_ROW_HEIGHT)
end

function ts.UpdateTalentFrame(frame)
    local scrollBar = frame.scrollBar
    local numTalents = #ts.Talents
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                           TALENT_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    for i = 1, MAX_TALENT_ROWS do
        local talentIndex = i + offset
        local talent = ts.Talents[talentIndex]
        local row = frame.rows[i]
        row:SetTalent(talent)
    end
    if (numTalents <= MAX_TALENT_ROWS) then
        frame:SetWidth(NONSCROLLING_WIDTH)
    else
        frame:SetWidth(SCROLLING_WIDTH)
    end
end

local function InsertSequence(talentSequence, classToken)
    local tabTotals = {0, 0, 0}
    for _, talent in ipairs(talentSequence) do
        tabTotals[talent.tab] = tabTotals[talent.tab] + 1
    end
    local points = string.format("%d/%d/%d", unpack(tabTotals))
    local sequence = {
        name = "<unnamed>",
        talents = talentSequence,
        points = points,
        classToken = classToken or GetPlayerClassToken()
    }
    EnsureSequenceMetadata(sequence, GetPlayerClassToken())
    tinsert(GetSequenceStore(), 1, sequence)
    return sequence
end

function ts:ImportTalents(talentsString)
    local isWowhead = strfind(talentsString,"wowhead")
    if (not isWowhead) then return end
    local talents, classToken = ts.WowheadTalents.GetTalents(talentsString)
    if (talents == nil) then return end
    local sequence = InsertSequence(talents, classToken)
    GetCollapsedClassStore()[classToken] = nil
    self.PendingRenameSequence = sequence
    if (self.ImportFrame and self.ImportFrame:IsShown()) then
        local scrollBar = self.ImportFrame.scrollBar
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, SEQUENCES_ROW_HEIGHT)
        ts:UpdateSequencesFrame()
    end
end

function ts:SetTalents(talents)
    if (talents == nil) then return end
    ts.Talents = talents
    TalentSequenceTalents = ts.Talents
    TalentSequenceActiveClass = (#talents > 0) and GetPlayerClassToken() or nil
    if (self.MainFrame and self.MainFrame:IsShown()) then
        local scrollBar = self.MainFrame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                               TALENT_ROW_HEIGHT)
        ts.ScrollFirstUnlearnedTalentIntoView(self.MainFrame)
        ts.UpdateTalentFrame(self.MainFrame)
    end
end

local function SequencesEqual(left, right)
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

function ts:UpdateSequencesFrame()
    local frame = self.ImportFrame
    frame:ShowAllLoadButtons()
    frame.displayRows = BuildSequenceDisplayRows()
    FauxScrollFrame_Update(frame.scrollBar, #frame.displayRows,
                           MAX_SEQUENCE_ROWS, SEQUENCES_ROW_HEIGHT, nil, nil,
                           nil, nil, nil, nil, true)
    local offset = FauxScrollFrame_GetOffset(frame.scrollBar)
    for i = 1, MAX_SEQUENCE_ROWS do
        local index = i + offset
        local row = frame.rows[i]
        row:SetEntry(frame.displayRows[index])
    end

    if (self.PendingRenameSequence) then
        local rowIndex = FindDisplayRowIndexForSequence(frame.displayRows,
                                                        self.PendingRenameSequence)
        if (rowIndex) then
            local desiredOffset = rowIndex - 1
            local maxOffset = #frame.displayRows - MAX_SEQUENCE_ROWS
            if (maxOffset < 0) then maxOffset = 0 end
            if (desiredOffset > maxOffset) then desiredOffset = maxOffset end
            FauxScrollFrame_SetOffset(frame.scrollBar, desiredOffset)
            for i = 1, MAX_SEQUENCE_ROWS do
                local displayIndex = i + desiredOffset
                frame.rows[i]:SetEntry(frame.displayRows[displayIndex])
            end
            frame.rows[rowIndex - desiredOffset]:SetForRename()
            self.PendingRenameSequence = nil
        end
    end
end

function ts.CreateImportFrame(talentFrame)
    local sequencesFrame = nil
    if (UsingTalented) then 
        sequencesFrame = CreateFrame("Frame", "TalentSequences", _G[talentFrame], "BasicFrameTemplateWithInset") 
    else
        sequencesFrame = CreateFrame("Frame", "TalentSequences", UIParent, "BasicFrameTemplateWithInset")
    end
    sequencesFrame:Hide()
    sequencesFrame:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)
    sequencesFrame:SetSize(325, 212)
    sequencesFrame:SetPoint("CENTER")
    sequencesFrame:SetMovable(true)
    sequencesFrame:SetClampedToScreen(true)
    sequencesFrame:SetScript("OnMouseDown", sequencesFrame.StartMoving)
    sequencesFrame:SetScript("OnMouseUp", sequencesFrame.StopMovingOrSizing)
    sequencesFrame.TitleText:SetText("Talent Sequences")
    function sequencesFrame:ShowAllLoadButtons()
        for _, row in ipairs(self.rows) do row:SetForLoad() end
    end
    tinsert(UISpecialFrames, "TalentSequences")
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar",
                                  sequencesFrame, "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", sequencesFrame.InsetBg, "TOPLEFT", 5, -6)
    scrollBar:SetPoint("BOTTOMRIGHT", sequencesFrame.InsetBg, "BOTTOMRIGHT",
                       -28, 28)

    sequencesFrame.scrollBar = scrollBar

    local importButton = CreateFrame("Button", nil, sequencesFrame,
                                     "UIPanelButtonTemplate")
    importButton:SetPoint("BOTTOM", 0, 8)
    importButton:SetSize(75, 24)
    importButton:SetText("Import")
    importButton:SetNormalFontObject("GameFontNormal")
    importButton:SetHighlightFontObject("GameFontHighlight")
    importButton:SetScript("OnClick",
                           function() StaticPopup_Show(IMPORT_DIALOG) end)

    local rows = {}
    for i = 1, MAX_SEQUENCE_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, sequencesFrame)
        row.index = i
        row:SetPoint("RIGHT", scrollBar)
        row:SetPoint("LEFT", scrollBar)
        row:SetHeight(SEQUENCES_ROW_HEIGHT)

        local nameInput = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        nameInput:SetPoint("TOP")
        nameInput:SetPoint("BOTTOM")
        nameInput:SetPoint("LEFT")
        nameInput:SetWidth(150)
        nameInput:SetAutoFocus(false)

        local namedLoadButton = CreateFrame("Button", nil, row,
                                            "UIPanelButtonTemplate")
        namedLoadButton:SetPoint("TOPLEFT", nameInput, "TOPLEFT", -6, 0)
        namedLoadButton:SetPoint("BOTTOMRIGHT", nameInput, "BOTTOMRIGHT")
        nameInput:Hide()

        local talentAmountString = row:CreateFontString(nil, "ARTWORK",
                                                        "GameFontWhite")
        talentAmountString:SetPoint("LEFT", nameInput, "RIGHT")
        local headerButton = CreateFrame("Button", nil, row)
        headerButton:SetPoint("TOPLEFT")
        headerButton:SetPoint("BOTTOMRIGHT")
        local headerText = row:CreateFontString(nil, "ARTWORK",
                                                "GameFontHighlight")
        headerText:SetPoint("LEFT", headerButton, "LEFT", 4, 0)
        headerText:SetJustifyH("LEFT")

        local deleteButton = CreateFrame("Button", nil, row)
        deleteButton:EnableMouse(true)
        deleteButton:SetPoint("RIGHT")
        deleteButton:SetPoint("TOP")
        deleteButton:SetPoint("BOTTOM")
        deleteButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        local delete = row:CreateTexture(nil, "ARTWORK")
        delete:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        delete:SetAllPoints(deleteButton)
        delete:SetVertexColor(1, 1, 1, 0.5)

        local renameButton = CreateFrame("Button", nil, row)
        renameButton:EnableMouse(true)
        renameButton:SetPoint("TOP")
        renameButton:SetPoint("BOTTOM")
        renameButton:SetPoint("RIGHT", delete, "LEFT")
        renameButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        talentAmountString:SetPoint("RIGHT", renameButton, "LEFT")

        local rename = row:CreateTexture(nil, "ARTWORK")
        rename:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        rename:SetAllPoints(renameButton)
        rename:SetVertexColor(1, 1, 1, 0.5)

        nameInput:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            self:Hide()
            namedLoadButton:Show()
        end)
        nameInput:SetScript("OnEnterPressed", function(self)
            local inputText = self:GetText()
            local newName = (inputText and inputText ~= "") and inputText or
                            ts.L.UNNAMED
            if (self:GetParent().entry and self:GetParent().entry.sequence) then
                self:GetParent().entry.sequence.name = newName
            end
            namedLoadButton:Show()
            self:Hide()
            ts:UpdateSequencesFrame()
        end)
        namedLoadButton:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            if (self:IsEnabled()) then
                tooltip:SetText(ts.L.LOAD_SEQUENCE_TIP)
            else
                tooltip:SetText(ts.L.LOAD_OTHER_CLASS_TIP)
            end
            tooltip:Show()
        end)
        namedLoadButton:SetScript("OnLeave", function() tooltip:Hide() end)
        namedLoadButton:SetScript("OnClick", function(self)
            local entry = self:GetParent().entry
            local sequence = entry and entry.sequence
            if (not sequence) then return end
            if (sequence.classToken ~= GetPlayerClassToken()) then return end
            ts:SetTalents(sequence.talents)
        end)
        headerButton:SetScript("OnClick", function(self)
            local entry = self:GetParent().entry
            if (not entry or entry.type ~= "header" or entry.isCurrentClass) then
                return
            end
            local collapsedClasses = GetCollapsedClassStore()
            collapsedClasses[entry.classToken] = not collapsedClasses[entry.classToken]
            ts:UpdateSequencesFrame()
        end)
        local function onIconButtonEnter(tooltipText, button, icon)
            icon:SetVertexColor(1, 1, 1, 1)
            tooltip:SetOwner(button, "ANCHOR_RIGHT")
            tooltip:SetText(tooltipText)
            tooltip:Show()
        end
        local function onIconButtonLeave(icon)
            icon:SetVertexColor(1, 1, 1, 0.5)
            tooltip:Hide()
        end
        deleteButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.DELETE_TIP, self, delete)
        end)
        deleteButton:SetScript("OnLeave", function()
            onIconButtonLeave(delete)
        end)
        renameButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.RENAME_TIP, self, rename)
        end)
        renameButton:SetScript("OnLeave", function()
            onIconButtonLeave(rename)
        end)
        deleteButton:SetScript("OnClick", function(self)
            if (not IsShiftKeyDown()) then return end
            local entry = self:GetParent().entry
            local sequence = entry and entry.sequence
            local index = entry and entry.sequenceIndex
            if (not sequence or not index) then return end
            local shouldClearActive = false
            if (sequence and SequencesEqual(sequence.talents, ts.Talents)) then
                shouldClearActive = true
            end
            if (#GetSequenceStore() == 1) then
                shouldClearActive = true
            end
            if (shouldClearActive) then
                ts:SetTalents({})
            end
            tremove(GetSequenceStore(), index)
            ts:UpdateSequencesFrame()
        end)
        renameButton:SetScript("OnClick", function(self)
            self:GetParent():SetForRename()
        end)

        function row:SetForRename()
            if (not self.entry or self.entry.type ~= "sequence") then return end
            namedLoadButton:Hide()
            nameInput:SetText(self.entry.sequence.name)
            nameInput:Show()
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
        function row:SetForLoad()
            nameInput:ClearFocus()
            nameInput:Hide()
            namedLoadButton:Show()
            namedLoadButton:Enable()
            deleteButton:Show()
            renameButton:Show()
            headerButton:Hide()
            headerText:Hide()
        end
        function row:SetEntry(entry)
            self.entry = entry
            if (entry == nil) then
                self:Hide()
                return
            end

            self:Show()
            self:SetForLoad()
            if (entry.type == "header") then
                namedLoadButton:Hide()
                talentAmountString:SetText("")
                deleteButton:Hide()
                renameButton:Hide()
                headerButton:Show()
                headerText:Show()
                local prefix = "[-]"
                if (not entry.isCurrentClass and GetCollapsedClassStore()[entry.classToken]) then
                    prefix = "[+]"
                end
                local suffix = ""
                if (entry.isCurrentClass) then
                    suffix = " (" .. ts.L.CURRENT_CLASS_LABEL .. ")"
                end
                headerText:SetText(prefix .. " " .. entry.className .. suffix)
                return
            end

            namedLoadButton:SetText(entry.sequence.name)
            talentAmountString:SetText(entry.sequence.points)
            local canLoad = entry.sequence.classToken == GetPlayerClassToken()
            if (canLoad) then
                namedLoadButton:Enable()
                namedLoadButton:GetFontString():SetTextColor(1, 1, 1)
                talentAmountString:SetTextColor(1, 1, 1)
            else
                namedLoadButton:Disable()
                namedLoadButton:GetFontString():SetTextColor(0.5, 0.5, 0.5)
                talentAmountString:SetTextColor(0.6, 0.6, 0.6)
            end
        end

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", scrollBar, 5, -6)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end
        rawset(rows, i, row)
    end
    sequencesFrame.rows = rows

    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SEQUENCES_ROW_HEIGHT,
                                         function()
            ts:UpdateSequencesFrame()
        end)
    end)
    scrollBar:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)

    ts.ImportFrame = sequencesFrame
end

function ts.CreateMainFrame(talentFrame)
    local mainFrame = CreateFrame("Frame", nil, _G[talentFrame], BackdropTemplateMixin and "BackdropTemplate")
    mainFrame:SetPoint("CENTER")
    mainFrame:SetSize(128, 128)
    if (not UsingTalented) then
        mainFrame:SetPoint("TOPLEFT", talentFrame, "TOPRIGHT", -36, -12)
        mainFrame:SetPoint("BOTTOMLEFT", talentFrame, "BOTTOMRIGHT", 0, 72)
        mainFrame:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
    else
        mainFrame:SetPoint("TOPLEFT", talentFrame, "TOPRIGHT", 0, 0)
        mainFrame:SetPoint("BOTTOMLEFT", talentFrame, "TOPRIGHT", 0, -450)
        mainFrame:SetBackdrop({
	    bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
	    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	    tile = true,
	    tileEdge = true,
	    tileSize = 16,
	    edgeSize = 16,
	    insets = { left = 3, right = 5, top = 3, bottom = 5 },
        })
    end
    
    mainFrame:SetBackdropColor(0, 0, 0, 1)
    mainFrame:SetScript("OnShow", function(self)
        ts.ScrollFirstUnlearnedTalentIntoView(self)
    end)
    mainFrame:SetScript("OnHide", function(self)
        if (ts.ImportFrame and ts.ImportFrame:IsShown()) then
            ts.ImportFrame:Hide()
        end
    end)
    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    mainFrame:RegisterEvent("SPELLS_CHANGED")
    mainFrame:SetScript("OnEvent", function(self, event)
        if (((event == "CHARACTER_POINTS_CHANGED") or
            (event == "SPELLS_CHANGED")) and self:IsVisible()) then
            ts.ScrollFirstUnlearnedTalentIntoView(self)
            ts.UpdateTalentFrame(self)
        end
    end)
    
    mainFrame:Hide()

    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame,
                                  "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", 0, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", -30, 8)
    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, TALENT_ROW_HEIGHT,
                                         function()
            ts.UpdateTalentFrame(mainFrame)
        end)
    end)
    scrollBar:SetScript("OnShow", function() ts.UpdateTalentFrame(mainFrame) end)
    mainFrame.scrollBar = scrollBar

    local rows = {}
    for i = 1, MAX_TALENT_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, mainFrame)
        row:SetWidth(110)
        row:SetHeight(TALENT_ROW_HEIGHT)

        local level = CreateFrame("Frame", "$parentLevel", row)
        level:SetWidth(LEVEL_WIDTH)
        level:SetPoint("LEFT", row, "LEFT")
        level:SetPoint("TOP", row, "TOP")
        level:SetPoint("BOTTOM", row, "BOTTOM")

        local levelLabel = level:CreateFontString(nil, "OVERLAY",
                                                  "GameFontWhite")
        levelLabel:SetPoint("TOPLEFT", level, "TOPLEFT")
        levelLabel:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT")
        level.label = levelLabel

        local icon = CreateFrame("Button", "$parentIcon", row,
                                 "ItemButtonTemplate")
        icon:SetWidth(37)
        icon:SetPoint("LEFT", level, "RIGHT", 4, 0)
        icon:SetPoint("TOP", level, "TOP")
        icon:SetPoint("BOTTOM", level, "BOTTOM")
        icon:EnableMouse(true)
        icon:SetScript("OnClick", function(self)
            local talent = self:GetParent().talent
            local _, _, _, _, currentRank =
                GetTalentInfo(talent.tab, talent.index)
            local playerLevel = UnitLevel("player")
            if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
                LearnTalent(talent.tab, talent.index)
            end
        end)
        icon:SetScript("OnEnter", function(self)
            if (not self.tooltip) then return end
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
            tooltip:Show()
        end)
        icon:SetScript("OnLeave", function() tooltip:Hide() end)

        local rankBorderTexture = icon:CreateTexture(nil, "OVERLAY")
        rankBorderTexture:SetWidth(32)
        rankBorderTexture:SetHeight(32)
        rankBorderTexture:SetPoint("CENTER", icon, "BOTTOMRIGHT")
        rankBorderTexture:SetTexture(
            "Interface\\TalentFrame\\TalentFrame-RankBorder")
        local rankText = icon:CreateFontString(nil, "OVERLAY",
                                               "GameFontNormalSmall")
        rankText:SetPoint("CENTER", rankBorderTexture)
        icon.rank = rankText

        row.icon = icon
        row.level = level

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", mainFrame, 8, -8)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        function row:SetTalent(talent)
            if (not talent) then
                self:Hide()
                self.talent = nil
                return
            end

            self:Show()
            self.talent = talent
            local name, icon, _, _, currentRank, maxRank =
                GetTalentInfo(talent.tab, talent.index)

            SetItemButtonTexture(self.icon, icon)
            local tabName = GetTalentTabInfo(talent.tab)
            self.icon.tooltip = format("%s (%d/%d) - %s", name, talent.rank,
                                       maxRank, tabName)
            self.icon.rank:SetText(talent.rank)

            if (talent.rank < maxRank) then
                self.icon.rank:SetTextColor(GREEN_FONT_COLOR.r,
                                            GREEN_FONT_COLOR.g,
                                            GREEN_FONT_COLOR.b)
            else
                self.icon.rank:SetTextColor(NORMAL_FONT_COLOR.r,
                                            NORMAL_FONT_COLOR.g,
                                            NORMAL_FONT_COLOR.b)
            end
            if (tooltip:IsOwned(self.icon) and self.icon.tooltip) then
                tooltip:SetText(self.icon.tooltip, nil, nil, nil, nil, true)
            end

            local iconTexture = _G[self.icon:GetName() .. "IconTexture"]
            iconTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0)

            self.level.label:SetText(talent.level)
            local playerLevel = UnitLevel("player")
            if (talent.level <= playerLevel) then
                self.level.label:SetTextColor(GREEN_FONT_COLOR.r,
                                              GREEN_FONT_COLOR.g,
                                              GREEN_FONT_COLOR.b)
            else
                self.level.label:SetTextColor(RED_FONT_COLOR.r,
                                              RED_FONT_COLOR.g, RED_FONT_COLOR.b)
            end

            if (talent.rank <= currentRank) then
                self.level.label:SetTextColor(GRAY_FONT_COLOR.r,
                                              GRAY_FONT_COLOR.g,
                                              GRAY_FONT_COLOR.b)
                self.icon.rank:SetTextColor(GRAY_FONT_COLOR.r,
                                            GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                iconTexture:SetDesaturated(1)
            else
                iconTexture:SetDesaturated(nil)
            end
        end

        rawset(rows, i, row)
    end
    mainFrame.rows = rows

    local loadButton = CreateFrame("Button", "$parentloadButton", mainFrame,
                                   "UIPanelButtonTemplate")
    loadButton:SetPoint("TOP", mainFrame, "BOTTOM", 0, 4)
    loadButton:SetPoint("RIGHT", mainFrame)
    loadButton:SetPoint("LEFT", mainFrame)
    loadButton:SetText(ts.L.LOAD)
    loadButton:SetHeight(22)
    loadButton:SetScript("OnClick", function()
        if (ts.ImportFrame == nil) then ts.CreateImportFrame(talentFrame) end
        ts.ImportFrame:Show()
        if (UsingTalented) then
            ts.ImportFrame:SetFrameLevel(4)
            ts.ImportFrame:Raise()
        end
    end)
    local showButton = CreateFrame("Button", "ShowTalentOrderButton",
                                   _G[talentFrame], "UIPanelButtonTemplate")
    if (not UsingTalented) then
        showButton:SetPoint("TOPRIGHT", -120, -16)
        showButton:SetHeight(18)
    else
        showButton:SetPoint("TOPRIGHT", -100, -4)
    end
    showButton:SetText("  Talent Sequence >>  ")
    if (IsTalentSequenceExpanded) then
        showButton:SetText("  Talent Sequence <<  ")
        mainFrame:Show()
    end
    showButton.tooltip = ts.L.TOGGLE
    showButton:SetScript("OnClick", function(self)
        IsTalentSequenceExpanded = not IsTalentSequenceExpanded
        if (IsTalentSequenceExpanded) then
            mainFrame:Show()
            self:SetText("  Talent Sequence <<  ")
        else
            mainFrame:Hide()
            self:SetText("  Talent Sequence >>  ")
        end
    end)
    showButton:SetScript("OnEnter", function(self)
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
        tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
        tooltip:Show()
    end)
    showButton:SetScript("OnLeave", function() tooltip:Hide() end)
    showButton:SetWidth(showButton:GetTextWidth() + 10)
    ts.MainFrame = mainFrame
end

local initRun = false
local function init(talentFrame)
    if (initRun) then return end
    if (not TalentSequenceTalents) then TalentSequenceTalents = {} end
    if (not TalentSequenceSavedSequences) then
        TalentSequenceSavedSequences = {}
    end
    GetSequenceStore()
    GetCollapsedClassStore()
    MigrateSavedSequences()
    if (#TalentSequenceTalents > 0 and #GetSequenceStore() == 0) then
        InsertSequence(TalentSequenceTalents, GetPlayerClassToken())
    end
    ts.Talents = TalentSequenceTalents
    if (IsTalentSequenceExpanded == 0) then IsTalentSequenceExpanded = false end
    if (ts.MainFrame == nil) then ts.CreateMainFrame(talentFrame) end
    initRun = true
end

local function hookTaleneted(Talented)
    if Talented then
        hooksecurefunc(Talented, "ToggleTalentFrame", function()
            if (initRun) then return end
            UsingTalented = true
            init("TalentedFrame")
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
            hookTaleneted(Talented)
        else
            local talented_loader = CreateFrame("Frame")
            talented_loader:SetScript("OnEvent", function(self,event,...)
                if (...) == "Talented" then
                    self:UnregisterEvent("ADDON_LOADED")
                    Talented = LibStub("AceAddon-3.0"):GetAddon("Talented",true)
                    hookTaleneted(Talented)
                end
            end)
            talented_loader:RegisterEvent("ADDON_LOADED")
        end
    end
else
    hooksecurefunc("ToggleTalentFrame", function(...)
        if (PlayerTalentFrame == nil) then return end
        if (initRun) then return end
        init("PlayerTalentFrame")
    end)
end
