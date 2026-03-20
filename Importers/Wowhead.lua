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

ts.WowheadTalents = {}

local function NormalizeTalentString(rawTalentString)
    if (type(rawTalentString) ~= "string") then
        return nil
    end

    local normalized = rawTalentString:match("^%s*(.-)%s*$")
    if (normalized == "") then
        return nil
    end

    normalized = normalized:gsub("[?#].*$", "")
    normalized = normalized:gsub("/+$", "")
    return normalized
end

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
    if strfind(rawTalentString, "/wotlk/") then
        return "wotlk"
    end
    if strfind(rawTalentString, "/cata/") then
        return "cata"
    end
    return nil
end

local function GetFlavorMetadata(flavorKey)
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    return flavorMap and flavorMap.__meta or nil
end

local function GetTalentPointLevel(flavorMeta, pointNumber)
    if not flavorMeta or pointNumber < 1 then
        return nil
    end

    local pointGrantLevels = flavorMeta.pointGrantLevels
    if type(pointGrantLevels) == "table" then
        return pointGrantLevels[pointNumber]
    end

    local startingLevel = flavorMeta.startingLevel or 9
    return startingLevel + pointNumber
end

local function GetEncodedTalentToken(flavorMeta, encodedId)
    if not flavorMeta or not encodedId then
        return nil, nil
    end

    local singlePointTokens = flavorMeta.singlePointTokens
    local maxRankTokens = flavorMeta.maxRankTokens
    local index = strfind(singlePointTokens, encodedId, 1, true)
    if index then
        return strsub(singlePointTokens, index, index), false
    end

    index = strfind(maxRankTokens, encodedId, 1, true)
    if index then
        return strsub(singlePointTokens, index, index), true
    end

    return nil, nil
end

local function GetWowheadClass(rawTalentString)
    for segment in string_gmatch(rawTalentString, "[^/]+") do
        if segment == "death-knight" or segment == "deathknight" then
            return "DEATHKNIGHT"
        end
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

    local flavorMeta = GetFlavorMetadata(flavorKey)
    local normalizedToken = GetEncodedTalentToken(flavorMeta, encodedId)
    if not normalizedToken then
        return nil
    end

    local classToken = GetWowheadClass(rawTalentString)
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    local classMap = flavorMap and flavorMap[classToken]
    local treeMap = classMap and classMap[currentTab]
    return treeMap and treeMap[normalizedToken] or nil
end

local function GetMappedTalentResult(rawTalentString, currentTab, encodedId)
    local flavorMeta = GetFlavorMetadata(GetWowheadFlavor(rawTalentString))
    local normalizedToken, isMaxRank = GetEncodedTalentToken(flavorMeta, encodedId)
    local entry = GetFlavorTalentEntry(rawTalentString, currentTab, encodedId)
    if not entry then
        return nil, nil, "MAPPING_FAILED"
    end

    local importedClassToken = GetWowheadClass(rawTalentString)
    local playerClassToken = ts.DB.GetPlayerClassToken()
    if (importedClassToken and importedClassToken ~= playerClassToken) then
        local talentIndex = strfind(flavorMeta.singlePointTokens, normalizedToken, 1, true)
        if not talentIndex then
            return nil, nil, "MAPPING_FAILED"
        end
        return talentIndex, entry, nil, isMaxRank
    end

    local talentIndex = FindTalentIndexByName(currentTab + 1, entry.name)
    if not talentIndex then
        return nil, nil, "MAPPING_FAILED"
    end

    return talentIndex, entry, nil, isMaxRank
end

local function HasTalentOrder(encodedString, flavorMeta)
    if not flavorMeta then
        return false
    end

    for i = 1, strlen(encodedString) do
        local encodedId = strsub(encodedString, i, i)
        if GetEncodedTalentToken(flavorMeta, encodedId) then
            return true
        end
    end
    return false
end

function ts.WowheadTalents.GetTalents(talentString)
    local rawTalentString = NormalizeTalentString(talentString)
    if not rawTalentString then
        return nil, nil, "INVALID_URL"
    end

    local classToken = GetWowheadClass(rawTalentString)
    if not classToken then
        return nil, nil, "INVALID_URL"
    end
    if not GetWowheadFlavor(rawTalentString) then
        return nil, classToken, "INVALID_URL"
    end
    local flavorKey = GetWowheadFlavor(rawTalentString)
    local flavorMeta = GetFlavorMetadata(flavorKey)
    if not flavorMeta then
        return nil, classToken, "IMPORT_FAILED"
    end

    local startPosition = FindLast(rawTalentString, "/")
    if startPosition then
        talentString = strsub(rawTalentString, startPosition + 1)
    else
        talentString = rawTalentString
    end

    if not HasTalentOrder(talentString, flavorMeta) then
        return nil, classToken, "NO_ORDER"
    end

    local currentTab = 0
    local talentStringLength = strlen(talentString)
    local talents = {}
    local talentCounter = {}
    local pointsSpent = 0
    for i = 1, talentStringLength, 1 do
        local encodedId = strsub(talentString, i, i)
        if strbyte(encodedId) <= 50 then
            currentTab = tonumber(encodedId)
        else
            local talentIndex, entry, err, isMaxRank =
                GetMappedTalentResult(rawTalentString, currentTab, encodedId)
            if not talentIndex then
                return nil, classToken, err or "IMPORT_FAILED"
            end
            local ranks = entry and entry.ranks
            if isMaxRank then
                local _, _, _, _, _, maxRank = GetTalentInfo(currentTab + 1, talentIndex)
                for j = 1, maxRank, 1 do
                    pointsSpent = pointsSpent + 1
                    tinsert(talents, {
                        tab = currentTab + 1,
                        index = talentIndex,
                        rank = j,
                        level = GetTalentPointLevel(flavorMeta, pointsSpent),
                        spellId = ranks and ranks[j],
                    })
                end
            else
                pointsSpent = pointsSpent + 1
                talentCounter[talentIndex] = (talentCounter[talentIndex] or 0) + 1
                local rank = talentCounter[talentIndex]
                tinsert(talents, {
                    tab = currentTab + 1,
                    index = talentIndex,
                    rank = rank,
                    level = GetTalentPointLevel(flavorMeta, pointsSpent),
                    spellId = ranks and ranks[rank],
                })
            end
        end
    end
    return talents, classToken
end
