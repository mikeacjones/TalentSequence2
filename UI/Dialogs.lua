local _, ts = ...

local _G = _G
local StaticPopup_Show = StaticPopup_Show

local IMPORT_DIALOG = "TALENTPLANNERIMPORTDIALOG"

ts.Dialogs = {}

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

function ts.Dialogs.ShowImportDialog()
    StaticPopup_Show(IMPORT_DIALOG)
end
