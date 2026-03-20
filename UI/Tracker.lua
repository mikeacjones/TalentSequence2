local _, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
local LearnTalent = LearnTalent
local CreateFrame = CreateFrame
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local format = format
local ceil = ceil
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local TALENT_ROW_HEIGHT = 38
local MAX_TALENT_ROWS = 10
local SCROLLING_WIDTH = 102
local NONSCROLLING_WIDTH = 84
local LEVEL_WIDTH = 20

function ts.FindFirstUnlearnedIndex()
    for index, talent in pairs(ts.Talents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
        if (talent.rank > currentRank) then return index end
    end
end

function ts.ScrollFirstUnlearnedTalentIntoView(frame)
    local scrollBar = frame.scrollBar
    local numTalents = #ts.Talents
    local nextTalentIndex = ts.FindFirstUnlearnedIndex()

    if (numTalents <= MAX_TALENT_ROWS or not nextTalentIndex or nextTalentIndex == 1) then
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

function ts:SetTalents(talents)
    if (talents == nil) then return end
    ts.Talents = talents
    TalentSequenceTalents = ts.Talents
    TalentSequenceActiveClass = (#talents > 0) and ts.DB.GetPlayerClassToken() or nil
    if (self.MainFrame and self.MainFrame:IsShown()) then
        local scrollBar = self.MainFrame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                               TALENT_ROW_HEIGHT)
        ts.ScrollFirstUnlearnedTalentIntoView(self.MainFrame)
        ts.UpdateTalentFrame(self.MainFrame)
    end
end

function ts.CreateMainFrame()
    local cfg = ts.FrameConfig
    local talentFrame = cfg.talentFrameName
    local mainFrame = CreateFrame("Frame", nil, _G[talentFrame], BackdropTemplateMixin and "BackdropTemplate")
    mainFrame:SetPoint("CENTER")
    mainFrame:SetSize(128, 128)
    mainFrame:SetPoint(cfg.trackerAnchors[1][1], talentFrame, cfg.trackerAnchors[1][2], cfg.trackerAnchors[1][3], cfg.trackerAnchors[1][4])
    mainFrame:SetPoint(cfg.trackerAnchors[2][1], talentFrame, cfg.trackerAnchors[2][2], cfg.trackerAnchors[2][3], cfg.trackerAnchors[2][4])
    mainFrame:SetBackdrop(cfg.trackerBackdrop)
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

    local tooltip = ts.tooltip
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
    loadButton:SetText(ts.L.MANAGE)
    loadButton:SetHeight(22)
    loadButton:SetScript("OnClick", function()
        if (ts.ImportFrame == nil) then ts.CreateImportFrame() end
        ts.ImportFrame:Show()
        ts.ImportFrame:Raise()
        if (cfg.raiseManagerOnShow) then
            ts.ImportFrame:SetFrameLevel(4)
        end
    end)
    local showButton = CreateFrame("Button", "ShowTalentOrderButton",
                                   _G[talentFrame], "UIPanelButtonTemplate")
    showButton:SetPoint(unpack(cfg.showButtonAnchor))
    if (cfg.showButtonHeight) then
        showButton:SetHeight(cfg.showButtonHeight)
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
