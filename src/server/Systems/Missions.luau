-- Daily missions: every morning each player gets a short list (find, visit, go deep, survive, hide,
-- haul) with item rewards, plus a lore mission pointing at the day's 2029 Files piece. Brand-new
-- saves get the first-day chain instead (drag a prop, loot a robot room, bank, survive), one step
-- live at a time, until they finish it. Live missions with a place to go send an arrow target.
-- Finishing a whole list counts the day toward the saved daily streak. Checked here on a slow tick
-- from public APIs and player attributes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MissionsLogic = require(ReplicatedStorage.Shared.Logic.Missions)
local Net = require(ReplicatedStorage.Shared.Net)
local StreakLogic = require(ReplicatedStorage.Shared.Logic.Streak)
local DayNight = require(script.Parent.DayNight)
local Files = require(script.Parent.Files)
local Inventory = require(script.Parent.Inventory)
local Saves = require(script.Parent.Saves)
local Scores = require(script.Parent.Scores)
local Tokens = require(script.Parent.Tokens)
local Warehouse = require(script.Parent.Warehouse)

type Mission = MissionsLogic.Mission

local settings = Config.Missions

local Missions = {}

local lists: { [Player]: { Mission } } = {}
-- Alive when the night started (or first spawned this session after it started) and not died since
local survivors: { [Player]: boolean } = {}
local hadLife: { [Player]: boolean } = {}
local places: { MissionsLogic.Place } = {}
local ready = false
local stateRemote: RemoteEvent
local random = Random.new()

local function roll(): number
	return random:NextNumber()
end

local function fill(text: string, values: { [string]: string }): string
	return (string.gsub(text, "{(%w+)}", function(key)
		return values[key]
	end))
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- A session that can't save loads defaults, which would look brand new; only trust a real save
local function isFirstDay(player: Player): boolean
	local data = Saves.data(player)
	return data ~= nil and data.firstDay and Saves.canSave(player)
end

local function today(): number
	return StreakLogic.dayOf(os.time())
end

local function streakLabel(player: Player): string
	local data = Saves.data(player)
	return if data then StreakLogic.label(settings.Streak, data.streak, today()) else ""
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
	local chain = list[1] ~= nil and list[1].chain == true
	stateRemote:FireClient(player, {
		reason = reason,
		day = DayNight.day(),
		title = if chain then settings.FirstDay.Title else settings.ListTitle,
		streak = streakLabel(player),
		rows = MissionsLogic.snapshot(settings, list),
		finished = done,
		allDone = MissionsLogic.allDone(list),
	})
end

-- The list just got finished: count today toward the streak, pay its milestones, end the first day
local function onListDone(player: Player, list: { Mission })
	local data = Saves.data(player)
	if not data or not Saves.canSave(player) then
		return
	end
	if list[1] and list[1].chain then
		data.firstDay = false
		Saves.tell(player, settings.FirstDay.DoneLine)
	end
	local before = data.streak.days
	if StreakLogic.complete(data.streak, today()) then
		Saves.markDirty(player, true)
		Scores.raise(player, "StreakDays", data.streak.days)
		local days = tostring(data.streak.days)
		task.delay(2.5, Saves.tell, player, fill(settings.Streak.CountedLine, { days = days }))
		for _, milestone in StreakLogic.rewardsReached(settings.Streak.Rewards, before, data.streak.days) do
			local paid = Tokens.add(player, milestone.tokens)
			local line =
				fill(settings.Streak.RewardLine, { days = tostring(milestone.day), tokens = tostring(paid) })
			task.delay(5, Saves.tell, player, line)
		end
	end
end

local function reward(player: Player, list: { Mission }, finished: { Mission })
	for _, mission in finished do
		Inventory.add(player, mission.reward.item, mission.reward.count)
		Scores.add(player, "MissionsDone", 1)
		Tokens.add(player, Config.Dawn.Tokens.Mission)
	end
	if #finished > 0 and MissionsLogic.allDone(list) then
		onListDone(player, list)
	end
end

local function newList(player: Player, reason: string)
	local current = lists[player]
	if isFirstDay(player) then
		-- An unfinished chain carries over to the next day
		if not (current and current[1] and current[1].chain and not MissionsLogic.allDone(current)) then
			lists[player] = MissionsLogic.firstDay(settings)
		end
	else
		local context = { places = places, canSurvive = DayNight.phase() ~= "Night" }
		local list = MissionsLogic.pick(settings, context, roll)
		if Files.piecePosition() then
			table.insert(list, MissionsLogic.lore(settings, roll))
		end
		lists[player] = list
	end
	send(player, reason)
