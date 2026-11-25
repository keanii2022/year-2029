-- Aisle 40, the Smile Aisle. Makes sure exactly one aisle sign reads 40 on every map, carves the
-- night manager's hidden office out of the far end of the racks beside it, and lays out the
-- store's smile propaganda along the aisle. Also finds a spot for the lost and found box just
-- inside the entrance. Plain data appended to the layout; server SmileAisle builds it.
-- Local studs like the rest of WarehouseGen: x east, z south.
local SmileAisle = {}

export type Rect = { x0: number, z0: number, x1: number, z1: number }
export type Decor = {
	kind: string, -- "poster" | "sticker" | "banner"
	x: number,
	y: number,
	z: number,
	nx: number, -- outward normal of the face it's on (banners: the way their front reads)
	nz: number,
	index: number, -- which line or picture, counting from 1 along the aisle
	sprayed: boolean, -- survivor paint over it
}
export type Plan = {
	sign: any,
	lane: Rect, -- the walking floor of aisle 40, between rack rows 1 and 2
	office: Rect, -- the hidden office, where rows 2 and 3 used to end
	panel: { x: number, z: number, width: number }, -- doorway centre in the office wall at z = office.z0
	booth: { x: number, z: number }, -- centre; back to row 1, screen facing +z
	mark: { x: number, z: number }, -- where you stand to be checked
	phone: { x: number, z: number }, -- on the office's aisle wall
	greeter: { x: number, z: number }, -- at the aisle mouth by the sign
	decor: { Decor },
}
export type LostFound = { x: number, z: number }

-- The three rack rows a racking zone's sign hangs over the start of, nearest the sign first, or
-- nil when the zone has fewer than three
local function rowsFor(layout: any, sign: any, pitch: number): { any }?
	local rows = {}
	for k = 0, 2 do
		local z = sign.z + k * pitch
		for _, shelf in layout.shelves do
			if math.abs(shelf.x0 - 3 - sign.x) < 0.01 and math.abs(shelf.z - z) < 0.01 then
				rows[k + 1] = shelf
				break
			end
		end
		if not rows[k + 1] then
			return nil
		end
	end
	return rows
end

