-- Night tricks on the client: flashlight flicker and battery bar, the peek view and breath holding
-- while hidden (hold Jump: Space / Cross), room reverb, heavy breathing after a sprint, rain,
-- lightning (with the odd robot standing in the flash), night PA subtitles, far-off shelf noises
-- and survivor journal pages.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Body = require(ReplicatedStorage.Shared.Logic.NightTricksBody)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local World = require(ReplicatedStorage.Shared.Logic.NightTricksWorld)
local Input = require(script.Parent.Input)
local Movement = require(script.Parent.Movement)
local Music = require(script.Parent.Music)

local Settings = Config.NightTricks
local Sounds = Settings.Sounds
local player = Players.LocalPlayer

local NightTricks = {}

local random = Random.new()
local breathRemote: RemoteEvent
local gui: ScreenGui
local peek: Frame
local breathBar: Frame
local batteryBar: Frame
local subtitle: TextLabel
local note: TextLabel
local lorePanel: Frame
local rain: Sound?
local heavy: Sound?
local askedToHold = false
local effort = 0
local flashing = false
local nightToken = 0
local noteToken = 0
local subtitleToken = 0
local lastFlickerSound = 0

local function makeSound(name: string, volume: number, looped: boolean): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

local function playOnce(name: string, volume: number)
	local sound = makeSound(name, volume, false)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

local function isNight(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
end

-- UI -------------------------------------------------------------------------------------------

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextColor3 = Color3.fromRGB(230, 230, 225)
	text.TextStrokeTransparency = 0.5
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function bar(name: string, bottom: number, parent: Instance): Frame
	local rules = Settings.Battery.Bar
	local back = Instance.new("Frame")
	back.Name = name
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -bottom)
	back.Size = UDim2.fromOffset(rules.Width, rules.Height)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Visible = false
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = rules.Color
	fill.BorderSizePixel = 0
	fill.Parent = back
	back.Parent = parent
	return back
end

local function setBar(frame: Frame, share: number, low: boolean)
	local fill = frame:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	fill.BackgroundColor3 = if low then Settings.Battery.Bar.LowColor else Settings.Battery.Bar.Color
end

local function buildPeek(parent: Instance): Frame
	local rules = Settings.Peek
	local holder = Instance.new("Frame")
	holder.Name = "Peek"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	local slatHeight = (1 - rules.Gap * rules.Slats) / rules.Slats
	for index = 0, rules.Slats - 1 do
		local slat = Instance.new("Frame")
		slat.Position = UDim2.fromScale(0, index * (slatHeight + rules.Gap) + rules.Gap / 2)
		slat.Size = UDim2.fromScale(1, slatHeight)
		slat.BackgroundColor3 = rules.Color
		slat.BorderSizePixel = 0
		slat.Parent = holder
	end
	holder.Parent = parent
	return holder
end

