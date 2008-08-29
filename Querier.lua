
Querier = LibStub("AceAddon-3.0"):NewAddon("Querier", "AceConsole-3.0")

local addon = Querier
local tonumber = tonumber
local GetItemInfo = GetItemInfo
local GetSpellLink = GetSpellLink
local GetTime = GetTime
local maxspells = 60000

-- Time between queries to reset list
local TimeQuery = 600
--local TimeQuery = 10
-- Max number of queries to allow during time period
local MaxQuery = 10

local function giveOptions()

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
			ItemScan = {
				type = "input",
				name = "Item Scan",
				desc = "Scans the server and provides an item links from first input to second input.",
				get = false,
				set = function(info, v) Querier:ItemScan(v) end,
				order = 4,
			},
			SpellQuery = {
				type = "input",
				name = "Spell Query",
				desc = "Queries the server and provides an spell link.",
				get = false,
				set = function(info, v) Querier:SpellQuery(v) end,
				order = 3,
			},
			SpellScan = {
				type = "input",
				name = "Spell Scan",
				desc = "Scans the server and provides an spell links from first input to second input.",
				get = false,
				set = function(info, v) Querier:SpellScan(v) end,
				order = 4,
			},
		}
	}

	return options

end


function addon:OnInitialize()

	local AceConfig = LibStub("AceConfig-3.0")
	local AceConfigReg = LibStub("AceConfigRegistry-3.0")
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")

	AceConfig:RegisterOptionsTable("Querier", giveOptions)

	-- Create blizzard interface options stuff
	self.optionsFrame = AceConfigDialog:AddToBlizOptions("Querier","Querier")
	self.optionsFrame["About"] = LibStub("LibAboutPanel").new("Querier", "Querier")

	-- Create slash commands
	self:RegisterChatCommand("ItemQuery", "ItemQuery")
	self:RegisterChatCommand("SpellQuery", "SpellQuery")
	self:RegisterChatCommand("iq", "ItemQuery")
	self:RegisterChatCommand("sq", "SpellQuery")
	self:RegisterChatCommand("ItemScan", "ItemScan")
	self:RegisterChatCommand("SpellScan", "SpellScan")
	self:RegisterChatCommand("is", "ItemScan")
	self:RegisterChatCommand("ss", "SpellScan")

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
					return 0
				else
					-- Increase the number of failed queries
					totalquery = totalquery + 1
					self:Print("Item link not found.   Try again to see if item has been cached.")
					return 1
				end

			else

				self:Print("Item not queried as there is a risk of disconnect.  Please try again later.")
				return 2

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
				for i = 1, maxspells do
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

function addon:ItemScan(StartID, EndID)

	self:Print("Starting Item ID scan from ItemID: " .. StartID .. " to SpellID: " .. EndID)

	for i=StartID,EndID,1 do

		local status = self:ItemQuery(i)

		if (status == 1) then

			self:ItemQuery(i)

		elseif (status == 2) then

			self:Print("Stopping automated item scan because of disconnect issues.")
			break

		end

	end

end

function addon:SpellScan(StartID, EndID)

	self:Print("Starting Spell ID scan from SpellID: " .. StartID .. " to SpellID: " .. EndID)

	for i=StartID,EndID,1 do

		self:SpellQuery(i)

	end

end
