local InteractKinds = require("../src/shared/Logic/InteractKinds")
local Loudness = require("../src/shared/Logic/Loudness")
local Manifest = require("../src/shared/Logic/Manifest")
local ManifestData = require("../src/shared/Logic/ManifestData")
local expect = require("./expect")

local index = Manifest.index(ManifestData :: any)
local KINDS = { "open", "toggle", "hide", "channel", "press", "cycle", "vend", "sit", "phone" }
local MOVING_FIELDS = { "parts", "press", "spin", "bob", "pop", "spinOnSit" }
local SOUND_FIELDS = { "sound", "offSound", "endSound", "loop", "staticSound" }
local IMAGE_FIELDS = { "static", "screenOn" }

-- Calls fn(modelName, label, behaviour) for every behaviour, byPart ones included.
local function eachBehaviour(fn: (string, string, any) -> ())
	for modelName, behaviour in InteractKinds.all() do
		fn(modelName, modelName, behaviour)
		for partName, sub in behaviour.byPart or {} do
			fn(modelName, `{modelName}.{partName}`, sub)
		end
	end
end

-- expect(...).toBe(label) reports which entry failed.
local function check(ok: boolean, label: string)
	expect(if ok then label else `{label} (bad)`).toBe(label)
end

return {
	["every behaviour is for a real model and has a known kind and loudness"] = function()
		eachBehaviour(function(modelName, label, behaviour)
			check(index.models[modelName] ~= nil, label)
			check(table.find(KINDS, behaviour.kind) ~= nil, label)
			check(Loudness.isLevel(behaviour.loudness), label)
			for _, field in { "loopLoudness", "endLoudness" } do
				if behaviour[field] then
					check(Loudness.isLevel(behaviour[field]), `{label}.{field}`)
				end
			end
		end)
	end,
	["every moving part exists and has a motion"] = function()
		eachBehaviour(function(modelName, label, behaviour)
			local entry = index.models[modelName]
			for _, field in MOVING_FIELDS do
				for _, partName in behaviour[field] or {} do
					local name = `{label}.{field}.{partName}`
					check(Manifest.part(entry, partName) ~= nil, name)
					check(Manifest.motion(modelName, partName, nil) ~= nil, name)
				end
			end
		end)
	end,
	["byPart keys are real parts"] = function()
		for modelName, behaviour in InteractKinds.all() do
			for partName in behaviour.byPart or {} do
				check(Manifest.part(index.models[modelName], partName) ~= nil, `{modelName}.{partName}`)
			end
		end
	end,
	["every sound and image is in the pack"] = function()
		eachBehaviour(function(_, label, behaviour)
			for _, field in SOUND_FIELDS do
				if behaviour[field] then
					check(index.sounds[behaviour[field]] ~= nil, `{label}.{behaviour[field]}`)
				end
			end
			for _, image in behaviour.channels or {} do
				check(index.images[image] ~= nil, `{label}.{image}`)
			end
			for _, field in IMAGE_FIELDS do
				if behaviour[field] then
					check(index.images[behaviour[field]] ~= nil, `{label}.{behaviour[field]}`)
				end
			end
		end)
	end,
	["each kind has the fields it needs"] = function()
		eachBehaviour(function(_, label, behaviour)
			if behaviour.kind == "sit" then
				check(type(behaviour.seatHeight) == "number", label)
			elseif behaviour.kind == "cycle" or behaviour.kind == "vend" then
				check(type(behaviour.duration) == "number", label)
			elseif behaviour.kind == "channel" then
				check(#(behaviour.channels or {}) > 0, label)
			end
		end)
	end,
}
