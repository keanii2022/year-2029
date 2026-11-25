-- Logs the new-player funnel (Config/Funnel) with AnalyticsService, once per step per player per
-- session. The starting kit doesn't count as loot.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Funnel = require(ReplicatedStorage.Shared.Logic.Funnel)
local DayNight = require(script.Parent.DayNight)
local Grab = require(script.Parent.Grab)
local Inventory = require(script.Parent.Inventory)

local FunnelSystem = {}

local steps = Config.Funnel.Steps
local progress: { [Player]: Funnel.Progress } = {}
local aliveAtLightsOut: { [Player]: boolean } = {}
local kitItems: { [string]: boolean } = {}
for _, item in Config.Guns.StartingLoadout do
	kitItems[item.id] = true
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function reach(player: Player, name: string)
	local mine = progress[player]
	if not mine then
		mine = {}
		progress[player] = mine
	end
	for _, index in Funnel.reach(mine, steps, name) do
		-- Analytics can refuse calls in Studio or under load; the game never waits on it
		pcall(
			AnalyticsService.LogOnboardingFunnelStepEvent,
			AnalyticsService,
			player,
			index,
			steps[index].name
		)
	end
end

function FunnelSystem.Start()
	Players.PlayerAdded:Connect(function(player)
		reach(player, "Joined")
	end)
	for _, player in Players:GetPlayers() do
		reach(player, "Joined")
	end
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
		aliveAtLightsOut[player] = nil
	end)
	Inventory.onAdded(function(player, itemId)
		if typeof(player) == "Instance" and player:IsA("Player") and not kitItems[itemId] then
			reach(player, "FirstLoot")
		end
	end)
	Grab.onGrabbed(function(player)
		reach(player, "FirstGrab")
	end)
	DayNight.onPhaseChanged(function(phase, previous)
		if phase == "Siren" then
			for _, player in Players:GetPlayers() do
				if alive(player) then
					reach(player, "HeardSiren")
				end
			end
		elseif phase == "Night" then
			table.clear(aliveAtLightsOut)
			for _, player in Players:GetPlayers() do
				aliveAtLightsOut[player] = alive(player) or nil
			end
		elseif phase == "Day" and previous == "Night" then
			for player in aliveAtLightsOut do
				if player.Parent and alive(player) then
					reach(player, "SurvivedNight")
				end
			end
			table.clear(aliveAtLightsOut)
		end
	end)
end

return FunnelSystem
