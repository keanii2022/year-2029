-- PA events: every few minutes with the lights on (rarer at night) the store PA calls out a spot and
-- something worth the walk turns up there: a delivery crate drops in a numbered aisle, an
-- installation's prize chests refill, or a lost item waits at the front desk. A beam of light
-- marks the spot; clients get the line for the chime, subtitle and screen-edge arrow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Installations = require(ReplicatedStorage.Shared.Logic.WarehouseGenInstallations)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PrizesLogic = require(ReplicatedStorage.Shared.Logic.Prizes)
local Rng = require(ReplicatedStorage.Shared.Logic.WarehouseGenRng)
local WarehouseGen = require(ReplicatedStorage.Shared.Logic.WarehouseGen)
local DayNight = require(script.Parent.DayNight)
local Loudness = require(script.Parent.Loudness)
local PrizeChests = require(script.Parent.PrizeChests)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.Prizes.Pa

type Site = { name: string?, x: number, z: number, y: number? }

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

local function beam(position: Vector3): BasePart
	local look = Settings.Beam
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
		local id = ModelLibrary.soundId(Settings.DropSound)
		if id then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.RollOffMinDistance, sound.RollOffMaxDistance = Loudness.rollOff(Settings.DropLoudness)
			sound.PlayOnRemove = true
			sound.Parent = chest.root
			sound:Destroy()
		end
		Loudness.emit(chest.root.Position, Settings.DropLoudness, chest.model)
	end)
	tween:Play()
end

-- The beam (and the crate, if the event left one) go once it's emptied, or after a while either way
local function expire(marker: BasePart, chest: PrizeChests.Chest?)
	local started = os.clock()
	while os.clock() - started < Settings.Lifetime do
		if chest and PrizeChests.isEmpty(chest) then
			break
		end
		if not chest and os.clock() - started >= Settings.Beam.Seconds then
			break
		end
		task.wait(1)
	end
	marker:Destroy()
	if chest then
		PrizeChests.remove(chest)
	end
end

local function deliverySite(): Site?
	local layout = Warehouse.layout()
	if #layout.signs == 0 then
		return nil
	end
	local sign = rng:pick(layout.signs)
	local search = Settings.DeliverySearch
	local x, z = PrizesLogic.clearNear(clearAt(3), sign.x, sign.z, search[1], search[2], 20, rng)
	return if x and z then { name = tostring(sign.number), x = x, z = z } else nil
end

-- Just outside the hall's first doorway, where the beam can be seen over the racks
local function openSite(): (Site?, any)
	local rooms = PrizeChests.rooms()
	if #rooms == 0 then
		return nil, nil
	end
	local layout = Warehouse.layout()
	local room = rng:pick(rooms)
	local hall = WarehouseGen.pocketAt(layout, room.cx, room.cz)
	local name = Config.Missions.Places[room.kind] or room.kind
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

local function crateAt(site: Site, event: any): PrizeChests.Chest?
	return PrizeChests.spawn({
		x = site.x,
		z = site.z,
		turn = rng:range(0, 360),
		value = event.value,
		loot = event.loot,
		restocks = false,
	})
end

local function run(name: string, site: Site, room: any)
	local event = Settings.Events[name]
	local chest: PrizeChests.Chest? = nil
	if name == "open" then
		PrizeChests.refill(room)
	else
		chest = crateAt(site, event)
		if not chest then
			return
		end
		if name == "delivery" then
			drop(chest)
		end
	end
	local position = Warehouse.toWorld(site.x, site.z)
	task.spawn(expire, beam(position), chest)
	eventRemote:FireAllClients({
		text = PrizesLogic.line(event.text, site.name),
		position = position,
		glitch = rng:next() < Settings.GlitchChance,
		voice = event.voice,
	})
end

-- Picks and runs one event. Returns the event name, or nil when none could happen.
function PaEvents.trigger(): string?
	local sites = {
		delivery = deliverySite(),
		lost = frontDeskSite(),
	}
	local openSpot, openRoom = openSite()
	sites.open = openSpot
	local possible = {}
	for name in Settings.Events do
		possible[name] = sites[name] ~= nil
	end
	local name = PrizesLogic.pickEvent(Settings.Events, possible, rng)
	if name then
		run(name, sites[name], openRoom)
	end
	return name
end

function PaEvents.Init()
	eventRemote = Net.event("PaEvent")
	folder = Instance.new("Folder")
	folder.Name = "PaEvents"
	folder.Parent = workspace
end

function PaEvents.Start()
	task.wait(rng:range(Settings.FirstDelay[1], Settings.FirstDelay[2]))
	while true do
		PaEvents.trigger()
		task.wait(PrizesLogic.gap(Settings.Gap, DayNight.phase(), rng) or Settings.Gap.Night[2])
	end
end

return PaEvents
