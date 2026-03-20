# Talent Planner

Talent Planner is a WoW AddOn for Classic Anniversary Edition and Burning Crusade Classic that displays a planned talent order next to the in-game talent window while you level.

Import a talent sequence from a Wowhead calculator URL, save multiple sequences per character, and load the one you want to follow in-game.

## Supports

- Wowhead Classic talent calculator URLs
- Wowhead TBC talent calculator URLs
- Blizzard talent UI

## In-Game Previews

![Blizzard frame displaying Talent Planner](https://i.imgur.com/elwqFaH.jpeg)

## How To Use

### Add a Wowhead Talent Sequence

1. Build your talent sequence in the Wowhead calculator for your game version:
   - Classic Era / Anniversary: use the Classic calculator
   - Burning Crusade Classic: use the TBC calculator
2. Ensure that **Talent Order** is enabled in Wowhead. You must expand the Talent Order panel and keep it active, or Wowhead may not preserve the point-by-point sequence in the URL.
3. Copy the entire Wowhead talent calculator URL.
4. In-game, open your Talent window and click **Talent Planner >>**
5. Click **Import**
6. Paste the Wowhead talent calculator URL
7. Name the sequence and press Enter
8. Click **Load** on that saved sequence to make it active
9. Spend points as you level using the sequence shown beside the talent window

![screenshot](https://i.imgur.com/dZAMbix.png) ![screenshot](https://i.imgur.com/3BZAal9.png)

## Wowhead Import Coverage

TBC Wowhead imports use explicit class and tree mappings for all nine classes. Classic Wowhead support is also available.

The importer resolves in-game talent indices dynamically with `GetTalentInfo`, making it robust across Classic/TBC tree differences.

## Origins

This AddOn is a fork of the original [Talent Sequence](https://www.curseforge.com/wow/addons/talent-sequence/) AddOn, updated for current Classic clients with flavor-specific TOCs, improved Wowhead import handling, and compatibility fixes for current Classic UI behavior.

## Issues and Feedback

Found a bug or have a feature request? Please [open an issue on GitHub](https://github.com/mikeacjones/TalentPlanner/issues).

## Development

### Source Layout

- `Core/Database.lua` — central data access layer
- `Importers/WowheadData_Classic.lua` — Classic Wowhead talent name mappings
- `Importers/WowheadData_TBC.lua` — TBC Wowhead talent name mappings
- `Importers/Wowhead.lua` — Wowhead URL parsing
- `UI/Dialogs.lua` — import dialog
- `UI/Manager.lua` — sequence management frame
- `UI/Tracker.lua` — talent order display panel
- `TalentPlanner.lua` — init and event wiring
- `Localization/Localization.xml` — locale loader
- `Localization/enUS.lua` and locale-specific files — strings

### Packaging

Releases are built and uploaded automatically via GitHub Actions when a version tag (`v*`) is pushed. The workflow uses [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to publish to CurseForge and WoWInterface.

For local builds:

```sh
./package.sh
```

### Installing Locally

Copy the packaged `TalentPlanner/` folder into:

```text
World of Warcraft/_anniversary_/Interface/AddOns/
```

Restart the client if you changed TOC metadata, or use `/reload` for Lua-only changes.
