local _, ts = ...

local strfind = strfind
local strsub = strsub
local strlen = strlen
local pairs = pairs

ts.TalentResolver = {}

-- Cached reverse lookup: spellId -> {tab, index, rank}
-- Keyed by classToken to avoid cross-class collisions
local spellIdCache = {}

-- Cached forward lookup: "tab:index" -> {ranks = {spellId, ...}, name, icon}
-- Keyed by classToken
local locationCache = {}

local function GetTalentData()
    return ts.WowheadData
end

local function BuildCacheForClass(classToken)
    if spellIdCache[classToken] then return end

    local talentData = GetTalentData()
    if not talentData then return end

    local spellLookup = {}
    local locLookup = {}

    for _, flavorMap in pairs(talentData) do
        local classMap = flavorMap[classToken]
        if classMap then
            local meta = flavorMap.__meta
            local singleTokens = meta and meta.singlePointTokens
            if singleTokens then
                for tab, treeMap in pairs(classMap) do
                    if type(tab) == "number" then
                        for token, entry in pairs(treeMap) do
                            local index = strfind(singleTokens, token, 1, true)
                            if index and entry.ranks then
                                local key = (tab + 1) .. ":" .. index
                                locLookup[key] = entry
                                for rank, spellId in ipairs(entry.ranks) do
                                    spellLookup[spellId] = {
                                        tab = tab + 1,
                                        index = index,
                                        rank = rank,
                                    }
                                end
                            end
                        end
                    end
                end
            end
            break
        end
    end

    spellIdCache[classToken] = spellLookup
    locationCache[classToken] = locLookup
end

function ts.TalentResolver.Resolve(spellId, classToken)
    if not spellId or not classToken then return nil end
    BuildCacheForClass(classToken)
    local lookup = spellIdCache[classToken]
    return lookup and lookup[spellId] or nil
end

function ts.TalentResolver.GetSpellId(classToken, tab, index, rank)
    if not classToken or not tab or not index then return nil end
    BuildCacheForClass(classToken)
    local locLookup = locationCache[classToken]
    if not locLookup then return nil end
    local key = tab .. ":" .. index
    local entry = locLookup[key]
    if not entry or not entry.ranks then return nil end
    return entry.ranks[rank or 1]
end

function ts.TalentResolver.GetMaxRank(classToken, tab, index)
    if not classToken or not tab or not index then return nil end
    BuildCacheForClass(classToken)
    local locLookup = locationCache[classToken]
    if not locLookup then return nil end
    local key = tab .. ":" .. index
    local entry = locLookup[key]
    if not entry or not entry.ranks then return nil end
    return #entry.ranks
end

function ts.TalentResolver.GetFlavorMeta()
    local talentData = GetTalentData()
    if not talentData then return nil end
    for _, flavorMap in pairs(talentData) do
        return flavorMap.__meta
    end
    return nil
end

function ts.TalentResolver.InvalidateCache()
    spellIdCache = {}
    locationCache = {}
end
