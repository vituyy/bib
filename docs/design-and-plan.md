# Spooky Steal: Game Design & Execution Plan

> The Word version of this document is `docs/Spooky-Steal-Design-and-Plan.docx`; this Markdown copy is generated from it.

Working title. Version 3, updated 1 October 2026 with the new cartoon UI, the pet inventory with Equip Best, the friend boost and the real numbers from the game.

## What changed in this version

| Change | Summary |
|---|---|
| New UI | Chunky cartoon style: white studded menus with thick black outlines, cyan boxes, glossy buttons and outlined text. Rebirth menu shows this rebirth vs the next one. |
| HUD | Money and Candy in big gold and pink numbers on the right; night/day timer as plain text at the top; Speed Level bar at the bottom with a + button to the Speed Shop. |
| Pet inventory | Pets are either equipped (on the base, earning) or in an inventory of 60. The Pets menu has search, stacked cards and Equip Best. |
| Eggs menu | Same window as Pets: what's hatching with live timers, the egg bag below, tap an egg to hatch it, Hatch Best fills every free incubator. |
| Friend boost | +10% pet Money for every friend playing in the same server, shown bottom left. |
| Doc synced to the game | Speed, rebirth, costume and player numbers now match SpookyStealV3.2. |

## 1. Overview

**Pitch:** A spooky Halloween street at night. Trick-or-Treat at every door for Candy, then sneak in through the windows and steal the owners' eggs while they chase you home. Hatch the eggs into Brainrot and Halloween pets that wander your base and earn Money, train your speed, buy costumes and trails, and take on bigger, scarier houses.

**Genre:** Roblox "steal and collect" tycoon, inspired by Steal an Egg.

**Players:** 5 per server, one base each.

**Look:** Tattersall studs style (two-tone checkered studs tiles), with each level in its own colour theme under dark Halloween night lighting.

**Core loop:** Trick-or-Treat → earn Candy → buy treadmills and train speed → steal eggs → escape the owner → hatch pets → earn Money → buy costumes and trails → unlock better houses → repeat at a higher level.

**Two currencies:**

| Currency | Earned from | Spent on |
|---|---|---|
| Candy | Trick-or-Treating at doors | Treadmills (speed training) |
| Money | Pets on your base, every second | Costumes (unlock better doors) and trails (faster training) |

## 2. Game description

### 2.1 The map

- **Hub** at the start of the street: 5 player bases (56 × 56 studs each), the Speed Shop (treadmills and trails) and the Costume Shop (mannequins). The hub is about 430 × 260 studs. Owners stop chasing at the Level 1 line, so the hub is safe.
- **The street:** one long straight road of 9 house lots, about 2,100 studs long. Each lot is its own level and harder than the one before. Houses have one or two floors and several rooms, and get grander along the street.
- No gates: every house can be broken into from the start. Progress is limited by speed (can you escape?) and costume (will they give you Candy?).

### 2.2 Map style and level themes

The map now starts as a blank layout that Viktor builds by hand:

- **What's in the blank map:** the hub floor and walls, the 5 base pads, the shop spots, the 9 lots each with their own floor and boundary walls, and the level lines.
- **Style:** tattersall studs. Floors and walls use a checkerboard of two close shades of the same colour, with studs on every tile, like the reference screenshots (green grass next to a sand-coloured floor, orange and mustard walls).
- **Models on the side:** every house (including the finished House 1 mummy tomb), prop and decoration sits in rows next to the map, ready to drag in. The old map is backed up in ServerStorage.
- **Naming rules still apply:** the scripts find doors, egg spots, owner spawns, plots and level lines by name, so those parts must keep their names when a house is placed.

Each level gets its own floor and wall theme:

| Level | Owner | Floor | Walls |
|---|---|---|---|
| Hub | – | Dark grass green | Purple and grey stone |
| 1 | Friendly Mummy | Desert sand | Sandstone |
| 2 | Old Witch | Swamp green | Mossy dark green |
| 3 | Scarecrow | Wheat yellow | Hay and barn red |
| 4 | Zombie Chef | Red and cream diner tiles | Greasy mint green |
| 5 | Gravedigger | Dead grass | Grey graveyard stone |
| 6 | Count Vlad | Blood red | Dark castle purple |
| 7 | Banshee | Pale misty blue | Ghostly grey-white |
| 8 | Headless Horseman | Autumn leaf orange | Dark wood brown |
| 9 | Lich King | Frozen ice blue | Necrotic green |

