#!/usr/bin/env -S uv run --project tools
"""
Generates WowheadData Lua files from Wowhead talent calculator data.

Usage:
    uv run --project tools tools/generate_wowhead_data.py <flavor> <data_file> <output_file>

Example:
    uv run --project tools tools/generate_wowhead_data.py tbc data/talents-tbc.js Importers/WowheadData_TBC.lua

The data file is the talents-classic endpoint served by Wowhead:
    Classic: https://nether.wowhead.com/classic/data/talents-classic
    TBC:     https://nether.wowhead.com/tbc/data/talents-classic
    Wrath:   https://nether.wowhead.com/wotlk/data/talents-classic
    Cata:    https://nether.wowhead.com/cata/data/talents-classic

Save the response to a file and pass it as <data_file>.

The script also fetches shared calculator metadata from:
    https://wow.zamimg.com/js/WH/Wow/TalentCalcClassic.js

The script can also fetch directly:
    uv run --project tools tools/generate_wowhead_data.py tbc --fetch Importers/WowheadData_TBC.lua
"""

import json
import re
import sys
import os

CALCULATOR_JS_URL = "https://wow.zamimg.com/js/WH/Wow/TalentCalcClassic.js"

DEFAULT_CALCULATOR_METADATA = {
    "single_point_tokens": "abcdefghjkmnpqrstvwzxyilou468-~!",
    "max_rank_tokens": "ABCDEFGHJKMNPQRSTVWZXYILOU579_^.",
    "baseline_level": 10,
}

MAX_LEVELS = {
    "classic": 60,
    "tbc": 70,
    "wotlk": 80,
    "cata": 85,
}

# WoW class IDs to tokens
CLASS_NAMES = {
    "1": "WARRIOR", "2": "PALADIN", "3": "HUNTER", "4": "ROGUE",
    "5": "PRIEST", "6": "DEATHKNIGHT", "7": "SHAMAN", "8": "MAGE",
    "9": "WARLOCK", "11": "DRUID",
}

PAGE_DATA_KEYS = {
    "classic": "classic",
    "tbc": "tbc",
    "wotlk": "wrath",
    "cata": "cata",
}

# Wowhead spec IDs per class, in in-game tab order.
FLAVOR_SPEC_MAPS = {
    "classic": {
        "11": ["283", "281", "282"],  # DRUID: Balance, Feral, Resto
        "3":  ["361", "363", "362"],  # HUNTER: BM, Marks, Survival
        "8":  ["81",  "41",  "61"],   # MAGE: Arcane, Fire, Frost
        "2":  ["382", "383", "381"],  # PALADIN: Holy, Prot, Ret
        "5":  ["201", "202", "203"],  # PRIEST: Disc, Holy, Shadow
        "4":  ["182", "181", "183"],  # ROGUE: Assassin, Combat, Sub
        "7":  ["261", "263", "262"],  # SHAMAN: Ele, Enhance, Resto
        "9":  ["302", "303", "301"],  # WARLOCK: Affliction, Demo, Destro
        "1":  ["161", "164", "163"],  # WARRIOR: Arms, Fury, Prot
    },
    "tbc": {
        "11": ["283", "281", "282"],
        "3":  ["361", "363", "362"],
        "8":  ["81",  "41",  "61"],
        "2":  ["382", "383", "381"],
        "5":  ["201", "202", "203"],
        "4":  ["182", "181", "183"],
        "7":  ["261", "263", "262"],
        "9":  ["302", "303", "301"],
        "1":  ["161", "164", "163"],
    },
    "wotlk": {
        "11": ["283", "281", "282"],
        "3":  ["361", "363", "362"],
        "8":  ["81",  "41",  "61"],
        "2":  ["382", "383", "381"],
        "5":  ["201", "202", "203"],
        "4":  ["182", "181", "183"],
        "6":  ["398", "399", "400"],  # DEATHKNIGHT: Blood, Frost, Unholy
        "7":  ["261", "263", "262"],
        "9":  ["302", "303", "301"],
        "1":  ["161", "164", "163"],
    },
    "cata": {
        "11": ["752", "750", "748"],  # DRUID: Balance, Feral, Resto
        "3":  ["811", "807", "809"],  # HUNTER: BM, Marks, Survival
        "8":  ["799", "851", "823"],  # MAGE: Arcane, Fire, Frost
        "2":  ["831", "839", "855"],  # PALADIN: Holy, Prot, Ret
        "5":  ["760", "813", "795"],  # PRIEST: Disc, Holy, Shadow
        "4":  ["182", "181", "183"],  # ROGUE: Assassin, Combat, Sub
        "6":  ["398", "399", "400"],  # DEATHKNIGHT: Blood, Frost, Unholy
        "7":  ["261", "263", "262"],  # SHAMAN: Ele, Enhance, Resto
        "9":  ["871", "867", "865"],  # WARLOCK: Affliction, Demo, Destro
        "1":  ["746", "815", "845"],  # WARRIOR: Arms, Fury, Prot
    },
}

