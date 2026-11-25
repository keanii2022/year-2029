local AdminAccess = require("../src/shared/Logic/AdminAccess")
local expect = require("./expect")

local function rules(overrides: { [string]: any }?): AdminAccess.Rules
	local base: { [string]: any } = {
		userIds = { 111 },
		userNames = { "GhostyBoy" },
		resolvedIds = { 222 },
		creatorId = 333,
		creatorIsUser = true,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base :: any
end

return {
	["listed and resolved ids are admins"] = function()
		expect(AdminAccess.isAdmin(111, "someone", rules())).toBe(true)
		expect(AdminAccess.isAdmin(222, "someone", rules())).toBe(true)
	end,
	["the creator is an admin only when a user owns the place"] = function()
		expect(AdminAccess.isAdmin(333, "someone", rules())).toBe(true)
		expect(AdminAccess.isAdmin(333, "someone", rules({ creatorIsUser = false }))).toBe(false)
	end,
	["names match without caring about case"] = function()
		expect(AdminAccess.isAdmin(999, "ghostyboy", rules())).toBe(true)
		expect(AdminAccess.isAdmin(999, "ghostyboy2", rules())).toBe(false)
	end,
	["everyone else is refused"] = function()
		expect(AdminAccess.isAdmin(999, "stranger", rules())).toBe(false)
	end,
	["nextIndex wraps round"] = function()
		expect(AdminAccess.nextIndex(1, 3)).toBe(2)
		expect(AdminAccess.nextIndex(3, 3)).toBe(1)
	end,
	["count only takes whole numbers in range"] = function()
		expect(AdminAccess.count(5, 20)).toBe(5)
		expect(AdminAccess.count(0, 20)).toBe(nil)
		expect(AdminAccess.count(21, 20)).toBe(nil)
		expect(AdminAccess.count(2.5, 20)).toBe(nil)
		expect(AdminAccess.count("5", 20)).toBe(nil)
	end,
}
