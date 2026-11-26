-- Robot companions. Each morning a few chore robots turn curious (blue-white eyes, holding up a ghost
-- of something they want). Players earn one's trust (Logic/RobotTrust) with gifts, by building near
-- it, by fixing it when it's shot down and by keeping it safe at night. As trust grows it trails
-- you, walks beside you hauling junk, then bonds: follows, chirps when someone comes near your fort,
-- pulls back on a piece being pried, and once shown a spot builds you a fort by day (a private
-- SimForts crew, every leg watched by Logic/BuildPlan so it never stands stuck). Out alone at night,
-- a scout that sees it pulls it into the pack until morning. Robots does the moving; this decides.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildPlan = require(ReplicatedStorage.Shared.Logic.BuildPlan)
local Config = require(ReplicatedStorage.Shared.Config)
local FortPlan = require(ReplicatedStorage.Shared.Logic.FortPlan)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local RobotTrust = require(ReplicatedStorage.Shared.Logic.RobotTrust)
local DayNight = require(script.Parent.DayNight)
local Dog = require(script.Parent.Dog)
local Grab = require(script.Parent.Grab)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Robots = require(script.Parent.Robots)
local Saves = require(script.Parent.Saves)
local SimForts = require(script.Parent.SimForts)

local settings = Config.Companion
local trustSettings: RobotTrust.Settings = settings.Trust
local build = settings.Build
local sounds = settings.Sounds
local voice = settings.Voice
local grabTag = Config.Grab.Tag

type Robot = Robots.Robot
type Alive = { player: Player, root: BasePart, position: Vector3, look: Vector3, crouching: boolean }
type Lesson = { by: number, at: number, position: Vector3 }
type Hold = { began: number, ended: number? }
type Pal = {
	robot: Robot,
	records: { [number]: RobotTrust.Record }, -- by UserId
	owner: Player?,
	ownerId: number?,
	ownerAwaySince: number?,
	ownerLeftAt: number?,
	lockedUntil: number,
	wants: string?,
	shownStage: RobotTrust.Stage?, -- the owner's stage the last time it reacted to one
	mode: RobotTrust.Mode,
	downBy: any?,
	downSince: number?,
	repaired: boolean,
	homeUntil: number,
	shotLossAt: { [number]: number },
	shunned: { [number]: number }, -- UserId -> the day they shot it: no trust from it that day
	waryAt: number,
	nightResult: ("kept" | "taken")?,
	lastGift: { [number]: string }, -- the last item each player gave it, for its bonded badge
	-- learning: one loose prop fetched for you
	scavenge: { prop: PVInstance, since: number }?,
	nextScavengeAt: number,
	skipped: { [any]: number },
	ownerStillSince: number,
	ownerLastPosition: Vector3?,
	-- guarding
	alarmAt: number,
	guardAt: number,
	fortSpot: Vector3?,
	fortPieces: number,
	fortAt: number,
	-- building
	crew: SimForts.Crew?,
	job: SimForts.Job?,
	leg: BuildPlan.Leg?,
	task: ("lift" | "place" | "rest")?,
	taskUntil: number,
	nextPickAt: number,
	crewPeak: number, -- the most pieces its fort has had: refilling below this is a repair
	playerRefusals: number, -- set-downs at this slot refused for a player standing in it
	-- teaching
	lessons: { [PVInstance]: Lesson },
	-- curious behaviour
	noticedAt: number,
	tilting: boolean,
	scoutAt: number,
	loading: { [string]: string }, -- "ghost" / "badge" -> what's being built for it right now
	recheckAt: number, -- an idle builder looks again for loose pieces now and then
	outside: boolean, -- sets the carried piece down from outside the fort
	triedBoth: boolean, -- already tried the other side of this slot
	speaking: Sound?,
	voiceAt: number,
	holds: { [ProximityPrompt]: { [number]: Hold } }, -- server-side hold timing, by UserId
	anchorAt: Vector3?,
	-- prompts ride an invisible anchor that follows the robot (its model swaps at dusk and dawn)
	anchor: Part,
	give: ProximityPrompt,
	repair: ProximityPrompt,
	buildPrompt: ProximityPrompt,
}

local Companion = {}

local pals: { [Robot]: Pal } = {}
local folder: Folder
local random = Random.new()
local wantsList: { string } = {}
local itemModels: { [string]: string } = {}
local ghostCache: { [string]: Model | false } = {}
local rapportUsed: { [number]: boolean } = {}
local leftAt: { [number]: number } = {} -- players who left: when, so their records can be let go
local builtToday: { [number]: { day: number, placed: number } } = {} -- owner UserId -> new pieces today
local foundAt: { [number]: number } = {} -- owner UserId -> last "Build here"
-- Refreshed once a tick, shared by every robot
local aliveList: { Alive } = {}
local aliveNow: { [Player]: Alive } = {}
local repickAt = 0
local wantOffset = 0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function point(v: Vector3): RobotTrust.Point
	return { x = v.X, z = v.Z }
end

local function fromPoint(p: RobotTrust.Point, y: number): Vector3
	return Vector3.new(p.x, y, p.z)
end

local function cycleSeconds(): number
	local lengths = if Config.DayNight.ShortCycle
		then Config.DayNight.ShortLengths
		else Config.DayNight.Lengths
	return lengths.Day + lengths.Siren + lengths.Night
end

local function aliveOf(player: Player?): Alive?
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not player or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	local look = flat(root.CFrame.LookVector)
	return {
		player = player,
		root = root,
		position = root.Position,
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis,
		crouching = (character :: Model):GetAttribute("Stance") == "Crouch",
	}
end

local function itemName(id: string): string
	local item = Inventory.Items[id]
	return if item then item.name else id
end

-- Sounds -------------------------------------------------------------------------------------------

local function play(robot: Robot, name: string)
	local holder = robot.headPart or robot.model.PrimaryPart
	local id = ModelLibrary.soundId(name)
	if not holder or not holder.Parent or not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = sounds.Volume
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("quiet")
	sound.Parent = holder
	Mix.route(sound, "SFX")
	sound:Play()
	Debris:AddItem(sound, 8)
end

-- The happy two-tone: low then high.
local function happy(robot: Robot)
	play(robot, sounds.HappyLow)
	task.delay(sounds.HappyGap, function()
		if not robot.dead then
			play(robot, sounds.HappyHigh)
		end
	end)
end

-- A line in Keani's robot voice: one at a time, and never more often than the cooldown.
local function say(pal: Pal, name: string)
	local now = os.clock()
	local robot = pal.robot
	local holder = robot.headPart or robot.model.PrimaryPart
	local id = ModelLibrary.soundId(name)
	if now < pal.voiceAt or not holder or not holder.Parent or not id then
		return
	end
	pal.voiceAt = now + voice.Cooldown
	if pal.speaking then
		pal.speaking:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = voice.Volume
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff("quiet")
	sound.Parent = holder
	Mix.route(sound, "SFX")
	pal.speaking = sound
	sound:Play()
	Debris:AddItem(sound, 10)
end

local function userIdOf(shooter: any): number?
	if typeof(shooter) == "Instance" and shooter:IsA("Player") then
		return shooter.UserId
	end
	return nil
end

local function shuns(pal: Pal, userId: number): boolean
	return pal.shunned[userId] == DayNight.day()
end

