-- Flips the store lighting with the clock: dim fluorescent day, red pulsing siren,
-- a flicker into near black at lights out, and lights snapping back on in the morning.
-- Also drives the warehouse strip lights: on by day, dark at night except the red emergency ones,
-- and the broken ones near you flicker (so do the always-on work lamps tagged to flicker).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClockEffects = require(ReplicatedStorage.Shared.Logic.ClockEffects)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.DayNight

local LightingController = {}

local effect: RBXScriptConnection?
local stripsOn = true
local LIGHT_TAG = "WarehouseLight"
local FLICKER_TAG = "FlickerLight"

local function setStrip(strip: BasePart, on: boolean)
	local glow = strip:FindFirstChildOfClass("SurfaceLight")
	local emergency = strip:GetAttribute("Emergency") == true
	if on then
		strip.Material = Enum.Material.Neon
		strip.Color = strip:GetAttribute("Glow") or strip.Color
		if glow then
			glow.Enabled = true
			glow.Color = strip:GetAttribute("LightColor") or glow.Color
			glow.Brightness = strip:GetAttribute("Brightness") or glow.Brightness
			glow.Range = strip:GetAttribute("Range") or glow.Range
		end
	elseif emergency then
		strip.Material = Enum.Material.Neon
		strip.Color = Settings.Emergency.Glow
		if glow then
			glow.Enabled = true
			glow.Color = Settings.Emergency.Light
			glow.Brightness = Settings.Emergency.Brightness
			glow.Range = Settings.Emergency.Range
		end
	else
		strip.Material = Enum.Material.SmoothPlastic
		strip.Color = Settings.DeadStripColor
		if glow then
			glow.Enabled = false
		end
	end
end

local function setAllStrips(on: boolean)
	stripsOn = on
	for _, strip in CollectionService:GetTagged(LIGHT_TAG) do
		if strip:IsA("BasePart") then
			setStrip(strip, on)
		end
	end
end

-- Broken strips near the camera blink at random while they have power
local function flickerNearby()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	for _, strip in CollectionService:GetTagged(FLICKER_TAG) do
		if
			strip:IsA("BasePart")
			and (stripsOn or strip:GetAttribute("Emergency") == true or strip:GetAttribute("AlwaysOn") == true)
			and (strip.Position - origin).Magnitude < Settings.FlickerRange
		then
			local lit = math.random() > 0.35
			strip.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local glow = strip:FindFirstChildWhichIsA("Light")
			if glow then
				glow.Enabled = lit
			end
		end
	end
end

local function apply(target)
	Lighting.Ambient = target.Ambient
	Lighting.OutdoorAmbient = target.OutdoorAmbient
	Lighting.Brightness = target.Brightness
	Lighting.ClockTime = target.ClockTime
	Lighting.ColorShift_Top = target.ColorShift_Top
	Lighting.ColorShift_Bottom = target.ColorShift_Bottom
	Lighting.FogColor = target.FogColor
	Lighting.FogStart = target.FogStart
	Lighting.FogEnd = target.FogEnd
	-- The Atmosphere belongs to the world build; only tune it, never make another.
	local haze = Lighting:FindFirstChild("Haze")
	if haze and haze:IsA("Atmosphere") then
		haze.Density = target.Haze.Density
		haze.Color = target.Haze.Color
		haze.Haze = target.Haze.Haze
	end
	local on = target == Settings.Lighting.Day
	if on ~= stripsOn then
		setAllStrips(on)
	end
end

local function stopEffect()
	if effect then
		effect:Disconnect()
		effect = nil
	end
end

local function runEffect(onFrame: (elapsed: number) -> boolean)
	stopEffect()
	local started = os.clock()
	effect = RunService.RenderStepped:Connect(function()
		if onFrame(os.clock() - started) then
			stopEffect()
		end
	end)
end

local function siren()
	local day = Settings.Lighting.Day
	apply(day)
	runEffect(function(elapsed)
		local pulse = ClockEffects.sirenPulse(elapsed, Settings.SirenFlashRate) * Settings.SirenStrength
		Lighting.Ambient = day.Ambient:Lerp(Settings.SirenColor, pulse)
		Lighting.OutdoorAmbient = day.OutdoorAmbient:Lerp(Settings.SirenColor, pulse)
		return false
	end)
end

local function lightsOut()
	local wasOn: boolean? = nil
	runEffect(function(elapsed)
		local on, done = ClockEffects.flicker(elapsed, Settings.FlickerPattern)
		if on ~= wasOn then
			wasOn = on
			apply(if on then Settings.Lighting.Day else Settings.Lighting.Night)
		end
		return done
	end)
end

local function show(phase: string, animate: boolean)
	if phase == "Siren" then
		siren()
	elseif phase == "Night" and animate then
		lightsOut()
	else
		stopEffect()
		apply(if phase == "Night" then Settings.Lighting.Night else Settings.Lighting.Day)
	end
end

function LightingController.Start()
	-- Streaming brings strips in and out as you walk: set each one as it arrives
	CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(function(strip)
		if strip:IsA("BasePart") then
			setStrip(strip, stripsOn)
		end
	end)
	local sinceFlicker = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceFlicker += dt
		if sinceFlicker >= 0.09 then
			sinceFlicker = 0
			flickerNearby()
		end
	end)
	Net.event("PhaseChanged").OnClientEvent:Connect(function(phase: string)
		show(phase, true)
	end)
	-- Joining mid-phase: match the current phase without replaying the lights-out flicker.
	show(ReplicatedStorage:GetAttribute("Phase") or "Day", false)
end

return LightingController
