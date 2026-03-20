local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local strupper = strupper
local tinsert = tinsert
local GetTalentInfo = GetTalentInfo
local GetNumTalents = GetNumTalents
local string_gmatch = string.gmatch

local characterIndices = "abcdefghjkmnpqrstvwzxyilou"

ts.WowheadTalents = {}

local function FindLast(haystack, needle)
    local lastIndex = nil
    local currentIndex = string.find(haystack, needle, 1, true)
    while currentIndex do
        lastIndex = currentIndex
        currentIndex = string.find(haystack, needle, currentIndex + 1, true)
    end
    return lastIndex
end

local function GetWowheadFlavor(rawTalentString)
    if strfind(rawTalentString, "/classic/") then
        return "classic"
    end
    if strfind(rawTalentString, "/tbc/") then
        return "tbc"
    end
    return nil
end

local function GetWowheadClass(rawTalentString)
    for segment in string_gmatch(rawTalentString, "[^/]+") do
        if segment == "druid" or segment == "hunter" or segment == "mage" or
            segment == "paladin" or segment == "priest" or segment == "rogue" or
            segment == "shaman" or segment == "warlock" or segment == "warrior" then
            return strupper(segment)
        end
    end

    return nil
end

local function FindTalentIndexByName(tabIndex, talentName)
    if not talentName or not GetNumTalents then
        return nil
    end

    for talentIndex = 1, GetNumTalents(tabIndex) do
        local name = GetTalentInfo(tabIndex, talentIndex)
        if name == talentName then
            return talentIndex
        end
    end

    return nil
end

local function GetFlavorTalentEntry(rawTalentString, currentTab, encodedId)
    local flavorKey = GetWowheadFlavor(rawTalentString)
    if not flavorKey then
        return nil
    end

    local classToken = GetWowheadClass(rawTalentString)
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    local classMap = flavorMap and flavorMap[classToken]
    local treeMap = classMap and classMap[currentTab]
    return treeMap and treeMap[strlower(encodedId)] or nil
end

local function GetMappedTalentResult(rawTalentString, currentTab, encodedId)
    local entry = GetFlavorTalentEntry(rawTalentString, currentTab, encodedId)
    if entry then
        local talentIndex = FindTalentIndexByName(currentTab + 1, entry.name)
        if talentIndex then
            return talentIndex, entry
        end
    end

    return strfind(characterIndices, strlower(encodedId)), nil
end

local function HasTalentOrder(encodedString)
    for i = 1, strlen(encodedString) do
        local byte = strbyte(encodedString, i)
        if byte >= 97 and byte <= 122 then return true end  -- a-z
        if byte >= 65 and byte <= 90 then return true end   -- A-Z
    end
    return false
end

function ts.WowheadTalents.GetTalents(talentString)
    local rawTalentString = talentString
    local classToken = GetWowheadClass(rawTalentString)
    if not classToken then
        return nil
    end
    local startPosition = FindLast(talentString, "/")
    if startPosition then
        talentString = strsub(talentString, startPosition + 1)
    end

    if not HasTalentOrder(talentString) then
        return nil, classToken, "NO_ORDER"
    end

    local currentTab = 0
    local talentStringLength = strlen(talentString)
    local level = 9
    local talents = {}
    local talentCounter = {}
    for i = 1, talentStringLength, 1 do
        local encodedId = strsub(talentString, i, i)
        if strbyte(encodedId) <= 50 then
            currentTab = tonumber(encodedId)
        else
            local talentIndex, entry = GetMappedTalentResult(rawTalentString, currentTab, encodedId)
            if not talentIndex then
                return nil
            end
            local ranks = entry and entry.ranks
            -- wowhead says to max out the talent if its in caps
            if strbyte(encodedId) < 97 then
                local _, _, _, _, _, maxRank = GetTalentInfo(currentTab + 1, talentIndex)
                for j = 1, maxRank, 1 do
                    level = level + 1
                    tinsert(talents, {
                        tab = currentTab + 1,
                        index = talentIndex,
                        rank = j,
                        level = level,
                        spellId = ranks and ranks[j],
                    })
                end
            else
                level = level + 1
                talentCounter[encodedId] = (talentCounter[encodedId] or 0) + 1
                local rank = talentCounter[encodedId]
                tinsert(talents, {
                    tab = currentTab + 1,
                    index = talentIndex,
                    rank = rank,
                    level = level,
                    spellId = ranks and ranks[rank],
                })
            end
        end
    end
    return talents, classToken
end