local function buildLorePanel(parent: Instance): Frame
	local panel = Instance.new("Frame")
	panel.Name = "Lore"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromOffset(420, 220)
	panel.BackgroundColor3 = Color3.fromRGB(214, 206, 184)
	panel.BorderSizePixel = 0
	panel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
	padding.Parent = panel
	local ink = Color3.fromRGB(35, 32, 30)
	label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.SpecialElite,
		TextSize = 20,
		TextColor3 = ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	label({
		Name = "Body",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -50),
		Font = Enum.Font.SpecialElite,
		TextSize = 16,
		TextColor3 = ink,
		TextStrokeTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, panel)
	label({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(200, 16),
		TextSize = 12,
		TextColor3 = ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Use to close",
	}, panel)
	panel.Parent = parent
	return panel
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "NightTricks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	peek = buildPeek(gui)
	batteryBar = bar("Battery", 72, gui)
	breathBar = bar("Breath", 92, gui)
	label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(260, 16),
		TextSize = 13,
		Text = "Hold Jump to hold your breath",
	}, breathBar)
	subtitle = label({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.6, 0, 0, 24),
		TextSize = 18,
		TextWrapped = true,
		Visible = false,
	}, gui)
	note = label({
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -122),
		Size = UDim2.new(0.5, 0, 0, 20),
		TextSize = 15,
		Visible = false,
	}, gui)
	lorePanel = buildLorePanel(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showFor(target: TextLabel, text: string, seconds: number, token: number, current: () -> number)
	target.Text = text
	target.Visible = true
	task.delay(seconds, function()
		if current() == token then
			target.Visible = false
		end
	end)
end

local function showNote(text: unknown)
	if type(text) ~= "string" then
		return
	end
	noteToken += 1
	showFor(note, text, 2.5, noteToken, function()
		return noteToken
	end)
end

local function showLore(title: unknown, text: unknown)
	if type(title) ~= "string" or type(text) ~= "string" then
		return
	end
	(lorePanel:FindFirstChild("Title") :: TextLabel).Text = title;
	(lorePanel:FindFirstChild("Body") :: TextLabel).Text = text
	lorePanel.Visible = true
end

-- Battery and breath ------------------------------------------------------------------------------

local function updateFlashlight()
	local level = player:GetAttribute("Battery") or Settings.Battery.Max
	local on = player:GetAttribute("FlashlightOn") == true
	local low = level < Settings.Battery.LowAt
	batteryBar.Visible = on or low
	setBar(batteryBar, level / Settings.Battery.Max, low)

	local beam = workspace.CurrentCamera:FindFirstChild("FlashlightBeam")
	local light = beam and beam:FindFirstChildOfClass("SpotLight")
	if not light then
		return
	end
	local share = Body.flicker(level, os.clock(), Settings.Battery)
	light.Brightness = Config.DayNight.Flashlight.Brightness * share
	if share < 1 and os.clock() - lastFlickerSound > 3 then
		lastFlickerSound = os.clock()
		playOnce(Sounds.Flicker, 0.4)
	end
end

local function updateHiding()
	local hidden = player:GetAttribute("Hidden") == true
	peek.Visible = hidden
	breathBar.Visible = hidden
	setBar(breathBar, (player:GetAttribute("Breath") or Settings.Breath.Max) / Settings.Breath.Max, false)
	if not hidden then
		askedToHold = false
	end
end

local function onJump(began: boolean)
	if began and player:GetAttribute("Hidden") == true then
		askedToHold = true
		breathRemote:FireServer(true)
	elseif not began and askedToHold then
		askedToHold = false
		breathRemote:FireServer(false)
	end
end

local function onUse(began: boolean)
	if began and lorePanel.Visible then
		lorePanel.Visible = false
	end
end

-- Room sound --------------------------------------------------------------------------------------

local function updateSound(dt: number)
	local hidden = player:GetAttribute("Hidden") == true
	local reverb = World.reverb(hidden, player:GetAttribute("Area") == "Room", Settings.Reverb)
	SoundService.AmbientReverb = (Enum.ReverbType :: any)[reverb]

	local sprinting = Movement.getStance() == "Sprint"
	effort = Body.stepEffort(effort, sprinting, dt, Settings.Winded)
	local winded = Body.isWinded(effort, sprinting, Settings.Winded)
		or player:GetAttribute("Exhausted") == true
	if winded and not heavy then
		heavy = makeSound(Sounds.Heavy, Settings.Winded.Volume, true)
		if heavy then
			heavy:Play()
		end
	elseif not winded and heavy then
		heavy:Destroy()
		heavy = nil
	end
end

-- Storm -------------------------------------------------------------------------------------------

local function moonlights(): { SpotLight }
	local lights = {}
	local haunts = workspace:FindFirstChild("Haunts")
	for _, child in if haunts then haunts:GetChildren() else {} do
		local light = child.Name == "Moonlight" and child:FindFirstChildOfClass("SpotLight")
		if light then
			table.insert(lights, light)
		end
	end
	return lights
end

local function blacken(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.new(0, 0, 0)
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

-- A robot standing further down the aisle you're looking along. Client only, gone next flash.
local function placeSilhouette(rng: Random): Model?
	local rules = Settings.Storm.Silhouette
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		return nil
	end
	look = look.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	local origin = camera.CFrame.Position
	local distance = rng:NextNumber(rules.MinDistance, rules.MaxDistance)
	local hit = workspace:Raycast(origin, look * distance, params)
	if hit and (hit.Position - origin).Magnitude < rules.MinDistance then
		return nil
	end
	local spot = if hit then hit.Position - look * 3 else origin + look * distance
	local floor = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	local model = floor and ModelLibrary.get(rules.Models[rng:NextInteger(1, #rules.Models)])
	if not floor or not model then
		return nil
	end
	blacken(model)
	local facing = CFrame.lookAt(Vector3.zero, -look)
	model:PivotTo(facing)
	local box, size = model:GetBoundingBox()
	model:PivotTo(facing + (floor.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	model.Parent = camera
	return model
end

local function flashOnce(strength: number, hold: number, silhouette: Model?)
	local rules = Settings.Storm.Flash
	local savedAmbient, savedBrightness = Lighting.Ambient, Lighting.Brightness
	local lights = moonlights()
	local savedMoon = {}
	for index, light in lights do
		savedMoon[index] = light.Brightness
		light.Brightness *= 1 + (rules.MoonlightBoost - 1) * strength
	end
	Lighting.Ambient = savedAmbient:Lerp(rules.Ambient, strength)
	Lighting.Brightness = savedBrightness + rules.Brightness * strength
	task.wait(hold)
	if silhouette then
		silhouette:Destroy()
	end
	for index, light in lights do
		light.Brightness = savedMoon[index]
	end
	if isNight() then -- the Lighting controller owns these; never undo a phase change
		Lighting.Ambient, Lighting.Brightness = savedAmbient, savedBrightness
	end
end

local function onStorm(near: unknown, seed: unknown)
	if type(seed) ~= "number" or flashing or not isNight() then
		return
	end
	flashing = true
	local rng = Random.new(seed)
	local rules = Settings.Storm
	local strength = if near == true then 1 else 0.45
	local silhouette = if near == true and rng:NextNumber() < rules.Silhouette.Chance
		then placeSilhouette(Random.new(seed + player.UserId))
		else nil
	flashOnce(strength, rules.Flash.Hold, silhouette)
	task.wait(rules.Flash.Gap)
	flashOnce(strength * 0.8, rules.Flash.Hold, nil)
	flashing = false
	local delay = if near == true
		then rules.ThunderDelay[1]
		else World.between(rules.ThunderDelay, rng:NextNumber())
	task.delay(delay, playOnce, if near == true then Sounds.ThunderNear else Sounds.ThunderFar, 0.9)
end

-- Night ambience ----------------------------------------------------------------------------------

local function scheduleShelfNoise(token: number)
	local gap = World.between(Settings.Storm.ShelfNoiseGap, random:NextNumber())
	task.delay(gap, function()
		if token ~= nightToken then
			return
		end
		playOnce(
			if random:NextNumber() < 0.5 then Sounds.ShelfScrape else Sounds.ShelfThud,
			Settings.Storm.ShelfNoiseVolume
		)
		scheduleShelfNoise(token)
	end)
end

local function onPhase()
	nightToken += 1
	local night = isNight()
	if night and not rain then
		rain = makeSound(Sounds.Rain, Settings.Storm.RainVolume, true)
		if rain then
			rain:Play()
		end
	elseif not night and rain then
		rain:Destroy()
		rain = nil
	end
	if night then
		scheduleShelfNoise(nightToken)
	end
end

local function onAnnouncement(text: unknown, voice: unknown, glitch: unknown)
	if type(text) ~= "string" then
		return
	end
	local rules = Settings.PA
	playOnce(Sounds.Chime, rules.Volume)
	task.delay(rules.ChimeToLine, function()
		if type(voice) == "string" then
			Music.playVoiceLine(voice)
		end
		subtitleToken += 1
		showFor(subtitle, text, rules.SubtitleTime, subtitleToken, function()
			return subtitleToken
		end)
		if glitch == true then
			task.delay(rules.SubtitleTime * 0.6, playOnce, Sounds.Glitch, rules.Volume)
		end
	end)
end

function NightTricks.Start()
	breathRemote = Net.event("HoldBreath")
	buildGui()
	Input.bind("Jump", onJump)
	Input.bind("Use", onUse)
	Net.event("NightTricksNote").OnClientEvent:Connect(showNote)
	Net.event("LoreNote").OnClientEvent:Connect(showLore)
	Net.event("NightStorm").OnClientEvent:Connect(onStorm)
	Net.event("NightPA").OnClientEvent:Connect(onAnnouncement)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()

	local sinceSound = 0
	RunService.RenderStepped:Connect(function(dt)
		updateFlashlight()
		updateHiding()
		sinceSound += dt
		if sinceSound >= 0.25 then
			updateSound(sinceSound)
			sinceSound = 0
		end
	end)
end

return NightTricks
