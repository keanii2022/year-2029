-- Night tricks on the server: flashlight battery ("Battery" 0-100 on the player), breath holding
-- while hidden ("Breath", "HoldingBreath"), the area a player is in for room sound ("Area"),
-- generators that light a section and hum for robots, fuel can pickups ("FuelCans"), survivor
-- journals, and the night storm and PA, which every client plays from one server roll.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Body = require(ReplicatedStorage.Shared.Logic.NightTricksBody)
local Config = require(ReplicatedStorage.Shared.Config)
local Generator = require(ReplicatedStorage.Shared.Logic.NightTricksGenerator)
local HauntPlacement = require(ReplicatedStorage.Shared.Logic.HauntPlacement)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local World = require(ReplicatedStorage.Shared.Logic.NightTricksWorld)
local DayNight = require(script.Parent.DayNight)
local Files = require(script.Parent.Files)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local PaEvents = require(script.Parent.PaEvents)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.NightTricks
local Sounds = Settings.Sounds

type Gen = {
	model: Model,
	state: Generator.State,
	lights: { PointLight },
	prompt: ProximityPrompt,
	runSound: Sound?,
	sinceHum: number,
	lastPullAt: number,
}

local NightTricks = {}

local random = Random.new()
local folder: Folder
local fuelFolder: Folder
local breathRemote: RemoteEvent
local noteRemote: RemoteEvent
local loreRemote: RemoteEvent
local stormRemote: RemoteEvent
local paRemote: RemoteEvent
local breaths: { [Player]: Body.Breath } = {}
local generators: { Gen } = {}
local nextLightningAt = math.huge
local nextAnnouncementAt = math.huge

local function roll(): number
	return random:NextNumber()
end

local function tell(player: Player, text: string)
	if player.Parent then
		noteRemote:FireClient(player, text)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- While hidden the body sits inside the furniture; noise comes from the furniture.
local function noisePosition(player: Player): Vector3?
	local spot = Interact.isHidden(player) and Interact.hidingSpot(player)
	if spot then
		return spot:GetPivot().Position
	end
	local root = rootOf(player)
	return root and root.Position
end

local function playSound(
	parent: Instance,
	name: string,
	level: string,
	group: Mix.Group,
	looped: boolean?
): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = parent
	Mix.route(sound, group)
	if not looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 30) -- in case it never loads and so never ends
	end
	sound:Play()
	return sound
end

-- Flashlight battery ---------------------------------------------------------------------------

local function onFlashlightChanged(player: Player)
	if player:GetAttribute("FlashlightOn") ~= true then
		return
	end
	local battery = Settings.Battery
	local decision =
		Body.switchOn(player:GetAttribute("Battery") or battery.Max, Inventory.has(player, battery.ItemId))
	if decision == "swap" then
		Inventory.remove(player, battery.ItemId, 1)
		player:SetAttribute("Battery", battery.Max)
		tell(player, "New battery in.")
	elseif decision == "dead" then
		player:SetAttribute("FlashlightOn", false)
		tell(player, "Battery's dead. Find another.")
	end
end

-- The battery slot: swap a fresh one in now, unless the current one is still nearly full
local function onBatterySwap(player: Player)
	local battery = Settings.Battery
	local level = player:GetAttribute("Battery") or battery.Max
	if not Inventory.has(player, battery.ItemId) then
		tell(player, "No spare batteries.")
	elseif level >= battery.Max * 0.9 then
		tell(player, "Battery's still good.")
	else
		Inventory.remove(player, battery.ItemId, 1)
		player:SetAttribute("Battery", battery.Max)
		tell(player, "New battery in.")
	end
end

local function stepBattery(player: Player, dt: number)
	local on = player:GetAttribute("FlashlightOn") == true
	if not on then
		return
	end
	local level =
		Body.drainBattery(player:GetAttribute("Battery") or Settings.Battery.Max, on, dt, Settings.Battery)
	player:SetAttribute("Battery", level)
	if level <= 0 then
		player:SetAttribute("FlashlightOn", false)
	end
