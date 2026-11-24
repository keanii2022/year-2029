-- Psst: a player whispers, players within HearRange hear it and see which way it came from, and
-- robots get it as a quiet noise. Rate-limited per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Loudness = require(script.Parent.Loudness)

local Settings = Config.Psst

local Psst = {}

local lastPsstAt: { [Player]: number } = {}
local heardRemote: RemoteEvent

local function onPsst(player: Player)
	local now = os.clock()
	if now - (lastPsstAt[player] or -math.huge) < Settings.Cooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not humanoid or not head or humanoid.Health <= 0 then
		return
	end
	lastPsstAt[player] = now

	local position = head.Position
	for _, listener in Players:GetPlayers() do
		local listenerCharacter = listener.Character
		if listenerCharacter then
			local distance = (listenerCharacter:GetPivot().Position - position).Magnitude
			if listener == player or distance <= Settings.HearRange then
				heardRemote:FireClient(listener, player, position)
			end
		end
	end
	Loudness.emit(position, "quiet", player)
end

function Psst.Init()
	heardRemote = Net.event("PsstHeard")
	Net.event("Psst").OnServerEvent:Connect(onPsst)
	Players.PlayerRemoving:Connect(function(player)
		lastPsstAt[player] = nil
	end)
end

return Psst
