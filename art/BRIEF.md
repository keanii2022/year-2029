# Year 2029 art brief

Year 2029 is a first person survival shooter on Roblox. A giant robot training lab that never ends: rows of fake homes (kitchens, bedrooms, offices) built for robots to practice chores in. 30 players loot, build forts out of the furniture, and fight. At lights out the lab robots hunt. Full plan: `PLAN.md` at the repo root (read only "The pitch" if you need context).

These models get made now so Roblox building can start later. Original designs only. Nothing from the game 3008, Arc Raiders, any movie, any real brand, store or product. No logos, no real words except short made-up labels (under 6 letters).

## Look

- Bright, friendly showroom by day. The furniture looks like a cheerful catalog: pale wood, cream, mint, coral, butter yellow, sky blue, soft grey. A little worn: scuffs, a stain, tape, a sticky price tag (made-up number).
- Lab gear and guns are made from lab parts: white and grey plastic shells, dark rubber grips, orange and teal accents, hazard stripes, exposed screws, cable ties, tape. Chunky and readable from far away, like good toys that could hurt. Sci-fi blasters, not real guns. No blood anywhere.
- Robots are sleek company robots: clean white shells with soft panel lines, a small screen or lens face. Friendly by day. At night the same robot is scary: tall, too thin or too wide, scanner eye. Creepy, not gory. A 9 year old should get chills, not nightmares.
- Low poly with soft bevels. Shapes first, small details second. Must read at 40 studs away.

## Scale (1 stud is about 0.3 m, a player is about 5 studs tall)

| Thing | Size in studs |
|---|---|
| Door frame | 3.5 wide, 7 tall |
| Kitchen counter | 3 tall, 2 deep |
| Table | 2.5 tall |
| Chair seat | 1.5 high |
| Bed | 4.5 wide, 7 long, 2 high |
| Couch | 7 wide, 3 deep, 2.8 tall |
| Fridge | 2.5 wide, 2.5 deep, 6 tall |
| Pistol | about 1.2 long |
| Rifle | about 3 long |
| Food can | about 0.4 tall |
| Day robot | 5 to 6 tall |
| Night robot | 6.5 to 9 tall |
| Dog | about 2.2 tall at the head, 3 long |

## Roblox moderation (important)

Roblox reviews every mesh part on its own, in flat grey, with no texture. A robot arm mesh got removed once because the upper arm alone (a rod with a band and a ball on the end) looked rude. So:

- Join everything into as few parts as possible. Props are one part unless something has to move.
- Never a lone rod with a rounded end, and never a rod with a ring band on it, as its own part. Gun barrels are boxy shrouds, hex prisms (`cyl(..., seg=6)`) or end in a flat muzzle block.
- After each final build, run the solo check and look at `solo.png`. Every part alone in grey must look like what it is.

## Moving parts (objects come to life)

If a real one would move, light up or show something, ours has that piece split out. Part names tell Roblox what to do:

- `Body`: the still part. Everything else is welded or hinged to it.
- `Door`, `DoorL`, `DoorR`, `Lid`, `Flap`, `Visor`: hinged. Put the hinge in `pivots` so the origin sits on it.
- `Drawer1`, `Drawer2`...: slides straight out along -y. Origin anywhere.
- `Button`, `Knob`, `Lever`, `Handset`, `Crank`, `Trigger`, `Arm`, `Toast`, `Jack`: small movers, pivot where they turn or press.
- `Spin`, `Spin2`: turns around its own up axis (fan blades, disco ball, clock hands, record). Pivot on the axle.
- `Mag`: gun magazine that drops out on reload.
- `Glow`: lights up. Plain one-color pieces. Roblox switches them between Neon and dull.
- `Screen`, `Screen2`: flat, faces -y, gets its own image with 0 to 1 UVs (TV channels, posters, arcade). Drop a `screen.png` in the item folder to set the default picture, else the kit's test pattern is used.
- Wearables: helmets have their origin at the bottom center of the head (Roblox HatAttachment). Backpacks have it at the middle of the back (BodyBackAttachment).

Moving parts still pass the solo check: a lone drawer or button alone in grey must look like a drawer or button.

## Kit

- `_kit/kit.py` is the creepy robot kit (prims, materials, `Robot`). `Robot(name, folder="robots", max_h=9)` for humanoids, with arm and leg parts and joints (Head, Torso, UpperArm, Forearm, Hand, Thigh, Shin and Left versions). Use `Extra` for a part the game recolors at night (scanner eye, glow strip).
- `_kit/ykit.py` adds `Prop` and `@item(name, folder, size, pivots)` for everything else. Read its docstring. Parts with pivots get their origin at the hinge.
- Materials: `paint`, `metal`, `wood`, `cardboard`, `cloth`, `plain`, `flat`, `glow`, `fade`. Use `plain` for plastic, `cloth` for fabric, `wood` for wood.

## Run

- Props: `_kit/run.sh <build file> [quick] name name ...` from `art`. Robots: a robot's `build.py` is a normal Blender script, run it with `_kit/run.sh robots/<name>/build.py [quick]`.
- Only use run.sh to run Blender. It waits for the laptop to cool and for any other Blender to finish. One Blender at a time across all sessions. Foreground, timeout 600000 ms.
- Solo check: `nice -n 15 /opt/homebrew/bin/blender -b -t 2 --factory-startup -P _kit/solo.py -- <fbx>` (quick, but still one Blender at a time: check `pgrep -f "blender -b"` first).
- Sheet: `nice -n 15 /opt/homebrew/bin/blender -b -t 2 --factory-startup -P _kit/sheet.py -- <folder> [cols]`.
- Read `preview.png` after each run. Fix floating bits, wrong scale, muddy shapes. 2 to 3 runs per item is plenty for props.

## Budgets

- Small props (food, ammo, gear): under 1500 triangles, 512 texture.
- Guns: under 3000 triangles, 512 texture.
- Furniture: under 3000 triangles (big pieces up to 5000), 512 or 1024 texture.
- Robots: under 10000 triangles, 1024 texture. Dog: under 6000, 1024.

## Folders

- `gear/` guns, ammo, handcuffs, flashlight, battery, bandage, medkit, crate, locker. Build file `gear/build.py`.
- `food/` consumables. Build file `food/build.py`.
- `furniture/` fort pieces by room. Build files `furniture/<room>.py`.
- `lab/` pillars, signs, lights, speaker, siren, gate, dock, bench. Build file `lab/build.py`.
- `robots/<name>/build.py` one per robot. `dog/build.py` for the dog.
- Write only in your own folders. No git, no Studio, no downloads, no `src`.
