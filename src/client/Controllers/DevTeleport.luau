-- Studio playtests and admins only: jump to the next / previous installation and show which one
-- ("poolroom 3/64"). Keyboard T / Shift+T (not while carrying, where T turns the prop), gamepad
-- both sticks pressed together (L3 + R3, add L1 to go back), touch the TP buttons top-left.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)

local player = Players.LocalPlayer

local DevTeleport = {}

local function enable()
	local request = Net.event("DevTeleport")
	Net.event("DevTeleported").OnClientEvent:Connect(function(kind: string, index: number, count: number)
		Hints.flash("devTeleport", `[TEST] {kind} {index}/{count}`, 5)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if player:GetAttribute("CarrySpeedMultiplier") ~= nil then
			return
		end
		if input.KeyCode == Enum.KeyCode.T and not processed then
			local back = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			request:FireServer(if back then -1 else 1)
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 or input.KeyCode == Enum.KeyCode.ButtonR3 then
			local other = if input.KeyCode == Enum.KeyCode.ButtonL3
				then Enum.KeyCode.ButtonR3
				else Enum.KeyCode.ButtonL3
			if UserInputService:IsGamepadButtonDown(input.UserInputType, other) then
				local back = UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonL1)
				request:FireServer(if back then -1 else 1)
			end
		end
	end)
	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "DevTeleport"
		gui.ResetOnSpawn = false
		for index, spec in { { "TP ◀", -1 }, { "TP ▶", 1 } } do
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(64, 36)
			button.Position = UDim2.fromOffset(12 + (index - 1) * 72, 120)
			button.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
			button.BackgroundTransparency = 0.3
			button.TextColor3 = Color3.fromRGB(236, 232, 222)
			button.Font = Enum.Font.GothamBold
			button.TextSize = 14
			button.Text = spec[1]
			button.Activated:Connect(function()
				request:FireServer(spec[2])
			end)
			button.Parent = gui
		end
		gui.Parent = player:WaitForChild("PlayerGui")
	end
end

function DevTeleport.Start()
	if RunService:IsStudio() or player:GetAttribute("Admin") == true then
		enable()
		return
	end
	-- The server decides admins a moment after joining
	local connection
	connection = player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") == true then
			connection:Disconnect()
			enable()
		end
	end)
end

return DevTeleport