Only the Mummy's desert theme came from Viktor; the rest are suggestions to change freely.

### 2.3 The houses and owners

| # | Owner | Owner speed | Candy per knock | Min. costume | Floors | Eggs |
|---|---|---|---|---|---|---|
| 1 | Friendly Mummy | 14 | 5 | None | 1 | 4 |
| 2 | Old Witch | 17 | 10 | None | 1 | 4 |
| 3 | Scarecrow | 21 | 20 | Bedsheet Ghost | 1 | 5 |
| 4 | Zombie Chef | 25 | 40 | Pumpkin Head | 2 | 5 |
| 5 | Gravedigger | 30 | 80 | Witch | 1 | 5 |
| 6 | Count Vlad | 37 | 160 | Vampire | 2 | 6 |
| 7 | Banshee | 46 | 320 | Glowing Skeleton | 2 | 6 |
| 8 | Headless Horseman | 58 | 650 | Werewolf | 2 | 6 |
| 9 | Lich King | 72 | 1,300 | Grim Reaper | 2 | 6 |

Owner speed grows roughly exponentially so the last houses need a well-trained runner. House 1 is slower than a brand-new player (14 vs 16), so a first-timer can always get away from it.

### 2.4 Trick-or-Treat

Walk up to a front door and knock to get Candy (20 s cooldown per house). If your costume is below the house's minimum, the owner refuses with a roast line such as "And you call this a costume? I'm not giving you my candy!"

### 2.5 Stealing eggs

- Climb in through a window, pick an egg by its look and hold the prompt for 1 s.
- The owner needs a moment to notice you (a red "!" over their head): 0.8 s plus 0.2 s per egg rarity step, so a Common egg gives a 1 s head start and a Secret egg 2.2 s. They can't catch you during that time. Then the owner starts the chase from wherever they stand, even inside the house. They follow a planned path through rooms, doors, windows and stairs while a wall is in the way, pass through props outside so they never get stuck, and walk back to their spot afterwards. The closest thief is chased. Bigger, rarer eggs slow you down (95% down to 82% of your speed).
- Get past the Level 1 line and walk the egg to your base to keep it. If the owner touches you, they take the egg back and you are stunned for 1.5 s. Owners also give up after 30 s or when you are 150 studs ahead.

### 2.6 Day and night

A 5-minute night, then a **10-second day**. During the day every house closes, anyone on the street is sent home, and an egg still being carried crumbles. Every egg respawns when the next night starts.

### 2.7 Eggs: every pet has its own egg

