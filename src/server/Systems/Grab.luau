-- Grab and build. The server owns every carried prop: clients send aim and rotation,
-- the server moves the prop, finds where it lands, and freezes it there on drop.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.Logic.GrabMath)
local GrabRules = require(ReplicatedStorage.Shared.Logic.GrabRules)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.Grab

-- Casts use a slightly smaller box so props can sit flush against walls and each other.
local CAST_SHRINK = 0.98

type Carry = {
	prop: PVInstance,
	parts: { BasePart },
	collide: { [BasePart]: boolean },
	size: Vector3,
	pivotOffset: CFrame,
	pickupPivot: CFrame,
	boxCFrame: CFrame,
	angles: Vector3, -- tip, turn, roll in degrees
	aim: Vector3?,
	humanoid: Humanoid?,
	lastGhost: number,
}

local Grab = {}

local carriers: { [Player]: Carry } = {}
local carriedBy: { [PVInstance]: Player } = {}

local requestRemote: RemoteEvent
local dropRemote: RemoteEvent
local stateRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent
local ghostRemote: UnreliableRemoteEvent

local function boxOf(prop: PVInstance): (CFrame, Vector3)
	if prop:IsA("BasePart") then
		return prop.CFrame, prop.Size
	end
	return (prop :: Model):GetBoundingBox()
end

local function partsOf(prop: PVInstance): { BasePart }
	local parts = {}
	if prop:IsA("BasePart") then
		table.insert(parts, prop)
	end
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < 1e6
end

local function rotationOf(angles: Vector3): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
end

local function findLanding(carry: Carry, root: BasePart, humanoid: Humanoid): (CFrame?, boolean, string?)
	local rotation = rotationOf(carry.angles)
	local position = carry.boxCFrame.Position
	local x = GrabMath.snapToGrid(position.X, Settings.GridSize)
	local z = GrabMath.snapToGrid(position.Z, Settings.GridSize)
	local size = carry.size

	local ignore: { Instance } = { carry.prop }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.FilterDescendantsInstances = ignore
	castParams.RespectCanCollide = true

	local start = CFrame.new(x, position.Y, z) * rotation
	local hit =
		workspace:Blockcast(start, size * CAST_SHRINK, Vector3.new(0, -Settings.MaxDropFall, 0), castParams)
	if not hit then
		local ok, reason = GrabRules.canPlace({
			groundFound = false,
			distance = 0,
			reach = Settings.PlaceReach,
			heightAboveFeet = 0,
			maxHeightAboveFeet = Settings.MaxPlaceAboveFeet,
			blocked = false,
		})
		return nil, ok, reason
	end

	local halfHeight = GrabMath.verticalHalfExtent(
		size.X,
		size.Y,
		size.Z,
		rotation.RightVector.Y,
		rotation.UpVector.Y,
		rotation.LookVector.Y
	)
	local y = GrabMath.landingY(position.Y, hit.Distance, halfHeight, CAST_SHRINK)
	local landed = CFrame.new(x, y, z) * rotation

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { carry.prop }
	overlapParams.RespectCanCollide = true
	local overlapping = workspace:GetPartBoundsInBox(landed, size * CAST_SHRINK, overlapParams)

	local feetY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local ok, reason = GrabRules.canPlace({
		groundFound = true,
		distance = (landed.Position - root.Position).Magnitude,
		reach = Settings.PlaceReach,
		heightAboveFeet = (y - halfHeight) - feetY,
		maxHeightAboveFeet = Settings.MaxPlaceAboveFeet,
		blocked = #overlapping > 0,
	})
	return landed, ok, reason
end

local function release(player: Player, carry: Carry, pivot: CFrame?)
	if pivot and carry.prop:IsDescendantOf(workspace) then
		carry.prop:PivotTo(pivot)
	end
	for _, part in carry.parts do
		part.Anchored = true -- frozen where it lands until the server resets
		part.CanCollide = carry.collide[part]
	end
	player:SetAttribute("CarrySpeedMultiplier", nil)
	carriers[player] = nil
	carriedBy[carry.prop] = nil
	if player.Parent then
		stateRemote:FireClient(player, nil)
	end
end

-- Death, leaving or respawn: land it if the spot is good, otherwise put it back where it was picked up.
local function forceDrop(player: Player, carry: Carry)
	local root, humanoid = bodyOf(player)
	if root and humanoid then
		local landed, ok = findLanding(carry, root, humanoid)
		if landed and ok then
			release(player, carry, landed * carry.pivotOffset)
			return
		end
	end
	release(player, carry, carry.pickupPivot)
end

