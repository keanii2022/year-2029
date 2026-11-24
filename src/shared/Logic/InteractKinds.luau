-- What every usable object does when pressed, by model name. Part and sound names come from
-- art/MOVES.md and art/SOUNDS.md; tests/InteractKinds.spec.luau checks them against the manifest.
--
-- kind     open: parts swing or slide open and shut. toggle: on and off. hide: step inside.
--          channel: next picture on a screen. press: one push. cycle: runs a while, then ends.
--          vend: drops a snack. sit: sit down. phone: rings on its own, pick up to answer.
-- parts    hinge or slide parts: open while open/on, held for a cycle.
-- press    parts that go down and back up on every use.
-- each     a hit on one of `parts` moves only that part (drawers).
-- byPart   a different behaviour when that part is the one being looked at.
-- spin     parts that turn while on. bob: parts that drift up and down while on.
-- glow     Glow parts and lamp light follow the on/open state. light: add a lamp light.
-- sound    plays on use (on or open). offSound: plays on off or close (phone: handset clatter).
-- loop     plays while on. loopConfig: Config.Interact key holding the loop's id instead.
-- loudness of the use sound. loopLoudness: emitted every few seconds while on.
local InteractKinds = {}

export type Kind = "open" | "toggle" | "hide" | "channel" | "press" | "cycle" | "vend" | "sit" | "phone"

export type Behaviour = {
	kind: Kind,
	parts: { string }?,
	press: { string }?,
	each: boolean?,
	byPart: { [string]: Behaviour }?,
	spin: { string }?,
	spinSpeed: number?, -- turns per second
	bob: { string }?,
	glow: boolean?,
	light: boolean?,
	sound: string?,
	offSound: string?,
	endSound: string?,
	loop: string?,
	loopConfig: string?,
	loudness: string,
	loopLoudness: string?,
	endLoudness: string?,
	duration: number?, -- cycle seconds
	pop: { string }?, -- cycle parts that pop out at the end
	channels: { string }?, -- channel image names, in order
	static: string?, -- image shown between channels
	staticSound: string?,
	canTurnOff: boolean?,
	screenOn: string?, -- image while on
	lines: string?, -- Config.Interact key with what it says
	lieDown: boolean?, -- hide lying flat (beds, bathtub)
	seatHeight: number?, -- share of the model's height where you sit
	search: boolean?, -- sitting searches the cushions for ammo
	spinOnSit: { string }?,
}

local TV_CHANNELS =
	{ "helpbot_ad", "blob_lamp_ad", "weather", "cooking_with_toast", "right_back", "test_pattern" }
local POSTERS = {
	"helper_of_the_month",
	"smile_on_camera",
	"hug_your_toaster",
	"think_less",
	"dont_panic",
	"lost_dog",
	"mega_sale",
	"sleep_2",
	"helper_of_the_month_defaced",
	"smile_on_camera_defaced",
	"think_less_defaced",
	"dont_panic_defaced",
}

local function cabinet(parts: { string }, each: boolean?): Behaviour
	return {
		kind = "open",
		parts = parts,
		each = each,
		sound = "cabinet_creak",
		offSound = "cabinet_shut",
		loudness = "normal",
	}
end

local function drawers(sound: string): Behaviour
	return {
		kind = "open",
		parts = { "Drawer1", "Drawer2", "Drawer3" },
		each = true,
		sound = sound,
		offSound = sound,
		loudness = "normal",
	}
end

local function tap(): Behaviour
	return {
		kind = "toggle",
		sound = "tap_squeak",
		offSound = "tap_squeak",
		loop = "water_running_loop",
		loudness = "normal",
		loopLoudness = "normal",
	}
end

local function bed(): Behaviour
	return { kind = "hide", lieDown = true, sound = "sheets_rustle", loudness = "quiet" }
end

local function seat(height: number, sound: string?, search: boolean?): Behaviour
	return { kind = "sit", seatHeight = height, sound = sound, loudness = "quiet", search = search }
end

local function lamp(sound: string, loop: string?): Behaviour
	return {
		kind = "toggle",
		glow = true,
		light = true,
		sound = sound,
		offSound = sound,
		loop = loop,
		loudness = "quiet",
	}
end