FETCH_URLS = {
    "classic": "https://nether.wowhead.com/classic/data/talents-classic",
    "tbc":     "https://nether.wowhead.com/tbc/data/talents-classic",
    "wotlk":   "https://nether.wowhead.com/wotlk/data/talents-classic",
    "cata":    "https://nether.wowhead.com/cata/data/talents-classic",
}


def fetch_url(url):
    import urllib.request

    print(f"Fetching {url} ...", file=sys.stderr)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode("utf-8")


def fetch_data(flavor):
    url = FETCH_URLS.get(flavor)
    if not url:
        print(f"Unknown flavor '{flavor}'. Known: {', '.join(FETCH_URLS)}", file=sys.stderr)
        sys.exit(1)
    return fetch_url(url)


def fetch_calculator_js():
    return fetch_url(CALCULATOR_JS_URL)


def get_spec_map(flavor):
    spec_map = FLAVOR_SPEC_MAPS.get(flavor)
    if not spec_map:
        print(f"Unknown flavor '{flavor}'. Known: {', '.join(FLAVOR_SPEC_MAPS)}", file=sys.stderr)
        sys.exit(1)
    return spec_map


def parse_data(raw, flavor):
    page_data_key = PAGE_DATA_KEYS.get(flavor, flavor)
    pattern = rf'WH\.setPageData\("wow\.talentCalcClassic\.{re.escape(page_data_key)}\.data",(\{{.*?\}})\)'
    match = re.search(pattern, raw, re.DOTALL)
    if not match:
        print(f"Could not find talent data for flavor '{flavor}'", file=sys.stderr)
        sys.exit(1)
    data = json.loads(match.group(1))

    match_spells = re.search(r'WH\.Gatherer\.addData\(6,\s*\d+,\s*(\{.*)', raw, re.DOTALL)
    if not match_spells:
        print("Could not find spell Gatherer data", file=sys.stderr)
        sys.exit(1)
    json_str = match_spells.group(1)
    depth = 0
    for i, ch in enumerate(json_str):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        if depth == 0:
            spells = json.loads(json_str[: i + 1])
            break

    return data["trees"], data["talents"], spells


def parse_calculator_metadata(raw):
    tokens = re.search(r'const H=\{min:"([^"]+)",max:"([^"]+)"\}', raw)
    baseline = re.search(r"var p=(\d+);", raw)

    if not tokens or not baseline:
        print("Warning: could not extract calculator metadata; using defaults", file=sys.stderr)
        return DEFAULT_CALCULATOR_METADATA.copy()

    return {
        "single_point_tokens": tokens.group(1),
        "max_rank_tokens": tokens.group(2),
        "baseline_level": int(baseline.group(1)),
    }


def build_point_grant_levels(flavor, baseline_level):
    max_level = MAX_LEVELS.get(flavor)
    if not max_level:
        return []

    if flavor in {"classic", "tbc", "wotlk"}:
        return list(range(baseline_level, max_level + 1))

    if flavor == "cata":
        levels = list(range(baseline_level, 81, 2))
        levels.extend(range(81, max_level + 1))
        return levels

    return []


