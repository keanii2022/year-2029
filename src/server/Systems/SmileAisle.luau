-- Aisle 40, the Smile Aisle, built from the layout's plan (Logic/WarehouseGenSmileAisle): smile
-- propaganda with survivor paint over it, a robot greeter frozen mid-wave, a flickering SMILE sign
-- and a smile-check booth. Bow three times on the booth's mark (Logic/SmileCheck) and a panel in
-- the racks behind you slides open on the night manager's office: his desk, a name tag with no
-- name, his kid's drawing, his last tape (a secret 2029 File) and his lanyard (a secret cosmetic).
-- Also the office's phone, which rings only at night while someone is in the aisle, and the lost
-- and found box by the entrance. Client SmileAisle reads the ReplicatedStorage.SmileAisle marker.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local ModelRig = require(ReplicatedStorage.Shared.ModelRig)
local Net = require(ReplicatedStorage.Shared.Net)
local SmileCheck = require(ReplicatedStorage.Shared.Logic.SmileCheck)
local DayNight = require(script.Parent.DayNight)
local Files = require(script.Parent.Files)
local Saves = require(script.Parent.Saves)
local Scores = require(script.Parent.Scores)
local Warehouse = require(script.Parent.Warehouse)

local Settings = Config.SmileAisle
local Gen = Config.Warehouse.SmileAisle
local Booth = Settings.Booth
local Office = Settings.Office
local Sounds = Settings.Sounds
local Volume = Settings.Volume
local RACK_HEIGHT = Config.Warehouse.RackHeight

local SmileAisle = {}

local random = Random.new()
local voiceRemote: RemoteEvent
local folder: Folder
local plan: any

local function at(x: number, y: number, z: number): Vector3
	return Warehouse.toWorld(x, z) + Vector3.new(0, y, 0)
end

-- A part whose Front face looks along (nx, nz)
local function facing(position: Vector3, nx: number, nz: number): CFrame
	return CFrame.lookAt(position, position + Vector3.new(nx, 0, nz))
end

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local new = Instance.new("Part")
	new.Name = name
	new.Anchored = true
	new.Size = size
	new.CFrame = cframe
	new.Color = color
	new.Material = material or Enum.Material.SmoothPlastic
	new.TopSurface = Enum.SurfaceType.Smooth
	new.BottomSurface = Enum.SurfaceType.Smooth
	new.Parent = folder
	return new
end

-- Paper, stickers, paint: nothing hits them or casts shadows
local function flat(new: BasePart): BasePart
	new.CanCollide = false
	new.CanQuery = false
	new.CanTouch = false
	new.CastShadow = false
	return new
end

