-- The day and night clock. The server owns it and publishes it as ReplicatedStorage attributes
-- (Phase, PhaseEndsAt in server time, Day) plus a PhaseChanged event, so clients and later
-- systems (robots, supplies) all agree on what time it is.
-- Also owns flashlight on/off: clients ask, the server sets the player's FlashlightOn attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Logic.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(script.Parent.Inventory)

local Settings = Config.DayNight

type Listener = (phase: Clock.Phase, previous: Clock.Phase, day: number) -> ()

local DayNight = {}

local lengths: Clock.Lengths
local state: Clock.State
local listeners: { Listener } = {}
local phaseRemote: RemoteEvent
local flashlightRemote: RemoteEvent
local lastToggle: { [Player]: number } = {}
local frozenLeft: number? = nil
local frozenPublishedAt = 0

local function publish()
	ReplicatedStorage:SetAttribute("Phase", state.phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", state.endsAt)
	ReplicatedStorage:SetAttribute("Day", state.day)
end

local function advance()
	local nextState, transitions = Clock.advance(state, workspace:GetServerTimeNow(), lengths)
	if #transitions == 0 then
		return
	end
	state = nextState
	publish()
	for _, transition in transitions do
		phaseRemote:FireAllClients(transition.to, state.endsAt, transition.day)
		for _, listener in listeners do
			task.spawn(listener, transition.to, transition.from, transition.day)
		end
	end
end

-- While frozen the phase end keeps sliding forward, re-published once a second so clocks hold still
local function step()
	if not frozenLeft then
		advance()
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - frozenPublishedAt >= 1 then
		frozenPublishedAt = now
		state = { phase = state.phase, endsAt = now + frozenLeft, day = state.day }
		publish()
	end
end

local function hasLiveCharacter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function onFlashlight(player: Player, on: unknown)
	if type(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Settings.Flashlight.ToggleCooldown then
		return
	end
	lastToggle[player] = now
	-- Battery is owned by NightTricks; a dead light only turns on when a spare is in the bag (NightTricks swaps it in).
	local battery = player:GetAttribute("Battery")
	local dead = type(battery) == "number" and battery <= 0
	if on and dead and not Inventory.has(player, "FlashlightBattery") then
		return
	end
	player:SetAttribute("FlashlightOn", on and hasLiveCharacter(player))
end

local function onCharacterAdded(player: Player, character: Model)
	player:SetAttribute("FlashlightOn", false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		player:SetAttribute("FlashlightOn", false)
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("FlashlightOn", false)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function DayNight.phase(): Clock.Phase
	return state.phase
end

function DayNight.isNight(): boolean
	return Clock.isNight(state.phase)
end

function DayNight.day(): number
	return state.day
end

function DayNight.timeLeft(): number
	return Clock.timeLeft(state.endsAt, workspace:GetServerTimeNow())
end

-- Calls listener(phase, previous, day) on every phase change. Returns a function that unsubscribes.
function DayNight.onPhaseChanged(listener: Listener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Admin: runs the clock forward to the start of phase, firing every change on the way so robots,
-- supplies and clients react as if the time had passed. False if phase is unknown or already on.
function DayNight.skipTo(phase: string): boolean
	if (lengths :: any)[phase] == nil or state.phase == phase then
		return false
	end
	while state.phase ~= phase do
		state = { phase = state.phase, endsAt = workspace:GetServerTimeNow(), day = state.day }
		advance()
	end
	if frozenLeft then
		frozenLeft = lengths[state.phase]
	end
	return true
end

-- Admin: stops the clock where it is, or starts it again with the time that was left.
function DayNight.setFrozen(frozen: boolean)
	local now = workspace:GetServerTimeNow()
	if frozen and not frozenLeft then
		frozenLeft = Clock.timeLeft(state.endsAt, now)
		frozenPublishedAt = 0
	elseif not frozen and frozenLeft then
		state = { phase = state.phase, endsAt = now + frozenLeft, day = state.day }
		frozenLeft = nil
		publish()
	end
	ReplicatedStorage:SetAttribute("ClockFrozen", frozenLeft ~= nil)
end

function DayNight.isFrozen(): boolean
	return frozenLeft ~= nil
end

function DayNight.Init()
	lengths = Clock.lengths(Settings)
	state = Clock.start(workspace:GetServerTimeNow(), lengths)
	publish()
	phaseRemote = Net.event("PhaseChanged")
	flashlightRemote = Net.event("FlashlightToggle")
end

function DayNight.Start()
	flashlightRemote.OnServerEvent:Connect(onFlashlight)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastToggle[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return DayNight
