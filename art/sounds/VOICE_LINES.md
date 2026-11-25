# Voice lines to record

Keani records these. No computer voices: the Mac's built in `say` voices are not allowed in public projects.

How to record
- Quiet room, phone or mic about a hand away from your mouth.
- Save as wav or m4a. Leave a short breath of silence before and after each line.
- One line per file. Name it like the file name below.
- Robot lines: run `_kit/robotize.sh robot_error_training.m4a sounds/robots/voice_error_training.mp3`.
- Everything else: just trim and save as mp3 into the group folder. No robot effect.

## Robots (run robotize.sh)

Frozen hunters say one of these when the lights come on. It plays right after `robots/error_stall.mp3`. Say it flat and slow, like a machine reading a label.

| File | Line |
|---|---|
| voice_error_training | ERROR. NEEDS MORE TRAINING. |
| voice_error_task | ERROR. TASK NOT FOUND. |
| voice_error_data | ERROR. NOT ENOUGH DATA. |
| voice_error_retry | ERROR. PLEASE TRY AGAIN TOMORROW. |

## Store announcer (warehouse, from the speaker horns)

Cheerful, a bit too cheerful. Big smile while you talk, it comes through.

| File | Line |
|---|---|
| announcer_welcome | Good morning, shoppers! The store is open. Have a wonderful day! |
| announcer_welcome_2 | Rise and shine! Lights are on. Our helpers are happy to see you! |
| announcer_countdown | Lights out in ten. Nine. Eight. Seven. Six. Five. Four. Three. Two. One. |
| announcer_lights_out | The store is now closed. Please stay where our helpers can find you. |
| announcer_lights_out_2 | Good night, shoppers! Sleep tight. |

Record the countdown as one take, one second per number, so it lines up with the siren. Also save each number alone (`announcer_10` to `announcer_1`) if you want the game to speed it up.

## PRESS ME button (fun)

Happy and bouncy, like a kids' toy.

| File | Line |
|---|---|
| button_good_job | Good job! |
| button_task_complete | Task complete! |
| button_you_did_it | You did it! |

## Rotary phone (fun)

Creepy cheerful. Smile the whole time, slow down near the end. Plays after someone picks up the ringing phone.

| File | Line |
|---|---|
| phone_message | Hello! Thank you for calling. Your call is very important to us. Please stay on the line. We know where you are. Please hold. |

## Walkie talkie (fun)

Plays once the first time a player picks up a walkie. Say it like a tired night guard. Run it through the walkie static yourself, or play `fun/walkie_static.mp3` before and after it in game.

| File | Line |
|---|---|
| walkie_intro | Is this thing on? If you can hear me, hide when the lights go out. When they come back on, the robots freeze. Over. |

## Night PA (warehouse, from the speaker horns)

Same announcer, but after hours. Calm, slow, too polite. Play `warehouse/pa_chime.mp3` before each one. Sometimes `warehouse/pa_glitch.mp3` after.

| File | Line |
|---|---|
| pa_closed | Attention shoppers. The store is now closed. Please remain where you are. |
| pa_aisle | Shopper in aisle thirty two, please remain still. |
| pa_parents | Will the parents of... please come to the front desk. |
| pa_thank_you | Thank you for staying with us. Thank you for staying. Thank you. |

For `pa_parents`, leave a full second of silence where the name would go. For `pa_thank_you`, get a little slower and flatter each time.

## Lost kid (warehouse, somewhere in the dark)

Soft and close to the mic, like a kid hiding behind a shelf. Never loud.

| File | Line |
|---|---|
| kid_giggle | (a soft giggle) |
| kid_found_you | (whispered) Found you. |
| kid_humming | (hum a few notes of a nursery style tune you make up, then stop mid tune) |
| kid_come_find_me | Come find me. |

Make the tune up yourself so it's ours. Five to eight notes is plenty.

## Far phone pickup (warehouse)

Plays when a player picks up after `warehouse/phone_ring_far.mp3`. Record close and quiet, the game adds the line crackle.

| File | Line |
|---|---|
| phone_breathing | (slow breathing on the line, a few breaths, nothing else) |
| phone_giggle | (breathing, then a small giggle, then hang up) |
| phone_jingle_hum | (hum the store jingle slowly, a bit off key) |

## PA lines (day, the livelier warehouse)
| id | line |
|---|---|
| pa_never_close | Attention shoppers: the store will never close. |
| pa_smiling_mandatory | A reminder that smiling is mandatory in aisle 40. |
| pa_special_everything | Today's special is everything, forever. |
| pa_lost_children | Lost children will collect themselves at the front desk. |
| pa_helpers_looking | Please do not look directly at the helpers. |
| pa_keep_moving | Standing still is shoplifting. Keep moving. |
| pa_always_happy | We are always happy to help. Always. |
| pa_aisle_12 | Please do not go into aisle 12. |
| pa_thank_you | Thank you for shopping. Thank you. Thank you. |
| pa_exit_elsewhere | The exit is somewhere else. |
| pa_your_name | If you hear your name, do not answer. |
| pa_fresh_bread | Fresh bread in the bakery. There is no bakery. |

## Aisle 40 (only heard in the Smile Aisle; the dad lines are the night manager's voice)
| id | line |
|---|---|
| pa_aisle40_counting | Shoppers in aisle 40: please smile for the helpers. The helpers are counting. |
| pa_aisle40_happy | A happy shopper is a safe shopper. Are you happy, shopper in aisle 40? |
| pa_aisle40_frowning | Frowning has been detected in aisle 40. Frowning is shoplifting. |
| pa_aisle40_wider | Wider, please. A little wider. Thank you, aisle 40. |
| pa_aisle40_manager | Would the night manager please return to aisle 40. Your shift is not over. |
| dad_phone_bud | (a robot copying him, on the aisle 40 phone) Hey bud. I'm in the office, behind the smiles. The booth can't tell a smile from a bow. Three little bows. ...Smile for the helpers, bud. |
| dad_last_tape | (his real last tape, tired, quiet) Last tape. They learned my voice from these. If a helper says I'll come find you, that's not me. I'd say stay put. Stay put, bud. I'm coming. |

## Night phone
| id | line |
|---|---|
| phone_giggle | A child's giggle, close to the mouthpiece, cut off. (Played after a few seconds of breathing when you answer a ringing phone at night.) |
