-- Server speed check. The client owns its WalkSpeed and every reach check trusts root.Position, so
-- each Heartbeat compares a root's horizontal movement with the fastest it may go (sprint, carry
-- slowdown, AdminSpeed; admin Fly is skipped) using Logic/MoveCheck, and pulls a cheater back to
-- their last good spot. Height is ignored so falling never counts. Server teleports call
-- MoveCheck.grace; new characters and anchored roots (hiding) get grace on their own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MoveCheckLogic = require(ReplicatedStorage.Shared.Logic.MoveCheck)

local settings = Config.MoveCheck

local MoveCheck = {}

type Tracked = {
	root: BasePart,
	lastGood: Vector3,
	graceUntil: number,
	state: MoveCheckLogic.State,
}

local tracked: { [Player]: Tracked } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function maxSpeed(player: Player): number
	local carry = player:GetAttribute("CarrySpeedMultiplier")
	local admin = player:GetAttribute("AdminSpeed")
	return Config.Movement.SprintSpeed
		* (if type(carry) == "number" then carry else 1)
		* (if type(admin) == "number" then admin else 1)
end

local function track(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or player.Character ~= character then
		return
	end
	tracked[player] = {
		root = root,
		lastGood = root.Position,
		graceUntil = os.clock() + settings.SpawnGraceSeconds,
		state = MoveCheckLogic.new(maxSpeed(player), settings),
	}
end

local function check(player: Player, entry: Tracked, dt: number, now: number)
	local root = entry.root
	if not root.Parent then
		tracked[player] = nil
		return
	end
	local speed = maxSpeed(player)
	if root.Anchored then
		entry.graceUntil = now + settings.GraceSeconds
	end
	if now < entry.graceUntil or player:GetAttribute("Fly") == true then
		entry.lastGood = root.Position
		entry.state = MoveCheckLogic.new(speed, settings)
		return
	end
	local moved = (flat(root.Position) - flat(entry.lastGood)).Magnitude
	if MoveCheckLogic.step(entry.state, moved, dt, speed, settings) then
		local character = root.Parent :: Model
		character:PivotTo(CFrame.new(entry.lastGood) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
		entry.state = MoveCheckLogic.new(speed, settings)
		return
	end
	entry.lastGood = root.Position
end

-- Call right before the server moves a character itself (admin teleports, DevTeleport).
function MoveCheck.grace(player: Player, seconds: number?)
	local entry = tracked[player]
	if entry then
		entry.graceUntil = os.clock() + (seconds or settings.GraceSeconds)
	end
end

function MoveCheck.Start()
	if not settings.Enabled then
		return
	end
	local function setUpPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			track(player, character)
		end)
		if player.Character then
			task.spawn(track, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setUpPlayer)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracked[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, entry in tracked do
			check(player, entry, dt, now)
		end
	end)
end

return MoveCheck
