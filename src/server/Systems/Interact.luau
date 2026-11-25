-- Press to use. The client says which object (and which part of it) it's looking at; the server checks
-- reach and runs that object's behaviour from Logic/InteractKinds. Moving parts tween here so
-- everyone sees them, every use makes a 3D sound and a Loudness event, and players can hide inside.
-- Containers listens for opens and shuts here to show what's inside.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local InteractKinds = require(ReplicatedStorage.Shared.Logic.InteractKinds)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Manifest = require(ReplicatedStorage.Shared.Logic.Manifest)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Logic.Interact)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)

local Settings = Config.Interact

type Behaviour = InteractKinds.Behaviour
type State = { on: boolean, channel: number, running: boolean, ring: number, loop: Sound? }
type Spinner = { behaviour: Behaviour, started: number }
type Hiding = {
	model: Model,
	pivot: CFrame,
	parts: { string },
	sound: string?,
	transparency: { [Instance]: number },
}
type Handler = (player: Player, model: Model, behaviour: Behaviour, key: string, parts: { string }) -> ()
type OpenListener = (player: Player?, model: Model, key: string, open: boolean) -> ()
type UseFilter = (player: Player, model: Model, behaviour: Behaviour) -> boolean

local Interact = {}

local states: { [Model]: { [string]: State } } = {}
local poseValues: { [Model]: { [string]: NumberValue } } = {}
local spinning: { [Model]: { [string]: Spinner } } = {}
local noisy: { [Model]: { [string]: string } } = {} -- loudness level per running continuous source
local lastUse: { [Model]: number } = {}
local cushionSearched: { [Model]: number } = {}
local tracked: { [Model]: RBXScriptConnection } = {}
local ringing: { [Model]: boolean } = {}
local lastPlayerUse: { [Player]: number } = {}
local hiding: { [Player]: Hiding } = {}
local occupants: { [Model]: Player } = {}
local openListeners: { OpenListener } = {}
local useFilter: UseFilter? = nil

local HIDE_KEY = "Hide"
local random = Random.new()
local useRemote: RemoteEvent

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function stateOf(model: Model, key: string): State
	local byKey = states[model] or {}
	states[model] = byKey
	local state = byKey[key]
	if not state then
		state = { on = false, channel = 0, running = false, ring = 0, loop = nil }
		byKey[key] = state
	end
	return state
end

local function announceOpen(player: Player?, model: Model, key: string, open: boolean)
	for _, listener in openListeners do
		task.spawn(listener, player, model, key, open)
	end
end

local function setOn(model: Model, key: string, state: State, on: boolean)
	state.on = on
	model:SetAttribute(Rules.stateAttribute(key), on)
end

-- Sound

local function playSound(model: Model, id: string?, level: string, looped: boolean): Sound?
	local part = model.PrimaryPart
	if not id or not part then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Settings.Volume
	sound.Looped = looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(level :: any)
	sound.Parent = part
	sound:Play()
	if not looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 30) -- in case it never loads and so never ends
	end
	return sound
end

-- Robots hear the event even while the sound itself has no uploaded id yet.
local function makeNoise(model: Model, soundName: string?, level: string)
	Loudness.emit(model:GetPivot().Position, level :: any, model)
	playSound(model, soundName and ModelLibrary.soundId(soundName), level, false)
end

local function bubble(model: Model, text: string)
	local part = model.PrimaryPart
	if not part then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "InteractBubble"
	gui.Size = UDim2.fromOffset(280, 70)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	gui.MaxDistance = 60
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	Debris:AddItem(gui, Settings.BubbleTime)
end

-- What it says: a fixed line (string), one voice line ({ sound, text }) or a random one from a list.
local function say(model: Model, linesKey: string?)
	local lines = linesKey and Settings[linesKey]
	if type(lines) == "string" then
		bubble(model, lines)
		return
	end
	if type(lines) ~= "table" then
		return
	end
	local line = if lines.text then lines else Rules.pick(lines, random:NextNumber())
	if line then
		bubble(model, line.text)
		playSound(model, ModelLibrary.soundId(line.sound), "normal", false)
	end
end

-- Moving parts

