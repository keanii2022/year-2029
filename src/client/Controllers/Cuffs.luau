-- Client side of handcuffs: the "Cuff" hint and Use / Fire when cuffs are selected on the hotbar, the CUFFED overlay
-- and mash prompt for the victim, and the rob panel for the cuffer. The server decides everything.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CuffsLogic = require(ReplicatedStorage.Shared.Logic.Cuffs)
local InventoryItems = require(ReplicatedStorage.Shared.Logic.InventoryItems)
local Net = require(ReplicatedStorage.Shared.Net)
local Glyphs = require(script.Parent.Glyphs)
local Hints = require(script.Parent.Hints)
local Hotbar = require(script.Parent.Hotbar)
local Input = require(script.Parent.Input)

local settings = Config.Cuffs
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local AIM_DOT = 0.6 -- how close to the camera's look a target must be to get picked

local Cuffs = {}

local gui: ScreenGui
local overlay: Frame
local timerLabel: TextLabel
local mashRow: Frame
local mashFilled = false
local robPanel: Frame
local robTitle: TextLabel
local robList: Frame
local doneButton: TextButton

local requestRemote: RemoteEvent
local mashRemote: RemoteEvent
local takeRemote: RemoteEvent
local aimedTarget: Player? = nil
local lastDevice: Input.Device = "Keyboard"

local function make(className: string, props: { [string]: any }, parent: Instance): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.GothamBold
	return make("TextLabel", props, parent)
end

local function button(props: { [string]: any }, parent: Instance): TextButton
	props.BackgroundColor3 = Color3.fromRGB(32, 31, 30)
	props.BorderSizePixel = 0
	props.TextColor3 = TEXT
	props.Font = Enum.Font.GothamBold
	props.TextSize = 16
	props.AutoButtonColor = true
	return make("TextButton", props, parent)
end

local function buildOverlay()
	overlay = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, gui)
	text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(600, 140),
		Rotation = -5,
		Font = Enum.Font.PermanentMarker,
		Text = "CUFFED",
		TextColor3 = SPRAY_RED,
		TextSize = 96,
		ZIndex = 11,
	}, overlay)
	timerLabel = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 40),
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 34,
		ZIndex = 11,
	}, overlay)
	mashRow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.565),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, overlay)
	text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.61),
		Size = UDim2.fromOffset(600, 20),
		Text = "Anyone else can uncuff you.",
		TextSize = 14,
		TextTransparency = 0.4,
		ZIndex = 11,
	}, overlay)
end

local function buildRobPanel()
	robPanel = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, robPanel)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, robPanel)
	robTitle = text({
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, robPanel)
	robList = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, robPanel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, robList)
	-- Modal frees the mouse while the panel is open, even in first person.
	doneButton =
		button({ Size = UDim2.new(1, 0, 0, 32), Text = "Done", Modal = true, LayoutOrder = 3 }, robPanel)
	doneButton.Activated:Connect(function()
		robPanel.Visible = false
	end)
end

local function showRobList(target: Player?, list: { { id: string, count: number } }?)
	for _, child in robList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not target or not list then
		robPanel.Visible = false
		return
	end
	robTitle.Text = `{target.DisplayName}'s bag`
	if #list == 0 then
		text(
			{ Size = UDim2.new(1, 0, 0, 24), Text = "Empty.", TextSize = 16, TextTransparency = 0.4 },
			robList
		)
	end
	for index, stack in list do
		local item = InventoryItems[stack.id]
		local name = if item then item.name else stack.id
		local take = button({
			Size = UDim2.new(1, 0, 0, 32),
			Text = if stack.count > 1 then `Take {name} x{stack.count}` else `Take {name}`,
			LayoutOrder = index,
		}, robList)
		take.Activated:Connect(function()
			takeRemote:FireServer(stack.id)
		end)
	end
	robPanel.Visible = true
	if lastDevice == "Gamepad" then
		GuiService.SelectedObject = robList:FindFirstChildWhichIsA("TextButton") or doneButton
	end
end

local function flat(v: Vector3): CuffsLogic.Flat
	return { x = v.X, z = v.Z }
end

-- The closest player in front of the camera who could be cuffed right now. The server
-- still checks the cooldown and everything else.
local function findTarget(): Player?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera or player:GetAttribute("Cuffed") then
		return nil
	end
	local look = camera.CFrame.LookVector
	local best, bestDistance = nil, math.huge
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
		if other == player or not otherRoot or not humanoid then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		if distance == 0 or distance >= bestDistance or look:Dot(offset.Unit) < AIM_DOT then
			continue
		end
		local ok = CuffsLogic.canCuff({
			cufferPosition = flat(root.Position),
			targetPosition = flat(otherRoot.Position),
			targetFacing = flat(otherRoot.CFrame.LookVector),
			targetHealth = humanoid.Health,
			targetMaxHealth = humanoid.MaxHealth,
			targetAlive = humanoid.Health > 0,
			targetCuffed = other:GetAttribute("Cuffed") == true,
			cufferCuffed = false,
			hasCuffs = true,
			sinceTargetLastCuffed = nil,
		}, settings)
		if ok then
			best, bestDistance = other, distance
		end
	end
	return best
end

local function update()
	local slot = Hotbar.selected()
	aimedTarget = if slot and slot.item == settings.ItemId then findTarget() else nil
	Hints.set(
		"cuff",
		if aimedTarget then string.format(Config.Hints.CuffHint, aimedTarget.DisplayName) else nil,
		2
	)

	local cuffed = player:GetAttribute("Cuffed") == true
	overlay.Visible = cuffed
	if cuffed then
		local untilTime = player:GetAttribute("CuffedUntil")
		local left = if type(untilTime) == "number" then untilTime - workspace:GetServerTimeNow() else 0
		timerLabel.Text = `{math.max(0, math.ceil(left))}`
		if not mashFilled then
			mashFilled = true
			Glyphs.fill(
				mashRow,
				Config.Hints.MashHint,
				{ size = 26, textSize = 18, font = Enum.Font.GothamBold }
			)
		end
	end
end

-- The uncuff prompt sits on the cuffed player's own body; it's for everyone else.
local function hideOwnPrompt(character: Model)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "Uncuff" then
			descendant.Enabled = false
		end
	end)
end

function Cuffs.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Cuffs"
	Input.markMenu(gui)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	buildOverlay()
	buildRobPanel()
end

function Cuffs.Start()
	requestRemote = Net.event("CuffsRequest")
	mashRemote = Net.event("CuffsMash")
	takeRemote = Net.event("CuffsTake")
	Net.event("CuffsRob").OnClientEvent:Connect(showRobList)
	local function cuff(began: boolean, device: Input.Device)
		lastDevice = device
		if began and aimedTarget then
			requestRemote:FireServer(aimedTarget)
		end
	end
	Input.bind("Use", cuff)
	Hotbar.onUse("Cuffs", cuff)
	Input.bind("Jump", function(began, device)
		lastDevice = device
		if began and player:GetAttribute("Cuffed") then
			mashRemote:FireServer()
		end
	end)

	player.CharacterAdded:Connect(hideOwnPrompt)
	if player.Character then
		hideOwnPrompt(player.Character)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	Glyphs.onChanged(function()
		mashFilled = false
	end)
	RunService.RenderStepped:Connect(update)
end

return Cuffs