- When an egg spawns, the game picks its pet straight away (using that house's rarity odds), and the egg takes that pet's design. The egg always hatches the pet it was made for.
- There are no signs or labels above eggs. Players learn to read the designs: a black egg with little ears is a Black Cat, an orange ribbed egg with a stem is a Pumpkling.
- Rarer eggs are bigger, more detailed and heavier to carry, which is the only built-in rarity hint.
- Eggs sit in nests (as in the reference screenshots).
- **Hatching is free**, in 3 incubators on your base (+1 per base upgrade). You can hold 12 unhatched eggs. Tap an egg in the Eggs menu to hatch it, or press Hatch Best to fill every free incubator with your rarest eggs. Hatch time depends on rarity:

| Rarity | Hatch time | Carry speed |
|---|---|---|
| Common | 10 s | 95% |
| Uncommon | 30 s | 93% |
| Rare | 2 min | 91% |
| Epic | 5 min | 89% |
| Legendary | 15 min | 87% |
| Mythic | 30 min | 85% |
| Secret | 1 hr | 82% |

### 2.8 Pets and their egg designs

20 pets across 7 rarities. Pets are either **equipped** (on your base, earning Money every second) or in your **inventory**. A pet can be sold for 30 seconds of its income.

| Pet | Rarity | Money/s | Egg design hint |
|---|---|---|---|
| Bat | Common | 1 | Dark grey egg with two folded wing flaps |
| Black Cat | Common | 2 | Black egg with pointed ear nubs and green eye slits |
| Candy Spider | Uncommon | 4 | Purple egg wrapped in thin leg stripes |
| Pumpkling | Uncommon | 6 | Orange ribbed egg with a green stem |
| Scarecrow Crow | Uncommon | 9 | Black egg with a straw tuft and a yellow beak tip |
| Candy Corn Critter | Rare | 15 | Yellow, orange and white bands |
| Vampire Bat | Rare | 22 | Dark red egg with wing flaps and tiny fangs |
| Zombie Pup | Rare | 32 | Green patchwork egg with stitches and a floppy ear |
| Tralalero Tralala | Epic | 65 | Blue egg with a shark fin and sneaker soles |
| Ghosty | Epic | 90 | White egg with a wavy hem, slightly see-through |
| Wraith | Epic | 130 | Grey-blue egg in torn cloth wraps |
| Tung Tung Tung Sahur | Legendary | 260 | Wood-grain egg with a baseball-bat stripe |
| Mini Werewolf | Legendary | 380 | Brown furry egg with ears and claw scratches |
| Bombardiro Crocodilo | Legendary | 620 | Green scaly egg with plane-wing stubs |
| Blood Moon Bat | Mythic | 1,000 | Crimson egg with a glowing crescent moon |
| Lich Cat | Mythic | 1,600 | Bone-white egg with cat ears and glowing green eyes |
| Ballerina Cappuccina | Mythic | 2,600 | Cream and pink egg with a tutu frill and a cup rim on top |
| Shadow Clown | Mythic | 4,000 | Black egg with a ruff collar and purple diamonds |
| Headless Horseman | Secret | 8,000 | Black egg with ears and red flame cracks |
| Pumpkin King | Secret | 15,000 | Orange-gold egg with a crown and a glowing carved face |

**Egg variants (added 1 October 2026):** every egg rolls two separate things, and one result never changes the other, so an egg can have both, one or neither (a Big Diamond egg, a Gigantic egg, a Rainbow egg...). The egg and the pet it hatches look the part: bigger for a size, glowing and sparkling for a material.

| Size | Chance | Egg size | Pet size | Money/s |
|---|---|---|---|---|
| Normal | 75.5% | 0.7x | 1x | x1 |
| Big | 20% | 1.56x | 1.6x | x3 |
| Huge | 4% | 1.89x | 2.1x | x8 |
| Gigantic | 0.5% | 2.34x | 2.8x | x30 |

| Material | Chance | Look | Money/s |
|---|---|---|---|
| Golden | 15% | gold glow | x3 |
| Diamond | 5% | ice-blue glow | x8 |
| Rainbow | 1% | glow cycling through every colour | x25 |

Multipliers stack: a Gigantic Rainbow pet earns x750 (a Gigantic Rainbow Pumpkin King would earn $11.25M/s, about 1 egg in 20,000). A variant pet is stored as "Bat+Big+Golden" and counts as its plain pet in the Index. All numbers are in `Config.Sizes` and `Config.Materials`.

Because variants raise the average pet income by about 3.4x, every Money price (costumes, trails, base upgrades, Index rewards) was multiplied by 3 so the pacing in 2.11 stays the same for an average-luck player. Lucky players are faster, unlucky ones a little slower.

A thief carries the egg in front of their chest, like holding it in both hands.

When the owner catches you (or you die while carrying), the egg goes back to the nest it was taken from, with the same pet, size and material, so another player can steal it.

**Wandering pets:** pets walk slowly around inside your base, stop now and then to idle, and never leave the base. Money pops up above each pet as it earns. Pets don't block players.

**Equipped and inventory:** your base has 10 pet slots, +2 per base upgrade (up to 18). Up to 60 more pets wait in the inventory. When the base is full, a hatched pet goes straight to the inventory. The Pets menu shows equipped pets on top and the inventory below, stacked by kind (x2, x3) with a search box. Tap a pet to equip, unequip or sell it; **Equip Best** puts your highest-earning pets on the base.

**Friend boost:** +10% pet Money for every friend playing in the same server (up to +40% with 4 friends), shown in the bottom-left corner.

**Base upgrades:** bought with Money at the UPGRADE BASE sign ($5K, $75K, $1M, $15M). Each one makes the base deeper and adds 2 pet slots and 1 incubator.

**Pet Index:** every pet you hatch is recorded. Money rewards for discovering 5, 10, 15 and 20 different pets ($25K, $300K, $3M, $30M).

### 2.9 Speed: treadmills, trails and rebirth

- **Treadmills (Candy):** 7 tiers, Rusty to Cursed (0 to 150,000 Candy). A new one spawns in front of your base and replaces the old one. Step on and your character runs by itself, earning Speed XP (1 to 64 XP/s by tier). Jump to get off.
- **Trails (Money):** sold in the new Trails tab of the Speed Shop. A trail multiplies the XP your treadmill gives: a 30 XP/s treadmill with a 1.5x trail gives 45 XP/s. You keep every trail you buy and equip one at a time, and it shows as a visible trail behind your character.
- **Speed Levels:** each level makes you 1.85% faster. Level 0 = 16, level 50 ≈ 40, level 100 (max) ≈ 100. Each level costs 12% more XP than the last up to level 70 (6 XP for level 1, about 15,000 for level 70), then 5% more (about 65,000 for level 100). With a fitting treadmill, rebirth and trail a level takes roughly 10 to 40 seconds.
- **Rebirth:** opens at Speed Level 10, then 20, 30, 40, 55, 70, 85 and 100 (8 rebirths). It resets your Speed Level and XP and raises your XP multiplier: x2 after the first rebirth, x3 after the second, up to x9. Pets, eggs, Money, Candy, treadmills, trails and costumes are kept.
- **Total training speed:** treadmill XP/s × trail × rebirth multiplier.

Suggested trail ladder (the build in Studio may tune these):

| Trail | XP boost | Price (Money) |
|---|---|---|
| Candle Smoke | 1.25x | 1,800 |
| Bat Swarm | 1.5x | 18,000 |
| Candy Sparkle | 2x | 135,000 |
| Ghost Wisp | 2.5x | 1,050,000 |
| Pumpkin Fire | 3x | 6,600,000 |
| Blood Moon | 4x | 42,000,000 |
| Nightmare Shadow | 5x | 225,000,000 |

### 2.10 Costumes

Money buys costumes from mannequins in the Costume Shop. They visibly dress your character, set which doors give you Candy and add bonus Candy to every knock.

| Tier | Costume | Price (Money) | Candy bonus |
|---|---|---|---|
| 1 | Bedsheet Ghost | 150 | +10% |
| 2 | Pumpkin Head | 900 | +25% |
| 3 | Witch | 5,400 | +50% |
| 4 | Vampire | 30,000 | +75% |
| 5 | Glowing Skeleton | 165,000 | +100% |
| 6 | Werewolf | 900,000 | +150% |
| 7 | Grim Reaper | 4,800,000 | +200% |
| 8 | Mummy | 21,000,000 | +300% |
| 9 | Frankenstein | 105,000,000 | +400% |
| 10 | Red Devil | 450,000,000 | +500% |

### 2.11 Pacing targets (set 1 October 2026)

These come from a simulation of an active player (about 40% of the time on the treadmill, 25% knocking, 35% stealing), so a normal player takes roughly 1.5 to 2 times as long. The aim: a purchase every few minutes in the first hour, no wait longer than about 30 to 45 minutes before the very end, and everything finished in about 8 to 10 hours of real play.

| Milestone | Active player |
|---|---|
| First costume, steal from house 2 | 2 to 3 min |
| Steal from house 4 | 16 min |
| Steal from house 6 | 45 min |
| Steal from house 9 | about 2 h |
| All 10 costumes, 7 trails, 4 base upgrades | about 4 to 5 h |

Money sinks and gates: costumes (also gate the candy per door), trails (XP multiplier), base upgrades (pet and incubator slots) and Index rewards. Candy only buys treadmills, so it has nothing to buy after the Cursed Treadmill (see 5.1).

### 2.12 Interface

- **Style:** chunky cartoon simulator UI. White studded panels with a thick black outline, the menu icon and name sticking out over the top-left corner, a big red X, cyan boxes, glossy gradient buttons and white text with a black outline. Menus pop open in the centre of the screen and buttons bounce.
- **HUD:** Money and Candy on the right side in big gold and pink numbers with coin and candy icons; night/day timer at the top; "RUN!" banner during a chase; Speed Level bar at the bottom (orange to yellow) with walk speed, rebirth multiplier and a + button to the Speed Shop; friend boost bottom left; menu buttons (Rebirth, Index, Pets, Eggs, Store) on the left.
- **Rebirth menu:** this rebirth vs the next side by side (XP multiplier, Speed Level reset), a warning line, a level bar towards the next rebirth, and Rebirth and Train Faster buttons.
- **Pets and Eggs menus:** darker inventory window with a blue title bar, search box, card grids with coloured rarity splashes and counts, and Equip Best / Hatch Best at the bottom.

## 3. Built so far

The main copy is the **SpookyStealV3.2** place, kept in the GitHub repo vituyy/bib (place/SpookyStealV3.2.rbxl) together with all scripts. Nothing is published yet.

**Working and playtested**

- Hub with 5 bases, Speed Shop and Costume Shop; one street of 9 unique houses (mummy tomb, witch cottage, farmhouse, zombie diner, gravedigger crypt, Vlad's manor, Banshee Hall, Horseman's Hollow, Lich King's keep).
- Whole map scaled up: houses 1.75x bigger, lots 2x deeper and 1.5x longer, street about 2,100 studs, hub 430 × 260, bases 56 × 56.
- House 1 fully upgraded into an Egyptian mummy tomb, inside and out (great hall, burial chamber, treasure vault, golden egg altars).
- Trick-or-Treat with costume checks and roast lines.
- Egg stealing, owner chase that stops at the Level 1 line, catch and stun, delivery to base. All 9 owners and 47 eggs spawn.
- Day/night cycle with egg respawn and street closing.
- Auto-running treadmills, Speed XP, levels and rebirth.
- **Free hatching** in 3+ incubators, pets on the base earning Money, pet inventory with Equip Best, friend boost.
- New cartoon HUD and menus (Rebirth, Index, Pets, Eggs, Store, Speed Shop). Saving with DataStore (needs a published place to actually save).

**Art**

- 65 AI-generated studs models (9 owners, 20 pets, 20 egg designs, 10 costumes, 6 props) plus House 1's custom props. Costumes really dress the character and the mannequins wear them.
- Map decoration: street lamps, dead trees, gravestones, fences, pumpkins, cauldrons, purple haze, stars and a moon.

**Version 2 changes (done in V3.2)**

- Blank tattersall map with themed floors and walls per level, all houses and props in rows on the side, old map backed up.
- Trails tab and trail multiplier.
- One egg design per pet, rarity signs removed.
- Wandering pets.
- 10-second day.

**Safety (added 1 October 2026)**

- **Save lock:** a player's save is stamped with the server that has it open, so two servers can't both load it (no duplicating items by rejoining quickly). A crashed server blocks a player for at most 4 minutes. A loaded save is repaired (NaN or negative numbers, unknown pets, eggs or costumes are fixed or removed) so one bad value can't break the game.
- **Codes:** the Store menu has a Codes box. Each code can be used once per player and is not case sensitive. They live in `CODES` at the top of `ShopService.luau` (server only, so players can't read them). Current codes: DEV01 gives $100,000 and DEV02 gives 10,000 Candy. Five wrong codes in a minute lock the box for a minute.
- **Prompt range checks:** doors, eggs, mannequins and the upgrade sign check that the player is really standing next to them, because cheats can fire prompts from anywhere.
- **Movement check:** if a player keeps moving much faster than the speed the server gave them for 2 seconds, they are put back where they were last fine.
- Every purchase and menu action already goes through one server function that re-checks costs, ownership and rate.

## 4. Execution plan

Each phase ends with a playtest in Studio. ✓ done, ◐ in progress, ○ not started.

### Phase 1: Core game

- ✓ Core loop scripted end to end
- ✓ 9-house street, hub, day/night, owners and chases
- ✓ Treadmills, speed levels, rebirth
- ✓ Eggs, incubators, pets, income
- ✓ Costumes and Trick-or-Treat gating

### Phase 2: Version 2 changes (Studio rebuild)

- ✓ Blank tattersall map with level themes, models on the side
- ✓ Trails: Trails tab, XP multiplier, visible trail effect
- ✓ 20 egg designs, pet chosen at spawn, no rarity signs
- ✓ Pets wander around the base
- ✓ Day shortened to 10 s

### Phase 2b: Version 3 UI and pets

- ✓ Cartoon UI: studded menus, HUD, Rebirth menu, Speed Level bar
- ✓ Pets inventory, Equip Best, Pets and Eggs window, Hatch Best
- ✓ Friend boost (+10% Money per friend)
- ◐ Playtest the new UI in Studio on PC and phone; swap the drawn Money/Candy icons for uploaded pictures

### Phase 3: World building (Viktor, by hand)

- ○ Place the houses on their lots and dress each lot to its theme
- ○ Upgrade houses 2 to 9 to the same quality as the House 1 tomb
- ○ Interiors: furniture, hiding spots and room layouts that make the chase interesting
- ○ Real treadmill model per tier
- ○ Check every door, egg spot and owner spawn still works after placing houses

### Phase 4: Game feel

- ○ Animations: owner run and grab, pet walk and idle, hatch reveal, costume change
- ○ Sounds and music: night ambience, door knock, alarm when an owner spots you, chase music, hatch fanfare
- ○ Feedback: "RUN!" banner, screen shake on catch, Candy and Money flying to the HUD
- ✓ Owner pathfinding through rooms, doors, windows and stairs (untested in Studio)
- ◐ UI polish and a mobile-friendly layout (new UI done, phone layout still to test)

### Phase 5: Balance

- ○ Spreadsheet the full progression (Candy per night, Money per hour, time to each costume, trail and speed level)
- ○ Fix the speed-vs-owner gaps listed in section 5
- ○ Tune house rarity odds, hatch times, pet income and trail prices so a new player reaches house 3 to 4 in their first session

### Phase 6: Retention and social

- ○ Tutorial for the first night, including how to read egg designs
- ○ Pet index that shows each pet's egg design once discovered
- ○ Offline earnings, daily rewards, quests
- ○ Leaderboards (Money, Speed Level, rebirths)

### Phase 7: Launch prep

- ○ Publish privately, turn on API access, test saving
- ○ Anti-exploit checks on the server (speed, teleport, remote spam)
- ○ Monetisation (see section 5)
- ○ Game icon, thumbnails, description, max players set to 5
- ○ Friends-only test, fix bugs, then public release around Halloween

## 5. What the concept is still missing

### 5.1 Design decisions to make

1. **Stealing from other players.** In Steal an Egg the big hook is raiding other players' bases. Right now you only steal from NPC houses. Decide whether players can steal eggs or pets from each other, and how bases are protected (locks, shields, timers). Wandering pets would make a base raid look great.

**2. Rebirth vs. speed.** Rebirth resets Speed Level to 0, so a player who rebirths becomes too slow for the houses they were stealing from. The XP multiplier (x2, x3, ...) and trails help them climb back faster but don't fix it. Decide what rebirth keeps (e.g. a speed floor, or reset only XP) and what else it gives.

3. **New-player escape.** *(Done 1 October 2026: house 1's owner runs at 14 and house 2's at 17.)* A new player carrying the smallest egg runs at about 15, so house 1 can always be escaped. Check in Studio that the owner starting inside the house still feels fair.

**4. Endgame.** Outrunning the Lich King (72) while carrying a Secret egg needs about Speed Level 93 (max is 100). Decide what comes after house 9: more streets, a boss house, prestige worlds, limited events.

5. **Reading eggs.** With no signs, a new player can't tell a Common egg from a Mythic one. Decide how much help to give: only size, a subtle glow for Legendary and up, or the pet index revealing designs as you discover them (recommended).

6. **Egg design surprise.** Eggs now always hatch the pet they look like. Decide whether a small chance of a "mutated" or golden version would add excitement without breaking trust in the designs.

7. **Candy after treadmills.** Once you own the Cursed Treadmill, Candy has nothing to buy. Options: speed potions, egg-luck boosts, costume dyes.

**8. Pet management.** The base holds 10 to 18 pets and the inventory 60; selling pays 30 s of income. Decide on merging duplicates, trading, pet levels, or more inventory space as a Money sink.

9. **Caught penalty.** The owner takes the egg and you're stunned for 1.5 s. Consider whether that is enough on the far houses.

**10. Shared eggs.** 5 players share 47 eggs per night. Decide whether eggs are first come first served or per player, and whether players can help or block each other during a chase.

11. **Dark vs. bright.** The tattersall colours are brighter than the original dark Halloween palette. Check in game that night lighting keeps the spooky mood.

### 5.2 Content gaps

- A distinct gameplay twist per house (traps, locked rooms, guard pets, lights that wake the owner) so houses 4 to 9 feel different, not just faster.
- Owner personalities: voice lines, a reaction when they spot you, a unique catch animation.
- Shoes (trails are now in).
- Seasonal and limited eggs, and events like a Blood Moon night with double rare eggs.

### 5.3 Systems not yet designed

- Tutorial and first-session flow.
- Monetisation: game passes (2x Candy, extra incubator, more pet space, VIP), developer products (instant hatch, speed potion, egg-luck boost, premium trails). Keep it fair: nothing that makes you uncatchable.
- Retention: daily rewards, quests, offline earnings, group rewards.
- Leaderboards and the pet index.
- Trading (if wanted), with scam protection.
- Anti-exploit and save protection (move to ProfileStore before launch).
- Mobile and console controls.
- Audio.
- Analytics: where players quit, which house they get stuck on.

### 5.4 Suggested next three steps

1. Build the map by hand on the new tattersall layout, starting with the hub and houses 1 to 3.

2. Decide on player-vs-player stealing and the rebirth rule, because both change the economy.

3. Build a balance spreadsheet with the new trail multipliers and fix the first-house escape problem before any public test.
