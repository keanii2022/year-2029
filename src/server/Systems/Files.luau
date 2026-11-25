-- The 2029 Files: lore a player has found, kept in their save. Sources: survivor journals
-- (NightTricks calls Files.find), lost kid sightings (Haunts "kid_peek" scares) and one guaranteed
-- piece a day (a tape or a TV, placed here) that the TODAY list's lore mission points at. Reading
-- the daily piece gives your own next unfound entry of its kind, so everyone on the server gains
-- from the same one. Every Config.Files.PerChapter finds opens a chapter; the FilesFound stat
-- unlocks the cosmetics (Config.Saves). The client draws the FILES page from Net "FilesState".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FilesLogic = require(ReplicatedStorage.Shared.Logic.Files)
local HauntPlacement = require(ReplicatedStorage.Shared.Logic.HauntPlacement)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Haunts = require(script.Parent.Haunts)
local Saves = require(script.Parent.Saves)
local Scores = require(script.Parent.Scores)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Files
local Daily = Settings.Daily
local catalog = FilesLogic.catalog(Settings, Config.NightTricks.Journals)

local Files = {}

local random = Random.new()
local stateRemote: RemoteEvent
local loreRemote: RemoteEvent
local folder: Folder
local piece: Model? = nil
local readToday: { [Player]: boolean } = {}

local function fill(text: string, values: { [string]: string }): string
	return (string.gsub(text, "{(%w+)}", function(key)
		return values[key]
	end))
end

local function sendState(player: Player)
	local data = Saves.data(player)
	if data and player.Parent then
		stateRemote:FireClient(player, { found = table.clone(data.files) })
	end
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Daily piece ------------------------------------------------------------------------------------

local function kindsFrom(first: string): { string }
	local kinds = { first }
	for _, kind in Daily.Kinds do
		if kind ~= first then
			table.insert(kinds, kind)
		end
	end
	return kinds
end

local function onPieceUsed(player: Player, kind: string)
	local data = Saves.data(player)
	if not data or not aliveRoot(player) then
		return
	end
	readToday[player] = true
	local entry = FilesLogic.nextOf(catalog, data.files, kindsFrom(kind))
	if entry then
		loreRemote:FireClient(player, entry.title, entry.text)
		Files.find(player, entry.id)
	else
		loreRemote:FireClient(player, Daily.AllFoundTitle, Daily.AllFoundText)
	end
end

local function findSpot(): HauntPlacement.Spot?
	local layout = Warehouse.layout()
	local half = layout.half - Config.Warehouse.WallThickness - Daily.SpotPad
	local function clear(x: number, z: number): boolean
		return WarehouseGen.depth(layout, x, z) >= Daily.MinDepth
			and WarehouseGen.isClear(layout, Config.Warehouse, x, z, Daily.SpotPad)
	end
	local spots = HauntPlacement.spots(1, half, 0, Daily.SpotTries, clear, {}, function()
		return random:NextNumber()
	end)
	return spots[1]
end

local function placePiece(day: number)
	if piece then
		piece:Destroy()
		piece = nil
	end
	table.clear(readToday)
	local kind = Daily.Kinds[day % #Daily.Kinds + 1]
	local spot = findSpot()
	local model = spot and ModelLibrary.get(Daily.Models[kind])
	if not spot or not model then
		return
	end
	-- Not a working TV for Interact: this one only plays its file
	model:SetAttribute("ModelName", nil)
	local radians = math.rad(spot.turn)
	local rotation = CFrame.lookAt(Vector3.zero, -Vector3.new(math.sin(radians), 0, math.cos(radians)))
	model:PivotTo(rotation)
	local box, size = model:GetBoundingBox()
	local target = Warehouse.toWorld(spot.x, spot.z)
	model:PivotTo(rotation + (target - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		model:Destroy()
		return
	end
	local hum = Instance.new("PointLight")
	hum.Range = Daily.Hum.Range
	hum.Brightness = Daily.Hum.Brightness
	hum.Shadows = false
	hum.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Daily.Prompts[kind]
	prompt.ObjectText = Daily.ObjectText
	prompt.MaxActivationDistance = Daily.PromptReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		onPieceUsed(player, kind)
	end)
	model.Parent = folder
	piece = model
end

local function waitForWarehouse()
	local root = workspace:FindFirstChild("Warehouse")
	while not (root and root:GetAttribute("Built")) do
		task.wait(1)
		root = workspace:FindFirstChild("Warehouse")
	end
end

-- Public -----------------------------------------------------------------------------------------

-- Records a find. Quietly does nothing for unknown ids, repeats, or before the save loads.
function Files.find(player: Player, id: string)
	local data = Saves.data(player)
	if not data then
		return
	end
	local before = FilesLogic.count(data.files, catalog)
	if not FilesLogic.add(data.files, catalog, id) then
		return
	end
	local count = before + 1
	local chapters = #Settings.Chapters
	Saves.markDirty(player, true)
	Scores.raise(player, "FilesFound", count)
	Saves.tell(player, fill(Settings.FoundLine, { count = tostring(count), total = tostring(#catalog) }))
	if
		FilesLogic.chaptersOpen(count, Settings.PerChapter, chapters)
		> FilesLogic.chaptersOpen(before, Settings.PerChapter, chapters)
	then
		task.delay(2.5, Saves.tell, player, Settings.ChapterLine)
	end
	sendState(player)
end

-- Where today's piece is, for the lore mission's arrow
function Files.piecePosition(): Vector3?
	return if piece and piece.Parent then piece:GetPivot().Position else nil
end

function Files.readToday(player: Player): boolean
	return readToday[player] == true
end

-- Shows an entry on the player's lore note and records it (repeats just show it again)
function Files.read(player: Player, id: string)
	local entry = FilesLogic.byId(catalog, id)
	if entry then
		loreRemote:FireClient(player, entry.title, entry.text)
		Files.find(player, id)
	end
end

function Files.Init()
	stateRemote = Net.event("FilesState")
	loreRemote = Net.event("LoreNote")
	folder = Instance.new("Folder")
	folder.Name = "DailyLore"
	folder.Parent = workspace
	Net.event("FilesSync").OnServerEvent:Connect(sendState)
	Saves.onLoaded(sendState)
	Haunts.onScare(function(player, scare)
		local data = Saves.data(player)
		if scare ~= Settings.SightingScare or not data then
			return
		end
		local entry = FilesLogic.nextOf(catalog, data.files, { "sighting" })
		if entry then
			Files.find(player, entry.id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		readToday[player] = nil
	end)
end

function Files.Start()
	waitForWarehouse()
	placePiece(DayNight.day())
	DayNight.onPhaseChanged(function(phase, _previous, day)
		if phase == "Day" then
			placePiece(day)
		end
	end)
end

return Files
