# Spooky Steal: New Player Tutorial Plan

Version 1, 3 October 2026, for place file **SpookySteal-V6**. This plan is written so that two different workers can pick it up:

- **Worker A: the code agent** (Claude Code in the repo, no Studio, cannot see the game). It does the logic, data, rules and text.
- **Worker B: the Studio agent** (an AI or a person who can open the place in Studio, see the screen and playtest). It does everything that has to be looked at: layout, models, effects, sounds, camera feel.

Section 6 says exactly who does what. Section 7 is a ready-to-paste brief for Worker B.

---

## 1. Goal and principles

**Goal:** a brand-new player has made their first pet, understood how Speed, costumes, treadmills and Money connect, and *wants to go back out at night*, within about **8 to 10 minutes**, without reading a manual.

1. **Do it, don't read it.** Every lesson is an action in the real world. Text is one short line (at most 12 words) at a time.
2. **One new idea per step.** Never teach two mechanics in the same step.
3. **A reward every 60 to 90 seconds.** A level-up, a door scene, an egg, a hatch. Each gets a sound, a flash and a number going up.
4. **Safe first, scary second.** The first chase cannot be lost. The first real danger (a faster owner and the kick) comes *after* the player has something to lose and is told it is fine.
5. **Never lock the player in.** There is always a Skip button, the tutorial never blocks walking, buying or knocking. If the player does a step early, it ticks off by itself.
6. **Same world, no tutorial map.** The tutorial runs on the real street, the player's real base and the real shops. A separate map would cost a lot and teach the wrong layout.
7. **Personality.** A small guide character with jokes makes the chore feel like a story (see 4.1).
8. **Teach just in time.** Rebirth, Index, trails, Pet Capacity, Hatching Pads and codes are *not* in the tutorial. They pop up as one-line hints the first time they matter (section 5).

## 2. What the tutorial must teach

| # | Mechanic | Where it is taught | The one sentence the player should walk away with |
|---|---|---|---|
| 1 | Costumes (Candy buys them) | Step 1 | "Costumes make me better at everything." |
| 2 | Running earns Speed XP, Speed Level makes me faster | Step 2 | "Running = faster." |
| 3 | Treadmill multiplies XP | Step 3 | "The treadmill makes it grow faster." |
| 4 | Trick-or-Treat gives Candy, the costume tier matters | Step 4 | "Good costume = more Candy; weak costume = refused." |
| 5 | Night: eggs can only be stolen at night | Step 5 | "Eggs come out at night." |
| 6 | Stealing, the chase, "!" marker, escaping to base | Step 5 | "Grab the egg, run home." |
| 7 | Incubator, hatching, pets earn Money | Step 6 | "Eggs become pets, pets pay me." |
| 8 | Spend Money on a better treadmill | Step 7 | "Money makes me train faster." |
| 9 | Getting caught: lose the egg, get kicked, no real loss | Step 8 (optional "brave" step) | "Being caught only costs me the egg." |
| 10 | Owner speed vs. my speed (why levelling matters) | Step 8 | "Faster than the owner = safe." |

## 3. The flow, step by step

Total time for an average player: **8 to 10 minutes**. The tracker (4.2) shows the steps as a checklist with a progress bar. Each step has *trigger*, *player action*, *guide line*, *reward* and *edge cases*. Numbers come from `Config.luau` (V5.0).

### Step 0: Arrival (about 10 s)
- **Exists already:** a new player (no costume owned) spawns in front of the Costume Shop with 100 Candy and yellow arrows.
- **Add:** a short camera move from the street sign "SPOOKY STREET" down to the player, the guide appears with a pop and says "Psst! New here? Get dressed. Nobody steals eggs in plain clothes." The tracker slides in with step 1 highlighted.

### Step 1: Get a costume (about 20 s) *(logic exists)*
- **Action:** walk to the Bedsheet Ghost, press E.
- **On buy:** costume pops onto the character, confetti, a "ding", the Candy number drops from 100 to 0 with a short count-down, and the multiplier sign on the stand ("x2 Candy, 1.5 XP/s") pulses once.
- **Guide:** "Ooh, scary! Now you earn 1.5 XP every second you run."
- **Edge cases:** dying respawns at the shop until a costume is owned (exists). If the player ignores the arrows for 20 s the guide hops over the costume.

