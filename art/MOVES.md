# What every moving part does

For the Roblox build. Part names follow BRIEF.md "Moving parts". Press = E or Square. Sound pulls robots and players unless it says quiet.

## Kitchen
| Item | Part | Does |
|---|---|---|
| counter | Door1 to Door3 | Swing open on a side hinge. Small loot inside. |
| fridge | Door, Door2 | Fridge and freezer doors swing open. Food loot inside. |
| fridge | Glow | Inside light turns on while a door is open. |
| stove | Glow | Burners glow orange when switched on. Warm: standing close slowly refills energy. |
| stove | Flap | Oven door drops open. Loot or a hiding spot for small stuff. |
| pantry | Door | Swings open. Cans on the shelves are food loot. |

## Living room and bedroom
| Item | Part | Does |
|---|---|---|
| tv_stand | Screen | Shows a channel. Press to change it (see Channels). |
| tv_stand | DoorL, DoorR | Cabinet doors swing open. |
| floor_lamp | Button, Glow | Pull the chain: light on or off. A lit lamp is seen from far away at night. |
| couch, armchair | (seat) | Sit. Search the cushions for loose ammo now and then. |
| wardrobe | DoorL, DoorR | Swing open. Hide inside with the doors shut. |
| dresser | Drawer1 to Drawer3 | Slide out. Small loot. |
| nightstand | Drawer1 | Slides out. |
| nightstand | Glow | Alarm clock face. Rings at lights out (loud). |
| bed, bunk_bed, kid_bed | (under) | Hide under. Sleep to refill energy by day. |

## Office, bathroom, kids room, walls
| Item | Part | Does |
|---|---|---|
| desk | Drawer1 to Drawer3 | Slide out. |
| desk | Screen | Old computer screen. Press: a pop up asks "Are you still there?" |
| office_chair | Spin | Sit and spin. |
| filing_cabinet | Drawer1 to Drawer3 | Slide out. Papers inside, sometimes a key card or ammo. |
| whiteboard | Screen | Shows scribbles. Later: pick a message to write on it. |
| sink_cabinet | DoorL, DoorR | Swing open. |
| sink_cabinet, bathtub | Tap | Turn on: water runs (particles from the spout). Refill a water bottle at the sink. |
| bathtub | (inside) | Lie down to hide. |
| shower_door | Slide | Glass slides sideways along x. |
| toy_chest | Lid | Opens up. Plays a little tune (quiet). Hide inside. |
| wall_panel | Screen | Picture in the frame. Swappable. |
| door_frame | Glow | EXIT? sign flickers. |

## Warehouse pieces
| Item | Part | Does |
|---|---|---|
| ceiling_light | Glow | On by day, off at lights out. |
| emergency_light | Glow | Off by day, red at night. |
| siren_light | Glow, Spin | Glows and the mirror spins during the lights out siren. |
| entrance_gate | Glow, Slide | Lamps blink, the grate slides up at round start. |
| charging_dock | Glow | Pulses while a robot is docked. |
| arm_bench | Arm | Robot arm sways back and forth, picking up nothing. |
| speaker_horn | (whole) | Plays store announcements and the day music. |

