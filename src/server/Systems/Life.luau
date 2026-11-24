-- Feeds each player's Life controller: a short list of aisle spots near them (the rack layout is
-- server only), and real copies of the props it animates (clients can't load uploaded models).
-- By day the same spots send a calm chore bot or two out to work where each player can see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeSpots = require(ReplicatedStorage.Shared.Logic.LifeSpots)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local RobotChores = require(ReplicatedStorage.Shared.Logic.RobotChores)
local DayNight = require(script.Parent.DayNight)
local Robots = require(script.Parent.Robots)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Life
local Origin = Config.Warehouse.Origin
local Chores = Config.Robots.Chores
local random = Random.new()

local Life = {}

local spotsEvent = Net.event("LifeSpots")

local function publishProps()
	local folder = Instance.new("Folder")
	folder.Name = "LifeProps"
	folder.Parent = ReplicatedStorage
	for _, name in { Settings.CartModel, Settings.BoxModel } do
		if ModelLibrary.entry(name) and ModelLibrary.uploaded(name) then
			local model = ModelLibrary.get(name)
			if model then
				model.Parent = folder
			end
		end
	end
end

local function sendChores(position: Vector3, spots: { LifeSpots.Spot })
	local out, idle = Robots.choresNear(position, Chores.CallRadius)
	local need = RobotChores.needed(out, Chores.PerPlayer)
	local viewer = { x = position.X, z = position.Z }
	for _, robot in idle do
		if need <= 0 then
			return
		end
		local home = { x = robot.home.X, z = robot.home.Z }
		local goal, face = RobotChores.pickSpot(spots, home, viewer, Chores, random:NextNumber())
		if
			goal
			and Robots.sendOnChore(
				robot,
				Vector3.new(goal.x, 0, goal.z),
				face and Vector3.new(face.x, 0, face.z)
			)
		then
			need -= 1
		end
	end
end

local function sendSpots(spots: { LifeSpots.Spot })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local relative = root.Position - Origin
			local near =
				LifeSpots.near(spots, relative.X, relative.Z, 0, Settings.SpotsRadius, Settings.SpotsMax)
			local world = table.create(#near)
			for n, spot in near do
				world[n] = {
					x = spot.x + Origin.X,
					z = spot.z + Origin.Z,
					kind = spot.kind,
					dx = spot.dx,
					dz = spot.dz,
				}
			end
			spotsEvent:FireClient(player, world)
			if DayNight.phase() == "Day" then
				sendChores(root.Position, world)
			end
		end
	end
end

function Life.Start()
	task.spawn(publishProps)
	local spots = LifeSpots.fromShelves(Warehouse.layout().shelves, Settings)
	while true do
		sendSpots(spots)
		task.wait(Settings.SpotsEvery)
	end
end

return Life