### Step 2: Run and level up (about 30 s)
- **Trigger:** costume bought. **Action:** run anywhere ("Run around! Any direction!").
- **Feedback:** the Speed Level bar at the bottom is highlighted; XP numbers pop up ("+1.5") while moving; standing still shows "no XP". The first level costs 20 XP, so about 13 s of running. When it fills: "LEVEL UP! Speed 21.5", a whoosh, a short trail of sparks on the character.
- **Tutorial boost:** x3 XP during the tutorial only, so the first level arrives in about 5 s and the second in about 10 s (tune in section 8).
- **Guide:** "See that bar? Fill it and you run faster. Faster = safer."

### Step 3: Your base and the treadmill (about 45 s)
- **Trigger:** one level gained. **Action:** follow a glowing path (arrows or a beam) to the player's own base and step onto the treadmill.
- **Feedback:** the treadmill belt scrolls, the XP number shows the treadmill factor ("x1 Rusty Treadmill: later you can buy better ones"), the guide stands next to the base sign "YOUR BASE".
- **Guide:** "This is home. Treadmills multiply your XP. Buy better ones later with Money."
- **Rule to show:** the treadmill cannot be used while carrying an egg (a one-line hint if the player tries during step 5).
- **Edge cases:** if the player already used the treadmill before this step, tick it off silently.

### Step 4: Trick-or-Treat at House 1 (about 60 s)
- **Trigger:** treadmill used for 5 s. **Action:** follow the path to the Old Witch's door (House 1), press E to knock.
- **Scene (exists):** door opens, the owner says Happy Halloween, Candy flies into the counter (x2 from the Ghost costume, so 10 Candy).
- **Make it special for the tutorial:** the first knock is *always answered* (never "busy", never day).
- **Guide:** "Candy! Costume multiplies it. Better houses need better costumes. Remember that."
- **Reward:** a big "+10 Candy" with the pink candy icon flying to the HUD counter.
- **Optional lesson (10 s):** the player is invited to knock House 3 or 4 later, where the door says "Needs Pumpkin Head!" This is *not* forced, a hint is queued for the first time they meet a refusal.

### Step 5: Steal your first egg (about 2 min), the main event
- **Trigger:** Candy received. **Action:** walk into the Witch's cottage (through the door that is open now or a window), find the glowing egg on its nest, press E.
- **Night note:** nights last 300 s and the day only 10 s, so the street is almost always open. If it happens to be day, the guide says "Wait for dusk, it only takes a few seconds!" and shows a countdown.
- **Safe first chase:** the owner's reaction time is increased and his speed is slowed to 12 for this one theft (the Old Witch is 17, the player has 20 plus the level gained). The owner still chases, the "!" appears, the red RUN banner shows, but he cannot catch the player. Do not tell the player this.
- **Guide:** "RUN! Back to your base! He's slow, but don't tell him I said that."
- **Path:** a bright arrow path from the house to the base while the chase is on. The egg is visible in the player's hands (exists).
- **Arrive at base:** a green "SAFE!" flash, a cheer sound, the RUN banner turns into "Escaped!".
- **Edge cases:** died, left, or day came: egg is put back and the step restarts at the egg. If the player lets the owner reach them anyway (cannot happen with the safe chase, but test), no kick in this step.

### Step 6: Hatch it (about 60 s)
- **Trigger:** egg delivered. **Action:** open the Eggs menu (button glows), choose the egg, put it on the hatching pad. A Swamp Egg hatches in 10 s.
- **Feedback:** a countdown ring above the pad, the egg wobbles more and more, then a hatch reveal (flash, light burst, the pet pops out, name and rarity text, "NEW!" in the Index).
- **Wow factor (design decision, see 8):** the tutorial egg is always a *Big* pet (x3 income) so the first reveal feels special.
- **Pet walks around the base and starts earning:** "$ +3 per second" floats up from the pet every second for 5 seconds so the player sees the connection.
- **Guide:** "A Bog Toad! It makes Money while you sleep. Well, while you play."
- **Edge cases:** pet capacity and pads are not mentioned here. If the player opens the wrong menu, the right button keeps pulsing.