local function joint(model: Model, partName: string): ModelRig.Joint?
	local found = ModelRig.rig(model)[partName]
	if found then
		-- Grab anchors every part of a carried prop and leaves them anchored, which freezes the hinge.
		found.motor.Part1.Anchored = false
	end
	return found
end

local function poseValue(model: Model, partName: string): NumberValue?
	if not joint(model, partName) then
		return nil
	end
	local byPart = poseValues[model] or {}
	poseValues[model] = byPart
	local value = byPart[partName]
	if not value then
		local created = Instance.new("NumberValue")
		created.Changed:Connect(function(t)
			ModelRig.setPose(model, partName, t)
		end)
		byPart[partName] = created
		value = created
	end
	return value
end

-- A new tween on the same value cancels the old one, so a door can be shut while it's still opening.
local function tweenPose(model: Model, parts: { string }?, t: number, time: number)
	for _, name in parts or {} do
		local value = poseValue(model, name)
		if value then
			local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			TweenService:Create(value, info, { Value = t }):Play()
		end
	end
end

local function pulse(model: Model, parts: { string }?, hold: number?)
	if not parts or #parts == 0 then
		return
	end
	tweenPose(model, parts, 1, Settings.PressTime)
	task.delay(Settings.PressTime + (hold or 0), tweenPose, model, parts, 0, Settings.PressTime)
end

-- One full turn, then back to 0 without a jump (a full turn looks the same as none).
local function spinOnce(model: Model, parts: { string }?, time: number)
	for _, name in parts or {} do
		local value = poseValue(model, name)
		if value then
			value.Value = 0
			TweenService:Create(value, TweenInfo.new(time, Enum.EasingStyle.Quad), { Value = 1 }):Play()
			task.delay(time, function()
				if value.Value >= 1 then
					value.Value = 0
				end
			end)
		end
	end
end

local function setGlow(model: Model, on: boolean, light: boolean?)
	ModelRig.setGlow(model, on)
	if not light then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and Manifest.isGlow(part.Name) then
			local lamp = part:FindFirstChild("InteractLight") :: PointLight?
			if not lamp then
				local created = Instance.new("PointLight")
				created.Name = "InteractLight"
				created.Range = Settings.Light.Range
				created.Brightness = Settings.Light.Brightness
				created.Color = Settings.Light.Color
				created.Shadows = true
				created.Parent = part
				lamp = created
			end
			if lamp then
				lamp.Enabled = on
			end
		end
	end
end

local function showImage(model: Model, imageName: string?)
	ModelRig.rig(model)
	ModelRig.setScreen(model, imageName and ModelLibrary.imageId(imageName) or "")
end

-- Everything that runs while an object is on: loop sound, loudness pings, spinning, glow, screen.
local function setRunning(model: Model, key: string, behaviour: Behaviour, state: State, on: boolean)
	if on and not state.loop then
		local id = if behaviour.loopConfig
			then Settings[behaviour.loopConfig]
			else behaviour.loop and ModelLibrary.soundId(behaviour.loop)
		state.loop = playSound(model, id, behaviour.loopLoudness or behaviour.loudness, true)
	elseif not on and state.loop then
		state.loop:Destroy()
		state.loop = nil
	end

	if behaviour.loopLoudness then
		local byKey = noisy[model] or {}
		noisy[model] = byKey
		byKey[key] = if on then behaviour.loopLoudness else nil
	end

	if behaviour.spin or behaviour.bob then
		local byKey = spinning[model] or {}
		spinning[model] = byKey
		if on then
			for _, name in behaviour.spin or {} do
				joint(model, name)
			end
			for _, name in behaviour.bob or {} do
				joint(model, name)
			end
			byKey[key] = { behaviour = behaviour, started = os.clock() }
		else
			byKey[key] = nil
			for _, name in behaviour.bob or {} do
				ModelRig.setPose(model, name, 0)
			end
		end
	end

	if behaviour.glow then
		setGlow(model, on, behaviour.light)
	end
	if behaviour.screenOn then
		showImage(model, if on then behaviour.screenOn else nil)
	end
end