local function surface(target: BasePart, face: Enum.NormalId, background: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	if background then
		local paper = Instance.new("Frame")
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundColor3 = background
		paper.BorderSizePixel = 0
		paper.Parent = gui
	end
	gui.Parent = target
	return gui
end

local function text(
	parent: Instance,
	words: string,
	color: Color3,
	font: Enum.Font,
	size: UDim2,
	position: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font
	label.TextColor3 = color
	label.Text = words
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local function dot(parent: Instance, color: Color3, size: UDim2, position: UDim2, z: number): Frame
	local blob = Instance.new("Frame")
	blob.Size = size
	blob.Position = position
	blob.BackgroundColor3 = color
	blob.BorderSizePixel = 0
	blob.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = blob
	blob.Parent = parent
	return blob
end

-- A yellow smiley in a square of the parent; crying turns the mouth down and adds tears
local function smiley(parent: Instance, size: UDim2, position: UDim2, crying: boolean)
	local face = dot(parent, Settings.SmileyYellow, size, position, 2)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = face
	local ink = Settings.SmileyInk
	dot(face, ink, UDim2.fromScale(0.12, 0.18), UDim2.fromScale(0.28, 0.26), 3)
	dot(face, ink, UDim2.fromScale(0.12, 0.18), UDim2.fromScale(0.6, 0.26), 3)
	local mouth =
		text(face, ")", ink, Enum.Font.GothamBold, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0.42))
	mouth.Rotation = if crying then -90 else 90
	mouth.ZIndex = 3
	if crying then
		dot(face, Settings.TearBlue, UDim2.fromScale(0.07, 0.2), UDim2.fromScale(0.3, 0.46), 4)
		dot(face, Settings.TearBlue, UDim2.fromScale(0.07, 0.2), UDim2.fromScale(0.63, 0.46), 4)
	end
end

local function spray(parent: Instance, words: string)
	local label = text(
		parent,
		words,
		Settings.SprayColor,
		Enum.Font.PermanentMarker,
		UDim2.fromScale(1, 0.4),
		UDim2.fromScale(0, 0.35)
	)
	label.Rotation = -12
	label.ZIndex = 8
end

local function prompt(target: BasePart, action: string, object: string, reach: number): ProximityPrompt
	local new = Instance.new("ProximityPrompt")
	new.ActionText = action
	new.ObjectText = object
	new.MaxActivationDistance = reach
	new.Parent = target
	return new
end

local function sound(parent: Instance, name: string, volume: number, looped: boolean?): Sound?
	local id = ModelLibrary.soundId(name)
	if not id then
		return nil
	end
	local new = Instance.new("Sound")
	new.SoundId = id
	new.Volume = volume
	new.Looped = looped == true
	new.RollOffMinDistance = Settings.RollOff.Min
	new.RollOffMaxDistance = Settings.RollOff.Max
	new.Parent = parent
	Mix.route(new, "SFX")
	return new
end

local function playOnce(parent: Instance, name: string, volume: number)
	local new = sound(parent, name, volume)
	if new then
		new.Ended:Once(function()
			new:Destroy()
		end)
		new:Play()
	end
end

-- A library model standing on the floor at (x, z), its front along facingDir. Its ModelName is
-- cleared so Interact and Grab leave it alone: these are set dressing with their own behaviour.
local function model(name: string, x: number, z: number, facingDir: Vector3, y: number?): Model?
	local new = ModelLibrary.get(name)
	if not new then
		return nil
	end
	new:SetAttribute("ModelName", nil)
	local rotation = CFrame.lookAt(Vector3.zero, -facingDir)
	new:PivotTo(rotation)
	local box, size = new:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	new:PivotTo(rotation + (at(x, y or 0, z) - bottom))
	new.Parent = folder
	return new
end

local function topOf(target: Model): number
	local box, size = target:GetBoundingBox()
	return box.Position.Y + size.Y / 2 - Config.Warehouse.Origin.Y
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function localSpot(position: Vector3): (number, number)
	local relative = position - Config.Warehouse.Origin
	return relative.X, relative.Z
end

local function anyoneIn(rect: any): boolean
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root then
			local x, z = localSpot(root.Position)
			if SmileCheck.inside(rect, x, z) then
				return true
			end
		end
	end
	return false
end

local function speak(player: Player, line: any, seconds: number)
	voiceRemote:FireClient(player, line.voice, line.text, seconds)
end

-- Propaganda ----------------------------------------------------------------------------------------

local function buildPoster(item: any)
	local size = Settings.PosterSize
	local paper = flat(
		part("SmilePoster", size, facing(at(item.x, item.y, item.z), item.nx, item.nz), Settings.PosterColor)
	)
	paper.Transparency = 1
	local image = if item.index % Settings.PosterImageEvery == 0
		then ModelLibrary.imageId(
			Settings.PosterImages[item.index // Settings.PosterImageEvery % #Settings.PosterImages + 1]
		)
		else nil
	local gui = surface(paper, Enum.NormalId.Front, if image then nil else Settings.PosterColor)
	if image then
		local picture = Instance.new("ImageLabel")
		picture.Size = UDim2.fromScale(1, 1)
		picture.BackgroundTransparency = 1
		picture.Image = image
		picture.Parent = gui
	else
		smiley(gui, UDim2.fromScale(0.6, 0.4), UDim2.fromScale(0.2, 0.06), false)
		local line = Settings.Propaganda[(item.index - 1) % #Settings.Propaganda + 1]
		text(
			gui,
			line,
			Settings.PosterInk,
			Enum.Font.GothamBlack,
			UDim2.fromScale(0.86, 0.42),
			UDim2.fromScale(0.07, 0.52)
		)
	end
	if item.sprayed then
		spray(gui, Settings.Spray[(item.index // Gen.SprayEvery - 1) % #Settings.Spray + 1])
	end
end

local function buildSticker(item: any)
	local size = Settings.StickerSize
	local sticker = flat(
		part(
			"SmileSticker",
			Vector3.new(size, size, 0.05),
			facing(at(item.x, item.y, item.z), item.nx, item.nz),
			Settings.SmileyYellow
		)
	)
	sticker.Transparency = 1
	sticker.Orientation += Vector3.new(0, 0, (item.index * 37) % 40 - 20)
	smiley(surface(sticker, Enum.NormalId.Front), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), false)
end

local function buildBanner(item: any)
	local lane = plan.lane
	local width = lane.z1 - lane.z0 - 1
	local banner = flat(
		part(
			"SmileBanner",
			Vector3.new(width, 2.2, 0.15),
			facing(at(item.x, item.y, item.z), item.nx, item.nz),
			Settings.PosterColor,
			Enum.Material.Fabric
		)
	)
	local words = Settings.Banners[(item.index - 1) % #Settings.Banners + 1]
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = surface(banner, face)
		text(
			gui,
			words,
			Settings.PosterInk,
			Enum.Font.GothamBlack,
			UDim2.fromScale(0.94, 0.8),
			UDim2.fromScale(0.03, 0.1)
		)
		if item.sprayed and face == Enum.NormalId.Back then
			spray(gui, Settings.Spray[1])
		end
	end
end

local function buildNeonSign()
	local sign = Settings.NeonSign
	local lane = plan.lane
	local tube = flat(
		part(
			"SmileNeon",
			sign.Size,
			facing(at(lane.x0 + 1, sign.Y, (lane.z0 + lane.z1) / 2), -1, 0),
			sign.Color,
			Enum.Material.Neon
		)
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = surface(tube, face)
		gui.LightInfluence = 0
		text(
			gui,
			sign.Text,
			Color3.new(1, 1, 1),
			Enum.Font.GothamBlack,
			UDim2.fromScale(0.9, 0.8),
			UDim2.fromScale(0.05, 0.1)
		)
	end
	local glow = Instance.new("PointLight")
	glow.Color = sign.Color
	glow.Range = sign.Light.Range
	glow.Brightness = sign.Light.Brightness
	glow.Parent = tube
	-- Client Lighting blinks FlickerLight parts; AlwaysOn keeps it going through the night
	tube:SetAttribute("AlwaysOn", true)
	CollectionService:AddTag(tube, "FlickerLight")
end

local function buildGreeter()
	local greeter = model(Settings.Greeter.Model, plan.greeter.x, plan.greeter.z, Vector3.new(-1, 0, 0))
	if greeter then
		ModelRig.rig(greeter)
		ModelRig.setPose(greeter, "Arm", Settings.Greeter.WavePose)
	end
end

-- Booth --------------------------------------------------------------------------------------------

local screenLabel: TextLabel
local screenText = ""

local function setScreen(words: string, color: Color3)
	if words ~= screenText then
		screenText = words
		screenLabel.Text = words
		screenLabel.TextColor3 = color
	end
end

local boothBody: BasePart

local function buildBooth()
	local size = Booth.Size
	local spot = plan.booth
	boothBody = part("SmileBooth", size, facing(at(spot.x, size.Y / 2, spot.z), 0, 1), Booth.Color)
	local front = spot.z + size.Z / 2
	local screen = part(
		"BoothScreen",
		Vector3.new(size.X - 0.8, 1.8, 0.2),
		facing(at(spot.x, 5.4, front + 0.1), 0, 1),
		Booth.ScreenColor
	)
	screen.Material = Enum.Material.Glass
	local gui = surface(screen, Enum.NormalId.Front, Booth.ScreenColor)
	gui.LightInfluence = 0
	screenLabel =
		text(gui, "", Booth.TextColor, Enum.Font.Code, UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1))
	setScreen(Booth.Idle, Booth.TextColor)
	local lens = part(
		"BoothLens",
		Vector3.new(0.6, 0.6, 0.3),
		facing(at(spot.x, 7.1, front + 0.15), 0, 1),
		Booth.ScreenColor,
		Enum.Material.Glass
	)
	local light = flat(
		part(
			"BoothLight",
			Vector3.new(0.18, 0.18, 0.05),
			facing(at(spot.x + 0.45, 7.3, front + 0.3), 0, 1),
			Booth.RejectColor,
			Enum.Material.Neon
		)
	)
	light.Shape = Enum.PartType.Ball
	lens.CanCollide = false
	-- Survivor paint on the booth's side, the side you see walking in
	spray(surface(boothBody, Enum.NormalId.Right), Settings.Spray[1])
	local mark = flat(
		part(
			"BoothMark",
			Vector3.new(3, 0.05, 3),
			facing(at(plan.mark.x, 0.03, plan.mark.z), 0, 1),
			Booth.Color
		)
	)
	mark.Transparency = 1
	text(
		surface(mark, Enum.NormalId.Top),
		Booth.Mark,
		Settings.SmileyYellow,
		Enum.Font.GothamBlack,
		UDim2.fromScale(0.9, 0.5),
		UDim2.fromScale(0.05, 0.25)
	)
	-- The hint: a crying smiley low on the rack beside the booth, three red tally marks under it
	local lane = plan.lane
	local hint = flat(
		part(
			"CryingSticker",
			Vector3.new(0.9, 1.3, 0.05),
			facing(at(spot.x - size.X / 2 - 1.2, 1.6, lane.z0 + 0.06), 0, 1),
			Settings.SmileyYellow
		)
	)
	hint.Transparency = 1
	local hintGui = surface(hint, Enum.NormalId.Front)
	smiley(hintGui, UDim2.fromScale(1, 0.65), UDim2.fromScale(0, 0), true)
	text(
		hintGui,
		Settings.HintMarks,
		Settings.SprayColor,
		Enum.Font.PermanentMarker,
		UDim2.fromScale(1, 0.3),
		UDim2.fromScale(0, 0.68)
	)
end

-- Office -------------------------------------------------------------------------------------------

local panel: BasePart
local closedAt: CFrame
local openAt: CFrame
local spill: PointLight
local isOpen = false
local closeAt = 0

local function wall(
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y0: number,
	y1: number,
	color: Color3?
): Part
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	return part(
		name,
		size,
		CFrame.new(at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)),
		color or Office.WallColor,
		Enum.Material.Metal
	)
end

local function slide(open: boolean)
	isOpen = open
	TweenService:Create(
		panel,
		TweenInfo.new(Office.SlideSeconds, Enum.EasingStyle.Sine),
		{ CFrame = if open then openAt else closedAt }
	):Play()
	playOnce(panel, Sounds.Slide, Volume.Slide)
	spill.Enabled = open
end

local function open()
	closeAt = os.clock() + Office.OpenSeconds
	if not isOpen then
		slide(true)
	end
end

local function buildDrawing(x: number, z: number)
	local paper = flat(
		part("KidDrawing", Vector3.new(2.4, 1.8, 0.05), facing(at(x, 5.2, z), 1, 0), Color3.new(1, 1, 1))
	)
	paper.Orientation += Vector3.new(0, 0, 4)
	local gui = surface(paper, Enum.NormalId.Front, Color3.fromRGB(246, 242, 230))
	text(
		gui,
		Office.Drawing,
		Color3.fromRGB(40, 70, 160),
		Enum.Font.FredokaOne,
		UDim2.fromScale(0.8, 0.2),
		UDim2.fromScale(0.1, 0.04)
	)
	dot(gui, Color3.fromRGB(240, 200, 40), UDim2.fromScale(0.16, 0.2), UDim2.fromScale(0.8, 0.04), 2) -- sun
	-- Dad: tall, a tie; the kid: small, a yellow raincoat; holding hands
	local ink = Color3.fromRGB(60, 50, 40)
	dot(gui, ink, UDim2.fromScale(0.1, 0.13), UDim2.fromScale(0.3, 0.3), 2)
	dot(gui, Color3.fromRGB(70, 90, 120), UDim2.fromScale(0.07, 0.4), UDim2.fromScale(0.315, 0.43), 2)
	dot(gui, ink, UDim2.fromScale(0.07, 0.1), UDim2.fromScale(0.58, 0.55), 2)
	dot(gui, Color3.fromRGB(240, 200, 40), UDim2.fromScale(0.1, 0.22), UDim2.fromScale(0.565, 0.65), 2)
	local hands = Instance.new("Frame")
	hands.Size = UDim2.fromScale(0.2, 0.015)
	hands.Position = UDim2.fromScale(0.37, 0.68)
	hands.BackgroundColor3 = ink
	hands.BorderSizePixel = 0
	hands.ZIndex = 3
	hands.Parent = gui
end

local function onTape(player: Player)
	if not aliveRoot(player) then
		return
	end
	speak(player, Settings.TapeLine, Settings.TapeSubtitleSeconds)
	Files.read(player, Office.Tape.File)
end

local function onLanyard(player: Player)
	if not aliveRoot(player) then
		return
	end
	local data = Saves.data(player)
	if not data then
		return
	end
	if (data.stats[Office.Lanyard.Stat] or 0) >= 1 then
		Saves.tell(player, Office.Lanyard.Again)
		return
	end
	Scores.raise(player, Office.Lanyard.Stat, 1)
end

local function buildOffice()
	local box = plan.office
	local t = Office.Wall
	local door = plan.panel
	local left, right = door.x - door.width / 2, door.x + door.width / 2
	local h = Office.DoorHeight
	-- The aisle side looks like more racking; the doorway hides in it
	wall("OfficeFront", box.x0, box.z0, left, box.z0 + t, 0, RACK_HEIGHT)
	wall("OfficeFront", right, box.z0, box.x1, box.z0 + t, 0, RACK_HEIGHT)
	wall("OfficeFront", left, box.z0, right, box.z0 + t, h, RACK_HEIGHT)
	wall("OfficeBack", box.x0, box.z1 - t, box.x1, box.z1, 0, RACK_HEIGHT)
	wall("OfficeSide", box.x0, box.z0 + t, box.x0 + t, box.z1 - t, 0, RACK_HEIGHT)
	wall("OfficeSide", box.x1 - t, box.z0 + t, box.x1, box.z1 - t, 0, RACK_HEIGHT)
	wall(
		"OfficeCeiling",
		box.x0 + t,
		box.z0 + t,
		box.x1 - t,
		box.z1 - t,
		Office.Ceiling,
		Office.Ceiling + 0.4,
		Office.InsideColor
	)
	local carpet =
		wall("OfficeCarpet", box.x0 + t, box.z0 + t, box.x1 - t, box.z1 - t, 0, 0.1, Office.CarpetColor)
	carpet.Material = Enum.Material.Carpet

	closedAt = facing(at(door.x, h / 2, box.z0 + t / 2), 0, -1)
	openAt = closedAt * CFrame.new(door.width, 0, 0) -- slides along inside the wall, into the racking
	panel = part(
		"OfficePanel",
		Vector3.new(door.width, h, t * 0.8),
		closedAt,
		Office.WallColor,
		Enum.Material.Metal
	)
	local cover = surface(panel, Enum.NormalId.Front, Settings.PosterColor)
	smiley(cover, UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.25, 0.12), false)
	text(
		cover,
		Settings.Propaganda[3],
		Settings.PosterInk,
		Enum.Font.GothamBlack,
		UDim2.fromScale(0.8, 0.3),
		UDim2.fromScale(0.1, 0.45)
	)
	spill = Instance.new("PointLight")
	spill.Color = Office.Lamp.Color
	spill.Range = Office.Spill.Range
	spill.Brightness = Office.Spill.Brightness
	spill.Enabled = false
	spill.Parent = panel

	-- The way out from inside, always: a release by the door (line of sight, so not through walls)
	local release = part(
		"DoorRelease",
		Vector3.new(0.5, 0.8, 0.3),
		facing(at(left - 1, 4, box.z0 + t + 0.15), 0, 1),
		Booth.RejectColor
	)
	prompt(release, Office.Release.Prompt, Office.Release.Object, Office.PromptReach).Triggered:Connect(open)

	-- His desk against the back wall, facing the door, and his chair
	local midX = (box.x0 + box.x1) / 2
	local desk = model("desk", midX, box.z1 - t - 2, Vector3.new(0, 0, -1))
	model("office_chair", midX, box.z1 - t - 4.5, Vector3.new(0, 0, 1))
	model("filing_cabinet", box.x1 - t - 1.5, box.z1 - t - 1.5, Vector3.new(-1, 0, 0))
	local deskTop = if desk then topOf(desk) else 3
	local lamp = model("desk_lamp", midX + 1.6, box.z1 - t - 2.2, Vector3.new(0, 0, -1), deskTop)
	local glow = Instance.new("PointLight")
	glow.Color = Office.Lamp.Color
	glow.Range = Office.Lamp.Range
	glow.Brightness = Office.Lamp.Brightness
	glow.Shadows = true
	glow.Parent = (lamp and lamp:FindFirstChildWhichIsA("BasePart", true))
		or (desk and desk:FindFirstChildWhichIsA("BasePart", true))
		or carpet

	-- Name tag propped on the desk: the name line was never filled in
	local tag = flat(
		part(
			"NameTag",
			Vector3.new(1, 0.65, 0.05),
			facing(at(midX - 0.4, deskTop + 0.33, box.z1 - t - 2.6), 0, -1)
				* CFrame.Angles(math.rad(-15), 0, 0),
			Color3.new(1, 1, 1)
		)
	)
	local tagGui = surface(tag, Enum.NormalId.Front, Color3.fromRGB(244, 244, 240))
	local band = Instance.new("Frame")
	band.Size = UDim2.fromScale(1, 0.3)
	band.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
	band.BorderSizePixel = 0
	band.ZIndex = 2
	band.Parent = tagGui
	text(
		band,
		Office.NameTag.Top,
		Color3.new(1, 1, 1),
		Enum.Font.GothamBold,
		UDim2.fromScale(0.9, 0.8),
		UDim2.fromScale(0.05, 0.1)
	)
	text(
		tagGui,
		Office.NameTag.Role,
		Color3.fromRGB(90, 90, 90),
		Enum.Font.GothamMedium,
		UDim2.fromScale(0.8, 0.16),
		UDim2.fromScale(0.1, 0.8)
	)

	-- His tape recorder: the last tape is still in it
	local recorder = part(
		"TapeRecorder",
		Vector3.new(1.3, 0.45, 0.9),
		facing(at(midX - 1.6, deskTop + 0.23, box.z1 - t - 2.2), 0, -1),
		Color3.fromRGB(36, 34, 32)
	)
	flat(
		part(
			"TapeReel",
			Vector3.new(0.8, 0.06, 0.5),
			recorder.CFrame * CFrame.new(0, 0.25, 0),
			Color3.fromRGB(150, 140, 120)
		)
	)
	prompt(recorder, Office.Tape.Prompt, Office.Tape.Object, Office.PromptReach).Triggered:Connect(
		function(player)
			playOnce(recorder, Sounds.Tape, Volume.Small)
			onTape(player)
		end
	)

	-- His kid's drawing pinned to the side wall
	buildDrawing(box.x0 + t + 0.06, (box.z0 + box.z1) / 2)

	-- His lanyard on a hook beside the desk
	local hookX, hookZ = box.x1 - t - 0.06, (box.z0 + box.z1) / 2 - 2
	flat(
		part(
			"LanyardStrap",
			Vector3.new(0.1, 1.2, 0.04),
			facing(at(hookX, 5.4, hookZ), -1, 0),
			Color3.fromRGB(160, 30, 36)
		)
	)
	local card = part(
		"LanyardCard",
		Vector3.new(0.6, 0.8, 0.04),
		facing(at(hookX - 0.02, 4.5, hookZ), -1, 0),
		Color3.fromRGB(226, 222, 210)
	)
	card.CanCollide = false
	local cardGui = surface(card, Enum.NormalId.Front, Color3.fromRGB(226, 222, 210))
	text(
		cardGui,
		Office.NameTag.Role,
		Color3.fromRGB(60, 60, 60),
		Enum.Font.GothamBold,
		UDim2.fromScale(0.9, 0.2),
		UDim2.fromScale(0.05, 0.72)
	)
	local photo = Instance.new("Frame")
	photo.Size = UDim2.fromScale(0.5, 0.5)
	photo.Position = UDim2.fromScale(0.25, 0.12)
	photo.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	photo.BorderSizePixel = 0
	photo.ZIndex = 2
	photo.Parent = cardGui
	prompt(card, Office.Lanyard.Prompt, Office.Lanyard.Object, Office.PromptReach).Triggered:Connect(
		onLanyard
	)
end

-- Phone ---------------------------------------------------------------------------------------------

local phonePart: BasePart
local phonePrompt: ProximityPrompt
local ringing: Sound?
local ringUntil = 0
local nextRingAt = 0

local function stopRing()
	ringUntil = 0
	phonePrompt.Enabled = false
	if ringing then
		ringing:Stop()
	end
end

local function buildPhone()
	local spot = plan.phone
	local shelfY = 4
	local shelf = part(
		"PhoneShelf",
		Vector3.new(1.6, 0.2, 1.1),
		CFrame.new(at(spot.x, shelfY, spot.z - 0.55)),
		Office.WallColor,
		Enum.Material.Metal
	)
	local phone = model(Settings.Phone.Model, spot.x, spot.z - 0.55, Vector3.new(0, 0, -1), shelfY + 0.1)
	phonePart = if phone
		then (phone.PrimaryPart or phone:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
		else shelf
	ringing = sound(phonePart, Sounds.Ring, Volume.Ring, true)
	phonePrompt = prompt(phonePart, Settings.Phone.Prompt, Settings.Phone.Object, Settings.Phone.Reach)
	phonePrompt.Enabled = false -- only while it rings
	phonePrompt.Triggered:Connect(function(player)
		if ringUntil == 0 or not aliveRoot(player) then
			return
		end
		stopRing()
		playOnce(phonePart, Sounds.Pickup, Volume.Small)
		speak(player, Settings.Phone.Line, Settings.Phone.SubtitleSeconds)
		Files.read(player, Settings.Phone.File)
	end)
end

local function stepPhone(now: number)
	if ringUntil > 0 then
		if now >= ringUntil or not DayNight.isNight() then
			stopRing()
			nextRingAt = now + random:NextNumber(Settings.Phone.Gap[1], Settings.Phone.Gap[2])
		end
		return
	end
	if not DayNight.isNight() or not anyoneIn(plan.lane) then
		return
	end
	if nextRingAt == 0 then
		nextRingAt = now + random:NextNumber(Settings.Phone.Gap[1], Settings.Phone.Gap[2]) / 2
	elseif now >= nextRingAt then
		ringUntil = now + Settings.Phone.RingSeconds
		phonePrompt.Enabled = true
		if ringing then
			ringing:Play()
		end
	end
end

-- Lost and found ------------------------------------------------------------------------------------

local function buildLostFound(spot: any)
	local lost = Settings.LostFound
	local base = at(spot.x, 0, spot.z)
	local box = part(
		"LostFoundBox",
		Vector3.new(2.6, 1.6, 2),
		facing(base + Vector3.new(0, 0.8, 0), 0, 1),
		lost.BoxColor,
		Enum.Material.Cardboard
	)
	text(
		surface(box, Enum.NormalId.Front),
		lost.Label,
		Color3.fromRGB(30, 30, 30),
		Enum.Font.PermanentMarker,
		UDim2.fromScale(0.9, 0.5),
		UDim2.fromScale(0.05, 0.25)
	)
	local coat = part(
		"Raincoat",
		Vector3.new(1.6, 0.35, 1.2),
		facing(base + Vector3.new(0.1, 1.75, 0), 0, 1) * CFrame.Angles(0, math.rad(10), 0),
		lost.CoatColor,
		Enum.Material.Fabric
	)
	coat.CanCollide = false
	local sticker = flat(
		part(
			"LostChildSticker",
			Vector3.new(0.7, 0.05, 0.45),
			coat.CFrame * CFrame.new(0.3, 0.2, 0),
			Color3.new(1, 1, 1)
		)
	)
	text(
		surface(sticker, Enum.NormalId.Top, Color3.fromRGB(240, 240, 236)),
		lost.Sticker,
		Color3.fromRGB(170, 40, 40),
		Enum.Font.GothamBold,
		UDim2.fromScale(0.9, 0.6),
		UDim2.fromScale(0.05, 0.2)
	)
	prompt(box, lost.Prompt, lost.Object, lost.Reach).Triggered:Connect(function(player)
		if aliveRoot(player) then
			Files.read(player, lost.File)
		end
	end)
end

-- Loops ---------------------------------------------------------------------------------------------

local bows: { [Player]: SmileCheck.Bows } = {}
local markSince: { [Player]: number } = {}
local holdUntil = 0

local function stepBooth(now: number)
	local markAt = at(plan.mark.x, 0, plan.mark.z)
	local onMark, best = false, 0
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		local here = false
		if root then
			local offset = root.Position - markAt
			here = Vector2.new(offset.X, offset.Z).Magnitude <= Booth.MarkRadius
		end
		local state = bows[player] or SmileCheck.newBows()
		bows[player] = state
		local crouched = here and (player.Character :: Model):GetAttribute("Stance") == "Crouch"
		local before = state.count
		if SmileCheck.stepBows(state, Booth.Bows, now, crouched, here) then
			holdUntil = now + 4
			setScreen(Booth.Accepted, Booth.AcceptColor)
			playOnce(boothBody, Sounds.Accepted, Volume.Booth)
			open()
		elseif state.count > before then
			playOnce(boothBody, Sounds.Beep, Volume.Booth)
		end
		if here then
			onMark = true
			markSince[player] = markSince[player] or now
			best = math.max(best, state.count)
			-- Standing there smiling (or not) gets you turned down, again and again
			if state.count == 0 and now - markSince[player] >= Booth.RejectAfter and now >= holdUntil then
				markSince[player] = now
				setScreen(Booth.Reject, Booth.RejectColor)
				playOnce(boothBody, Sounds.Reject, Volume.Booth)
				holdUntil = now + 2
			end
		else
			markSince[player] = nil
		end
	end
	if now < holdUntil then
		return
	end
	if best > 0 then
		local words =
			string.gsub(Booth.Progress, "{(%w+)}", { n = tostring(best), total = tostring(Booth.Bows.Bows) })
		setScreen(words, Booth.TextColor)
	elseif onMark then
		setScreen(Booth.Scanning, Booth.TextColor)
	else
		setScreen(Booth.Idle, Booth.TextColor)
	end
end

local function stepOffice(now: number)
	if not isOpen or now < closeAt then
		return
	end
	-- Never shuts on someone standing in the doorway
	local doorAt = at(plan.panel.x, 0, plan.panel.z)
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root then
			local offset = root.Position - doorAt
			if Vector2.new(offset.X, offset.Z).Magnitude < plan.panel.width then
				return
			end
		end
	end
	slide(false)
end

local function publish()
	local lane = plan.lane
	local marker = Instance.new("Configuration")
	marker.Name = "SmileAisle"
	marker:SetAttribute("LaneMin", at(lane.x0, 0, lane.z0))
	marker:SetAttribute("LaneMax", at(lane.x1, 0, lane.z1))
	marker.Parent = ReplicatedStorage
end

function SmileAisle.Init()
	voiceRemote = Net.event("SmileAisleVoice")
	Players.PlayerRemoving:Connect(function(player)
		bows[player] = nil
		markSince[player] = nil
	end)
end

function SmileAisle.Start()
	local root = workspace:WaitForChild("Warehouse", math.huge)
	while not root:GetAttribute("Built") do
		root:GetAttributeChangedSignal("Built"):Wait()
	end
	local layout = Warehouse.layout()
	folder = Instance.new("Folder")
	folder.Name = "SmileAisle"
	folder.Parent = workspace
	if layout.lostFound then
		buildLostFound(layout.lostFound)
	end
	plan = layout.smileAisle
	if not plan then
		return
	end
	for _, item in plan.decor do
		if item.kind == "poster" then
			buildPoster(item)
		elseif item.kind == "sticker" then
			buildSticker(item)
		else
			buildBanner(item)
		end
	end
	buildNeonSign()
	buildGreeter()
	buildBooth()
	buildOffice()
	buildPhone()
	publish()
	task.spawn(function()
		while true do
			local now = os.clock()
			stepBooth(now)
			stepOffice(now)
			stepPhone(now)
			task.wait(Booth.Every)
		end
	end)
end

return SmileAisle
