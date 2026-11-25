# Year 2029

Original Roblox PvPvE game: a warehouse full of robots. Loot and build forts by day, survive the robots at night. Design and build steps live in PLAN.md. Research in RESEARCH.md.

## Status
- Plan and Blender asset library done. Roblox code lives in `src/`, built step by step from PLAN.md.
- Its own Roblox place, shares nothing with any other project. Publishing is Keani's job.

## Layout
- `art/` is the asset library: one folder per group (robots, haunt, critters, dog, story, gear, fun, food, furniture, lab), each model in its own folder with FBX, texture, preview and grey check. `art/gallery.html` shows them all, `art/animations.html` plays the animations.
- `art/_kit/` holds the build tools. `art/MOVES.md` says what every moving part does. `art/SOUNDS.md` and `art/sounds/` hold the sound pack.

## Code layout
- Rojo project (`default.project.json`), tools pinned in `rokit.toml`. `rojo serve` to sync into Studio; `./scripts/check.sh` runs StyLua, Selene, Lune tests and builds `build/Year2029.rbxl`.
- `src/server/Systems/*.luau` and `src/client/Controllers/*.luau` are picked up automatically by `Shared/Loader`: each returns a table with optional `Init()` (no yielding) and `Start()`.
- Tuning numbers: one file per system in `src/shared/Config/`, read as `Config.<File>.<Name>`.
- Remotes: `Shared/Net` (`Net.event("Name")`), created by name, no shared list.
- Pure logic (no Roblox services or Instances) goes in `src/shared/Logic/` with a Lune test in `tests/<Name>.spec.luau`. Roblox glue stays thin. A Logic module that needs a sibling uses `if script then require(script.Parent.X) else require("./X")` so it loads in both Roblox and Lune.
- Server decides loot, hits, money and cuffs. Clients only ask.

## Rules
- Blender only through `art/_kit/run.sh` (one Blender at a time, low priority, keeps the laptop cool). Run from `art/`.
- Grey check every new mesh part with `_kit/solo.py`. Roblox moderation judges each MeshPart alone in flat grey. No lone round-ended rods as their own part.
- Original only. Same genre as 3008 is fine; nothing from 3008, no real stores or brands.
- Keani's own recordings always win and are never replaced. Lines nobody recorded get AI/robot stand-in voices from `art/_kit/voice_lines.py` (Keani okayed this 2026-11-25); it never overwrites an existing clip.
- No blood. Dark but never kiddy. Survivor writing is red spray paint.
- No employer names, coworker names, or anyone's real names.
