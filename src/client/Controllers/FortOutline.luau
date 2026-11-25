-- Your fort shows as yours: pieces you placed that make a fort (Director's clusters, same
-- FortRadius / FortMinProps) get a faint outline while you're within FortOutlineRange, and the
-- first time you see one a nudge says so. Drawn on your screen only; nobody else sees it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DirectorLogic = require(ReplicatedStorage.Shared.Logic.Director)

local Hints = require(script.Parent.Hints)

local Settings = Config.Grab
local OUTLINE = Color3.fromRGB(200, 215, 230)

local player = Players.LocalPlayer

local FortOutline = {}

local folder: Folder
local outlines: { [PVInstance]: SelectionBox } = {}

local function myPieces(): { PVInstance }
	local pieces = {}
	for _, prop in CollectionService:GetTagged(Settings.Tag) do
		if
			prop:IsA("PVInstance")
			and prop:GetAttribute("PlacedBy") == player.UserId
			and prop:GetAttribute("CarriedBy") == nil
			and prop:IsDescendantOf(workspace)
		then
			table.insert(pieces, prop)
		end
	end
	return pieces
end

-- My pieces that belong to a fort and sit within range of position
local function fortPieces(position: Vector3): { [PVInstance]: true }
	local pieces = myPieces()
	local points = {}
	for index, prop in pieces do
		local at = prop:GetPivot().Position
		points[index] = { x = at.X, z = at.Z }
	end
	local found = {}
	for _, group in DirectorLogic.cluster(points, Config.Director.FortRadius) do
		if group.count >= Config.Director.FortMinProps and group.members then
			for _, index in group.members do
				local prop = pieces[index]
				if (prop:GetPivot().Position - position).Magnitude <= Settings.FortOutlineRange then
					found[prop] = true
				end
			end
		end
	end
	return found
end

local function refresh()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local wanted = if root and root:IsA("BasePart") then fortPieces(root.Position) else {}
	for prop, outline in outlines do
		if not wanted[prop] then
			outline:Destroy()
			outlines[prop] = nil
		end
	end
	for prop in wanted do
		if not outlines[prop] then
			local outline = Instance.new("SelectionBox")
			outline.Adornee = prop
			outline.Color3 = OUTLINE
			outline.LineThickness = 0.03
			outline.Transparency = 0.65
			outline.Parent = folder
			outlines[prop] = outline
		end
	end
	if next(wanted) then
		Hints.nudge("fort", Config.Hints.FortNudge)
	end
end

function FortOutline:Start()
	folder = Instance.new("Folder")
	folder.Name = "FortOutline"
	folder.Parent = player:WaitForChild("PlayerGui")
	while true do
		refresh()
		task.wait(Settings.FortOutlineEvery)
	end
end

return FortOutline
