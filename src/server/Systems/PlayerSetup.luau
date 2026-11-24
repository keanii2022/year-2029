-- Character defaults on spawn and the server's copy of each player's stance.
-- Other systems read character:GetAttribute("Stance") ("Walk" | "Sprint" | "Crouch").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementLogic = require(ReplicatedStorage.Shared.Logic.Movement)
local Net = require(ReplicatedStorage.Shared.Net)

local settings = Config.Movement

local PlayerSetup = {}

local lastStanceAt: { [Player]: number } = {}

local function setUpCharacter(character: Model)
	character:SetAttribute("Stance", "Walk")
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = settings.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = settings.JumpHeight
end

local function setUpPlayer(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	player.CharacterAdded:Connect(setUpCharacter)
	if player.Character then
		task.spawn(setUpCharacter, player.Character)
	end
end

local function onStance(player: Player, stance: any)
	if not MovementLogic.isStance(stance) then
		return
	end
	local now = os.clock()
	-- Small slack under the client's own interval so honest clients never get dropped.
	if now - (lastStanceAt[player] or 0) < settings.StanceMinInterval * 0.5 then
		return
	end
	lastStanceAt[player] = now
	local character = player.Character
	if character then
		character:SetAttribute("Stance", stance)
	end
end

function PlayerSetup.Init()
	Net.event("MovementStance").OnServerEvent:Connect(onStance)
	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastStanceAt[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
end

return PlayerSetup
