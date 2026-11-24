-- Builds the giant warehouse from the seeded layout in Logic/WarehouseGen: floor, walls and a roof
-- lost in haze, giant pillars, shelving aisles, junk, robot rooms, paint and oil on the walls, spawns.
-- Parts go into square chunk folders so streaming (on in the place file) can load them near players.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)

local Warehouse = {}

local settings = Config.Warehouse
local MAX_PART = 2000 -- Roblox caps a part at 2048 studs per side
local YIELD_EVERY = 300 -- instances built between yields so the server never stalls

local layout: WarehouseGen.Layout
local root: Folder
local chunks: { [string]: Folder } = {}
local built = 0
local cosmetic: Random

local function toWorld(x: number, z: number, y: number?): Vector3
	return settings.Origin + Vector3.new(x, y or 0, z)
end

local function chunkFor(x: number, z: number): Folder
	local i = math.floor((x + layout.half) / settings.ChunkSize)
	local j = math.floor((z + layout.half) / settings.ChunkSize)
	local key = `Chunk_{i}_{j}`
	local folder = chunks[key]
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = key
		folder.Parent = root
		chunks[key] = folder
	end
	return folder
end

local function noteBuilt()
	built += 1
	if built % YIELD_EVERY == 0 then
		task.wait()
	end
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	noteBuilt()
	return part
end

-- Turns the model so its front (+z in the manifest) points along facing, stands it on the floor at
-- (x, z), and with backToWall pushes it out by half its depth so its back touches (x, z).
local function placeModel(model: Model, x: number, z: number, facing: Vector3, backToWall: boolean)
	local rotation = CFrame.lookAt(Vector3.zero, -facing)
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local push = if backToWall then size.Z / 2 + 0.2 else 0
	local target = toWorld(x, z) + facing * push
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(rotation + (target - bottom))
end

local function spawnModel(
	name: string,
	parent: Instance,
	x: number,
	z: number,
	facing: Vector3,
	backToWall: boolean
): Model?
	local model = ModelLibrary.get(name)
	if not model then
		return nil
	end
	placeModel(model, x, z, facing, backToWall)
	if not settings.FixedModels[name] then
		CollectionService:AddTag(model, Config.Grab.Tag)
	end
	model.Parent = parent
	noteBuilt()
	return model
end

local function facingFromTurn(degrees: number): Vector3
	local radians = math.rad(degrees)
	return Vector3.new(math.sin(radians), 0, math.cos(radians))
end

local function buildHaze()
	local haze = Lighting:FindFirstChild("Haze")
	if not haze then
		haze = Instance.new("Atmosphere")
		haze.Name = "Haze"
	end
	for property, value in settings.Haze do
		(haze :: any)[property] = value
	end
	haze.Parent = Lighting
end

local function buildFloor()
	local tiles = math.ceil(layout.size / settings.ChunkSize)
	for j = 0, tiles - 1 do
		for i = 0, tiles - 1 do
			local x = -layout.half + (i + 0.5) * settings.ChunkSize
			local z = -layout.half + (j + 0.5) * settings.ChunkSize
			block(
				chunkFor(x, z),
				"Floor",
				Vector3.new(settings.ChunkSize, 2, settings.ChunkSize),
				CFrame.new(toWorld(x, z, -1)),
				settings.FloorColor,
				Enum.Material.Concrete
			)
		end
	end
end

-- Outer walls and roof are huge single parts, kept outside the chunks so they're always there
local function buildShell(shell: Folder)
	local height = settings.CeilingHeight
	local thick = settings.WallThickness
	local pieces = math.ceil(layout.size / MAX_PART)
	local length = layout.size / pieces
	for n = 0, pieces - 1 do
		local along = -layout.half + (n + 0.5) * length
		local edge = layout.half - thick / 2
		local alongX = Vector3.new(length, height, thick)
		local alongZ = Vector3.new(thick, height, length)
		local y = height / 2
		block(
			shell,
			"WallNorth",
			alongX,
			CFrame.new(toWorld(along, -edge, y)),
			settings.WallColor,
			Enum.Material.Concrete
		)
		block(
			shell,
			"WallSouth",
			alongX,
			CFrame.new(toWorld(along, edge, y)),
			settings.WallColor,
			Enum.Material.Concrete
		)
		block(
			shell,
			"WallWest",
			alongZ,
			CFrame.new(toWorld(-edge, along, y)),
			settings.WallColor,
			Enum.Material.Concrete
		)
		block(
			shell,
			"WallEast",
			alongZ,
			CFrame.new(toWorld(edge, along, y)),
			settings.WallColor,
			Enum.Material.Concrete
		)
		for m = 0, pieces - 1 do
			local other = -layout.half + (m + 0.5) * length
			block(
				shell,
				"Ceiling",
				Vector3.new(length, 4, length),
				CFrame.new(toWorld(along, other, height + 2)),
				settings.CeilingColor,
				Enum.Material.Metal
			)
		end
	end
	local gate = ModelLibrary.get("entrance_gate")
	if gate then
		placeModel(gate, layout.entrance.x, layout.entrance.z - thick, Vector3.new(0, 0, -1), true)
		gate.Parent = shell
	end
