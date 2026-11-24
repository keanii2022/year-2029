-- Showroom floor plan: one row per art group, wrapping long groups, in showroom space (x along a row, rows go +z).
-- Pure: sizes are { x, y, z } arrays from the manifest.

export type Item = { name: string, size: { number } }
export type Group = { name: string, models: { Item } }
export type Options = { spacing: number, rowGap: number, maxRowWidth: number }

export type Spot = { name: string, group: string, x: number, z: number }
export type RowLabel = { group: string, x: number, z: number }
export type Plan = { spots: { Spot }, labels: { RowLabel }, width: number, depth: number }

local ManifestLayout = {}

function ManifestLayout.plan(groups: { Group }, options: Options): Plan
	local plan: Plan = { spots = {}, labels = {}, width = 0, depth = 0 }
	local rowZ = 0

	for _, group in groups do
		local x, rowDepth = 0, 0
		local rowSpots = {}

		local function closeRow()
			for _, spot in rowSpots do
				spot.z = rowZ + rowDepth / 2
			end
			plan.width = math.max(plan.width, x - options.spacing)
			rowZ += rowDepth + options.rowGap
			x, rowDepth, rowSpots = 0, 0, {}
		end

		table.insert(plan.labels, { group = group.name, x = 0, z = rowZ })
		for _, item in group.models do
			local width, depth = item.size[1], item.size[3]
			if x > 0 and x + width > options.maxRowWidth then
				closeRow()
			end
			local spot = { name = item.name, group = group.name, x = x + width / 2, z = 0 }
			table.insert(plan.spots, spot)
			table.insert(rowSpots, spot)
			x += width + options.spacing
			rowDepth = math.max(rowDepth, depth)
		end
		if #rowSpots > 0 then
			closeRow()
		end
	end

	plan.depth = math.max(rowZ - options.rowGap, 0)
	return plan
end

return ManifestLayout
