-- On-screen basics: health bar with a stance tag, Tokens, ammo, the phase clock, crosshair, hit
-- marker, the "down" screen (what got you, on top of every menu) and a marker to your dropped pile
-- once you're back. Clean and dark; warnings use the red spray-paint look. On a phone the health
-- bar moves top-left by the ? / RECORD buttons and the ammo sits above the gun buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local Clock = require(ReplicatedStorage.Shared.Logic.Clock)
local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Glyphs = require(script.Parent.Glyphs)
local Gun = require(script.Parent.Gun)
local TouchButtons = require(script.Parent.TouchButtons)

local settings = Config.Guns
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local LOW_HEALTH = 0.3
local PILE_SECONDS = 60 -- the dropped-pile marker fades out over this long
local AMMO_TOUCH_AT = Vector2.new(-246, -168) -- above AIM / RELOAD, in TouchButtons' layout
local HEALTH_TOUCH_AT = Vector2.new(156, 90) -- right of the ? / RECORD buttons
local PHASE_WORDS = { Day = "DAY", Siren = "LIGHTS OUT", Night = "NIGHT" }
local TOUCH_BAR_WIDTH = 220 -- leaves room for the TODAY list on a 667-wide phone

local Hud = {}

local gui: ScreenGui
local downGui: ScreenGui
local healthPanel: Frame
local healthFill: Frame
local healthTitle: TextLabel
local ammoLabel: TextLabel
local reserveLabel: TextLabel
local ammoKindLabel: TextLabel
local ammoPanel: Frame
local clockLabel: TextLabel
local hitMarker: Frame
local downScreen: Frame
local downByLabel: TextLabel
local countdownLabel: TextLabel
local tokensLabel: TextLabel
local pileMarker: BillboardGui? = nil
local pileLabel: TextLabel? = nil
local pileShownAt = 0
local hitMarkerUntil = 0
local hitMarkerShownAt = 0
local hitMarkerScale: UIScale

local function frame(props: { [string]: any }, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT
	l.Font = Enum.Font.GothamBold
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function buildCrosshair()
	local center = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
	}, gui)
	frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = 0.15,
	}, center)
	for _, offset in { Vector2.new(0, -11), Vector2.new(0, 11), Vector2.new(-11, 0), Vector2.new(11, 0) } do
		local vertical = offset.X == 0
		frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			Size = if vertical then UDim2.fromOffset(2, 7) else UDim2.fromOffset(7, 2),
			BackgroundColor3 = TEXT,
			BackgroundTransparency = 0.35,
		}, center)
	end

	hitMarker = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	for _, angle in { 45, -45 } do
		frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3, 30),
			Rotation = angle,
			BackgroundColor3 = TEXT,
		}, hitMarker)
	end
	hitMarkerScale = Instance.new("UIScale")
	hitMarkerScale.Parent = hitMarker
end

local function buildHealth()
	local panel = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(240, 14),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
	}, gui)
	healthPanel = panel
	healthFill = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = TEXT,
	}, panel)
	healthTitle = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(120, 14),
		Text = "HEALTH",
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
end

local function refreshTokens()
	local tokens = player:GetAttribute("Tokens")
	tokensLabel.Text = if type(tokens) == "number" then `TOKENS {tokens}` else ""
end

local function buildAmmo()
	ammoPanel = frame({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(160, 44),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	-- The mag big, the reserve small beside it: "12 +24"
	local row = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, ammoPanel)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	ammoLabel = label({
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 34,
		Text = "0",
	}, row)
	reserveLabel = label({
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 16,
		TextTransparency = 0.35,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "",
	}, row)
	ammoKindLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(120, 14),
		Text = "CELLS",
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, ammoPanel)
end

-- Top centre, clear of Roblox's corner buttons: time left in this phase, red through the siren
local function buildClock()
	clockLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(200, 22),
		Text = "",
		TextSize = 16,
		TextTransparency = 0.2,
		TextStrokeTransparency = 0.6,
	}, gui)
	-- Tokens sit quietly under the clock, away from the health block
	tokensLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 38),
		Size = UDim2.fromOffset(200, 14),
		Text = "",
		TextSize = 12,
		TextTransparency = 0.4,
		TextStrokeTransparency = 0.7,
	}, gui)
