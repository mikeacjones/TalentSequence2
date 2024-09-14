local addonName, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
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
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local TALENT_ROW_HEIGHT = 38
local MAX_TALENT_ROWS = 7
local SEQUENCES_ROW_HEIGHT = 26
local MAX_SEQUENCE_ROWS = 5
local SCROLLING_WIDTH = 102
local NONSCROLLING_WIDTH = 84
local IMPORT_DIALOG = "TALENTSEQUENCEIMPORTDIALOG"
local LEVEL_WIDTH = 20
local UsingTalented = false

IsTalentSequenceExpanded = false
TalentSequenceTalents = {}

StaticPopupDialogs[IMPORT_DIALOG] = {
    text = ts.L.IMPORT_DIALOG,
    hasEditBox = true,
    button1 = ts.L.OK,
    button2 = ts.L.CANCEL,
    OnShow = function(self) _G[self:GetName() .. "EditBox"]:SetText("") end,
    OnAccept = function(self)
        local talentsString = self.editBox:GetText()
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

local function InsertSequence(talentSequence)
    local tabTotals = {0, 0, 0}
    for _, talent in ipairs(talentSequence) do
        tabTotals[talent.tab] = tabTotals[talent.tab] + 1
    end
    local points = string.format("%d/%d/%d", unpack(tabTotals))
    tinsert(TalentSequenceSavedSequences, 1,
            {name = "<unnamed>", talents = talentSequence, points = points})
end

local function GetTalentDictionary()
  local tabOne = {}
  local tabTwo = {}
  local tabThree = {}
  local dict = { tabOne, tabTwo, tabThree }
  for i = 1, GetNumTalentTabs() do
    for j = 1, GetNumTalents(i) do
      local name, icon, row, column, currentRank, maxRank = GetTalentInfo(i, j)
      talent = { name = name, icon = icon, currentRank = currentRank, maxRank = maxRank, index = j, tab = i, row = row, column = column }
      if talent.name then
        table.insert(dict[i], talent)
      end
    end
  end
  table.sort(dict[1], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  table.sort(dict[2], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  table.sort(dict[3], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  for i = 1, GetNumTalentTabs() do
    for j = 1, GetNumTalents(i) do
      talent = dict[i][j]
    end
  end
  return dict
end

function ts:ImportTalents(talentsString)
    local talents = {}
    local isWowhead = strfind(talentsString,"wowhead")
    local talents = nil
    local talentDict = GetTalentDictionary()
    if (isWowhead) then 
        talents = ts.WowheadTalents.GetTalents(talentsString, talentDict)
    else
        talents = ts.IcyVeinsTalents.GetTalents(talentsString, talentDict)
    end
    if (talents == nil) then return end
    InsertSequence(talents)
    if (self.ImportFrame and self.ImportFrame:IsShown()) then
        local scrollBar = self.ImportFrame.scrollBar
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, SEQUENCES_ROW_HEIGHT)
        ts:UpdateSequencesFrame()
        ts.ImportFrame.rows[1]:SetForRename()
    end
end

function ts:SetTalents(talents)
    if (talents == nil) then return end
    ts.Talents = talents
    TalentSequenceTalents = ts.Talents
    if (self.MainFrame and self.MainFrame:IsShown()) then
        local scrollBar = self.MainFrame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                               TALENT_ROW_HEIGHT)
        ts.ScrollFirstUnlearnedTalentIntoView(self.MainFrame)
        ts.UpdateTalentFrame(self.MainFrame)
    end
end

function ts:UpdateSequencesFrame()
    local frame = self.ImportFrame
    frame:ShowAllLoadButtons()
    FauxScrollFrame_Update(frame.scrollBar, #TalentSequenceSavedSequences,
                           MAX_SEQUENCE_ROWS, SEQUENCES_ROW_HEIGHT, nil, nil,
                           nil, nil, nil, nil, true)
    local offset = FauxScrollFrame_GetOffset(frame.scrollBar)
    for i = 1, MAX_SEQUENCE_ROWS do
        local index = i + offset
        local row = frame.rows[i]
        row:SetSequence(TalentSequenceSavedSequences[index])
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

        function row:SetSequence(sequence)
            if (sequence == nil) then
                self:Hide()
            else
                self:Show()
                namedLoadButton:SetText(sequence.name)
                talentAmountString:SetText(sequence.points)
            end
        end

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
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            local inputText = self:GetText()
            local newName = (inputText and inputText ~= "") and inputText or
                            ts.L.UNNAMED
            TalentSequenceSavedSequences[index].name = newName
            namedLoadButton:Show()
            self:Hide()
            ts:UpdateSequencesFrame()
        end)
        namedLoadButton:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip:SetText(ts.L.LOAD_SEQUENCE_TIP)
            tooltip:Show()
        end)
        namedLoadButton:SetScript("OnLeave", function() tooltip:Hide() end)
        namedLoadButton:SetScript("OnClick", function(self)
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            local sequence = TalentSequenceSavedSequences[index]
            ts:SetTalents(sequence.talents)
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
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            tremove(TalentSequenceSavedSequences, index)
            ts:UpdateSequencesFrame()
        end)
        renameButton:SetScript("OnClick", function(self)
            self:GetParent():SetForRename()
        end)

        function row:SetForRename()
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self.index
            namedLoadButton:Hide()
            nameInput:SetText(TalentSequenceSavedSequences[index].name)
            nameInput:Show()
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
        function row:SetForLoad()
            nameInput:ClearFocus()
            nameInput:Hide()
            namedLoadButton:Show()
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
        mainFrame:SetPoint("TOPLEFT", talentFrame, "TOPRIGHT", 0, -130)
        mainFrame:SetPoint("BOTTOMLEFT", talentFrame, "BOTTOMRIGHT", 0, 18)
        mainFrame:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
    else
        mainFrame:SetPoint("TOPLEFT", talentFrame, "TOPRIGHT", 35, 0)
        mainFrame:SetPoint("BOTTOMLEFT", talentFrame, "TOPRIGHT", 35, -550)
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
    scrollBar:SetPoint("TOPLEFT", 0, -6)
    scrollBar:SetPoint("BOTTOMRIGHT", -26, 5)
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
            tooltip:SetTalent(self.talentTab, self.talentIndex)
            tooltip:AddLine(" ", nil, nil, nil)
            tooltip:AddLine(self.tooltip, nil, nil, nil)
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
            local link = GetTalentLink(talent.tab, talent.index, false, nil)
            self.icon.tooltip = format("Train %s to (%d/%d)", link, talent.rank,
                                       maxRank, tabName)
            self.icon.talentTab = talent.tab
            self.icon.talentIndex = talent.index
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
        showButton:SetPoint("TOPLEFT", 60, -32)
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
    if (#TalentSequenceTalents > 0 and #TalentSequenceSavedSequences == 0) then
        InsertSequence(TalentSequenceTalents)
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

local _,_,_,talented_loadable, talented_error = GetAddOnInfo("Talented")
if talented_loadable and not (talented_error == "MISSING" or talented_error == "DISABLED") then
    local Talented
    if GetAddOnEnableState((GetUnitName("player")),"Talented") == 2 then
        local loaded, finished = IsAddOnLoaded("Talented")
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