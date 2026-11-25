-- Sim player forts, the Roblox side of Logic/FortPlan. Finds a site and sizes its plan from the
-- furniture lying around, hands crew bots one piece and slot at a time, holds the piece in front of
-- the bot while it walks, and sets it down through Grab's own placement check, so a bot fort is as
-- legal as a player's and pries the same way. Walking the bots stays in SimPlayers.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FortPlan = require(ReplicatedStorage.Shared.Logic.FortPlan)
local GrabFit = require(ReplicatedStorage.Shared.GrabFit)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Grab = require(script.Parent.Grab)
local Loudness = require(script.Parent.Loudness)

local settings = Config.SimPlayers.Forts
local grab = Config.Grab

-- Wall probes run at two heights: rack shelves leave gaps a single ray slips through
local PROBE_HEIGHTS = { 1.5, 4 }
-- A probe that meets a loose prop or an invisible volume tries again past it, this many times
local LOOK_THROUGH = 4
-- A placed piece further than this from where its crew set it has been knocked out of the fort
local MOVED = 1.5
-- Studs a blocked slot's start is planned around before the next try
local BLOCK_STEP = 1.5

export type Crew = {
	id: number,
	owner: number, -- PlacedBy on every piece the crew sets down
	plan: FortPlan.Plan,
	floorY: number,
	members: { [any]: true },
	size: number,
	pieces: { [PVInstance]: string }, -- placed or on its way, to its FortPlan key
	at: { [string]: Vector3 }, -- where each placed piece was set
	idle: boolean, -- nothing left nearby that fits; cleared at dawn and when a piece goes missing
}

export type Job = {
	crew: Crew,
	prop: PVInstance,
	key: string,
	slot: FortPlan.Slot,
	axes: { number }, -- the prop's own box sides that go along the wall, up and out
	size: Vector3,
	pry: boolean, -- someone else's placed piece: pry it loose first
	carrying: boolean,
	tries: number,
	pivotOffset: CFrame,
	collide: { [BasePart]: boolean },
	anchored: { [BasePart]: boolean },
}

type Candidate = {
	prop: PVInstance,
	axes: { number },
	sides: { number },
	size: Vector3,
	pry: boolean,
	distance: number,
}

local SimForts = {}

local crews: { [number]: Crew } = {}
local claims: { [PVInstance]: Job } = {}
local nextCrew = 0
local nextKey = 0
local random = Random.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function partsOf(prop: PVInstance): { BasePart }
	local parts = {}
	if prop:IsA("BasePart") then
		table.insert(parts, prop)
	end
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function isGrabbable(part: Instance): boolean
	local instance: Instance? = part
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, grab.Tag) then
			return true
		end
		instance = instance.Parent
	end
	return false
end

