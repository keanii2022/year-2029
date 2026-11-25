-- A faint mark over Roblox friends in this server once they're within Config.Arrival.FriendMark
-- Range, so you can find each other in the dark. Strangers never get one (the player list stays
-- hidden on purpose) and it changes nothing about damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Settings = Config.Arrival.FriendMark
local player = Players.LocalPlayer

local SPRAY_RED = Color3.fromRGB(200, 28, 22)

type Friend = { mark: BillboardGui?, checkedAt: number, isFriend: boolean }

local Friends = {}

local known: { [Player]: Friend } = {}

local function makeMark(head: BasePart): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Name = "FriendMark"
	board.Size = UDim2.fromOffset(Settings.Size, Settings.Size)
	board.StudsOffsetWorldSpace = Vector3.new(0, Settings.Height, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = Settings.Range
	board.Adornee = head
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.6, 0.6)
	dot.Rotation = 45
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = SPRAY_RED
	dot.BackgroundTransparency = Settings.Transparency
	dot.Parent = board
	board.Parent = head
	return board
end

local function refresh(other: Player, entry: Friend, now: number)
	if now - entry.checkedAt >= Settings.RecheckEvery then
		entry.checkedAt = now
		local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
		entry.isFriend = ok and isFriend == true
	end
	local character = other.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local wanted = entry.isFriend and head ~= nil and humanoid ~= nil and humanoid.Health > 0
	if entry.mark and (not wanted or entry.mark.Adornee ~= head) then
		entry.mark:Destroy()
		entry.mark = nil
	end
	if wanted and not entry.mark then
		entry.mark = makeMark(head :: BasePart)
	end
end

local function forget(other: Player)
	local entry = known[other]
	if entry and entry.mark then
		entry.mark:Destroy()
	end
	known[other] = nil
end

function Friends.Start()
	Players.PlayerRemoving:Connect(forget)
	while true do
		local now = os.clock()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local entry = known[other]
				if not entry then
					entry = { mark = nil, checkedAt = -math.huge, isFriend = false }
					known[other] = entry
				end
				refresh(other, entry, now)
			end
		end
		task.wait(Settings.CheckEvery)
	end
end

return Friends
