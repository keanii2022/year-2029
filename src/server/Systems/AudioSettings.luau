-- Each player's audio sliders and gentler-scares toggle, kept in their save. The client panel
-- (Controllers/AudioSettings) asks with nil for the saved settings and sends new ones on close.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SavesLogic = require(ReplicatedStorage.Shared.Logic.Saves)
local Saves = require(script.Parent.Saves)

local AudioSettings = {}

local remote: RemoteEvent

local function send(player: Player)
	local data = Saves.data(player)
	if data then
		remote:FireClient(player, data.audio)
	end
end

local function onRemote(player: Player, raw: any)
	local data = Saves.data(player)
	if not data then
		return
	end
	if raw == nil then
		send(player)
		return
	end
	data.audio = SavesLogic.cleanAudio(raw)
	Saves.markDirty(player, true)
end

function AudioSettings.Init()
	remote = Net.event("AudioSettings")
	remote.OnServerEvent:Connect(onRemote)
	Saves.onLoaded(send)
end

return AudioSettings
