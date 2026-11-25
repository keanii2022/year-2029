-- Tokens: the saved currency, earned only by playing (dawn payouts, missions, forts) and never sold
-- for Robux. Lives in the player save; the balance goes out as the player's "Tokens" attribute.
-- No shop yet: Tokens.spend is the one way out for when there is one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SavesLogic = require(ReplicatedStorage.Shared.Logic.Saves)
local Saves = require(script.Parent.Saves)

local Tokens = {}

-- Earned before the save finished loading; added once it does
local pending: { [Player]: number } = {}

local function publish(player: Player, data: SavesLogic.Data)
	player:SetAttribute("Tokens", data.tokens)
end

function Tokens.get(player: Player): number
	local data = Saves.data(player)
	return if data then data.tokens else 0
end

-- Returns how many were added (whole Tokens only).
function Tokens.add(player: Player, amount: number): number
	local data = Saves.data(player)
	if not data then
		local whole = math.max(0, math.floor(amount))
		pending[player] = (pending[player] or 0) + whole
		return whole
	end
	local added = SavesLogic.addTokens(data, amount)
	if added > 0 then
		publish(player, data)
		Saves.markDirty(player, true)
	end
	return added
end

-- Takes amount if the player has it and their save can be written. True when it went through.
function Tokens.spend(player: Player, amount: number): boolean
	local data = Saves.data(player)
	if not data or not Saves.canSave(player) or not SavesLogic.spendTokens(data, amount) then
		return false
	end
	publish(player, data)
	Saves.markDirty(player, true)
	return true
end

function Tokens.Init()
	Saves.onLoaded(function(player, data)
		local queued = pending[player]
		pending[player] = nil
		if queued then
			SavesLogic.addTokens(data, queued)
			Saves.markDirty(player)
		end
		publish(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return Tokens
