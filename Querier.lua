
Querier = LibStub("AceAddon-3.0"):NewAddon("Querier", "AceConsole-3.0")

local addon = Querier
local tonumber = tonumber
local GetItemInfo = GetItemInfo
local GetSpellLink = GetSpellLink
local GetTime = GetTime

-- Time between queries to reset list
local TimeQuery = 600
--local TimeQuery = 10
-- Max number of queries to allow during time period
local MaxQuery = 10

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


function addon:OnInitialize()

	AceConfig:RegisterOptionsTable("Querier", options, {"Querier"})
	LibStub("LibAboutPanel").new(nil, "Querier")
	self:RegisterChatCommand("ItemQuery", "ItemQuery")
	self:RegisterChatCommand("SpellQuery", "SpellQuery")
	self:RegisterChatCommand("iq", "ItemQuery")
	self:RegisterChatCommand("sq", "SpellQuery")

end

do

	local lastitem = nil
	local lastquery = nil
	local totalquery = 0

	function addon:ItemQuery(ItemID)

		local id = tonumber(ItemID)
		-- We have a string, lets assume it's an item link
		if (not id) then

			-- New regexp thanks to Arrowmaster
			local _, _, ID = string.find(ItemID, "item:(%d+)")

			if (tonumber(ID) ~= nil) then
				self:Print("Item link: " .. ItemID .. " is item ID: " .. ID)
			else
				self:Print("Invalid input.  Must be numeric item-ID or item link.")
			end

		-- We've got a number, lets try to get the link via ID
		else

			local maxtime
			if (lastquery) then
				maxtime = lastquery + TimeQuery
			else
				maxtime = 0
			end

			-- If we haven't done a query in a long time, reset the query count.
			if lastquery and (GetTime() > maxtime) then
				totalquery = 0
			end

			-- Only do the query if we haven't done too many
			if (totalquery < MaxQuery) then
				-- Attempt to cache the ID
				GameTooltip:SetHyperlink("item:"..id..":0:0:0:0:0:0:0")
				-- Set the time of the query so we can reset failed queries later
				lastquery = GetTime()
				self:Print("Item queried.")

				local _,itemlink = GetItemInfo(id)

				if (itemlink ~= nil) then
					self:Print("Item link found: " .. itemlink)
				else
					-- Increase the number of failed queries
					totalquery = totalquery + 1
					self:Print("Item link not found.   Try again to see if item has been cached.")
				end

			else
				self:Print("Item not queried as there is a risk of disconnect.  Please try again later.")
			end

		end

	end

end

function addon:SpellQuery(SpellID)

	local id = tonumber(SpellID)
	if (not id) then
			local _, _, ID = string.find(SpellID, "spell:(%d+)")

			if (tonumber(ID) ~= nil) then
				self:Print("Spell link: " .. SpellID .. " is spell ID: " .. ID)
			else
				local spellName
				for i = 1, 50000 do
					spellName = GetSpellInfo(i)
					if (spellName and (spellName:lower() == SpellID:lower())) then
						self:Print("Spell link: " .. GetSpellLink(i) .. " is spell ID: " .. tostring(i))
						return
					end
				end
				self:Print("Spell: " .. SpellID .. " not found")
			end
	else
		if (GetSpellLink(id) ~= nil) then
			self:Print("Spell link found: " .. GetSpellLink(id))
		else
			self:Print("Spell link unknown.")
		end
	end

end