local function onGrabRequest(player: Player, prop: any)
	if typeof(prop) ~= "Instance" or not prop:IsA("PVInstance") then
		return
	end
	if not CollectionService:HasTag(prop, Settings.Tag) or not prop:IsDescendantOf(workspace) then
		return
	end
	local root, humanoid = bodyOf(player)
	local boxCFrame, size = boxOf(prop)
	local distance = if root
		then (boxCFrame.Position - root.Position).Magnitude - size.Magnitude / 2
		else math.huge

	local ok = GrabRules.canGrab({
		alive = root ~= nil,
		alreadyCarrying = carriers[player] ~= nil,
		carriedByOther = carriedBy[prop] ~= nil,
		distance = math.max(distance, 0),
		reach = Settings.GrabReach,
	})
	if not ok or not humanoid then
		return
	end

	local parts = partsOf(prop)
	local collide = {}
	local mass = 0
	for _, part in parts do
		collide[part] = part.CanCollide
		mass += part:GetMass()
		part.Anchored = true
		part.CanCollide = false
	end

	local tip, turn, roll = boxCFrame:ToEulerAnglesYXZ()
	local multiplier = GrabMath.carrySpeedMultiplier(
		mass,
		Settings.LightMass,
		Settings.HeavyMass,
		Settings.MinSpeedMultiplier
	)
	local pivot = prop:GetPivot()
	local carry: Carry = {
		prop = prop,
		parts = parts,
		collide = collide,
		size = size,
		pivotOffset = boxCFrame:ToObjectSpace(pivot),
		pickupPivot = pivot,
		boxCFrame = boxCFrame,
		angles = Vector3.new(
			GrabMath.wrapAngle(math.deg(tip)),
			GrabMath.wrapAngle(math.deg(turn)),
			GrabMath.wrapAngle(math.deg(roll))
		),
		aim = nil,
		humanoid = humanoid,
		lastGhost = 0,
	}
	-- The client Movement controller owns WalkSpeed and multiplies by this attribute.
	player:SetAttribute("CarrySpeedMultiplier", multiplier)
	carriers[player] = carry
	carriedBy[prop] = player
	stateRemote:FireClient(player, prop)
end

local function onDrop(player: Player)
	local carry = carriers[player]
	local root, humanoid = bodyOf(player)
	if not carry or not root or not humanoid then
		return
	end
	local landed, ok = findLanding(carry, root, humanoid)
	if landed and ok then
		release(player, carry, landed * carry.pivotOffset)
	else
		ghostRemote:FireClient(player, landed, carry.size, false)
	end
end

local function onAim(player: Player, position: any, tip: any, turn: any, roll: any)
	local carry = carriers[player]
	if not carry or typeof(position) ~= "Vector3" then
		return
	end
	if not (isFiniteNumber(tip) and isFiniteNumber(turn) and isFiniteNumber(roll)) then
		return
	end
	if not (isFiniteNumber(position.X) and isFiniteNumber(position.Y) and isFiniteNumber(position.Z)) then
		return
	end
	carry.aim = position
	carry.angles = Vector3.new(GrabMath.wrapAngle(tip), GrabMath.wrapAngle(turn), GrabMath.wrapAngle(roll))
end

local function step(dt: number)
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * Settings.CarrySmoothing)
	for player, carry in carriers do
		if not carry.prop:IsDescendantOf(workspace) then
			release(player, carry, nil)
			continue
		end
		local root, humanoid = bodyOf(player)
		if not root or not humanoid or humanoid ~= carry.humanoid then
			forceDrop(player, carry)
			continue
		end

		local origin = root.Position
		local target = carry.aim or (origin + root.CFrame.LookVector * Settings.DefaultHoldDistance)
		local x, y, z = GrabMath.clampToReach(
			origin.X,
			origin.Y,
			origin.Z,
			target.X,
			target.Y,
			target.Z,
			Settings.MinHoldDistance,
			Settings.MaxHoldDistance
		)
		local goal = CFrame.new(x, y, z) * rotationOf(carry.angles)
		carry.boxCFrame = carry.boxCFrame:Lerp(goal, alpha)
		carry.prop:PivotTo(carry.boxCFrame * carry.pivotOffset)

		if now - carry.lastGhost >= 1 / Settings.GhostRate then
			carry.lastGhost = now
			local landed, ok = findLanding(carry, root, humanoid)
			ghostRemote:FireClient(player, landed, carry.size, ok)
		end
	end
end

local TEST_PROPS = {
	{ name = "Couch", size = Vector3.new(7, 3, 3), color = Color3.fromRGB(120, 120, 125), count = 1 },
	{ name = "Shelf", size = Vector3.new(6, 6, 2), color = Color3.fromRGB(95, 95, 100), count = 1 },
	{ name = "Crate", size = Vector3.new(3, 3, 3), color = Color3.fromRGB(150, 145, 135), count = 4 },
	{ name = "Panel", size = Vector3.new(4, 7, 0.6), color = Color3.fromRGB(170, 170, 170), count = 6 },
}

local function spawnTestProps()
	local folder = Instance.new("Folder")
	folder.Name = "GrabTestProps"
	local origin = Settings.TestPropsOrigin
	local row = 0
	for _, kind in TEST_PROPS do
		for i = 1, kind.count do
			local part = Instance.new("Part")
			part.Name = kind.name
			part.Size = kind.size
			part.Color = kind.color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CFrame = CFrame.new(origin + Vector3.new((i - 1) * 8, kind.size.Y / 2, row * 8))
			CollectionService:AddTag(part, Settings.Tag)
			part.Parent = folder
		end
		row += 1
	end
	folder.Parent = workspace
end

function Grab:Init()
	requestRemote = Net.event("GrabRequest")
	dropRemote = Net.event("GrabDrop")
	stateRemote = Net.event("GrabState")
	aimRemote = Net.unreliable("GrabAim")
	ghostRemote = Net.unreliable("GrabGhost")
end

function Grab:Start()
	requestRemote.OnServerEvent:Connect(onGrabRequest)
	dropRemote.OnServerEvent:Connect(onDrop)
	aimRemote.OnServerEvent:Connect(onAim)
	Players.PlayerRemoving:Connect(function(player)
		local carry = carriers[player]
		if carry then
			forceDrop(player, carry)
		end
	end)
	RunService.Heartbeat:Connect(step)

	if Settings.SpawnTestProps then
		spawnTestProps()
	end
end

return Grab
