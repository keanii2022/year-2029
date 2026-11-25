-- One subtitle line near the bottom of the screen for things the player hears: store PA lines,
-- night announcements, rumors. Kept apart from the Hints list so it never pushes out control hints.
-- The newest line replaces the one showing.
local Players = game:GetService("Players")

local Subtitles = {}

local gui: ScreenGui
local label: TextLabel
local token = 0

function Subtitles.show(text: string, seconds: number)
	token += 1
	local mine = token
	label.Text = text
	label.Visible = true
	task.delay(seconds, function()
		if token == mine then
			label.Visible = false
		end
	end)
end

function Subtitles.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Subtitles"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	label = Instance.new("TextLabel")
	label.Name = "Line"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -150)
	label.Size = UDim2.new(0.6, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(230, 230, 225)
	label.TextStrokeTransparency = 0.5
	label.Visible = false
	label.Parent = gui
end

function Subtitles.Start()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Subtitles
