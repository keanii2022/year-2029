-- Your first spawn in a server: next to a Roblox friend who's already playing here, or, for a
-- first-timer (first-day save), right in front of the nearest locker so the first-day chain can
-- point at it. Later spawns are left to the normal spawn points.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MoveCheck = require(script.Parent.MoveCheck)
local Saves = require(script.Parent.Saves)

local Settings = Config.Arrival

local Arrival = {}

local placed: { [Player]: boolean } = {}

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function friendHere(player: Player): BasePart?
	for _, other in Players:GetPlayers() do
		local root = other ~= player and aliveRoot(other)
		if root then
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and isFriend then
				return root
			end
		end
	end
	return nil
end

-- Behind the friend, pulled in short of any wall in the way
local function besideFriend(friend: BasePart, character: Model): CFrame
	local back = -friend.CFrame.LookVector * Settings.FriendGap
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, friend.Parent :: Instance }
	local hit = workspace:Raycast(friend.Position, back, params)
	local spot = if hit
		then friend.Position + back.Unit * math.max(0, hit.Distance - 2)
		else friend.Position + back
	return CFrame.lookAt(spot, Vector3.new(friend.Position.X, spot.Y, friend.Position.Z))
end

local function inFrontOfLocker(from: Vector3): CFrame?
	local lockers = workspace:FindFirstChild("Lockers")
	local best, bestDistance = nil, math.huge
	for _, locker in if lockers then lockers:GetChildren() else {} do
		if locker:IsA("Model") then
			local distance = (locker:GetPivot().Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = locker, distance
			end
		end
	end
	if not best then
		return nil
	end
	local pivot = best:GetPivot()
	local spot = pivot.Position + pivot.LookVector * Settings.LockerGap
	spot = Vector3.new(spot.X, from.Y, spot.Z)
	return CFrame.lookAt(spot, Vector3.new(pivot.Position.X, from.Y, pivot.Position.Z))
end

local function isFirstTimer(player: Player): boolean
	local waited = 0
	while not Saves.isLoaded(player) and waited < Settings.SaveWait and player.Parent do
		waited += task.wait(0.5)
	end
	local data = Saves.data(player)
	return data ~= nil and data.firstDay and Saves.canSave(player)
end

local function onFirstCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local friend = friendHere(player)
	local target = if friend
		then besideFriend(friend, character)
		elseif isFirstTimer(player) then inFrontOfLocker(root.Position)
		else nil
	-- Only move a body that's still the one we were placing and still alive
	if not target or player.Character ~= character or not aliveRoot(player) then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, target.Position)
	MoveCheck.grace(player)
	character:PivotTo(target)
end

local function onPlayerAdded(player: Player)
	local function onCharacter(character: Model)
		if placed[player] then
			return
		end
		placed[player] = true
		onFirstCharacter(player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Arrival.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		placed[player] = nil
	end)
end

return Arrival
