-------------------------------------------------------------------------------
-- Querier.lua
-------------------------------------------------------------------------------
-- File date: @file-date-iso@
-- Project version: @project-version@
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local _G = getfenv(0)

local string = _G.string

local pairs = _G.pairs

local tonumber = _G.tonumber
local tostring = _G.tostring

-------------------------------------------------------------------------------
-- Localized Blizzard API.
-------------------------------------------------------------------------------
local GetItemInfo	= _G.GetItemInfo
local GetSpellInfo	= _G.GetSpellInfo
local GetSpellLink	= _G.GetSpellLink
local GetTime		= _G.GetTime

-------------------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------------------
local MODNAME, private = ...

local LibStub	= _G.LibStub
local addon	= LibStub("AceAddon-3.0"):NewAddon(MODNAME, "AceConsole-3.0")
local L		= LibStub("AceLocale-3.0"):GetLocale(MODNAME)

_G[MODNAME]	= addon

------------------------------------------------------------------------------
-- Constants.
------------------------------------------------------------------------------
local VERSION		= GetAddOnMetadata(MODNAME, "Version")
local MAX_SPELLS	= 60000
local QUERY_DELAY	= 300		-- Time between queries to reset list
local MAX_QUERIES	= 10		-- Max number of queries to allow during time period
local MAX_SAFEQUERIES	= 500

local options = {
	type='group',
	args = {
		header1 = {
			order = 1,
			type = "header",
			name = "",
		},
		version = {
			order = 2,
			type = "description",
			name = "Version " .. VERSION .. "\n",
		},
		about =	{
			order = 3,
			type = "description",
			name = "A simple slash-command-based addon for querying item information from the Blizzard servers via ItemIDs and SpellIDs.\n\nCommand line shortcuts are provided beside the name.\n",
		},
		header2 = {
			order = 4,
			type = "header",
			name = "",
		},
		itemdesc = {
			order = 10,
			type = "description",
			name = "To perform an item scan, enter the start ID followed by the end ID and click Okay (ie: 500 1000).\n",
		},
		ItemQuery = {
			type = "input",
			name = "Item Query (/iq)",
			desc = "Queries the server and provides an item link.",
			get = false,
			set = function(info, v) addon:ItemQuery(v) end,
			order = 11,
		},
		ResetItem = {
			type = "execute",
			name = "Reset Item Lock",
			desc = "Resets the item lock when querying items.",
			set = function() addon:ResetItemLock() end,
			order = 16,
		},
		header3 = {
			order = 20,
			type = "header",
			name = "",
		},
		spelldesc = {
			order = 21,
			type = "description",
			name = "To perform a spell scan, enter the start ID followed by the end ID and click Okay (ie: 500 1000).\n",
		},
		SpellQuery = {
			type = "input",
			name = "Spell Query (/sq)",
			desc = "Queries the server and provides a spell link.",
			get = false,
			set = function(info, v) addon:SpellQuery(v) end,
			order = 30,
		},
		header4 = {
			order = 40,
			type = "header",
			name = "Safe Queries",
		},
		safe_query_alchemy = {
			type = "execute",
			name = "Alchemy",
			desc = "Scans all Alchemy items which have been deemed as safe.",
			func = function() addon:SafeQuery("alchemy") end,
			order = 41,
		},
		safe_query_blacksmithing = {
			type = "execute",
			name = "Blacksmithing",
			desc = "Scans all Blacksmithing items which have been deemed as safe.",
			func = function() addon:SafeQuery("blacksmithing") end,
			order = 42,
		},
		safe_query_cooking = {
			type = "execute",
			name = "Cooking",
			desc = "Scans all Cooking items which have been deemed as safe.",
			func = function() addon:SafeQuery("cooking") end,
			order = 43,
		},
		safe_query_enchanting = {
			type = "execute",
			name = "Enchanting",
			desc = "Scans all Enchanting items which have been deemed as safe.",
			func = function() addon:SafeQuery("enchanting") end,
			order = 44,
		},
		safe_query_engineering = {
			type = "execute",
			name = "Engineering",
			desc = "Scans all Engineering items which have been deemed as safe.",
			func = function() addon:SafeQuery("engineering") end,
			order = 45,
		},
		safe_query_firstaid = {
			type = "execute",
			name = "First Aid",
			desc = "Scans all First Aid items which have been deemed as safe.",
			func = function() addon:SafeQuery("firstaid") end,
			order = 46,
		},
		safe_query_jewelcrafting = {
			type = "execute",
			name = "Jewelcrafting",
			desc = "Scans all Jewelcrafting items which have been deemed as safe.",
			func = function() addon:SafeQuery("jewelcrafting") end,
			order = 47,
		},
		safe_query_leatherworking = {
			type = "execute",
			name = "Leatherworking",
			desc = "Scans all Leatherworking items which have been deemed as safe.",
			func = function() addon:SafeQuery("leatherworking") end,
			order = 48,
		},
		safe_query_mounts = {
			type = "execute",
			name = "Mounts",
			desc = "Scans all Mount items which have been deemed as safe.",
			func = function() addon:SafeQuery("mount") end,
			order = 49,
		},
		safe_query_reputation = {
			type = "execute",
			name = "Reputation",
			desc = "Scans all reputation items which have been deemed as safe.",
			func = function() addon:SafeQuery("reputation") end,
			order = 50,
		},
		safe_query_tailoring = {
			type = "execute",
			name = "Tailoring",
			desc = "Scans all Tailoring items which have been deemed as safe.",
			func = function() addon:SafeQuery("tailoring") end,
			order = 51,
		},
	}
}

