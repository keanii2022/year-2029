# Research: the endless store survival genre

What we looked at: the Roblox game 3008 (based on the SCP-3008 "infinite store" story), plus games that share its loop. The goal is to learn why it works, then make our own game. We copy no names, characters, art, music, levels or look.

Note: most 3008 sources are fan guides. They disagree on exact numbers. Treat timings as rough.

## The day and night loop

- Day lasts about 6 to 8 minutes. Night lasts about 5 to 7 minutes. Some guides say a siren plays for about a minute before night. ([Deltias Gaming](https://deltiasgaming.com/?p=246316), [Playgama](https://playgama.com/blog/?p=5314))
- Day is safe. The store's monsters wander but don't hurt you. ([Droidgamers](https://www.droidgamers.com/guides/how-to-play-3008/))
- Night starts when the lights shut off. The monsters patrol and hunt. ([Droidgamers](https://www.droidgamers.com/guides/how-to-play-3008/))
- The day counter goes up forever. There is no last day. Survival is the score. ([Pro Game Guides](https://progameguides.com/roblox/roblox-3008-beginners-guide-3008-tips-and-tricks/))
- Special days break the routine. Every 10th night is a harder night: more monsters, faster, jump higher. Every 16th day is foggy: monsters can hurt you in daylight. ([Gurugamer](https://gurugamer.com/mobile-games/how-to-play-roblox-3008-18896))
- Takeaway: the loop is "prepare, then survive". Day has a clear job (get food, build). Night is the test. The siren gives a short panic window.

## Hunger and energy

- Three bars: health, hunger, energy. Hunger and energy drain over time. Monsters take health. ([Deltias Gaming](https://deltiasgaming.com/?p=246316))
- Food lies around the store. Different foods fill different bars. Some food respawns on set days. ([Pro Game Guides](https://progameguides.com/roblox/roblox-3008-beginners-guide-3008-tips-and-tricks/))
- Takeaway: food is the reason to explore in daylight. Two bars with different foods give small choices.
- Watch out: survival games often make hunger a chore. Keep drain slow and food easy to find early. ([PC Gamer](https://www.pcgamer.com/uk/how-survival-games-get-hunger-and-thirst-wrong-and-how-to-fix-it))

## Building

- Almost every big object can be picked up and moved. ([Deltias Gaming](https://deltiasgaming.com/?p=246316))
- Players build forts by stacking furniture to wall themselves in for the night. ([Deltias Gaming](https://deltiasgaming.com/?p=246316))
- Takeaway: building is just "carry and drop". No menus, no crafting tree. That makes it easy for kids and great with friends.

## Night threats

- The monsters are store staff who look normal by day and turn on you in the dark. Several types exist (regular, wide, and some named ones). ([Pocket Tactics](https://www.pockettactics.com/roblox/3008))
- Takeaway: the threat is scary because it was harmless a minute ago. Same thing, new rules. We need our own creature for this. It cannot look or act like their staff.

## Camera and movement feel

- We found no source that confirms 3008 locks first person, so this part comes from Keani's own play and from Roblox dev guides.
- Common recipe on the Roblox dev forum ([realistic camera guide](https://devforum.roblox.com/t/creating-a-simple-realistic-camera-with-view-bobbing-dynamic-blur-sprinting/646943), [configurable head bob](https://devforum.roblox.com/t/configurable-head-bobbing-script/1505850), [realistic first person like Doors](https://devforum.roblox.com/t/how-to-make-a-realistic-1st-person-walk-script-like-doors/2051857), [Immersive Player Framework](https://devforum.roblox.com/t/ipf-immersive-player-framework-v10/4616229)):
  - Head bob follows a sine wave. It grows with real speed, not with the key held.
  - Run bobs bigger and faster than walk. Field of view widens a little when running.
  - Sway: the camera leans a bit into turns and strafes, eased with a spring.
  - Footsteps play on the bob's low point, so sound and picture line up. Floor material changes the sound.
  - Momentum: speed eases up and down instead of snapping.
  - Small idle breathing when standing still.
- Known gotchas: hats and hair block the view in first person. Bob can break if the camera is welded to the head. The built-in first person lock feels stiff. ([same threads](https://devforum.roblox.com/t/how-to-make-a-realistic-first-person-system-in-a-horror-game/762698))
- Takeaway: build our own camera layer on top of Roblox's first person lock. Tune it with numbers in Config.

## Why the scale works

- The store feels endless because rooms repeat with small changes. Your brain can't map it, so you feel tiny and lost. ([Game Developer on the Backrooms and liminal spaces](https://www.gamedeveloper.com/design/backrooms-liminal-spaces-and-the-subliminal-menace-of-loneliness-in-indie-horror-games))
- Research on digital liminal spaces found that mood, theme and being alone shape the feeling most. Fog was one of the tools tested. ([Bray thesis, Leeds 2023](https://etheses.whiterose.ac.uk/id/eprint/34902/2/Bray_206039969_Thesis.pdf), [Herrera thesis, SMU](https://scholar.smu.edu/guildhall_leveldesign_etds/19))
- Ways to fake huge on Roblox:
  - Very tall ceilings and pillars that fade into haze.
  - Repeating tiles and rooms, built by code, so the map can be huge without hand work.
  - Fog or atmosphere so you never see the end.
  - Signs with numbers that don't help you navigate.
  - Stream in only the area near the player so a giant map stays fast.

## Music and mood

- 3008 has a bright, friendly look while being a horror game. ([Playgama](https://playgama.com/blog/game-faqs/what-is-the-roblox-game-3008-about/))
- Cheerful plus creepy is a known trick. Happy Game calls itself an "oddly cheerful world of nightmares". ([Game Developer](https://gamedeveloper.com/art/honing-creepiness-through-contrast-in-horror-puzzler-happy-game))
- Poppy Playtime uses a bright toy factory as the lure, then turns the cute mascots into the threat. ([EarlyGame](https://earlygame.com/guides/gaming/cute-video-games-that-are-actually-horror))
- On Roblox, Dandy's World plays cheerful cartoon music on safe floors, which makes the scary parts hit harder. ([RoWatcher](https://rowatcher.com/news/how-roblox-horror-games-keep-players-terrified))
- Takeaway: day should sound happy and a little too upbeat. Night drops the music and leaves hum, footsteps and distant noises.

## Similar games worth knowing

- SCP-3008: Infinite Store on Steam and Xbox, a paid take on the same idea. ([Steam](https://store.steampowered.com/app/4224460/SCP3008_Infinite_Store/))
- Monke08 on Roblox, inspired by 3008 with a different monster. Shows a reskin alone isn't enough to stand out. ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/SCP3008Roblox))
- Don't Starve: day is for planning, dusk for prep, night for survival. 8 minute days. ([Don't Starve wiki](https://dontstarve.wiki.gg/wiki/Day-Night_Cycle))
- Minecraft: gather, build shelter, survive the night. The classic version of this loop. ([Game Bootcamp](https://seanking11.github.io/gamebootcamp/modules/31-survival-crafting))
- Lethal Company: mixes comedy and horror, and lets monsters hear you. ([GamesRadar](https://www.gamesradar.com/games/horror/the-horror-is-almost-secondary-to-the-menial-task-from-crow-country-to-resident-evil-9-heres-how-horror-games-keep-us-scared))
- Arc Raiders: PvPvE shooter where deadly robots are the shared threat and players pick between teaming up and betraying. A backstab "stings precisely because the trust was real". Critics say betrayal often pays best, so the game nudges co-op with robot-only rewards. ([God is a Geek review](https://godisageek.com/reviews/arc-raiders-review/), [Epic Games Store](https://store.epicgames.com/news/how-arc-raiders-lets-you-thrive-in-a-post-apocalyptic-world-dominated-by-machines), [Destructoid](https://newsletter.destructoid.com/p/destructoid-checkpoint-the-slippery-slope-of-arc-raiders), [number13](https://en.number13.de/why-arc-raiders-needs-a-real-pve-mode-and-why-doing-friendly-is-currently-breaking-the-game/))
- Backrooms games: dread from empty, repeating space. ([Game Developer](https://www.gamedeveloper.com/design/backrooms-liminal-spaces-and-the-subliminal-menace-of-loneliness-in-indie-horror-games))

## What we take, in one list

1. A short day with a clear job, and a night that tests it.
2. A siren or warning before night.
3. Two slow bars (hunger, energy) and food lying around.
4. Carry and drop building. No menus.
5. A threat that is harmless by day and dangerous by night.
6. Forced first person with real feeling movement.
7. Huge, repeating, hazy space.
8. Happy music by day, near silence by night.
9. Special nights and days that break the routine.
