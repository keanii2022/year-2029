-- PA events: every few minutes with the lights on (rarer at night) the store PA calls out a spot and
-- something worth the walk turns up there: a delivery crate drops in a numbered aisle, an
-- installation's prize chests refill, a lost item waits at the front desk, or a bait prize counts
-- down under a huge beam. Now and then a rumor crackles over the radio instead, with no beam at all.
-- A beam of light marks the spot; clients get the line for the chime, subtitle and screen-edge arrow.
-- Where it lands and how soon is quietly steered by the Director so groups run into each other.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DirectorLogic = require(ReplicatedStorage.Shared.Logic.Director)
local Installations = require(ReplicatedStorage.Shared.Logic.WarehouseGenInstallations)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PrizesLogic = require(ReplicatedStorage.Shared.Logic.Prizes)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Director = require(script.Parent.Director)
local Loudness = require(script.Parent.Loudness)
local PrizeChests = require(script.Parent.PrizeChests)
local SimPlayers = require(script.Parent.SimPlayers)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Prizes.Pa
local Steering = Config.Director

type Site = { name: string?, x: number, z: number, y: number?, place: boolean? }

local PaEvents = {}

local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 1))
local eventRemote: RemoteEvent
local folder: Folder

local function clearAt(pad: number): (number, number) -> boolean
	local layout = Warehouse.layout()
	return function(x, z)
		return WarehouseGen.isClear(layout, Config.Warehouse, x, z, pad)
	end
end