## Fun props
| Item | Part | Does |
|---|---|---|
| lava_lamp | Glow, Blob | Switch on: glass glows (see-through Neon), blobs drift slowly up and down. |
| crt_tv | Screen, Knob | Turn the knob: next channel, with a burst of static. |
| press_button | Button | Press: it says something cheerful and useless ("Good job!", "Task complete!", "You did it!"). |
| boombox | Button, Flap, Glow | Play or stop music (loud). Tape door opens. Lights bounce to the beat. |
| arcade_cabinet | Screen, Lever, Button, Glow | Title screen, joystick wiggles. Later: a tiny game. |
| microwave | Door, Spin, Glow, Button | Door opens, plate spins, light on, ding at the end (loud). Heat up food for a bigger refill. |
| toaster | Lever, Toast | Push the lever, wait, toast pops up. Toast is food. |
| desk_lamp | Arm, Glow | Light on or off. The arm can be aimed. |
| table_fan | Spin | Blades spin when on. |
| wall_clock | Screen, Spin, Spin2 | Hands count down to lights out. A survivor sprayed the danger zone on the face. |
| rotary_phone | Handset, Spin | Rings now and then (loud). Pick up: a creepy cheerful message. Dial spins. |
| disco_ball | Spin | Spins and throws light spots. |
| vending_machine | Button, Flap, Glow | Press a button: a random snack drops into the flap. A few per round. |
| toilet | Lid, Lever | Lid flips up. Flush (loud). |
| jack_in_the_box | Crank, Lid, Jack | Crank plays a tune, then the lid pops and Jack springs out (loud). |
| rubber_duck | (whole) | Squeaks when pressed or stepped on. A quiet tripwire for your fort. |
| neon_open_sign | Glow | On or off. Flickers. |
| record_player | Lid, Spin, Arm | Lid opens, record spins, arm swings over. Plays a record. |
| music_box | Lid, Spin | Open: the little robot dancer spins and a tune plays (quiet). |
| poster_frame | Screen | Shows any poster. |
| spray_can | Button | Hold to spray. Pick a warning from a short list (RUN, HIDE, NOT SAFE, arrow, tally...) and it lands on the wall as a red decal. You become the survivor who wrote it. Limited paint per can. |
| walkie_talkie | Button, Knob, Glow | Spawns in pairs across the map. Hold the side button to talk to whoever has the other one. Knob picks the channel. Light blinks when someone talks. You never know who's on the other end. |
| baby_monitor_cam | Spin, Glow | Set it down anywhere. Head slowly pans. Red light means it's live. Other players can find it and smash it. |
| baby_monitor_screen | Screen, Glow, Button | Shows the cam's view in night vision. Sound bars light up when robots or players make noise near the cam. |
| crank_radio | Crank, Knob, Glow | Crank to charge it (makes a little noise). Turn the knob to tune: old broadcasts, a hint where a supply drop lands, bits of the story. Dial glows while it has charge. |

## Food
| Item | Part | Does |
|---|---|---|
| pizza_box | Lid | Flips open. Take one slice at a time, the box empties as players eat. |
| cereal_box | Flap | Top flap opens. Rattles when shaken. |
| noodle_cup | Lid | Peels back. Better refill with hot water from the stove. |
| peanut_butter | Lid | Twists off. |
| egg_carton | Lid | Opens. Eggs break if you drop the carton. |
| lunchbox | Lid | Opens. Holds a few small foods, like a mini backpack. |
| popcorn_bag | (whole) | Put it in the microwave: it puffs up and pops (loud). |
| watermelon | (whole) | Heavy, two hands. Hit it to split it into watermelon slices. |

## Channels and posters
- Pictures live in `posters/` (posters, 1000 x 1500) and `posters/screens/` (TV and screens, 800 x 600).
- TV channels in order: helpbot_ad, blob_lamp_ad, weather, cooking_with_toast, right_back, test_pattern, with static between each.
- Posters: helper_of_the_month, smile_on_camera, hug_your_toaster, think_less, dont_panic, lost_dog, mega_sale, sleep_2.
- Defaced posters (`*_defaced`): survivors sprayed on them in red paint. Mix them in with the clean ones.
- Spray paint scrawls for walls: `posters/scrawls/`, see-through PNGs to use as Decals anywhere (run, hide, dont_sleep, they_hear_you, not_safe, stay_quiet, no_way_out, lights_lie, arrow, tally, question_mark), plus dark marks with no blood: oil_handprint, oil_handprints_sliding, oil_drag_mark, oil_splat (robots leak black oil), claw_marks (robot claws gouged the wall)..
- Rule: printed means it was made before. Spray paint means a survivor wrote it after.
- Redraw them all with `python3 _kit/posters.py` (uses headless Chrome, not Blender).

## Gear
Guns are one `Handle` part plus `Mag` and `Glow`. They point along -y.

