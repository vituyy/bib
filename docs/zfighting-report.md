# Overlapping surfaces report (flickering textures)

Scanned file: `SpookySteal-V6 (1).rbxl` (now the main place, `place/SpookySteal-V6.rbxl`), 4 October 2026.

> **Update (5.1):** the server now fixes these automatically when it starts (`MapBuilder.FixFlicker`, lifting one part of each pair by 0.03 studs). A new scan of the V5.3 place shows that House 4 and the bases were already rebuilt without them; about 960 remain in House 3, the Costume Shop, House 1, House 5, House 4 and the Speed Shop, and those are the ones the fix handles. In Studio edit mode you will still see them flicker until you move the parts yourself.

## What "glitchy overlapping textures" is and how it was found

When two parts have a face in the **same plane, facing the same way, and overlapping**, the graphics card cannot decide which one is in front. The surface flickers or shows jagged stripes of both colours, worst at a distance and when the camera moves. This is called z-fighting.

The scan read every block-shaped part in the place (88,932 parts) and looked for pairs where:

- a face of part A and a face of part B point the same way and are less than 0.06 studs apart,
- the two faces overlap by at least 0.05 square studs,
- the two parts look different (a different Color or Material; identical-looking pairs do not flicker visibly and were left out: 2,360 pairs),
- the overlap is not buried inside a third solid part.

Result: **1,757 flickering overlaps**, 1,561 of them in the Workspace (the rest are in `ServerStorage` backups that never render). The full list with world coordinates, colours and materials is in `docs/zfighting-pairs.csv`, sorted by size (biggest first).

**Not covered:** MeshParts, unions and wedges (no flat faces to compare), Decals/Textures (the place has only 1: the shopkeeper's face), and anything the scripts build at runtime that is not already in the saved place.

## Where they are

| # | Where | Pairs | Total overlap | What overlaps | Looks like |
|---|---|---|---|---|---|
| 1 | **House 4** roof (`Map.Street.Houses.House4.Structure.Roof."Gabled roof".Shingle`), around (39 to 112, 44 to 55, 807 to 821) | 207 | 518 studs² | Each shingle row overlaps the row above it by 2.5 studs², both with the same 0.35 thickness, so their top faces are in one plane. The two tints (76,47,79) and (87,53,88) flicker against each other | Strobing stripes across the whole roof |
| 2 | **House 3** roof (`House3.Structure.Roof.OverlappingShingle`), around (20 to 70, 20 to 40, 525 to 610) | 625 | 417 studs² | Same cause as House 4: shingles of 4 x 3.6 x 0.45 stacked about 3.3 studs apart on the same slope | Strobing stripes across the roof |
| 3 | **House 3** roof deck vs raked bargeboard (`RoofDeck`, `RakedBargeboard`), at (47, 30, 605) and (47, 30, 525) | 2 | 87 studs² | The underside of the 1.5 stud board is 0.037 studs from the underside of the deck: the two biggest single overlaps in the game (44 studs² each), seen from inside the attic | Big flickering band under the roof edge |
| 4 | House 3 other roof pieces (`GableShingle` 69, `PorchShingle` 30, `PorchRoof` 8) | 107 | 96 studs² | Same shingle stacking on the gables and the porch | Stripes on gables and porch roof |
| 5 | **Player bases**, all 5 (`Map.Plots.Plot1` to `Plot5` -> `Structure.RoofShingle` / `GableFascia`), roof at z -114 to -101, x from -45 to 106 across the five bases | 60 per plot (300) | 34 per plot | Neighbouring shingles are 0.08 studs longer than their spacing, so they overlap in one plane, with alternating colours; the gold `GableFascia` top is only 0.025 studs from the shingle tops. **Built by `BaseBuilder.luau` lines 425 to 435**, so this one is fixable in code | Stripes on the stall roof of every base, everyone sees it |
| 6 | **Costume Shop** roof (`RoofPlank` x 7, at (206 to 219, 24, -22)) | 7 | 45 studs² | Two sizes of planks (95/55/30 and 120/72/40) in the same plane, 10 studs² each | Flicker on the roof |
| 7 | Costume Shop: `BackLevel` vs `Post` at (223, 2, -10) and `Beam` vs `Post` at (220, 19, -68) | 2 | 8 studs² | A plank wall flush with a brick post | Brick and planks fighting on one wall |
| 8 | Costume Shop **mannequins** (UpperTorso, LowerTorso, Cape, Head, arms, legs of the costume art, at (192 to 213, 3 to 11, -18 to -62)) | 148 | 54 studs² | Costume pieces whose surfaces lie in the same plane as the body underneath (cape on back, lining on torso, second layer of the same limb) | Shimmer on costume parts when the camera moves |
| 9 | **Speed Shop** `Counter` vs `CounterPost` (4), at (-118, 1, -18) and (-118, 1, -40); `MainSign` pennants vs glow (6); `SideSigns` (4); `Bunting` (5) | 19 | 27 studs² | The counter front is level with the posts; sign trim is level with the board | Flicker on the counter front and signs |
| 10 | **House 4** striped awning (20 pairs, at (36, 15, 839)) | 20 | 14 studs² | Two stripe colours with edges in the same plane | Stripe edges shimmer |
| 11 | **House 1**: `CrateBox`/`CrateEdge`/`CrateSlat` (96 pairs, near (1 to 3, 2 to 3, 160)) and pumpkin faces (`Mouth`, `Eye`, `Tooth` vs `PumpkinLobe`, 12 pairs, near (-6 to 94, 1 to 2, 202 to 208)) | 108 | 22 studs² | Crate battens flush with the box sides; the glowing pumpkin face flush with the pumpkin | Small shimmer on crates and pumpkins |
| 12 | `_ArtPreview` (LanternMoth 14, Crow 1) and `ModelGallery` (1) | 16 | 3 studs² | Pet previews far away from the map (at y 600) | Only visible in the gallery, not in the game |

House 2 and Houses 5 to 9 have none yet (they are still placeholders). The backups in `ServerStorage` (`MapBackup_*`, `WitchHouse_v1/v2`, `ArtBackups` ...) have 196 more of the same kind, but they are not rendered.

**Worst offenders to fix first:** 1, 2, 3 (House 3 and 4 roofs, the biggest and the most visible), then 5 (every base), then 6 and 9.

## How to fix each type

| Cause | Fix (in Studio) |
|---|---|
| Overlapping shingle rows (1, 2, 4, 5) | Make each row 0.02 to 0.04 studs thicker or higher than the row it overlaps (alternate rows: +0.03), or shorten every shingle so it stops where the next one starts. Keep the same colour for both layers if you want to keep the overlap. |
| A trim or board flush with another part (3, 7, 9, 10, 11) | Push the smaller part 0.03 to 0.05 studs outward from the surface it sits on, or make it 0.05 thicker so it stands out from the surface. |
| Costume art (8) | Make the cape/lining/layer 0.02 to 0.03 studs bigger than the body piece underneath, or move it 0.02 outward. |
| Nothing visible changes | Only a 0.03 stud gap or step is needed. Anything bigger starts to look like a gap or a ledge. |

Item 5 is in `src/server/Services/BaseBuilder.luau` (the shingle rows and `GableFascia` at lines 425 to 435), so it can be fixed in code without opening Studio. The other items are hand-built parts saved in the place file; they need to be moved in Studio. A script that nudges every overlapping pair automatically is possible, but would change the look of the roofs a little, so it should be checked by eye.
