-- Keeps the warehouse busy round this player, locally and only nearby: boxes tumbling off racks a few
-- aisles over, a cart rolling across an aisle end by itself, footsteps that aren't yours, far clangs
-- and slams, machines flickering, cheerful-wrong PA lines by day, and a room tone that swells in the
-- open. Rarer moments too: a strip dying overhead, a robot shape crossing a far aisle end, drips into
-- a puddle, a vending machine dropping a can, pigeons bursting off a rack, a rat darting under one,
-- a far phone that stops when you get close. Always on near the camera: signs swaying on their
-- cables, dust under lit strips, moths round a light. The server sends aisle spots near us (Net
-- "LifeSpots"). Anything missing from the manifest stays silent or falls back to a plain part.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HauntSight = require(ReplicatedStorage.Shared.Logic.HauntSight)
local LifeMoments = require(ReplicatedStorage.Shared.Logic.LifeMoments)
local LifeSchedule = require(ReplicatedStorage.Shared.Logic.LifeSchedule)
local LifeSpots = require(ReplicatedStorage.Shared.Logic.LifeSpots)
local Manifest = require(ReplicatedStorage.Shared.Logic.Manifest)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Music = require(script.Parent.Music)
local Subtitles = require(script.Parent.Subtitles)

local Settings = Config.Life
local Sounds = Settings.Sounds
local Volume = Settings.Volume
local FLOOR_Y = Config.Warehouse.Origin.Y
local RACK_TOP = FLOOR_Y + Config.Warehouse.RackHeight
local CHIME_LEAD = 1.5 -- the chime rings out before the subtitle and voice
local LIGHT_TAG = "WarehouseLight" -- same tags the Lighting controller drives
local FLICKER_TAG = "FlickerLight"

local Life = {}

local player = Players.LocalPlayer
local random = Random.new()
local spots: { LifeSpots.Spot } = {}
local machines: { [Model]: boolean } = {}
local wetPatches: { [BasePart]: boolean } = {}
local signs: { [PVInstance]: number } = {} -- sign -> how far it sways, degrees
local dyingStrips: { [BasePart]: boolean } = {}
local live = 0
local fx: Folder

local function roll(): number
	return random:NextNumber()
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

local function phase(): string
	return ReplicatedStorage:GetAttribute("Phase") or "Day"
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function seen(position: Vector3): boolean
	local cam = workspace.CurrentCamera
	return HauntSight.inView(cam.CFrame.Position, cam.CFrame.LookVector, position, cam.FieldOfView * 0.6, 500)
end

-- Sounds ------------------------------------------------------------------------------------------

local function makeSound(parent: Instance, name: string, volume: number, looped: boolean): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.RollOffMinDistance = Settings.RollOff.Min
	sound.RollOffMaxDistance = Settings.RollOff.Max
	sound.Parent = parent
	return sound
end

local function playOnce(sound: Sound?)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

local function holderAt(position: Vector3): Part
	local holder = Instance.new("Part")
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Position = position
	holder.Parent = fx
	return holder
end

local function playAt(position: Vector3, name: string, volume: number)
	local holder = holderAt(position)
	playOnce(makeSound(holder, name, volume, false))
	task.delay(15, function()
		holder:Destroy()
	end)
end

-- A sound at a different speed, cut off after `seconds`.
local function playClipAt(position: Vector3, name: string, volume: number, speed: number, seconds: number)
	local holder = holderAt(position)
	local sound = makeSound(holder, name, volume, false)
	if sound then
		sound.PlaybackSpeed = speed
		sound:Play()
	end
	task.delay(seconds, function()
		holder:Destroy()
	end)
end

local function playFlat(name: string, volume: number)
	playOnce(makeSound(SoundService, name, volume, false))
end

-- Props -------------------------------------------------------------------------------------------

