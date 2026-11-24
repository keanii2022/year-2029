-- Lookups over the generated ManifestData, plus what each part name means (art/BRIEF.md "Moving parts").
-- Pure: vectors are { x, y, z } arrays in model space (y up, front faces +z).

export type Vec = { number }

export type PartInfo = {
	name: string,
	center: Vec,
	size: Vec,
	pivot: Vec,
}

export type ModelEntry = {
	name: string,
	group: string,
	size: Vec,
	parts: { PartInfo },
	clips: { string },
	moves: { { part: string, does: string } },
	assetId: number?,
	textureId: number?,
	screenId: number?,
}

export type Asset = { name: string, assetId: number? }

export type Data = {
	models: { ModelEntry },
	sounds: { Asset },
	images: { Asset },
}

export type Index = {
	models: { [string]: ModelEntry },
	groups: { { name: string, models: { ModelEntry } } },
	sounds: { [string]: Asset },
	images: { [string]: Asset },
}

export type Axis = "X" | "Y" | "Z"

-- hinge/mover/joint turn around a pivot, spin turns forever, slide moves along an axis.
-- amount is degrees for turning kinds and a fraction of the part's length for slides.
export type Motion = {
	kind: "hinge" | "slide" | "spin" | "mover" | "joint",
	axis: Axis,
	amount: number?,
}

local Manifest = {}

local AXIS_INDEX = { X = 1, Y = 2, Z = 3 }

-- Keyed by the part name without its trailing number (Door2 -> Door, Spin2 -> Spin).
local MOTIONS: { [string]: Motion } = {
	Door = { kind = "hinge", axis = "Y" },
	DoorL = { kind = "hinge", axis = "Y" },
	DoorR = { kind = "hinge", axis = "Y" },
	Lid = { kind = "hinge", axis = "X" },
	Flap = { kind = "hinge", axis = "X" },
	Visor = { kind = "hinge", axis = "X" },
	Shirt = { kind = "hinge", axis = "X" },
	Drawer = { kind = "slide", axis = "Z" },
	Slide = { kind = "slide", axis = "X" },
	Blob = { kind = "slide", axis = "Y", amount = 0.6 },
	Toast = { kind = "slide", axis = "Y", amount = 0.5 },
	Mag = { kind = "slide", axis = "Y", amount = -1 },
	Button = { kind = "slide", axis = "Z", amount = -0.3 },
	Spin = { kind = "spin", axis = "Y" },
	Cam = { kind = "spin", axis = "Y" },
	Knob = { kind = "spin", axis = "Z" },
	Crank = { kind = "spin", axis = "Z" },
	Lever = { kind = "mover", axis = "X" },
	Handset = { kind = "mover", axis = "X" },
	Trigger = { kind = "mover", axis = "X" },
	Arm = { kind = "mover", axis = "X" },
	Jack = { kind = "slide", axis = "Y", amount = 0.8 },
	Twitch = { kind = "mover", axis = "X" },
	Tap = { kind = "mover", axis = "Y" },
	Handle = { kind = "mover", axis = "X" },
	-- robots, the dog and critters
	Head = { kind = "joint", axis = "Y" },
	Jaw = { kind = "joint", axis = "X" },
	Tail = { kind = "joint", axis = "Y" },
	Extra = { kind = "joint", axis = "X" },
	UpperArm = { kind = "joint", axis = "X" },
	Forearm = { kind = "joint", axis = "X" },
	Hand = { kind = "joint", axis = "X" },
	Thigh = { kind = "joint", axis = "X" },
	Shin = { kind = "joint", axis = "X" },
	Leg = { kind = "joint", axis = "X" },
	LegBL = { kind = "joint", axis = "X" },
	LegBR = { kind = "joint", axis = "X" },
	LegFL = { kind = "joint", axis = "X" },
	LegFR = { kind = "joint", axis = "X" },
	Legs = { kind = "joint", axis = "X" },
	WingL = { kind = "joint", axis = "Z" },
	WingR = { kind = "joint", axis = "Z" },
}

-- Robot limbs hang off the part above them; everything else hangs off the root.
local LIMB_PARENTS = {
	Head = "Torso",
	Extra = "Head",
	Jaw = "Head",
	UpperArm = "Torso",
	Forearm = "UpperArm",
	Hand = "Forearm",
	Thigh = "Torso",
	Shin = "Thigh",
}

local ROOT_ORDER = { "Body", "Handle", "Torso" }

