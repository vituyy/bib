# Spooky Steal: Game Design & Execution Plan

Working title. Version 2, updated 29 September 2026 with trails, egg designs, wandering pets, the hand-built tattersall map and the 10-second day.

> **Repo note (30 September 2026):** this file was converted from `Spooky-Steal-Design-and-Plan.docx`. The code in `src/` (from SpookyStealV3.2) already contains every Version 2 change, so Phase 2 below is marked done.

## What changed in this version

| Change | Summary |
|---|---|
| Trails | New Trails tab in the Speed Shop. Bought with Money, a trail multiplies the Speed XP your treadmill gives. |
| Egg designs | Every pet has its own egg design that hints at the pet inside. No rarity signs above eggs: players judge an egg by its look. |
| Wandering pets | Pets walk around your base instead of standing on a plate. |
| New map | The map is stripped to themed baseplates and walls in the tattersall studs style. Viktor builds the rest by hand from models placed on the side. |
| Shorter day | The day now lasts 10 seconds (was 20). |

## 1. Overview

**Pitch:** A spooky Halloween street at night. Trick-or-Treat at every door for Candy, then sneak in through the windows and steal the owners' eggs while they chase you home. Hatch the eggs into Brainrot and Halloween pets that wander your base and earn Money, train your speed, buy costumes and trails, and take on bigger, scarier houses.

**Genre:** Roblox "steal and collect" tycoon, inspired by Steal an Egg.

**Players:** 6 per server, one base each.

**Look:** Tattersall studs style (two-tone checkered studs tiles), with each level in its own colour theme under dark Halloween night lighting.

**Core loop:** Trick-or-Treat → earn Candy → buy treadmills and train speed → steal eggs → escape the owner → hatch pets → earn Money → buy costumes and trails → unlock better houses → repeat at a higher level.

**Two currencies:**

| Currency | Earned from | Spent on |
|---|---|---|
| Candy | Trick-or-Treating at doors | Treadmills (speed training) |
| Money | Pets on your base, every second | Costumes (unlock better doors) and trails (faster training) |

## 2. Game description

### 2.1 The map

- **Hub** at the start of the street: 6 player bases (56 × 56 studs each), the Speed Shop (treadmills and trails) and the Costume Shop (mannequins). The hub is about 430 × 260 studs. Owners stop chasing at the Level 1 line, so the hub is safe.
- **The street:** one long straight road of 9 house lots, about 2,100 studs long. Each lot is its own level and harder than the one before. Houses have one or two floors and several rooms, and get grander along the street.
- No gates: every house can be broken into from the start. Progress is limited by speed (can you escape?) and costume (will they give you Candy?).

### 2.2 Map style and level themes

The map now starts as a blank layout that Viktor builds by hand:

- **What's in the blank map:** the hub floor and walls, the 6 base pads, the shop spots, the 9 lots each with their own floor and boundary walls, and the level lines.
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
| 1 | Friendly Mummy | 16 | 5 | None | 1 | 4 |
| 2 | Old Witch | 18 | 10 | None | 1 | 4 |
| 3 | Scarecrow | 21 | 20 | Bedsheet Ghost | 1 | 5 |
| 4 | Zombie Chef | 25 | 40 | Pumpkin Head | 2 | 5 |
| 5 | Gravedigger | 30 | 80 | Witch | 1 | 5 |
| 6 | Count Vlad | 37 | 160 | Vampire | 2 | 6 |
| 7 | Banshee | 46 | 320 | Glowing Skeleton | 2 | 6 |
| 8 | Headless Horseman | 58 | 650 | Werewolf | 2 | 6 |
| 9 | Lich King | 72 | 1,300 | Grim Reaper | 2 | 6 |

Owner speed grows roughly exponentially so the last houses need a well-trained runner. House 1 matches a brand-new player (16).

### 2.4 Trick-or-Treat

