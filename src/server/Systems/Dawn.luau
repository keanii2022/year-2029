-- The morning payoff. At the siren every locker lights a dim beam until lights out, and each
-- player's locker is noted; whatever they add before lights out is "banked tonight". At lights out
-- the props players placed are noted too. When the lights come back on, every player who was alive
-- at lights out and still is gets the Dawn Report: their life streak, bag, fort pieces still
-- standing, dog, banked items and the Tokens it all paid. Dying resets the streak.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DawnScore = require(ReplicatedStorage.Shared.Logic.DawnScore)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local InventoryLogic = require(ReplicatedStorage.Shared.Logic.Inventory)
local Net = require(ReplicatedStorage.Shared.Net)
local DayNight = require(script.Parent.DayNight)
local Inventory = require(script.Parent.Inventory)
local PaEvents = require(script.Parent.PaEvents)
local Saves = require(script.Parent.Saves)
local Tokens = require(script.Parent.Tokens)

local settings = Config.Dawn
local rules: DawnScore.Rules = settings.Tokens

type Stack = InventoryLogic.Stack
type Placed = { prop: PVInstance, owner: number, at: CFrame }

local Dawn = {}

local streaks: { [Player]: number } = {}
local aliveAtLightsOut: { [Player]: boolean } = {}
local lockerAtSiren: { [Player]: { Stack } } = {}
local bankedTonight: { [Player]: { Stack } } = {}
local placedAtLightsOut: { Placed } = {}
local beamFolder: Folder
local reportRemote: RemoteEvent

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function lockerTotals(player: Player): { Stack }?
	local data = Saves.data(player)
	return data and InventoryLogic.totals(data.locker)
end

local function dogOf(player: Player): Model?
	local folder = workspace:FindFirstChild("Dog")
	for _, child in if folder then folder:GetChildren() else {} do
		if child:IsA("Model") and child:GetAttribute("Owner") == player.UserId then
			return child
		end
	end
	return nil
end

local function onSiren()
	beamFolder:ClearAllChildren()
	local lockers = workspace:FindFirstChild("Lockers")
	for _, locker in if lockers then lockers:GetChildren() else {} do
		if locker:IsA("Model") then
			PaEvents.beam(locker:GetPivot().Position, settings.LockerBeam, beamFolder)
		end
	end
	table.clear(lockerAtSiren)
	for _, player in Players:GetPlayers() do
		lockerAtSiren[player] = lockerTotals(player)
	end
end

local function onLightsOut()
	beamFolder:ClearAllChildren()
	table.clear(bankedTonight)
	for player, before in lockerAtSiren do
		local after = lockerTotals(player)
		if after then
			bankedTonight[player] = DawnScore.banked(before, after)
		end
	end
	table.clear(lockerAtSiren)

	table.clear(aliveAtLightsOut)
	for _, player in Players:GetPlayers() do
		aliveAtLightsOut[player] = aliveRoot(player) ~= nil or nil
	end

	table.clear(placedAtLightsOut)
	for _, prop in CollectionService:GetTagged(Config.Grab.Tag) do
		local owner = prop:GetAttribute("PlacedBy")
		if prop:IsA("PVInstance") and type(owner) == "number" and prop:IsDescendantOf(workspace) then
			table.insert(placedAtLightsOut, { prop = prop, owner = owner, at = prop:GetPivot() })
		end
	end
end

-- Pieces placed before lights out that are still theirs, close to where they were and not knocked
-- over, as positions per owner UserId
local function standingForts(): { [number]: { Vector3 } }
	local forts = {}
	for _, entry in placedAtLightsOut do
		local prop = entry.prop
		if prop:IsDescendantOf(workspace) and prop:GetAttribute("PlacedBy") == entry.owner then
			local now = prop:GetPivot()
			local moved = (now.Position - entry.at.Position).Magnitude
			local tilt = math.deg(math.acos(math.clamp(now.UpVector:Dot(entry.at.UpVector), -1, 1)))
			if moved <= settings.FortDrift and tilt <= settings.FortTilt then
				forts[entry.owner] = forts[entry.owner] or {}
				table.insert(forts[entry.owner], now.Position)
			end
		end
	end
	table.clear(placedAtLightsOut)
	return forts
end

local function anyWithin(points: { Vector3 }, position: Vector3, radius: number): boolean
	for _, point in points do
		if (point - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function report(player: Player, root: BasePart, day: number, fort: { Vector3 }, banked: { Stack })
	local dog = dogOf(player)
	local dogAt = dog and dog:GetPivot().Position
	local nights = streaks[player] or 1
	local paid = DawnScore.payout({
		nights = nights,
		fortPieces = #fort,
		dogAtFort = dogAt ~= nil and anyWithin(fort, dogAt, settings.DogNearFort),
		bankedStacks = #banked,
	}, rules)
	Tokens.add(player, paid.total)
	reportRemote:FireClient(player, {
		day = day,
		nights = nights,
		carrying = DawnScore.topLines(Inventory.list(player), InventoryItems, settings.CarryShown),
		fortPieces = #fort,
		dogWithYou = dogAt ~= nil and (dogAt - root.Position).Magnitude <= settings.DogWithYou,
		banked = DawnScore.topLines(banked, InventoryItems, settings.BankedShown),
		pay = paid,
		balance = Tokens.get(player),
	})
end

local function onDawn(day: number)
	local forts = standingForts()
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		local banked = bankedTonight[player] or {}
		if root and aliveAtLightsOut[player] then
			streaks[player] = (streaks[player] or 0) + 1
			report(player, root, day, forts[player.UserId] or {}, banked)
		elseif #banked > 0 then
			-- Down at dawn, but what made it into the locker made it out
			local paid = Tokens.add(player, DawnScore.bankedPay(#banked, rules))
			Saves.tell(player, `Banked tonight: +{paid} Tokens`)
		end
	end
	table.clear(bankedTonight)
	table.clear(aliveAtLightsOut)
end

local function onPhaseChanged(phase: string, previous: string, day: number)
	if phase == "Siren" then
		onSiren()
	elseif phase == "Night" then
		onLightsOut()
	elseif phase == "Day" and previous == "Night" then
		onDawn(day)
	end
end

-- A new body is a new life
local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		streaks[player] = 0
		aliveAtLightsOut[player] = nil
	end)
end

local function onPlayerRemoving(player: Player)
	streaks[player] = nil
	aliveAtLightsOut[player] = nil
	lockerAtSiren[player] = nil
	bankedTonight[player] = nil
end

function Dawn.Init()
	reportRemote = Net.event("DawnReport")
	beamFolder = Instance.new("Folder")
	beamFolder.Name = "LockerBeams"
	beamFolder.Parent = workspace
end

function Dawn.Start()
	DayNight.onPhaseChanged(onPhaseChanged)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Dawn