local function probeIgnore(): { Instance }
	local ignore = GrabFit.characters()
	for _, name in { Config.SimPlayers.FolderName, "Robots", "RobotStash" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	return ignore
end

-- First fixed, solid thing along a ray, passing loose props and invisible volumes.
local function castFixed(origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = table.clone(ignore)
	for _ = 1, LOOK_THROUGH do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if not (part:IsA("BasePart") and part.Transparency >= 1) and not isGrabbable(part) then
			return hit
		end
		table.insert(skip, part)
	end
	return nil
end

-- A prop's box, which of its sides points up as it lies, and how it would stand in a wall.
local function shape(prop: PVInstance): (CFrame, Vector3, { number }, { number })
	local box, size = GrabFit.boxOf(prop)
	local ups = { math.abs(box.RightVector.Y), math.abs(box.UpVector.Y), math.abs(box.LookVector.Y) }
	local up = 1
	for axis = 2, 3 do
		if ups[axis] > ups[up] then
			up = axis
		end
	end
	local sides = { size.X, size.Y, size.Z }
	local along, height, out = FortPlan.orient(sides, up, settings.Plan.MinWallHeight)
	return box, size, { along, height, out }, sides
end

-- The rotation that stands a box with its axes[1] side along `along`, axes[2] up and axes[3] out.
local function standing(axes: { number }, along: Vector3, out: Vector3): CFrame
	local images = {}
	images[axes[1]] = along
	images[axes[2]] = Vector3.yAxis
	images[axes[3]] = out
	-- keep it right-handed: each box axis is the cross of the next two
	local depth = axes[3]
	images[depth] = images[depth % 3 + 1]:Cross(images[(depth + 1) % 3 + 1])
	return CFrame.fromMatrix(Vector3.zero, images[1], images[2], images[3])
end

local function slotBox(job: Job, nudge: number): CFrame
	local slot, crew = job.slot, job.crew
	local along = Vector3.new(slot.dx, 0, slot.dz)
	local out = Vector3.new(slot.nx, 0, slot.nz)
	local position = Vector3.new(
		slot.x + slot.nx * nudge,
		crew.floorY + slot.bottom + slot.height / 2,
		slot.z + slot.nz * nudge
	)
	return CFrame.new(position) * standing(job.axes, along, out)
end

local function placedByOf(prop: Instance): number?
	local placedBy = prop:GetAttribute("PlacedBy")
	return if type(placedBy) == "number" then placedBy else nil
end

-- Loose or prisable pieces around center a crew could use, nearest first.
local function candidates(
	crew: Crew?,
	center: Vector3,
	raid: boolean,
	skip: { [Instance]: boolean }
): { Candidate }
	local list = {}
	local owner = crew and crew.owner
	for _, instance in CollectionService:GetTagged(grab.Tag) do
		if
			not instance:IsA("PVInstance")
			or claims[instance]
			or skip[instance]
			or (crew and crew.pieces[instance])
		then
			continue
		end
		local distance = (flat(instance:GetPivot().Position) - flat(center)).Magnitude
		if distance > settings.SearchRange or instance:GetAttribute("CarriedBy") ~= nil then
			continue
		end
		local placedBy = placedByOf(instance)
		local pry = placedBy ~= nil and placedBy ~= owner
		if (pry and not raid) or not instance:IsDescendantOf(workspace) then
			continue
		end
		local _, size, axes, sides = shape(instance)
		local longest = math.max(size.X, size.Y, size.Z)
		if longest >= settings.MinSide and longest <= settings.MaxSide then
			table.insert(
				list,
				{ prop = instance, axes = axes, sides = sides, size = size, pry = pry, distance = distance }
			)
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

local function playPlaced(prop: PVInstance)
	local holder = partsOf(prop)[1]
	local id = holder
		and ModelLibrary.soundId(settings.PlaceSounds[random:NextInteger(1, #settings.PlaceSounds)])
	if not holder or not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("normal")
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Back to how it was before the haul: hinged parts swing again; nothing anchored before means the
-- whole piece freezes where it's set, the same as Grab's own release.
local function restoreParts(job: Job)
	local anyAnchored = false
	for _, was in job.anchored do
		anyAnchored = anyAnchored or was
	end
	for part, collide in job.collide do
		if part.Parent then
			part.Anchored = job.anchored[part] or not anyAnchored
			part.CanCollide = collide
		end
	end
	job.prop:SetAttribute("CarriedBy", nil)
	job.carrying = false
end

-- Crews --------------------------------------------------------------------------------------------

-- A new crew fort near `near`, door facing `facing` when it stands free. nil when no spot around has
-- room for even the smallest fort.
function SimForts.found(near: Vector3, facing: Vector3?): Crew?
	local ignore = probeIgnore()
	local front = 3
	if facing and flat(facing).Magnitude > 0.1 then
		local best = -math.huge
		for axis, a in FortPlan.AXES do
			local dot = facing.X * a[1] + facing.Z * a[2]
			if dot > best then
				front, best = axis, dot
			end
		end
	end
	for try = 1, settings.SiteTries do
		local at = near
		if try > 1 then
			local angle = random:NextNumber(0, math.pi * 2)
			at = near + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(6, 18)
		end
		local taken = false
		for _, crew in crews do
			if FortPlan.contains(crew.plan, at.X, at.Z, settings.Plan.Room * 2) then
				taken = true
			end
		end
		local floor = not taken and castFixed(at + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), ignore)
		if not floor then
			continue
		end
		local floorY = floor.Position.Y
		local walls = {}
		for axis, a in FortPlan.AXES do
			local direction = Vector3.new(a[1], 0, a[2]) * settings.SiteProbe
			walls[axis] = settings.SiteProbe
			for _, height in PROBE_HEIGHTS do
				local hit = castFixed(Vector3.new(at.X, floorY + height, at.Z), direction, ignore)
				if hit then
					walls[axis] = math.min(walls[axis], hit.Distance)
				end
			end
		end
		local available = 0
		for index, candidate in candidates(nil, at, false, {}) do
			if index > settings.CountPieces then
				break
			end
			available += candidate.sides[candidate.axes[1]]
		end
		local plan = FortPlan.new(
			{ x = at.X, z = at.Z, walls = walls, front = front, available = available },
			settings.Plan
		)
		if plan then
			nextCrew += 1
			local crew: Crew = {
				id = nextCrew,
				owner = -(settings.OwnerBase + nextCrew),
				plan = plan,
				floorY = floorY,
				members = {},
				size = 0,
				pieces = {},
				at = {},
				idle = false,
			}
			crews[crew.id] = crew
			return crew
		end
	end
	return nil
end

-- An unfinished crew fort near position with room for one more builder.
function SimForts.nearestOpen(position: Vector3): Crew?
	local best, bestDistance = nil, settings.JoinRange
	for _, crew in crews do
		local distance = (flat(SimForts.center(crew)) - flat(position)).Magnitude
		if not crew.idle and crew.size < settings.CrewSize and distance < bestDistance then
			best, bestDistance = crew, distance
		end
	end
	return best
end

function SimForts.join(crew: Crew, member: any)
	if not crew.members[member] then
		crew.members[member] = true
		crew.size += 1
	end
end

-- The last builder gone leaves the fort standing, with nobody to keep it up.
function SimForts.leave(crew: Crew, member: any)
	if crew.members[member] then
		crew.members[member] = nil
		crew.size -= 1
	end
	if crew.size <= 0 then
		crews[crew.id] = nil
	end
end

-- Pieces knocked out, pried away or gone free their stretch for a repair.
function SimForts.audit(crew: Crew)
	local plan = crew.plan
	for prop, key in crew.pieces do
		local piece = plan.pieces[key]
		if not piece then
			crew.pieces[prop] = nil
			crew.at[key] = nil
		elseif piece.placed then
			local at = crew.at[key]
			local intact = prop:IsDescendantOf(workspace)
				and placedByOf(prop) == crew.owner
				and prop:GetAttribute("CarriedBy") == nil
				and at ~= nil
				and (GrabFit.boxOf(prop).Position - at).Magnitude <= MOVED
			if not intact then
				FortPlan.remove(plan, key)
				crew.pieces[prop] = nil
				crew.at[key] = nil
				crew.idle = false
			end
		end
	end
end

-- A new day: every crew checks its fort and gets back to repairing and building it up.
function SimForts.dawn()
	for _, crew in crews do
		SimForts.audit(crew)
		crew.idle = false
	end
end

function SimForts.building(crew: Crew): boolean
	return not crew.idle
end

function SimForts.count(crew: Crew): number
	return FortPlan.count(crew.plan)
end

function SimForts.center(crew: Crew): Vector3
	local x, z = FortPlan.center(crew.plan)
	return Vector3.new(x, crew.floorY, z)
end

-- A random spot on the fort's inside floor.
function SimForts.insideSpot(crew: Crew): Vector3
	local x, z = FortPlan.inside(crew.plan, random:NextNumber(), random:NextNumber(), 1.5)
	return Vector3.new(x, crew.floorY, z)
end

function SimForts.raided(crew: Crew, position: Vector3): boolean
	return FortPlan.contains(crew.plan, position.X, position.Z, settings.DefendPad)
end

-- Jobs ---------------------------------------------------------------------------------------------

-- The next piece worth hauling from near `from`, with its slot held in the plan. Long pieces close
-- by come first; someone else's placed piece only when raid, and only if nothing loose is close.
-- skip: pieces this bot gave up on. nil with no crewmate hauling either marks the crew idle until
-- dawn or a piece goes missing.
function SimForts.pickPiece(crew: Crew, from: Vector3, raid: boolean, skip: { [Instance]: boolean }): Job?
	SimForts.audit(crew)
	local center = SimForts.center(crew)
	local best, bestScore, bestSlot = nil, math.huge, nil
	for _, candidate in candidates(crew, center, raid, skip) do
		local sides, axes = candidate.sides, candidate.axes
		local slot = FortPlan.slotFor(crew.plan, sides[axes[1]], sides[axes[3]], sides[axes[2]])
		if slot then
			local prop = candidate.prop
			local score = (flat(prop:GetPivot().Position) - flat(from)).Magnitude
				+ candidate.distance * 0.5
				- slot.length * 3
				+ (if candidate.pry then 25 else 0)
			if score < bestScore then
				best, bestScore, bestSlot = candidate, score, slot
			end
		end
	end
	if not best or not bestSlot then
		for _, claim in claims do
			if claim.crew == crew then
				return nil -- a crewmate's haul may still open up room
			end
		end
		crew.idle = true
		return nil
	end
	nextKey += 1
	local key = `k{nextKey}`
	FortPlan.reserve(crew.plan, bestSlot, key)
	local job: Job = {
		crew = crew,
		prop = best.prop,
		key = key,
		slot = bestSlot,
		axes = best.axes,
		size = best.size,
		pry = best.pry,
		carrying = false,
		tries = 0,
		pivotOffset = CFrame.identity,
		collide = {},
		anchored = {},
	}
	claims[best.prop] = job
	crew.pieces[best.prop] = key
	return job
end

-- Still worth going for: in the world and nobody else has picked it up.
function SimForts.valid(job: Job): boolean
	local carriedBy = job.prop:GetAttribute("CarriedBy")
	return job.prop:IsDescendantOf(workspace)
		and (carriedBy == nil or (job.carrying and carriedBy == job.crew.owner))
end

-- Seconds to pry it loose: longer when it's fortified, the same as for a player.
function SimForts.pryTime(job: Job): number
	return if Grab.isFortified(job.prop) then grab.FortPrySeconds else grab.PrySeconds
end

function SimForts.pryNoise(job: Job, source: Instance?, soundIndex: number): number
	return Grab.pryNoise(job.prop, source, soundIndex)
end

-- Picks the piece up. Returns the carry speed multiplier, or nil when it can't be taken.
function SimForts.lift(job: Job): number?
	local prop = job.prop
	if not SimForts.valid(job) or not Grab.botTake(prop) then
		return nil
	end
	local box, size, axes = shape(prop)
	job.size, job.axes = size, axes
	job.pivotOffset = box:ToObjectSpace(prop:GetPivot())
	local mass = 0
	for _, part in partsOf(prop) do
		job.collide[part] = part.CanCollide
		job.anchored[part] = part.Anchored
		mass += part:GetMass()
		part.Anchored = true
		part.CanCollide = false
	end
	prop:SetAttribute("CarriedBy", job.crew.owner)
	job.carrying = true
	job.pry = false
	return GrabMath.carrySpeedMultiplier(mass, grab.LightMass, grab.HeavyMass, grab.MinSpeedMultiplier)
end

-- Holds the piece square across the bot's chest. Every frame, so watchers see it carried.
function SimForts.carry(job: Job, root: BasePart)
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then
		return
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	local slot = job.slot
	local position = root.Position
		+ look * (slot.depth / 2 + settings.CarryGap + root.Size.Z / 2)
		+ Vector3.new(0, slot.height / 2 - settings.CarryDrop, 0)
	job.prop:PivotTo(CFrame.new(position) * standing(job.axes, right, look) * job.pivotOffset)
end

function SimForts.standSpot(job: Job): Vector3
	local x, z = FortPlan.stand(job.slot, settings.StandGap)
	return Vector3.new(x, job.crew.floorY, z)
end

function SimForts.slotSpot(job: Job): Vector3
	return Vector3.new(job.slot.x, job.crew.floorY, job.slot.z)
end

-- Sets the carried piece in its slot through Grab's placement check, nudged out a little when the
-- exact spot is refused. Returns ok and, when refused, the GrabRules reason.
function SimForts.place(
	job: Job,
	body: { root: BasePart, humanoid: Humanoid, eye: Vector3 }
): (boolean, string?)
	local crew = job.crew
	local ok, reason = false, nil
	local box = CFrame.identity
	for _, nudge in settings.Nudges do
		box = slotBox(job, nudge)
		ok, reason = Grab.botPlace(job.prop, box, job.size, job.pivotOffset, body, crew.owner)
		if ok or reason == "player" then
			break
		end
	end
	if not ok then
		job.tries += 1
		return false, reason
	end
	restoreParts(job)
	FortPlan.confirm(crew.plan, job.key)
	crew.at[job.key] = box.Position
	claims[job.prop] = nil
	playPlaced(job.prop)
	Loudness.emit(box.Position, "normal", body.root.Parent)
	return true, nil
end

-- Something fixed sits in the slot: plan around its start and hold the next slot the piece fits.
-- False when the fort has nowhere left for it.
function SimForts.reslot(job: Job): boolean
	local plan, slot = job.crew.plan, job.slot
	FortPlan.remove(plan, job.key)
	if slot.on then
		FortPlan.blockTop(plan, slot.on)
	else
		FortPlan.block(plan, slot.edge, slot.from, slot.from + math.min(slot.length, BLOCK_STEP))
	end
	local nextSlot = FortPlan.slotFor(plan, slot.length, slot.depth, slot.height)
	if not nextSlot then
		job.crew.pieces[job.prop] = nil
		return false
	end
	FortPlan.reserve(plan, nextSlot, job.key)
	job.slot, job.tries = nextSlot, 0
	return true
end

-- Gives the job up. A carried piece is set down on the floor where it is.
function SimForts.cancel(job: Job)
	local crew = job.crew
	-- a player who took it out of the bot's hands owns the carry now: leave it to Grab
	if
		job.carrying
		and job.prop:IsDescendantOf(workspace)
		and job.prop:GetAttribute("CarriedBy") == crew.owner
	then
		local box, size = GrabFit.boxOf(job.prop)
		local bottom = box.Position.Y - GrabFit.reach(box.Rotation, size, Vector3.yAxis)
		job.prop:PivotTo(job.prop:GetPivot() + Vector3.new(0, crew.floorY - bottom, 0))
		restoreParts(job)
	end
	local piece = crew.plan.pieces[job.key]
	if piece and not piece.placed then
		FortPlan.remove(crew.plan, job.key)
		if crew.pieces[job.prop] == job.key then
			crew.pieces[job.prop] = nil
		end
	end
	if claims[job.prop] == job then
		claims[job.prop] = nil
	end
end

return SimForts
