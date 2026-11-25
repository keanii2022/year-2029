-- The 2029 Files: lore found in the world, saved as a list of ids. Every PerChapter finds opens the
-- next chapter (and a cosmetic, through the FilesFound stat). No Roblox here.
export type Entry = { id: string, kind: string, title: string, text: string }

local Files = {}

-- Every entry in order: the survivor journals NightTricks places (Config.NightTricks.Journals,
-- which carry their own id) first, then the Files config's own entries
function Files.catalog(config: any, journals: { any }): { Entry }
	local list = {}
	for _, page in journals do
		table.insert(list, { id = page.id, kind = "journal", title = page.title, text = page.text })
	end
	for _, entry in config.Entries do
		table.insert(list, { id = entry.id, kind = entry.kind, title = entry.title, text = entry.text })
	end
	return list
end

function Files.byId(catalog: { Entry }, id: string): Entry?
	for _, entry in catalog do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Adds a known id once. True when it was new.
function Files.add(found: { string }, catalog: { Entry }, id: string): boolean
	if table.find(found, id) or not Files.byId(catalog, id) then
		return false
	end
	table.insert(found, id)
	return true
end

-- First entry of one of these kinds not found yet, trying the kinds in order
function Files.nextOf(catalog: { Entry }, found: { string }, kinds: { string }): Entry?
	for _, kind in kinds do
		for _, entry in catalog do
			if entry.kind == kind and not table.find(found, entry.id) then
				return entry
			end
		end
	end
	return nil
end

-- Finds that count toward chapters: known entries only, so a renamed id never inflates it
function Files.count(found: { string }, catalog: { Entry }): number
	local count = 0
	for _, id in found do
		if Files.byId(catalog, id) then
			count += 1
		end
	end
	return count
end

function Files.chaptersOpen(count: number, perChapter: number, chapters: number): number
	return math.clamp(math.floor(count / perChapter), 0, chapters)
end

-- Finds needed for the next chapter, or nil once they're all open
function Files.nextChapterAt(count: number, perChapter: number, chapters: number): number?
	local open = Files.chaptersOpen(count, perChapter, chapters)
	return if open < chapters then (open + 1) * perChapter else nil
end

return Files
