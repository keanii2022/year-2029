-- Aisle 40 for the local player: the store PA's own aisle 40 lines by day while you're in the
-- aisle, the voice lines the server sends (the phone, the night manager's tape), and the aisle 40
-- sign that reads 41 while you're not looking at it (Logic/SmileCheck.stepSign).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local SmileCheck = require(ReplicatedStorage.Shared.Logic.SmileCheck)
local Music = require(script.Parent.Music)
local Subtitles = require(script.Parent.Subtitles)

local Settings = Config.SmileAisle
local SIGN_TAG = "SmileAisleSign"
local CHIME_LEAD = 1.2 -- the chime rings out before the voice starts

local SmileAisle = {}

local player = Players.LocalPlayer
local random = Random.new()

local function play(parent: Instance, name: string, volume: number, group: Mix.Group)
	local id = ModelLibrary.soundId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = parent
	Mix.route(sound, group)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function paLoop(marker: Instance)
	local low: Vector3 = marker:GetAttribute("LaneMin")
	local high: Vector3 = marker:GetAttribute("LaneMax")
	local lane = { x0 = low.X, z0 = low.Z, x1 = high.X, z1 = high.Z }
	local nextAt: number? = nil
	local index = random:NextInteger(1, #Settings.PaLines)
	while true do
		task.wait(1)
		local root = rootPart()
		local inside = root ~= nil and SmileCheck.inside(lane, root.Position.X, root.Position.Z)
		local day = (ReplicatedStorage:GetAttribute("Phase") or "Day") == "Day"
		if not inside or not day then
			nextAt = nil
			continue
		end
		local now = os.clock()
		if not nextAt then
			nextAt = now + between(Settings.PaFirst)
		elseif now >= nextAt then
			nextAt = now + between(Settings.PaGap)
			local line = Settings.PaLines[index]
			index = index % #Settings.PaLines + 1
			play(SoundService, Settings.Sounds.Chime, Settings.Volume.Chime, "Voice")
			task.wait(CHIME_LEAD)
			Music.playVoiceLine(line.voice)
			Subtitles.show(Config.Life.PaPrefix .. line.text, Settings.PaSubtitleSeconds)
		end
	end
end

local function signLabels(sign: Instance): { TextLabel }
	local labels = {}
	for _, child in sign:GetDescendants() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	return labels
end

local function signLoop()
	local rules = Settings.Sign
	local real = tostring(Config.Warehouse.SmileAisle.Number)
	local wrong = tostring(Config.Warehouse.SmileAisle.WrongNumber)
	local state = SmileCheck.newSign()
	local showing = real
	local roll = function()
		return random:NextNumber()
	end
	while true do
		task.wait(rules.Every)
		local sign = CollectionService:GetTagged(SIGN_TAG)[1]
		local root = rootPart()
		local camera = workspace.CurrentCamera
		if not (sign and sign:IsA("Model") and root and camera) then
			continue
		end
		local position = sign:GetPivot().Position
		if (position - root.Position).Magnitude > rules.Range then
			state = SmileCheck.newSign()
			continue
		end
		local _, onScreen = camera:WorldToViewportPoint(position)
		local flipped = SmileCheck.stepSign(state, rules, onScreen, rules.Every, roll)
		local want = if flipped then wrong else real
		if want ~= showing then
			showing = want
			for _, label in signLabels(sign) do
				label.Text = want
			end
			-- Snapping back to 40 happens in plain view: a small crackle, like a bad bulb
			if want == real then
				local part = sign:FindFirstChildWhichIsA("BasePart", true)
				if part then
					play(part, Settings.Sounds.Crackle, Settings.Volume.Small, "SFX")
				end
			end
		end
	end
end

function SmileAisle.Start()
	task.spawn(function()
		Net.event("SmileAisleVoice").OnClientEvent
			:Connect(function(voice: string, text: string, seconds: number)
				Music.playVoiceLine(voice)
				Subtitles.show(text, seconds)
			end)
	end)
	task.spawn(signLoop)
	task.spawn(function()
		paLoop(ReplicatedStorage:WaitForChild("SmileAisle", math.huge))
	end)
end

return SmileAisle
