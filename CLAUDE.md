# Year 2029

Original Roblox PvPvE game: a warehouse full of robots. Loot and build forts by day, survive the robots at night. Design and build steps live in PLAN.md. Research in RESEARCH.md.

## Status
- Plan and Blender asset library done. Roblox building hasn't started.
- Its own Roblox place, shares nothing with any other project. Publishing is Keani's job.

## Layout
- `art/` is the asset library: one folder per group (robots, haunt, critters, dog, story, gear, fun, food, furniture, lab), each model in its own folder with FBX, texture, preview and grey check. `art/gallery.html` shows them all, `art/animations.html` plays the animations.
- `art/_kit/` holds the build tools. `art/MOVES.md` says what every moving part does. `art/SOUNDS.md` and `art/sounds/` hold the sound pack.

## Rules
- Blender only through `art/_kit/run.sh` (one Blender at a time, low priority, keeps the laptop cool). Run from `art/`.
- Grey check every new mesh part with `_kit/solo.py`. Roblox moderation judges each MeshPart alone in flat grey. No lone round-ended rods as their own part.
- Original only. Same genre as 3008 is fine; nothing from 3008, no real stores or brands.
- No Mac `say` or other TTS voices. Human voice lines go in `art/sounds/VOICE_LINES.md` for Keani to record.
- No blood. Dark but never kiddy. Survivor writing is red spray paint.
- No employer names, coworker names, or anyone's real names.
