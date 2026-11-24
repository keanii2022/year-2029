-- Keeps the warehouse busy round this player, locally and only nearby: boxes tumbling off racks a few
-- aisles over, a cart rolling across an aisle end by itself, footsteps that aren't yours, far clangs
-- and slams, machines flickering, cheerful-wrong PA lines by day, and a room tone that swells in the
-- open. The server sends aisle spots near us (Net "LifeSpots"); events land 25-90 studs off, mostly
-- out of sight. Anything missing from the manifest stays silent or falls back to a plain part.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HauntSight = require(ReplicatedStorage.Shared.Logic.HauntSight)
local LifeSchedule = require(ReplicatedStorage.Shared.Logic.LifeSchedule)
local LifeSpots = require(ReplicatedStorage.Shared.Logic.LifeSpots)
local Manifest = require(ReplicatedStorage.Shared.Logic.Manifest)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)
local Music = require(script.Parent.Music)

local Settings = Config.Life
local Sounds = Settings.Sounds
local Volume = Settings.Volume
local FLOOR_Y = Config.Warehouse.Origin.Y
local CHIME_LEAD = 1.5 -- the chime rings out before the subtitle and voice

local Life = {}

local player = Players.LocalPlayer
local random = Random.new()
local spots: { LifeSpots.Spot } = {}
local machines: { [Model]: boolean } = {}
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

local HANDLERS: { [string]: (LifeSpots.Spot, any) -> PVInstance? } = {
	box_fall = dropBox,
	cart_roll = rollCart,
	footsteps = footsteps,
}

local function runEvent(name: string)
	local event = Settings.Events[name]
	local root = rootPart()
	if not root or live >= Settings.MaxLive then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local viewer = { x = root.Position.X, z = root.Position.Z, lookX = look.X, lookZ = look.Z }
	local spot = LifeSpots.choose(spots, viewer, event.kind, Settings, roll)
	if not spot then
		return
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

local function watchMachines()
	local warehouse = workspace:WaitForChild("Warehouse")
	local function add(instance: Instance)
		if instance:IsA("Model") and Settings.Machines[instance.Name] then
			machines[instance] = true
		end
	end
	for _, instance in warehouse:GetDescendants() do
		add(instance)
	end
	warehouse.DescendantAdded:Connect(add)
	warehouse.DescendantRemoving:Connect(function(instance)
		machines[instance :: Model] = nil
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
	watchMachines()
	while true do
		task.wait(random:NextNumber(Settings.MachineGap.Min, Settings.MachineGap.Max))
		flickerMachine()
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
			Hints.flash("life_pa", Settings.PaPrefix .. line.text, Settings.PaSubtitleSeconds)
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
	task.spawn(eventLoop)
	task.spawn(machineLoop)
	task.spawn(paLoop)
	task.spawn(roomToneLoop)
end

return Life
