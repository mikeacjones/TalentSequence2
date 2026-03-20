#!/usr/bin/env python3
"""
Generates WowheadData Lua files from Wowhead talent calculator data.

Usage:
    python3 tools/generate_wowhead_data.py <flavor> <data_file> <output_file>

Example:
    python3 tools/generate_wowhead_data.py tbc data/talents-tbc.js Importers/WowheadData_TBC.lua

The data file is the talents-classic endpoint served by Wowhead:
    TBC:     https://nether.wowhead.com/tbc/data/talents-classic
    Classic: https://nether.wowhead.com/classic/data/talents-classic

Save the response to a file and pass it as <data_file>.

The script can also fetch directly:
    python3 tools/generate_wowhead_data.py tbc --fetch Importers/WowheadData_TBC.lua
"""

import json
import re
import sys
import os

CHAR_INDICES = "abcdefghjkmnpqrstvwzxyilou"

# WoW class IDs to tokens
CLASS_NAMES = {
    "1": "WARRIOR", "2": "PALADIN", "3": "HUNTER", "4": "ROGUE",
    "5": "PRIEST", "7": "SHAMAN", "8": "MAGE", "9": "WARLOCK", "11": "DRUID",
}

# Wowhead spec IDs per class, in in-game tab order.
# This ordering is shared across Classic and TBC.
SPEC_MAP = {
    "11": ["283", "281", "282"],  # DRUID: Balance, Feral, Resto
    "3":  ["361", "363", "362"],  # HUNTER: BM, Marks, Survival
    "8":  ["81",  "41",  "61"],   # MAGE: Arcane, Fire, Frost
    "2":  ["382", "383", "381"],  # PALADIN: Holy, Prot, Ret
    "5":  ["201", "202", "203"],  # PRIEST: Disc, Holy, Shadow
    "4":  ["182", "181", "183"],  # ROGUE: Assassin, Combat, Sub
    "7":  ["261", "263", "262"],  # SHAMAN: Ele, Enhance, Resto
    "9":  ["302", "303", "301"],  # WARLOCK: Affliction, Demo, Destro
    "1":  ["161", "164", "163"],  # WARRIOR: Arms, Fury, Prot
}

FETCH_URLS = {
    "classic": "https://nether.wowhead.com/classic/data/talents-classic",
    "tbc":     "https://nether.wowhead.com/tbc/data/talents-classic",
}


def fetch_data(flavor):
    import urllib.request
    url = FETCH_URLS.get(flavor)
    if not url:
        print(f"Unknown flavor '{flavor}'. Known: {', '.join(FETCH_URLS)}", file=sys.stderr)
        sys.exit(1)
    print(f"Fetching {url} ...", file=sys.stderr)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode("utf-8")


def parse_data(raw, flavor):
    pattern = rf'WH\.setPageData\("wow\.talentCalcClassic\.{re.escape(flavor)}\.data",(\{{.*?\}})\)'
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


def escape_lua_string(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def generate_lua(flavor, trees, talents, spells):
    lines = []
    lines.append("local _, ts = ...")
    lines.append("")
    lines.append(f"-- Auto-generated from Wowhead {flavor.upper()} talent calculator data")
    lines.append(f"-- Run: python3 tools/generate_wowhead_data.py {flavor} --fetch <output>")
    lines.append(f"-- Encoding: talents sorted by (row, col), mapped to: {CHAR_INDICES}")
    lines.append("")
    lines.append("ts.WowheadData = {")
    lines.append(f"    {flavor} = {{")

    for class_id in sorted(SPEC_MAP.keys(), key=lambda x: CLASS_NAMES[x]):
        class_name = CLASS_NAMES[class_id]
        spec_ids = SPEC_MAP[class_id]
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
                if i >= len(CHAR_INDICES):
                    print(
                        f"Warning: {tree_desc} has more talents ({len(sorted_talents)}) "
                        f"than encoding characters ({len(CHAR_INDICES)})",
                        file=sys.stderr,
                    )
                    break
                char = CHAR_INDICES[i]
                first_spell = spells[str(t["ranks"][0])]
                name = escape_lua_string(first_spell["name_enus"])
                icon = first_spell.get("icon", "")
                rank_ids = ", ".join(str(r) for r in t["ranks"])
                lines.append(
                    f'                {char} = {{ name = "{name}", icon = "{icon}", ranks = {{{rank_ids}}} }},'
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
    else:
        with open(data_source, "r") as f:
            raw = f.read()

    trees, talents, spells = parse_data(raw, flavor)
    lua = generate_lua(flavor, trees, talents, spells)

    output_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), output_file)
    with open(output_path, "w") as f:
        f.write(lua)

    # Stats
    talent_count = sum(len(talents[sid]) for sids in SPEC_MAP.values() for sid in sids if sid in talents)
    rank_count = sum(
        len(t["ranks"])
        for sids in SPEC_MAP.values()
        for sid in sids
        if sid in talents
        for t in talents[sid].values()
    )
    print(f"Generated {output_file}: {len(CLASS_NAMES)} classes, {talent_count} talents, {rank_count} spell IDs", file=sys.stderr)


if __name__ == "__main__":
    main()