end

local function buildSpawns(folder: Folder)
	for index, spot in layout.spawns do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `Spawn{index}`
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Enabled = not settings.UseTestRoom
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.CFrame = CFrame.new(toWorld(spot.x, spot.z, 0.1))
		spawn.Color = settings.FloorColor
		spawn.Material = Enum.Material.Concrete
		spawn.Parent = folder
	end
	-- Step 1's test room spawns would win half the time, so they go quiet while the warehouse is live
	local testRoom = workspace:FindFirstChild("TestRoom")
	if testRoom and not settings.UseTestRoom then
		for _, descendant in testRoom:GetDescendants() do
			if descendant:IsA("SpawnLocation") then
				descendant.Enabled = false
			end
		end
	end
end

local function buildPillars()
	local height = settings.CeilingHeight
	for _, pillar in layout.pillars do
		local parent = chunkFor(pillar.x, pillar.z)
		block(
			parent,
			"Pillar",
			Vector3.new(settings.PillarSize, height, settings.PillarSize),
			CFrame.new(toWorld(pillar.x, pillar.z, height / 2)),
			settings.PillarColor,
			Enum.Material.Concrete
		)
		local base = ModelLibrary.get("pillar_base")
		if base then
			placeModel(base, pillar.x, pillar.z, Vector3.new(0, 0, 1), false)
			base.Parent = parent
			noteBuilt()
		end
	end
end