local function cleanup(model: Model)
	for _, state in states[model] or {} do
		if state.loop then
			state.loop:Destroy()
		end
	end
	for _, value in poseValues[model] or {} do
		value:Destroy()
	end
	states[model] = nil
	poseValues[model] = nil
	spinning[model] = nil
	noisy[model] = nil
	lastUse[model] = nil
	cushionSearched[model] = nil
	ringing[model] = nil
	if tracked[model] then
		tracked[model]:Disconnect()
		tracked[model] = nil
	end
end

local function track(model: Model)
	if not tracked[model] then
		tracked[model] = model.Destroying:Connect(function()
			cleanup(model)
		end)
	end
end

-- Hiding

local function leave(player: Player, stepOut: boolean)
	local entry = hiding[player]
	if not entry then
		return
	end
	hiding[player] = nil
	if occupants[entry.model] == player then
		occupants[entry.model] = nil
	end
	announceOpen(player, entry.model, HIDE_KEY, false)
	if player.Parent then
		player:SetAttribute("Hidden", nil)
	end
	for instance, transparency in entry.transparency do
		if instance.Parent then
			(instance :: any).Transparency = transparency
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	if stepOut and entry.model:IsDescendantOf(workspace) then
		local box, size = entry.model:GetBoundingBox()
		local front = entry.model:GetPivot().ZVector -- models face +z
		local spot = box.Position
			+ front * (size.Z / 2 + Settings.EjectDistance)
			+ Vector3.new(0, 3 - size.Y / 2, 0)
		character:PivotTo(CFrame.lookAt(spot, spot + front))
		tweenPose(entry.model, entry.parts, 1, Settings.OpenTime)
		task.delay(
			Settings.OpenTime + Settings.RevealHold,
			tweenPose,
			entry.model,
			entry.parts,
			0,
			Settings.OpenTime
		)
		makeNoise(entry.model, entry.sound, "quiet")
	end
	root.Anchored = false
end

