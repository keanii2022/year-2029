-- Hint text and the controls card. A hint with Keyboard / Gamepad / Touch wording shows the one
-- for the device the player last used (Hints.text). Keys themselves live in Controllers/Input.
return {
	CardTitle = "HOW TO SURVIVE",
	StartHint = {
		Keyboard = "[H] Controls      [L] Flashlight",
		Gamepad = "[D-pad up] Flashlight",
		Touch = "[?] Controls      [LIGHT] Flashlight",
	},
	StartHintSeconds = 20,
	FlashlightHint = {
		Keyboard = "It's dark. [L] Flashlight",
		Gamepad = "It's dark. [D-pad up] Flashlight",
		Touch = "It's dark. Tap LIGHT",
	},
	LitRadius = 40, -- studs from a red emergency light (its strip hangs high) that still count as lit
	GrabTargetHint = { Keyboard = "[F] Grab", Gamepad = "[R1] Grab", Touch = "Tap GRAB" },
	CarryHint = {
		Keyboard = "[F] Drop   [R] Turn   [T] Turn / Tip / Roll   [Scroll] Closer / farther   [Alt + R] Spin",
		Gamepad = "[R1] Drop   [R2 / L2] Turn   [D-pad] Turn / Tip / Roll, down resets   [L1 + R2] Spin",
		Touch = "GRAB drops   TURN turns it   AXIS changes the turn",
	},
	-- Rows of the controls card: { keyboard, gamepad, phone, what it does }. The card shows the
	-- column for the device in use. A row with only one entry is a heading.
	Controls = {
		{ "MOVING" },
		{ "W A S D", "Left stick", "Stick", "Walk" },
		{ "Mouse", "Right stick", "Drag", "Look around" },
		{ "Shift", "L3", "RUN", "Sprint (uses energy)" },
		{ "C", "R3", "CROUCH", "Crouch: slow and silent, robots barely see you" },
		{ "Space", "Cross", "Jump", "Jump (hold while hiding to hold your breath)" },
		{ "DOING THINGS" },
		{ "E", "Square", "USE", "Use what you're looking at: open, sit, hide, switch on" },
		{ "F", "R1", "GRAB", "Grab and drop furniture to build a fort" },
		{ "R / T / Scroll", "R2 L2 / D-pad", "TURN / AXIS", "While carrying: turn it, change the turn axis" },
		{ "L", "D-pad up", "LIGHT", "Flashlight" },
		{ "IN YOUR HANDS" },
		{ "1 - 9 / Scroll", "Triangle / L1", "Tap the bar", "Pick what to hold from the bar at the bottom" },
		{ "Click", "R2", "Big button", "Use what you hold: fire, eat, drink, bandage, throw, cuff" },
		{ "Right click", "L2", "AIM", "Aim a gun" },
		{ "", "D-pad left right down", "", "Eat, drink, bandage right away" },
		{ "G", "", "", "Throw an EMP (robots shut down)" },
		{ "V", "", "", "Fire the disruptor (destroys a robot)" },
		{ "OTHER" },
		{ "M", "Touchpad", "REC", "Your record, looks and blueprint" },
		{ "H", "", "?", "Show or hide this card" },
	},
}