end

local function buildDownScreen()
	-- Its own gui so it covers the bag, containers, menus and hints
	downGui = Instance.new("ScreenGui")
	downGui.Name = "Down"
	downGui.ResetOnSpawn = false
	downGui.IgnoreGuiInset = true
	downGui.DisplayOrder = 10
	downScreen = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 10,
	}, downGui)
	local title = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, -40, 0, 140),
		Rotation = -4,
		Font = Enum.Font.PermanentMarker,
		Text = "YOU WENT DOWN",
		TextColor3 = SPRAY_RED,
		TextScaled = true,
		ZIndex = 11,
	}, downScreen)
	local fitTitle = Instance.new("UITextSizeConstraint")
	fitTitle.MaxTextSize = 72
	fitTitle.Parent = title
	downByLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		TextSize = 20,
		ZIndex = 11,
	}, downScreen)
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.59),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "Your stuff is where you fell.",
		TextSize = 18,
		TextTransparency = 0.2,
		ZIndex = 11,
	}, downScreen)
	countdownLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		TextSize = 16,
		TextTransparency = 0.4,
		ZIndex = 11,
	}, downScreen)
end

local function refreshAmmo()
	local mag, reserve, reloading = Gun.getMagazine()
	ammoPanel.Visible = mag ~= nil
	ammoKindLabel.Text = Gun.getAmmoLabel() or ""
	if mag and reserve then
		local empty = mag + reserve <= 0
		ammoLabel.Text = if reloading then "RELOADING" elseif empty then "EMPTY" else tostring(mag)
		reserveLabel.Text = if reloading or empty then "" else `+{reserve}`
		reserveLabel.Visible = reserveLabel.Text ~= ""
		ammoLabel.TextSize = if reloading then 22 else 34
		ammoLabel.Font = if empty then Enum.Font.PermanentMarker else Enum.Font.GothamBold
		ammoLabel.TextColor3 = if empty or (mag <= 0 and not reloading) then SPRAY_RED else TEXT
	end
end

local function updateClock()
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local word = PHASE_WORDS[phase]
	if not word then
		clockLabel.Text = ""
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
	local frozen = ReplicatedStorage:GetAttribute("ClockFrozen") == true
	clockLabel.Text = if frozen or type(endsAt) ~= "number"
		then word
		else `{word}  {Clock.readout(endsAt - workspace:GetServerTimeNow())}`
	local siren = phase == "Siren"
	clockLabel.TextColor3 = if siren then SPRAY_RED else TEXT
	clockLabel.Font = if siren then Enum.Font.PermanentMarker else Enum.Font.GothamBold
	clockLabel.TextSize = if siren then 22 else 16
end

-- Back on your feet: a marker over the pile you dropped, fading out over PILE_SECONDS
local function showPileMarker(at: Vector3)
	if pileMarker then
		pileMarker:Destroy()
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "DroppedPile"
	anchor.Parent = workspace.Terrain
	anchor.Position = at
	local marker = Instance.new("BillboardGui")
	marker.Name = "DroppedPile"
	marker.Size = UDim2.fromOffset(160, 24)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	marker.AlwaysOnTop = true
	marker.ResetOnSpawn = false
	marker.Adornee = anchor
	pileLabel = label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 18,
		TextStrokeTransparency = 0.5,
	}, marker)
	-- The anchor goes with the marker
	marker.Destroying:Once(function()
		anchor:Destroy()
	end)
	marker.Parent = player:WaitForChild("PlayerGui")
	pileMarker = marker
	pileShownAt = os.clock()
end

local function updatePileMarker()
	local marker, text = pileMarker, pileLabel
	if not marker or not text then
		return
	end
	local share = (os.clock() - pileShownAt) / PILE_SECONDS
	local anchor = marker.Adornee :: Attachment?
	if share >= 1 or not anchor then
		marker:Destroy()
		pileMarker, pileLabel = nil, nil
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local distance = if root then math.floor((root.Position - anchor.WorldPosition).Magnitude) else nil
	text.Text = if distance then `YOUR STUFF  {distance}` else "YOUR STUFF"
	text.TextTransparency = share * share
	text.TextStrokeTransparency = 0.5 + 0.5 * share