local function tv(byPart: { [string]: Behaviour }?): Behaviour
	return {
		kind = "channel",
		channels = TV_CHANNELS,
		static = "static",
		staticSound = "tv_static_burst",
		canTurnOff = true,
		sound = "tv_channel_thunk",
		offSound = "tv_channel_thunk",
		loudness = "normal",
		loopLoudness = "loud",
		byPart = byPart,
	}
end

local kinds: { [string]: Behaviour } = {
	-- Kitchen
	fridge = {
		kind = "open",
		parts = { "Door", "Door2" },
		glow = true,
		sound = "fridge_open",
		offSound = "fridge_jars",
		loop = "fridge_hum_loop",
		loudness = "normal",
	},
	pantry = cabinet({ "Door" }),
	counter = cabinet({ "Door1", "Door2", "Door3" }, true),
	stove = {
		kind = "toggle",
		glow = true,
		sound = "stove_ignite",
		loop = "stove_burner_loop",
		loudness = "normal",
		byPart = {
			Flap = {
				kind = "open",
				parts = { "Flap" },
				sound = "oven_door",
				offSound = "oven_door",
				loudness = "normal",
			},
		},
	},
	microwave = {
		kind = "cycle",
		press = { "Button" },
		spin = { "Spin" },
		spinSpeed = 0.3,
		glow = true,
		duration = 6,
		loop = "microwave_hum_loop",
		endSound = "microwave_ding",
		loudness = "normal",
		endLoudness = "loud",
		byPart = {
			Door = {
				kind = "open",
				parts = { "Door" },
				sound = "microwave_door",
				offSound = "microwave_door",
				loudness = "normal",
			},
		},
	},
	toaster = {
		kind = "cycle",
		parts = { "Lever" },
		pop = { "Toast" },
		duration = 4,
		sound = "toaster_lever",
		loop = "toaster_tick_loop",
		endSound = "toaster_pop",
		loudness = "normal",
		endLoudness = "normal",
	},

	-- Living room and bedroom
	tv_stand = tv({ DoorL = cabinet({ "DoorL", "DoorR" }), DoorR = cabinet({ "DoorL", "DoorR" }) }),
	crt_tv = tv(),
	floor_lamp = {
		kind = "toggle",
		press = { "Button" },
		glow = true,
		light = true,
		sound = "lamp_chain_click",
		offSound = "lamp_chain_click",
		loop = "bulb_buzz_loop",
		loudness = "quiet",
	},
	desk_lamp = lamp("lamp_chain_click"),
	couch = seat(0.4, "cushion_squish", true),
	armchair = seat(0.4, "cushion_squish", true),
	kitchen_chair = seat(0.47, "spring_creak"),
	office_chair = {
		kind = "sit",
		seatHeight = 0.45,
		spinOnSit = { "Spin" },
		sound = "chair_squeak",
		loudness = "normal",
	},
	wardrobe = { kind = "hide", parts = { "DoorL", "DoorR" }, sound = "wardrobe_creak", loudness = "normal" },
	dresser = drawers("drawer_wood"),
	nightstand = {
		kind = "open",
		parts = { "Drawer1" },
		sound = "drawer_wood",
		offSound = "drawer_wood",
		loudness = "normal",
	},
	bed = bed(),
	bunk_bed = bed(),
	kid_bed = bed(),

	-- Office, bathroom, kids room
	desk = {
		kind = "open",
		parts = { "Drawer1", "Drawer2", "Drawer3" },
		each = true,
		sound = "drawer_wood",
		offSound = "drawer_wood",
		loudness = "normal",
		byPart = {
			Screen = {
				kind = "press",
				screenOn = "desktop",
				sound = "computer_chime",
				lines = "ScreenLine",
				loudness = "normal",
			},
		},
	},
	filing_cabinet = drawers("drawer_metal"),
	sink_cabinet = {
		kind = "open",
		parts = { "DoorL", "DoorR" },
		sound = "cabinet_creak",
		offSound = "cabinet_shut",
		loudness = "normal",
		byPart = { Tap = tap() },
	},
	bathtub = {
		kind = "hide",
		lieDown = true,
		sound = "hide_creak",
		loudness = "quiet",
		byPart = { Tap = tap() },
	},
	shower_door = {
		kind = "open",
		parts = { "Slide" },
		sound = "shower_slide",
		offSound = "shower_rattle",
		loudness = "normal",
	},
	toy_chest = { kind = "hide", parts = { "Lid" }, sound = "toy_chest_creak", loudness = "quiet" },
	toilet = {
		kind = "open",
		parts = { "Lid" },
		sound = "toilet_lid",
		offSound = "toilet_lid",
		loudness = "normal",
		byPart = {
			Lever = { kind = "press", press = { "Lever" }, sound = "toilet_flush", loudness = "loud" },
		},
	},
	wall_panel = { kind = "channel", channels = POSTERS, loudness = "quiet" },
	poster_frame = { kind = "channel", channels = POSTERS, loudness = "quiet" },

	-- Fun props
	lava_lamp = {
		kind = "toggle",
		glow = true,
		light = true,
		bob = { "Blob" },
		sound = "lava_switch",
		offSound = "lava_switch",
		loop = "lava_bubble_loop",
		loudness = "quiet",
	},
	neon_open_sign = lamp("neon_crackle", "neon_buzz_loop"),
	press_button = {
		kind = "press",
		press = { "Button" },
		sound = "press_button_click",
		lines = "ButtonLines",
		loudness = "normal",
	},
	boombox = {
		kind = "toggle",
		press = { "Button" },
		glow = true,
		sound = "boombox_button",
		offSound = "boombox_button",
		loopConfig = "BoomboxMusicId",
		loudness = "normal",
		loopLoudness = "loud",
		byPart = {
			Flap = {
				kind = "open",
				parts = { "Flap" },
				sound = "boombox_tape_door",
				offSound = "boombox_tape_door",
				loudness = "quiet",
			},
		},
	},
	arcade_cabinet = {
		kind = "toggle",
		press = { "Lever", "Button" },
		glow = true,
		screenOn = "arcade_title",
		sound = "arcade_coin",
		offSound = "arcade_joystick",
		loudness = "normal",
	},
	table_fan = {
		kind = "toggle",
		spin = { "Spin" },
		spinSpeed = 3,
		sound = "fan_click",
		offSound = "fan_click",
		loop = "fan_whir_loop",
		loudness = "quiet",
	},
	disco_ball = {
		kind = "toggle",
		spin = { "Spin" },
		spinSpeed = 0.25,
		loop = "disco_motor_loop",
		loudness = "quiet",
	},
	record_player = {
		kind = "toggle",
		parts = { "Lid", "Arm" },
		spin = { "Spin" },
		spinSpeed = 0.55,
		sound = "record_lid",
		offSound = "record_lid",
		loop = "record_crackle_loop",
		loudness = "normal",
		loopLoudness = "loud",
	},
	music_box = { kind = "toggle", parts = { "Lid" }, spin = { "Spin" }, spinSpeed = 0.4, loudness = "quiet" },
	jack_in_the_box = {
		kind = "cycle",
		spin = { "Crank" },
		spinSpeed = 0.8,
		pop = { "Lid", "Jack" },
		duration = 3.5,
		sound = "jack_crank",
		endSound = "jack_boing",
		loudness = "normal",
		endLoudness = "loud",
	},
	vending_machine = {
		kind = "vend",
		press = { "Button" },
		pop = { "Flap" },
		duration = 1.4,
		sound = "vending_beep",
		loop = "vending_whirr",
		endSound = "vending_thud",
		loudness = "normal",
	},
	rotary_phone = {
		kind = "phone",
		parts = { "Handset" },
		press = { "Spin" },
		sound = "phone_dial",
		offSound = "phone_handset",
		loop = "phone_ring",
		loudness = "normal",
		loopLoudness = "loud",
	},
	rubber_duck = { kind = "press", sound = "duck_squeak", loudness = "normal" },

	-- Gear and story pieces that sit in the world
	loot_crate = {
		kind = "open",
		parts = { "Lid" },
		sound = "crate_lid",
		offSound = "crate_lid",
		loudness = "normal",
	},
	supply_locker = {
		kind = "open",
		parts = { "Door" },
		sound = "locker_clang",
		offSound = "locker_clang",
		loudness = "normal",
	},
	locker = {
		kind = "open",
		parts = { "Door" },
		sound = "locker_clang",
		offSound = "locker_clang",
		loudness = "normal",
	},
}

function InteractKinds.get(modelName: string?): Behaviour?
	return if modelName then kinds[modelName] else nil
end

function InteractKinds.all(): { [string]: Behaviour }
	return kinds
end

return InteractKinds
