# Talent Planner

Talent Planner is a Classic-era WoW AddOn that shows a talent-point spending order next to the in-game talent frame.

This source tree is the cleaned top-level addon layout used for both supported clients:
- `TalentPlanner_Vanilla.toc` for Classic Era / Anniversary Vanilla
- `TalentPlanner_TBC.toc` for Burning Crusade Classic

## Supports

- Wowhead talent calculator URLs
- Blizzard talent UI
- Talented addon integration

## Current Wowhead Support

The Wowhead importer supports a mapping-based decode path for flavors where the old fixed slot-index parser is unreliable.

Current mapped support:
- TBC Warrior
- TBC Paladin
- TBC Hunter
- TBC Rogue
- TBC Priest
- TBC Shaman
- TBC Mage
- TBC Warlock
- TBC Druid

The parser is structured as:
- `flavor -> class -> tree -> wowhead code -> talent name`

It then resolves the real in-game talent index dynamically with `GetTalentInfo`, which makes the importer much more robust across Classic/TBC tree differences.

Classic mappings can be added incrementally by supplying one calibration file per tree with:
- the full Wowhead URL
- the exact point-by-point order

## Source Layout

- `Core/Database.lua` central data access layer
- `Importers/WowheadData.lua` per-class talent name mappings
- `Importers/Wowhead.lua` Wowhead URL parsing
- `UI/Dialogs.lua` import dialog
- `UI/Manager.lua` sequence management frame
- `UI/Tracker.lua` talent order display panel
- `TalentPlanner.lua` init and event wiring
- `Localization.lua` strings
- `TalentPlanner_TBC.toc` TBC client entry point
- `TalentPlanner_Vanilla.toc` Vanilla client entry point

## Packaging

Releases are built and uploaded automatically via GitHub Actions when a version tag (`v*`) is pushed. The workflow uses [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to publish to CurseForge and WoWInterface.

For local builds:

```sh
./package.sh
```

This creates a zip under `.release/` containing a single top-level `TalentPlanner/` addon folder.

## Installing Locally

Copy the packaged `TalentPlanner/` folder into:

```text
World of Warcraft/_anniversary_/Interface/AddOns/
```

Then restart the client if you changed TOC metadata, or use `/reload` for Lua-only changes.

## Notes

- If a saved active sequence is deleted, the addon clears the active sequence instead of recreating it as `<unnamed>` on reload.
- The popup import dialog has been updated to work with the newer `StaticPopup` edit box field naming used by current Classic clients.