| Item | Part | Does |
|---|---|---|
| every gun | Mag | Drops out on reload, a fresh one slides in. |
| every gun | Glow | Lights up while loaded, dims when empty. |
| revolver | Mag | The hex drum. Turns one sixth each shot, swings out to reload. |
| revolver | Hammer | Cocks back before each shot (pivot at its base), snaps forward on fire. |
| shotgun | Pump | Racks back toward the grip and forward after each shot. |
| disruptor | Mag, Glow | Battery pack swaps out. The zigzag arc between the prongs flashes on fire. Stuns robots. |
| flare_gun | Mag | The flare round. A fired flare lights an area for a while and pulls robots to it. |
| marksman_rifle | Glow | Scope lens glints. Players far away can spot it. |
| handcuffs | Arm, Glow | Cuff swings shut. Red lights blink while locked on a robot. |
| flashlight | Glow | On or off. Seen from far away at night. |
| hard_hat | Glow | Headlamp on or off, hands free. |
| riot_helmet | Visor | Flips down for more protection, up to see better. |
| school_backpack, hiking_pack, big_duffel | Flap | Opens when you look in your bag. Bigger bag, more slots. |
| noise_maker | Spin | Wind the key, it ticks, then rings (loud). Throw it to pull robots or players away. The key turns around y, not z. |
| smoke_can | (whole) | Throw it: a smoke cloud blocks sight for a while. |
| emp_charge | (whole) | Pull the tab, throw it: robots nearby freeze for a few seconds. |
| loot_crate | Lid | Flips open. Loot inside. |
| supply_locker | Door | Swings open. Better loot, locked by day. |

## Haunts and life
Rigged ones (lost_kid, mannequin, pigeon, rat, moth) have clips in `anim/` beside the model, same as the robots.
| Item | Part | Does |
|---|---|---|
| lost_kid | clips | idle, tilt, giggle, walk, run, peek, point, wave. Rare, once a night at most. Never touches you. Fade it out when you get close and leave stuffed_robot where it stood. |
| lost_kid | (decal) | `posters/scrawls/fog_found_you.png` goes on a freezer door after it was there. |
| kid_ball | Body | Rolls slowly toward you out of the dark. Quiet. |
| mannequin | clips | stand, reach, turn, crouch, face. Snap to a new pose only while no player's camera can see it. |
| greeter | Arm | Waves on a loop. Head and Screen tilt together. Plays the welcome line, worse each night. |
| robot_pile | Twitch | The arm jerks now and then. Glow eyes flicker. |
| shirt_folder | Arm, Shirt | Arm swings down, Shirt flips its half over, back to start. Forever. Quiet whir. |
| security_cam | Cam, Glow | Cam turns slowly to face the nearest player in range. Glow red light on. |
| drawing_wall | Screen | Kids' drawings, happy at the start, darker by the end. |
| pigeon | clips | idle, peck, walk, fly, takeoff. Sprint near a flock and they all take off at once: loud, pulls robots. Peck at dropped food. |
| rat | clips | idle, scurry, rear. Scurry away when a flashlight hits them. Rear up to sniff a still player. |
| moth | clips | flutter, rest. Circle working lights. |

## Story spots
| Item | Part | Does |
|---|---|---|
| candles | Glow | Flames flicker. Light seen from far at night. Press to blow out. |
| notes_wall | Screen | Survivor notes with hints (siren timer, pigeons, the kid, mannequins). |
| broken_skylight | Glass | Set see-through. Moonlight comes down through it at night. |
| puddle | Body | A little shiny and see-through. Splash sound when you walk through, pulls robots. |
| leak_bucket | Body | Drip sound loop. |
| survivor_tent, sleeping_bag, weeds, vines | Body | Set dressing. The tent is a hiding spot. |
| locker | Door | Swings open on its left hinge. Your saved stash, the only thing that comes with you to every server. |
| paper_and_pen | Body | Pick up to draw a blueprint of your fort. Used up when you do. |
| blueprint | Body | Lay it out once a day, during the day: a ghost outline your pieces snap into. |
| dog_bowl | Body | Put food in it near the dog. Each fill builds trust. |
| generator | Handle, Glow | Pull Handle to start (can fail a few times). Glow on while running. Lights a section. Burns fuel, sputters when low, then dies: refuel with fuel_can and pull again. The hum pulls robots. |
| fuel_can | Body | Pour into a generator. Loot, rare deep in. |
| cassette_tape | Body | Play in a walkie_talkie: a survivor's recording. Lore. |
| journal | Body | Read a survivor's pages. Lore. |
| TV screens | Screen | Lore ads `posters/screens/lore_2026` to `lore_2029` play on old TVs, in order they tell how it went wrong. |
