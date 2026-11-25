-- The Dawn Report: once the lights have come back on, a short card for everyone who made it through
-- the night, with a chime. It closes itself after a few seconds or on any key, button or touch, and
-- never takes input away from the game. The server works out everything on it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)

local settings = Config.Dawn
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local WIDTH = 360
local ROW_HEIGHT = 20
local ROWS = { "NIGHTS THIS LIFE", "CARRYING", "FORT STANDING", "DOG", "BANKED TONIGHT", "DAILY STREAK" }
local FADE = TweenInfo.new(0.5)

local CLOSING_INPUTS = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
}

local Dawn = {}

local gui: ScreenGui
local card: CanvasGroup
local title: TextLabel
local values: { TextLabel } = {}
local tokensLine: TextLabel
local breakdownLine: TextLabel
local shownAt = 0
local cardToken = 0

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT
	l.Font = Enum.Font.GothamBold
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function buildCard()
	card = Instance.new("CanvasGroup")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(WIDTH, 96 + ROW_HEIGHT * #ROWS)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.3
	card.BorderSizePixel = 0
	card.GroupTransparency = 1
	card.Visible = false
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = card

	title = label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 34),
		Text = "",
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	for index, name in ROWS do
		local top = 44 + (index - 1) * ROW_HEIGHT
		label({
			Position = UDim2.fromOffset(14, top),
			Size = UDim2.fromOffset(120, ROW_HEIGHT),
			Text = name,
			TextSize = 11,
			TextTransparency = 0.45,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		values[index] = label({
			Position = UDim2.fromOffset(136, top),
			Size = UDim2.new(1, -150, 0, ROW_HEIGHT),
			Text = "",
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
	end
	local bottom = 48 + ROW_HEIGHT * #ROWS
	tokensLine = label({
		Position = UDim2.fromOffset(14, bottom),
		Size = UDim2.new(1, -28, 0, 26),
		Text = "",
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	breakdownLine = label({
		Position = UDim2.fromOffset(14, bottom + 26),
		Size = UDim2.new(1, -28, 0, 14),
		Text = "",
		TextSize = 11,
		TextTransparency = 0.45,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
end

local function listText(lines: any): string
	if type(lines) ~= "table" or #lines == 0 then
		return "nothing"
	end
	local names = {}
	for _, line in lines do
		local count = tonumber(line.count) or 1
		table.insert(names, if count > 1 then `{line.name} x{count}` else tostring(line.name))
	end
	return table.concat(names, ", ")
end

local function breakdownText(pay: any): string
	local parts = { `night x{pay.multiplier} +{pay.life}` }
	for _, part in
		{ { "fort", pay.fort }, { "dog", pay.dog }, { "robot", pay.robot }, { "banked", pay.banked } }
	do
		if (tonumber(part[2]) or 0) > 0 then
			table.insert(parts, `{part[1]} +{part[2]}`)
		end
	end
	return table.concat(parts, "   ")
end

local function chime()
	local id = ModelLibrary.soundId(settings.Sounds.Chime)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = settings.ChimeVolume
	sound.Parent = SoundService
	Mix.route(sound, "UI")
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function hide()
	if not card.Visible then
		return
	end
	cardToken += 1
	local token = cardToken
	TweenService:Create(card, FADE, { GroupTransparency = 1 }):Play()
	task.delay(FADE.Time, function()
		if token == cardToken then
			card.Visible = false
		end
	end)
end

local function show(report: any)
	local pay = report.pay
	title.Text = (string.gsub(settings.Title, "{day}", tostring(report.day)))
	values[1].Text = `{report.nights}   x{pay.multiplier}`
	values[2].Text = listText(report.carrying)
	values[3].Text = if report.fortPieces > 0 then `{report.fortPieces} pieces` else "none"
	values[4].Text = if report.dogWithYou then "with you" else "not with you"
	if report.robotMadeIt == true then
		values[4].Text ..= "   -   your robot made it"
	end
	values[5].Text = listText(report.banked)
	local streak = tostring(report.streak or "")
	values[6].Text = if streak ~= "" then streak else "finish a TODAY list to start one"
	tokensLine.Text = `+{pay.total} TOKENS   ({report.balance})`
	breakdownLine.Text = breakdownText(pay)

	cardToken += 1
	local token = cardToken
	shownAt = os.clock()
	card.Visible = true
	TweenService:Create(card, FADE, { GroupTransparency = 0 }):Play()
	Mix.duck("dawn", Config.Mix.Duck.Dawn)
	chime()
	task.delay(settings.CardSeconds, function()
		if token == cardToken then
			hide()
		end
	end)
end

local function onReport(report: unknown)
	if type(report) ~= "table" or type((report :: any).pay) ~= "table" then
		return
	end
	task.delay(settings.CardDelay, show, report)
end

-- Watches input without sinking it, so the press that closes the card still does its normal job
local function onInput(input: InputObject)
	if
		card.Visible
		and CLOSING_INPUTS[input.UserInputType]
		and os.clock() - shownAt >= settings.CardGrace
	then
		hide()
	end
end

function Dawn.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Dawn"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	buildCard()
end

function Dawn.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.event("DawnReport").OnClientEvent:Connect(onReport)
	UserInputService.InputBegan:Connect(onInput)
end

return Dawn