-- The server's uploaded copy when it published one, else the greybox, else nil.
local function prop(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("LifeProps")
	local template = folder and folder:FindFirstChild(name)
	if template then
		return (template :: Model):Clone()
	end
	if ModelLibrary.entry(name) then
		return ModelLibrary.get(name)
	end
	return nil
end

-- Visual only: never collides, never in the way of rays, clicks or touches.
local function ghost(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
end

-- How far a model's pivot sits above its lowest point, to stand it on the floor.
local function footLift(model: Model): number
	local box, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
end

local function cardboardBlock(): Part
	local box = Instance.new("Part")
	box.Name = "LooseBox"
	box.Size = Settings.BoxSize
	box.Color = Settings.BoxColor
	box.Material = Enum.Material.Cardboard
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	return box
end

-- One physics body: every part welded to the root and let go.
local function looseBox(): (PVInstance, BasePart)
	local model = prop(Settings.BoxModel)
	local body = model and model.PrimaryPart
	if model and body then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				if part ~= body then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = part
					weld.Parent = part
				end
				part.Anchored = false
			end
		end
		return model, body
	end
	if model then
		model:Destroy()
	end
	local block = cardboardBlock()
	return block, block
end

-- Live effects ------------------------------------------------------------------------------------

-- Leaves an effect up for Lifetime, then removes it the first moment nobody's looking at it.
local function retire(instance: PVInstance)
	task.delay(Settings.Lifetime, function()
		while instance.Parent and seen(instance:GetPivot().Position) do
			task.wait(3)
		end
		instance:Destroy()
		live -= 1
	end)
end

local function viewerAt(root: BasePart): LifeSpots.Viewer
	local look = workspace.CurrentCamera.CFrame.LookVector
	return { x = root.Position.X, z = root.Position.Z, lookX = look.X, lookZ = look.Z }
end

local function floorAt(spot: LifeSpots.Spot): Vector3
	return Vector3.new(spot.x, FLOOR_Y, spot.z)
end

local function directionOf(spot: LifeSpots.Spot): Vector3
	return Vector3.new(spot.dx, 0, spot.dz)
end

local function dropBox(spot: LifeSpots.Spot): PVInstance?
	local out = directionOf(spot)
	local from = floorAt(spot)
		- out * Settings.AisleOffset
		+ Vector3.yAxis * (pick(Settings.BoxDropHeights) + 1)
	playAt(from, Sounds.BoxScrape, Volume.Event * 0.6)
	task.wait(0.4)
	local box, body = looseBox()
	box:PivotTo(CFrame.new(from) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	box.Parent = fx
	body.AssemblyLinearVelocity = out * between(Settings.BoxPush) + Vector3.yAxis
	body.AssemblyAngularVelocity =
		Vector3.new(random:NextNumber(-3, 3), random:NextNumber(-3, 3), random:NextNumber(-3, 3))
	-- It brushes the rack on the way out, so only a touch after a real fall counts as the landing.
	local droppedAt = os.clock()
	local landing
	landing = body.Touched:Connect(function(hit: BasePart)
		if os.clock() - droppedAt > 0.3 and not hit:IsDescendantOf(box) then
			landing:Disconnect()
			playAt(body.Position, Sounds.BoxThump, Volume.Event)
		end
	end)
	task.delay(5, function()
		landing:Disconnect()
	end)
	return box
end

local function rollCart(spot: LifeSpots.Spot): PVInstance?
	local cart = prop(Settings.CartModel)
	if not cart then
		return nil
	end
	local across = directionOf(spot)
	local distance, seconds = Settings.CartRoll.Distance, Settings.CartRoll.Seconds
	local start = floorAt(spot) - across * distance / 2
	for _, part in cart:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	cart:PivotTo(CFrame.lookAt(start, start + across))
	local box, size = cart:GetBoundingBox()
	local base = cart:GetPivot() + Vector3.yAxis * (FLOOR_Y - (box.Position.Y - size.Y / 2))
	cart:PivotTo(base)
	cart.Parent = fx

	local rolling = makeSound(
		cart.PrimaryPart or cart:FindFirstChildWhichIsA("BasePart", true) or fx,
		Sounds.CartRoll,
		Volume.Event * 0.7,
		true
	)
	if rolling then
		rolling:Play()
	end
	local started = os.clock()
	while true do
		local t = math.min((os.clock() - started) / seconds, 1)
		local eased = 1 - (1 - t) ^ 2 -- slows to a stop like it ran out of push
		cart:PivotTo(base + across * distance * eased)
		if rolling then
			rolling.Volume = Volume.Event * 0.7 * (1 - eased)
		end
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if rolling then
		rolling:Destroy()
	end
	return cart
end

-- Someone walking along the aisle, then stopping.
local function footsteps(spot: LifeSpots.Spot): PVInstance?
	local walk = if roll() < 0.5 then Vector3.xAxis else -Vector3.xAxis
	local holder = holderAt(floorAt(spot) + Vector3.yAxis * 0.5)
	local steps = random:NextInteger(Settings.Footsteps.Count[1], Settings.Footsteps.Count[2])
	for _ = 1, steps do
		local step = makeSound(holder, Sounds.Step, Volume.Step * random:NextNumber(0.8, 1), false)
		if not step then
			break
		end
		step.PlaybackSpeed = random:NextNumber(0.9, 1.05)
		playOnce(step)
		holder.Position += walk * Settings.Footsteps.Stride
		task.wait(Settings.Footsteps.Every * random:NextNumber(0.85, 1.15))
	end
	task.wait(2)
	holder:Destroy()
	return nil
end

local function farSound(spot: LifeSpots.Spot, event: any): PVInstance?
	playAt(floorAt(spot) + Vector3.yAxis * random:NextNumber(2, 10), pick(event.sounds), Volume.Event)
	return nil
end

-- Waits up to `seconds`, ending early (true) once stop() says so.
local function waitUnless(seconds: number, stop: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if stop() then
			return true
		end
		task.wait(0.1)
	end
	return stop()
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- A far phone ringing; it goes quiet the moment you get close, as if someone picked up.
local function phone(spot: LifeSpots.Spot): PVInstance?
	local settings = Settings.Phone
	local position = floorAt(spot) + Vector3.yAxis * 3
	local function close(): boolean
		local root = rootPart()
		return root ~= nil and (root.Position - position).Magnitude <= settings.StopRadius
	end
	if close() then
		return nil
	end
	local holder = holderAt(position)
	for _ = 1, random:NextInteger(settings.Rings[1], settings.Rings[2]) do
		local ring = makeSound(holder, Sounds.Phone, Volume.Event, false)
		if not ring then
			break
		end
		local ended = false
		ring.Ended:Once(function()
			ended = true
		end)
		ring:Play()
		local stopped = waitUnless(6, function()
			return ended or close()
		end) and not ended
		ring:Destroy()
		if stopped or waitUnless(settings.Pause, close) then
			break
		end
	end
	holder:Destroy()
	return nil
end

-- One long slowed-down scrape that slides along the aisle, like a rack being dragged.
local function shelfDrag(spot: LifeSpots.Spot, event: any): PVInstance?
	local settings = Settings.ShelfDrag
	local along = Vector3.new(-spot.dz, 0, spot.dx) * (if roll() < 0.5 then 1 else -1)
	local holder = holderAt(floorAt(spot) + Vector3.yAxis * 2)
	local sound = makeSound(holder, pick(event.sounds), Volume.Event, false)
	if not sound then
		holder:Destroy()
		return nil
	end
	sound.PlaybackSpeed = between(settings.Speed)
	sound:Play()
	local seconds = if sound.TimeLength > 0 then sound.TimeLength / sound.PlaybackSpeed else 4
	TweenService:Create(
		holder,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Position = holder.Position + along * settings.Slide }
	):Play()
	task.wait(seconds + 1)
	holder:Destroy()
	return nil
end

-- Flat gap from a part's footprint, 0 when standing right under it.
local function gapUnder(part: BasePart, position: Vector3): number
	local offset = part.CFrame:PointToObjectSpace(position)
	local dx = math.max(math.abs(offset.X) - part.Size.X / 2, 0)
	local dz = math.max(math.abs(offset.Z) - part.Size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function stripOverhead(radius: number): BasePart?
	local root = rootPart()
	if not root then
		return nil
	end
	local best, bestGap = nil, radius
	for _, strip in CollectionService:GetTagged(LIGHT_TAG) do
		if
			strip:IsA("BasePart")
			and strip.Material == Enum.Material.Neon
			and not dyingStrips[strip]
			and strip:GetAttribute("Emergency") ~= true
			and not CollectionService:HasTag(strip, FLICKER_TAG)
		then
			local gap = gapUnder(strip, root.Position)
			if gap <= bestGap then
				best, bestGap = strip, gap
			end
		end
	end
	return best
end

-- Waits for the player to walk under a working strip, which stutters and dies, then comes back later.
-- Lighting owns the strips: if it has set this one since (phase change), it's left alone.
local function stripDie(): PVInstance?
	local settings = Settings.StripDie
	local strip: BasePart?
	waitUnless(settings.Wait, function()
		strip = stripOverhead(settings.Radius)
		return strip ~= nil
	end)
	if not strip then
		return nil
	end
	local target = strip :: BasePart
	dyingStrips[target] = true
	local glow = target:FindFirstChildOfClass("SurfaceLight")
	local litMaterial, litColor = target.Material, target.Color
	local glowWasOn = glow ~= nil and glow.Enabled
	local function set(lit: boolean)
		target.Material = if lit then litMaterial else Enum.Material.SmoothPlastic
		target.Color = if lit then litColor else settings.DeadColor
		if glow then
			glow.Enabled = lit and glowWasOn
		end
	end
	playAt(target.Position, Sounds.StripCrackle, Volume.Machine)
	for _, blink in LifeSchedule.flicker(settings.Flicker, roll) do
		set(blink.lit)
		task.wait(blink.seconds)
	end
	set(false)
	task.delay(between(settings.Dark), function()
		dyingStrips[target] = nil
		local stillOurs = target.Parent ~= nil
			and target.Material == Enum.Material.SmoothPlastic
			and target.Color:ToHex() == settings.DeadColor:ToHex()
		if not stillOurs then
			return
		end
		if phase() == "Night" then
			target.Color = Config.DayNight.DeadStripColor -- what Lighting leaves a plain strip at night
		else
			set(true)
		end
	end)
	return nil
end

-- A dark robot shape walking across the far end of the aisle you're looking down, then gone.
local function silhouette(): PVInstance?
	local settings = Settings.Silhouette
	local root = rootPart()
	if not root then
		return nil
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.5 then
		return nil -- looking up or down, not along an aisle
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, fx }
	local reach = settings.Far + settings.Margin
	local hit = workspace:Raycast(root.Position, flat * reach, params)
	local distance = LifeMoments.glimpseDistance(if hit then hit.Distance else reach, settings)
	if not distance then
		return nil
	end
	local figure = prop(settings.Model)
	if not figure then
		return nil
	end
	for _, part in figure:GetDescendants() do
		if part:IsA("BasePart") then
			local eye = Manifest.isGlow(part.Name) or Manifest.isScreen(part.Name)
			part.Color = if eye then settings.EyeColor else settings.Color
			part.Material = if eye then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	ghost(figure)
	local across = flat:Cross(Vector3.yAxis) * (if roll() < 0.5 then 1 else -1)
	local start = Vector3.new(root.Position.X, FLOOR_Y, root.Position.Z)
		+ flat * distance
		- across * settings.Width / 2
	-- Models face +z, so look away from the way it walks.
	figure:PivotTo(CFrame.lookAt(start, start - across))
	local base = figure:GetPivot() + Vector3.yAxis * footLift(figure)
	figure:PivotTo(base)
	figure.Parent = fx
	local seconds = between(settings.Seconds)
	local started = os.clock()
	while true do
		local t = math.min((os.clock() - started) / seconds, 1)
		figure:PivotTo(base + across * settings.Width * t)
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	figure:Destroy()
	return nil
end

local function ripple(position: Vector3)
	local settings = Settings.Drip
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.02, 0.3, 0.3)
	ring.CFrame = CFrame.new(position + Vector3.yAxis * 0.02) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = settings.Color
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.4
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = fx
	local grow = TweenService:Create(ring, TweenInfo.new(settings.RippleSeconds, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.02, settings.RippleSize, settings.RippleSize),
		Transparency = 1,
	})
	grow.Completed:Once(function()
		ring:Destroy()
	end)
	grow:Play()
end

-- A few drops falling from high up into a wet patch near you, each with a plip and a ripple.
local function drip(): PVInstance?
	local settings = Settings.Drip
	local root = rootPart()
	if not root then
		return nil
	end
	local patches, points = {}, {}
	for patch in wetPatches do
		table.insert(patches, patch)
		table.insert(points, { x = patch.Position.X, z = patch.Position.Z })
	end
	local near = LifeMoments.nearest(
		points,
		root.Position.X,
		root.Position.Z,
		settings.MinDistance,
		settings.MaxDistance,
		3
	)
	if #near == 0 then
		return nil
	end
	local patch = patches[pick(near)]
	local size = patch.Size
	local landing = patch.CFrame
		* Vector3.new(
			random:NextNumber(-0.3, 0.3) * size.X,
			size.Y / 2,
			random:NextNumber(-0.3, 0.3) * size.Z
		)
	local fall = math.sqrt(2 * settings.Height / workspace.Gravity)
	for _ = 1, random:NextInteger(settings.Count[1], settings.Count[2]) do
		local drop = Instance.new("Part")
		drop.Shape = Enum.PartType.Ball
		drop.Size = Vector3.one * 0.18
		drop.Color = settings.Color
		drop.Material = Enum.Material.Glass
		drop.Transparency = 0.3
		drop.Anchored = true
		drop.CanCollide = false
		drop.CanQuery = false
		drop.CanTouch = false
		drop.CastShadow = false
		drop.Position = landing + Vector3.yAxis * settings.Height
		drop.Parent = fx
		TweenService:Create(drop, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = landing,
		}):Play()
		task.wait(fall)
		drop:Destroy()
		playClipAt(landing, Sounds.Drip, Volume.Step, random:NextNumber(2, 2.6), 0.25)
		ripple(landing)
		task.wait(between(settings.Every))
	end
	return nil