end

-- Phone: health top-left by the ? / RECORD buttons, ammo above the gun buttons, bigger small print
local function place()
	local touch = Glyphs.device() == "Touch"
	if touch then
		healthPanel.AnchorPoint = Vector2.zero
		healthPanel.Position = UDim2.fromOffset(HEALTH_TOUCH_AT.X, HEALTH_TOUCH_AT.Y)
		healthPanel.Size = UDim2.fromOffset(TOUCH_BAR_WIDTH, 14)
		ammoPanel.Position = TouchButtons.place(AMMO_TOUCH_AT)
	else
		healthPanel.AnchorPoint = Vector2.new(0, 1)
		healthPanel.Position = UDim2.new(0, 24, 1, -24)
		healthPanel.Size = UDim2.fromOffset(240, 14)
		ammoPanel.Position = UDim2.new(1, -24, 1, -20)
	end
	local small = if touch then 14 else 12
	for _, text in { healthTitle, tokensLabel, ammoKindLabel } do
		text.TextSize = small
	end
end

local function showHitMarker(down: boolean)
	hitMarkerShownAt = os.clock()
	hitMarkerUntil = hitMarkerShownAt + settings.HitMarkerTime * (if down then 3 else 1)
	for _, line in hitMarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = if down then SPRAY_RED else TEXT
		end
	end
end

local function update()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = if humanoid and humanoid.MaxHealth > 0
		then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		else 0
	healthFill.Size = UDim2.fromScale(health, 1)
	healthFill.BackgroundColor3 = if health <= LOW_HEALTH then SPRAY_RED else TEXT

	hitMarker.Visible = os.clock() < hitMarkerUntil
	-- Pops in big and snaps down to size, so each hit reads as a hit.
	local pop = math.clamp(1 - (os.clock() - hitMarkerShownAt) / settings.HitMarkerTime, 0, 1)
	hitMarkerScale.Scale = 1 + (settings.HitMarkerPop - 1) * pop * pop

	local downUntil = player:GetAttribute("DownUntil")
	downScreen.Visible = type(downUntil) == "number"
	if type(downUntil) == "number" then
		local left = CombatLogic.respawnSecondsLeft(downUntil, workspace:GetServerTimeNow())
		countdownLabel.Text = if left > 0 then `Back in {left}` else "Coming back..."
		local by = player:GetAttribute("DownBy")
		downByLabel.Text = if type(by) == "string" then by else ""
	end

	updateClock()
	updatePileMarker()
end

local function isDown(): boolean
	return type(player:GetAttribute("DownUntil")) == "number"
end

local function playDownZap()
	local id = ModelLibrary.soundId(settings.DownSound)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = settings.DownSoundVolume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function Hud.Init()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	buildCrosshair()
	buildHealth()
	buildAmmo()
	buildClock()
	buildDownScreen()
end

function Hud.Start()
	-- No reset button: every spawn hands out the kit, so resetting would be free ammo.
	-- SetCore errors until the core scripts have registered it, so keep trying.
	task.spawn(function()
		for _ = 1, 30 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				return
			end
			task.wait(1)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	downGui.Parent = gui.Parent
	Glyphs.onChanged(place)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	place()
	Gun.onChanged(refreshAmmo)
	Gun.onHit(showHitMarker)
	refreshAmmo()
	player:GetAttributeChangedSignal("Tokens"):Connect(refreshTokens)
	refreshTokens()
	RunService.RenderStepped:Connect(update)
	local wasDown = isDown()
	player:GetAttributeChangedSignal("DownUntil"):Connect(function()
		local down = isDown()
		if down and not wasDown then
			playDownZap()
		elseif wasDown and not down then
			local pile = player:GetAttribute("DownAt")
			if typeof(pile) == "Vector3" then
				showPileMarker(pile)
			end
		end
		wasDown = down
	end)
end

return Hud
