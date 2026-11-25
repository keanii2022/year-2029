-- Stats, all-time leaderboards and cosmetics. Stats live in the player's save (Saves).
-- Counts downs, longest life and nights survived itself; other systems call Scores.add
-- (robots: "RobotKills", combat: "PlayerKills").
-- Boards are global, read from OrderedDataStores every few minutes, so they never show who is on
-- this server right now (the player list stays hidden). Weekly boards use a store per week.
-- Cosmetics are earned from stats and built from plain parts on the character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SavesLogic = require(ReplicatedStorage.Shared.Logic.Saves)
local ScoresLogic = require(ReplicatedStorage.Shared.Logic.Scores)
local DayNight = require(script.Parent.DayNight)
local Saves = require(script.Parent.Saves)

type SavesData = SavesLogic.Data

local Settings = Config.Saves
local BoardSettings = Settings.Boards
local Cosmetics = Settings.Cosmetics :: any

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local EQUIP_GAP = 0.2
local UNNAMED = "Survivor"

local Scores = {}

local lifeStartedAt: { [Player]: number } = {}
local nightStartedAt: number? = nil
local pending: { [Player]: { [string]: number } } = {}
local boardWritten: { [Player]: { [string]: number } } = {}
local worn: { [Player]: { Instance } } = {}
local lastEquipAt: { [Player]: number } = {}
local names: { [number]: string } = {}
-- One list of row labels per board column, across every board in the world
local boardRows: { [string]: { { TextLabel } } } = {}
local recordRemote: RemoteEvent

local function sendRecord(player: Player)
	local data = Saves.data(player)
	if not data or not player.Parent then
		return
	end
	recordRemote:FireClient(player, {
		stats = table.clone(data.stats),
		wearing = ScoresLogic.wearing(Cosmetics, data.cosmetics, data.stats),
		chosen = table.clone(data.cosmetics),
		saving = Saves.canSave(player),
	})
end

-- Cosmetics -------------------------------------------------------------------------------------

local function find(slot: string, id: string?): any
	for _, def in Cosmetics[slot] do
		if def.id == id then
			return def
		end
	end
	return nil
end