end

-- A vending machine near you whirrs and drops a can that rolls out onto the floor.
local function vendingCan(): PVInstance?
	local settings = Settings.VendingCan
	local root = rootPart()
	if not root then
		return nil
	end
	local list, points = {}, {}
	for model in machines do
		if model.Name == "vending_machine" then
			local at = model:GetPivot().Position
			table.insert(list, model)
			table.insert(points, { x = at.X, z = at.Z })
		end
	end
	local nearest = LifeMoments.nearest(
		points,
		root.Position.X,
		root.Position.Z,
		settings.MinDistance,
		settings.MaxDistance,
		1
	)[1]
	if not nearest then
		return nil
	end
	local machine = list[nearest]
	local box, size = machine:GetBoundingBox()
	playAt(box.Position, Sounds.VendingHum, Volume.Machine)
	task.wait(random:NextNumber(1.5, 3))
	if not machine.Parent then
		return nil
	end
	local pivot = machine:GetPivot()
	local front = pivot.ZVector -- models face +z
	local slot = box.Position + front * (size.Z / 2 + 0.4) - Vector3.yAxis * (size.Y / 2 - 0.6)
	local can = Instance.new("Part")
	can.Name = "Can"
	can.Shape = Enum.PartType.Cylinder
	can.Size = settings.Size
	can.Color = pick(settings.Colors)
	can.Material = Enum.Material.Metal
	can.CanQuery = false
	can.CanTouch = false
	-- Lying across the slot, so it rolls straight out.
	can.CFrame = CFrame.fromMatrix(slot, pivot.XVector, Vector3.yAxis)
	can.Parent = fx
	can.AssemblyLinearVelocity = front * settings.Push + pivot.XVector * random:NextNumber(-0.5, 0.5)
	playAt(slot, Sounds.VendingDrop, Volume.Event)
	return can
