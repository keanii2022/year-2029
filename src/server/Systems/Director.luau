-- The hidden event director: keeps an eye on where players (and sim bots) are and where they've
-- built forts, so PaEvents can drop its events where separate groups will run into each other.
-- It never tells anyone; it only answers PaEvents' "where?" and "how soon?". Picking: Logic/Director.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DirectorLogic = require(ReplicatedStorage.Shared.Logic.Director)
local PrizeChests = require(script.Parent.PrizeChests)
local SimPlayers = require(script.Parent.SimPlayers)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Director

local Director = {}

local random = Random.new()
local groups: { DirectorLogic.Group } = {}
local forts: { DirectorLogic.Point } = {}
local together = false
local lastMetAt = os.clock()

-- World position to layout x/z, or nil when it's outside the warehouse walls (lobby, test room)
local function toLayout(position: Vector3): DirectorLogic.Point?
	local relative = position - Config.Warehouse.Origin
	local half = Warehouse.layout().half
	if math.abs(relative.X) > half or math.abs(relative.Z) > half then
		return nil
	end
	return { x = relative.X, z = relative.Z }
end

local function gatherPeople(): { DirectorLogic.Point }
	local points = {}
	local function add(position: Vector3)
		local point = toLayout(position)
		if point then
			table.insert(points, point)
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			add(root.Position)
		end
	end
	for _, entry in SimPlayers.alive() do
		add(entry.position)
	end
	return points
end

-- Props a player or sim player placed carry Grab's "PlacedBy"; a few of them close together make a fort
local function gatherForts(): { DirectorLogic.Point }
	local placed = {}
	for _, prop in CollectionService:GetTagged(Config.Grab.Tag) do
		if
			prop:IsA("PVInstance")
			and prop:GetAttribute("PlacedBy") ~= nil
			and prop:IsDescendantOf(workspace)
		then
			local point = toLayout(prop:GetPivot().Position)
			if point then
				table.insert(placed, point)
			end
		end
	end
	local found = {}
	for _, pile in DirectorLogic.cluster(placed, Settings.FortRadius) do
		if pile.count >= Settings.FortMinProps then
			table.insert(found, { x = pile.x, z = pile.z })
		end
	end
	return found
end

local function sample()
	groups = DirectorLogic.cluster(gatherPeople(), Settings.ClusterRadius)
	together = DirectorLogic.together(groups, Settings.MeetRange) or (#groups == 1 and groups[1].count > 1)
	if together then
		lastMetAt = os.clock()
	end
end

local function installations(): { DirectorLogic.Installation }
	local list = {}
	for _, room in PrizeChests.rooms() do
		table.insert(list, { x = room.cx, z = room.cz, room = room })
	end
	return list
end

-- Event clock pace for PaEvents: below 1 while groups are mixing it up, above 1 once they've been
-- apart a while
function Director.pace(): number
	return DirectorLogic.pace(os.clock() - lastMetAt, together, Settings)
end

-- A layout spot that should pull groups together, or nil to let the event go anywhere.
-- wantRoom: only installation spots (the "is now open" event needs a hall).
function Director.spot(wantRoom: boolean?): DirectorLogic.Candidate?
	local candidates = DirectorLogic.candidates(groups, forts, installations(), Settings)
	if wantRoom then
		local halls = {}
		for _, candidate in candidates do
			if candidate.room then
				table.insert(halls, candidate)
			end
		end
		candidates = halls
	end
	return DirectorLogic.pick(candidates, Settings, function()
		return random:NextNumber()
	end)
end

function Director.Start()
	Warehouse.layout()
	lastMetAt = os.clock()
	local fortsAt = -math.huge
	while true do
		if os.clock() - fortsAt >= Settings.FortSeconds then
			fortsAt = os.clock()
			forts = gatherForts()
		end
		sample()
		task.wait(Settings.SampleSeconds)
	end
end

return Director