Walk up to a front door and knock to get Candy (20 s cooldown per house). If your costume is below the house's minimum, the owner refuses with a roast line such as "And you call this a costume? I'm not giving you my candy!"

### 2.5 Stealing eggs

- Climb in through a window, pick an egg by its look and hold the prompt for 1 s.
- The owner bursts out and chases the closest thief. Bigger, rarer eggs slow you down (95% down to 82% of your speed).
- Get past the Level 1 line and walk the egg to your base to keep it. If the owner touches you, they take the egg back and you are stunned for 1.5 s. Owners also give up after 30 s or when you are 150 studs ahead.

### 2.6 Day and night

A 5-minute night, then a **10-second day**. During the day every house closes, anyone on the street is sent home, and an egg still being carried crumbles. Every egg respawns when the next night starts.

### 2.7 Eggs: every pet has its own egg

- When an egg spawns, the game picks its pet straight away (using that house's rarity odds), and the egg takes that pet's design. The egg always hatches the pet it was made for.
- There are no signs or labels above eggs. Players learn to read the designs: a black egg with little ears is a Black Cat, an orange ribbed egg with a stem is a Pumpkling.
- Rarer eggs are bigger, more detailed and heavier to carry, which is the only built-in rarity hint.
- Eggs sit in nests (as in the reference screenshots).
- Hatching is free, in 3 incubators on your base. You can hold 12 unhatched eggs. Hatch time depends on rarity:

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

20 pets across 7 rarities. Up to 10 pets live on your base and earn Money every second. A pet can be sold for 30 seconds of its income.

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

**Wandering pets:** pets walk slowly around inside your base, stop now and then to idle, and never leave the base. Money pops up above each pet as it earns. Pets don't block players.

### 2.9 Speed: treadmills, trails and rebirth

- **Treadmills (Candy):** 7 tiers, Rusty to Cursed (0 to 150,000 Candy). A new one spawns in front of your base and replaces the old one. Step on and your character runs by itself, earning Speed XP (1 to 64 XP/s by tier). Jump to get off.
- **Trails (Money):** sold in the new Trails tab of the Speed Shop. A trail multiplies the XP your treadmill gives: a 30 XP/s treadmill with a 1.5x trail gives 45 XP/s. You keep every trail you buy and equip one at a time, and it shows as a visible trail behind your character.
- **Speed Levels:** each level makes you 4% faster. Level 0 = 16, level 20 ≈ 35, level 45 (max) ≈ 93.
- **Rebirth:** opens at Speed Level 25 (+5 per rebirth). It resets your Speed Level and gives a permanent +50% XP multiplier. Trails are kept.
- **Total training speed:** treadmill XP/s × trail × rebirth multiplier.

Suggested trail ladder (the build in Studio may tune these):

| Trail | XP boost | Price (Money) |
|---|---|---|
| Candle Smoke | 1.25x | 500 |
| Bat Swarm | 1.5x | 5,000 |
| Candy Sparkle | 2x | 40,000 |
| Ghost Wisp | 2.5x | 250,000 |
| Pumpkin Fire | 3x | 1,500,000 |
| Blood Moon | 4x | 8,000,000 |
| Nightmare Shadow | 5x | 40,000,000 |

### 2.10 Costumes

Money buys costumes from mannequins in the Costume Shop. They visibly dress your character and set which doors give you Candy.

| Tier | Costume | Price (Money) |
|---|---|---|
| 1 | Bedsheet Ghost | 50 |
| 2 | Pumpkin Head | 300 |
| 3 | Witch | 1,500 |
| 4 | Vampire | 7,500 |
| 5 | Glowing Skeleton | 35,000 |
| 6 | Werewolf | 150,000 |
| 7 | Grim Reaper | 600,000 |

## 3. Built so far

The main copy is the **SpookyStealV3.2** place in Roblox Studio (a copy lives in `place/`, and its scripts are in `src/`). Nothing is published.

**Working and playtested**

- Hub with 6 bases, Speed Shop and Costume Shop; one street of 9 unique houses (mummy tomb, witch cottage, farmhouse, zombie diner, gravedigger crypt, Vlad's manor, Banshee Hall, Horseman's Hollow, Lich King's keep).
- Whole map scaled up: houses 1.75x bigger, lots 2x deeper and 1.5x longer, street about 2,100 studs, hub 430 × 260, bases 56 × 56.
- House 1 fully upgraded into an Egyptian mummy tomb, inside and out (great hall, burial chamber, treasure vault, golden egg altars).
- Trick-or-Treat with costume checks and roast lines.
- Egg stealing, owner chase that stops at the Level 1 line, catch and stun, delivery to base. All 9 owners and 47 eggs spawn.
- Day/night cycle with egg respawn and street closing.
- Auto-running treadmills, Speed XP, levels and rebirth.
- Free hatching in 3 incubators, pets on the base earning Money.
- HUD and shop/egg/pet menus. Saving with DataStore (needs a published place to actually save).

**Art**

- 42 AI-generated studs models (9 owners, 20 pets, 7 costumes, 6 props) plus House 1's custom props. Costumes really dress the character and the mannequins wear them.
- Map decoration: street lamps, dead trees, gravestones, fences, pumpkins, cauldrons, purple haze, stars and a moon.

**Version 2 changes (done in V3.2)**

- Blank tattersall map with themed floors and walls per level, all houses and props in rows on the side, old map backed up.
- Trails tab and trail multiplier.
- One egg design per pet, rarity signs removed.
- Wandering pets.
- 10-second day.

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
- ○ Owner pathfinding through doors and stairs
- ○ UI polish and a mobile-friendly layout

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
- ○ Game icon, thumbnails, description, max players set to 6
- ○ Friends-only test, fix bugs, then public release around Halloween

## 5. What the concept is still missing

### 5.1 Design decisions to make

1. **Stealing from other players.** In Steal an Egg the big hook is raiding other players' bases. Right now you only steal from NPC houses. Decide whether players can steal eggs or pets from each other, and how bases are protected (locks, shields, timers). Wandering pets would make a base raid look great.

2. **Rebirth vs. speed.** Rebirth resets Speed Level to 0, so a player who rebirths becomes too slow for the houses they were stealing from. Trails help them climb back faster but don't fix it. Decide what rebirth keeps (e.g. a speed floor, or reset only XP) and what else it gives.

3. **New-player escape.** House 1's owner runs at 16, the same as a new player, and even the smallest egg slows you to 95%. On paper a new player can never outrun them and relies on the 30 s give-up or the 150-stud rule. Decide whether the first house should be slower or the thief gets a head start.

4. **Endgame.** The last house needs about Speed Level 44 with a Secret egg (max is 45). Decide what comes after house 9: more streets, a boss house, prestige worlds, limited events.

5. **Reading eggs.** With no signs, a new player can't tell a Common egg from a Mythic one. Decide how much help to give: only size, a subtle glow for Legendary and up, or the pet index revealing designs as you discover them (recommended).

6. **Egg design surprise.** Eggs now always hatch the pet they look like. Decide whether a small chance of a "mutated" or golden version would add excitement without breaking trust in the designs.

7. **Candy after treadmills.** Once you own the Cursed Treadmill, Candy has nothing to buy. Options: speed potions, egg-luck boosts, costume dyes.

8. **Pet management.** Only 10 pets per base and selling pays 30 s of income. Decide on merging duplicates, trading, pet levels, or more pet space as a Money sink.

9. **Caught penalty.** The owner takes the egg and you're stunned for 1.5 s. Consider whether that is enough on the far houses.

10. **Shared eggs.** 6 players share 47 eggs per night. Decide whether eggs are first come first served or per player, and whether players can help or block each other during a chase.

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