-- Shortens a shelf and the solid that blocks it out. The solid is the same table in every block
-- it was filed under, so changing it in place keeps them all in step.
local function cutShelf(layout: any, shelf: any, x1: number)
	local i = math.clamp(math.floor((shelf.x0 + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local j = math.clamp(math.floor((shelf.z + layout.half) / layout.blockSize), 0, layout.blocks - 1)
	local key = j * layout.blocks + i + 1
	for _, solid in layout.solidsByBlock[key] or {} do
		if
			solid.x0 == shelf.x0
			and solid.x1 == shelf.x1
			and math.abs(solid.z0 - (shelf.z - shelf.depth / 2)) < 0.01
		then
			solid.x1 = x1
			break
		end
	end
	shelf.x1 = x1
end

-- Faded posters on both rack faces, smiley stickers lower down, banners hung across the aisle
local function decor(plan: Plan, settings: any): { Decor }
	local list = {}
	local lane = plan.lane
	local faces = {
		{ z = lane.z0 + 0.05, nz = 1, x1 = lane.x1 - 3 }, -- row 1, looking into the aisle
		{ z = lane.z1 - 0.05, nz = -1, x1 = plan.office.x0 - settings.EndGap - 3 }, -- row 2, cut short
	}
	local posters, stickers = 0, 0
	for side, face in faces do
		local x = lane.x0 + 4 + (side - 1) * settings.PosterEvery / 2
		while x < face.x1 do
			posters += 1
			local low, high = settings.PosterHeight[1], settings.PosterHeight[2]
			table.insert(list, {
				kind = "poster",
				x = x,
				y = low + (high - low) * ((posters % 3) / 2),
				z = face.z,
				nx = 0,
				nz = face.nz,
				index = posters,
				sprayed = posters % settings.SprayEvery == 0,
			})
			x += settings.PosterEvery
		end
		x = lane.x0 + 2 + (side - 1) * settings.StickerEvery / 2
		while x < face.x1 do
			stickers += 1
			local low, high = settings.StickerHeight[1], settings.StickerHeight[2]
			table.insert(list, {
				kind = "sticker",
				x = x,
				y = low + (high - low) * ((stickers * 7 % 5) / 4),
				z = face.z,
				nx = 0,
				nz = face.nz,
				index = stickers,
				sprayed = false,
			})
			x += settings.StickerEvery
		end
	end
	local banners = 0
	local x = lane.x0 + settings.BannerEvery / 2
	while x < plan.office.x0 - 4 do
		banners += 1
		table.insert(list, {
			kind = "banner",
			x = x,
			y = settings.BannerY,
			z = (lane.z0 + lane.z1) / 2,
			nx = -1,
			nz = 0,
			index = banners,
			sprayed = banners % 2 == 0,
		})
		x += settings.BannerEvery
	end
	return list
end

-- Picks aisle 40 and plans it. A sign that already rolled 40 keeps it; otherwise the racking zone
-- nearest settings.Depth gets it. Every other sign that rolled 40 reads WrongNumber instead.
-- depth: WarehouseGen.depth for this layout. Nil only on a floor with no racking zone at all.
function SmileAisle.plan(layout: any, config: any, depth: (x: number, z: number) -> number): Plan?
	local settings = config.SmileAisle
	local best, bestRows, bestScore = nil, nil, math.huge
	for _, sign in layout.signs do
		local rows = rowsFor(layout, sign, config.RackPitch)
		if rows then
			local score = if sign.number == settings.Number
				then -1
				else math.abs(depth(sign.x, sign.z) - settings.Depth)
			if score < bestScore then
				best, bestRows, bestScore = sign, rows, score
			end
		end
	end
	if not best or not bestRows then
		return nil
	end
	for _, sign in layout.signs do
		if sign.number == settings.Number then
			sign.number = settings.WrongNumber
		end
	end
	best.number = settings.Number
	best.smile = true

	local half = config.RackDepth / 2
	local row1, row2, row3 = bestRows[1], bestRows[2], bestRows[3]
	local x1 = row1.x1
	local office = { x0 = x1 - settings.OfficeLength, z0 = row2.z - half, x1 = x1, z1 = row3.z + half }
	cutShelf(layout, row2, office.x0 - settings.EndGap)
	cutShelf(layout, row3, office.x0 - settings.EndGap)
	layout.addSolid({ x0 = office.x0, z0 = office.z0, x1 = office.x1, z1 = office.z1 })

	local lane = { x0 = row1.x0, z0 = row1.z + half, x1 = x1, z1 = row2.z - half }
	local panelX = office.x0 + settings.PanelInset
	local boothZ = lane.z0 + settings.BoothDepth / 2 + 0.1
	layout.addSolid({
		x0 = panelX - 2,
		z0 = lane.z0,
		x1 = panelX + 2,
		z1 = lane.z0 + settings.BoothDepth + 0.2,
	})
	local plan: Plan = {
		sign = best,
		lane = lane,
		office = office,
		panel = { x = panelX, z = office.z0, width = settings.PanelWidth },
		booth = { x = panelX, z = boothZ },
		mark = { x = panelX, z = lane.z0 + settings.BoothDepth + settings.MarkGap },
		phone = { x = office.x1 - 4, z = office.z0 },
		greeter = { x = lane.x0 + 2.5, z = lane.z0 + 1.5 },
		decor = {},
	}
	plan.decor = decor(plan, settings)
	return plan
end

-- The first clear spot walking in from the entrance doors, a little either side of the middle
function SmileAisle.lostFound(
	layout: any,
	config: any,
	isClear: (x: number, z: number, pad: number) -> boolean
): LostFound?
	local settings = config.SmileAisle
	local startZ = layout.entrance.z - config.WallThickness - 6
	for step = 0, settings.LostFoundSearch, 4 do
		for _, x in { 10, -10, 18, -18, 26, -26 } do
			local z = startZ - step
			if isClear(x, z, 3) then
				layout.addSolid({ x0 = x - 1.5, z0 = z - 1.5, x1 = x + 1.5, z1 = z + 1.5 })
				return { x = x, z = z }
			end
		end
	end
	return nil
end

return SmileAisle