-- What it holds up and wears ---------------------------------------------------------------------

local function stripToShell(model: Model, color: Color3?, transparency: number)
	for _, tag in CollectionService:GetTags(model) do
		CollectionService:RemoveTag(model, tag)
	end
	for _, descendant in model:GetDescendants() do
		for _, tag in CollectionService:GetTags(descendant) do
			CollectionService:RemoveTag(descendant, tag)
		end
		if
			descendant:IsA("ProximityPrompt")
			or descendant:IsA("Sound")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Transparency = math.max(descendant.Transparency, transparency)
			if color then
				descendant.Color = color
				descendant.Material = Enum.Material.Neon
			end
		end
	end
end

-- A copy of an item's world model, built once per look and cloned after. May yield the first time.
local function itemShell(id: string, ghost: boolean): Model?
	local key = `{id}:{ghost}`
	local cached = ghostCache[key]
	if cached ~= nil then
		return if cached then cached:Clone() else nil
	end
	local name = itemModels[id]
	local model = name and ModelLibrary.get(name)
	if not model then
		ghostCache[key] = false
		return nil
	end
	stripToShell(
		model,
		if ghost then settings.GhostColor else nil,
		if ghost then settings.GhostTransparency else 0
	)
	model:ScaleTo(model:GetScale() * (if ghost then settings.GhostScale else settings.BadgeScale))
	ghostCache[key] = model
	return model:Clone()
end