end

local function viewerSpot(
	kind: string,
	rules: { MinDistance: number, MaxDistance: number, SeenChance: number }
): LifeSpots.Spot?
	local root = rootPart()
	if not root then
		return nil
	end
	return LifeSpots.choose(spots, viewerAt(root), kind, {
		MinDistance = rules.MinDistance,
		MaxDistance = rules.MaxDistance,
		HiddenAngle = Settings.HiddenAngle,
		GlimpseChance = rules.SeenChance,
		GlimpseMinDistance = rules.MinDistance,
	}, roll)
end

type Bird = {
	model: Model,
	wings: { { part: BasePart, offset: CFrame, side: number } },
	from: CFrame,
	to: Vector3,
}

local function burst(birds: { Bird })
	local settings = Settings.Pigeons
	local started = os.clock()
	while true do
		local elapsed = os.clock() - started
		local t = math.min(elapsed / settings.Seconds, 1)
		local eased = 1 - (1 - t) ^ 2
		local flap = math.rad(settings.Flap) * math.sin(elapsed * 30)
		for _, bird in birds do
			local position = bird.from.Position:Lerp(bird.to, eased)
			local heading = Vector3.new(bird.to.X - bird.from.X, 0, bird.to.Z - bird.from.Z)
			local frame = CFrame.lookAt(position, position - heading)
			bird.model:PivotTo(frame)
			for _, wing in bird.wings do
				wing.part.CFrame = frame * wing.offset * CFrame.Angles(0, 0, wing.side * flap)
			end
		end
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Pigeons perched on a rack top a way off. Walk near and they burst up into the dark.
local function pigeons(): PVInstance?
	local settings = Settings.Pigeons
	local spot = viewerSpot("aisle", settings)
	if not spot then
		return nil
	end
	local perch = floorAt(spot) - directionOf(spot) * (Settings.AisleOffset + 1.5) + Vector3.yAxis * RACK_TOP
	if seen(perch) and roll() > settings.SeenChance then
		return nil
	end
	local flock = Instance.new("Model")
	flock.Name = "Pigeons"
	local birds: { Bird } = {}
	for _ = 1, random:NextInteger(settings.Count[1], settings.Count[2]) do
		local model = prop(settings.Model)
		if not model then
			break
		end
		ghost(model)
		local at = perch + Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-0.6, 0.6))
		model:PivotTo(CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
		model:PivotTo(model:GetPivot() + Vector3.yAxis * footLift(model))
		model.Parent = flock
		local from = model:GetPivot()
		local away = random:NextNumber(0, math.pi * 2)
		local bird: Bird = {
			model = model,
			wings = {},
			from = from,
			to = from.Position
				+ Vector3.new(math.cos(away) * 20, between(settings.Rise), math.sin(away) * 20),
		}
		for side, name in { [-1] = "WingL", [1] = "WingR" } do
			local part = model:FindFirstChild(name, true)
			if part and part:IsA("BasePart") then
				table.insert(
					bird.wings,
					{ part = part, offset = from:ToObjectSpace(part.CFrame), side = side }
				)
			end
		end
		table.insert(birds, bird)
	end
	if #birds == 0 then
		flock:Destroy()
		return nil
	end
	flock.Parent = fx
	local came = waitUnless(settings.Wait, function()
		local root = rootPart()
		return root ~= nil and flatDistance(root.Position, perch) <= settings.Burst
	end)
	if came or seen(perch) then
		playClipAt(perch, Sounds.Wings, Volume.Event, 1.6, settings.Seconds)
		burst(birds)
	end
	flock:Destroy()
	return nil
end

-- A rat darting along the foot of a rack, then in under it.
local function rat(): PVInstance?
	local settings = Settings.Rat
	local spot = viewerSpot("aisle", settings)
	if not spot then
		return nil
	end
	local critter = prop(settings.Model)
	if not critter then
		return nil
	end
	ghost(critter)
	local out = directionOf(spot)
	local along = Vector3.new(-out.Z, 0, out.X) * (if roll() < 0.5 then 1 else -1)
	local start = floorAt(spot) - out * (Settings.AisleOffset - 0.4)
	critter:PivotTo(CFrame.lookAt(start, start - along))
	local lift = Vector3.yAxis * footLift(critter)
	critter.Parent = fx
	local turn = start + along * between(settings.Run)
	local legs = { { start, turn, along }, { turn, turn - out * 2.5, -out } }
	for _, leg in legs do
		local from, to, heading = leg[1], leg[2], leg[3]
		local seconds = (to - from).Magnitude / settings.Speed
		local started = os.clock()
		while true do
			local t = math.min((os.clock() - started) / seconds, 1)
			local position = from:Lerp(to, t)
			critter:PivotTo(CFrame.lookAt(position, position - heading) + lift)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end
	critter:Destroy()
	return nil
end

local HANDLERS: { [string]: (any, any) -> PVInstance? } = {
	box_fall = dropBox,
	cart_roll = rollCart,
	footsteps = footsteps,
	phone_ring = phone,
	shelf_drag = shelfDrag,
	strip_die = stripDie,
	silhouette = silhouette,
	drip = drip,
	vending_can = vendingCan,
	pigeons = pigeons,
	rat = rat,
}

local function runEvent(name: string)
	local event = Settings.Events[name]
	local root = rootPart()
	if not root or live >= Settings.MaxLive then
		return
	end
	local spot = nil
	if event.kind then
		spot = LifeSpots.choose(spots, viewerAt(root), event.kind, Settings, roll)
		if not spot then
			return
		end
	end
	live += 1
	task.spawn(function()
		local ok, leftover = pcall(HANDLERS[name] or farSound, spot, event)
		if not ok then
			warn(`[Life] {name}: {leftover}`)
		end
		if ok and leftover then
			retire(leftover)
		else
			live -= 1
		end
	end)
end

local function eventLoop()
	while true do
		task.wait(
			LifeSchedule.gap(Settings.EventGap, Settings.PhaseRate[phase()], roll) or Settings.EventGap.Max
		)
		local name = LifeSchedule.pick(Settings.Events, phase(), roll)
		if name then
			runEvent(name)
		end
	end
end

-- Machines ----------------------------------------------------------------------------------------

local function isAisleSign(instance: Instance): boolean
	local name = instance:GetAttribute("ModelName") or instance.Name
	return instance:IsA("Model") and string.sub(name, 1, 10) == "aisle_sign"
end

-- Streaming brings warehouse parts in and out, so these lists follow it.
local function watchWarehouse()
	local warehouse = workspace:WaitForChild("Warehouse")
	local function add(instance: Instance)
		if instance:IsA("Model") and Settings.Machines[instance.Name] then
			machines[instance] = true
		elseif instance:IsA("BasePart") and instance.Name == "wet" then
			wetPatches[instance] = true
		elseif instance:IsA("BasePart") and instance.Name == "DeptSign" then
			signs[instance] = Settings.Sway.DeptAngle
		elseif isAisleSign(instance) then
			signs[instance :: Model] = Settings.Sway.AisleAngle
		end
	end
	for _, instance in warehouse:GetDescendants() do
		add(instance)
	end
	warehouse.DescendantAdded:Connect(add)
	warehouse.DescendantRemoving:Connect(function(instance)
		machines[instance :: Model] = nil
		wetPatches[instance :: BasePart] = nil
		signs[instance :: PVInstance] = nil
	end)
end

local function flickerMachine()
	local root = rootPart()
	if not root then
		return
	end
	local nearby = {}
	for model in machines do
		if (model:GetPivot().Position - root.Position).Magnitude <= Settings.MachineRadius then
			table.insert(nearby, model)
		end
	end
	if #nearby == 0 then
		return
	end
	local machine = pick(nearby)
	local glows: { [BasePart]: { Color3 | Enum.Material } } = {}
	local lights: { Light } = {}
	for _, instance in machine:GetDescendants() do
		if
			instance:IsA("BasePart") and (Manifest.isScreen(instance.Name) or Manifest.isGlow(instance.Name))
		then
			glows[instance] = { instance.Color, instance.Material }
		elseif instance:IsA("Light") and instance.Enabled then
			table.insert(lights, instance)
		end
	end
	playAt(machine:GetPivot().Position, pick(Settings.Machines[machine.Name]), Volume.Machine)
	for _, blink in LifeSchedule.flicker(Settings.Flicker, roll) do
		for part, saved in glows do
			part.Color = if blink.lit then saved[1] :: Color3 else Settings.MachineDarkColor
			part.Material = if blink.lit then saved[2] :: Enum.Material else Enum.Material.SmoothPlastic
		end
		for _, light in lights do
			light.Enabled = blink.lit
		end
		task.wait(blink.seconds)
	end
end

local function machineLoop()
	while true do
		task.wait(random:NextNumber(Settings.MachineGap.Min, Settings.MachineGap.Max))
		flickerMachine()
	end
end

-- Always on near the camera ------------------------------------------------------------------------

type Swing = {
	hinge: CFrame,
	offset: CFrame,
	motion: { Angle: number, Period: number },
	seed: number,
	roll: boolean,
}

-- Where a sign hangs from: a board's top edge, or the top of an aisle sign's cable.
local function hingeOf(sign: PVInstance): CFrame?
	if sign:IsA("BasePart") then
		return sign.CFrame * CFrame.new(0, sign.Size.Y / 2, 0)
	end
	local cable = sign:FindFirstChild("Cable")
	if cable and cable:IsA("BasePart") then
		return cable.CFrame * CFrame.new(0, cable.Size.Y / 2, 0)
	end
	return nil
end

-- The few signs nearest the camera sway a touch; the rest stay put, and any that drop out of range
-- go back exactly where they were.
local function swayLoop()
	local settings = Settings.Sway
	local swinging: { [PVInstance]: Swing } = {}
	local nextPick = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextPick then
			nextPick = now + settings.Every
			local camera = workspace.CurrentCamera.CFrame.Position
			local list, points = {}, {}
			for sign in signs do
				local at = (swinging[sign] and swinging[sign].hinge or sign:GetPivot()).Position
				table.insert(list, sign)
				table.insert(points, { x = at.X, z = at.Z })
			end
			local keep = {}
			for _, index in LifeMoments.nearest(points, camera.X, camera.Z, 0, settings.Radius, settings.Max) do
				keep[list[index]] = true
			end
			for sign, swing in swinging do
				if not keep[sign] then
					if sign.Parent then
						sign:PivotTo(swing.hinge * swing.offset)
					end
					swinging[sign] = nil
				end
			end
			for sign in keep do
				local hinge = not swinging[sign] and hingeOf(sign)
				if hinge then
					swinging[sign] = {
						hinge = hinge,
						offset = hinge:Inverse() * sign:GetPivot(),
						motion = { Angle = signs[sign], Period = settings.Period },
						seed = random:NextNumber(),
						-- A board on two cables only rocks; one on a single cable can twist too.
						roll = not sign:IsA("BasePart"),
					}
				end
			end
		end
		for sign, swing in swinging do
			if sign.Parent then
				local tilt, twist = LifeMoments.sway(now, swing.seed, swing.motion)
				sign:PivotTo(
					swing.hinge * CFrame.Angles(tilt, 0, if swing.roll then twist else 0) * swing.offset
				)
			else
				swinging[sign] = nil
			end
		end
	end)
