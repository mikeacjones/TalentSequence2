local _, ts = ...

local GetLocale = GetLocale

local localeText = {
    enUS = {
        TOGGLE = "Toggle Talent Planner Window",
        LOAD = "Load",
        MANAGE = "Manage",
        IMPORT = "Import URL",
        IMPORT_DIALOG = "Paste a Wowhead talent URL into the box below",
        OK = "OK",
        CANCEL = "Cancel",
        WRONG_CLASS = "Unable to import, you're not a %s!",
        LOAD_SEQUENCE_TIP = "Click to Load Sequence",
        LOAD_OTHER_CLASS_TIP = "Only sequences for your current class can be loaded",
        DELETE_TIP = "<Shift>Click to Delete",
        RENAME_TIP = "Click to Rename",
        CURRENT_CLASS_LABEL = "Current Character",
        UNNAMED = "<unnamed>"
    }
};

ts.L = localeText["enUS"]
local locale = GetLocale()
if (locale == "enUS" or locale == "enGB" or localeText[locale] == nil) then
    return
end
for k, v in pairs(localeText[locale]) do
    ts.L[k] = v
end
