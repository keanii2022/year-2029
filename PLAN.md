# Year 2029

Status: plan and asset library done. Roblox building not started.
Research: RESEARCH.md.

## The pitch

PvPvE survival. Up to 30 players drop into a humongous abandoned warehouse with a gun, and every one of them is a threat. Anyone can rob anyone, any time. The robots are the third side: they can't be shot, and they take whatever is left lying around.

The warehouse is from the world before AI and robots took over. It's full of the old world's stuff: furniture, toys, food, junk. Robots live here now, trying to understand human things. The place is so big it's scary.

- Lights on: robots sit in rooms scattered across the warehouse, going through people's old furniture and belongings, trying to figure out how to use them. Each room has some good stuff. Sneak in and grab it without the robot seeing you. Outside the rooms, loot the aisles, build a fort, gather food and ammo. Get lucky and find a dog or handcuffs.
- Siren: lights out in 60 seconds. Get home.
- Lights out: robots leave their rooms and sweep the aisles, gathering more stuff. Anything loose is theirs: loot piles, fort pieces, and you. Players fight too. Whoever goes down drops their stuff.
- Lights on again: robots are back in their rooms with new stuff they hauled in overnight. Loot, repair, rebuild. The day counter goes up.

Guns work all day, but only on players. Anyone can rob anyone, any time. Forts have no locks. Robots raid forts at night, and players raid them whenever. If you see someone dragging your wall away, you blast them.

Why it works: the old warehouse's power and music still run on their old schedule. Lights on is the robots' study shift. Lights out is their gathering shift. The music is an old store loop nobody ever turned off.

## What makes it fun

1. Other players are the real danger. Every stranger has a gun and wants your stuff.
2. Scary big. You feel tiny and lost.
3. Build anything. Every prop can be grabbed, carried and stacked.
4. Never safe. Forts can be raided day or night. Your defense is your eyes, your gun and your dog.
5. Trust is the game. Robots push strangers to team up. Loot tempts them to backstab.
6. Lose it all. Going down costs everything, so every fight matters. Get it back or get revenge.
7. Rare finds. A dog or a pair of handcuffs changes your whole day.
8. Feels real. Forced first person with head bob, sway, footsteps and momentum.
9. Creepily joyful elevator music by day, dead quiet at night.
10. Sneak in. Robot rooms hold the best stuff, and your gun is useless against robots.

## The day and night loop

| Phase | Length (start point) | What happens |
|---|---|---|
| Lights on | about 6 min | Robots stay in their rooms. Sneak, loot, build, rob, trade. Creepy happy music and old store announcements. |
| Siren | 60 sec | Alarm, flashing lights, voice countdown. |
| Lights out | about 4 min | Robots sweep the aisles, take anything loose, players included. Emergency lights and flashlights only. Hum and footsteps. |
| Morning | instant | Lights snap on. Day counter +1. Robots go back to their rooms with new stuff. |

All lengths live in config so playtests can change them.

## Systems

### Movement and camera
- Forced first person. Own hats and hair hidden.
- Head bob from real speed. Bigger when running. Sway into turns. Speed eases up and down.
- Footsteps synced to the bob, different per floor. Idle breathing.
- Run (Shift / L3), crouch (C / R3). Crouching is quieter.
- Psst (Q / Circle): a short quiet "psst" only players close by can hear. Get someone's attention, test if a fort is empty, or call your dog without giving yourself away. A robot hears it only if you're inside its room. Short cooldown so nobody spams it.

### The warehouse
- Mostly open floor: endless aisles of shelving, stacked junk and loose furniture, all from the old world. Dusty and faded.
- Robot rooms are placed randomly across the floor, not in rows. Each one is a little home a robot has set up from old furniture: walls, one or two doorways, a rug, a lamp.
- You can tell a robot is home from far away: a warm lamp glow, a hum, and things moving inside. The glow also shows the robot's view, which stays inside its room.
- Code builds the layout. No hand placing.
- Size target: about 8000 by 8000 studs. At normal walk speed that is about 8 minutes edge to edge, running about 5.
- 30 players in that space feels lonely on purpose. Loot hot spots pull people together.
- The roof is about 600 studs up and fades into haze, so it reads like an endless sky. Giant pillars vanish upward.
- The outer walls hide in fog. You never see an end until you touch it.
- Numbered aisle signs that don't really help.
- Players drop in at random spots spread far apart, so nobody starts next to anyone.
- Better loot deeper in, far from the entrance. The best loot sits inside robot rooms.
- Streaming on so the giant map stays fast.

### Grab and build
- Grab any prop, carry, drop, rotate, stack. Heavy props make you slower.
- Placing: while holding a prop, D-pad picks the rotate axis (left = turn, up = tip forward, right = roll, down = reset straight), R2 rotates it on that axis, L2 rotates back. A small arrow on the prop shows the current axis. A ghost outline shows where it lands. Keyboard: R rotates, T switches axis. Mouse wheel pushes it closer or farther.
- Props snap to 15 degree steps by default so walls line up. Hold L1 for free rotation.
- Anyone can move anything, including other people's forts.
- Props stay where they are dropped until the server resets.