local function buildShelf(shelf: WarehouseGen.Shelf)
	local model = Instance.new("Model")
	model.Name = "Shelving"
	local length = shelf.x1 - shelf.x0
	local centre = (shelf.x0 + shelf.x1) / 2
	local height = settings.ShelfHeight

	local uprights = math.max(2, math.ceil(length / settings.ShelfBay) + 1)
	for n = 0, uprights - 1 do
		local x = shelf.x0 + 0.3 + (length - 0.6) * n / (uprights - 1)
		block(
			model,
			"Upright",
			Vector3.new(0.6, height, shelf.depth),
			CFrame.new(toWorld(x, shelf.z, height / 2)),
			settings.ShelfSteel,
			Enum.Material.Metal
		)
	end
	for _, y in settings.ShelfDecks do
		block(
			model,
			"Deck",
			Vector3.new(length, 0.3, shelf.depth),
			CFrame.new(toWorld(centre, shelf.z, y + 0.15)),
			settings.ShelfDeck,
			Enum.Material.Metal
		)
	end
	for _ = 1, settings.ShelfStockRuns do
		local deck = settings.ShelfDecks[cosmetic:NextInteger(1, #settings.ShelfDecks)]
		local runLength = length * cosmetic:NextNumber(0.3, 0.7)
		local runHeight = cosmetic:NextNumber(2.5, 4.5)
		local x = shelf.x0 + 1 + runLength / 2 + cosmetic:NextNumber(0, length - runLength - 2)
		block(
			model,
			"Stock",
			Vector3.new(runLength, runHeight, shelf.depth - 0.6),
			CFrame.new(toWorld(x, shelf.z, deck + 0.3 + runHeight / 2)),
			settings.Cardboard,
			Enum.Material.Cardboard
		)
	end
	model.Parent = chunkFor(centre, shelf.z)
end

local function numberLabel(part: BasePart, face: Enum.NormalId, number: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 0.5)
	text.Position = UDim2.fromScale(0, 0.1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.Oswald
	text.TextColor3 = Color3.fromRGB(230, 226, 214)
	text.Text = tostring(number)
	text.Parent = gui
	gui.Parent = part
end

local function buildSign(sign: WarehouseGen.Sign)
	local model = ModelLibrary.get("aisle_sign")
	if not model then
		return
	end
	placeModel(model, sign.x, sign.z, Vector3.new(-1, 0, 0), false)
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		numberLabel(body, Enum.NormalId.Front, sign.number)
		numberLabel(body, Enum.NormalId.Back, sign.number)
	end
	model.Parent = chunkFor(sign.x, sign.z)
	noteBuilt()
end

local function buildJunk(junk: WarehouseGen.Junk)
	local parent = chunkFor(junk.x, junk.z)
	local turn = cosmetic:NextNumber(0, 360)
	for _, box in junk.boxes do
		local part = block(
			parent,
			"JunkBox",
			Vector3.new(box.sx, box.sy, box.sz),
			CFrame.new(toWorld(junk.x + box.x, junk.z + box.z, box.y))
				* CFrame.Angles(0, math.rad(turn + box.turn), 0),
			settings.Cardboard,
			Enum.Material.Cardboard
		)
		CollectionService:AddTag(part, Config.Grab.Tag)
	end
end

local function buildRoom(room: any)
	local model = Instance.new("Model")
	model.Name = `Room{room.id}`
	model:SetAttribute("RoomId", room.id)
	model:SetAttribute("Kind", room.kind)
	local height = settings.RoomWallHeight
	for _, wall in room.walls do
		block(
			model,
			"Wall",
			Vector3.new(wall.x1 - wall.x0, height, wall.z1 - wall.z0),
			CFrame.new(toWorld((wall.x0 + wall.x1) / 2, (wall.z0 + wall.z1) / 2, height / 2)),
			settings.RoomWallColor,
			Enum.Material.Plaster
		)
	end
	for _, item in room.items do
		local facing = Vector3.new(item.nx, 0, item.nz)
		local onWall = item.name ~= settings.RoomRug
		spawnModel(item.name, model, item.x, item.z, facing, onWall)
	end
	model.Parent = chunkFor(room.cx, room.cz)
end

local function fallbackArt(decal: WarehouseGen.Decal, gui: SurfaceGui)
	if decal.kind == "spray" or decal.kind == "claw" then
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.PermanentMarker
		if decal.kind == "spray" then
			text.TextColor3 = settings.SprayColor
			text.Text = settings.SprayText[decal.name] or string.upper((string.gsub(decal.name, "_", " ")))
		else
			text.TextColor3 = settings.OilColor
			text.TextTransparency = 0.25
			text.Text = "///"
		end
		text.Parent = gui
	elseif decal.kind == "oil" then
		local blob = Instance.new("Frame")
		blob.Size = UDim2.fromScale(0.8, 0.8)
		blob.Position = UDim2.fromScale(0.1, 0.1)
		blob.BackgroundColor3 = settings.OilColor
		blob.BackgroundTransparency = 0.15
		blob.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = blob
		blob.Parent = gui
	else
		local paper = Instance.new("TextLabel")
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundColor3 = settings.PosterColor
		paper.BorderSizePixel = 0
		paper.TextScaled = true
		paper.Font = Enum.Font.Oswald
		paper.TextColor3 = Color3.fromRGB(40, 38, 34)
		paper.Text = string.upper((string.gsub(decal.name, "_", " ")))
		paper.Parent = gui
	end
end

local function buildDecal(decal: WarehouseGen.Decal)
	local position = toWorld(decal.x, decal.z, decal.y)
	local part = Instance.new("Part")
	part.Name = `Paint_{decal.name}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(decal.width, decal.height, 0.05)
	part.CFrame = CFrame.lookAt(position, position + Vector3.new(decal.nx, 0, decal.nz))
		* CFrame.Angles(0, 0, math.rad(cosmetic:NextNumber(-8, 8)))

	local image = ModelLibrary.imageId(decal.name)
	if image then
		local sticker = Instance.new("Decal")
		sticker.Face = Enum.NormalId.Front
		sticker.Texture = image
		sticker.Parent = part
	else
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 1
		fallbackArt(decal, gui)
		gui.Parent = part
	end
	part.Parent = chunkFor(decal.x, decal.z)
	noteBuilt()
end

function Warehouse.layout(): WarehouseGen.Layout
	return layout
end

function Warehouse.rooms(): { any }
	return layout.rooms
end

-- 0 at the entrance, 1 at the far corners
function Warehouse.depth(position: Vector3): number
	local relative = position - settings.Origin
	return WarehouseGen.depth(layout, relative.X, relative.Z)
end

function Warehouse.roomAt(position: Vector3): any?
	local relative = position - settings.Origin
	return WarehouseGen.roomAt(layout, relative.X, relative.Z)
end

function Warehouse.toWorld(x: number, z: number): Vector3
	return toWorld(x, z)
end

function Warehouse.Init()
	local seed = if settings.Seed == 0 then Random.new():NextInteger(1, 2 ^ 31 - 1) else settings.Seed
	layout = WarehouseGen.generate(settings, seed)
	cosmetic = Random.new(seed)
	buildHaze()
end

function Warehouse.Start()
	root = Instance.new("Folder")
	root.Name = "Warehouse"
	root:SetAttribute("Seed", layout.seed)
	root.Parent = workspace

	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = root
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = root

	-- Floor and spawns first so anyone joining mid-build lands on something
	buildFloor()
	buildSpawns(spawns)
	buildShell(shell)
	buildPillars()
	for _, room in layout.rooms do
		buildRoom(room)
	end
	for _, shelf in layout.shelves do
		buildShelf(shelf)
	end
	for _, sign in layout.signs do
		buildSign(sign)
	end
	for _, junk in layout.junk do
		buildJunk(junk)
	end
	for _, item in layout.loose do
		spawnModel(item.name, chunkFor(item.x, item.z), item.x, item.z, facingFromTurn(item.turn), false)
	end
	for _, decal in layout.decals do
		buildDecal(decal)
	end
	root:SetAttribute("Built", true)
end

return Warehouse