end

-- Breath -----------------------------------------------------------------------------------------

local function setHolding(player: Player, holding: boolean)
	local breath = breaths[player]
	if not breath or breath.holding == holding then
		return
	end
	breaths[player] = { level = breath.level, holding = holding }
	player:SetAttribute("HoldingBreath", holding or nil)
	local character = player.Character
	if character and character.PrimaryPart then
		playSound(
			character.PrimaryPart,
			if holding then Sounds.HoldBreath else Sounds.Release,
			"quiet",
			"SFX"
		)
	end
end

local function onHoldBreath(player: Player, holding: unknown)
	local breath = breaths[player]
	if type(holding) ~= "boolean" or not breath then
		return
	end
	if holding and not Body.canHold(breath, Interact.isHidden(player), Settings.Breath) then
		return
	end
	setHolding(player, holding)
end

local function gasp(player: Player)
	player:SetAttribute("HoldingBreath", nil)
	local position = noisePosition(player)
	local character = player.Character
	if position then
		Loudness.emit(position, "loud", character)
	end
	if character and character.PrimaryPart then
		playSound(character.PrimaryPart, Sounds.Gasp, "loud", "SFX")
	end
end

local function stepBreath(player: Player, dt: number)
	local breath = breaths[player]
	if not breath then
		return
	end
	if breath.holding and not Interact.isHidden(player) then
		setHolding(player, false)
		breath = breaths[player]
	end
	local nextBreath, event = Body.stepBreath(breath, dt, Settings.Breath)
	breaths[player] = nextBreath
	local shown = math.floor(nextBreath.level + 0.5)
	if player:GetAttribute("Breath") ~= shown then
		player:SetAttribute("Breath", shown)
	end
	if event == "gasp" then
		gasp(player)
	end
end

local function stepArea(player: Player)
	local root = rootOf(player)
	if root then
		player:SetAttribute("Area", if Warehouse.roomAt(root.Position) then "Room" else "Aisle")
	end
end

-- Placement --------------------------------------------------------------------------------------

local function makeClearCheck(layout: WarehouseGen.Layout, pad: number): (number, number) -> boolean
	return function(x: number, z: number): boolean
		if not WarehouseGen.isClear(layout, Config.Warehouse, x, z, pad) then
			return false
		end
		for _, list in { layout.junk, layout.loose } :: { { { x: number, z: number } } } do
			for _, other in list do
				if (other.x - x) ^ 2 + (other.z - z) ^ 2 < pad * pad then
					return false
				end
			end
		end
		return true
	end
end

local function findSpots(count: number, rules: any, taken: { HauntPlacement.Spot }): { HauntPlacement.Spot }
	local layout = Warehouse.layout()
	local half = layout.half - Config.Warehouse.WallThickness - rules.SpotPad
	local clear = makeClearCheck(layout, rules.SpotPad)
	return HauntPlacement.spots(count, half, rules.SpotGap, rules.SpotTries, clear, taken, roll)
end

