-- Studio playtest only: T / Shift+T asks the server to jump to the next / previous installation and
-- shows which one ("poolroom 3/64"). Not while carrying a prop, where T turns the prop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Hints = require(script.Parent.Hints)

local player = Players.LocalPlayer

local DevTeleport = {}

function DevTeleport.Start()
	if not RunService:IsStudio() then
		return
	end
	local request = Net.event("DevTeleport")
	Net.event("DevTeleported").OnClientEvent:Connect(function(kind: string, index: number, count: number)
		Hints.flash("devTeleport", `[TEST] {kind} {index}/{count}   (T next, Shift+T back)`, 5)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.T then
			return
		end
		if player:GetAttribute("CarrySpeedMultiplier") ~= nil then
			return
		end
		local back = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		request:FireServer(if back then -1 else 1)
	end)
end

return DevTeleport