end

local function dustUnder(strip: BasePart): Part
	local settings = Settings.Dust
	local holder = holderAt(strip.Position - Vector3.yAxis * settings.Below)
	local long = math.max(strip.Size.X, strip.Size.Z)
	holder.Size = if strip.Size.X >= strip.Size.Z
		then Vector3.new(long, settings.Height, settings.Depth)
		else Vector3.new(settings.Depth, settings.Height, long)
	holder.CFrame = CFrame.new(holder.Position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate = settings.Rate
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Speed = NumberRange.new(0.05, 0.25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -0.03, 0)
	emitter.Drag = 0.5
	emitter.Size = NumberSequence.new(0.1)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(230, 225, 210))
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0.3
	emitter.Parent = holder
	return holder
end

type Moth = { model: Model, radius: number, speed: number, phase: number, lift: number }

local mothStrip: BasePart?
local mothFolder: Folder?
local mothSpin: RBXScriptConnection?

-- A few moths circling just under one working strip near the camera.
local function setMoths(strip: BasePart?)
	if strip == mothStrip then
		return
	end
	if mothSpin then
		mothSpin:Disconnect()
		mothSpin = nil
	end
	if mothFolder then
		mothFolder:Destroy()
		mothFolder = nil
	end
	mothStrip = strip
	if not strip then
		return
	end
	local settings = Settings.Moths
	local folder = Instance.new("Folder")
	folder.Name = "Moths"
	folder.Parent = fx
	mothFolder = folder
	local moths: { Moth } = {}
	for _ = 1, settings.Count do
		local model = prop(settings.Model)
		if not model then
			break
		end
		ghost(model)
		model:ScaleTo(settings.Scale)
		model.Parent = folder
		table.insert(moths, {
			model = model,
			radius = between(settings.Orbit),
			speed = between(settings.Speed) * (if roll() < 0.5 then 1 else -1),
			phase = random:NextNumber(0, math.pi * 2),
			lift = random:NextNumber(-0.5, 0.5),
		})
	end
	local center = strip.Position - Vector3.yAxis * 1.2
	mothSpin = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, moth in moths do
			local angle = moth.phase + t * moth.speed
			local position = center
				+ Vector3.new(
					math.cos(angle) * moth.radius,
					moth.lift + math.sin(t * 5 + moth.phase) * 0.3,
					math.sin(angle) * moth.radius
				)
			local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(moth.speed)
			moth.model:PivotTo(CFrame.lookAt(position, position - heading))
		end
	end)
