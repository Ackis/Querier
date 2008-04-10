
Querier = LibStub("AceAddon-3.0"):NewAddon("Querier", "AceConsole-3.0")

local AceConfig = LibStub("AceConfig-3.0")

local options = { 
	type='group',
	args = {
		ItemQuery = {
			type = "input",
			name = "Item Query",
			desc = "Queries the server and provides an item link.",
			get = false,
			set = function(info, v) Querier:ItemQuery(v) end,
			order = 1,
		},
		SpellQuery = {
			type = "input",
			name = "Spell Query",
			desc = "Queries the server and provides an spell link.",
			get = false,
			set = function(info, v) Querier:SpellQuery(v) end,
			order = 2,
		},
	},
}

AceConfig:RegisterOptionsTable("Querier", options, {"Querier"})

function Querier:ItemQuery(ItemID)

	local id = tonumber(ItemID)
	if (not id) then
		return self:Print("Invalid input.  Must be numeric item-ID.")
	end

	GameTooltip:SetHyperlink("item:"..id..":0:0:0:0:0:0:0")

	local _,itemlink = GetItemInfo(id)

	if (itemlink ~= nil) then

		self:Print("Item link found: " .. itemlink)

	else

		self:Print("Item link not found.   Try again to see if item has been cached.")

	end

end

function Querier:SpellQuery(SpellID)

	local id = tonumber(SpellID)
	if (not id) then
		return self:Print("Invalid input.  Must be numeric item-ID.")
	end

	if (GetSpellLink(id) ~= nil) then

		self:Print("Spell link found: " .. GetSpellLink(id))

	else

		self:Print("Spell link unknown.")

	end

end
