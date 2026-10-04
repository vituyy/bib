# Spooky Steal

A Halloween "steal and collect" Roblox game: Trick-or-Treat for Candy, steal eggs from the houses on the street, hatch them into pets and train your speed to take on scarier houses.

## What's in this repo

| Path | What it is |
|---|---|
| `src/` | All of the game's scripts, as plain files you can edit and review |
| `place/SpookyStealV3.2.rbxl` | The full place: map, models, houses, lighting and everything else |
| `docs/design-and-plan.md` | Game design and execution plan |
| `default.project.json` | Rojo config that links `src/` to the right spots in Studio |

How `src/` maps to Studio:

| Folder | Studio location |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

File names follow the Rojo rules: `Name.server.luau` is a Script, `Name.client.luau` is a LocalScript, and `Name.luau` is a ModuleScript.

## How to play the latest version

1. Download `place/SpookyStealV3.2-Tutorial.rbxl` (the newest version, with the Scarecrow Jack tutorial) from this repo (open the file on GitHub and click the download button).
2. Double-click it to open it in Roblox Studio, then press **Play**.

Every code change is copied into the place file for you (`tools/sync_place.py`), so the download always has the latest scripts.

If you change the map or models in Studio, save the place and upload the new file to Claude, so the repo stays up to date.

## Working with Rojo (optional)

[Rojo](https://rojo.space/docs) can sync `src/` into Studio live instead: run `rojo serve` in this folder and click **Connect** in the Rojo Studio plugin.

## Not synced by Rojo

Two small `Ambience` scripts live inside map models (`Workspace.ModelRows.Backups...` and `ServerStorage.MapBackup_BeforeTattersall...`). They stay in the place file.
