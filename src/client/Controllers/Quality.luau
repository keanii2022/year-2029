-- Lighter on phones and slow devices. Picks "high" or "low" and publishes it as the local player's
-- "Quality" attribute for other controllers to read. On low it does what it can from outside them:
-- no shadows from your own flashlight beam, thinner dust under the lights, and no environment
-- lighting (Lighting.Technology itself can't change at runtime).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Settings = Config.Quality
local player = Players.LocalPlayer
-- Made by the Flashlight and Life controllers
local BEAM_NAME = "FlashlightBeam"
local DUST_FOLDER = "LifeFx"

local Quality = {}

local level = "high"

local function lightenBeam(beam: Instance)
	if beam.Name ~= BEAM_NAME then
		return
	end
	for _, child in beam:GetChildren() do
		if child:IsA("Light") then
			child.Shadows = false
		end
	end
end

local function lightenEmitter(instance: Instance)
	if instance:IsA("ParticleEmitter") then
		instance.Rate = math.min(instance.Rate, Settings.MaxParticleRate)
	end
end

local function watchDust(folder: Instance)
	for _, descendant in folder:GetDescendants() do
		lightenEmitter(descendant)
	end
	folder.DescendantAdded:Connect(lightenEmitter)
end

local function goLow()
	if level == "low" then
		return
	end
	level = "low"
	player:SetAttribute("Quality", level)

	local camera = workspace.CurrentCamera
	for _, child in camera:GetChildren() do
		lightenBeam(child)
	end
	camera.ChildAdded:Connect(lightenBeam)

	local dust = workspace:FindFirstChild(DUST_FOLDER)
	if dust then
		watchDust(dust)
	else
		task.spawn(function()
			watchDust(workspace:WaitForChild(DUST_FOLDER))
		end)
	end

	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
end

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Averages frame time over the last Window seconds and drops to low the first time it's too slow
local function watchFrameRate()
	local frames, elapsed = 0, 0
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if os.clock() - started < Settings.Grace then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed >= Settings.Window then
			if frames / elapsed < Settings.LowFps then
				connection:Disconnect()
				goLow()
			end
			frames, elapsed = 0, 0
		end
	end)
end

function Quality.Init()
	player:SetAttribute("Quality", level)
end

function Quality.Start()
	if touchOnly() then
		goLow()
	else
		watchFrameRate()
	end
end

return Quality