end

-- Arrow targets ----------------------------------------------------------------------------------

local function nearest(position: Vector3, candidates: { Vector3 }): Vector3?
	local best, bestDistance = nil, math.huge
	for _, candidate in candidates do
		local distance = (candidate - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

-- Loose props nobody has placed yet: the ones worth dragging to start a fort
local function propSpots(): { Vector3 }
	local spots = {}
	for _, prop in CollectionService:GetTagged(Config.Grab.Tag) do
		if
			prop:IsA("PVInstance")
			and prop:IsDescendantOf(workspace)
			and prop:GetAttribute("PlacedBy") == nil
		then
			table.insert(spots, prop:GetPivot().Position)
		end
	end
	return spots
end

local function roomSpots(): { Vector3 }
	local spots = {}
	for _, room in Warehouse.rooms() do
		table.insert(spots, Warehouse.toWorld(room.cx, room.cz))
	end
	return spots
end

local function lockerSpots(): { Vector3 }
	local spots = {}
	local lockers = workspace:FindFirstChild("Lockers")
	for _, locker in if lockers then lockers:GetChildren() else {} do
		if locker:IsA("Model") then
			table.insert(spots, locker:GetPivot().Position)
		end
	end
	return spots
end

local function targetFor(kind: string, position: Vector3): Vector3?
	if kind == "haul" then
		return nearest(position, propSpots())
	elseif kind == "loot" then
		return nearest(position, roomSpots())
	elseif kind == "bank" then
		return nearest(position, lockerSpots())
	elseif kind == "lore" then
		return Files.piecePosition()
	end
	return nil
end

-- True when any live target appeared, went, or moved far enough to be worth resending
local function updateTargets(live: { Mission }, position: Vector3): boolean
	local changed = false
	for _, mission in live do
		local target = targetFor(mission.kind, position)
		local old = mission.target
		if
			(target == nil) ~= (old == nil)
			or (target and old and (target - old).Magnitude > settings.TargetResend)
		then
			mission.target = target
			changed = true
		end
	end
	return changed
end

-- Ticking ----------------------------------------------------------------------------------------

local function itemTotal(stacks: { { count: number } }): number
	local total = 0
	for _, stack in stacks do
		total += stack.count
	end
	return total
end

local function check(player: Player, list: { Mission })
	local root = aliveRoot(player)
	if not root then
		return
	end
	local data = Saves.data(player)
	local pocket = Warehouse.pocketAt(root.Position)
	local facts: MissionsLogic.Facts = {
		count = function(itemId)
			return Inventory.count(player, itemId)
		end,
		place = pocket and pocket.kind,
		depth = Warehouse.depth(root.Position),
		hidden = player:GetAttribute("Hidden") == true,
		hauling = player:GetAttribute("CarrySpeedMultiplier") ~= nil,
		inRoom = Warehouse.roomAt(root.Position) ~= nil,
		carried = itemTotal(Inventory.list(player)),
		banked = if data then itemTotal(data.locker) else 0,
		readLore = Files.readToday(player),
	}
	local live = MissionsLogic.active(list)
	local finished = {}
	for _, mission in live do
		if MissionsLogic.check(mission, facts, settings.CheckInterval) then
			table.insert(finished, mission)
		end
	end
	if #finished > 0 then
		reward(player, list, finished)
		updateTargets(MissionsLogic.active(list), root.Position)
		send(player, "done", finished)
	elseif updateTargets(live, root.Position) then
		send(player, "target")
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
					reward(player, list, finished)
					send(player, "done", finished)
				end
			end
			if Saves.isLoaded(player) then
				newList(player, "morning")
			end
		end
		table.clear(survivors)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- First spawn of the session after lights out counts as there for the night, as in Dawn
	if not hadLife[player] and DayNight.phase() == "Night" then
		survivors[player] = true
	end
	hadLife[player] = true
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
	-- The list waits for the save: whether it's the first-day chain depends on it
	Saves.onLoaded(function(player)
		if ready then
			newList(player, "join")
		end
	end)
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
		hadLife[player] = nil
	end)

	task.spawn(function()
		waitForWarehouse()
		findPlaces()
		ready = true
		for _, player in Players:GetPlayers() do
			if Saves.isLoaded(player) then
				newList(player, "join")
			end
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
