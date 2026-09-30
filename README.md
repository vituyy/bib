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

## Working with Rojo (recommended)

[Rojo](https://rojo.space/docs) keeps the scripts in `src/` in sync with Studio while you work.

1. Install Rojo (for example with [Aftman](https://github.com/LPGhatguy/aftman) or [Rokit](https://github.com/rojo-rbx/rokit)) and the Rojo plugin for Studio.
2. Open `place/SpookyStealV3.2.rbxl` in Studio.
3. In a terminal inside this repo, run `rojo serve`.
4. In Studio, open the Rojo plugin and click **Connect**.

After that, edits to files in `src/` show up in Studio right away. Rojo only manages the three folders in the table above; the map and models still live in the place file.

**Rule of thumb:** change scripts in `src/`, not in Studio (Rojo overwrites Studio edits to those scripts). Change the map and models in Studio, then save the place file over `place/SpookyStealV3.2.rbxl` and commit it.

## Without Rojo

You can also edit everything in Studio as usual. Before committing, save the place over `place/SpookyStealV3.2.rbxl` and ask Claude to re-extract the scripts into `src/` so the two stay in step.

## Not synced by Rojo

Two small `Ambience` scripts live inside map models (`Workspace.ModelRows.Backups...` and `ServerStorage.MapBackup_BeforeTattersall...`). They stay in the place file.
