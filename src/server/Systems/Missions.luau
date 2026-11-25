-- Daily missions: every morning each player gets a short list (find, visit, go deep, survive, hide,
-- haul) with item rewards, so a solo day always has a goal. Checked here on a slow tick from
-- public APIs and player attributes; nothing saves between sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MissionsLogic = require(ReplicatedStorage.Shared.Logic.Missions)
local Net = require(ReplicatedStorage.Shared.Net)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local Scores = require(script.Parent.Scores)
local Tokens = require(script.Parent.Tokens)
local Warehouse = require(script.Parent.Warehouse)

type Mission = MissionsLogic.Mission

local settings = Config.Missions

local Missions = {}

local lists: { [Player]: { Mission } } = {}
-- Alive when the night started and not died since
local survivors: { [Player]: boolean } = {}
local places: { MissionsLogic.Place } = {}
local ready = false
local stateRemote: RemoteEvent
local random = Random.new()

local function roll(): number
	return random:NextNumber()
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function send(player: Player, reason: string, finished: { Mission }?)
	local list = lists[player]
	if not list or not player.Parent then
		return
	end
	local done = {}
	for _, mission in finished or {} do
		table.insert(done, {
			text = mission.text,
			reward = MissionsLogic.rewardText(settings, mission.reward),
		})
	end
	stateRemote:FireClient(player, {
		reason = reason,
		day = DayNight.day(),
		rows = MissionsLogic.snapshot(settings, list),
		finished = done,
		allDone = MissionsLogic.allDone(list),
	})
end

local function reward(player: Player, finished: { Mission })
	for _, mission in finished do
		Inventory.add(player, mission.reward.item, mission.reward.count)
		Scores.add(player, "MissionsDone", 1)
		Tokens.add(player, Config.Dawn.Tokens.Mission)
	end
end

local function newList(player: Player, reason: string)
	local context = { places = places, canSurvive = DayNight.phase() ~= "Night" }
	lists[player] = MissionsLogic.pick(settings, context, roll)
	send(player, reason)
end

local function check(player: Player, list: { Mission })
	local root = aliveRoot(player)
	if not root then
		return
	end
	local pocket = Warehouse.pocketAt(root.Position)
	local facts: MissionsLogic.Facts = {
		count = function(itemId)
			return Inventory.count(player, itemId)
		end,
		place = pocket and pocket.kind,
		depth = Warehouse.depth(root.Position),
		hidden = player:GetAttribute("Hidden") == true,
		hauling = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
	}
	local finished = {}
	for _, mission in list do
		if MissionsLogic.check(mission, facts, settings.CheckInterval) then
			table.insert(finished, mission)
		end
	end
	if #finished > 0 then
		reward(player, finished)
		send(player, "done", finished)
	end
end

local function onPhaseChanged(phase: string, previous: string)
	if not ready then
		return
	end
	if phase == "Night" then
		for _, player in Players:GetPlayers() do
			survivors[player] = aliveRoot(player) ~= nil or nil
		end
	elseif phase == "Day" then
		for _, player in Players:GetPlayers() do
			local list = lists[player]
			if list and previous == "Night" then
				local survived = survivors[player] == true and aliveRoot(player) ~= nil
				local finished = MissionsLogic.dawn(list, survived)
				if #finished > 0 then
					reward(player, finished)
					send(player, "done", finished)
				end
			end
			newList(player, "morning")
		end
		table.clear(survivors)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			survivors[player] = nil
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	if ready then
		newList(player, "join")
	end
end

local function findPlaces()
	for _, pocket in Warehouse.layout().pockets do
		local middle = Warehouse.toWorld((pocket.x0 + pocket.x1) / 2, (pocket.z0 + pocket.z1) / 2)
		table.insert(places, { kind = pocket.kind, depth = Warehouse.depth(middle) })
	end
end

local function waitForWarehouse()
	local root = workspace:FindFirstChild("Warehouse")
	while not (root and root:GetAttribute("Built")) do
		task.wait(1)
		root = workspace:FindFirstChild("Warehouse")
	end
end

function Missions.Init()
	stateRemote = Net.event("MissionsState")
end

function Missions.Start()
	Net.event("MissionsSync").OnServerEvent:Connect(function(player)
		send(player, "sync")
	end)
	DayNight.onPhaseChanged(onPhaseChanged)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lists[player] = nil
		survivors[player] = nil
	end)

	task.spawn(function()
		waitForWarehouse()
		findPlaces()
		ready = true
		for _, player in Players:GetPlayers() do
			newList(player, "join")
		end
		while true do
			task.wait(settings.CheckInterval)
			for player, list in lists do
				check(player, list)
			end
		end
	end)
end

return Missions