local function plain(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

local function buildHat(def: any, head: BasePart, colour: Color3, into: { Instance })
	for _, spec in def.parts do
		local part: BasePart
		if spec.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			block.Shape = Enum.PartType[spec.shape]
			part = block
		end
		plain(part)
		part.Name = "Cosmetic"
		part.Size = spec.size
		part.Material = spec.material
			or (if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		part.Color = if spec.paint then colour else spec.color or Color3.fromRGB(60, 60, 62)
		part.CFrame = head.CFrame * CFrame.new(spec.offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = head.Parent
		table.insert(into, part)
	end
end

local function buildTrail(def: any, root: BasePart, colour: Color3, into: { Instance })
	local top = Instance.new("Attachment")
	top.Name = "CosmeticTrailTop"
	top.Position = Vector3.new(0, def.width / 2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "CosmeticTrailBottom"
	bottom.Position = Vector3.new(0, -def.width / 2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = def.lifetime
	trail.Color = ColorSequence.new(colour)
	trail.Transparency = NumberSequence.new(def.transparency, 1)
	trail.LightEmission = if def.neon then 1 else 0
	trail.FaceCamera = true
	trail.Parent = root
	table.insert(into, top)
	table.insert(into, bottom)
	table.insert(into, trail)
end

local function applyCosmetics(player: Player)
	for _, instance in worn[player] or {} do
		instance:Destroy()
	end
	worn[player] = nil
	local data = Saves.data(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not head or not root then
		return
	end
	local wearing = ScoresLogic.wearing(Cosmetics, data.cosmetics, data.stats)
	local colourDef = find("Colour", wearing.Colour)
	local colour = if colourDef then colourDef.color else TEXT
	local built = {}
	local hat = find("Hat", wearing.Hat)
	if hat then
		buildHat(hat, head, colour, built)
	end
	local trail = find("Trail", wearing.Trail)
	if trail then
		buildTrail(trail, root, colour, built)
	end
	worn[player] = built
end

local function onEquip(player: Player, slot: any, id: any)
	local now = os.clock()
	if now - (lastEquipAt[player] or 0) < EQUIP_GAP then
		return
	end
	lastEquipAt[player] = now
	local data = Saves.data(player)
	if not data or type(slot) ~= "string" or (id ~= nil and type(id) ~= "string") then
		return
	end
	if not ScoresLogic.canEquip(Cosmetics, slot, id, data.stats) then
		return
	end
	data.cosmetics[slot] = id
	Saves.markDirty(player)
	applyCosmetics(player)
	sendRecord(player)
end

-- Stats ----------------------------------------------------------------------------------------

local function afterChange(player: Player, before: { [string]: number })
	local data = Saves.data(player)
	if not data then
		return
	end
	Saves.markDirty(player)
	for _, label in ScoresLogic.newUnlocks(Cosmetics, before, data.stats) do
		Saves.tell(player, `Unlocked: {label}`)
	end
	sendRecord(player)
end

-- data is passed in when the player is leaving and Saves no longer hands it out.
local function recordLife(player: Player, data: SavesData?)
	local started = lifeStartedAt[player]
	lifeStartedAt[player] = nil
	if started and data then
		local before = table.clone(data.stats)
		if ScoresLogic.recordLife(data.stats, os.clock() - started) then
			afterChange(player, before)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	lifeStartedAt[player] = os.clock()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	character:WaitForChild("Head", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		Scores.add(player, "Downs", 1)
		recordLife(player, Saves.data(player))
	end)
	applyCosmetics(player)
end

local function onPhaseChanged(phase: string, previous: string)
	if phase == "Night" then
		nightStartedAt = os.clock()
	elseif phase == "Day" and previous == "Night" then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				humanoid
				and humanoid.Health > 0
				and ScoresLogic.survivedNight(lifeStartedAt[player], nightStartedAt)
			then
				Scores.add(player, "NightsSurvived", 1)
				Saves.tell(player, "You made it through the night")
			end
		end
		nightStartedAt = nil
	end
end

local function onLoaded(player: Player)
	local queued = pending[player]
	pending[player] = nil
	for stat, amount in queued or {} do
		Scores.add(player, stat, amount)
	end
	applyCosmetics(player)
	sendRecord(player)
end

-- Boards ---------------------------------------------------------------------------------------

local function thisWeek(): number
	return ScoresLogic.weekOf(os.time())
end

local function boardKey(board: any): string
	return ScoresLogic.boardKey(board.stat, board.weekly, thisWeek())
end

local function writeBoards(player: Player, data: SavesData)
	local written = boardWritten[player] or {}
	boardWritten[player] = written
	for _, board in BoardSettings.List do
		local value = if board.weekly
			then ScoresLogic.weekValue(data.weekly, thisWeek())
			else data.stats[board.stat] or 0
		local key = boardKey(board)
		if value > 0 and value ~= written[key] then
			written[key] = value
			Saves.writeBoard(key, player.UserId, value)
		end
	end
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = false, nil
	if userId > 0 then
		ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	end
	names[userId] = if ok and name then name else UNNAMED
	return names[userId]
end

local function textLabel(props: { [string]: any }, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = TEXT
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function buildBoard(home: CFrame, folder: Folder)
	local size = BoardSettings.PartSize
	local part = Instance.new("Part")
	part.Name = "Leaderboard"
	part.Anchored = true
	part.Size = size
	part.Color = PANEL
	part.Material = Enum.Material.Metal
	-- Upright and flush to the wall; the front face (-z) looks out the same way as the frame
	part.CFrame = home * CFrame.new(BoardSettings.Offset.X, size.Y / 2 + 1, -(size.Z / 2 + 0.1))

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 600)
	gui.LightInfluence = 0.3
	gui.Parent = part
	textLabel({
		Size = UDim2.new(1, 0, 0, 90),
		Text = BoardSettings.Title,
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = -2,
	}, gui)
	local columns = #BoardSettings.List
	for index, board in BoardSettings.List do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.Position = UDim2.new((index - 1) / columns, 12, 0, 100)
		column.Size = UDim2.new(1 / columns, -24, 1, -110)
		column.Parent = gui
		textLabel({
			Size = UDim2.new(1, 0, 0, 30),
			Text = board.title,
			TextScaled = true,
			TextTransparency = 0.2,
		}, column)
		local rows = {}
		for row = 1, BoardSettings.Size do
			rows[row] = textLabel({
				Position = UDim2.fromOffset(0, 36 + (row - 1) * 44),
				Size = UDim2.new(1, 0, 0, 40),
				Text = "",
				TextSize = 20,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, column)
		end
		boardRows[board.stat] = boardRows[board.stat] or {}
		table.insert(boardRows[board.stat], rows)
	end
	part.Parent = folder
end

local function refreshBoards()
	for _, board in BoardSettings.List do
		local rows = Saves.readBoard(boardKey(board), BoardSettings.Size)
		if rows then
			local texts = {}
			for rank = 1, BoardSettings.Size do
				local row = rows[rank]
				texts[rank] = if row then `{rank}. {nameOf(row.userId)}   {row.value}` else ""
			end
			for _, labels in boardRows[board.stat] or {} do
				for rank, label in labels do
					label.Text = texts[rank]
				end
			end
		end
	end
end

local function boardLoop()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	for _, spot in Saves.homeSpots() do
		buildBoard(spot, folder)
	end
	local lastWrite = os.clock()
	while true do
		refreshBoards()
		task.wait(BoardSettings.ReadInterval)
		if os.clock() - lastWrite >= BoardSettings.WriteInterval then
			lastWrite = os.clock()
			for _, player in Players:GetPlayers() do
				local data = Saves.data(player)
				if data and Saves.canSave(player) then
					writeBoards(player, data)
				end
			end
		end
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Public ---------------------------------------------------------------------------------------

-- Adds amount (default 1, whole and positive) to a stat for this player. Unknown stats are ignored.
-- Safe to call before their save has loaded; it's held until then.
function Scores.add(player: Player, stat: string, amount: number?)
	local count = amount or 1
	local data = Saves.data(player)
	if not data then
		if player.Parent then
			local queue = pending[player] or {}
			pending[player] = queue
			queue[stat] = (queue[stat] or 0) + count
		end
		return
	end
	local before = table.clone(data.stats)
	if ScoresLogic.add(data.stats, Settings.Stats, stat, count) then
		afterChange(player, before)
	end
end

-- Sets a best-of stat (BestHaul, StreakDays, FilesFound) when value beats it.
function Scores.raise(player: Player, stat: string, value: number)
	local data = Saves.data(player)
	if not data then
		return
	end
	local before = table.clone(data.stats)
	if ScoresLogic.raise(data.stats, Settings.Stats, stat, value) then
		afterChange(player, before)
	end
end

-- Notes nights survived in this one life for the weekly board.
function Scores.recordWeekLife(player: Player, nights: number)
	local data = Saves.data(player)
	if data and ScoresLogic.recordWeekLife(data.weekly, thisWeek(), nights) then
		Saves.markDirty(player)
	end
end

function Scores.get(player: Player, stat: string): number
	local data = Saves.data(player)
	return if data then data.stats[stat] or 0 else 0
end

-- A copy of every stat, or an empty table while the save loads.
function Scores.stats(player: Player): { [string]: number }
	local data = Saves.data(player)
	return if data then table.clone(data.stats) else {}
end

function Scores.Init()
	recordRemote = Net.event("RecordState")
	Net.event("CosmeticEquip").OnServerEvent:Connect(onEquip)
	Net.event("RecordSync").OnServerEvent:Connect(sendRecord)
	Saves.onLoaded(onLoaded)
	Saves.onLeaving(function(player, data)
		recordLife(player, data)
		task.spawn(function()
			writeBoards(player, data)
			boardWritten[player] = nil
		end)
	end)
end

function Scores.Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		worn[player] = nil
		lastEquipAt[player] = nil
	end)
	DayNight.onPhaseChanged(onPhaseChanged)
	task.spawn(boardLoop)
end

return Scores