local function beam(position: Vector3, look: any): BasePart
	local part = Instance.new("Part")
	part.Name = "PaBeam"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = look.Color
	part.Transparency = look.Transparency
	part.Size = Vector3.new(look.Height, look.Width, look.Width)
	part.CFrame = CFrame.new(position + Vector3.new(0, look.Height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	local glow = Instance.new("Attachment")
	glow.Position = Vector3.new(-look.Height / 2 + 2, 0, 0)
	glow.Parent = part
	local light = Instance.new("PointLight")
	light.Color = look.Color
	light.Range = look.LightRange
	light.Brightness = look.LightBrightness
	light.Shadows = false
	light.Parent = glow
	part.Parent = folder
	return part
end

local function sound(parent: Instance, name: string, loudness: string, looped: boolean): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local noise = Instance.new("Sound")
	noise.SoundId = id
	noise.Looped = looped
	noise.RollOffMinDistance, noise.RollOffMaxDistance = Loudness.rollOff(loudness :: any)
	noise.Parent = parent
	return noise
end

-- Drops the crate onto its spot from above, with a bang when it lands
local function drop(chest: PrizeChests.Chest)
	local landed = chest.model:GetPivot()
	local fall = Instance.new("NumberValue")
	fall.Value = Settings.DropHeight
	fall.Changed:Connect(function(height)
		chest.model:PivotTo(landed + Vector3.new(0, height, 0))
	end)
	chest.model:PivotTo(landed + Vector3.new(0, Settings.DropHeight, 0))
	local tween = TweenService:Create(
		fall,
		TweenInfo.new(Settings.DropTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 0 }
	)
	tween.Completed:Once(function()
		fall:Destroy()
		local bang = sound(chest.root, Settings.DropSound, Settings.DropLoudness, false)
		if bang then
			bang.PlayOnRemove = true
			bang:Destroy()
		end
		Loudness.emit(chest.root.Position, Settings.DropLoudness, chest.model)
	end)
	tween:Play()
end

-- The bait crate stays shut under a ticking countdown, then unlocks with a jingle everyone hears
local function countdown(chest: PrizeChests.Chest, seconds: number)
	local look = Settings.Bait
	PrizeChests.setLocked(chest, true)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 50)
	board.StudsOffset = Vector3.new(0, 6, 0)
	board.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Settings.Events.bait.beam.Color
	label.TextStrokeTransparency = 0.3
	label.Parent = board
	board.Parent = chest.root
	local ticking = sound(chest.root, look.TickSound, "normal", true)
	if ticking then
		ticking:Play()
	end
	for left = seconds, 1, -1 do
		if not chest.model.Parent then
			return
		end
		label.Text = (string.gsub(look.CountdownText, "{n}", tostring(left)))
		task.wait(1)
	end
	board:Destroy()
	if ticking then
		ticking:Destroy()
	end
	if not chest.model.Parent then
		return
	end
	PrizeChests.setLocked(chest, false)
	local jingle = sound(chest.root, look.OpenSound, look.OpenLoudness, false)
	if jingle then
		jingle.PlayOnRemove = true
		jingle:Destroy()
	end
	Loudness.emit(chest.root.Position, look.OpenLoudness, chest.model)
end

-- The beam (and the crate, if the event left one) go once it's emptied, or after a while either way
local function expire(marker: BasePart?, chest: PrizeChests.Chest?, beamSeconds: number)
	local started = os.clock()
	while os.clock() - started < Settings.Lifetime do
		if chest and PrizeChests.isEmpty(chest) then
			break
		end
		if not chest and os.clock() - started >= beamSeconds then
			break
		end
		task.wait(1)
	end
	if marker then
		marker:Destroy()
	end
	if chest then
		PrizeChests.remove(chest)
	end
end

-- Clear aisle floor named after its nearest aisle sign: near the director's spot when it has one,
-- otherwise by a random sign
local function aisleSite(target: DirectorLogic.Point?): Site?
	local layout = Warehouse.layout()
	if #layout.signs == 0 then
		return nil
	end
	local x, z
	if target then
		local search = Steering.SnapSearch
		x, z = PrizesLogic.clearNear(clearAt(3), target.x, target.z, search[1], search[2], 20, rng)
	else
		local sign = rng:pick(layout.signs)
		local search = Settings.DeliverySearch
		x, z = PrizesLogic.clearNear(clearAt(3), sign.x, sign.z, search[1], search[2], 20, rng)
	end
	if not (x and z) then
		return nil
	end
	local sign = DirectorLogic.nearest(layout.signs, { x = x, z = z })
	return { name = tostring(sign.number), x = x, z = z }
end

local function placeName(room: any): string
	return Config.Missions.Places[room.kind] or room.kind
end

-- Just outside the hall's first doorway, where the beam can be seen over the racks
local function openSite(target: DirectorLogic.Candidate?): (Site?, any)
	local rooms = PrizeChests.rooms()
	if #rooms == 0 then
		return nil, nil
	end
	local layout = Warehouse.layout()
	local room = if target and target.room then target.room else rng:pick(rooms)
	local hall = WarehouseGen.pocketAt(layout, room.cx, room.cz)
	local name = placeName(room)
	if not hall or not hall.doors or not hall.doors[1] then
		return { name = name, x = room.cx, z = room.cz }, room
	end
	local x, z, nx, nz = Installations.doorway(hall, hall.doors[1])
	return { name = name, x = x + nx * 6, z = z + nz * 6 }, room
end

local function frontDeskSite(): Site?
	local layout = Warehouse.layout()
	local x, z = layout.entrance.x, layout.entrance.z - Settings.FrontDeskInset
	local cx, cz = PrizesLogic.clearNear(clearAt(3), x, z, 0, 30, 20, rng)
	return if cx and cz then { x = cx, z = cz } else nil
end

-- A rumor by an installation calls it by name; anywhere else it's the aisle number
local function rumorSite(target: DirectorLogic.Point?): Site?
	local site = aisleSite(target)
	if not site then
		return nil
	end
	local halls = {}
	for _, hall in PrizeChests.rooms() do
		table.insert(halls, { x = hall.cx, z = hall.cz, room = hall })
	end
	local room = DirectorLogic.nearest(halls, site)
	if room and math.sqrt((room.x - site.x) ^ 2 + (room.z - site.z) ^ 2) <= Settings.Rumor.PlaceRange then
		site.name, site.place = placeName(room.room), true
	end
	return site
end

local function siteFor(name: string, target: DirectorLogic.Candidate?): (Site?, any)
	if name == "open" then
		return openSite(target)
	elseif name == "lost" then
		return frontDeskSite(), nil
	elseif name == "rumor" then
		return rumorSite(target), nil
	end
	return aisleSite(target), nil
end

local function lineFrom(options: string | { string }): string
	return if type(options) == "table" then rng:pick(options) else options
end

local function crateAt(site: Site, value: number, loot: PrizesLogic.ChestLoot): PrizeChests.Chest?
	return PrizeChests.spawn({
		x = site.x,
		z = site.z,
		turn = rng:range(0, 360),
		value = value,
		loot = loot,
		restocks = false,
	})
end

local function run(name: string, site: Site, room: any)
	local event = Settings.Events[name]
	local chest: PrizeChests.Chest? = nil
	if name == "open" then
		PrizeChests.refill(room)
	else
		local value, loot = event.value, event.loot
		local jackpot = event.jackpot
		if jackpot and rng:next() < jackpot.chance then
			value, loot = jackpot.value, jackpot.loot
		end
		chest = crateAt(site, value, loot)
		if not chest then
			return
		end
		if name == "delivery" then
			drop(chest)
		elseif event.countdown then
			task.spawn(countdown, chest, event.countdown)
		end
	end
	local position = Warehouse.toWorld(site.x, site.z)
	local look = event.beam or Settings.Beam
	local marker = if event.rumor then nil else beam(position, look)
	task.spawn(expire, marker, chest, look.Seconds)
	local text = if site.place and event.place then lineFrom(event.place) else lineFrom(event.text)
	eventRemote:FireAllClients({
		text = PrizesLogic.line(text, site.name),
		position = if event.rumor then nil else position,
		rumor = event.rumor == true,
		glitch = not event.rumor and rng:next() < Settings.GlitchChance,
		voice = event.voice,
	})
	SimPlayers.lure(position, Steering.BotPull[name] or 0, Steering.BotLureRange)
end

-- Picks and runs one event. Returns the event name, or nil when none could happen.
function PaEvents.trigger(): string?
	local hasSigns = #Warehouse.layout().signs > 0
	local possible = {
		delivery = hasSigns,
		bait = hasSigns,
		rumor = hasSigns,
		open = #PrizeChests.rooms() > 0,
		lost = true,
	}
	local name = PrizesLogic.pickEvent(Settings.Events, possible, rng)
	if not name then
		return nil
	end
	-- The front desk is the front desk; everything else lets the director suggest a spot
	local target = if name == "lost" then nil else Director.spot(name == "open")
	local site, room = siteFor(name, target)
	if not site and target then
		site, room = siteFor(name, nil)
	end
	if not site then
		return nil
	end
	run(name, site, room)
	return name
end

function PaEvents.Init()
	eventRemote = Net.event("PaEvent")
	folder = Instance.new("Folder")
	folder.Name = "PaEvents"
	folder.Parent = workspace
end

-- The gap between events counts down at the director's pace: quicker while everyone keeps apart,
-- slower while groups are already in each other's faces
function PaEvents.Start()
	task.wait(rng:range(Settings.FirstDelay[1], Settings.FirstDelay[2]))
	while true do
		PaEvents.trigger()
		local gap = PrizesLogic.gap(Settings.Gap, DayNight.phase(), rng) or Settings.Gap.Night[2]
		local waited = 0
		while waited < gap do
			waited += task.wait(1) * Director.pace()
		end
	end
end

return PaEvents
