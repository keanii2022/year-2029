-- Hint wording and the controls card. Keys are written as Glyphs templates: "{Grab} Grab" draws
-- the Grab action's key for the device in use, "{=R2}" draws one key by name, and a table with
-- Keyboard / Gamepad / Touch picks wording per device. Keys themselves live in Controllers/Input.
return {
	MaxLines = 4, -- hint lines under the crosshair at once; lower order wins
	NudgeSeconds = 5, -- first-time nudges, once per session each

	StartHint = "{Controls} All controls",
	StartHintSeconds = 12,

	-- Dark: night, and no emergency light close by
	DarkNudge = "It's dark. {Flashlight} Flashlight",
	FlashlightHint = "{Flashlight} Flashlight",
	LitRadius = 40, -- studs from a red emergency light (its strip hangs high) that still count as lit

	RobotNudge = "Robot close. {Crouch} Crouch to stay quiet",
	RobotNudgeDistance = 45,

	HiddenHint = "Hold {Jump} Hold breath   {Use} Get out",

	-- Grabbing is Fire with empty hands (the HANDS slot); F on the keyboard empties them for you
	GrabNudge = {
		Keyboard = "{=F} or empty hands + {Fire} grabs furniture for your fort",
		Gamepad = "{HotbarPrevious} {HotbarNext} to HANDS, then {Fire} grabs furniture",
		Touch = "Pick HANDS, then tap GRAB to build a fort",
	},
	GrabTargetHint = "{Fire} Grab",
	GrabNeedsHands = {
		Keyboard = "{Grab} Grab",
		Gamepad = "{HotbarPrevious} {HotbarNext} HANDS to grab",
		Touch = "Pick HANDS to grab",
	},
	PryHint = "Hold {Fire} Pry it loose",
	PryNeedsHands = {
		Keyboard = "Hold {Grab} Pry it loose",
		Gamepad = "{HotbarPrevious} {HotbarNext} HANDS to pry",
		Touch = "Pick HANDS to pry",
	},
	CarryHint = {
		Keyboard = "{Fire} Drop   {=R} Turn   {=T} Tip   {=Scroll} Closer / farther",
		Gamepad = "{Fire} Drop   {=DPad} Turn / tip   {=L2} + {=DPad} Roll   {=L1} {=R1} Closer / farther",
		Touch = "{Fire} Drop   {CarryTurn} Turn   {CarryTip} Tip   {CarryCloser} {CarryFarther} Distance",
	},

	ItemNudge = {
		Keyboard = "{=1} - {=9} or {=Scroll} picks what you hold   {Backpack} Backpack",
		Gamepad = "{HotbarPrevious} {HotbarNext} picks what you hold   {Backpack} Backpack",
		Touch = "Tap the bar to pick what you hold   {Backpack} Backpack",
	},
	BackpackTitle = "BACKPACK",
	BackpackEmpty = "Nothing in here yet. Loot the shelves.",
	BackpackFooter = {
		Keyboard = "{=LMB} Hold it   {Backpack} Close",
		Gamepad = "{=Cross} Hold it   {Backpack} {=Circle} Close",
		Touch = "Tap one to hold it",
	},
	HeldHint = "{Fire} %s", -- flashed when you pick a non-gun item: "{Fire} Eat"
	HeldHintSeconds = 3,

	GunHint = "{Fire} Fire   {Aim} Aim   {Reload} Reload",
	GunHintSeconds = 5, -- after picking up the gun; then only Reload when it runs low
	LowAmmoHint = "{Reload} Reload",
	LowAmmoShare = 0.25, -- of a full mag
	NoAmmoHint = "Out of cells",

	CuffHint = "{Fire} Cuff %s",
	MashHint = "Mash {Jump} to break free",
	LoreClose = "{Use} Close",

	ContainerFooter = {
		Keyboard = "{=LMB} Move stack   {=RMB} Move one   {Use} Shut it",
		Gamepad = "{=Cross} Move stack   {=Square} Move one   {=Circle} Close",
		Touch = "Tap a stack to move it",
	},

	-- The controls card (Controls action, touchpad, or the ? button on a phone). Rows are
	-- { keys, what it does }; a row with one entry is a heading.
	CardTitle = "HOW TO SURVIVE",
	CardClose = "{Controls} Close",
	Card = {
		Keyboard = {
			left = {
				{ "MOVE" },
				{ "{=W} {=A} {=S} {=D}", "Walk" },
				{ "{Sprint}", "Sprint, uses energy" },
				{ "{Crouch} {=Ctrl}", "Crouch: slow, quiet, hard to spot" },
				{ "{Jump}", "Jump. Hold while hidden: hold breath" },
				{ "DO" },
				{ "{Use}", "Open, sit, hide, switch on" },
				{ "{Flashlight}", "Flashlight" },
				{ "{Psst}", "Psst at players close by" },
				{ "{Record}", "Your record, looks, blueprint" },
			},
			right = {
				{ "HANDS" },
				{ "{=1} - {=9} {=Scroll}", "Pick what you hold" },
				{ "{Backpack}", "Backpack: everything you carry" },
				{ "{Fire}", "Use it: fire, eat, throw, cuff" },
				{ "{Fire}", "Empty hands: grab furniture. Hold: pry" },
				{ "{Grab}", "Grab shortcut, empties your hands" },
				{ "{Aim}", "Aim" },
				{ "{Reload}", "Reload" },
				{ "{Emp}", "Throw an EMP" },
				{ "{Disruptor}", "Fire the disruptor" },
				{ "CARRYING" },
				{ "{Fire}", "Drop it" },
				{ "{=R} {=T}", "Turn it, tip it (hold to keep going)" },
				{ "{=Arrows}", "Left / right turn, up / down tip" },
				{ "{=RMB} + {=Arrows}", "Roll it" },
				{ "{=Scroll}", "Closer or farther" },
			},
		},
		-- Callouts beside the pad drawing: left half of the pad on the left, right half on the right
		Gamepad = {
			left = {
				{ "{Aim}", "Aim" },
				{ "{HotbarPrevious}", "Previous item" },
				{ "{Flashlight}", "Flashlight" },
				{ "{Eat}", "Eat" },
				{ "{Drink}", "Drink" },
				{ "{Heal}", "Bandage or medkit" },
				{ "{=LS}", "Move. Click: sprint" },
			},
			right = {
				{ "{Fire}", "Use it. Empty hands: grab" },
				{ "{HotbarNext}", "Next item" },
				{ "{Backpack}", "Backpack" },
				{ "{Psst}", "Psst" },
				{ "{Jump}", "Jump. Hidden: hold breath" },
				{ "{Use}", "Use. Nothing there: reload" },
				{ "{=RS}", "Look. Click: crouch" },
			},
			footer = "{=Touchpad} Tap: this card. Hold: your record   {=Options} Menu",
			carry = "Carrying:   {=R2} Drop   {=DPad} Turn / tip   {=L2} + {=DPad} Roll   {=L1} {=R1} Closer / farther",
		},
		Touch = {
			left = {
				{ "MOVE" },
				{ "{=Stick}", "Walk (left thumb)" },
				{ "{=Drag}", "Look around" },
				{ "{Jump}", "Jump. Hidden: hold breath" },
				{ "{Crouch}", "Crouch: slow, quiet, hard to spot" },
				{ "{Sprint}", "Sprint, uses energy" },
				{ "OTHER" },
				{ "{Psst}", "Psst at players close by" },
				{ "{Record}", "Your record, looks, blueprint" },
			},
			right = {
				{ "DO" },
				{ "{=FIRE}", "Big button: uses what you hold" },
				{ "{=GRAB}", "Big button with HANDS picked. Hold: pry" },
				{ "{Use}", "Open, sit, hide, switch on" },
				{ "{Flashlight}", "Flashlight" },
				{ "{=Tap bar}", "Pick what you hold" },
				{ "{Backpack}", "Everything you carry" },
				{ "{Aim} {Reload}", "Show while you hold a gun" },
				{ "{CarryTurn} {CarryTip}", "Carrying: turn it, tip it" },
				{ "{CarryCloser} {CarryFarther}", "Carrying: closer, farther" },
			},
		},
	},
}
