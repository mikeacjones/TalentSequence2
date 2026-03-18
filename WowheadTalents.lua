local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass
local GetTalentInfo = GetTalentInfo
local GetNumTalents = GetNumTalents

local characterIndices = "abcdefghjkmnpqrstvwzxyilou"

ts.WowheadTalents = {}

local WOWHEAD_TALENT_NAME_MAP = {
    classic = {
        -- Populate Classic mappings explicitly per class/tree as calibration data is added.
    },
    tbc = {
        PALADIN = {
            [0] = {
                a = "Divine Strength",
                b = "Divine Intellect",
                c = "Spiritual Focus",
                d = "Improved Seal of Righteousness",
                e = "Healing Light",
                f = "Aura Mastery",
                g = "Improved Lay on Hands",
                h = "Unyielding Faith",
                j = "Illumination",
                k = "Improved Blessing of Wisdom",
                m = "Pure of Heart",
                n = "Divine Favor",
                p = "Sanctified Light",
                q = "Purifying Power",
                r = "Holy Power",
                s = "Light's Grace",
                t = "Holy Shock",
                v = "Blessed Life",
                w = "Holy Guidance",
                z = "Divine Illumination",
            },
            [1] = {
                a = "Improved Devotion Aura",
                b = "Redoubt",
                c = "Precision",
                d = "Guardian's Favor",
                e = "Toughness",
                f = "Blessing of Kings",
                g = "Improved Righteous Fury",
                h = "Shield Specialization",
                j = "Anticipation",
                k = "Stoicism",
                m = "Improved Hammer of Justice",
                n = "Improved Concentration Aura",
                p = "Spell Warding",
                q = "Blessing of Sanctuary",
                r = "Reckoning",
                s = "Sacred Duty",
                t = "One-Handed Weapon Specialization",
                v = "Improved Holy Shield",
                w = "Holy Shield",
                x = "Combat Expertise",
                y = "Avenger's Shield",
                z = "Ardent Defender",
            },
            [2] = {
                a = "Improved Blessing of Might",
                b = "Benediction",
                c = "Improved Judgement",
                d = "Improved Seal of the Crusader",
                e = "Deflection",
                f = "Vindication",
                g = "Conviction",
                h = "Seal of Command",
                j = "Pursuit of Justice",
                k = "Eye for an Eye",
                m = "Improved Retribution Aura",
                n = "Crusade",
                p = "Two-Handed Weapon Specialization",
                q = "Sanctity Aura",
                r = "Improved Sanctity Aura",
                s = "Vengeance",
                t = "Sanctified Judgement",
                v = "Sanctified Seals",
                w = "Divine Purpose",
                x = "Fanaticism",
                y = "Crusader Strike",
                z = "Repentance",
            },
        },
        DRUID = {
            [0] = {
                a = "Starlight Wrath",
                b = "Nature's Grasp",
                c = "Improved Nature's Grasp",
                d = "Control of Nature",
                e = "Focused Starlight",
                f = "Improved Moonfire",
                g = "Brambles",
                h = "Insect Swarm",
                j = "Nature's Reach",
                k = "Vengeance",
                m = "Celestial Focus",
                n = "Lunar Guidance",
                p = "Nature's Grace",
                q = "Moonglow",
                r = "Moonfury",
                s = "Balance of Power",
                t = "Dreamstate",
                v = "Moonkin Form",
                w = "Improved Faerie Fire",
                x = "Force of Nature",
                z = "Wrath of Cenarius",
            },
            [1] = {
                a = "Ferocity",
                b = "Feral Aggression",
                c = "Feral Instinct",
                d = "Brutal Impact",
                e = "Thick Hide",
                f = "Feral Swiftness",
                g = "Feral Charge",
                h = "Sharpened Claws",
                j = "Shredding Attacks",
                k = "Predatory Strikes",
                m = "Primal Fury",
                n = "Savage Fury",
                p = "Faerie Fire (Feral)",
                q = "Nurturing Instinct",
                r = "Heart of the Wild",
                s = "Survival of the Fittest",
                t = "Primal Tenacity",
                v = "Leader of the Pack",
                w = "Improved Leader of the Pack",
                x = "Mangle",
                z = "Predatory Instincts",
            },
            [2] = {
                a = "Improved Mark of the Wild",
                b = "Furor",
                c = "Naturalist",
                d = "Nature's Focus",
                e = "Natural Shapeshifter",
                f = "Intensity",
                g = "Subtlety",
                h = "Omen of Clarity",
                j = "Tranquil Spirit",
                k = "Improved Rejuvenation",
                m = "Nature's Swiftness",
                n = "Gift of Nature",
                p = "Improved Tranquility",
                q = "Empowered Touch",
                r = "Improved Regrowth",
                s = "Living Spirit",
                t = "Swiftmend",
                v = "Natural Perfection",
                w = "Empowered Rejuvenation",
                z = "Tree of Life",
            },
        },
    },
}

local function findLast(haystack, needle)
    local i = haystack:match(".*" .. needle .. "()")
    if i == nil then
        return nil
    else
        return i - 1
    end
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

local function GetFlavorTalentName(rawTalentString, currentTab, encodedId)
    local flavorKey = GetWowheadFlavor(rawTalentString)
    if not flavorKey then
        return nil
    end

    local _, classToken = UnitClass("player")
    local flavorMap = WOWHEAD_TALENT_NAME_MAP[flavorKey]
    local classMap = flavorMap and flavorMap[classToken]
    local treeMap = classMap and classMap[currentTab]
    return treeMap and treeMap[strlower(encodedId)] or nil
end

local function GetFlavorMappedTalentIndex(rawTalentString, currentTab, encodedId)
    local talentName = GetFlavorTalentName(rawTalentString, currentTab, encodedId)
    if not talentName then
        return nil
    end

    return FindTalentIndexByName(currentTab + 1, talentName)
end

local function GetMappedTalentIndex(rawTalentString, currentTab, encodedId)
    local mappedIndex = GetFlavorMappedTalentIndex(rawTalentString, currentTab, encodedId)
    if mappedIndex then
        return mappedIndex
    end

    return strfind(characterIndices, strlower(encodedId))
end

function ts.WowheadTalents.GetTalents(talentString)
    local rawTalentString = talentString
    local startPosition = findLast(talentString, "/")
    if startPosition then
        talentString = strsub(talentString, startPosition + 1)
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
            local talentIndex = GetMappedTalentIndex(rawTalentString, currentTab, encodedId)
            if not talentIndex then
                return nil
            end
            -- wowhead says to max out the talent if its in caps
            if strbyte(encodedId) < 97 then
                local _, _, _, _, _, maxRank = GetTalentInfo(currentTab + 1, talentIndex)
                for j = 1, maxRank, 1 do
                    level = level + 1
                    tinsert(talents, {
                        tab = currentTab + 1,
                        id = encodedId,
                        level = level,
                        index = talentIndex,
                        rank = j,
                    })
                end
            else
                level = level + 1
                if talentCounter[encodedId] == nil then
                    talentCounter[encodedId] = 1
                else
                    talentCounter[encodedId] = talentCounter[encodedId] + 1
                end
                tinsert(talents, {
                    tab = currentTab + 1,
                    id = encodedId,
                    level = level,
                    index = talentIndex,
                    rank = talentCounter[encodedId],
                })
            end
        end
    end
    return talents
end
