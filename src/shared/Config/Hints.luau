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
		Keyboard = "{Slot1} Empty hands to grab   {Grab} Grab",
		Gamepad = "{HotbarPrevious} {HotbarNext} to HANDS to grab",
		Touch = "Pick {=HANDS} to grab",
	},
	PryHint = "Hold {Fire} Pry it loose",
	PryNeedsHands = {
		Keyboard = "Hold {Grab} Pry it loose",
		Gamepad = "{HotbarPrevious} {HotbarNext} HANDS to pry",
		Touch = "Pick HANDS to pry",
	},
	CarryHint = {
		Keyboard = "{Fire} Place   Hold {Fire} Let go   {=Arrows} Spin / tip   {=Z} {=X} Roll   {=Scroll} Closer / farther   Hold to spin faster",
		Gamepad = "{Fire} Place   Hold {Fire} Let go   {=DPad} Spin / tip   {=L2} + {=DPad} Roll   {=L1} {=R1} Closer / farther   Hold to spin faster",
		Touch = "{Fire} Place   Hold {Fire} Let go   {=SPIN} {=TIP} {=ROLL} Turn it, hold to go faster   {CarryCloser} {CarryFarther} Distance",
	},

	ItemNudge = {
		Keyboard = "{=1} - {=6} or {=Scroll} picks what you hold   {Backpack} Bag",
		Gamepad = "{HotbarPrevious} {HotbarNext} picks what you hold   {Backpack} Bag",
		Touch = "Tap the bar to pick what you hold   {Backpack} Bag",
	},
	BackpackTitle = "BAG",
	BackpackEmpty = "Nothing in here yet. Loot the shelves.",
	BackpackFull = "BAG FULL", -- spray red beside the stack count when every stack is used
	BackpackQuickTitle = "QUICK SLOTS",
	BackpackToBag = "TO BAG",
	BackpackDrop = "DROP",
	BackpackDropAgain = "AGAIN TO DROP",
	BackpackDropSeconds = 2, -- the second drop press has this long to land
	-- %d: the hotbar number of the quick slot the gamepad would put into
	BackpackFooter = {
		Keyboard = "Hover + {=3} - {=6} or drag: quick slot   {=X} Drop   {=LMB} Pick   {Backpack} {=Esc} Close",
		Gamepad = "{=Cross} Put in slot %d   {=Square} Next slot   {=R1} Drop   {=Circle} Close",
		Touch = "Tap an item, then a quick slot   {Backpack} Close",
	},
	InBagToast = "%s: in your bag", -- every quick slot was taken
	InBagSeconds = 2.5,
	HeldHint = "{Fire} %s", -- flashed when you pick a non-gun item: "{Fire} Eat"
	HeldHintSeconds = 3,

	GunHint = "{Fire} Fire   {Aim} Aim   {Reload} Reload",
	GunHintSeconds = 5, -- after picking up the gun; then only Reload when it runs low
	LowAmmoHint = "{Reload} Reload",
	LowAmmoShare = 0.25, -- of a full mag
	NoAmmoHint = "Out of cells",

	-- Under the call wheel (hold {Callout})
	CallWheelFooter = {
		Keyboard = "{=1} - {=7} or mouse Pick   Let go of {Callout} Choose",
		Gamepad = "{=LS} {=DPad} Pick   Let go of {Callout} or {=Cross} Choose",
		Touch = "Tap a call",
	},

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
				{ "{Callout}", "Call out. Hold: pick a call" },
				{ "{Record}", "Your record, looks, blueprint" },
			},
			right = {
				{ "HANDS" },
				{ "{=1} - {=6} {=Scroll}", "Pick what you hold" },
				{ "{Backpack}", "Bag. Hover an item + 3 - 6: quick slot" },
				{ "{Fire}", "Use it: fire, eat, throw, cuff" },
				{ "{Fire}", "Empty hands: grab furniture. Hold: pry" },
				{ "{Grab}", "Grab shortcut, empties your hands" },
				{ "{Aim}", "Aim" },
				{ "{Reload}", "Reload" },
				{ "{Emp}", "Throw an EMP" },
				{ "{Disruptor}", "Fire the disruptor" },
				{ "CARRYING" },
				{ "{Fire}", "Drop it" },
				{ "{=Arrows}", "Left / right spin, up / down tip" },
				{ "{=Z} {=X}", "Roll it (or {=RMB} + left / right)" },
				{ "{=R} {=T}", "Spin, tip. Hold any: faster" },
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
				{ "{Backpack}", "Bag: fill your quick slots" },
				{ "{Callout}", "Call out. Hold: pick" },
				{ "{Jump}", "Jump. Hidden: hold breath" },
				{ "{Use}", "Use. Nothing there: reload" },
				{ "{=RS}", "Look. Click: crouch" },
			},
			footer = "{=Touchpad} Tap: this card. Hold: your record   {=Options} Menu",
			carry = "Carrying:   {=R2} Place, hold to let go   {=DPad} Spin / tip   {=L2} + {=DPad} Roll   {=L1} {=R1} Closer / farther",
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
				{ "{Callout}", "Call out. Hold: pick a call" },
				{ "{Record}", "Your record, looks, blueprint" },
			},
			right = {
				{ "DO" },
				{ "{=FIRE}", "Big button: uses what you hold" },
				{ "{=GRAB}", "Big button with HANDS picked. Hold: pry" },
				{ "{Use}", "Open, sit, hide, switch on" },
				{ "{Flashlight}", "Flashlight" },
				{ "{=Tap bar}", "Pick what you hold" },
				{ "{Backpack}", "Bag. Tap item, tap slot" },
				{ "{Aim} {Reload}", "Show while you hold a gun" },
				{ "{=SPIN} {=TIP} {=ROLL}", "Carrying: turn it every way" },
				{ "{CarryCloser} {CarryFarther}", "Carrying: closer, farther" },
			},
		},
	},
}
