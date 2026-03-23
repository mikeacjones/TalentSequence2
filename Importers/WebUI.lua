local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tonumber = tonumber
local tinsert = tinsert

ts.WebUITalents = {}

local URL_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ3456789"

-- Minimal base64 decoder
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
local B64_LOOKUP = {}
for i = 1, #B64 do B64_LOOKUP[B64:sub(i, i)] = i - 1 end

local function DecodeBase64(input)
    if not input or input == "" then return nil end
    input = input:gsub("[^A-Za-z0-9+/=]", "")
    local output = {}
    for i = 1, #input, 4 do
        local a = B64_LOOKUP[input:sub(i, i)] or 0
        local b = B64_LOOKUP[input:sub(i + 1, i + 1)] or 0
        local c = B64_LOOKUP[input:sub(i + 2, i + 2)] or 0
        local d = B64_LOOKUP[input:sub(i + 3, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        output[#output + 1] = string.char(math.floor(n / 65536) % 256)
        if input:sub(i + 2, i + 2) ~= "=" then
            output[#output + 1] = string.char(math.floor(n / 256) % 256)
        end
        if input:sub(i + 3, i + 3) ~= "=" then
            output[#output + 1] = string.char(n % 256)
        end
    end
    return table.concat(output)
end

local CLASS_TOKENS = {
    druid = "DRUID",
    hunter = "HUNTER",
    mage = "MAGE",
    paladin = "PALADIN",
    priest = "PRIEST",
    rogue = "ROGUE",
    shaman = "SHAMAN",
    warlock = "WARLOCK",
    warrior = "WARRIOR",
}

-- Minimal JSON parser for the web UI export format:
-- { "classToken": "PALADIN", "talents": [ {spellId}, ... ] }
local ParseObject, ParseArray

local function SkipWhitespace(str, pos)
    return str:match("^%s*()", pos)
end

local function ParseString(str, pos)
    if strsub(str, pos, pos) ~= '"' then return nil, pos end
    local endPos = strfind(str, '"', pos + 1, true)
    if not endPos then return nil, pos end
    return strsub(str, pos + 1, endPos - 1), endPos + 1
end

local function ParseNumber(str, pos)
    local numStr = str:match("^(-?%d+)", pos)
    if not numStr then return nil, pos end
    return tonumber(numStr), pos + #numStr
end

local function ParseValue(str, pos)
    pos = SkipWhitespace(str, pos)
    local ch = strsub(str, pos, pos)

    if ch == '"' then
        return ParseString(str, pos)
    elseif ch == '-' or (ch >= '0' and ch <= '9') then
        return ParseNumber(str, pos)
    elseif ch == '{' then
        return ParseObject(str, pos)
    elseif ch == '[' then
        return ParseArray(str, pos)
    elseif strsub(str, pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif strsub(str, pos, pos + 3) == "true" then
        return true, pos + 4
    elseif strsub(str, pos, pos + 4) == "false" then
        return false, pos + 5
    end
    return nil, pos
end

ParseObject = function(str, pos)
    if strsub(str, pos, pos) ~= '{' then return nil, pos end
    pos = SkipWhitespace(str, pos + 1)
    local obj = {}

    if strsub(str, pos, pos) == '}' then return obj, pos + 1 end

    while pos <= strlen(str) do
        pos = SkipWhitespace(str, pos)
        local key
        key, pos = ParseString(str, pos)
        if not key then return nil, pos end

        pos = SkipWhitespace(str, pos)
        if strsub(str, pos, pos) ~= ':' then return nil, pos end
        pos = SkipWhitespace(str, pos + 1)

        local val
        val, pos = ParseValue(str, pos)
        obj[key] = val

        pos = SkipWhitespace(str, pos)
        local ch = strsub(str, pos, pos)
        if ch == '}' then return obj, pos + 1 end
        if ch == ',' then pos = pos + 1 end
    end
    return nil, pos
end

ParseArray = function(str, pos)
    if strsub(str, pos, pos) ~= '[' then return nil, pos end
    pos = SkipWhitespace(str, pos + 1)
    local arr = {}

    if strsub(str, pos, pos) == ']' then return arr, pos + 1 end

    while pos <= strlen(str) do
        pos = SkipWhitespace(str, pos)
        local val
        val, pos = ParseValue(str, pos)
        tinsert(arr, val)

        pos = SkipWhitespace(str, pos)
        local ch = strsub(str, pos, pos)
        if ch == ']' then return arr, pos + 1 end
        if ch == ',' then pos = pos + 1 end
    end
    return nil, pos
end

local function ParseJSON(str)
    if type(str) ~= "string" then return nil end
    str = str:match("^%s*(.-)%s*$")
    if str == "" then return nil end
    local val = ParseValue(str, 1)
    return val
end

-- Detect whether the input is a web UI JSON blob
function ts.WebUITalents.IsJSON(input)
    local trimmed = input:match("^%s*(.-)%s*$")
    return strsub(trimmed, 1, 1) == "{"
end

-- Detect whether the input is a web UI URL
function ts.WebUITalents.IsURL(input)
    return strfind(input, "TalentPlanner%-WebUI") ~= nil
        or strfind(input, "talent%-planner%-webui") ~= nil
        or strfind(input, "#classic/") ~= nil
        or strfind(input, "#tbc/") ~= nil
        or strfind(input, "#b/") ~= nil
end

-- Import from JSON blob
function ts.WebUITalents.ImportJSON(input)
    local data = ParseJSON(input)
    if type(data) ~= "table" then
        return nil, nil, "INVALID_JSON"
    end

    local classToken = data.classToken
    if type(classToken) ~= "string" or classToken == "" then
        return nil, nil, "IMPORT_FAILED"
    end

    local talents = data.talents
    if type(talents) ~= "table" or #talents == 0 then
        return nil, classToken, "IMPORT_FAILED"
    end

    local meta = ts.TalentResolver.GetFlavorMeta()
    local startingLevel = meta and meta.startingLevel or 9

    local result = {}
    for i, t in ipairs(talents) do
        if type(t) == "number" then
            local spellId = t
            local resolved = ts.TalentResolver.Resolve(spellId, classToken)
            if not resolved then
                return nil, classToken, "MAPPING_FAILED"
            end
            tinsert(result, {
                tab = resolved.tab,
                index = resolved.index,
                rank = resolved.rank,
                level = startingLevel + i,
                spellId = spellId,
            })
        elseif type(t) == "table" then
            if t.spellId then
                local resolved = ts.TalentResolver.Resolve(t.spellId, classToken)
                if not resolved then
                    return nil, classToken, "MAPPING_FAILED"
                end
                tinsert(result, {
                    tab = resolved.tab,
                    index = resolved.index,
                    rank = resolved.rank,
                    level = t.level or (startingLevel + i),
                    spellId = t.spellId,
                })
            elseif t.tab and t.index and t.rank and t.level then
                tinsert(result, {
                    tab = t.tab,
                    index = t.index,
                    rank = t.rank,
                    level = t.level,
                    spellId = ts.TalentResolver.GetSpellId(classToken, t.tab, t.index, t.rank),
                })
            else
                return nil, classToken, "IMPORT_FAILED"
            end
        else
            return nil, classToken, "IMPORT_FAILED"
        end
    end

    return result, classToken
end

-- Import from URL hash
function ts.WebUITalents.ImportURL(input)
    -- Extract the hash fragment
    local hash = input:match("#(.+)$")
    if not hash then
        return nil, nil, "INVALID_URL"
    end

    -- New format: #b/<base64-json>
    local base64Data = hash:match("^b/(.+)$")
    if base64Data then
        local json = DecodeBase64(base64Data)
        if not json then
            return nil, nil, "IMPORT_FAILED"
        end
        return ts.WebUITalents.ImportJSON(json)
    end

    -- Legacy format: #flavor/class/encoded_order
    local flavor, classSlug, encoded = hash:match("^([^/]+)/([^/]+)/(.+)$")
    if not flavor or not classSlug or not encoded then
        return nil, nil, "INVALID_URL"
    end

    flavor = strlower(flavor)
    classSlug = strlower(classSlug)

    local classToken = CLASS_TOKENS[classSlug]
    if not classToken then
        return nil, nil, "INVALID_URL"
    end

    local meta = ts.TalentResolver.GetFlavorMeta()
    local startingLevel = meta and meta.startingLevel or 9

    -- Decode the encoded order
    local talents = {}
    local currentTab = 0
    local pointsSpent = 0

    for i = 1, strlen(encoded) do
        local ch = strsub(encoded, i, i)
        if ch == "0" or ch == "1" or ch == "2" then
            currentTab = tonumber(ch)
        else
            local pos = strfind(URL_CHARS, ch, 1, true)
            if not pos then
                return nil, classToken, "IMPORT_FAILED"
            end
            local talentIndex = pos -- 1-based index within the tab

            -- Determine rank by counting prior allocations to this talent
            local rank = 0
            for _, prev in ipairs(talents) do
                if prev.tab == (currentTab + 1) and prev.index == talentIndex then
                    rank = rank + 1
                end
            end
            rank = rank + 1

            pointsSpent = pointsSpent + 1
            local spellId = ts.TalentResolver.GetSpellId(classToken, currentTab + 1, talentIndex, rank)

            tinsert(talents, {
                tab = currentTab + 1,
                index = talentIndex,
                rank = rank,
                level = startingLevel + pointsSpent,
                spellId = spellId,
            })
        end
    end

    if #talents == 0 then
        return nil, classToken, "IMPORT_FAILED"
    end

    return talents, classToken
end

-- Main entry point: detect format and import
function ts.WebUITalents.GetTalents(input)
    if ts.WebUITalents.IsJSON(input) then
        return ts.WebUITalents.ImportJSON(input)
    end
    return ts.WebUITalents.ImportURL(input)
end
