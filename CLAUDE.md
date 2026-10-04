# Notes for Claude

- The owner does not use Rojo or copy/paste code. They download `place/SpookyStealV3.2.rbxl` and open it in Studio.
- After changing anything in `src/`, always run `python3 tools/sync_place.py` (needs `pip install lz4 zstandard`)
  so the place file contains the new scripts, and commit the place file with the change.
- A brand-new script file in `src/` can't be synced (the tool only updates scripts already in the place).
  Put new code in an existing script or ModuleScript, or ask the owner to add an empty script in Studio first.
- If the owner uploads a newer place file, copy it over `place/SpookyStealV3.2.rbxl` and re-extract the scripts into `src/`.
- For now `src/` matches `place/SpookyStealV3.2-Tutorial.rbxl` (the owner's House4 upload plus the tutorial), not the
  older `place/SpookyStealV3.2.rbxl`. Sync into that file (`python3 tools/sync_place.py place/SpookyStealV3.2-Tutorial.rbxl`)
  until the owner says to make it the main place file.
