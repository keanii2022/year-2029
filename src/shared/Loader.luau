-- Requires every ModuleScript in a folder, calls Init() on all of them, then Start() on all.
-- Init runs in order and may not yield; Start runs each in its own thread.
local Loader = {}

function Loader.run(container: Instance)
	local modules = {}
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				table.insert(modules, { name = child.Name, module = result })
			else
				warn(`[Loader] {child.Name} failed to load: {result}`)
			end
		end
	end

	for _, entry in modules do
		if type(entry.module) == "table" and entry.module.Init then
			local ok, err = pcall(entry.module.Init, entry.module)
			if not ok then
				warn(`[Loader] {entry.name}.Init failed: {err}`)
			end
		end
	end

	for _, entry in modules do
		if type(entry.module) == "table" and entry.module.Start then
			task.spawn(entry.module.Start, entry.module)
		end
	end
end

return Loader