-- Same as the warehouse build: front (+z) faces turn degrees, bottom sits on the floor.
local function place(name: string, spot: HauntPlacement.Spot, parent: Instance): Model?
	local model = ModelLibrary.get(name)
	if not model then
		return nil
	end
	local radians = math.rad(spot.turn)
	local rotation = CFrame.lookAt(Vector3.zero, -Vector3.new(math.sin(radians), 0, math.cos(radians)))
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local target = Warehouse.toWorld(spot.x, spot.z)
	model:PivotTo(rotation + (target - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	model.Parent = parent
	return model
end

local function addPrompt(model: Model, action: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = Settings.PromptReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	return prompt
end

-- Generators -------------------------------------------------------------------------------------

local function refreshGenerator(gen: Gen)
	local state, prompt = gen.state, gen.prompt
	prompt.ObjectText = `Generator, fuel {math.floor(state.fuel / Settings.Generators.MaxFuel * 100 + 0.5)}%`
	if not state.fixed then
		prompt.ActionText = "Fix"
		prompt.HoldDuration = Settings.Generators.FixTime
	elseif state.running or state.fuel <= 0 then
		prompt.ActionText = "Pour fuel"
		prompt.HoldDuration = 0
	else
		prompt.ActionText = "Pull start"
		prompt.HoldDuration = 0
	end
end

local function setLights(gen: Gen, share: number)
	for _, light in gen.lights do
		light.Enabled = share > 0
		light.Brightness = Settings.Generators.Light.Brightness * share
	end
end

local function setRunning(gen: Gen, running: boolean)
	ModelRig.setGlow(gen.model, running)
	setLights(gen, if running then 1 else 0)
	gen.sinceHum = 0
	if running and not gen.runSound and gen.model.PrimaryPart then
		gen.runSound =
			playSound(gen.model.PrimaryPart, Sounds.GeneratorRun, Settings.Generators.HumLevel, "SFX", true)
	elseif not running and gen.runSound then
		gen.runSound:Destroy()
		gen.runSound = nil
	end
end

local function pourFuel(gen: Gen, player: Player)
	local cans = player:GetAttribute("FuelCans") or 0
	if cans <= 0 then
		tell(player, "Needs fuel. Fuel cans are out in the aisles.")
		return
	end
	if gen.state.fuel >= Settings.Generators.MaxFuel then
		tell(player, "Tank's full.")
		return
	end
	player:SetAttribute("FuelCans", if cans > 1 then cans - 1 else nil)
	gen.state = Generator.refuel(gen.state, Settings.Generators.CanFuel, Settings.Generators)
	if gen.model.PrimaryPart then
		playSound(gen.model.PrimaryPart, Sounds.FuelPour, "normal", "SFX")
	end
end

local function pullStart(gen: Gen, player: Player)
	local now = os.clock()
	if now - gen.lastPullAt < Settings.Generators.PullCooldown then
		return
	end
	gen.lastPullAt = now
	ModelRig.setPose(gen.model, "Handle", 1)
	task.delay(0.25, ModelRig.setPose, gen.model, "Handle", 0)
	local state, result = Generator.pull(gen.state, roll(), Settings.Generators)
	gen.state = state
	local part = gen.model.PrimaryPart
	if result == "started" then
		setRunning(gen, true)
		if part then
			playSound(part, Sounds.GeneratorStart, "loud", "SFX")
			Loudness.emit(part.Position, "loud", gen.model)
		end
	elseif result == "failed" then
		if part then
			playSound(part, Sounds.GeneratorFail, "normal", "SFX")
			Loudness.emit(part.Position, "normal", gen.model)
		end
		tell(player, "It coughs. Pull again.")
	end
end

local function onGeneratorUsed(gen: Gen, player: Player)
	if not rootOf(player) then
		return
	end
	local state = gen.state
	if not state.fixed then
		gen.state = Generator.fix(state)
		tell(player, "Fixed. Now pull start it.")
	elseif state.running or state.fuel <= 0 then
		pourFuel(gen, player)
	else
		pullStart(gen, player)
	end
	refreshGenerator(gen)
end

local function addSectionLights(center: Vector3): { PointLight }
	local rules = Settings.Generators.Light
	local lights = {}
	for index = 1, rules.Count do
		local angle = index / rules.Count * math.pi * 2
		local holder = Instance.new("Part")
		holder.Name = "GeneratorLight"
		holder.Size = Vector3.one
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Position = center
			+ Vector3.new(math.cos(angle) * rules.Radius, rules.Height, math.sin(angle) * rules.Radius)
		local light = Instance.new("PointLight")
		light.Range = rules.Range
		light.Color = rules.Color
		light.Brightness = rules.Brightness
		light.Shadows = false
		light.Enabled = false
		light.Parent = holder
		holder.Parent = folder
		table.insert(lights, light)
	end
	return lights
end

local function placeGenerators(taken: { HauntPlacement.Spot })
	local rules = Settings.Generators
	for _, spot in findSpots(Warehouse.scaled(rules.Count), rules, taken) do
		local model = place("generator", spot, folder)
		if model then
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			ModelRig.rig(model)
			ModelRig.setGlow(model, false)
			local gen: Gen = {
				model = model,
				state = Generator.new(rules.StartFuel),
				lights = addSectionLights(model:GetPivot().Position),
				prompt = addPrompt(model, "Fix", "Generator"),
				sinceHum = 0,
				lastPullAt = 0,
			}
			gen.prompt.Triggered:Connect(function(player)
				onGeneratorUsed(gen, player)
			end)
			refreshGenerator(gen)
			table.insert(generators, gen)
		end
	end
end

local function stepGenerator(gen: Gen, dt: number)
	if not gen.state.running then
		return
	end
	local rules = Settings.Generators
	local state, event = Generator.tick(gen.state, dt, rules)
	gen.state = state
	local part = gen.model.PrimaryPart
	if event == "died" then
		setRunning(gen, false)
		if part then
			playSound(part, Sounds.GeneratorDie, "normal", "SFX")
		end
		refreshGenerator(gen)
		return
	end
	if event == "sputter" and part then
		playSound(part, Sounds.GeneratorSputter, "normal", "SFX")
	end
	if Generator.isSputtering(state, rules) then
		setLights(gen, if roll() < 0.35 then rules.Light.SputterDim else 1)
	end
	gen.sinceHum += dt
	if gen.sinceHum >= rules.HumEvery and part then
		gen.sinceHum = 0
		Loudness.emit(part.Position, rules.HumLevel, gen.model)
		refreshGenerator(gen)
	end
end

-- Fuel cans and journals ---------------------------------------------------------------------------

local function placeFuelCans()
	fuelFolder:ClearAllChildren()
	local rules = Settings.FuelCans
	local taken = {}
	for _, generator in generators do
		local pivot = generator.model:GetPivot().Position - Config.Warehouse.Origin
		table.insert(taken, { x = pivot.X, z = pivot.Z, turn = 0 })
	end
	for _, spot in findSpots(Warehouse.scaled(rules.Count), rules, taken) do
		local model = place("fuel_can", spot, fuelFolder)
		if model then
			local prompt = addPrompt(model, "Pick up", "Fuel can")
			prompt.Triggered:Connect(function(player)
				local cans = player:GetAttribute("FuelCans") or 0
				if not rootOf(player) or not model.Parent then
					return
				end
				if cans >= rules.MaxCarry then
					tell(player, "Hands full. Pour one first.")
					return
				end
				player:SetAttribute("FuelCans", cans + 1)
				model:Destroy()
			end)
		end
	end
end

local function placeJournals(taken: { HauntPlacement.Spot })
	local journals = Settings.Journals
	for index, spot in findSpots(#journals, Settings.Lore, taken) do
		local model = place("journal", spot, folder)
		local page = journals[index]
		if model then
			local prompt = addPrompt(model, "Read", page.title)
			prompt.Triggered:Connect(function(player)
				loreRemote:FireClient(player, page.title, page.text)
				Files.find(player, page.id)
			end)
		end
	end
end

-- Storm and PA -----------------------------------------------------------------------------------

local function realAisle(): number?
	local outside = {}
	local half = Warehouse.layout().half
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local here = root and root.Position - Config.Warehouse.Origin
		-- only someone actually out on the warehouse floor (not the lobby or test room)
		if
			root
			and here
			and math.abs(here.X) < half
			and math.abs(here.Z) < half
			and not Interact.isHidden(player)
		then
			table.insert(outside, root.Position)
		end
	end
	if #outside == 0 then
		return nil
	end
	local relative = outside[random:NextInteger(1, #outside)] - Config.Warehouse.Origin
	local sign = World.nearestSign(Warehouse.layout().signs, relative.X, relative.Z)
	return sign and sign.number
end

local function stepNight(now: number)
	if not DayNight.isNight() then
		return
	end
	if now >= nextLightningAt then
		nextLightningAt = now + World.between(Settings.Storm.LightningGap, roll())
		stormRemote:FireAllClients(roll() < Settings.Storm.NearChance, random:NextInteger(1, 2 ^ 30))
	end
	if now >= nextAnnouncementAt then
		-- the speakers are busy with an event call: try again shortly instead of talking over it
		if not PaEvents.claimAir(Settings.PA.ChimeToLine + Settings.PA.SubtitleTime) then
			nextAnnouncementAt = now + 10
			return
		end
		nextAnnouncementAt = now + World.between(Settings.PA.Gap, roll())
		local line = World.announcement(realAisle(), roll, Settings.PA)
		paRemote:FireAllClients(line.text, line.voice, roll() < Settings.PA.GlitchChance)
	end
end

local function onPhaseChanged(phase: string)
	local now = os.clock()
	if phase == "Night" then
		nextLightningAt = now + World.between(Settings.Storm.LightningGap, roll())
		nextAnnouncementAt = now + World.between(Settings.PA.Gap, roll())
	elseif phase == "Day" then
		nextLightningAt, nextAnnouncementAt = math.huge, math.huge
		if fuelFolder then
			placeFuelCans()
		end
	end
end

-- Players ----------------------------------------------------------------------------------------

local function onCharacterAdded(player: Player)
	player:SetAttribute("Battery", Settings.Battery.Max)
	player:SetAttribute("FuelCans", nil)
	player:SetAttribute("HoldingBreath", nil)
	breaths[player] = Body.newBreath(Settings.Breath)
	player:SetAttribute("Breath", Settings.Breath.Max)
end

local function onPlayerAdded(player: Player)
	player:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
		onFlashlightChanged(player)
	end)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	onCharacterAdded(player)
end

local function waitForWarehouse()
	local root = workspace:FindFirstChild("Warehouse")
	while not (root and root:GetAttribute("Built")) do
		task.wait(1)
		root = workspace:FindFirstChild("Warehouse")
	end
end

function NightTricks.Init()
	breathRemote = Net.event("HoldBreath")
	noteRemote = Net.event("NightTricksNote")
	loreRemote = Net.event("LoreNote")
	stormRemote = Net.event("NightStorm")
	paRemote = Net.event("NightPA")
	Net.event("BatterySwap").OnServerEvent:Connect(onBatterySwap)
end

function NightTricks.Start()
	breathRemote.OnServerEvent:Connect(onHoldBreath)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		breaths[player] = nil
	end)
	DayNight.onPhaseChanged(onPhaseChanged)

	local sinceTick, sinceArea = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		sinceArea += dt
		if sinceTick < Settings.TickEvery then
			return
		end
		local step = sinceTick
		sinceTick = 0
		local checkArea = sinceArea >= 1
		if checkArea then
			sinceArea = 0
		end
		for _, player in Players:GetPlayers() do
			stepBattery(player, step)
			stepBreath(player, step)
			if checkArea then
				stepArea(player)
			end
		end
		for _, gen in generators do
			stepGenerator(gen, step)
		end
		stepNight(os.clock())
	end)

	waitForWarehouse()
	folder = Instance.new("Folder")
	folder.Name = "NightTricks"
	folder.Parent = workspace
	fuelFolder = Instance.new("Folder")
	fuelFolder.Name = "FuelCans"
	fuelFolder.Parent = folder
	local taken: { HauntPlacement.Spot } = {}
	placeGenerators(taken)
	placeJournals(taken)
	placeFuelCans()
	if DayNight.isNight() then
		onPhaseChanged("Night")
	end
end

return NightTricks
