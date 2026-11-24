-- Every tuning number lives in a child module here (Config/Movement.luau, Config/Guns.luau, ...).
-- Each step adds its own file so parallel work never edits the same one.
local Config = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		Config[child.Name] = require(child) :: any
	end
end

return table.freeze(Config)
