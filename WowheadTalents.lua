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
        HUNTER = {
            [0] = {
                a = "Improved Aspect of the Hawk",
                b = "Endurance Training",
                c = "Focused Fire",
                d = "Improved Aspect of the Monkey",
                e = "Thick Hide",
                f = "Improved Revive Pet",
                g = "Pathfinding",
                h = "Bestial Swiftness",
                j = "Unleashed Fury",
                k = "Improved Mend Pet",
                m = "Ferocity",
                n = "Spirit Bond",
                p = "Intimidation",
                q = "Bestial Discipline",
                r = "Animal Handler",
                s = "Frenzy",
                t = "Ferocious Inspiration",
                v = "Catlike Reflexes",
                w = "Bestial Wrath",
                x = "The Beast Within",
                z = "Serpent's Swiftness",
            },
            [1] = {
                a = "Improved Concussive Shot",
                b = "Lethal Shots",
                c = "Improved Hunter's Mark",
                d = "Efficiency",
                e = "Go for the Throat",
                f = "Improved Arcane Shot",
                g = "Aimed Shot",
                h = "Rapid Killing",
                j = "Improved Stings",
                k = "Mortal Shots",
                m = "Concussive Barrage",
                n = "Scatter Shot",
                p = "Barrage",
                q = "Combat Experience",
                r = "Ranged Weapon Specialization",
                s = "Improved Barrage",
                t = "Careful Aim",
                v = "Master Marksman",
                w = "Trueshot Aura",
                z = "Silencing Shot",
            },
            [2] = {
                a = "Monster Slaying",
                b = "Humanoid Slaying",
                c = "Hawk Eye",
                d = "Savage Strikes",
                e = "Entrapment",
                f = "Deflection",
                g = "Improved Wing Clip",
                h = "Clever Traps",
                j = "Survivalist",
                k = "Deterrence",
                m = "Trap Mastery",
                n = "Surefooted",
                p = "Improved Feign Death",
                q = "Killer Instinct",
                r = "Counterattack",
                s = "Survival Instincts",
                t = "Lightning Reflexes",
                v = "Resourcefulness",
                w = "Wyvern Sting",
                x = "Master Tactician",
                y = "Readiness",
                z = "Thrill of the Hunt",
                i = "Expose Weakness",
            },
        },
        PRIEST = {
            [0] = {
                a = "Unbreakable Will",
                b = "Wand Specialization",
                c = "Silent Resolve",
                d = "Improved Power Word: Fortitude",
                e = "Improved Power Word: Shield",
                f = "Martyrdom",
                g = "Meditation",
                h = "Inner Focus",
                j = "Absolution",
                k = "Improved Inner Fire",
                m = "Mental Agility",
                n = "Improved Mana Burn",
                p = "Divine Spirit",
                q = "Mental Strength",
                r = "Improved Divine Spirit",
                s = "Focused Power",
                t = "Force of Will",
                v = "Reflective Shield",
                w = "Power Infusion",
                x = "Pain Suppression",
                y = "Focused Will",
                z = "Enlightenment",
            },
            [1] = {
                a = "Healing Focus",
                b = "Improved Renew",
                c = "Holy Specialization",
                d = "Spell Warding",
                e = "Divine Fury",
                f = "Blessed Recovery",
                g = "Inspiration",
                h = "Searing Light",
                j = "Holy Nova",
                k = "Improved Healing",
                m = "Holy Reach",
                n = "Healing Prayers",
                p = "Spirit of Redemption",
                q = "Spiritual Guidance",
                r = "Surge of Light",
                s = "Spiritual Healing",
                t = "Holy Concentration",
                v = "Blessed Resilience",
                w = "Empowered Healing",
                x = "Circle of Healing",
                z = "Lightwell",
            },
            [2] = {
                a = "Spirit Tap",
                b = "Blackout",
                c = "Shadow Affinity",
                d = "Improved Shadow Word: Pain",
                e = "Shadow Focus",
                f = "Improved Psychic Scream",
                g = "Improved Mind Blast",
                h = "Mind Flay",
                j = "Improved Fade",
                k = "Shadow Reach",
                m = "Shadow Weaving",
                n = "Focused Mind",
                p = "Silence",
                q = "Vampiric Embrace",
                r = "Improved Vampiric Embrace",
                s = "Shadow Resilience",
                t = "Darkness",
                v = "Shadowform",
                w = "Shadow Power",
                x = "Vampiric Touch",
                z = "Misery",
            },
        },
        MAGE = {
            [0] = {
                a = "Arcane Subtlety",
                b = "Arcane Focus",
                c = "Improved Arcane Missiles",
                d = "Wand Specialization",
                e = "Magic Absorption",
                f = "Arcane Concentration",
                g = "Arcane Fortitude",
                h = "Magic Attunement",
                i = "Slow",
                j = "Arcane Impact",
                k = "Improved Mana Shield",
                m = "Improved Counterspell",
                n = "Arcane Meditation",
                p = "Improved Blink",
                q = "Presence of Mind",
                r = "Arcane Mind",
                s = "Prismatic Cloak",
                t = "Arcane Power",
                v = "Arcane Potency",
                w = "Mind Mastery",
                x = "Empowered Arcane Missiles",
                y = "Spell Power",
            },
            [1] = {
                a = "Improved Fireball",
                b = "Impact",
                c = "Ignite",
                d = "Flame Throwing",
                e = "Improved Fire Blast",
                f = "Incineration",
                g = "Improved Flamestrike",
                h = "Pyroblast",
                j = "Burning Soul",
                k = "Master of Elements",
                m = "Molten Shields",
                n = "Improved Scorch",
                p = "Blast Wave",
                q = "Critical Mass",
                r = "Blazing Speed",
                s = "Playing with Fire",
                t = "Fire Power",
                v = "Pyromaniac",
                w = "Combustion",
                x = "Dragon's Breath",
                y = "Empowered Fireball",
                z = "Molten Fury",
            },
            [2] = {
                a = "Frost Warding",
                b = "Improved Frostbolt",
                c = "Elemental Precision",
                d = "Ice Shards",
                e = "Frostbite",
                f = "Permafrost",
                g = "Improved Frost Nova",
                h = "Piercing Ice",
                j = "Icy Veins",
                k = "Improved Blizzard",
                m = "Shatter",
                n = "Frost Channeling",
                p = "Arctic Reach",
                q = "Frozen Core",
                r = "Cold Snap",
                s = "Improved Cone of Cold",
                t = "Ice Floes",
                v = "Winter's Chill",
                w = "Ice Barrier",
                x = "Summon Water Elemental",
                y = "Empowered Frostbolt",
                z = "Arctic Winds",
            },
        },
        ROGUE = {
            [0] = {
                a = "Improved Eviscerate",
                b = "Remorseless Attacks",
                c = "Malice",
                d = "Ruthlessness",
                e = "Murder",
                f = "Puncturing Wounds",
                g = "Lethality",
                h = "Improved Expose Armor",
                j = "Relentless Strikes",
                k = "Improved Poisons",
                m = "Vile Poisons",
                n = "Fleet Footed",
                p = "Cold Blood",
                q = "Improved Kidney Shot",
                r = "Quick Recovery",
                s = "Master Poisoner",
                t = "Seal Fate",
                v = "Vigor",
                w = "Deadened Nerves",
                x = "Mutilate",
                z = "Find Weakness",
            },
            [1] = {
                a = "Improved Gouge",
                b = "Improved Sinister Strike",
                c = "Lightning Reflexes",
                d = "Precision",
                e = "Deflection",
                f = "Improved Slice and Dice",
                g = "Endurance",
                h = "Riposte",
                i = "Surprise Attacks",
                j = "Improved Sprint",
                k = "Dual Wield Specialization",
                l = "Combat Potency",
                m = "Dagger Specialization",
                n = "Improved Kick",
                p = "Mace Specialization",
                q = "Blade Flurry",
                r = "Sword Specialization",
                s = "Fist Weapon Specialization",
                t = "Aggression",
                v = "Weapon Expertise",
                w = "Adrenaline Rush",
                x = "Blade Twisting",
                y = "Vitality",
                z = "Nerves of Steel",
            },
            [2] = {
                a = "Master of Deception",
                b = "Opportunity",
                c = "Sleight of Hand",
                d = "Dirty Tricks",
                e = "Camouflage",
                f = "Improved Ambush",
                g = "Ghostly Strike",
                h = "Initiative",
                j = "Setup",
                k = "Elusiveness",
                m = "Serrated Blades",
                n = "Hemorrhage",
                p = "Dirty Deeds",
                q = "Preparation",
                r = "Heightened Senses",
                s = "Master of Subtlety",
                t = "Deadliness",
                v = "Enveloping Shadows",
                w = "Premeditation",
                x = "Shadowstep",
                y = "Sinister Calling",
                z = "Cheat Death",
            },
        },
        SHAMAN = {
            [0] = {
                a = "Convection",
                b = "Concussion",
                c = "Elemental Warding",
                d = "Earth's Grasp",
                e = "Call of Flame",
                f = "Reverberation",
                g = "Elemental Focus",
                h = "Call of Thunder",
                j = "Improved Fire Totems",
                k = "Eye of the Storm",
                m = "Elemental Devastation",
                n = "Elemental Fury",
                p = "Storm Reach",
                q = "Unrelenting Storm",
                r = "Elemental Precision",
                s = "Elemental Mastery",
                t = "Elemental Shields",
                v = "Lightning Mastery",
                w = "Totem of Wrath",
                z = "Lightning Overload",
            },
            [1] = {
                a = "Ancestral Knowledge",
                b = "Shield Specialization",
                c = "Guardian Totems",
                d = "Thundering Strikes",
                e = "Improved Ghost Wolf",
                f = "Improved Lightning Shield",
                g = "Enhancing Totems",
                h = "Shamanistic Focus",
                j = "Anticipation",
                k = "Flurry",
                m = "Toughness",
                n = "Improved Weapon Totems",
                p = "Spirit Weapons",
                q = "Elemental Weapons",
                r = "Mental Quickness",
                s = "Weapon Mastery",
                t = "Dual Wield",
                v = "Stormstrike",
                w = "Dual Wield Specialization",
                x = "Shamanistic Rage",
                z = "Unleashed Rage",
            },
            [2] = {
                a = "Improved Healing Wave",
                b = "Tidal Focus",
                c = "Improved Reincarnation",
                d = "Ancestral Healing",
                e = "Totemic Focus",
                f = "Nature's Guidance",
                g = "Healing Focus",
                h = "Totemic Mastery",
                j = "Healing Grace",
                k = "Restorative Totems",
                m = "Tidal Mastery",
                n = "Healing Way",
                p = "Nature's Swiftness",
                q = "Focused Mind",
                r = "Purification",
                s = "Mana Tide Totem",
                t = "Nature's Guardian",
                v = "Improved Chain Heal",
                w = "Nature's Blessing",
                z = "Earth Shield",
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
