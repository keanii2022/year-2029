-- The placement check the client's ghost and the server's place handler both run, so a green
-- ghost always places: does the box fit, is it in reach and under the stack limit, can the placer
-- see the spot (no placing through walls into sealed forts), and what a falling box lands on.
-- The maths lives in Logic/GrabPlace and Logic/GrabRules; this is the Roblox side of it.
local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local GrabPlace = require(script.Parent.Logic.GrabPlace)
local GrabRules = require(script.Parent.Logic.GrabRules)

local Settings = Config.Grab

-- A cast that meets an invisible volume or a non-solid part tries again past it, this many times
local LOOK_THROUGH = 3
-- Studs of the far end of the sight line that may touch something (the face the box sits against)
local SIGHT_SLACK = 0.1

export type Placing = {
	prop: PVInstance,
	size: Vector3,
	box: CFrame,
	carrier: Player,
	root: BasePart,
	humanoid: Humanoid,
	eye: Vector3, -- where the placer looks from
	tolerance: number,
	carrierBlocks: boolean,
	groundFound: boolean,
}

local GrabFit = {}

-- Placement probe for GetPartsInPart, which tests real part shapes. GetPartBoundsInBox only sees
-- bounding boxes, and big kit meshes (grass floor tiles, rack bays, hanging signs) have boxes that
-- reach well past their surfaces, so every spot near one looked blocked.
local probe: Part? = nil

local function probePart(): Part
	if probe and probe.Parent then
		return probe
	end
	local part = Instance.new("Part")
	part.Name = "GrabPlaceProbe"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = workspace
	probe = part
	return part
end

function GrabFit.boxOf(prop: PVInstance): (CFrame, Vector3)
	if prop:IsA("BasePart") then
		return prop.CFrame, prop.Size
	end
	return (prop :: Model):GetBoundingBox()
end

-- How far a box at this rotation reaches along a world direction.
function GrabFit.reach(rotation: CFrame, size: Vector3, direction: Vector3): number
	return GrabPlace.extentAlong(
		size,
		rotation.RightVector,
		rotation.UpVector,
		rotation.LookVector,
		direction
	)
end

function GrabFit.characters(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Casts straight down, passing invisible volumes and anything in ignore.
function GrabFit.castDown(start: CFrame, size: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = table.clone(ignore)
	table.insert(skip, probePart())
	for _ = 1, LOOK_THROUGH do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Blockcast(start, size, Vector3.new(0, -Settings.MaxDropFall, 0), params)
		if not hit or not hit.Instance:IsA("BasePart") then
			return hit
		end
		local part = hit.Instance :: BasePart
		if GrabPlace.landsOn(part.CanCollide, part.Transparency) then
			return hit
		end
		table.insert(skip, part)
	end
	return nil
end

-- Whether a box fits at box: fits, whether another player is what's in the way, and the part in
-- the way (for the push-out) when it's not a player.
function GrabFit.fits(
	prop: PVInstance,
	size: Vector3,
	box: CFrame,
	carrier: Player,
	tolerance: number,
	carrierBlocks: boolean
): (boolean, boolean, BasePart?)
	local part = probePart()
	local sx, sy, sz = GrabPlace.overlapSize(size.X, size.Y, size.Z, tolerance)
	part.Size = Vector3.new(sx, sy, sz)
	part.CFrame = box
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { prop, part }
	params.RespectCanCollide = false
	for _, other in workspace:GetPartsInPart(part, params) do
		local model = other:FindFirstAncestorOfClass("Model")
		local owner = nil
		while model and not owner do
			owner = Players:GetPlayerFromCharacter(model)
			model = model:FindFirstAncestorOfClass("Model")
		end
		local who: GrabPlace.Who = if not owner then nil elseif owner == carrier then "carrier" else "other"
		local otherSize = other.Size
		if
			GrabPlace.blocks({
				ownProp = false,
				character = who,
				canCollide = other.CanCollide,
				transparency = other.Transparency,
				thinnest = math.min(otherSize.X, otherSize.Y, otherSize.Z),
			}, carrierBlocks)
		then
			return false, who == "other", if who then nil else other
		end
	end
	return true, false, nil
end

-- Whether the line from eye to the box is clear of anything solid until it reaches the box.
function GrabFit.sightClear(eye: Vector3, box: CFrame, size: Vector3, ignore: { Instance }): boolean
	local toBox = box.Position - eye
	local distance = toBox.Magnitude
	if distance < 1e-3 then
		return true
	end
	local direction = toBox / distance
	local clearTo = distance - GrabFit.reach(box.Rotation, size, direction) - SIGHT_SLACK
	if clearTo <= 0 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(ignore)
	table.insert(skip, probePart())
	for _ = 1, LOOK_THROUGH do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(eye, direction * clearTo, params)
		if not hit then
			return true
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or GrabPlace.landsOn(part.CanCollide, part.Transparency) then
			return false
		end
		table.insert(skip, part)
	end
	return false
end

-- The whole place check. Returns ok, the reason when not, and the part in the way when blocked.
function GrabFit.check(placing: Placing): (boolean, string?, BasePart?)
	local box, size, root = placing.box, placing.size, placing.root
	local fits, playerInWay, blocker =
		GrabFit.fits(placing.prop, size, box, placing.carrier, placing.tolerance, placing.carrierBlocks)
	local ignore: { Instance } = GrabFit.characters()
	table.insert(ignore, placing.prop)
	local feetY = root.Position.Y - root.Size.Y / 2 - placing.humanoid.HipHeight
	local bottom = box.Position.Y - GrabFit.reach(box.Rotation, size, Vector3.yAxis)
	local ok, reason = GrabRules.canPlace({
		groundFound = placing.groundFound,
		distance = (box.Position - root.Position).Magnitude,
		reach = Settings.PlaceReach,
		sightBlocked = not GrabFit.sightClear(placing.eye, box, size, ignore),
		heightAboveFeet = bottom - feetY,
		maxHeightAboveFeet = Settings.MaxPlaceAboveFeet,
		blocked = not fits,
		playerInWay = playerInWay,
	})
	return ok, reason, blocker
end

return GrabFit