local function enter(player: Player, model: Model, behaviour: Behaviour, parts: { string })
	local root, humanoid = bodyOf(player)
	local character = player.Character
	if not root or not humanoid or not character or humanoid.SeatPart then
		return
	end
	tweenPose(model, parts, 1, Settings.OpenTime)
	task.delay(Settings.OpenTime, tweenPose, model, parts, 0, Settings.OpenTime)
	makeNoise(model, behaviour.sound, behaviour.loudness)
	makeNoise(model, "hide_creak", "quiet")

	local saved = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			saved[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end
	local box = model:GetBoundingBox()
	local pose = CFrame.new(box.Position) * model:GetPivot().Rotation
	if behaviour.lieDown then
		pose *= CFrame.Angles(math.pi / 2, 0, 0)
	end
	root.Anchored = true
	character:PivotTo(pose)

	hiding[player] = {
		model = model,
		pivot = model:GetPivot(),
		parts = parts,
		sound = behaviour.sound,
		transparency = saved,
	}
	occupants[model] = player
	player:SetAttribute("Hidden", true)
	announceOpen(player, model, HIDE_KEY, true)
end

-- Behaviours

local handlers: { [string]: Handler } = {}

local function toggle(player: Player?, model: Model, behaviour: Behaviour, key: string, parts: { string })
	local state = stateOf(model, key)
	local on = not state.on
	setOn(model, key, state, on)
	if behaviour.kind == "open" then
		announceOpen(player, model, key, on)
	end
	tweenPose(model, parts, if on then 1 else 0, Settings.OpenTime)
	pulse(model, behaviour.press)
	makeNoise(
		model,
		if on then behaviour.sound else behaviour.offSound or behaviour.sound,
		behaviour.loudness
	)
	setRunning(model, key, behaviour, state, on)
end

handlers.open = toggle
handlers.toggle = toggle

function handlers.channel(_player, model, behaviour, key)
	local state = stateOf(model, key)
	local channels = behaviour.channels or {}
	local index = Rules.nextChannel(state.channel, #channels, behaviour.canTurnOff)
	state.channel = index
	setOn(model, key, state, index > 0)
	makeNoise(model, if index > 0 then behaviour.sound else behaviour.offSound, behaviour.loudness)
	setRunning(model, key, behaviour, state, index > 0)
	if index == 0 then
		showImage(model, nil)
		return
	end
	if not behaviour.static then
		showImage(model, channels[index])
		return
	end
	showImage(model, behaviour.static)
	playSound(
		model,
		behaviour.staticSound and ModelLibrary.soundId(behaviour.staticSound),
		behaviour.loudness,
		false
	)
	task.delay(Settings.StaticBurst, function()
		if state.channel == index then
			showImage(model, channels[index])
		end
	end)
end

function handlers.press(_player, model, behaviour)
	pulse(model, behaviour.press)
	makeNoise(model, behaviour.sound, behaviour.loudness)
	if behaviour.screenOn then
		showImage(model, behaviour.screenOn)
	end
	say(model, behaviour.lines)
end

local function runCycle(
	model: Model,
	key: string,
	behaviour: Behaviour,
	parts: { string },
	onEnd: (() -> ())?
)
	local state = stateOf(model, key)
	if state.running then
		return
	end
	state.running = true
	setOn(model, key, state, true)
	pulse(model, behaviour.press)
	tweenPose(model, parts, 1, Settings.PressTime)
	makeNoise(model, behaviour.sound, behaviour.loudness)
	setRunning(model, key, behaviour, state, true)
	task.delay(behaviour.duration or 3, function()
		state.running = false
		setOn(model, key, state, false)
		setRunning(model, key, behaviour, state, false)
		tweenPose(model, parts, 0, Settings.PressTime)
		if not model:IsDescendantOf(workspace) then
			return
		end
		makeNoise(model, behaviour.endSound, behaviour.endLoudness or behaviour.loudness)
		pulse(model, behaviour.pop, Settings.PopHold)
		if onEnd then
			onEnd()
		end
	end)
end

function handlers.cycle(_player, model, behaviour, key, parts)
	runCycle(model, key, behaviour, parts)
end

function handlers.vend(player, model, behaviour, key, parts)
	if stateOf(model, key).running then
		return
	end
	local stock = model:GetAttribute("Stock")
	if type(stock) ~= "number" then
		stock = Settings.VendingStock
	end
	if stock <= 0 then
		pulse(model, behaviour.press)
		makeNoise(model, behaviour.sound, behaviour.loudness)
		bubble(model, Settings.SoldOutLine)
		return
	end
	model:SetAttribute("Stock", stock - 1)
	runCycle(model, key, behaviour, parts, function()
		local item = Settings.VendingItem
		if InventoryItems[item] and player.Parent then
			Inventory.add(player, item, 1)
		end
	end)
end

local function searchCushions(player: Player, model: Model)
	local now = os.clock()
	local feedback = Net.event("SupplyFeedback")
	local last = cushionSearched[model]
	if last and now - last < Settings.CushionCooldown then
		feedback:FireClient(player, Settings.CushionEmptyLine)
		return
	end
	cushionSearched[model] = now
	local amount = Rules.cushionFind(
		random:NextNumber(),
		random:NextNumber(),
		Settings.CushionChance,
		Settings.CushionAmmo.Min,
		Settings.CushionAmmo.Max
	)
	if amount > 0 and InventoryItems[Settings.CushionItem] then
		Inventory.add(player, Settings.CushionItem, amount)
		feedback:FireClient(player, string.format(Settings.CushionFoundLine, amount))
	else
		feedback:FireClient(player, Settings.CushionNothingLine)
	end
end

function handlers.sit(player, model, behaviour)
	local _, humanoid = bodyOf(player)
	if not humanoid or humanoid.SeatPart or model:FindFirstChild("InteractSeat") then
		return
	end
	local box, size = model:GetBoundingBox()
	local front = model:GetPivot().ZVector
	local position = box.Position + Vector3.new(0, size.Y * ((behaviour.seatHeight or 0.45) - 0.5), 0)
	local seat = Instance.new("Seat")
	seat.Name = "InteractSeat"
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanQuery = false
	seat.Anchored = true
	seat.CFrame = CFrame.lookAt(position, position + front)
	seat.Parent = model
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant then
			seat:Destroy()
		end
	end)
	seat:Sit(humanoid)
	task.delay(1, function()
		if seat.Parent and not seat.Occupant then
			seat:Destroy()
		end
	end)
	makeNoise(model, behaviour.sound, behaviour.loudness)
	spinOnce(model, behaviour.spinOnSit, Settings.SitSpinTime)
	if behaviour.search then
		searchCushions(player, model)
	end
end

function handlers.hide(player, model, behaviour, _key, parts)
	local action = Rules.hideAction(occupants[model], player)
	if action == "enter" then
		enter(player, model, behaviour, parts)
	elseif action == "reveal" then
		Interact.reveal(model)
	end
end

local function stopRinging(model: Model, behaviour: Behaviour, state: State)
	setOn(model, "", state, false)
	setRunning(model, "", behaviour, state, false)
end

-- At night whoever answers hears something wrong on the line, with a subtitle only they see.
-- Returns the looping sound, if any, for the hang-up to stop.
local function nightCall(player: Player, model: Model): Sound?
	local line = Rules.pick(Settings.NightPhoneLines, random:NextNumber())
	if not line then
		return nil
	end
	Net.event("SupplyFeedback"):FireClient(player, line.text)
	local loop = line.loop and playSound(model, ModelLibrary.soundId(line.loop), "quiet", true)
	task.delay(line.soundDelay or 0, function()
		local sound = playSound(model, ModelLibrary.soundId(line.sound), "quiet", false)
		if sound then
			sound.PlaybackSpeed = line.speed or 1
		end
	end)
	return loop
end

function handlers.phone(player, model, behaviour, _key, parts)
	local state = stateOf(model, "")
	if state.on then
		stopRinging(model, behaviour, state)
		state.running = true
		tweenPose(model, parts, 1, Settings.OpenTime)
		makeNoise(model, behaviour.offSound, behaviour.loudness)
		local night = DayNight.isNight()
		local loop = if night then nightCall(player, model) else nil
		if not night then
			say(model, "PhoneLine")
		end
		task.delay(Settings.PhoneTalkTime, function()
			if loop then
				loop:Destroy()
			end
			tweenPose(model, parts, 0, Settings.OpenTime)
			if model:IsDescendantOf(workspace) then
				makeNoise(model, behaviour.offSound, behaviour.loudness)
			end
			state.running = false
		end)
	elseif not state.running then
		spinOnce(model, behaviour.press, 1)
		makeNoise(model, behaviour.sound, behaviour.loudness)
	end
end

-- Phones ring on their own now and then, until someone answers or it gives up.
local function ringNowAndThen(model: Model, behaviour: Behaviour)
	if ringing[model] then
		return
	end
	ringing[model] = true
	track(model)
	task.spawn(function()
		while ringing[model] do
			task.wait(random:NextNumber(Settings.PhoneRingGap.Min, Settings.PhoneRingGap.Max))
			local state = stateOf(model, "")
			if not ringing[model] or not model:IsDescendantOf(workspace) or state.on or state.running then
				continue
			end
			state.ring += 1
			local ring = state.ring
			setOn(model, "", state, true)
			setRunning(model, "", behaviour, state, true)
			task.delay(Settings.PhoneRingFor, function()
				if state.on and state.ring == ring then
					stopRinging(model, behaviour, state)
				end
			end)
		end
	end)
end

local function watchForRingers(instance: Instance)
	if instance:IsA("Model") then
		local behaviour = InteractKinds.get(instance:GetAttribute("ModelName"))
		if behaviour and behaviour.kind == "phone" then
			ringNowAndThen(instance, behaviour)
		end
	end
end

local function onUse(player: Player, model: any, partName: any)
	if hiding[player] then
		leave(player, true)
		return
	end
	if player:GetAttribute("Cuffed") == true then
		return
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return
	end
	if type(partName) ~= "string" or not model:FindFirstChild(partName, true) then
		partName = nil
	end
	local behaviour = InteractKinds.get(model:GetAttribute("ModelName"))
	if not behaviour then
		return
	end
	local root = bodyOf(player)
	local distance = math.huge
	if root then
		local box, size = model:GetBoundingBox()
		local point = box:PointToObjectSpace(root.Position)
		distance = Rules.distanceToBox(point.X, point.Y, point.Z, size.X / 2, size.Y / 2, size.Z / 2)
	end
	local now = os.clock()
	local ok = Rules.canUse({
		alive = root ~= nil,
		-- Grab sets this on the carrier for as long as they hold a prop.
		carrying = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		distance = distance,
		reach = Settings.Reach,
		cooling = now - (lastUse[model] or -math.huge) < Settings.ObjectCooldown
			or now - (lastPlayerUse[player] or -math.huge) < Settings.PlayerCooldown,
	})
	if not ok then
		return
	end
	lastUse[model] = now
	lastPlayerUse[player] = now
	track(model)
	local resolved, key, parts = Rules.resolve(behaviour, partName)
	if useFilter and useFilter(player, model, resolved) then
		return
	end
	local handler = handlers[resolved.kind]
	if handler then
		handler(player, model, resolved, key, parts)
	end
end

local function emitContinuous()
	for model, byKey in noisy do
		if not model:IsDescendantOf(workspace) then
			continue
		end
		local position = model:GetPivot().Position
		for _, level in byKey do
			Loudness.emit(position, level :: any, model)
		end
	end
end

local function stepSpinners()
	local now = os.clock()
	for model, byKey in spinning do
		for _, spinner in byKey do
			local elapsed = now - spinner.started
			for _, name in spinner.behaviour.spin or {} do
				ModelRig.setPose(model, name, Rules.spinT(elapsed, spinner.behaviour.spinSpeed or 1))
			end
			for _, name in spinner.behaviour.bob or {} do
				ModelRig.setPose(model, name, Rules.bobT(elapsed, Settings.BobPeriod))
			end
		end
	end
end

-- Drops a hider out if they died, or their spot was destroyed, grabbed or pushed.
local function checkHiders()
	for player, entry in hiding do
		if not bodyOf(player) then
			leave(player, false)
		elseif
			not entry.model:IsDescendantOf(workspace)
			or (entry.model:GetPivot().Position - entry.pivot.Position).Magnitude
				> Settings.HideMoveTolerance
		then
			leave(player, true)
		end
	end
end

function Interact.isHidden(player: Player): boolean
	return hiding[player] ~= nil
end

function Interact.hidingSpot(player: Player): Model?
	local entry = hiding[player]
	return entry and entry.model
end

-- Opens a hiding spot and throws out whoever is inside. For robots and for players pressing it.
function Interact.reveal(model: Model): Player?
	local occupant = occupants[model]
	if occupant then
		leave(occupant, true)
	end
	return occupant
end

-- Calls listener(player, model, key, open) when a door, drawer or lid opens or shuts (player is
-- nil when shut by the server), and with key HIDE_KEY when someone steps into or out of a spot.
function Interact.onOpenChanged(listener: OpenListener)
	table.insert(openListeners, listener)
end

-- A filter that returns true takes the press instead of the object's behaviour.
function Interact.setUseFilter(filter: UseFilter)
	useFilter = filter
end

-- Shuts every open door, drawer and lid on a model, with sound.
function Interact.shut(model: Model)
	local behaviour = InteractKinds.get(model:GetAttribute("ModelName"))
	if not behaviour then
		return
	end
	for key, state in states[model] or {} do
		local resolved, _, parts = Rules.resolve(behaviour, if key == "" then nil else key)
		if state.on and resolved.kind == "open" then
			toggle(nil, model, resolved, key, parts)
		end
	end
end

function Interact.Init()
	useRemote = Net.event("InteractUse")
	useRemote.OnServerEvent:Connect(onUse)
	workspace.DescendantAdded:Connect(watchForRingers)
	for _, descendant in workspace:GetDescendants() do
		watchForRingers(descendant)
	end
	Players.PlayerRemoving:Connect(function(player)
		leave(player, false)
		lastPlayerUse[player] = nil
	end)
end

function Interact.Start()
	local sinceSpin, sinceNoise, sinceHide = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		sinceSpin += dt
		sinceNoise += dt
		sinceHide += dt
		if sinceSpin >= 1 / Settings.SpinRate then
			sinceSpin = 0
			stepSpinners()
		end
		if sinceNoise >= Settings.ContinuousEvery then
			sinceNoise = 0
			emitContinuous()
		end
		if sinceHide >= Settings.HiddenCheckEvery then
			sinceHide = 0
			checkHiders()
		end
	end)
end

return Interact
