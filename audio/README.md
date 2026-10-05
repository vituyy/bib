# Game audio

All music and sound effects are made by `python3 tools/make_audio.py` (needs `pip install numpy scipy` and `ffmpeg`). Change the script and run it again to re-tune a sound. Nothing here is copyrighted: it is all generated from code.

## Put them in the game (once)

1. In Roblox Studio open **View > Asset Manager**, choose the **Audio** tab and press **Bulk Import**. Select every `.mp3` in this folder. (Roblox checks audio before it is allowed: it can take a few minutes, and the account must be ID-verified for audio upload.)
2. When an upload is accepted, right-click it in the Asset Manager and **Copy ID**.
3. Send the list `file name -> id` to whoever maintains the code (or paste each id into `Id = ""` of the matching entry in `Config.Audio` in `src/shared/Config.luau`).

Sounds that have no id play a built-in Roblox sound (clicks, buy ping, error, kick) or stay silent (music, the rest).

## Files

| File | Config.Audio name | When it plays |
|---|---|---|
| `music_chill.mp3` | Music.Chill | Always, slow spooky waltz (68 s loop). Fades away during a chase and returns after. |
| `music_chase.mp3` | Music.Chase | While an owner chases you (50 s loop, fast and tense). |
| `music_blood.mp3` | Music.Blood | During the hourly Blood Moon (96 s loop, ominous). |
| `ui_click.mp3` | Click | Every button; pressing E on a prompt |
| `ui_hover.mp3` | Hover | Mouse over a button (not on phones) |
| `ui_open.mp3` / `ui_close.mp3` | Open / Close | A menu opens or closes |
| `ui_buy.mp3` | Buy | A purchase or other menu action worked |
| `ui_error.mp3` | Error | An action failed or a red message |
| `ui_candy.mp3` | Candy | You received Candy |
| `ui_levelup.mp3` | LevelUp | Speed Level up |
| `fanfare.mp3` | Fanfare | Rebirth |
| `egg_pickup.mp3` | EggPickup | You grabbed an egg |
| `egg_place.mp3` | EggPlace | An egg is put on a hatching pad |
| `egg_hatch.mp3` | EggHatch | A pet hatched |
| `chase_alert.mp3` | ChaseAlert | The owner starts chasing you |
| `escape.mp3` | Escape | You got an egg home |
| `caught.mp3` | Caught | The owner caught you (with the kick) |
| `kick.mp3` | Kick | The kick, heard by everyone nearby |
| `knock.mp3` / `door_creak.mp3` | Knock / DoorCreak | Trick-or-Treat: knocks, then the door opens |
| `blood_rise.mp3` | BloodRise | The Blood Moon rises |
| `thunder.mp3` | Thunder | Lightning flashes during the Blood Moon |
| `ui_notify.mp3`, `whoosh.mp3` | Notify, Whoosh | Spare effects, not used yet |

`Grunt` (the "oof" after the kick) has no file: it uses Roblox's built-in grunt unless you give it an id.

Players can switch music and sound effects off in the **Store** menu. The setting is kept until they leave the game.
