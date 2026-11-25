-- The "TODAY" list in the top right (a red spray tick when one's done), a toast with the reward
-- when one finishes and a "NEW DAY" popup each morning (unless the Dawn Report card is showing
-- then). The server decides what's done.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Glyphs = require(script.Parent.Glyphs)
local Hints = require(script.Parent.Hints)

local settings = Config.Missions
local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(12, 12, 14)
local TEXT = Color3.fromRGB(225, 222, 215)
local SPRAY_RED = Color3.fromRGB(200, 28, 22)
local ROW_HEIGHT = 34
local WIDTH = 230
local TOAST_SECONDS = 5
local POPUP_SECONDS = 4
local FADE = TweenInfo.new(0.8)
local TOAST_ORDER = 20 -- below any hint that matters
local DONE_SOUND = "arcade_coin"
local DONE_VOLUME = 0.6
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- The Dawn Report and the morning list arrive together; the popup waits this long to see if a card is coming
local DAWN_WAIT = 0.5
local DAWN_RECENT = 3

type Row = { tick: TextLabel, tickScale: UIScale, text: TextLabel, reward: TextLabel }

local Missions = {}

local gui: ScreenGui
local panel: Frame
local rows: { Row } = {}
local popup: Frame
local popupTitle: TextLabel
local popupLine: TextLabel
local popupToken = 0
local titleLabel: TextLabel
local dawnReportAt = -math.huge

local function frame(props: { [string]: any }, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

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

local function fill(text: string, values: { [string]: string }): string
	return (string.gsub(text, "{(%w+)}", function(key)
		return values[key]
	end))
end

-- Below the top bar so Roblox's own buttons stay clear
local function buildPanel()
	panel = frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 64),
		Size = UDim2.fromOffset(WIDTH, 30 + ROW_HEIGHT * settings.PerDay),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		Visible = false,
	}, gui)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = panel
	-- Clipboard clip
	frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(46, 8),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = 0.5,
	}, panel)
	titleLabel = label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 16),
		Text = settings.ListTitle,
		TextSize = 12,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	for index = 1, settings.PerDay do
		local top = 28 + (index - 1) * ROW_HEIGHT
		local tick = label({
			Position = UDim2.fromOffset(8, top),
			Size = UDim2.fromOffset(20, 18),
			Text = "",
			Font = Enum.Font.PermanentMarker,
			TextColor3 = SPRAY_RED,
			TextSize = 20,
		}, panel)
		local tickScale = Instance.new("UIScale")
		tickScale.Parent = tick
		rows[index] = {
			tick = tick,
			tickScale = tickScale,
			text = label({
				Position = UDim2.fromOffset(32, top),
				Size = UDim2.new(1, -40, 0, 18),
				Text = "",
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, panel),
			reward = label({
				Position = UDim2.fromOffset(32, top + 17),
				Size = UDim2.new(1, -40, 0, 12),
				Text = "",
				TextSize = 10,
				TextTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, panel),
		}
	end
end

local function buildPopup()
	popup = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(420, 90),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	popupTitle = label({
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		Font = Enum.Font.PermanentMarker,
		TextColor3 = SPRAY_RED,
		TextSize = 46,
		TextStrokeTransparency = 0.6,
	}, popup)
	popupLine = label({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 18,
		TextStrokeTransparency = 0.6,
	}, popup)
end

local function showPopup(title: string, line: string)
	popupToken += 1
	local token = popupToken
	popupTitle.Text = title
	popupLine.Text = line
	popupTitle.TextTransparency = 0
	popupLine.TextTransparency = 0
	popup.Visible = true
	task.delay(POPUP_SECONDS, function()
		if token ~= popupToken then
			return
		end
		TweenService:Create(popupTitle, FADE, { TextTransparency = 1 }):Play()
		TweenService:Create(popupLine, FADE, { TextTransparency = 1 }):Play()
		task.delay(FADE.Time, function()
			if token == popupToken then
				popup.Visible = false
			end
		end)
	end)
end

-- Bigger small print on a phone
local function fitText()
	local touch = Glyphs.device() == "Touch"
	titleLabel.TextSize = if touch then 14 else 12
	for _, row in rows do
		row.reward.TextSize = if touch then 13 else 10
		row.reward.Size = UDim2.new(1, -40, 0, if touch then 15 else 12)
		row.reward.TextTransparency = if touch then 0.3 else 0.5
	end
end

local function playDone()
	local id = ModelLibrary.soundId(DONE_SOUND)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = DONE_VOLUME
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function pulse(text: string)
	for _, row in rows do
		if row.text.Text == string.upper(text) then
			row.tickScale.Scale = 2
			TweenService:Create(row.tickScale, PULSE, { Scale = 1 }):Play()
		end
	end
end

local function morningPopup()
	task.wait(DAWN_WAIT)
	if os.clock() - dawnReportAt > DAWN_RECENT then
		showPopup(settings.MorningTitle, settings.MorningLine)
	end
end

local function showRows(list: { any })
	for index, row in rows do
		local entry = list[index]
		local done = entry and entry.done == true
		row.tick.Text = if done then "✓" else ""
		row.text.Text = if entry then string.upper(tostring(entry.text)) else ""
		row.text.Font = if done then Enum.Font.PermanentMarker else Enum.Font.GothamBold
		row.text.TextColor3 = if done then SPRAY_RED else TEXT
		row.text.TextTransparency = if done then 0.15 else 0
		row.reward.Text = if entry then tostring(entry.reward) else ""
	end
	panel.Visible = #list > 0
end

local function onState(state: unknown)
	if type(state) ~= "table" then
		return
	end
	local data = state :: any
	if type(data.rows) == "table" then
		showRows(data.rows)
	end
	if data.reason == "morning" then
		task.spawn(morningPopup)
	elseif data.reason == "join" then
		showPopup(settings.ListTitle, settings.MorningLine)
	elseif data.reason == "done" and type(data.finished) == "table" then
		-- Hint lines are one row high, so each finished mission gets its own line
		for index, finished in data.finished do
			local text = `{fill(settings.DoneLine, { text = tostring(finished.text) })}   {finished.reward}`
			Hints.flash(`mission{index}`, text, TOAST_SECONDS, nil, TOAST_ORDER)
			pulse(tostring(finished.text))
		end
		playDone()
		if data.allDone then
			Hints.flash("missionsAll", settings.AllDoneLine, TOAST_SECONDS, nil, TOAST_ORDER)
		end
	end
end

function Missions.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Missions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	buildPanel()
	buildPopup()
end

function Missions.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.event("DawnReport").OnClientEvent:Connect(function()
		dawnReportAt = os.clock()
	end)
	Glyphs.onChanged(fitText)
	fitText()
	Net.event("MissionsState").OnClientEvent:Connect(onState)
	Net.event("MissionsSync"):FireServer()
end

return Missions
