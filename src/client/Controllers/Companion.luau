-- Robot companions, client side: the Build prompt only for the robot's bonded owner, eyes that
-- flicker during the siren, and one short hint the first time each part of it matters. Trust is
-- never shown as a number; the robot's body language and sounds carry it (Systems/Companion).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Hints = require(script.Parent.Hints)

local settings = Config.Companion
local hints = settings.Hints
local player = Players.LocalPlayer

local Companion = {}

local HINT_EVERY = 0.5

local anchors: { [Part]: true } = {}
local flickering: { [BasePart]: number } = {} -- eye part -> its transparency before the flicker

local function refreshBuild(anchor: Part)
	local build = anchor:FindFirstChild("Build")
	if build and build:IsA("ProximityPrompt") then
		build.Enabled = anchor:GetAttribute("Owner") == player.UserId
			and anchor:GetAttribute("Bonded") == true
	end
end

local function onAnchor(instance: Instance)
	if not instance:IsA("Part") then
		return
	end
	local anchor = instance
	anchors[anchor] = true
	refreshBuild(anchor)
	for _, name in { "Owner", "Bonded" } do
		anchor:GetAttributeChangedSignal(name):Connect(function()
			refreshBuild(anchor)
		end)
	end
	anchor.ChildAdded:Connect(function()
		refreshBuild(anchor)
	end)
end

local function robotsFolder(): Instance?
	return workspace:FindFirstChild("Robots")
end

-- Siren: an owned robot's eyes stutter on and off until lights out.
local function flicker(now: number)
	local folder = robotsFolder()
	local on = math.floor(now * settings.FlickerRate) % 3 ~= 0
	local seen = {}
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("Flicker") == true then
			local eyes = model:FindFirstChild(Config.Robots.EyePart, true)
			if eyes and eyes:IsA("BasePart") then
				seen[eyes] = true
				if flickering[eyes] == nil then
					flickering[eyes] = eyes.Transparency
				end
				eyes.Transparency = if on then flickering[eyes] else 1
			end
		end
	end
	for eyes, before in flickering do
		if not seen[eyes] then
			flickering[eyes] = nil
			if eyes.Parent then
				eyes.Transparency = before
			end
		end
	end
end

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function showHints()
	local position = myPosition()
	if not position then
		return
	end
	local folder = robotsFolder()
	for _, model in if folder then folder:GetChildren() else {} do
		if not model:IsA("Model") or model:GetAttribute("Curious") ~= true then
			continue
		end
		local owner = model:GetAttribute("Owner")
		local close = (model:GetPivot().Position - position).Magnitude <= hints.HintRange
		if close and model:GetAttribute("Wants") and (owner == nil or owner == player.UserId) then
			Hints.nudge("robot_wants", hints.Wants)
		end
	end
	for anchor in anchors do
		local close = anchor.Parent and (anchor.Position - position).Magnitude <= hints.HintRange
		if close and anchor:GetAttribute("Down") == true then
			Hints.nudge("robot_down", hints.Down)
		end
	end
end

local function onStage()
	local stage = player:GetAttribute("RobotStage")
	if stage == "watching" then
		Hints.nudge("robot_watching", hints.Watching)
	elseif stage == "bonded" then
		Hints.nudge("robot_bonded", hints.Bonded)
	end
end

function Companion.Start()
	if not settings.Enabled then
		return
	end
	CollectionService:GetInstanceAddedSignal("CompanionAnchor"):Connect(onAnchor)
	CollectionService:GetInstanceRemovedSignal("CompanionAnchor"):Connect(function(instance)
		anchors[instance :: Part] = nil
	end)
	for _, instance in CollectionService:GetTagged("CompanionAnchor") do
		onAnchor(instance)
	end
	player:GetAttributeChangedSignal("RobotStage"):Connect(onStage)
	RunService.RenderStepped:Connect(function()
		flicker(os.clock())
	end)
	task.spawn(function()
		while true do
			task.wait(HINT_EVERY)
			showHints()
		end
	end)
end

return Companion
