-- Flips the store lighting with the clock: dim fluorescent day, red pulsing siren,
-- a flicker into near black at lights out, and lights snapping back on in the morning.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClockEffects = require(ReplicatedStorage.Shared.Logic.ClockEffects)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.DayNight

local LightingController = {}

local effect: RBXScriptConnection?

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
	Net.event("PhaseChanged").OnClientEvent:Connect(function(phase: string)
		show(phase, true)
	end)
	-- Joining mid-phase: match the current phase without replaying the lights-out flicker.
	show(ReplicatedStorage:GetAttribute("Phase") or "Day", false)
end

return LightingController