### Step 7: Spend Money (about 45 s)
- **Trigger:** first Money received. **Action:** open the Speed Shop, buy the Wooden Treadmill ($500, x2 XP).
- **Gift:** if the player has less than $500 after 60 s, the tutorial adds the missing Money ("Starter gift!") so the step never stalls. The numbers show how many seconds of income that would have been.
- **Feedback:** the old treadmill is replaced by the new model with a puff of smoke and the XP number doubles on the next run ("x2").
- **Guide:** "Double XP! You'll be faster than the owners soon."

### Step 8: The brave test (optional, about 60 s)
- **Trigger:** treadmill bought. A card appears: "Optional: dare to steal from House 2 and see what happens?" with Yes / Later.
- **If Yes:** a path to the Friendly Mummy (speed 38, faster than the player). The player steals, gets chased, the owner catches them, the **kick** plays (sound, flight of about 100 studs). The egg returns to its nest, the guide laughs and explains: "Caught = you lose the egg. That's all. Level up, try again."
- **Reward:** a "Brave" badge and a free Candy bonus. The step is optional, nobody gets stuck.

### Step 9: Graduation (about 20 s)
- **Trigger:** step 8 done or skipped, or 8 minutes passed.
- **Screen:** "You're a Spooky Stealer!" with a short list "Next goals": reach Speed 40 for House 2, get the Pumpkin Head costume (400 Candy) for House 4, hatch 5 different pets for the first Index reward.
- **Reward pack:** a small Money gift and a visible "Starter" badge. The tracker minimises into the normal goals list. Tutorial state is saved as **done**.

## 4. Components

