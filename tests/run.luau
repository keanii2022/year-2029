-- Runs every tests/*.spec.luau. A spec returns { ["test name"] = function() ... end }.
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0

local files = fs.readDir("tests")
table.sort(files)
for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		local specName = string.gsub(file, "%.luau$", "")
		local spec = require(`./{specName}`)
		local names = {}
		for name in spec do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local ok, err = pcall(spec[name])
			if ok then
				passed += 1
			else
				failed += 1
				print(`FAIL {file} :: {name}\n  {err}`)
			end
		end
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