end

-- Dust under the few lit strips nearest the camera, and moths round the nearest one.
local function lightLoop()
	local dust, mothSettings = Settings.Dust, Settings.Moths
	local dusty: { [BasePart]: Part } = {}
	while true do
		local camera = workspace.CurrentCamera.CFrame.Position
		local lit, points = {}, {}
		for _, strip in CollectionService:GetTagged(LIGHT_TAG) do
			-- Broken strips blink all the time; skipping them keeps the dust from coming and going.
			if
				strip:IsA("BasePart")
				and strip.Material == Enum.Material.Neon
				and not CollectionService:HasTag(strip, FLICKER_TAG)
			then
				table.insert(lit, strip)
				table.insert(points, { x = strip.Position.X, z = strip.Position.Z })
			end
		end
		local nearest = LifeMoments.nearest(points, camera.X, camera.Z, 0, dust.Radius, dust.Max)
		local keep = {}
		for _, index in nearest do
			keep[lit[index]] = true
		end
		for strip, holder in dusty do
			if not keep[strip] then
				holder:Destroy()
				dusty[strip] = nil
			end
		end
		for strip in keep do
			if not dusty[strip] then
				dusty[strip] = dustUnder(strip)
			end
		end
		local first = nearest[1] and lit[nearest[1]]
		local mothsHere = first and flatDistance(first.Position, camera) <= mothSettings.Radius
		setMoths(if mothsHere then first else nil)
		task.wait(1)
	end