local function colourBadge(userId: number): Model
	local colours = settings.BadgeColors
	local model = Instance.new("Model")
	model.Name = "Badge"
	local dot = Instance.new("Part")
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * 0.7
	dot.Material = Enum.Material.Neon
	dot.Color = colours[userId % #colours + 1]
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false
	dot.CanTouch = false
	dot.CastShadow = false
	dot.Parent = model
	model.PrimaryPart = dot
	return model
end

-- Shows the ghost while it's still asking (curious, watching) and the badge once bonded. Models
-- build off the tick, since the first copy of an item can take a moment to load.
local function dressUp(pal: Pal, stage: RobotTrust.Stage)
	local robot = pal.robot
	local wantsShown = pal.wants and not RobotTrust.atLeast(stage, "learning") and not Robots.isDown(robot)
	local ghostName = if wantsShown then pal.wants else nil
	if (robot.ghost and robot.ghost:GetAttribute("Item")) ~= ghostName then
		if ghostName and pal.loading.ghost ~= ghostName then
			pal.loading.ghost = ghostName
			task.spawn(function()
				local shell = itemShell(ghostName, true)
				pal.loading.ghost = nil
				if shell and pals[robot] == pal and pal.wants == ghostName and not robot.dead then
					shell:SetAttribute("Item", ghostName)
					Robots.attach(robot, "ghost", shell)
				elseif shell then
					shell:Destroy()
				end
			end)
		elseif not ghostName then
			Robots.attach(robot, "ghost", nil)
		end
	end
	local ownerId = pal.ownerId
	local badgeKey = nil
	if stage == "bonded" and ownerId then
		badgeKey = pal.lastGift[ownerId] or `colour{ownerId}`
	end
	if (robot.badge and robot.badge:GetAttribute("Key")) ~= badgeKey then
		if badgeKey and ownerId and pal.loading.badge ~= badgeKey then
			pal.loading.badge = badgeKey
			local gift = pal.lastGift[ownerId]
			task.spawn(function()
				local shell = (if gift then itemShell(gift, false) else nil) or colourBadge(ownerId)
				pal.loading.badge = nil
				if pals[robot] == pal and not robot.dead and pal.ownerId == ownerId then
					shell:SetAttribute("Key", badgeKey)
					Robots.attach(robot, "badge", shell)
				else
					shell:Destroy()
				end
			end)
		elseif not badgeKey then
			Robots.attach(robot, "badge", nil)
		end
	end
end

-- Trust records ----------------------------------------------------------------------------------

local function savedRapport(player: Player): number
	local data = Saves.data(player)
	local rapport = data and (data :: any).rapport
	if not rapport then
		return 0
	end
	return RobotTrust.rapport(rapport.stage, rapport.at, os.time(), trustSettings)
end

local function recordFor(pal: Pal, player: Player): RobotTrust.Record
	local record = pal.records[player.UserId]
	if not record then
		record = RobotTrust.new(0)
		pal.records[player.UserId] = record
	end
	return record
end

local function noteRapport(player: Player, stage: RobotTrust.Stage, together: boolean)
	local data = Saves.data(player)
	local rapport = data and (data :: any).rapport
	if not rapport then
		return
	end
	local rank = RobotTrust.rank(stage)
	if rank > rapport.stage then
		rapport.stage = rank
		rapport.at = os.time()
	elseif together and rapport.stage > 0 then
		rapport.at = os.time()
	end
end

local function ownsOther(player: Player, pal: Pal): boolean
	for _, other in pals do
		if other ~= pal and other.ownerId == player.UserId then
			return true
		end
	end
	return false
end

local function ownerStage(pal: Pal): RobotTrust.Stage
	local record = pal.ownerId and pal.records[pal.ownerId]
	return if record then RobotTrust.stage(record, trustSettings) else "curious"
end

-- Building ---------------------------------------------------------------------------------------

local function dropJob(pal: Pal)
	local job = pal.job
	Robots.carryWith(pal.robot, nil)
	if job then
		SimForts.cancel(job)
	end
	pal.job, pal.leg, pal.task = nil, nil, nil
end

local function leaveCrew(pal: Pal)
	dropJob(pal)
	if pal.crew then
		SimForts.leave(pal.crew, pal)
		pal.crew = nil
	end
end

local function placedToday(userId: number): number
	local entry = builtToday[userId]
	return if entry and entry.day == DayNight.day() then entry.placed else 0
end

local function canPlaceMore(pal: Pal, crew: SimForts.Crew): boolean
	local ownerId = pal.ownerId
	return ownerId ~= nil
		and BuildPlan.canPlace(SimForts.count(crew), pal.crewPeak, placedToday(ownerId), build.MaxPieces)
end

local function hasWork(pal: Pal): boolean
	local crew = pal.crew
	if not crew then
		return false
	end
	return pal.job ~= nil or (SimForts.building(crew) and canPlaceMore(pal, crew))
end

-- A piece set down: past the fort's best so far it's new and uses up one of today's pieces.
local function notePlaced(pal: Pal, crew: SimForts.Crew)
	local count, ownerId = SimForts.count(crew), pal.ownerId
	if count <= pal.crewPeak or not ownerId then
		return
	end
	pal.crewPeak = count
	local day = DayNight.day()
	local entry = builtToday[ownerId]
	if not entry or entry.day ~= day then
		entry = { day = day, placed = 0 }
		builtToday[ownerId] = entry
	end
	entry.placed += 1
end

local function skipPiece(pal: Pal, prop: Instance, now: number)
	BuildPlan.skip(pal.skipped, prop, now, build.SkipFor)
end

-- Where to stand to set the carried piece down: just inside the fort or just outside it. A robot is
-- too wide for most fort doors, and Grab's reach lets it set a piece down from either side.
local function standSpot(pal: Pal, job: SimForts.Job): Vector3
	local slot = job.slot
	local back = slot.depth / 2 + Config.SimPlayers.Forts.StandGap + 1
	local side = if pal.outside then 1 else -1
	return Vector3.new(slot.x + slot.nx * back * side, job.crew.floorY, slot.z + slot.nz * back * side)
end

-- A new carry leg toward whichever side of the slot is nearer.
local function startCarry(pal: Pal, job: SimForts.Job, now: number)
	local robot = pal.robot
	pal.outside = false
	local inside = flatDistance(standSpot(pal, job), robot.position)
	pal.outside = true
	local outside = flatDistance(standSpot(pal, job), robot.position)
	pal.outside = outside < inside
	pal.triedBoth = false
	pal.playerRefusals = 0
	pal.leg = BuildPlan.leg("carry", now, math.min(inside, outside))
end

local function finishTask(pal: Pal, now: number)
	local robot, job, task = pal.robot, pal.job, pal.task
	pal.task = nil
	if not job or task == "rest" then
		return
	end
	if task == "lift" then
		if not SimForts.lift(job) then
			skipPiece(pal, job.prop, now)
			dropJob(pal)
			return
		end
		Robots.carryWith(robot, function(body: Robot)
			if SimForts.valid(job) then
				SimForts.carry(job, Robots.body(body).root)
			end
		end)
		startCarry(pal, job, now)
	elseif task == "place" then
		local ok, reason = SimForts.place(job, Robots.body(robot))
		if ok then
			Robots.carryWith(robot, nil)
			pal.job, pal.leg = nil, nil
			pal.task, pal.taskUntil = "rest", now + build.RestTime
			play(robot, sounds.HappyLow)
			notePlaced(pal, job.crew)
			if not canPlaceMore(pal, job.crew) then
				say(pal, voice.BuildDone)
			end
			return
		end
		if reason == "player" then
			pal.playerRefusals += 1
		end
		local leg = pal.leg
		if not leg or BuildPlan.stopPlacing(leg, now, job.tries, pal.playerRefusals, build) then
			-- something sits in the slot (or someone won't move): plan around it, or give the piece up
			if SimForts.reslot(job) then
				startCarry(pal, job, now)
			else
				skipPiece(pal, job.prop, now)
				dropJob(pal)
			end
		end
	end
end

-- One step of fort building: fetch a loose piece, carry it to its slot, set it down through Grab.
local function buildStep(pal: Pal, crew: SimForts.Crew, now: number): Robots.Order
	local robot = pal.robot
	if pal.task then
		if now >= pal.taskUntil then
			finishTask(pal, now)
		end
		local job = pal.job
		local face = if job
			then (if job.carrying then SimForts.slotSpot(job) else job.prop:GetPivot().Position)
			else nil
		return { pose = if pal.task == "lift" then "grab" elseif job then "carry" else "idle", face = face }
	end
	local job = pal.job
	if job and not SimForts.valid(job) then
		dropJob(pal)
		job = nil
	end
	if not job then
		if now < pal.nextPickAt then
			return { goal = SimForts.center(crew), pose = "walk" }
		end
		job = SimForts.pickPiece(crew, robot.position, false, BuildPlan.skipping(pal.skipped, now))
		if not job then
			pal.nextPickAt = now + build.PickRetry
			return { pose = "idle" }
		end
		pal.job = job
		pal.leg = BuildPlan.leg("fetch", now, flatDistance(job.prop:GetPivot().Position, robot.position))
	end
	local haul = job :: SimForts.Job
	local leg = pal.leg :: BuildPlan.Leg
	local blocked = Robots.blocked(robot, 0.5)
	if not haul.carrying then
		local at = haul.prop:GetPivot().Position
		local distance = flatDistance(at, robot.position)
		if distance <= 3 + haul.size.Magnitude / 2 then
			pal.task, pal.taskUntil = "lift", now + build.PickupTime
			return { pose = "grab", face = at }
		end
		local step = BuildPlan.step(leg, now, distance, blocked, build)
		if step == "give_up" then
			skipPiece(pal, haul.prop, now)
			dropJob(pal)
			return { pose = "idle" }
		elseif step == "repath" then
			Robots.repath(robot)
		end
		return { goal = at, pose = "walk" }
	end
	local stand = standSpot(pal, haul)
	local distance = flatDistance(stand, robot.position)
	if distance <= Config.SimPlayers.Forts.PlaceRange + 0.5 then
		pal.task, pal.taskUntil = "place", now + build.PlaceTime
		return { pose = "carry", face = SimForts.slotSpot(haul) }
	end
	local step = BuildPlan.step(leg, now, distance, blocked, build)
	if step == "give_up" then
		if not pal.triedBoth then
			-- can't get to this side of the slot: try the other side
			pal.triedBoth = true
			pal.outside = not pal.outside
			pal.leg = BuildPlan.leg("carry", now, flatDistance(standSpot(pal, haul), robot.position))
		elseif SimForts.reslot(haul) then
			-- neither side: plan the piece into another slot
			startCarry(pal, haul, now)
		else
			skipPiece(pal, haul.prop, now)
			dropJob(pal)
		end
		return { pose = "idle" }
	elseif step == "repath" then
		Robots.repath(robot)
	end
	return { goal = stand, pose = "carry" }
end

-- The fort it guards ------------------------------------------------------------------------------

-- Your fort: its own crew's plan, else the middle of your placed pieces close to it.
local function refreshFort(pal: Pal, now: number)
	if now < pal.fortAt then
		return
	end
	pal.fortAt = now + 3
	local crew = pal.crew
	if crew then
		pal.fortSpot, pal.fortPieces = SimForts.center(crew), SimForts.count(crew)
		return
	end
	local ownerId = pal.ownerId
	local sum, count = Vector3.zero, 0
	if ownerId then
		for _, prop in CollectionService:GetTagged(grabTag) do
			if prop:IsA("PVInstance") and prop:GetAttribute("PlacedBy") == ownerId then
				local at = prop:GetPivot().Position
				if flatDistance(at, pal.robot.position) <= settings.FortRadius then
					sum += at
					count += 1
				end
			end
		end
	end
	pal.fortPieces = count
	pal.fortSpot = if count >= settings.FortMinPieces then sum / count else nil
end

local function hiddenInFort(pal: Pal): boolean
	local position = pal.robot.position
	local crew = pal.crew
	local minimum = Config.SimPlayers.Forts.HideMinPieces
	if crew and SimForts.count(crew) >= minimum then
		return FortPlan.contains(crew.plan, position.X, position.Z, -settings.HidePad)
	end
	local spot = pal.fortSpot
	return spot ~= nil and pal.fortPieces >= minimum and flatDistance(spot, position) <= 5
end

local function fortInside(pal: Pal): Vector3?
	if pal.crew and SimForts.count(pal.crew) > 0 then
		local x, z = FortPlan.center(pal.crew.plan)
		return Vector3.new(x, pal.robot.position.Y, z)
	end
	return pal.fortSpot
end

-- Someone coming near your fort: a chirp, and your dog barks along. Never more than that.
local function guard(pal: Pal, now: number)
	if now < pal.guardAt or not pal.owner then
		return
	end
	pal.guardAt = now + settings.GuardScanEvery
	refreshFort(pal, now)
	local spot, owner = pal.fortSpot, pal.owner
	if not spot or now < pal.alarmAt then
		return
	end
	if flatDistance(spot, pal.robot.position) > settings.FortRadius + settings.GuardRadius then
		return -- too far off to notice
	end
	local intruder = false
	for _, alive in aliveList do
		if alive.player ~= owner and flatDistance(alive.position, spot) <= settings.GuardRadius then
			intruder = true
		end
	end
	for _, robot in Robots.inRadius(spot, settings.GuardRadius) do
		if robot ~= pal.robot and not robot.brain.companion and not robot.dead then
			intruder = true
		end
	end
	if intruder then
		pal.alarmAt = now + settings.AlarmCooldown
		play(pal.robot, sounds.Alarm)
		Dog.backUp(owner, spot)
	end
end

-- Someone prying one of your pieces nearby: it grabs the other end and pulls. Returns the order
-- while it's tugging.
local function tug(pal: Pal, dt: number): Robots.Order?
	local ownerId = pal.ownerId
	if not ownerId or pal.job then
		return nil
	end
	local robot = pal.robot
	for _, pry in Grab.activePries() do
		local prop = pry.prop
		if prop:GetAttribute("PlacedBy") == ownerId and pry.player.UserId ~= ownerId then
			local at = prop:GetPivot().Position
			local distance = flatDistance(at, robot.position)
			if distance <= settings.TugReach then
				if distance <= 4 then
					Grab.resistPry(pry.player, settings.TugSeconds * dt, settings.TugCap)
					if os.clock() >= pal.alarmAt then
						pal.alarmAt = os.clock() + settings.AlarmCooldown
						play(robot, sounds.Alarm)
					end
					return { pose = "tug", face = at, look = at }
				end
				return { goal = at, speed = "chase", pose = "walk", look = at }
			end
		end
	end
	return nil
end

-- Learning: it fetches one loose prop near you and hands it over when you stop ------------------

local function isJunk(prop: PVInstance): boolean
	if not prop:IsDescendantOf(workspace) or Robots.isClaimed(prop) then
		return false
	end
	if prop:GetAttribute("PlacedBy") ~= nil or prop:GetAttribute("CarriedBy") ~= nil then
		return false
	end
	if Grab.isFortified(prop) then
		return false
	end
	local size = if prop:IsA("BasePart") then prop.Size else (prop :: Model):GetExtentsSize()
	return math.max(size.X, size.Y, size.Z) <= settings.MaxHaulSize
end

local function findJunk(pal: Pal, around: Vector3, now: number): PVInstance?
	local skipping = BuildPlan.skipping(pal.skipped, now)
	local best, bestDistance = nil, settings.ScavengeRange
	for _, prop in CollectionService:GetTagged(grabTag) do
		if prop:IsA("PVInstance") and not skipping[prop] then
			local distance = flatDistance(prop:GetPivot().Position, around)
			if distance < bestDistance and isJunk(prop) then
				best, bestDistance = prop, distance
			end
		end
	end
	return best
end

local function besideStep(pal: Pal, owner: Alive, now: number): Robots.Order
	local robot = pal.robot
	local carried = Robots.carried(robot)
	local ownerDistance = flatDistance(owner.position, robot.position)
	if carried then
		local still = now - pal.ownerStillSince >= settings.StillSeconds
		if still and ownerDistance <= settings.BesideDistance + 4 then
			Robots.letGo(robot, robot.position + robot.facing * 3)
			pal.nextScavengeAt = now + settings.ScavengeRest
			happy(robot)
		end
	elseif pal.scavenge then
		local hunt = pal.scavenge
		if
			not isJunk(hunt.prop)
			or now - hunt.since > settings.ScavengeTimeout
			or ownerDistance > settings.HurryDistance
		then
			BuildPlan.skip(pal.skipped, hunt.prop, now, build.SkipFor)
			pal.scavenge = nil
		else
			local at = hunt.prop:GetPivot().Position
			if flatDistance(at, robot.position) <= 4 then
				Robots.hold(robot, hunt.prop)
				pal.scavenge = nil
				return { pose = "grab", face = at }
			end
			return { goal = at, pose = "walk", look = at }
		end
	elseif now >= pal.nextScavengeAt then
		pal.nextScavengeAt = now + settings.ScavengeEvery
		local prop = findJunk(pal, owner.position, now)
		if prop then
			pal.scavenge = { prop = prop, since = now }
		end
	end
	local spot = RobotTrust.beside(point(owner.position), point(owner.look), settings.BesideDistance)
	local goal = fromPoint(spot, robot.position.Y)
	local pose = if carried then "carry" elseif owner.crouching then "crouch" else "idle"
	if flatDistance(goal, robot.position) <= settings.ArriveSlack then
		return { pose = pose, face = owner.position + owner.look * 10, look = owner.position }
	end
	return {
		goal = goal,
		speed = if ownerDistance > settings.HurryDistance then "chase" else "walk",
		pose = if carried then "carry" else "walk",
		look = owner.position,
	}
end

-- Keeping a distance from its owner, catching up when far, waiting when lost.
local function keepNear(pal: Pal, owner: Alive, keep: number, standPose: string): Robots.Order
	local robot = pal.robot
	local distance = flatDistance(owner.position, robot.position)
	local look = owner.position + Vector3.yAxis * 1.5
	if distance > settings.LostDistance then
		return { pose = "idle", look = look }
	end
	local spot = RobotTrust.approach(point(robot.position), point(owner.position), keep, settings.ArriveSlack)
	if not spot then
		local pose = if owner.crouching then "crouch" else standPose
		return { pose = pose, face = owner.position, look = look }
	end
	return {
		goal = fromPoint(spot, robot.position.Y),
		speed = if distance > settings.HurryDistance then "chase" else "walk",
		pose = "walk",
		look = look,
	}
end

-- Curious: waits at its room's doorway, turns to look at you, tilts its head, copies your crouch.
local function doorwayStep(pal: Pal, now: number): Robots.Order
	local robot = pal.robot
	local spot, out = Robots.doorway(robot, settings.DoorInset)
	spot = spot or robot.home
	local nearest: Alive? = nil
	local nearestDistance = settings.NoticeRange
	for _, alive in aliveList do
		local distance = flatDistance(alive.position, robot.position)
		if distance < nearestDistance then
			nearest, nearestDistance = alive, distance
		end
	end
	local tilt = nearest ~= nil and nearestDistance <= settings.TiltRange
	if nearest and now >= pal.noticedAt then
		play(robot, sounds.Notice)
		say(pal, voice.Notice)
	end
	if nearest then
		pal.noticedAt = now + 10
	end
	if tilt and not pal.tilting then
		play(robot, sounds.Tilt)
	end
	pal.tilting = tilt
	robot.model:SetAttribute("HeadTilt", if tilt then settings.TiltDegrees else nil)
	local goal = if flatDistance(spot :: Vector3, robot.position) > settings.ArriveSlack then spot else nil
	if goal then
		return { goal = goal, pose = "walk", look = nearest and nearest.position }
	end
	local pose = if nearest and nearest.crouching
		then "crouch"
		elseif nearest and robot.ghost then "offer"
		else "idle"
	local face = if nearest then nearest.position elseif out then (spot :: Vector3) + out * 10 else nil
	return { pose = pose, face = face, look = nearest and nearest.position + Vector3.yAxis * 1.5 }
end

-- Night with its owner: close by, or tucked in the fort while you hide or after you go down.
local function nightStep(pal: Pal, owner: Alive?, now: number): Robots.Order
	local robot = pal.robot
	local ownerDistance = owner and flatDistance(owner.position, robot.position)
	local hidden = hiddenInFort(pal)
	if not RobotTrust.kept(ownerDistance, hidden, settings.KeepRadius) and now >= pal.scoutAt then
		pal.scoutAt = now + settings.ScoutCheckEvery
		if Robots.scoutSees(robot, settings.ScoutRange) then
			pal.nightResult = "taken"
			dropJob(pal)
			Robots.letGo(robot, robot.position)
			play(robot, sounds.Sad)
			Robots.release(robot)
			return { pose = "idle" }
		end
	end
	if owner and not Interact.isHidden(owner.player) then
		return keepNear(pal, owner, settings.NightFollowDistance, "crouch")
	end
	local inside = fortInside(pal)
	if inside and not hidden and flatDistance(inside, robot.position) > 1.5 then
		return { goal = inside, pose = "walk" }
	end
	return { pose = "crouch" }
end

-- Ownership --------------------------------------------------------------------------------------

local function setOwner(pal: Pal, owner: Player?, switched: boolean, now: number)
	local previous = pal.owner
	if previous == owner then
		return
	end
	if previous and owner and previous.UserId == owner.UserId then
		-- the same person back on a new player object (a rejoin)
		pal.owner = owner
		pal.ownerAwaySince, pal.ownerLeftAt = nil, nil
		return
	end
	if previous and previous.Parent then
		previous:SetAttribute("RobotStage", nil)
	end
	leaveCrew(pal)
	if pal.scavenge then
		pal.scavenge = nil
	end
	Robots.letGo(pal.robot, pal.robot.position)
	pal.owner = owner
	pal.ownerId = owner and owner.UserId
	pal.ownerAwaySince, pal.ownerLeftAt = nil, nil
	pal.shownStage = nil
	pal.fortSpot, pal.fortAt = nil, 0
	if switched then
		pal.lockedUntil = now + cycleSeconds()
	end
	if owner then
		happy(pal.robot)
	end
end

local function updateOwner(pal: Pal, now: number)
	local owner = pal.owner
	if owner and not owner.Parent then
		pal.ownerLeftAt = pal.ownerLeftAt or now
		if now - pal.ownerLeftAt >= settings.LeftHoldSeconds then
			-- waited long enough: back to curious, as if it never knew them
			pal.records[owner.UserId] = nil
			setOwner(pal, nil, false, now)
			owner = nil
		end
	end
	if owner then
		-- away (so someone else can win it) only while the owner is dead or out of the server
		if owner.Parent and aliveNow[owner] then
			pal.ownerAwaySince = nil
		else
			pal.ownerAwaySince = pal.ownerAwaySince or now
		end
	end
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local record = pal.records[player.UserId]
		if record then
			table.insert(candidates, {
				id = player,
				stage = RobotTrust.stage(record, trustSettings),
				trust = record.trust,
				free = player.UserId == pal.ownerId or not ownsOther(player, pal),
			})
		end
	end
	local ownerRecord = owner and pal.records[owner.UserId]
	local chosen, switched = RobotTrust.chooseOwner({
		owner = owner,
		ownerStage = if ownerRecord then RobotTrust.stage(ownerRecord, trustSettings) else nil,
		ownerTrust = if ownerRecord then ownerRecord.trust else 0,
		ownerGoneFor = if pal.ownerAwaySince then now - pal.ownerAwaySince else 0,
		lockedUntil = pal.lockedUntil,
		now = now,
		goneSeconds = settings.OwnerGoneSeconds,
		margin = settings.SwitchMargin,
		candidates = candidates,
	})
	setOwner(pal, chosen, switched, now)
end

-- A stage up or down since it last reacted: the happy two-tone or a sad stall, saved as rapport.
local function reactToStage(pal: Pal, stage: RobotTrust.Stage)
	local owner = pal.owner
	if not owner then
		return
	end
	local shown = pal.shownStage
	pal.shownStage = stage
	owner:SetAttribute("RobotStage", stage)
	noteRapport(owner, stage, false)
	if not shown or shown == stage then
		return
	end
	if RobotTrust.rank(stage) > RobotTrust.rank(shown) then
		happy(pal.robot)
		if stage == "bonded" then
			say(pal, voice.Bonded)
		end
	else
		play(pal.robot, sounds.Sad)
	end
end

local function loseStage(pal: Pal, userId: number)
	local record = pal.records[userId]
	if record then
		RobotTrust.dropStage(record, trustSettings)
	end
end

-- It backs off from someone who shot it today, chirping. nil when nobody like that is close.
local function wary(pal: Pal, now: number): Robots.Order?
	local robot = pal.robot
	local nearest: Alive? = nil
	local nearestDistance = settings.WaryRange
	for _, alive in aliveList do
		local distance = flatDistance(alive.position, robot.position)
		if distance < nearestDistance and shuns(pal, alive.player.UserId) then
			nearest, nearestDistance = alive, distance
		end
	end
	if not nearest then
		return nil
	end
	if now >= pal.waryAt then
		pal.waryAt = now + settings.WaryChirpEvery
		play(robot, sounds.Alarm)
	end
	local away = flat(robot.position - nearest.position)
	away = if away.Magnitude > 0.01 then away.Unit else -robot.facing
	return {
		goal = robot.position + away * settings.WaryBackOff,
		pose = "walk",
		look = nearest.position + Vector3.yAxis * 1.5,
	}
end

-- Each tick ------------------------------------------------------------------------------------

local function forget(pal: Pal, userId: number)
	pal.records[userId] = nil
	pal.shotLossAt[userId] = nil
	pal.lastGift[userId] = nil
	pal.shunned[userId] = nil
end

local function decayAll(pal: Pal, dt: number, now: number)
	local at = pal.robot.position
	for userId, record in pal.records do
		local player = Players:GetPlayerByUserId(userId)
		if userId == pal.ownerId then
			-- the owner's trust only fades while they're dead or gone; a builder is working for them
			local with = pal.mode == "build" or (player ~= nil and aliveNow[player] ~= nil)
			RobotTrust.decay(record, dt, with, trustSettings)
		elseif player then
			local alive = aliveNow[player]
			local near = alive ~= nil and flatDistance(alive.position, at) <= trustSettings.NearDistance
			RobotTrust.decay(record, dt, near, trustSettings)
		elseif not leftAt[userId] then
			forget(pal, userId) -- left over LeftHoldSeconds ago (forgetLeavers dropped leftAt)
		end
	end
	local day = DayNight.day()
	for userId, last in pal.shotLossAt do
		if now - last >= settings.StageLossCooldown then
			pal.shotLossAt[userId] = nil
		end
	end
	for userId, shotOn in pal.shunned do
		if shotOn ~= day then
			pal.shunned[userId] = nil
		end
	end
	for userId in pal.lastGift do
		if not pal.records[userId] then
			pal.lastGift[userId] = nil
		end
	end
	for _, holds in pal.holds do
		for userId, hold in holds do
			if now - hold.began > 60 then
				holds[userId] = nil
			end
		end
	end
	-- anyone close enough to be noticed starts a record
	for _, alive in aliveList do
		if flatDistance(alive.position, at) <= settings.NoticeRange then
			recordFor(pal, alive.player)
		end
	end
end

local function checkLessons(pal: Pal, now: number)
	for prop, lesson in pal.lessons do
		if now - lesson.at < settings.TeachHoldSeconds then
			continue
		end
		pal.lessons[prop] = nil
		local player = Players:GetPlayerByUserId(lesson.by)
		local stayed = prop:IsDescendantOf(workspace)
			and prop:GetAttribute("PlacedBy") == lesson.by
			and (prop:GetPivot().Position - lesson.position).Magnitude <= settings.TeachMoved
		if player and stayed and not shuns(pal, lesson.by) and Grab.isFortified(prop) then
			local added = RobotTrust.teach(recordFor(pal, player), DayNight.day(), trustSettings)
			if added > 0 then
				play(pal.robot, sounds.Notice)
			end
		end
	end
end

local function updateDown(pal: Pal, now: number)
	local robot = pal.robot
	local down = Robots.isDown(robot)
	if down and not pal.downSince then
		pal.downSince = now
	elseif not down and pal.downSince then
		pal.downSince = nil
		if not pal.repaired then
			-- nobody fixed it: it rebooted on its own and wanders home. That costs the owner a stage
			-- only when they or a robot knocked it down (anyone else would be stealing it for free),
			-- and not after a night with the pack, which already cost one at dawn.
			local by = pal.downBy
			local byRobot = type(by) == "table" and by.brain ~= nil
			if pal.ownerId and byRobot and pal.nightResult ~= "taken" then
				loseStage(pal, pal.ownerId)
			end
			pal.homeUntil = now + settings.HomeSeconds
			play(robot, sounds.Sad)
		end
		pal.repaired = false
		pal.downBy = nil
	end
	pal.repair.Enabled = down and robot.brain.companion
	pal.give.Enabled = not down and pal.wants ~= nil and robot.brain.companion
	pal.anchor:SetAttribute("Down", down or nil)
end

local function stepPal(pal: Pal, dt: number, now: number)
	local robot = pal.robot
	local phase = DayNight.phase()
	decayAll(pal, dt, now)
	updateOwner(pal, now)
	updateDown(pal, now)
	checkLessons(pal, now)

	local owner = pal.owner
	local ownerAlive = owner and aliveNow[owner]
	local stage = ownerStage(pal)
	local crew = pal.crew
	if crew and crew.idle and now >= pal.recheckAt then
		pal.recheckAt = now + 15
		crew.idle = false -- something new may be lying around to build with
	end
	local mode = RobotTrust.mode({
		owned = owner ~= nil,
		stage = stage,
		phase = phase,
		down = Robots.isDown(robot),
		homeBound = now < pal.homeUntil,
		ownerHere = owner ~= nil and owner.Parent ~= nil,
		hasWork = hasWork(pal),
	})
	if pal.nightResult == "taken" and phase == "Night" then
		mode = "pack"
	end
	pal.mode = mode
	pal.anchor:SetAttribute("Owner", pal.ownerId)
	pal.anchor:SetAttribute("Bonded", stage == "bonded" or nil)
	pal.anchor:SetAttribute("Wants", pal.wants)
	pal.give.ActionText = if pal.wants then `Give {itemName(pal.wants)}` else "Give"

	if mode == "pack" then
		Robots.release(robot)
		return
	end
	if not robot.brain.companion then
		Robots.befriend(robot)
	end
	Robots.setCompanion(robot, pal.ownerId, stage == "bonded", pal.wants)
	dressUp(pal, stage)
	reactToStage(pal, stage)
	if owner and ownerAlive and flatDistance(ownerAlive.position, robot.position) <= settings.KeepRadius then
		noteRapport(owner, stage, true)
	end
	robot.model:SetAttribute("Flicker", (phase == "Siren" and owner ~= nil) or nil)
	if mode ~= "doorway" then
		robot.model:SetAttribute("HeadTilt", nil)
		pal.tilting = false
	end
	if mode ~= "build" and pal.job then
		dropJob(pal)
	end
	if mode ~= "beside" then
		pal.scavenge = nil
		if Robots.carried(robot) then
			Robots.letGo(robot, robot.position + robot.facing * 3)
		end
	end
	if ownerAlive then
		local last = pal.ownerLastPosition
		if not last or flatDistance(last, ownerAlive.position) > 0.5 then
			pal.ownerLastPosition = ownerAlive.position
			pal.ownerStillSince = now
		end
	end

	local order: Robots.Order = { pose = "idle" }
	if mode == "down" then
		return
	elseif mode == "doorway" then
		order = doorwayStep(pal, now)
	elseif mode == "home" then
		order = if flatDistance(robot.home, robot.position) > settings.ArriveSlack
			then { goal = robot.home, pose = "walk" }
			else { pose = "idle" }
	elseif mode == "night" then
		order = nightStep(pal, ownerAlive or nil, now)
	elseif mode == "build" and pal.crew then
		-- builds by day whether or not you're around to watch
		guard(pal, now)
		order = tug(pal, dt) or buildStep(pal, pal.crew, now)
	elseif mode == "wait" or not ownerAlive then
		order = { pose = "idle" } -- its owner left or is down: it waits where it is
	elseif mode == "trail" then
		order = keepNear(pal, ownerAlive, settings.TrailDistance, "offer")
	elseif mode == "beside" then
		order = besideStep(pal, ownerAlive, now)
	elseif mode == "follow" then
		guard(pal, now)
		order = tug(pal, dt) or keepNear(pal, ownerAlive, settings.FollowDistance, "idle")
	end
	if not pal.task then
		order = wary(pal, now) or order
	end
	if robot.brain.companion then
		Robots.drive(robot, order)
	end
end

-- Prompts ----------------------------------------------------------------------------------------

local function prompt(
	anchor: Part,
	name: string,
	action: string,
	hold: number,
	reach: number
): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.Name = name
	made.ActionText = action
	made.ObjectText = "Robot"
	made.HoldDuration = hold
	made.MaxActivationDistance = reach
	made.RequiresLineOfSight = false
	made.Parent = anchor
	return made
end

local function onHoldBegan(pal: Pal, made: ProximityPrompt, player: Player)
	pal.holds[made][player.UserId] = { began = os.clock() }
end

local function onHoldEnded(pal: Pal, made: ProximityPrompt, player: Player)
	local hold = pal.holds[made][player.UserId]
	if hold and not hold.ended then
		hold.ended = os.clock()
	end
end

-- Server-side checks before a prompt counts: the hold really lasted (timed here, not trusted from
-- the client), and the player is alive, uncuffed, empty-handed and still within reach.
local function canUse(pal: Pal, made: ProximityPrompt, player: Player, reach: number): boolean
	local hold = pal.holds[made][player.UserId]
	pal.holds[made][player.UserId] = nil
	if not hold or (hold.ended or os.clock()) - hold.began < made.HoldDuration - settings.HoldSlack then
		return false
	end
	if player:GetAttribute("Cuffed") == true or Grab.isCarrying(player) then
		return false
	end
	local alive = aliveOf(player)
	return alive ~= nil and flatDistance(alive.position, pal.robot.position) <= reach + settings.ArriveSlack
end

local REFUSALS: { [RobotTrust.Refusal]: string } = {
	day = "It needs time. Come back tomorrow.",
	full = "It already trusts you all it can.",
	given = "It already has that from you today.",
}

local function onGive(pal: Pal, player: Player)
	local wants = pal.wants
	if not wants or Robots.isDown(pal.robot) or not pal.robot.brain.companion then
		return
	end
	if not canUse(pal, pal.give, player, settings.GiveReach) then
		return
	end
	if not Inventory.has(player, wants) then
		Saves.tell(player, `It wants {itemName(wants)}.`)
		return
	end
	if shuns(pal, player.UserId) then
		Saves.tell(player, "It won't take anything from you today.")
		return
	end
	local record = recordFor(pal, player)
	local day = DayNight.day()
	local refusal = RobotTrust.giftRefusal(record, wants, day, trustSettings)
	if refusal then
		Saves.tell(player, REFUSALS[refusal] or REFUSALS.full)
		return
	end
	if Inventory.remove(player, wants, 1) < 1 then
		return
	end
	if not rapportUsed[player.UserId] then
		-- a bonded rapport from an earlier server: the first gift here starts from watching
		rapportUsed[player.UserId] = true
		RobotTrust.headStart(record, RobotTrust.startTrust(savedRapport(player), trustSettings))
	end
	RobotTrust.gift(record, wants, day, trustSettings)
	pal.lastGift[player.UserId] = wants
	pal.wants = RobotTrust.nextWant(wantsList, wants, 0)
	happy(pal.robot)
	say(pal, voice.Gift)
end

local function repairItem(player: Player): { id: string, count: number }?
	for _, item in settings.RepairItems do
		if Inventory.has(player, item.id, item.count) then
			return item
		end
	end
	return nil
end

local function onRepair(pal: Pal, player: Player)
	if not Robots.isDown(pal.robot) or not pal.robot.brain.companion then
		return
	end
	if not canUse(pal, pal.repair, player, settings.RepairReach) then
		return
	end
	local item = repairItem(player)
	if not item then
		Saves.tell(player, "It needs a battery, or a handful of blaster cells.")
		return
	end
	if Inventory.remove(player, item.id, item.count) < item.count then
		return
	end
	pal.repaired = true
	Robots.standUp(pal.robot)
	play(pal.robot, sounds.Repair)
	if shuns(pal, player.UserId) then
		return -- fixed, but no trust from it today
	end
	local knockedItDown = userIdOf(pal.downBy) == player.UserId
	local added = RobotTrust.repair(recordFor(pal, player), DayNight.day(), knockedItDown, trustSettings)
	if added > 0 then
		happy(pal.robot)
	end
end

local function onBuild(pal: Pal, player: Player)
	if player.UserId ~= pal.ownerId or ownerStage(pal) ~= "bonded" then
		return
	end
	if Robots.isDown(pal.robot) or not pal.robot.brain.companion then
		return
	end
	if not canUse(pal, pal.buildPrompt, player, settings.GiveReach) then
		return
	end
	local alive = aliveOf(player) :: Alive
	local now = os.clock()
	local last = foundAt[player.UserId]
	if last and now - last < build.FoundCooldown then
		Saves.tell(player, "Give it a moment.")
		return
	end
	if placedToday(player.UserId) >= build.MaxPieces then
		Saves.tell(player, "It's built all it can today. It'll still fix what it built.")
		return
	end
	-- find the new spot first: a bad spot keeps the fort it's on and doesn't spend the cooldown
	local crew = SimForts.found(alive.position, alive.look, player.UserId)
	if not crew then
		Saves.tell(player, "No room for a fort here. Try somewhere with a wall to build against.")
		return
	end
	foundAt[player.UserId] = now
	leaveCrew(pal)
	SimForts.join(crew, pal)
	pal.crew = crew
	pal.crewPeak = 0
	pal.fortAt = 0
	pal.nextPickAt = 0
	happy(pal.robot)
	say(pal, voice.BuildStart)
	Saves.tell(
		player,
		if DayNight.phase() == "Day" then "It starts building." else "It'll build here at first light."
	)
end

-- Curious robots ---------------------------------------------------------------------------------

local function makePal(robot: Robot): Pal
	local anchor = Instance.new("Part")
	anchor.Name = `Companion{robot.id}`
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(robot.position + Vector3.yAxis * 4)
	anchor:SetAttribute("RobotId", robot.id)
	anchor.Parent = folder
	CollectionService:AddTag(anchor, "CompanionAnchor")
	wantOffset += 1
	local pal: Pal = {
		robot = robot,
		records = {},
		owner = nil,
		ownerId = nil,
		ownerAwaySince = nil,
		ownerLeftAt = nil,
		lockedUntil = 0,
		wants = RobotTrust.nextWant(wantsList, nil, DayNight.day() + wantOffset),
		shownStage = nil,
		mode = "doorway",
		downBy = nil,
		downSince = nil,
		repaired = false,
		homeUntil = 0,
		shotLossAt = {},
		shunned = {},
		waryAt = 0,
		nightResult = nil,
		lastGift = {},
		scavenge = nil,
		nextScavengeAt = 0,
		skipped = {},
		ownerStillSince = 0,
		ownerLastPosition = nil,
		alarmAt = 0,
		guardAt = 0,
		fortSpot = nil,
		fortPieces = 0,
		fortAt = 0,
		crew = nil,
		job = nil,
		leg = nil,
		task = nil,
		taskUntil = 0,
		nextPickAt = 0,
		crewPeak = 0,
		playerRefusals = 0,
		lessons = {},
		noticedAt = 0,
		tilting = false,
		scoutAt = 0,
		loading = {},
		recheckAt = 0,
		outside = false,
		triedBoth = false,
		speaking = nil,
		voiceAt = 0,
		holds = {},
		anchorAt = nil,
		anchor = anchor,
		give = prompt(anchor, "Give", "Give", settings.GiveHold, settings.GiveReach),
		repair = prompt(anchor, "Repair", "Repair", settings.RepairHold, settings.RepairReach),
		buildPrompt = prompt(anchor, "Build", "Build here", settings.BuildHold, settings.GiveReach),
	}
	pal.repair.Enabled = false
	pal.buildPrompt.KeyboardKeyCode = Enum.KeyCode.F
	pal.buildPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	pal.buildPrompt.UIOffset = Vector2.new(0, 60)
	pal.give.Triggered:Connect(function(player)
		onGive(pal, player)
	end)
	pal.repair.Triggered:Connect(function(player)
		onRepair(pal, player)
	end)
	pal.buildPrompt.Triggered:Connect(function(player)
		onBuild(pal, player)
	end)
	for _, made in { pal.give, pal.repair, pal.buildPrompt } do
		pal.holds[made] = {}
		made.PromptButtonHoldBegan:Connect(function(player)
			onHoldBegan(pal, made, player)
		end)
		made.PromptButtonHoldEnded:Connect(function(player)
			onHoldEnded(pal, made, player)
		end)
	end
	pals[robot] = pal
	Robots.befriend(robot)
	Robots.keep(robot, true)
	return pal
end

local function removePal(pal: Pal)
	local robot = pal.robot
	setOwner(pal, nil, false, os.clock())
	pals[robot] = nil
	pal.anchor:Destroy()
	Robots.keep(robot, false)
	if not robot.dead then
		robot.model:SetAttribute("HeadTilt", nil)
		robot.model:SetAttribute("Flicker", nil)
		Robots.release(robot)
	end
end

-- Worth keeping into a new day: it's owned, or someone here has started on it.
local function courted(pal: Pal): boolean
	if pal.owner then
		return true
	end
	for userId, record in pal.records do
		if record.trust > 0 and Players:GetPlayerByUserId(userId) then
			return true
		end
	end
	return false
end

local function fillCurious()
	local unowned = 0
	for _, pal in pals do
		if not pal.owner then
			unowned += 1
		end
	end
	if unowned >= settings.CuriousPerServer then
		return
	end
	local pool = Robots.choreBots()
	for i = #pool, 2, -1 do
		local j = random:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for _, robot in pool do
		if unowned >= settings.CuriousPerServer then
			break
		end
		if not pals[robot] then
			makePal(robot)
			unowned += 1
		end
	end
end

local function onDawn()
	local day = DayNight.day()
	for _, pal in table.clone(pals) do
		local owner = pal.owner
		local record = owner and pal.records[owner.UserId]
		if pal.nightResult == "taken" and owner then
			-- back from the pack, still recoverable
			loseStage(pal, owner.UserId)
		elseif pal.nightResult == "kept" and owner and record and aliveOf(owner) then
			record.survivedNight = true
			local alive = aliveOf(owner) :: Alive
			pal.fortAt = 0
			refreshFort(pal, os.clock())
			local together = flatDistance(alive.position, pal.robot.position) <= settings.KeepRadius
			if (together or hiddenInFort(pal)) and not shuns(pal, owner.UserId) then
				RobotTrust.hide(record, day, trustSettings)
			end
		end
		if not courted(pal) then
			removePal(pal)
		else
			pal.wants = RobotTrust.nextWant(wantsList, pal.wants, day)
			if pal.crew then
				SimForts.audit(pal.crew)
				pal.crew.idle = false
			end
		end
	end
	repickAt = 0
end

local function onPhaseChanged(phase: string, previous: string)
	if phase == "Siren" then
		for _, pal in pals do
			pal.nightResult = nil
		end
	elseif phase == "Night" then
		for _, pal in pals do
			if pal.owner then
				pal.nightResult = "kept"
			end
			dropJob(pal)
		end
	elseif phase == "Day" and previous == "Night" then
		onDawn()
	end
end

-- Hooks --------------------------------------------------------------------------------------------

local function onShot(robot: Robot, shooter: any, knockedDown: boolean)
	local pal = pals[robot]
	if not pal then
		return
	end
	if knockedDown then
		-- recorded even for a pack hunter, so whoever downed it can't repair it for trust
		pal.downBy = shooter
		pal.repaired = false
	end
	if not robot.brain.companion then
		return -- a robot hunting you with the pack can be shot back at no cost
	end
	local now = os.clock()
	local shooterId = userIdOf(shooter)
	if shooterId then
		pal.shunned[shooterId] = DayNight.day()
		local last = pal.shotLossAt[shooterId]
		if pal.records[shooterId] and (not last or now - last >= settings.StageLossCooldown) then
			pal.shotLossAt[shooterId] = now
			loseStage(pal, shooterId)
			play(robot, sounds.Sad)
		end
	end
	if knockedDown then
		dropJob(pal)
		pal.scavenge = nil
		Robots.keepDown(robot, settings.DownSeconds)
		say(pal, voice.Down)
	end
end

local function onPlaced(player: Player, prop: PVInstance)
	local at = prop:GetPivot().Position
	for _, pal in pals do
		if pal.records[player.UserId] and flatDistance(at, pal.robot.position) <= settings.TeachRadius then
			pal.lessons[prop] = { by = player.UserId, at = os.clock(), position = at }
		end
	end
end

local function refreshAlive()
	table.clear(aliveList)
	table.clear(aliveNow)
	for _, player in Players:GetPlayers() do
		local alive = aliveOf(player)
		if alive then
			table.insert(aliveList, alive)
			aliveNow[player] = alive
		end
	end
end

-- Players gone longer than LeftHoldSeconds are let go (decayAll drops their records once leftAt
-- does), along with build limits from earlier days and spent cooldowns.
local function forgetOld(now: number)
	for userId, gone in leftAt do
		if now - gone >= settings.LeftHoldSeconds then
			leftAt[userId] = nil
			rapportUsed[userId] = nil
		end
	end
	local day = DayNight.day()
	for userId, entry in builtToday do
		if entry.day ~= day then
			builtToday[userId] = nil
		end
	end
	for userId, at in foundAt do
		if now - at >= build.FoundCooldown then
			foundAt[userId] = nil
		end
	end
end

-- Public -------------------------------------------------------------------------------------------

-- The player's robot made it through last night with them (for the Dawn Report).
function Companion.madeIt(player: Player): boolean
	for robot, pal in pals do
		if pal.ownerId == player.UserId and pal.nightResult == "kept" and not robot.dead then
			return true
		end
	end
	return false
end

function Companion.Init()
	folder = Instance.new("Folder")
	folder.Name = "Companions"
	folder.Parent = workspace
end

function Companion.Start()
	if not settings.Enabled or not Config.Robots.Enabled then
		return
	end
	for _, entry in Config.Supplies.Loot do
		itemModels[entry.item] = entry.model
	end
	for _, id in settings.Wants do
		if Inventory.Items[id] and itemModels[id] then
			table.insert(wantsList, id)
		else
			warn(`[Companion] wanted item {id} isn't a known item with a world model`)
		end
	end
	Robots.onShot(onShot)
	Grab.onPlaced(onPlaced)
	DayNight.onPhaseChanged(onPhaseChanged)
	Players.PlayerRemoving:Connect(function(player)
		local current = Players:GetPlayerByUserId(player.UserId)
		if current and current ~= player then
			return
		end
		leftAt[player.UserId] = os.clock()
		for _, pal in pals do
			if pal.ownerId == player.UserId then
				dropJob(pal)
				pal.scavenge = nil
				Robots.letGo(pal.robot, pal.robot.position)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		leftAt[player.UserId] = nil
		for _, pal in pals do
			if pal.ownerId == player.UserId then
				-- back within LeftHoldSeconds: the robot is still theirs
				pal.owner = player
				pal.ownerLeftAt, pal.ownerAwaySince = nil, nil
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		for robot, pal in pals do
			local at = robot.position
			if not robot.dead and (not pal.anchorAt or (at - pal.anchorAt).Magnitude > 0.05) then
				pal.anchorAt = at
				pal.anchor.CFrame = CFrame.new(at + Vector3.yAxis * 4)
			end
		end
	end)
	task.spawn(function()
		local interval = 1 / settings.TickRate
		while true do
			local dt = task.wait(interval)
			local now = os.clock()
			-- One error anywhere in a tick must never stop the loop for the rest of the server
			local tickOk, tickProblem = pcall(function()
				refreshAlive()
				forgetOld(now)
				for robot, pal in table.clone(pals) do
					if robot.dead then
						removePal(pal)
					else
						local ok, problem = pcall(stepPal, pal, dt, now)
						if not ok then
							warn(`[Companion] {problem}`)
						end
					end
				end
				if DayNight.phase() == "Day" and now >= repickAt then
					repickAt = now + settings.RepickEvery
					fillCurious()
				end
			end)
			if not tickOk then
				warn(`[Companion] tick: {tickProblem}`)
			end
		end
	end)
end

return Companion
