# Notes for Claude

- The owner does not use Rojo or copy/paste code. They download `place/SpookySteal-V6.rbxl` and open it in Studio.
- After changing anything in `src/`, always run `python3 tools/sync_place.py` (needs `pip install lz4 zstandard`)
  so the place file contains the new scripts, and commit the place file with the change.
- A brand-new script file in `src/` can't be synced (the tool only updates scripts already in the place).
  Put new code in an existing script or ModuleScript, or ask the owner to add an empty script in Studio first.
- If the owner uploads a newer place file, copy it over `place/SpookySteal-V6.rbxl` and re-extract the scripts into `src/`.
- A place file uploaded on github.com ("Add files via upload") lands on the repo's default branch, which is `claude/inspiring-bohr-18n3sq`, not `main`. Look there first (`git fetch`, then `git ls-tree -r origin/claude/inspiring-bohr-18n3sq`).
- `src/client/Main.client.luau` is at Roblox's limit of 200 local variables alive at once. One more top-level `local` (even inside a `do` block at the end) makes Roblox refuse the whole script and the player sees no HUD at all. `luau-compile` does not catch this. Put new client code in another client script (for example `CostumeLabels.client.luau`) and run `python3 tools/check_locals.py <path to luau-ast>` after changing any script.