end

-- PA ----------------------------------------------------------------------------------------------

local function paLoop()
	local bag = LifeSchedule.newBag()
	while true do
		task.wait(random:NextNumber(Settings.PaGap.Min, Settings.PaGap.Max))
		if phase() == "Day" then
			local line = Settings.PaLines[LifeSchedule.draw(bag, #Settings.PaLines, roll)]
			playFlat(Sounds.Chime, Volume.Chime)
			task.wait(CHIME_LEAD)
			Music.playVoiceLine(line.voice)
			Subtitles.show(Settings.PaPrefix .. line.text, Settings.PaSubtitleSeconds)
			if roll() < Settings.PaGlitchChance then
				task.wait(Settings.PaSubtitleSeconds * 0.6)
				playFlat(Sounds.Glitch, Volume.Chime)
			end
		end
	end
end

-- Room tone ---------------------------------------------------------------------------------------

local function roomToneLoop()
	local settings = Settings.RoomTone
	local tone = makeSound(SoundService, Sounds.RoomTone, 0, true)
	if not tone then
		return
	end
	tone:Play()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local fade = TweenInfo.new(settings.Fade)
	while true do
		local root = rootPart()
		local target = 0
		-- Music plays the same hum at night; this one carries the day.
		if root and phase() ~= "Night" then
			params.FilterDescendantsInstances = { player.Character :: Instance, fx }
			local distances = {}
			for n = 1, settings.Rays do
				local angle = n / settings.Rays * math.pi * 2
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * settings.Far
				local hit = workspace:Raycast(root.Position, direction, params)
				table.insert(distances, if hit then hit.Distance else settings.Far)
			end
			target = LifeSchedule.roomTone(distances, settings)
		end
		TweenService:Create(tone, fade, { Volume = target }):Play()
		task.wait(settings.Every)
	end
end

function Life.Start()
	fx = Instance.new("Folder")
	fx.Name = "LifeFx"
	fx.Parent = workspace
	Net.event("LifeSpots").OnClientEvent:Connect(function(list: { LifeSpots.Spot })
		spots = list
	end)
	task.spawn(function()
		watchWarehouse()
		swayLoop()
		task.spawn(machineLoop)
		eventLoop()
	end)
	task.spawn(lightLoop)
	task.spawn(paLoop)
	task.spawn(roomToneLoop)
end

return Life
