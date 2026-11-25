-- Warehouse size presets. Every count in the configs is tuned for TunedSize; smaller warehouses
-- shrink them by area raised to CountScalePower (below 1), so small maps end up a bit denser.
local WarehouseSizes = {}

export type Choice = { size: string, publicLobby: boolean }

-- 1 at TunedSize, about 0.31 for a half-width warehouse at power 0.85
function WarehouseSizes.scale(size: number, config: any): number
	return (size / config.TunedSize) ^ (2 * config.CountScalePower)
end

-- A count tuned for TunedSize, scaled to this size. Never drops a positive count to zero.
function WarehouseSizes.scaled(size: number, count: number, config: any): number
	if count <= 0 then
		return 0
	end
	return math.max(1, math.floor(count * WarehouseSizes.scale(size, config) + 0.5))
end

function WarehouseSizes.isSize(name: unknown, config: any): boolean
	return type(name) == "string" and config.Sizes[name] ~= nil
end

-- Studs for a preset name; unknown names fall back to DefaultSize
function WarehouseSizes.studs(name: string?, config: any): number
	return config.Sizes[name or ""] or config.Sizes[config.DefaultSize]
end

-- What a size server stored in MemoryStore, checked; anything off becomes the default.
function WarehouseSizes.parseChoice(raw: unknown, config: any): Choice
	local stored = if type(raw) == "table" then raw :: any else {}
	return {
		size = if WarehouseSizes.isSize(stored.size, config) then stored.size else config.DefaultSize,
		publicLobby = stored.publicLobby == true,
	}
end

-- The config handed to WarehouseGen for one preset: a copy with Size swapped in
function WarehouseSizes.configFor(name: string?, config: any): any
	local sized = table.clone(config)
	sized.Size = WarehouseSizes.studs(name, config)
	return sized
end

return WarehouseSizes