### Objects come to life
Nothing is just a box. If a real one would do something, ours does too. Press E or Square on it.
- Open and close: fridge (light inside turns on), pantry, wardrobe, sink doors, microwave, toy chest, toilet lid, loot crate, supply locker. Drawers slide out on dressers, nightstands, filing cabinets and desks. Small loot can hide inside.
- Hide inside: wardrobe, toy chest, bathtub, under beds. A robot or player has to open it to find you.
- Switch on and off: floor lamp, desk lamp, lava lamp (blobs drift up when it's on), ceiling lights, neon OPEN sign, boombox, disco ball, table fan. Lights matter at night: a lit lamp shows where your fort is.
- Screens: the old TV flips through channels of funny pre-AI ads, a weather report and static. Arcade cabinet screen. Posters can be swapped.
- Press it: the big PRESS ME button says something cheerful and useless. Toaster pops toast. Microwave hums and dings. Vending machine drops a random snack (a real food source). Jack-in-the-box cranks then pops.
- Sit: couches, chairs, beds. Office chair spins. Search couch cushions for loose ammo.
- Spin and tick: wall clock hands count down to lights out. Fan blades, record player, music box dancer.
- Taps: sink and bathtub run water. Refill a water bottle at a sink.
- Rings on its own: an old phone rings now and then. Pick up and hear a creepy cheerful message.
- Noise is a choice. Most of these make sound, and sound pulls robots and players. A boombox at your fort is a party and a dinner bell.
- Life size gear you hold and turn: spray paint can (write your own red warnings on walls), walkie-talkie pair (talk to whoever has the other one), baby monitor (camera plus night vision screen), hand-crank radio (old broadcasts and supply drop hints).
- Every object has a sound and a loudness (quiet, normal, loud). Loudness decides who hears it, players and robots. Full list in `art/SOUNDS.md`. What every moving part does: `art/MOVES.md`.
- Gear: guns have a mag that drops on reload, flashlight and hard hat lamp switch on, handcuffs open and snap shut, helmets with a visor flip it up and down.

### Players vs players
This is the core of the game. The robots set the clock, but most fights are player against player.
- Day: rob people in the aisles, raid forts while the owners are out looting, ambush people coming out of robot rooms with the good stuff.
- Night: the purge. Everyone is stuck near home in the dark, robots are sweeping, and raiders use the chaos to hit forts.
- Use robots as a weapon: lure a chasing robot into another player, or fire near someone's hideout so the noise pulls robots onto them.
- Pure free-for-all. No parties, no teams, no friendly markers. Any truce is just two people deciding not to shoot yet.
- You never know if you're alone. No player list, no kill feed, no map dots. You find out other players exist by hearing footsteps, gunshots or a fort that wasn't there yesterday.

### Guns and fighting
- Guns only hurt players. Against robots they do nothing except make noise, and gunfire pulls robots from nearby rooms.
- Basic guns are common. Better guns are rare loot, deeper in the warehouse.
- The guns: starter pistol, revolver, SMG, shotgun, rifle, marksman rifle (long range, the warehouse is huge), nail gun (built from junk), dart blaster (quiet), flare gun (lights up an area and pulls robots to it), one rare heavy gun.
- Helmets block some damage: bike helmet, hard hat with a lamp, riot helmet with a flip visor.
- Backpacks: school backpack, hiking pack, big duffel. Bigger bag, more slots, slower you.
- Throwables: noise maker (a decoy alarm clock that pulls robots away), smoke can.
- Ammo is limited. Ammo boxes are loot, with more of them deeper in.
- The server checks every shot. The client only says "I fired here".
- Going down drops everything as a loot pile where you fell. You respawn at a random drop spot far from other players, with nothing.
- You see a faint marker on your loot pile, so you can run back for it. The pile stays until someone takes it or the next lights out ends.
- Whoever picks up your stuff gets a red tag only you can see, for a few minutes. Payback is a real option.
- Spawn kit: a starter pistol with a few bullets and a flashlight. Everything else has to be found again.
- Aim assist on controller.

### Handcuffs (super rare)
- Cuff someone from behind, or when they're low on health.
- While cuffed they can't move or shoot, and you can take anything from their bag.
- Cuffs last about 20 seconds. Mash a button to break free faster. Friends can uncuff you.
- Cuffs break after one use. You can't cuff the same person again for a few minutes.

### Robots
- Day: each robot stays in its room, poking at old human stuff and trying to use it (a robot trying to cook with a lamp, reading a book upside down). Its sight stays inside its room.
- Sneaking: crouching is quiet, running is loud. Grab the good stuff while its back is turned.
- Spotted by day: it leaves its room and chases you until it loses you for a few seconds, then walks back. You can lure one into another player.
- Caught by day: it takes your best item and puts it on a shelf in its room. Sneak back in to steal it back.
- Night: robots leave their rooms and sweep the aisles with scanner lights, gathering anything loose: loot piles, fort pieces, players. Caught at night counts as going down.
- Morning: they're back in their rooms, and what they hauled in is the new loot.
- Normal guns can't hurt robots. Only rare robot-killer gear works: an EMP charge (throw it, robots nearby shut down for a while) and the disruptor (a rare robot-only weapon that can destroy one).
- Destroying a robot drops its whole room's loot and gives rewards you can't get from players, so teaming up is worth it.
- Only rooms near players get a live robot. The rest sleep, so a giant map stays fast.
- Day robots are chore bots: cleaner, carrier, cook. Night hunters: scout (scanner eye), brute (pulls forts apart), crawler (fits under things).
- Lights on: the hunters stall right where they were standing when the lights came on. They freeze mid step in the aisles, their red eyes dim and flicker, they twitch now and then, and they say "ERROR. NEEDS MORE TRAINING." Frozen hunters are harmless by day but you walk past them all day long, and at the siren they jerk back to life.
- At lights out every robot swaps to its night model where it stands: dark rusty shell, black oil, red glowing cracks and eyes. The friendly chore bots' faces go wrong, so the room you thought was safe isn't.

### The dog (rare)
- One spawns somewhere each day. It's wary, not yours. It has to learn to trust you.
- Trust takes food over a few visits, across a day or two. Each visit it gets closer: first it backs off growling, then it eats while you watch, then its tail wags, then it follows. A small trust bar or hearts over its head make it obvious you're building something.
- Once it trusts you: "follow me" keeps it by your side, "guard here" leaves it protecting a spot, like your fort and stash, or a pile of valuables while you go empty your bag.
- Barks when someone touches what it guards. Bites robots and raiders.

### Haunts and life
The warehouse should feel alive and wrong. Small things react to you.
- **The lost kid.** A small ghost in a faded yellow raincoat, hood up, sleeves too long, bare grey feet. A paper bag mask with a crayon smile and two black holes for eyes. The announcer glitches into "will the parents of... please come to the front desk," then it stands at the end of an aisle. It never hurts you. It giggles, tilts its head too far, rolls a ball to you, pushes a cart by itself, writes "found you" on a fogged freezer door, peeks around shelves. Sometimes it leads you to loot, sometimes straight to a hunter. Get close and it's gone, leaving its stuffed robot on the floor. Rare, maybe once a night per server, so it stays scary.
- **Pigeons** in the rafters peck at dropped food. Sprint near them and the flock bursts into flight, which tells nearby robots where you are.
- **Rats** scatter from food aisles when a flashlight hits them. **Moths** circle the lights that still work.
- **Mannequins** in the showroom change pose whenever nobody is looking at them.
- **The greeter** at the entrance still waves and says welcome on a loop, voice getting worse every night.
- **Robot pile:** a heap of shut down robots. One of them twitches.
- **The shirt folder:** a robot folding the same shirt forever.
- **Security cameras** slowly turn to follow you.
- **Story spots:** a survivor camp (sheet tents, sleeping bags, candles, a dead radio, a notes wall), a kids' drawing wall that gets darker toward the end, roof leaks with buckets and puddles, moonlight through broken skylights, weeds pushing up through cracked concrete.

### Night: things to do while scared
- **The store rearranges itself.** While you hide, robots restock and drag shelves around. You hear it far off. In the morning the aisles are in a new layout, so your path home isn't where you left it. Forts and lockers stay put.
- **Hide inside furniture.** Get into wardrobes, fridges, under beds. The view turns into peeking through the slats or gap. Hold your breath when a robot stops right outside: it drains fast, and letting go makes a gasp robots can hear.
- **Sound that fits the room.** Big echo in the giant aisles, tight in a bedroom set, muffled while hiding. Heavy breathing after a sprint. Footsteps louder on metal than carpet. (Roblox reverb zones and audio effects, no extra files.)
- **Rain and lightning.** Rain on the roof all night. Lightning flashes through the skylights and lights the floor for a split second. Sometimes a robot is standing at the end of the aisle in one flash and gone in the next.
- **The announcer knows you're there.** At night the PA chimes and says things like "Shopper in aisle 32, please remain still." Rare, and sometimes it's right.
- **Phones ring far away.** Find the ringing phone and pick it up: breathing and a giggle, or the store jingle slowed down.
- **Flashlight battery.** It drains, flickers when low, and robots notice the beam. Batteries are loot.
- **Generators.** Fix and start one to light a section, which makes it safer. It runs on fuel and sputters when low, then dies and needs refueling and a new pull start. The hum pulls robots in, so a lit area is safe from the dark, not from them.
- **Lore you find.** Old helper robot ads on the TVs, cassette tapes for the walkie, survivor journals. Together they tell what happened in 2029.
- **Body feel.** Your hands are visible holding what you carry, breath fogs in the freezer aisle, dust floats in your flashlight beam.

### Supplies
- Food fills hunger. Energy drinks fill energy for running.
- Food with a twist: pizza box (one slice at a time), chips (loud to eat), ration pack (best refill, rare), popcorn (pop it in the microwave, loud), watermelon (heavy, split it to share), lunchbox (holds a few small foods), noodle cup (better with hot water from the stove). Full list in the asset gallery.
- Ammo, bandages, flashlight batteries.
- Super rare: EMP charges and the disruptor, the only things that work on robots.
- Empty hunger slowly hurts. Empty energy means no running.

### Saves and scores
- Your locker saves. Anything you put in it comes with you to every server. Anything outside it (your bag, your fort) is at risk and stays behind.
- Unlocks and the dog's trust save too.
- Blueprints: find paper and a pen, then turn your fort into a blueprint. It saves the layout, not the furniture. On another day, in any server, lay it out somewhere clear and it shows a ghost outline that the pieces snap into, but you still need the real pieces from your locker or from scavenging.
- You can lay out a blueprint once per day, during the day only. So a raid still costs you: the pieces that got wrecked are gone (or dropped as loot for the raider), and the blueprint only saves rebuild time.
- Saves: days survived, kills, robot kills, cosmetics.
- Leaderboards: most days survived, most player kills, most robot kills.

## Keani's calls

- Name: Year 2029.
- Players per server: 30.
- Pure free-for-all: no parties. You drop in alone and have no idea who else is here. The Roblox player list is hidden.
- Going down: you lose everything. Your stuff drops where you fell. Go back and find it, or hunt down whoever took it.
- Scale: huge. Walking from one end to the other takes real minutes. The roof is so high it disappears into haze, so the sky looks never ending.
- Audience: as big as possible. No blood anywhere, so it gets the lowest Roblox age rating. Creepy, not gory.
- Gun look: sci-fi blasters. Hits show sparks, no blood.
- Survivor writing is red spray paint: warnings like RUN, GO BACK, LIGHTS LIE, a ? after EXIT, sprayed-over posters. Anything printed is from before; anything sprayed came after.
- Dark, never kiddy: robots leak black oil, so the walls have oily handprints, drag marks and splats, plus claw gouges. A 12 year old should think it's a scary game, not a baby game. Scary without gore, so anyone can still play.
- World: an abandoned warehouse from before AI. Robots study human stuff in random rooms by day and gather in the aisles by night.
- Guns can't kill robots. Only rare robot-killer gear can.
- Music: Keani picks it. Elevator music that's creepily joyful, dreamcore and liminal.

## First playable (the test that matters)

One big room, props, a few players, guns. Move, grab, build, shoot. If dragging a couch into a wall and blasting a raider is fun on a PS controller, the game works. Everything else comes after.

## Build steps

Each step is one session. Code rules for every step: see "Code layout" in CLAUDE.md. Every step adds its own files (`src/server/Systems/<Name>.luau`, `src/client/Controllers/<Name>.luau`, `src/shared/Config/<Name>.luau`, pure logic in `src/shared/Logic/` with Lune tests in `tests/<Name>.spec.luau`), so steps never edit the same file. `./scripts/check.sh` must pass. Studio testing happens in the Year 2029 place only.

### 0. Rojo scaffold
- **Status:** done
- **Dependencies:** none
- **Scope:** `default.project.json`, `rokit.toml`, `wally.toml`, `selene.toml`, `stylua.toml`, `scripts/check.sh`, `tests/run.luau`, `tests/expect.luau`, `src/shared/Config/init.luau`, `src/shared/Net.luau`, `src/shared/Loader.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`
- Rojo project, loaders that start every system and controller, Config folder, Net remotes, Lune test runner.

### 1. First person feel
- **Status:** done
- **Dependencies:** 0
- **Scope:** `src/client/Controllers/Movement.luau`, `src/client/Controllers/Camera.luau`, `src/client/Controllers/Input.luau`, `src/server/Systems/TestRoom.luau`, `src/server/Systems/PlayerSetup.luau`, `src/shared/Config/Movement.luau`, `src/shared/Logic/Movement*.luau`, `tests/Movement*.spec.luau`
- **Out of scope:** grabbing, guns, the real warehouse.
- Movement and camera from Systems above (first person, sprint, crouch, jump, head bob, keyboard + PS controller). Hide the player list. Greybox test room built from code. Done when it feels good on keyboard and PS controller.

### 2. Bring in the models
- **Status:** done
- **Dependencies:** 0
- **Scope:** `tools/upload_assets.py`, `assets/manifest.json`, `src/shared/ModelLibrary.luau`, `src/shared/ModelRig.luau`, `src/server/Systems/Showroom.luau`, `src/shared/Config/Models.luau`, `src/shared/Logic/Manifest*.luau`, `tests/Manifest*.spec.luau`; read-only: `art/` (MOVES.md, each model's folder, `sounds/`)
- **Out of scope:** changing anything in `art/`, running Blender.
- An upload script (Open Cloud, key from an env var, never saved) that sends every FBX, texture and sound and writes asset ids into the manifest. ModelLibrary loads a model by name (greybox stand-in when not uploaded yet). ModelRig wires moving parts on their hinges, Glow parts to Neon, Screen parts to swappable images. A showroom places every model in rows. Done when every model sits in a test room, looks right, and its parts move.

### 3. Grab and build
- **Status:** done
- **Dependencies:** 0
- **Scope:** `src/server/Systems/Grab.luau`, `src/client/Controllers/Grab.luau`, `src/shared/Config/Grab.luau`, `src/shared/Logic/Grab*.luau`, `tests/Grab*.spec.luau`
- **Out of scope:** guns, using objects (step 7).
- Grab, carry, drop, rotate, stack, grid snap and freeze on drop, with the placing controls above. Server decides every move. Spawns a few greybox props for testing. Done when a kid builds a walled fort in a few minutes and a friend can tear it down.

### 4. Guns
- **Status:** done
- **Dependencies:** 1, 3
- **Scope:** `src/server/Systems/Combat.luau`, `src/server/Systems/Inventory.luau`, `src/client/Controllers/Gun.luau`, `src/client/Controllers/Hud.luau`, `src/shared/Config/Guns.luau`, `src/shared/Logic/Combat*.luau`, `src/shared/Logic/Inventory*.luau`, `tests/Combat*.spec.luau`, `tests/Inventory*.spec.luau`
- **Out of scope:** robots, handcuffs, supplies beyond ammo.
- Basic blaster (sparks, no blood), ammo, health, going down drops everything as a loot pile, respawn. Server-side hits. Done when a 1 v 1 over a fort is fair and fun. (First playable.)

### 5. The giant warehouse
- **Status:** done
- **Dependencies:** 1, 2
- **Scope:** `src/server/Systems/Warehouse.luau`, `src/shared/Config/Warehouse.luau`, `src/shared/Logic/WarehouseGen*.luau`, `tests/WarehouseGen*.spec.luau`
- **Out of scope:** lighting changes (step 6), robots.
- Code-built aisles, junk stacks and randomly placed robot rooms (seeded), tall ceiling lost in haze, streaming on. Spawns move into it; the test room stays reachable by a Config flag. Done when walking two minutes one way still feels endless.

### 6. Lights on, siren, lights out
- **Status:** done
- **Dependencies:** 1, 2
- **Scope:** `src/server/Systems/DayNight.luau`, `src/client/Controllers/Lighting.luau`, `src/client/Controllers/Flashlight.luau`, `src/client/Controllers/Music.luau`, `src/shared/Config/DayNight.luau`, `src/shared/Logic/Clock*.luau`, `tests/Clock*.spec.luau`
- **Out of scope:** robots, generators (step 12).
- Server clock, day and night phases, lighting flip, siren, music and voice line hooks (sound ids from the manifest), flashlights. Done when the mood flips hard.

### 7. Objects come to life and sound
- **Status:** done
- **Dependencies:** 2, 3
- **Scope:** `src/server/Systems/Interact.luau`, `src/server/Systems/Loudness.luau`, `src/client/Controllers/Interact.luau`, `src/shared/Config/Interact.luau`, `src/shared/Logic/Loudness*.luau`, `tests/Loudness*.spec.luau`
- **Out of scope:** robots reacting to sound (step 8 reads the loudness system).
- Press to use, hide inside, switch on and off, screens, the loudness system. Done when a boombox at your fort pulls in a stranger.

### 8. Robots
- **Status:** done
- **Dependencies:** 5, 6, 7
- **Scope:** `src/server/Systems/Robots.luau`, `src/server/Systems/RobotGear.luau`, `src/shared/Config/Robots.luau`, `src/shared/Logic/Robot*.luau`, `tests/Robot*.spec.luau`
- **Out of scope:** the dog, haunts.
- Day: chore bots study in rooms, room-only sight, chase, steal your best item. Night: swap to night models, sweep the aisles, take loose stuff and players, walk to loud sounds. EMP and disruptor. Done when sneaking into a room is tense and a night is scary with no other players around.

### 9. Supplies
- **Status:** done
- **Dependencies:** 4, 5, 7
- **Scope:** `src/server/Systems/Supplies.luau`, `src/client/Controllers/Needs.luau`, `src/shared/Config/Supplies.luau`, `src/shared/Logic/Needs*.luau`, `src/shared/Logic/Loot*.luau`, `tests/Needs*.spec.luau`, `tests/Loot*.spec.luau`
- **Out of scope:** saving (step 14).
- Hunger, energy, food, ammo boxes, bandages, loot by depth. Done when day has a clear shopping list.

### 10. Handcuffs
- **Status:** done
- **Dependencies:** 4
- **Scope:** `src/server/Systems/Cuffs.luau`, `src/client/Controllers/Cuffs.luau`, `src/shared/Config/Cuffs.luau`, `src/shared/Logic/Cuffs*.luau`, `tests/Cuffs*.spec.luau`
- Cuff, rob, break free, cooldown. Done when getting cuffed feels bad but not unfair.

### 11. The dog
- **Status:** current
- **Dependencies:** 4, 8, 9
- **Scope:** `src/server/Systems/Dog.luau`, `src/shared/Config/Dog.luau`, `src/shared/Logic/Dog*.luau`, `tests/Dog*.spec.luau`
- Spawn, trust over visits with food, follow, guard, bark, bite. Done when finding one feels like a big deal.

### 12. Night tricks
- **Status:** current
- **Dependencies:** 6, 7, 8
- **Scope:** `src/server/Systems/NightTricks.luau`, `src/client/Controllers/NightTricks.luau`, `src/shared/Config/NightTricks.luau`, `src/shared/Logic/NightTricks*.luau`, `tests/NightTricks*.spec.luau`
- Store rearranging, hiding inside furniture with breath holding, room sound, rain and lightning, PA lines, phones, flashlight battery, generators with fuel, lore. Done when a night alone has a plan, not just hiding.

### 13. Haunts and life
- **Status:** done
- **Dependencies:** 6, 7
- **Scope:** `src/server/Systems/Haunts.luau`, `src/client/Controllers/Haunts.luau`, `src/shared/Config/Haunts.luau`, `src/shared/Logic/Haunt*.luau`, `tests/Haunt*.spec.luau`
- The lost kid, pigeons, rats, moths, mannequins, greeter, cameras, story spots. Done when a player alone at night jumps at least once.

### 14. Saves and scores
- **Status:** current
- **Dependencies:** 3, 4, 9
- **Scope:** `src/server/Systems/Saves.luau`, `src/server/Systems/Scores.luau`, `src/client/Controllers/Locker.luau`, `src/shared/Config/Saves.luau`, `src/shared/Logic/Saves*.luau`, `tests/Saves*.spec.luau`
- Locker, blueprints (paper and pen, once per day), stats, leaderboards, cosmetics. Done when a full server plays a few nights with no breaks.

## Later ideas

- Hard night every 10th night. Foggy days where robots stay awake.
- Squads and shared forts.
- Proximity voice so you can talk (or lie) to strangers.

## What we need

- Art: built, see Asset library below.
- Sound: day music Keani picks (creepily joyful elevator music, dreamcore, liminal), old store announcements, night hum, siren, robot hums and beeps, footsteps per floor, gun sounds, dog bark, psst.
- All original. Nothing from 3008, Arc Raiders, any movie or any real store.

## Asset library (built)

The Blender run is done. Every model lives in `art/` with its FBX, texture, preview and grey check. Open `art/gallery.html` to see them all.

- What's there: furniture for every room, warehouse pieces, guns and gear, food, fun props, six robots with day and night looks, the dog, posters, TV channels, spray paint and oil marks.
- Haunts (`haunt/`): the lost kid, its stuffed robot and ball, mannequin, greeter, robot pile, shirt folder, security cam, kids' drawing wall. Critters (`critters/`): pigeon, rat, moth. Story spots (`story/`): survivor tent, sleeping bag, candles, notes wall, leak bucket, puddle, broken skylight, weeds, vines, locker, paper and pen, blueprint, dog bowl. Pictures for these come from `_kit/haunt_pics.py`.
- Moving parts are their own pieces with the hinge in the right spot. Glow parts light up. Screen parts take a swappable image.
- Every part passed the flat grey check Roblox moderation uses.
- Rebuild any model: `_kit/run.sh <folder>/build.py <name>` from `art` (one Blender at a time, keeps the laptop cool). Night robots: same with `NIGHT=1`.
- Furniture is faded with dust settled on top faces so the old store looks abandoned. Fun props stay bright.
- Animations: every robot, the dog, the lost kid, the mannequin and the critters have clips in `anim/` beside the FBX (robots: idle, walk, chase, grab, scan, plus study for chore bots and stall and wake for hunters; dog: idle, walk, run, sit, bark, bite). Each clip's bones are named after the model's parts, so Roblox's Animation Editor import maps them straight onto the Motor6D joints. `anim/anim.json` has the raw keys if we'd rather play them from code. `anim/preview.mp4` shows them all.
- Sounds: 160 original sounds in `art/sounds/`, open `sounds/index.html` to listen. Rebuild with `python3 art/_kit/sounds.py`. Voice lines for Keani to record are in `sounds/VOICE_LINES.md`, and `_kit/robotize.sh` turns a recording into a robot voice.
- Still to find or make: the day music (Keani picks). If a loop clicks in Roblox, switch it to OGG.

## Tech notes

- Rojo, Wally, StyLua, Selene.
- Server-authoritative: money, loot, hits and cuffs are decided on the server.
- All tuning numbers in one Config file.
- Its own repo. Shares no code, places or assets with any other project.
- Its own place in Studio.

## Risks

- Robbing can feel mean. Cuff and kill cooldowns, and robot-only rewards, keep it fun.
- Moving hundreds of physics props with many players can lag. Props snap to a grid and freeze when dropped.
- Giant maps can be slow on phones and consoles. Streaming and simple greybox art first.

## Calls to review

Best guesses made during the /parallel run. Change any of them in the step's Config file.

- Step 1: walk 14, sprint 22, crouch 7, jump height 5, view 72 widening to 80 on sprint. A middle ground that leaves room to outrun a robot.
- Step 1: Sprint = hold Shift / L3 toggle; Crouch = toggle C / R3; jumping or sprinting stands you up. Standard shooter habits.
- Step 1: Buttons: Use E/Square, Grab F/R1, Fire click/R2, Aim right-click/L2, Rotate R/Triangle, Psst Q/Circle, Jump Space/Cross. Common console layout, Grab on a bumper so you can grab and aim together.
- Step 1: Test room 160x160, grey walls 24 high, blue shelving rows, crates for jump tests, four corner spawns. Big enough for a 1v1 over a fort.
- Step 3: Grab/drop on F / R1, since E and Square stay free for using objects.
- Step 3: Free rotate is hold Left Alt + R on keyboard (the plan only gave L1 for the pad). Gamepad gets no closer/farther control because the plan only named the mouse wheel.
- Step 3: Ghost is soft green when the spot's OK and red when it's blocked; the rotate arrow is yellow for turn, light blue for tip, purple for roll. Readable in a dim room.
- Step 3: Limits: stack up to 12 studs above your feet, grab from 12, place up to 18, hold 4-12 out. Heavy props slow you down to 55% (a couch is about 72%). A fort's walls end up roughly double your height.
- Step 2: Showroom at (2000, 0, 0) on dark concrete, rows by group with uppercase labels and name tags within 60 studs. Kept far from the test room so they never overlap.
- Step 2: You spawn in the test room; set `Config.Models.ShowroomSpawnPlayers = true` to spawn in the showroom instead. Keeps step 1 testing clean.
- Step 2: Demo motion is on: every moving part opens and closes on a 4-second loop (doors 100°, slides 80%, levers 30°). Lets you check the hinges at a glance.
- Step 2: Stand-ins before upload are grey blocks, with Glow in warm orange and Screen near-black. You can still read what's what.
- Step 2: Images upload as Decals and sounds as Audio; the two sampler mp3s go in a "misc" group.
- Step 6: Cycle is Day 6 min, Siren 1 min, Night 4 min (`ShortCycle = true` for a 40/15/30s test loop). Long enough days to loot and build; nights short enough to stay scary.
- Step 6: Day is dim greenish fluorescent, the siren pulses red, lights out flickers to near-black cold blue, morning snaps back on. The hard flip the step asked for.
- Step 6: Flashlight is L / D-pad up. A free key that's easy to reach in the dark.
- Step 6: Announcer welcome lines play in the morning and as random daytime PA, countdown 11s before lights out, a lights-out line at lights out. Night PA lines left for step 12.
- Step 6: `DayMusicId` is empty for you to fill in with your pick.
- Step 4: "Starter Blaster" firing "Blaster Cells" straight from your bag (60 per stack, no magazines or reload). Simple first playable.
- Step 4: Spawn kit is 1 blaster + 36 cells. 100 health, 22 damage out to 40 studs dropping to 11 at 140, one shot per 0.22s: 5 hits to down someone up close. Leaves time to react and hide behind a fort.
- Step 4: No health regen (healing comes from supplies). Respawn after 6s. 10-slot bag.
- Step 4: Loot pile is a dark fabric bag with a "Take" prompt (hold 0.6s) listing what's inside.
- Step 4: Sparks are orange-white and the tracer is a thin red-orange line. Aim zooms to 72%.
- Step 4: HUD: off-white health bar bottom-left (red under 30%), ammo bottom-right ("EMPTY" in red marker), small crosshair, X hit marker that turns red when you down someone. Down screen: tilted red "YOU WENT DOWN", "Your stuff is where you fell.", "Back in N".
- Step 5: Warehouse is 8000x8000 studs (about 9.5 min wall to wall at walk speed), roof at 600 lost in haze, at (0,0,-6000). Players spawn there; set `Config.Warehouse.UseTestRoom = true` to spawn in the test room instead. "Huge" was your call.
- Step 5: Seed 0 = a new layout every server. Keeps it fresh every round.
- Step 5: Floor mix: 40% shelving blocks, 35% open junk and loose furniture, 25% nearly empty, giant pillars every 400 studs. 40 spawns at least 600 studs apart so you start alone.
- Step 5: 90 robot rooms (kitchen, living, bedroom, kids, office, bathroom, arcade, store), each with a rug, a lamp and 4-7 furniture pieces. "Store" rooms are the old store from before AI.
- Step 5: Aisle sign numbers are random 1-99 so they can't be used to navigate. Adds to the lost feeling.
- Step 5: About 1400 wall marks: spray 40% (RUN, HIDE, LIGHTS LIE, EXIT?, DON'T SLEEP, tallies, >>>), oil 35%, claws 10%, old posters 15%.
- Step 5: Haze is dusty grey-tan (density 0.42).
- Step 10: E / Square cuffs the player you're looking at ("[E] Cuff Name" hint). Having cuffs in your bag counts as holding them, since there's no item-select yet.
- Step 10: 3-minute cooldown after being cuffed, against everyone, not just the last cuffer. Stops a crowd chain-cuffing one person.
- Step 10: Cuffs last 20s, each mash takes 0.25s off, 5s minimum; mashing hard gets you out in about 7s. Low health = 35% or less, "behind" = roughly a 140° cone, 6-stud reach.
- Step 10: Anyone else can uncuff with a 2s hold. Robbing takes a whole stack per click. Handcuffs item value 30.
- Step 10: Copy: big red spray-paint "CUFFED" with a countdown, "Mash Space/Cross to break free", "Anyone else can uncuff you.", rob panel "Name's bag".
- Step 7: Use prompt is a dark rounded pill like "E  Open" / "Square  Hide", shown through walls. Verbs: Open/Close, Turn on/off, Hide, Get out, Change channel, Next picture, Start, Buy a snack, Sit, Sit and search, Answer, Dial, Press.
- Step 7: PRESS ME uses the lines from VOICE_LINES.md; the desk screen says "Are you still there?"; an empty vending machine says "SOLD OUT. Thank you for shopping!"
- Step 7: TV goes off, then 6 channels with static between, then off again; loud only while on. Posters cycle the 8 clean + 4 defaced ones.
- Step 7: Pressing a wardrobe, toy chest, bathtub or bed hides you right away, and you can't tell from outside whether it's taken. Keeps hide-and-seek tense.
- Step 7: Sitting on a couch searches the cushions: 35% chance of 2-6 Blaster Cells, then a 5-minute cooldown for that couch. Vending machines hold 3 snacks. The phone rings every 90-240s.
- Step 7: Lamps throw warm light (range 18), so a lit fort shows at night, like the plan says.
- Step 7: Hearing ranges: quiet 20 for players (robots only in the same room), normal 45 / 25, loud 120 / 80.
- Step 7: `Config.Interact.BoomboxMusicId` is empty: there's no boombox song in the pack yet, so it's your pick.
- Step 9: Foods are generic: Snack Bar, Chips, Apple, Sandwich, Juice Box, Pizza Box/Slice, Popcorn, Noodle Cup, Watermelon/Slice, Lunchbox, Ration Pack, Energy Drink, plus Bandage, Flashlight Battery, EMP Charge, Disruptor. No real brands.
- Step 9: Ammo boxes give 8-20 Blaster Cells on pickup instead of being their own item.
- Step 9: Pizza box, watermelon and lunchbox open into slices / a sandwich + apple + juice box. Chips are loud to eat.
- Step 9: A full belly lasts about a day and a night; sprinting empties energy in ~90s, and resting only refills energy to 35, so drinks matter. Starving does 0.5 damage a second.
- Step 9: Quick use is 1 Eat, 2 Drink, 3 Bandage (1-4s to use, not while cuffed). It picks the smallest item that covers what you're missing.
- Step 9: HUD: thin Hunger/Energy bars above health (red spray paint HUNGRY/STARVING, TIRED/EXHAUSTED when low) and a "SUPPLIES" list (Food 3, Drinks 2, Bandages 2, Cells 30, Batteries 1) where anything under target turns red. That's the day's shopping list.
- Step 9: Loot gets better with depth: ration packs past 40%, EMP past 75%, Disruptor past 85% of the way in. Restocks every morning.
- Step 13: Private scares (only you see them): the lost kid at the edge of your flashlight, a giggle behind you, a mannequin behind you with arms out that's gone when you look away, a ball rolling to your feet, a pigeon flock bursting up. The kid leaves its stuffed robot behind for 60s.
- Step 13: The lost kid shows at most once a night per server. If you're alone at night for 100s with no scare, you get one, so "jumps at least once" holds. Hidden players only get the giggle.
- Step 13: The greeter uses the announcer welcome line, slower and more distorted each night, and stands just inside the entrance.
- Step 13: Pigeons sit on the floor in open spots (the rafters are lost in haze); rats run along the aisles. Both scatter and come back when nobody's near.
- Step 13: Security cams on pillars 16 studs up with a red glow. Mannequin poses: stand, reach, point, crouch, look back, hug.
- Step 13: Counts: 12 camps, 10 drawing walls, 25 leaks, 15 skylights, 40 weed patches, 30 pigeon flocks, 30 rat nests, moths at 30 lamps, 40 cams.
- Step 13: Scare odds when alone at night are about 35% a minute (10% of that by day, 40% during the siren), with at least 75s between scares.
- Step 8: Room to bot: kitchen = cook; living/office/arcade/store = carrier; bedroom/kids/bathroom = cleaner.
- Step 8: Speeds: chore bots walk 8, chase 17-18; hunters 17-21 (crawler fastest). Sprinting at 22 outruns all of them, but not for long on an empty energy bar.
- Step 8: Sight: chore 34 studs, scout 70, brute 45, crawler 40, 110° cone. Crouch halves it, sprinting +20%, night +20%. Noticing you takes ~1.2s by day, ~0.35s at night.
- Step 8: Chases give up 4s after losing you; day chases stay within 120 studs of home.
- Step 8: Caught by day: your best item's whole stack goes into a dark metal crate on a shelf in that room ("Take" prompt, quiet sound), and the robot ignores you for 8s. Caught at night = going down.
- Step 8: Footsteps carry 12 studs walking, 30 sprinting, 0 crouched; gunshots are loud. A flashlight on a robot at night gives you away. A hunter at a sound has a 40% chance to open a hiding spot within 10 studs.
- Step 8: Rooms wake within 220 studs of a player; max 12 chore bots + 8 hunters live at once.
- Step 8: EMP: G, thrown 45 studs, 22-stud radius, robots off for 8s, loud pop. Disruptor: V, 60-stud range, 45s cooldown, destroys one robot.
- Step 8: A destroyed robot leaves a wreck, a black oil puddle and sparks; its room's loot spills out and the destroyer gets 2 EMP charges.
- Step 8: Eyes are pale cyan by day, dim flickering red when stalled, bright red at night with a red scanner light. "ERROR. NEEDS MORE TRAINING." is on-screen text until you record it.
- Gamepad map after merging: D-pad up flashlight, D-pad down EMP, D-pad right disruptor, D-pad left eat, L1 drink, touchpad bandage. Every button gets one job (Grab takes the D-pad and L1 only while carrying).
