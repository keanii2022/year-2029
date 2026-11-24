-- On-screen basics: health bar, ammo, crosshair, hit marker and the "down" screen.
-- Clean and dark; warnings use the red spray-paint look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local CombatLogic = require(ReplicatedStorage.Shared.Logic.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local Gun = require(script.Parent.Gun)

local settings = Config.Guns
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local LOW_HEALTH = 0.3

local Hud = {}

local gui: ScreenGui
local healthFill: Frame
local ammoLabel: TextLabel
local ammoPanel: Frame
local hitMarker: Frame
local downScreen: Frame
local countdownLabel: TextLabel
local hitMarkerUntil = 0

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
			Size = UDim2.fromOffset(2, 30),
			Rotation = angle,
			BackgroundColor3 = TEXT,
		}, hitMarker)
	end
end

local function buildHealth()
	local panel = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(240, 14),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
	}, gui)
	healthFill = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = TEXT,
	}, panel)
	label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(120, 14),
		Text = "HEALTH",
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
end

local function buildAmmo()
	ammoPanel = frame({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(160, 44),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	ammoLabel = label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0",
	}, ammoPanel)
	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(120, 14),
		Text = "CELLS",
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, ammoPanel)
end

local function buildDownScreen()
	downScreen = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 10,
	}, gui)
	label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(600, 140),
		Rotation = -4,
		Font = Enum.Font.PermanentMarker,
		Text = "YOU WENT DOWN",
		TextColor3 = SPRAY_RED,
		TextSize = 72,
		ZIndex = 11,
	}, downScreen)
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(600, 24),
		Text = "Your stuff is where you fell.",
		TextSize = 18,
		TextTransparency = 0.2,
		ZIndex = 11,
	}, downScreen)
	countdownLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(600, 24),
		Text = "",
		TextSize = 16,
		TextTransparency = 0.4,
		ZIndex = 11,
	}, downScreen)
end

local function refreshAmmo()
	local mag, reserve, reloading = Gun.getMagazine()
	ammoPanel.Visible = mag ~= nil
	if mag and reserve then
		local empty = mag + reserve <= 0
		ammoLabel.Text = if reloading then "RELOADING" elseif empty then "EMPTY" else `{mag} / {reserve}`
		ammoLabel.TextSize = if reloading then 22 else 34
		ammoLabel.Font = if empty then Enum.Font.PermanentMarker else Enum.Font.GothamBold
		ammoLabel.TextColor3 = if empty or (mag <= 0 and not reloading) then SPRAY_RED else TEXT
	end
end

local function showHitMarker(down: boolean)
	hitMarkerUntil = os.clock() + settings.HitMarkerTime * (if down then 3 else 1)
	for _, line in hitMarker:GetChildren() do
		(line :: Frame).BackgroundColor3 = if down then SPRAY_RED else TEXT
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

	local downUntil = player:GetAttribute("DownUntil")
	downScreen.Visible = type(downUntil) == "number"
	if type(downUntil) == "number" then
		local left = CombatLogic.respawnSecondsLeft(downUntil, workspace:GetServerTimeNow())
		countdownLabel.Text = if left > 0 then `Back in {left}` else "Coming back..."
	end
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
	buildDownScreen()
end

function Hud.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Gun.onChanged(refreshAmmo)
	Gun.onHit(showHitMarker)
	refreshAmmo()
	RunService.RenderStepped:Connect(update)
end

return Hud