local function baseName(partName: string): string
	local trimmed = string.gsub(partName, "%d+$", "")
	return trimmed
end

function Manifest.index(data: Data): Index
	local index: Index = { models = {}, groups = {}, sounds = {}, images = {} }
	local groupsByName = {}
	for _, entry in data.models do
		index.models[entry.name] = entry
		local group = groupsByName[entry.group]
		if not group then
			group = { name = entry.group, models = {} }
			groupsByName[entry.group] = group
			table.insert(index.groups, group)
		end
		table.insert(group.models, entry)
	end
	table.sort(index.groups, function(a, b)
		return a.name < b.name
	end)
	for _, group in index.groups do
		table.sort(group.models, function(a, b)
			return a.name < b.name
		end)
	end
	for _, sound in data.sounds do
		index.sounds[sound.name] = sound
	end
	for _, image in data.images do
		index.images[image.name] = image
	end
	return index
end

function Manifest.contentId(assetId: number?): string?
	return if assetId then `rbxassetid://{assetId}` else nil
end

function Manifest.soundId(index: Index, name: string): string?
	local sound = index.sounds[name]
	return Manifest.contentId(sound and sound.assetId)
end

function Manifest.imageId(index: Index, name: string): string?
	local image = index.images[name]
	return Manifest.contentId(image and image.assetId)
end

function Manifest.part(entry: ModelEntry, partName: string): PartInfo?
	for _, info in entry.parts do
		if info.name == partName then
			return info
		end
	end
	return nil
end

function Manifest.partNames(entry: ModelEntry): { string }
	local names = {}
	for _, info in entry.parts do
		table.insert(names, info.name)
	end
	return names
end

function Manifest.isGlow(partName: string): boolean
	return partName == "Glow"
end

function Manifest.isScreen(partName: string): boolean
	return baseName(partName) == "Screen"
end

function Manifest.rootPart(partNames: { string }): string?
	local present = {}
	for _, name in partNames do
		present[name] = true
	end
	for _, name in ROOT_ORDER do
		if present[name] then
			return name
		end
	end
	return partNames[1]
end

function Manifest.parentPart(partName: string, partNames: { string }, root: string): string
	local left = string.match(partName, "^Left(.+)$")
	local limbParent = LIMB_PARENTS[left or partName]
	if limbParent then
		local wanted = if left and limbParent ~= "Torso" then `Left{limbParent}` else limbParent
		if table.find(partNames, wanted) then
			return wanted
		end
	end
	return root
end

-- nil means the part stays welded still (Body, Glow, Screen, Glass and anything unknown).
function Manifest.motion(
	modelName: string,
	partName: string,
	overrides: { [string]: { [string]: Axis } }?
): Motion?
	if partName == "Torso" then
		return nil
	end
	local plain = string.match(partName, "^Left(.+)$") or partName
	local motion = MOTIONS[plain] or MOTIONS[baseName(plain)]
	if not motion then
		return nil
	end
	local modelOverrides = overrides and overrides[modelName]
	local axis = modelOverrides and modelOverrides[partName]
	if axis then
		return { kind = motion.kind, axis = axis, amount = motion.amount }
	end
	return motion
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- Turning direction that swings the part out toward the front and up (doors open outward, lids lift).
-- Positive turns follow the right-hand rule, the same as CFrame.Angles.
function Manifest.turnSign(axis: Axis, center: Vec, pivot: Vec): number
	local axisVector = { 0, 0, 0 }
	axisVector[AXIS_INDEX[axis]] = 1
	local lever = { center[1] - pivot[1], center[2] - pivot[2], center[3] - pivot[3] }
	local sweep = cross(axisVector, lever)
	return if sweep[2] + sweep[3] < 0 then -1 else 1
end

-- Offset for a part at openness t (0 closed, 1 fully open): degrees to turn and studs to slide along motion.axis.
function Manifest.pose(
	motion: Motion,
	t: number,
	info: PartInfo,
	limits: { [string]: number }
): (number, number)
	local sign = Manifest.turnSign(motion.axis, info.center, info.pivot)
	if motion.kind == "hinge" then
		return sign * t * (motion.amount or limits.HingeOpenDegrees), 0
	elseif motion.kind == "spin" then
		return t * 360, 0
	elseif motion.kind == "mover" or motion.kind == "joint" then
		return sign * t * (motion.amount or limits.MoverDegrees), 0
	end
	local length = info.size[AXIS_INDEX[motion.axis]]
	return 0, t * length * (motion.amount or limits.SlideOpenFraction)
end

return Manifest