def escape_lua_string(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def lua_table_key(token):
    return f'["{escape_lua_string(token)}"]'


def generate_lua(flavor, trees, talents, spells, metadata):
    spec_map = get_spec_map(flavor)
    single_point_tokens = metadata["single_point_tokens"]
    max_rank_tokens = metadata["max_rank_tokens"]
    baseline_level = metadata["baseline_level"]
    point_grant_levels = build_point_grant_levels(flavor, baseline_level)
    point_levels_lua = ", ".join(str(level) for level in point_grant_levels)

    lines = []
    lines.append("local _, ts = ...")
    lines.append("")
    lines.append(f"-- Auto-generated from Wowhead {flavor.upper()} talent calculator data")
    lines.append(f"-- Run: uv run --project tools tools/generate_wowhead_data.py {flavor} --fetch <output>")
    lines.append(f"-- Single-point tokens: {single_point_tokens}")
    lines.append(f"-- Max-rank tokens: {max_rank_tokens}")
    lines.append(f"-- Baseline talent level: {baseline_level}")
    lines.append(f"-- Point-grant levels: {point_levels_lua}")
    lines.append("")
    lines.append("ts.WowheadData = {")
    lines.append(f"    {flavor} = {{")
    lines.append("        __meta = {")
    lines.append(f'            singlePointTokens = "{escape_lua_string(single_point_tokens)}",')
    lines.append(f'            maxRankTokens = "{escape_lua_string(max_rank_tokens)}",')
    lines.append(f"            startingLevel = {baseline_level - 1},")
    lines.append(f"            pointGrantLevels = {{{point_levels_lua}}},")
    lines.append("        },")

    for class_id in sorted(spec_map.keys(), key=lambda x: CLASS_NAMES[x]):
        class_name = CLASS_NAMES[class_id]
        spec_ids = spec_map[class_id]
        lines.append(f"        {class_name} = {{")

        for tab_idx, spec_id in enumerate(spec_ids):
            if spec_id not in talents:
                print(f"Warning: spec {spec_id} not found in data, skipping", file=sys.stderr)
                continue
            tree_desc = trees[spec_id]["description"]
            tree_talents = talents[spec_id]
            sorted_talents = sorted(tree_talents.values(), key=lambda t: (t["row"], t["col"]))
            lines.append(f"            [{tab_idx}] = {{ -- {tree_desc}")

            for i, t in enumerate(sorted_talents):
                if i >= len(single_point_tokens):
                    print(
                        f"Warning: {tree_desc} has more talents ({len(sorted_talents)}) "
                        f"than encoding characters ({len(single_point_tokens)})",
                        file=sys.stderr,
                    )
                    break
                char = single_point_tokens[i]
                first_spell = spells[str(t["ranks"][0])]
                name = escape_lua_string(first_spell["name_enus"])
                icon = first_spell.get("icon", "")
                rank_ids = ", ".join(str(r) for r in t["ranks"])
                lines.append(
                    f'                {lua_table_key(char)} = {{ name = "{name}", icon = "{icon}", ranks = {{{rank_ids}}} }},'
                )

            lines.append("            },")
        lines.append("        },")

    lines.append("    },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    flavor = sys.argv[1]
    data_source = sys.argv[2]
    output_file = sys.argv[3]

    if data_source == "--fetch":
        raw = fetch_data(flavor)
        calculator_js = fetch_calculator_js()
    else:
        with open(data_source, "r") as f:
            raw = f.read()
        calculator_js = fetch_calculator_js()

    trees, talents, spells = parse_data(raw, flavor)
    metadata = parse_calculator_metadata(calculator_js)
    lua = generate_lua(flavor, trees, talents, spells, metadata)
    spec_map = get_spec_map(flavor)

    output_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), output_file)
    with open(output_path, "w") as f:
        f.write(lua)

    # Stats
    talent_count = sum(len(talents[sid]) for sids in spec_map.values() for sid in sids if sid in talents)
    rank_count = sum(
        len(t["ranks"])
        for sids in spec_map.values()
        for sid in sids
        if sid in talents
        for t in talents[sid].values()
    )
    print(f"Generated {output_file}: {len(spec_map)} classes, {talent_count} talents, {rank_count} spell IDs", file=sys.stderr)


if __name__ == "__main__":
    main()