### 4.1 The guide character
- A floating pumpkin ghost or small ghost ("Boo", name is open) that hovers near the player, bobs, points at targets, and reacts with emotes: cheer, laugh, flinch.
- Lines are in a speech bubble above the guide (reuse the dark bubble with white text style of the owner's door scene) *and* in the tracker, so players who look away can read them.
- Voice: short, funny, never mean. Tone examples are in the step texts above. Maximum 12 words per line.
- Also appears on follow-up hints (section 5).

### 4.2 The tracker
- Top-left card: title "Getting started", 9 rows with checkboxes, current step in bold and a sub-line with the hint, a progress bar "3 / 9", a small **Skip** button (asks "Skip the tutorial? You keep your starting stuff.").
- Completed rows tick with a pop and a small sound. The card auto-collapses on phones to a one-line version.

### 4.3 World guidance
- **Path arrows** (exists, generalise): from the player to the current target. Replace the evenly spaced chevrons with a glowing line or beam that hugs the ground and re-routes around obstacles (use `PathfindingService` to place the points).
- **Target highlight:** a yellow `Highlight` on the thing to use (costume, door, egg, incubator, shop) and a floating icon with a distance.
- **Off-screen indicator:** an edge-of-screen arrow when the target is behind the camera.
- **Prompt hints:** the ProximityPrompt of the current target is bigger and pulses.

### 4.4 Reward feedback ("juice")
Every tick on the tracker plays: sound, confetti or sparkle burst at the player, a number pop ("+10 Candy", "Level 2!"), the matching HUD counter bounces. Keep it under 1.5 s so it never blocks play.

### 4.5 Camera
Three short non-blocking moments only: the intro pan (step 0), the hatch reveal zoom (step 6) and the graduation orbit (step 9). The player can always skip with any input.

## 5. Just-in-time hints (after the tutorial, one time each)

Small guide popups, shown the first time the situation happens, never twice.

| Trigger | Hint |
|---|---|
| Knock refused ("costume not good enough") | "Candy buys better costumes. Check the shop!" |
| Money reaches the Pet Capacity price | "Your base is filling up. Upgrade Pet Capacity!" |
| Eggs in the bag and all pads busy | "All pads busy. Upgrade Hatching Pads for more." |
| First rare variant (Big, Golden...) | "A Golden Bog Toad! Variants earn way more." |
| First time Speed Level reaches the rebirth level | "You can Rebirth: reset your level for permanent x2 XP." |
| First time a faster owner is next to the player | "He's faster than you. Level up or hide!" |
| First time the player carries an egg to the treadmill | "No treadmill while carrying an egg." |
| 60 s idle at night in the hub | "Houses are open! Go knock or steal." |
| First day/night change | "Dawn! Eggs reset when night comes back." |

## 6. Who does what

### 6.1 Worker A (code agent, no Studio): can be done with good quality
These are logic and data changes. They can be written, syntax-checked and unit-tested with the Luau tools in this repo, and shipped by `tools/sync_place.py`.

| Task | Details |
|---|---|
| Tutorial state machine | Steps, triggers, completion events, skipping, early completion, restarts on death or day/night change. One table in `Config.Tutorial` (id, title, hint, guide line, reward, trigger name). |
| Persistence | `data.Tutorial = { Step = n, Done = bool }` in `Config.StartingData`, sanitising in `DataService`, migration so existing players are marked done. |
| Event hooks | Fire step events from the existing services: costume bought, level up, treadmill used, knock done, egg stolen, egg delivered, egg placed, hatched, treadmill bought, caught, day/night. |
| Server rules | Safe first chase (slow owner, longer reaction), always-open first knock, starter Money gift, tutorial XP boost, guaranteed Big first pet, the optional brave step, rewards. All server-side, validated, cannot be farmed (each reward once). |
| Objective tracker (functional) | A working card with checklist rows, progress bar, Skip, built in code in the existing client script with the existing UI helpers. |
| Guidance (functional) | Replace the chevrons with a path made of waypoints from `PathfindingService`, `Highlight`s, off-screen arrow and distance text. |
| Hints system | The table in section 5 as data, one-time flags saved, queueing so two hints never overlap. |
| Replay | A "Replay tutorial" button in the Store menu. |
| Funnel logging | `step id` + time in seconds written to the log and a counter so completion can be measured. |
| Text and balance | All lines, numbers, timings (tuned with the simulator in the repo). |
| Docs | Keep `docs/design-and-plan.md` section 2.13 and this file up to date. |

**Constraints for Worker A** (from `CLAUDE.md`): new scripts cannot be synced, so the owner must first add **empty** scripts in Studio, or the code goes into existing ones. Suggested empty scripts: `ServerScriptService.Server.Services.TutorialService` (ModuleScript) and `StarterPlayer.StarterPlayerScripts.Client.Tutorial` (LocalScript). Worker A cannot see the result, so every visual number (sizes, colours, offsets) is a first guess.

### 6.2 Worker B (Studio agent or person who can see the game): must be done by someone who can look at it

| Task | Why it needs eyes |
|---|---|
| **UI look and feel** of the tracker, guide bubbles, reward popups, Skip dialog, graduation screen | Layout, scale on phone, tablet and PC, safe areas, font sizes, colours matching the studded cartoon UI. Worker A can only build the structure. |
| **Guide character model and animations** (idle bob, point, cheer, laugh, flinch) | A model, rig and animation assets. Worker A can only move an existing part. |
| **Visual effects**: confetti, sparkles, level-up whoosh trail, hatch reveal burst, "SAFE!" flash, smoke on treadmill swap | Particle tuning is a look. |
| **Sounds and music**: ding, level-up, door knock, cheer, egg wobble, hatch pop, guide voice blips, kick (replace the built-in ones) | Needs uploads and listening. |
| **Camera moves** (intro pan, hatch zoom, graduation orbit) | Needs framing and timing by eye. |
| **Hatch reveal sequence** | The most important "wow", needs the egg model, a pet pedestal, camera and VFX tuned together. |
| **World signage**: "YOUR BASE" sign, "START HERE" sign, a signpost with arrows at the hub, door numbers | Placement and models. |
| **Treadmill model per tier** (still missing in the game) | The step where the treadmill is swapped should look different. |
| **Playtest and tune** on phone (device emulator), tablet and PC, controller | Prompts, readability, reach of buttons. |
| **Check the physical route** of the guidance path: no clipping into fences, correct height on slopes, doors and windows that open | Needs walking it. |
| **Check the kick** lands in a sensible place and the owner animation looks right | Physics feel. |
| **Pacing pass** | Time each step with a real person, cut or merge steps that run long. |

### 6.3 Handoff order (so the two never overwrite each other in the single place file)
1. **Owner:** adds the two empty scripts in Studio, uploads the place, tells Worker A.
2. **Worker A:** builds the logic layer and a bare working tutorial, syncs the place, commits, gives the download link.
3. **Owner downloads the place and gives it to Worker B** (or opens it in Studio with Worker B's AI).
4. **Worker B:** does all of 6.2 in Studio, **without renaming the objects and Remotes that Worker A's scripts use** (the list is in the brief, 7), saves and uploads the new place.
5. **Worker A:** re-extracts the scripts into `src/` (see `CLAUDE.md`), fixes any logic issue Worker B found, and re-syncs. Repeat once more for polish.

Only one worker edits the place at a time.

## 7. Brief for Worker B (paste this)

> You are working on the Roblox game **Spooky Steal** (place file `SpookySteal-V6.rbxl`). Read `docs/design-and-plan.md` first (sections 2.10 to 2.13), then `docs/tutorial-plan.md`. A teammate (Claude Code in the repo, who cannot see the game) built the tutorial logic. **Your job is the look and feel of the first-time tutorial and nothing else.**
>
> 1. Open the place and play as a brand-new player (delete your saved data or use a new test account). Walk through the tutorial and note everything that looks wrong or feels slow.
> 2. Make the UI in `StarterPlayerScripts.Client.Main` (tracker card, guide bubble, reward popups, skip dialog, graduation screen) look good and readable on a phone, tablet and PC. Match the existing studded white panels with black outlines, cyan boxes and glossy gradient buttons.
> 3. Make the guide character (model, rig, idle/point/cheer/laugh animations) and the sound effects, particles, camera moves and hatch reveal described in section 6.2.
> 4. Do **not** change the game rules, prices, speeds, or the names of: the Remotes in `ReplicatedStorage.Remotes`, the attributes `TutorialSpawn`, the tag `TutorialCostume`, any `Config.*` table, or the services' function names. If you must, tell the owner so the code agent can adapt.
> 5. Keep every tutorial animation under 1.5 s (except the three camera moments in 4.5), always skippable.
> 6. Save, upload, and list in your report: what you changed, the asset ids you uploaded (sounds, animations), and anything that looked broken that you did not fix.
>
> **Acceptance check:** a stranger on a phone finishes the tutorial in under 10 minutes without asking a question, can name 3 things they did (buy a costume, steal an egg, hatch a pet), and the Skip button works at every step.

## 8. Open decisions for the owner

1. **Guaranteed Big first pet** (x3 income) for the wow moment: yes or no. It makes the first hatch special but gives every player a head start worth about 3x of a Bog Toad ($9/s).
2. **Starter Money gift** of $500 so the treadmill step never stalls: yes or no (the simulation says a new player affords $500 after about 2 minutes anyway).
3. **Tutorial XP boost** (x3) for the first few minutes: keep it short, or the economy in section 2.11 shifts.
4. **Safe first chase** where the owner cannot catch the player: acceptable, or should the first chase be real?
5. **The brave step** (getting kicked on purpose) as optional or removed.
6. **Guide name and look:** ghost, pumpkin, bat, or a skeleton? Any voice or just text and blips?
7. **Skip default:** show Skip from step 1, or only after step 3 so nobody skips the costume lesson.
8. **Existing players:** mark them done silently, or offer "Replay tutorial" once.

## 9. How we will know it works

Measured by the funnel log (Worker A) and by watching 3 to 5 new players (Worker B or the owner):

| Metric | Target |
|---|---|
| Players who finish step 6 (first hatch) | 80% or more |
| Time from join to first hatch | 5 min or less (median) |
| Tutorial finished or skipped by minute 10 | 95% |
| Quits before step 3 | under 10% |
| Players who return for a second night | 50% or more (day-1 retention is a later metric) |

If one step loses more than 15% of the players, cut or simplify that step first.

## 10. Phases

| Phase | Worker | Output | Time (rough) |
|---|---|---|---|
| 0 | Owner | Two empty scripts added, decisions in section 8 answered | 10 min |
| 1 | A | State machine, data, rules, hooks, bare tracker, hints, replay, funnel log | 1 session |
| 2 | B | UI, guide, VFX, sounds, camera, hatch reveal, signs | 2 to 3 sessions |
| 3 | A + B | Playtest with 3 to 5 new players, fix the worst drop-off, tune | 1 to 2 sessions |
| 4 | A | Docs updated, final sync, release as the next version | short |
