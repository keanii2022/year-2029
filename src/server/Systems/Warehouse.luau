-- Builds the warehouse from the seeded layout in Logic/WarehouseGen: a dark concrete floor, walls and
-- a trussed roof lost in haze, giant pillars, packed racking, store departments under hanging signs,
-- strip lights on cables, robot rooms, dreamcore pockets, paint and oil on the walls, spawns.
-- Parts go into square chunk folders so streaming (on in the place file) can load them near players.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabRules = require(ReplicatedStorage.Shared.Logic.GrabRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ShelfStock = require(ReplicatedStorage.Shared.Logic.ShelfStock)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local WarehouseSizes = require(ReplicatedStorage.Shared.Logic.WarehouseSizes)
local ShelfStream = require(script.Parent.ShelfStream)
local SizeServers = require(script.Parent.SizeServers)

local Warehouse = {}

local settings = Config.Warehouse
local MAX_PART = 2000 -- Roblox caps a part at 2048 studs per side
local YIELD_EVERY = 400 -- instances built between yields so the server never stalls
local FLICKER_TAG = "FlickerLight"
local LIGHT_TAG = "WarehouseLight" -- client Lighting switches these off at night, emergency ones go red

local layout: WarehouseGen.Layout
-- The layout waits on the size choice (a MemoryStore read on size servers), so it is made in Start;
-- other systems asking for it before then wait here.
local layoutReady = Instance.new("BindableEvent")
local root: Folder
local chunks: { [string]: Folder } = {}
local built = 0
local cosmetic: Random
local shelfStocked = 0

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

-- Thin, non-colliding bits (cables, tape) that nothing should hit or cast shadows from
local function detail(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
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

local function longestSide(size: Vector3): number
	return math.max(size.X, size.Y, size.Z)
end

local function tagIfMovable(model: Model, name: string)
	local _, size = model:GetBoundingBox()
	if GrabRules.movable(name, longestSide(size), settings.FixedModels, settings.MaxGrabSize) then
		CollectionService:AddTag(model, Config.Grab.Tag)
	end
end

-- A small no-shadow light on the models that always glow (battery lamps, candles, vending machines)
local function addModelLight(model: Model, name: string)
	local toneName = settings.ModelLights[name]
	local tone = toneName and settings.LampTones[toneName]
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not tone or not body then
		return
	end
	local glow = Instance.new("PointLight")
	glow.Color = tone.color
	glow.Brightness = tone.brightness
	glow.Range = tone.range
	glow.Shadows = false
	glow.Parent = body
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
	tagIfMovable(model, name)
	addModelLight(model, name)
	model.Parent = parent
	noteBuilt()
	return model
end

local function facingFromTurn(degrees: number): Vector3
	local radians = math.rad(degrees)
	return Vector3.new(math.sin(radians), 0, math.cos(radians))
end

-- Blender kit pieces replace the code-built stand-ins only once they're uploaded; before that the
-- greybox stand-in would look worse than the styled boxes.
local function hasKit(name: string?): boolean
	return name ~= nil and ModelLibrary.uploaded(name)
end

-- movable: a prop rather than structure, so it gets the grab tag unless it's fixed or too big
local function placeKit(
	name: string,
	x: number,
	z: number,
	facing: Vector3,
	lift: number?,
	movable: boolean?
): Model?
	local model = ModelLibrary.get(name)
	if not model then
		return nil
	end
	placeModel(model, x, z, facing, false)
	if lift and lift ~= 0 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
	if movable then
		tagIfMovable(model, name)
	end
	addModelLight(model, name)
	model.Parent = chunkFor(x, z)
	noteBuilt()
	return model
end

-- Tiles a 32-stud kit floor over a rect, whole tiles only, turned at random so repeats don't line up
local function tileKitFloor(name: string, x0: number, z0: number, x1: number, z1: number, lift: number)
	local size = 32
	local x = x0
	while x + size <= x1 + 0.01 do
		local z = z0
		while z + size <= z1 + 0.01 do
			placeKit(name, x + size / 2, z + size / 2, facingFromTurn(cosmetic:NextInteger(0, 3) * 90), lift)
			z += size
		end
		x += size
	end
end

local function textGui(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

local PAINT_SKIES = {
	sky = { Color3.fromRGB(86, 150, 214), Color3.fromRGB(200, 226, 244), 0.15 },
	dusk = { Color3.fromRGB(120, 70, 170), Color3.fromRGB(220, 150, 200), 0.5 },
	night = { Color3.fromRGB(10, 16, 44), Color3.fromRGB(40, 60, 110), 0.55 },
}

local function rounded(parent: Instance, size: UDim2, position: UDim2, color: Color3, transparency: number)
	local blob = Instance.new("Frame")
	blob.Size = size
	blob.Position = position
	blob.BackgroundColor3 = color
	blob.BackgroundTransparency = transparency
	blob.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = blob
	blob.Parent = parent
	return blob
end

-- A painted sky (blue, dusk purple or night) with flat clouds, optionally a green hill; or a wall
-- of party stars and balloons. Painted, never quite convincing.
local function paintFace(part: BasePart, face: Enum.NormalId, kind: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 4
	gui.LightInfluence = if kind == "night" then 0.1 else 0.4
	local canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BorderSizePixel = 0
	if kind == "stars" then
		canvas.BackgroundTransparency = 1
		for _ = 1, cosmetic:NextInteger(8, 14) do
			local star = Instance.new("TextLabel")
			local size = cosmetic:NextNumber(0.05, 0.12)
			star.Size = UDim2.fromScale(size, size * 2)
			star.Position = UDim2.fromScale(cosmetic:NextNumber(0, 0.95), cosmetic:NextNumber(0.05, 0.6))
			star.BackgroundTransparency = 1
			star.TextScaled = true
			star.Text = if cosmetic:NextNumber() < 0.6 then "★" else "●"
			star.TextColor3 = ({
				Color3.fromRGB(240, 220, 200),
				Color3.fromRGB(220, 70, 70),
				Color3.fromRGB(240, 200, 60),
			})[cosmetic:NextInteger(1, 3)]
			star.Parent = canvas
		end
		canvas.Parent = gui
		gui.Parent = part
		return
	end
	local palette = PAINT_SKIES[if kind == "hill" or kind == "sky_floor" then "sky" else kind]
		or PAINT_SKIES.sky
	canvas.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(palette[1], palette[2])
	gradient.Parent = canvas
	canvas.Parent = gui
	for _ = 1, cosmetic:NextInteger(3, 6) do
		local w = cosmetic:NextNumber(0.12, 0.3)
		rounded(
			canvas,
			UDim2.fromScale(w, w * 0.35),
			UDim2.fromScale(cosmetic:NextNumber(0, 1 - w), cosmetic:NextNumber(0.05, 0.6)),
			Color3.fromRGB(250, 250, 252),
			palette[3]
		)
	end
	if kind == "night" then
		for _ = 1, 30 do
			rounded(
				canvas,
				UDim2.fromOffset(2, 2),
				UDim2.fromScale(cosmetic:NextNumber(), cosmetic:NextNumber()),
				Color3.fromRGB(255, 255, 240),
				0.2
			)
		end
	elseif kind == "hill" then
		rounded(
			canvas,
			UDim2.fromScale(1.6, 0.9),
			UDim2.fromScale(-0.3, 0.62),
			Color3.fromRGB(78, 150, 62),
			0
		)
	end
	gui.Parent = part
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

-- Outer walls, roof and trusses are tiled from pieces under the part size cap and kept outside
-- the chunks so they're always there: no sky anywhere, ever.
local function buildShell(shell: Folder)
	local height = settings.CeilingHeight
	local thick = settings.WallThickness
	local pieces = math.ceil(layout.size / MAX_PART)
	local length = layout.size / pieces
	for n = 0, pieces - 1 do
		local along = -layout.half + (n + 0.5) * length
		local edge = layout.half - thick / 2
		local alongX = Vector3.new(length, height + 8, thick)
		local alongZ = Vector3.new(thick, height + 8, length)
		local y = (height + 8) / 2
		for _, spot in
			{
				{ "WallNorth", alongX, toWorld(along, -edge, y) },
				{ "WallSouth", alongX, toWorld(along, edge, y) },
				{ "WallWest", alongZ, toWorld(-edge, along, y) },
				{ "WallEast", alongZ, toWorld(edge, along, y) },
			}
		do
			block(
				shell,
				spot[1],
				spot[2],
				CFrame.new(spot[3]),
				settings.WallColor,
				Enum.Material.CorrodedMetal
			)
		end
		for m = 0, pieces - 1 do
			local other = -layout.half + (m + 0.5) * length
			block(
				shell,
				"Roof",
				Vector3.new(length, 4, length),
				CFrame.new(toWorld(along, other, height + 2)),
				settings.CeilingColor,
				Enum.Material.CorrodedMetal
			)
		end
	end -- Kit wall panels line the inside of the outer wall: block and steel below, steel above, a dock
	-- door now and then. They sit in the chunks so streaming can drop the far ones.
	if hasKit("wall_lower") and hasKit("wall_upper") then
		local inset = layout.half - thick
		local panels = math.floor(layout.size / 16)
		for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local inward = Vector3.new(-side[1], 0, -side[2])
			for n = 0, panels - 1 do
				local along = -layout.half + (n + 0.5) * 16
				local x = if side[1] == 0 then along else side[1] * inset
				local z = if side[1] == 0 then side[2] * inset else along
				local roll = cosmetic:NextNumber()
				local lower = if roll < 0.04 and hasKit("dock_door")
					then "dock_door"
					elseif roll < 0.2 and hasKit("wall_oily") then "wall_oily"
					elseif roll < 0.32 and hasKit("wall_lower_damaged") then "wall_lower_damaged"
					else "wall_lower"
				placeKit(lower, x, z, inward)
				placeKit("wall_upper", x, z, inward, 16)
			end
		end
	end
	-- Steel trusses every TrussGap studs: the thing that makes it read as a warehouse when you look up
	local x = -layout.half + settings.TrussGap
	while x < layout.half do
		for n = 0, pieces - 1 do
			local along = -layout.half + (n + 0.5) * length
			local truss = block(
				shell,
				"Truss",
				Vector3.new(1.2, 3, length),
				CFrame.new(toWorld(x, along, height - 1.5)),
				settings.TrussColor,
				Enum.Material.Metal
			)
			truss.CastShadow = false
		end
		x += settings.TrussGap
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
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.CFrame = CFrame.new(toWorld(spot.x, spot.z, 0.1))
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
	local kitPillars = hasKit("giant_pillar_base") and hasKit("giant_pillar")
	for _, pillar in layout.pillars do
		local parent = chunkFor(pillar.x, pillar.z)
		if kitPillars then
			-- Base, then segments stacked every 32, each turned a quarter from the one below
			placeKit("giant_pillar_base", pillar.x, pillar.z, Vector3.new(0, 0, 1))
			local level = 1
			while level * 32 < height do
				placeKit("giant_pillar", pillar.x, pillar.z, facingFromTurn(level * 90), level * 32)
				level += 1
			end
		end
		local shaft = block(
			parent,
			"Pillar",
			Vector3.new(settings.PillarSize, height, settings.PillarSize),
			CFrame.new(toWorld(pillar.x, pillar.z, height / 2)),
			settings.PillarColor,
			Enum.Material.Concrete
		)
		-- The kit pillar is slightly bigger, so the plain shaft hides inside it as its collision
		shaft.Transparency = if kitPillars then 1 else 0
		-- A faded safety band at the bottom, the bit everyone scuffs
		local band = block(
			parent,
			"PillarBand",
			Vector3.new(settings.PillarSize + 0.2, 4, settings.PillarSize + 0.2),
			CFrame.new(toWorld(pillar.x, pillar.z, 2)),
			Color3.fromRGB(170, 140, 50),
			Enum.Material.Concrete
		)
		detail(band)
		band.CanCollide = true
		band.Transparency = if kitPillars then 1 else 0
		-- Some pillars still point to an exit. None of them lead anywhere.
		if cosmetic:NextNumber() < settings.ExitSignChance then
			local face = cosmetic:NextInteger(0, 3)
			local out = settings.PillarSize / 2 + 0.3
			local offset = ({
				Vector3.new(out, 0, 0),
				Vector3.new(-out, 0, 0),
				Vector3.new(0, 0, out),
				Vector3.new(0, 0, -out),
			})[face + 1]
			local at = toWorld(pillar.x, pillar.z, 14) + offset
			local sign = block(
				parent,
				"ExitSign",
				Vector3.new(4, 1.6, 0.3),
				CFrame.lookAt(at, at + offset),
				Color3.fromRGB(40, 200, 90),
				Enum.Material.Neon
			)
			detail(sign)
			textGui(sign, Enum.NormalId.Front, "EXIT", Color3.fromRGB(235, 255, 240), Enum.Font.GothamBlack)
			local glow = Instance.new("SurfaceLight")
			glow.Face = Enum.NormalId.Front
			glow.Color = sign.Color
			glow.Brightness = settings.ExitSignLight.brightness
			glow.Range = settings.ExitSignLight.range
			glow.Shadows = false
			glow.Parent = sign
		end
	end
end

local RACK_WRECKS = { "rack_collapsed", "rack_toppled_beam" }
local EMPTY_BAY = "rack_bay_empty"

-- Loose props across one slot of a code-built rack (the fallback before the kit is uploaded).
-- base: the slot's centre at its load bottom, x along the rack.
local function stockSlot(base: CFrame, slot: Vector3, parent: Instance)
	if
		shelfStocked >= WarehouseSizes.scaled(layout.size, settings.ShelfStockMax, settings)
		or cosmetic:NextNumber() >= settings.ShelfStockChance
	then
		return
	end
	local left = -slot.X / 2 + 0.2
	for _ = 1, cosmetic:NextInteger(settings.ShelfStockPerSlot[1], settings.ShelfStockPerSlot[2]) do
		local model = ModelLibrary.get(settings.ShelfStock[cosmetic:NextInteger(1, #settings.ShelfStock)])
		if not model then
			continue
		end
		local _, size = model:GetBoundingBox()
		if left + size.X > slot.X / 2 - 0.2 or size.Y > slot.Y or size.Z > slot.Z then
			model:Destroy()
			continue
		end
		local depthRoom = (slot.Z - size.Z) / 2
		local turn = CFrame.Angles(0, math.rad(cosmetic:NextNumber(-12, 12)), 0)
		model:PivotTo(
			base * CFrame.new(left + size.X / 2, 0, cosmetic:NextNumber(-depthRoom, depthRoom)) * turn
		)
		local box, turnedSize = model:GetBoundingBox()
		local bottom = box.Position.Y - turnedSize.Y / 2
		model:PivotTo(model:GetPivot() + Vector3.new(0, base.Position.Y - bottom, 0))
		CollectionService:AddTag(model, Config.Grab.Tag)
		model.Parent = parent
		noteBuilt()
		shelfStocked += 1
		left += size.X + cosmetic:NextNumber(0.1, 0.5)
	end
end

-- Streamed shelf props go in their own folder inside the chunk, out of reach of the night rearranging
local function stockFolder(x: number, z: number): Folder
	local chunk = chunkFor(x, z)
	local folder = chunk:FindFirstChild("ShelfStock") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShelfStock"
		folder.Parent = chunk
	end
	return folder :: Folder
end

local function newBaySeed(): number
	return cosmetic:NextInteger(1, 2 ^ 31 - 1)
end

-- A baked bay's empty pallet slots: a wire deck across the beams where there's no floor, and the
-- slots handed to ShelfStream for props.
local function stockKitBay(bay: Model, name: string, x: number, z: number)
	local gaps = settings.KitShelfGaps[name]
	if not gaps then
		return
	end
	local box, size = bay:GetBoundingBox()
	local floor = box * CFrame.new(0, -size.Y / 2, 0)
	local slot = settings.KitShelfSlot
	for _, gap in gaps do
		if gap.y > 0 then
			block(
				bay,
				"WireDeck",
				Vector3.new(slot.X, 0.2, slot.Z),
				floor * CFrame.new(gap.x, gap.y - 0.1, 0),
				settings.RackDeck,
				Enum.Material.DiamondPlate
			)
		end
	end
	ShelfStream.addBay(
		floor,
		ShelfStock.gapSlots(gaps, slot.X, slot.Y, settings),
		newBaySeed(),
		stockFolder(x, z)
	)
end

-- rack_bay_empty with its stock streamed. The mesh only shows: its collision hull would wrap the
-- stock and stop the grab ray, so plain parts do the colliding instead. Decks sit just inside the
-- mesh decks (solid, so props can be placed on them); the end frames stop players walking through
-- but stay out of raycasts. Before the mesh is uploaded, posts and beams stand in for it.
local function buildEmptyBay(x: number, z: number, facing: Vector3)
	local floor = CFrame.lookAt(toWorld(x, z), toWorld(x, z) - facing)
	local uploaded = hasKit(EMPTY_BAY)
	local frame = Instance.new("Model")
	frame.Name = "RackBay"
	if uploaded then
		local mesh = placeKit(EMPTY_BAY, x, z, facing)
		if mesh then
			for _, part in mesh:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
				end
			end
			mesh.Parent = frame
		end
	end
	local halfDepth = settings.ShelfDepth / 2 + 0.1
	for _, level in settings.ShelfLevels do
		if level.y > 0 then
			block(
				frame,
				"Deck",
				Vector3.new(settings.ShelfWidth + 0.1, 0.04, settings.ShelfDepth),
				floor * CFrame.new(0, level.y - 0.03, 0),
				settings.RackDeck,
				Enum.Material.DiamondPlate
			)
			if not uploaded then
				for _, side in { -1, 1 } do
					local beam = block(
						frame,
						"Beam",
						Vector3.new(settings.ShelfWidth + 0.4, 0.35, 0.15),
						floor * CFrame.new(0, level.y - 0.2, side * halfDepth),
						settings.RackBeam,
						Enum.Material.Metal
					)
					detail(beam)
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		local sideX = side * (settings.ShelfWidth / 2 + 0.25)
		local endFrame = block(
			frame,
			"EndFrame",
			Vector3.new(0.3, settings.RackHeight, halfDepth * 2 + 0.3),
			floor * CFrame.new(sideX, settings.RackHeight / 2, 0),
			settings.RackUpright,
			Enum.Material.Metal
		)
		endFrame.Transparency = 1
		endFrame.CanQuery = false
		endFrame.CastShadow = false
		if not uploaded then
			for _, front in { -1, 1 } do
				local post = block(
					frame,
					"Post",
					Vector3.new(0.3, settings.RackHeight, 0.3),
					floor * CFrame.new(sideX, settings.RackHeight / 2, front * halfDepth),
					settings.RackUpright,
					Enum.Material.Metal
				)
				detail(post)
			end
		end
	end
	frame.Parent = chunkFor(x, z)
	ShelfStream.addBay(floor, ShelfStock.levelSlots(settings), newBaySeed(), stockFolder(x, z))
end

local function buildKitRack(shelf: WarehouseGen.Shelf): boolean
	if not hasKit("rack_bay_full") then
		return false
	end
	local length = shelf.x1 - shelf.x0
	local bays = math.max(1, math.floor(length / 12.1))
	local step = length / bays
	for n = 0, bays - 1 do
		local name = ShelfStock.pickBay(cosmetic:NextNumber(), settings.RackBays)
		if cosmetic:NextNumber() < settings.RackWreckChance then
			name = RACK_WRECKS[cosmetic:NextInteger(1, #RACK_WRECKS)]
		end
		if name ~= EMPTY_BAY and not hasKit(name) then
			name = "rack_bay_full"
		end
		local facing = if cosmetic:NextNumber() < 0.5 then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
		local x = shelf.x0 + (n + 0.5) * step
		if name == EMPTY_BAY then
			buildEmptyBay(x, shelf.z, facing)
		else
			local bay = placeKit(name, x, shelf.z, facing)
			if bay then
				stockKitBay(bay, name, x, shelf.z)
			end
		end
	end
	if hasKit("rack_end") then
		placeKit("rack_end", shelf.x0 - 1.2, shelf.z, Vector3.new(-1, 0, 0))
		placeKit("rack_end", shelf.x1 + 1.2, shelf.z, Vector3.new(1, 0, 0))
	end
	return true
end

local function buildRack(shelf: WarehouseGen.Shelf)
	if buildKitRack(shelf) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Racking"
	local length = shelf.x1 - shelf.x0
	local centre = (shelf.x0 + shelf.x1) / 2
	local height = settings.RackHeight

	local uprights = math.max(2, math.ceil(length / settings.RackBay) + 1)
	for n = 0, uprights - 1 do
		local x = shelf.x0 + 0.3 + (length - 0.6) * n / (uprights - 1)
		block(
			model,
			"Upright",
			Vector3.new(0.6, height, shelf.depth),
			CFrame.new(toWorld(x, shelf.z, height / 2)),
			settings.RackUpright,
			Enum.Material.Metal
		)
	end
	for _, y in settings.RackDecks do
		block(
			model,
			"Deck",
			Vector3.new(length, 0.5, shelf.depth),
			CFrame.new(toWorld(centre, shelf.z, y + 0.25)),
			settings.RackBeam,
			Enum.Material.Metal
		)
		-- Packed with boxed stock, a few gaps where things were taken
		local runs = cosmetic:NextInteger(settings.RackStock[1], settings.RackStock[2])
		local slot = length / runs
		for r = 0, runs - 1 do
			if cosmetic:NextNumber() >= 0.85 then
				local base = CFrame.new(toWorld(shelf.x0 + r * slot + slot / 2, shelf.z, y + 0.5))
				stockSlot(base, Vector3.new(slot * 0.9, 5.5, shelf.depth - 0.4), model)
			else
				local runLength = slot * cosmetic:NextNumber(0.6, 0.95)
				local runHeight = cosmetic:NextNumber(3, 5.5)
				local x = shelf.x0 + r * slot + slot / 2
				local shade = cosmetic:NextNumber(0.75, 1.1)
				block(
					model,
					"Stock",
					Vector3.new(runLength, runHeight, shelf.depth - 0.4),
					CFrame.new(toWorld(x, shelf.z, y + 0.5 + runHeight / 2)),
					settings.Cardboard:Lerp(Color3.new(0, 0, 0), 1 - math.min(shade, 1)),
					Enum.Material.Cardboard
				)
			end
		end
	end
	model.Parent = chunkFor(centre, shelf.z)
end

-- An aisle number hanging over the end of a rack row on a cable. The number goes on the sign's
-- Screen faces (or its Body) so it fits the sign, not the world.
local function buildSign(sign: WarehouseGen.Sign)
	local name = if hasKit("aisle_sign_hanging") then "aisle_sign_hanging" else "aisle_sign"
	local model = ModelLibrary.get(name)
	if not model then
		return
	end
	placeModel(model, sign.x, sign.z, Vector3.new(-1, 0, 0), false)
	local _, size = model:GetBoundingBox()
	local top = settings.RackHeight + settings.AisleSignGap
	model:PivotTo(model:GetPivot() + Vector3.new(0, top - size.Y, 0))
	local color = Color3.fromRGB(230, 226, 214)
	local text = tostring(sign.number)
	local screens = {}
	for _, partName in { "Screen", "Screen2" } do
		local screen = model:FindFirstChild(partName, true)
		if screen and screen:IsA("BasePart") then
			table.insert(screens, screen)
		end
	end
	if #screens > 0 then
		for _, screen in screens do
			textGui(screen, Enum.NormalId.Front, text, color, Enum.Font.Oswald)
			textGui(screen, Enum.NormalId.Back, text, color, Enum.Font.Oswald)
		end
	else
		local body = model:FindFirstChild("Body", true)
		if body and body:IsA("BasePart") then
			textGui(body, Enum.NormalId.Front, text, color, Enum.Font.Oswald)
			textGui(body, Enum.NormalId.Back, text, color, Enum.Font.Oswald)
		end
	end
	local cable = settings.CeilingHeight - top
	local wire = block(
		model,
		"Cable",
		Vector3.new(0.1, cable, 0.1),
		CFrame.new(toWorld(sign.x, sign.z, top + cable / 2)),
		settings.CableColor,
		Enum.Material.Metal
	)
	detail(wire)
	if sign.smile then
		-- Rearrange leaves it alone; client SmileAisle makes it read 41 when nobody's looking
		model:SetAttribute("SmileAisle", true)
		CollectionService:AddTag(model, "SmileAisleSign")
	end
	model.Parent = chunkFor(sign.x, sign.z)
	noteBuilt()
end

-- A department name on a board hanging from the roof on two very long cables
local function buildDeptSign(sign: WarehouseGen.DeptSign)
	local parent = chunkFor(sign.x, sign.z)
	local board = block(
		parent,
		"DeptSign",
		Vector3.new(20, 5, 0.6),
		CFrame.new(toWorld(sign.x, sign.z, sign.y))
			* CFrame.Angles(0, math.rad(cosmetic:NextNumber(-6, 6)), 0),
		Color3.fromRGB(196, 190, 172),
		Enum.Material.SmoothPlastic
	)
	detail(board)
	local ink = Color3.fromRGB(46, 52, 64)
	textGui(board, Enum.NormalId.Front, sign.text, ink, Enum.Font.GothamBlack)
	textGui(board, Enum.NormalId.Back, sign.text, ink, Enum.Font.GothamBlack)
	local cable = settings.CeilingHeight - sign.y - 2.5
	for _, dx in { -8, 8 } do
		local wire = block(
			parent,
			"Cable",
			Vector3.new(0.12, cable, 0.12),
			board.CFrame * CFrame.new(dx, 2.5 + cable / 2, 0),
			settings.CableColor,
			Enum.Material.Metal
		)
		detail(wire)
	end
end

local function buildLight(light: WarehouseGen.Light)
	local parent = chunkFor(light.x, light.z)
	local tone = settings.LightTones[light.tone] or settings.LightTones.cold
	local size = if light.axis == "x"
		then Vector3.new(light.length, 0.35, 0.8)
		else Vector3.new(0.8, 0.35, light.length)
	local dead = light.state == "dead"
	local strip = block(
		parent,
		"LightStrip",
		size,
		CFrame.new(toWorld(light.x, light.z, light.y)),
		if dead then Color3.fromRGB(70, 72, 74) else tone.glow,
		if dead then Enum.Material.SmoothPlastic else Enum.Material.Neon
	)
	detail(strip)
	if not dead then
		local emergency = cosmetic:NextInteger(1, settings.EmergencyEvery) == 1
		if emergency or cosmetic:NextInteger(1, settings.LightEvery) == 1 then
			local glow = Instance.new("SurfaceLight")
			glow.Face = Enum.NormalId.Bottom
			glow.Color = tone.light
			glow.Brightness = tone.brightness
			glow.Range = tone.range
			glow.Angle = 120
			glow.Shadows = false
			glow.Parent = strip
		end
		strip:SetAttribute("Glow", tone.glow)
		strip:SetAttribute("LightColor", tone.light)
		strip:SetAttribute("Brightness", tone.brightness)
		strip:SetAttribute("Range", tone.range)
		strip:SetAttribute("Emergency", emergency)
		CollectionService:AddTag(strip, LIGHT_TAG)
	end
	if light.state == "flicker" then
		CollectionService:AddTag(strip, FLICKER_TAG)
	end
	local wire = block(
		parent,
		"Cable",
		Vector3.new(0.1, light.cable, 0.1),
		CFrame.new(toWorld(light.x, light.z, light.y + light.cable / 2)),
		settings.CableColor,
		Enum.Material.Metal
	)
	detail(wire)
end

local SIDE_FACES = { Enum.NormalId.Front, Enum.NormalId.Back }

local function buildPiece(spec: WarehouseGen.Piece)
	if spec.kitOnly then
		if hasKit(spec.kit) then
			placeKit(spec.kit :: string, spec.x, spec.z, facingFromTurn(spec.turn), spec.y, true)
		end
		return
	end
	if hasKit(spec.skipIfKit) then
		return
	end
	if hasKit(spec.kit) then
		placeKit(spec.kit :: string, spec.x, spec.z, facingFromTurn(spec.turn), nil, true)
		return
	end
	if hasKit(spec.kitFloor) then
		tileKitFloor(
			spec.kitFloor :: string,
			spec.x - spec.sx / 2,
			spec.z - spec.sz / 2,
			spec.x + spec.sx / 2,
			spec.z + spec.sz / 2,
			spec.y - spec.sy / 2
		)
	end
	local style = settings.Styles[spec.style]
	if not style then
		warn(`[Warehouse] no style "{spec.style}"`)
		return
	end
	local parent = chunkFor(spec.x, spec.z)
	local part: BasePart
	local cframe = CFrame.new(toWorld(spec.x, spec.z, spec.y)) * CFrame.Angles(0, math.rad(spec.turn), 0)
	if spec.lean then
		cframe *= CFrame.Angles(math.rad(spec.lean), 0, 0)
	end
	if spec.shape == "wedge" then
		part = Instance.new("WedgePart")
		part.Size = Vector3.new(spec.sx, spec.sy, spec.sz)
		part.CFrame = cframe
	elseif spec.shape == "ball" then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(spec.sx, spec.sx, spec.sx)
		ball.CFrame = cframe
		part = ball
	elseif spec.shape == "cylinder_wall" then
		-- A disc flat against a wall: the cylinder's axis points out of the wall (z)
		local disc = Instance.new("Part")
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(spec.sz, spec.sx, spec.sy)
		disc.CFrame = cframe * CFrame.Angles(0, math.rad(90), 0)
		part = disc
	elseif spec.shape == "cylinder" then
		local cylinder = Instance.new("Part")
		cylinder.Shape = Enum.PartType.Cylinder
		-- A cylinder's axis is its X, so stand it up
		cylinder.Size = Vector3.new(spec.sy, spec.sx, spec.sz)
		cylinder.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
		part = cylinder
	else
		part = Instance.new("Part")
		part.Size = Vector3.new(spec.sx, spec.sy, spec.sz)
		part.CFrame = cframe
	end
	part.Name = spec.style
	part.Anchored = true
	part.Color = style.color
	part.Material = style.material
	part.Transparency = style.transparency or 0
	part.Reflectance = style.reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not spec.collide then
		detail(part)
	end
	if spec.label then
		for _, face in SIDE_FACES do
			textGui(part, face, spec.label, Color3.fromRGB(236, 228, 210), Enum.Font.FredokaOne)
		end
	end
	if spec.paint == "sky_floor" then
		paintFace(part, Enum.NormalId.Top, "sky")
	elseif spec.paint == "hill" or spec.paint == "stars" then
		for _, face in SIDE_FACES do
			paintFace(part, face, spec.paint)
		end
	elseif spec.paint then
		if spec.sy < 2 then
			paintFace(part, Enum.NormalId.Bottom, spec.paint)
		else
			for _, face in
				{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
			do
				paintFace(part, face, spec.paint)
			end
		end
	end
	if spec.lamp then
		local tone = settings.LampTones[spec.lamp]
		if tone then
			local glow: Light
			if spec.sy <= 0.4 then
				local surface = Instance.new("SurfaceLight")
				surface.Face = if spec.y < 1 then Enum.NormalId.Top else Enum.NormalId.Bottom
				surface.Angle = 140
				glow = surface
			else
				glow = Instance.new("PointLight")
			end
			glow.Color = tone.color
			glow.Brightness = tone.brightness
			glow.Range = tone.range
			glow.Shadows = false
			glow.Parent = part
		end
		-- Not a strip light, so it never goes dark at night; it just blinks when you're near
		if spec.flicker then
			part:SetAttribute("AlwaysOn", true)
			CollectionService:AddTag(part, FLICKER_TAG)
		end
	end
	if settings.MovableStyles[spec.style] and longestSide(part.Size) <= settings.MaxGrabSize then
		CollectionService:AddTag(part, Config.Grab.Tag)
	end
	part.Parent = parent
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
			settings.Cardboard:Lerp(Color3.new(0, 0, 0), cosmetic:NextNumber(0, 0.3)),
			Enum.Material.Cardboard
		)
		CollectionService:AddTag(part, Config.Grab.Tag)
	end
end

-- A robot room is an installation set: its walls are pieces, so the model holds just its furniture
local function buildRoom(room: any)
	local model = Instance.new("Model")
	model.Name = `Room{room.id}`
	model:SetAttribute("RoomId", room.id)
	model:SetAttribute("Kind", room.kind)
	for _, item in room.items do
		spawnModel(item.name, model, item.x, item.z, Vector3.new(item.nx, 0, item.nz), false)
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
	detail(part)
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

local function waitForLayout()
	if not layout then
		layoutReady.Event:Wait()
	end
end

function Warehouse.layout(): WarehouseGen.Layout
	waitForLayout()
	return layout
end

function Warehouse.rooms(): { any }
	waitForLayout()
	return layout.rooms
end

-- A count tuned for Config.Warehouse.TunedSize, scaled to this server's warehouse
function Warehouse.scaled(count: number): number
	waitForLayout()
	return WarehouseSizes.scaled(layout.size, count, settings)
end

-- 0 at the entrance, 1 at the far corners
function Warehouse.depth(position: Vector3): number
	waitForLayout()
	local relative = position - settings.Origin
	return WarehouseGen.depth(layout, relative.X, relative.Z)
end

function Warehouse.roomAt(position: Vector3): any?
	waitForLayout()
	local relative = position - settings.Origin
	return WarehouseGen.roomAt(layout, relative.X, relative.Z)
end

-- The dreamcore pocket a spot is inside, if any (kind: poolroom, flooded, office, ...)
function Warehouse.pocketAt(position: Vector3): WarehouseGen.Pocket?
	waitForLayout()
	local relative = position - settings.Origin
	return WarehouseGen.pocketAt(layout, relative.X, relative.Z)
end

function Warehouse.toWorld(x: number, z: number): Vector3
	return toWorld(x, z)
end

function Warehouse.Init()
	buildHaze()
end

function Warehouse.Start()
	ModelLibrary.preloadImages()
	local seed = if settings.Seed == 0 then Random.new():NextInteger(1, 2 ^ 31 - 1) else settings.Seed
	layout = WarehouseGen.generate(WarehouseSizes.configFor(SizeServers.choice().size, settings), seed)
	cosmetic = Random.new(seed)
	layoutReady:Fire()

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
	-- A size server reads its settings before building, so early arrivals spawned in the test room
	if game.PrivateServerId ~= "" then
		for _, player in Players:GetPlayers() do
			if player.Character then
				task.spawn(player.LoadCharacter, player)
			end
		end
	end
	buildShell(shell)
	buildPillars()
	for _, room in layout.rooms do
		buildRoom(room)
	end
	-- Where the installations are, for the client soundtrack (it switches music near one)
	local markers = Instance.new("Folder")
	markers.Name = "Installations"
	for index, hall in layout.pockets do
		local marker = Instance.new("Vector3Value")
		marker.Name = `{hall.kind}_{index}`
		marker.Value = toWorld((hall.x0 + hall.x1) / 2, (hall.z0 + hall.z1) / 2)
		marker:SetAttribute("Radius", math.max(hall.x1 - hall.x0, hall.z1 - hall.z0) / 2)
		marker.Parent = markers
	end
	markers.Parent = ReplicatedStorage
	ShelfStream.setBudget(WarehouseSizes.scaled(layout.size, settings.ShelfStreamBudget, settings))
	for _, shelf in layout.shelves do
		buildRack(shelf)
	end
	for _, spec in layout.pieces do
		buildPiece(spec)
	end
	for _, light in layout.lights do
		buildLight(light)
	end
	for _, sign in layout.deptSigns do
		buildDeptSign(sign)
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
