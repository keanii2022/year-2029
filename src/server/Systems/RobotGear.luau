-- Robot-only gear. EMP charge: throw it, every robot near where it lands shuts down for a while.
-- Disruptor: fires an arc that destroys the robot it hits. Normal guns never hurt robots.
-- Clients only ask ("RobotGear", action, aim direction); the server checks the bag and does the rest.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local RobotWeapons = require(ReplicatedStorage.Shared.Logic.RobotWeapons)
local Inventory = require(script.Parent.Inventory)
local Loudness = require(script.Parent.Loudness)
local Robots = require(script.Parent.Robots)

local settings = Config.Robots

local RobotGear = {}

local lastUse: { [Player]: number } = {}
local lastDisruptor: { [Player]: number } = {}

local function isFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude < math.huge
end

-- The player's head and a clean aim direction, or nil if they can't use gear right now.
local function aimOf(player: Player, direction: any): (Model?, Vector3, Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character
		and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not humanoid or humanoid.Health <= 0 or not head or not head:IsA("BasePart") then
		return nil, Vector3.zero, Vector3.zero
	end
	if not isFiniteVector(direction) or direction.Magnitude < 0.1 then
		return nil, Vector3.zero, Vector3.zero
	end
	return character, head.Position, direction.Unit
end

local function cast(origin: Vector3, offset: Vector3, ignore: Instance): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	return workspace:Raycast(origin, offset, params)
end

local function owns(player: Player, itemId: string): boolean
	-- the item list may not know these ids yet (another step adds them)
	return Inventory.Items[itemId] ~= nil and Inventory.has(player, itemId)
end

local function chargeModel(): PVInstance
	local model = ModelLibrary.get("emp_charge")
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		return model
	end
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.6, 0.8, 0.6)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Color = Color3.fromRGB(60, 70, 80)
	return part
end

local function blast(position: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.one * 2
	ring.CFrame = CFrame.new(position)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 200, 255)
	ring.Transparency = 0.3
	ring.Parent = workspace
	TweenService
		:Create(ring, TweenInfo.new(0.45), { Size = Vector3.one * settings.EmpRadius * 2, Transparency = 1 })
		:Play()
	Debris:AddItem(ring, 0.6)
end

local function throwEmp(player: Player, direction: any)
	local character, origin, aim = aimOf(player, direction)
	local itemId = settings.EmpItemId
	if not character or not owns(player, itemId) or Inventory.remove(player, itemId, 1) < 1 then
		return
	end
	local hit = cast(origin, aim * settings.EmpThrowRange, character)
	local landing = if hit then hit.Position + hit.Normal * 0.5 else origin + aim * settings.EmpThrowRange
	local ground = cast(landing, Vector3.new(0, -60, 0), character)
	if ground then
		landing = ground.Position + Vector3.yAxis * 0.4
	end

	local charge = chargeModel()
	charge:PivotTo(CFrame.new(origin))
	charge.Parent = workspace
	local started = os.clock()
	while true do
		local t = math.min(1, (os.clock() - started) / settings.EmpFlightTime)
		local arc = Vector3.yAxis * math.sin(t * math.pi) * 4
		charge:PivotTo(CFrame.new(origin:Lerp(landing, t) + arc) * CFrame.Angles(t * 9, t * 5, 0))
		if t >= 1 then
			break
		end
		task.wait()
	end

	task.wait(settings.EmpFuse)
	blast(landing)
	for _, robot in Robots.inRadius(landing, settings.EmpRadius) do
		Robots.disable(robot, settings.EmpSeconds)
	end
	Loudness.emit(landing, "loud", charge)
	charge:Destroy()
end

-- A jagged line of short neon bolts from a to b.
local function arc(a: Vector3, b: Vector3)
	local segments = 7
	local last = a
	for i = 1, segments do
		local point = a:Lerp(b, i / segments)
		if i < segments then
			point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.2
		end
		local bolt = Instance.new("Part")
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(170, 220, 255)
		bolt.Size = Vector3.new(0.12, 0.12, (point - last).Magnitude)
		bolt.CFrame = CFrame.lookAt((last + point) / 2, point)
		bolt.Parent = workspace
		Debris:AddItem(bolt, 0.15)
		last = point
	end
end

local function fireDisruptor(player: Player, direction: any)
	local character, origin, aim = aimOf(player, direction)
	local now = os.clock()
	if not character or not owns(player, settings.DisruptorItemId) then
		return
	end
	if not RobotWeapons.ready(lastDisruptor[player], now, settings.DisruptorCooldown) then
		return
	end
	lastDisruptor[player] = now
	local hit = cast(origin, aim * settings.DisruptorRange, character)
	local finish = if hit then hit.Position else origin + aim * settings.DisruptorRange
	arc(origin + aim * 1.5, finish)
	Loudness.emit(origin, "normal", character)
	local robot = hit and Robots.fromPart(hit.Instance)
	if robot then
		Robots.destroy(robot, player)
	end
end

local function onUse(player: Player, action: any, direction: any)
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < settings.GearUseInterval then
		return
	end
	lastUse[player] = now
	if action == "Emp" then
		throwEmp(player, direction)
	elseif action == "Disruptor" then
		fireDisruptor(player, direction)
	end
end

function RobotGear.Init()
	Net.event("RobotGear").OnServerEvent:Connect(onUse)
end

function RobotGear.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		lastDisruptor[player] = nil
	end)
end

return RobotGear
