-- Callouts: a player calls out, players within HearRange hear which call it was and where it came
-- from, and robots get it as a normal noise. A new call cuts the caller's last one off for everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local VoiceLines = require(ReplicatedStorage.Shared.Logic.VoiceLines)
local Loudness = require(script.Parent.Loudness)

local Settings = Config.Callouts

local Callouts = {}

local lastCallAt: { [Player]: number } = {}
local heardRemote: RemoteEvent

local function onCallout(player: Player, index: unknown)
	if not VoiceLines.validCallout(index, #Settings.Sounds) then
		return
	end
	local now = os.clock()
	if now - (lastCallAt[player] or -math.huge) < Settings.Cooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not humanoid or not head or humanoid.Health <= 0 then
		return
	end
	lastCallAt[player] = now

	local position = head.Position
	for _, listener in Players:GetPlayers() do
		local listenerCharacter = listener.Character
		if listenerCharacter then
			local distance = (listenerCharacter:GetPivot().Position - position).Magnitude
			if listener == player or distance <= Settings.HearRange then
				heardRemote:FireClient(listener, player, index, position)
			end
		end
	end
	Loudness.emit(position, "normal", player)
end

function Callouts.Init()
	heardRemote = Net.event("CalloutHeard")
	Net.event("Callout").OnServerEvent:Connect(onCallout)
	Players.PlayerRemoving:Connect(function(player)
		lastCallAt[player] = nil
	end)
end

return Callouts