-------------------------------------------------------------------------------
-- Initialization functions
-------------------------------------------------------------------------------
function addon:OnInitialize()
	local AceConfig = LibStub("AceConfig-3.0")
	local AceConfigReg = LibStub("AceConfigRegistry-3.0")
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")

	AceConfig:RegisterOptionsTable("Querier", options)

	-- Create Blizzard interface options stuff
	self.optionsFrame = AceConfigDialog:AddToBlizOptions("Querier","Querier")
	self.optionsFrame["About"] = LibStub("LibAboutPanel").new("Querier", "Querier")

	-- Create slash commands
	self:RegisterChatCommand("querier", "SlashHandler")
	self:RegisterChatCommand("iq", "ItemQuery")
	self:RegisterChatCommand("iqr", "ResetItemLock")
	self:RegisterChatCommand("sq", "SpellQuery")
	self:RegisterChatCommand("is", "ItemScan")
	self:RegisterChatCommand("ss", "SpellScan")
	self:RegisterChatCommand("safequery", "SafeQuery")
end

function addon:SlashHandler(input)
	local lower = string.lower(input)

	if not lower or lower:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	elseif lower == "about" then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame["About"])
	else
		self:Print(L["Unknown option."])
	end
end

do
	local lastitem = nil
	local lastquery = nil
	local totalquery = 0

	-- Queries the WoW server for a specific [[http://www.wowwiki.com/ItemLink | Item ID]].
	-- @name Querier:ItemQuery
	-- @usage Querier:ItemQuery(3432)
	-- @param ItemID The [[http://www.wowwiki.com/ItemLink | Item ID]] of the item we are querying.
	-- @return Item is queried and output into chat.
	function addon:ItemQuery(ItemID)

		local id = tonumber(ItemID)
		-- We have a string, lets assume it's an item link
		if (not id) then
			-- New regexp thanks to Arrowmaster
			local _,_,ID = string.find(ItemID, "item:(%d+)")
			if (tonumber(ID) ~= nil) then
				self:Print("Item link: " .. ItemID .. " is item ID: " .. ID)
			else
				self:Print("Invalid input.  Must be numeric item-ID or item link.")
			end
		-- We've got a number, lets try to get the link via ID
		else
			local maxtime
			if (lastquery) then
				maxtime = lastquery + QUERY_DELAY
			else
				maxtime = 0
			end

			-- If we haven't done a query in a long time, reset the query count.
			if lastquery and (GetTime() > maxtime) then
				totalquery = 0
			end

			-- Only do the query if we haven't done too many
			if (totalquery < MAX_QUERIES) then
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

	--- Resets the lock on querying to allow you to bypass the safeguards in place.
	-- @name Querier:ResetItemLock
	-- @usage Querier:ResetItemLock()
	function addon:ResetItemLock()
		self:Print("Reseting item lockout.  You may still get disconnected.")
		lastitem = nil
		lastquery = nil
		totalquery = 0
	end

end

function addon:SpellQuery(SpellID)

	local id = tonumber(SpellID)
	if (not id) then
			local _,_,ID = string.find(SpellID, "spell:(%d+)")

			if (tonumber(ID) ~= nil) then
				self:Print("Spell link: " .. SpellID .. " is spell ID: " .. ID)
			else
				local spellName
				for i = 1, MAX_SPELLS do
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

function addon:ItemScan(args)

	local StartID, EndID = string.match(args, "([a-z0-9]+)[ ]?(.*)")

	if (not StartID) or (not tonumber(StartID)) or (not EndID) or (not tonumber(EndID)) then
		self:Print("Please enter a valid start and end ID.")
		return
	end

	if (StartID > EndID) then
		self:Print("The end ID must be greater than the starting ID.")
		return
	end

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

function addon:SpellScan(args)

	local StartID, EndID = string.match(args, "([a-z0-9]+)[ ]?(.*)")

	if (not StartID) or (not tonumber(StartID)) or (not EndID) or (not tonumber(EndID)) then
		self:Print("Please enter a valid start and end ID.")
		return
	end

	if (StartID > EndID) then
		self:Print("The end ID must be greater than the starting ID.")
		return
	end

	self:Print("Starting Spell ID scan from SpellID: " .. StartID .. " to SpellID: " .. EndID)

	for i=StartID,EndID,1 do
		self:SpellQuery(i)
	end

end

function addon:SafeQuery(input)
	local lower = input and input:lower() or nil

	if not lower then
		self:Print("You should specify a category to query.")
		return
	end
	local query_data = private[lower.."_items"]

	if not query_data then
		self:Printf("%s: No such category.", input)
		return
	else
		self:Printf("Scanning %s items.", lower)
	end
	local count = 0
	local attempts = 0

	for index, id_num in pairs(query_data) do
		if attempts > MAX_SAFEQUERIES then
			self:Printf("Queried %d items.  Breaking now to let the server catch up.  Please use the command again in a few moments.", MAX_SAFEQUERIES)
			break
		end

		local item_name, item_link = GetItemInfo(id_num)

		if not item_name then
			GameTooltip:SetHyperlink("item:"..id_num..":0:0:0:0:0:0:0")
			attempts = attempts + 1
		end
		count = count + 1
	end
	self:Printf("SafeQuery finished - %d items scanned: %d cache attempts.", count, attempts)
end
