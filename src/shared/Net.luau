-- Remotes are created by name on the server and waited for on the client,
-- so a system never has to touch a shared remotes list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(className: string, name: string): Instance
	local remotes = folder()
	if RunService:IsServer() then
		local existing = remotes:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
		return remote
	end
	return remotes:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return get("RemoteEvent", name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return get("UnreliableRemoteEvent", name) :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get("RemoteFunction", name) :: RemoteFunction
end

return Net
