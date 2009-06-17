--[[

************************************************************************

Querier.lua

File date: @file-date-iso@ 
Project version: @project-version@

Author: Ackis on Thunderlord US Horde

************************************************************************

Please see Wowace.com for more information.

************************************************************************

--]]

local MODNAME = "Querier"

Querier = LibStub("AceAddon-3.0"):NewAddon(MODNAME, "AceConsole-3.0")

local addon = LibStub("AceAddon-3.0"):GetAddon(MODNAME)
local L	= LibStub("AceLocale-3.0"):GetLocale(MODNAME)

local tonumber = tonumber
local GetItemInfo = GetItemInfo
local GetSpellLink = GetSpellLink
local GetTime = GetTime
local maxspells = 60000

-- Time between queries to reset list
local TimeQuery = 300

-- Addon version
local addonversion = GetAddOnMetadata(MODNAME, "Version")

-- Max number of queries to allow during time period
local MaxQuery = 10

local function giveOptions()

	local options = { 
		type='group',
		args = {
			header1 =
			{
				order = 1,
				type = "header",
				name = "",
			},
			version =
			{
				order = 2,
				type = "description",
				name = "Version " .. addonversion .. "\n",
			},
			about =
			{
				order = 3,
				type = "description",
				name = "A simple slash-command-based addon for querying item information from the Blizzard servers via ItemIDs and SpellIDs.\n\nCommand line shortcuts are provided beside the name.\n",
			},
			header2 =
			{
				order = 4,
				type = "header",
				name = "",
			},
			itemdesc =
			{
				order = 10,
				type = "description",
				name = "To perform an item scan, enter the start ID followed by the end ID and click ok (ie: 500 1000).\n",
			},
			ItemQuery = {
				type = "input",
				name = "Item Query (/iq)",
				desc = "Queries the server and provides an item link.",
				get = false,
				set = function(info, v) Querier:ItemQuery(v) end,
				order = 11,
			},
			ItemScan = {
				type = "input",
				name = "Item Scan (/is)",
				desc = "Scans the server and provides an item links from first input to second input.",
				get = false,
				set = function(info, v) Querier:ItemScan(v) end,
				order = 15,
			},
			ResetItem = {
				type = "execute",
				name = "Reset Item Lock",
				desc = "Resets the item lock when querying items.",
				set = function() Querier:ResetItemLock() end,
				order = 16,
			},
			header3 =
			{
				order = 20,
				type = "header",
				name = "",
			},
			spelldesc =
			{
				order = 21,
				type = "description",
				name = "To perform a spell scan, enter the start ID followed by the end ID and click ok (ie: 500 1000).\n",
			},
			SpellQuery = {
				type = "input",
				name = "Spell Query (/sq)",
				desc = "Queries the server and provides an spell link.",
				get = false,
				set = function(info, v) Querier:SpellQuery(v) end,
				order = 30,
			},
			SpellScan = {
				type = "input",
				name = "Spell Scan (/ss)",
				desc = "Scans the server and provides an spell links from first input to second input.",
				get = false,
				set = function(info, v) Querier:SpellScan(v) end,
				order = 35,
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
	self:RegisterChatCommand("querier", "SlashHandler")
	self:RegisterChatCommand("iq", "ItemQuery")
	self:RegisterChatCommand("sq", "SpellQuery")
	self:RegisterChatCommand("is", "ItemScan")
	self:RegisterChatCommand("ss", "SpellScan")
	self:RegisterChatCommand("safequery", "SafeQuery")

end

function addon:SlashHandler(input)

	local lower = string.lower(input)

	if (not lower) or (lower and lower:trim() == "") then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	elseif (input == "about") then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame["About"])
	else
		self:Print(L["Unknown option."])
	end

end

do

	local lastitem = nil
	local lastquery = nil
	local totalquery = 0

	--- Queries the WoW server for a specific [[http://www.wowwiki.com/ItemLink | Item ID]].
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

	function addon:ResetItemLock()

		self:Print("Reseting item lockout.  You may still have a chance to be disconnected.")
		lastitem = nil
		lastquery = nil
		totalquery = nil

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

function addon:ItemScan(args)

	local StartID, EndID = string.match(args, "([a-z0-9]+)[ ]?(.*)")

	if (not StartID) or (not tonumber(StartID)) or (not EndID) or (not tonumber(EndID)) then

		self:Print("Please enter a valid start and end ID.")
		return

	end

	if (StartID > EndID) then

		self:Print("The end ID must be greater than the starting ID. Moron.")
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

		self:Print("The end ID must be greater than the starting ID. Moron.")
		return

	end

	self:Print("Starting Spell ID scan from SpellID: " .. StartID .. " to SpellID: " .. EndID)

	for i=StartID,EndID,1 do

		self:SpellQuery(i)

	end

end

do

	-- Table containing all "safe" items which can be auto queried.
	local t = {

		-- Ashtongue
		32444,
		32442,
		32436,
		32435,
		32430,
		32429,
		32440,
		32438,
		32443,
		32441,
		32433,
		32434,
		32431,
		32432,
		32447,
		32439,
		32437,
		32486,
		32487,
		32488,
		32489,
		32490,
		32492,
		32491,
		32493,
		32485,
		--Cenarion Expedition
		25737,
		24417,
		23814,
		24429,
		25838,
		25836,
		25835,
		25735,
		25736,
		29194,
		25869,
		32070,
		23618,
		28632,
		25526,
		29720,
		30623,
		31392,
		31391,
		29174,
		29173,
		31949,
		24183,
		29192,
		22918,
		28271,
		29170,
		29172,
		29171,
		33999,
		31390,
		31402,
		33149,
		31356,
		22922,
		29721,
		31804,
		-- Honor Hold
		29213,
		23142,
		22531,
		24007,
		24008,
		25826,
		25825,
		29214,
		29215,
		29196,
		25870,
		22905,
		29719,
		30622,
		29169,
		29166,
		32883,
		24180,
		29189,
		22547,
		34218,
		29153,
		29156,
		29151,
		33150,
		23619,
		29722,
		23999,
		-- KoT
		29198,
		28272,
		22536,
		25910,
		33160,
		29713,
		30635,
		29184,
		29185,
		24181,
		24174,
		29186,
		33158,
		29183,
		29181,
		29182,
		33152,
		31355,
		31777,
		--Kurenai
		29217,
		29144,
		29219,
		34175,
		34173,
		30444,
		29148,
		29142,
		29146,
		29218,
		30443,
		29227,
		29229,
		29230,
		29231,
		31830,
		31832,
		31834,
		31836,
		29140,
		29136,
		29138,
		31774,
		--- Lower City ---
		23138,
		30836,
		30835,
		30841,
		24179,
		24175,
		30846,
		22910,
		33157,
		34200,
		29199,
		22538,
		30833,
		30633,
		30834,
		30832,
		30830,
		33148,
		31357,
		31778,
		--Netherwing
		32694,
		32695,
		32863,
		32864,
		32858,
		32859,
		32857,
		32860,
		32861,
		32862,
		--Ogri'la
		32910,
		32909,
		32784,
		32783,
		32572,
		32653,
		32654,
		32652,
		32650,
		32647,
		32648,
		32651,
		32645,
		32828,
		32569,
		--Sha'tari Skyguard ---
		32722,
		32721,
		32539,
		32538,
		32770,
		32771,
		32319,
		32314,
		32317,
		32316,
		32318,
		38628,
		32445,
		--Shattered Sun Offensive
		35244,
		35245,
		35255,
		35246,
		35256,
		35262,
		35248,
		35260,
		35263,
		35264,
		35249,
		35250,
		35261,
		34780,
		35238,
		35251,
		35266,
		35239,
		35240,
		35253,
		35268,
		35269,
		35254,
		34872,
		35500,
		35769,
		35768,
		35767,
		35766,
		34665,
		34667,
		34672,
		34666,
		34671,
		34670,
		34673,
		34674,
		29193,
		35252,
		35697,
		35695,
		35696,
		35699,
		35698,
		35259,
		35241,
		35271,
		35505,
		35502,
		35708,
		34678,
		34679,
		34680,
		34677,
		34676,
		34675,
		35325,
		35322,
		35323,
		35221,
		35247,
		35257,
		35267,
		35258,
		37504,
		35242,
		35243,
		35265,
		35270,
		35755,
		35752,
		35754,
		35753,
		--Sporeggar
		27689,
		30156,
		25548,
		24539,
		25827,
		25828,
		25550,
		24245,
		29150,
		29149,
		22916,
		38229,
		34478,
		22906,
		31775,
		--The Aldor
		23149,
		23601,
		30842,
		29129,
		28881,
		28878,
		28885,
		28882,
		23145,
		23603,
		29704,
		29693,
		30843,
		24293,
		29127,
		29128,
		29130,
		24177,
		23604,
		29703,
		29691,
		25721,
		29123,
		29124,
		28886,
		28887,
		28888,
		28889,
		23602,
		29702,
		29689,
		24295,
		30844,
		31779,
		--The Consortium
		25732,
		28274,
		23146,
		23136,
		29457,
		29456,
		29118,
		25733,
		23134,
		23155,
		23150,
		22552,
		25908,
		25902,
		24314,
		29117,
		29116,
		29115,
		24178,
		25734,
		22535,
		23874,
		25903,
		33156,
		33305,
		29122,
		29119,
		29121,
		33622,
		31776,
		--The Mag'har
		25741,
		29143,
		25742,
		34174,
		34172,
		29664,
		29147,
		29141,
		29145,
		25743,
		22917,
		29102,
		29104,
		29105,
		29103,
		31829,
		31831,
		31833,
		31835,
		29139,
		29135,
		29137,
		31773,
		--The Scale of the Sands
		29298,
		29299,
		29300,
		29301,
		29294,
		29295,
		29296,
		29297,
		29302,
		29303,
		29304,
		29305,
		29307,
		29306,
		29308,
		29309,
		32274,
		32283,
		32277,
		32282,
		32284,
		32281,
		32288,
		32286,
		32287,
		32290,
		32293,
		32291,
		32294,
		35763,
		32306,
		32305,
		32304,
		35762,
		32299,
		32301,
		32300,
		32311,
		35765,
		32312,
		32310,
		35764,
		31737,
		31735,
		32292,
		32308,
		32309,
		32302,
		--The Scryers
		23133,
		23597,
		28907,
		28908,
		28904,
		28903,
		23143,
		23598,
		29701,
		29682,
		24292,
		29131,
		29134,
		29132,
		29133,
		24176,
		22908,
		23599,
		29700,
		29684,
		25722,
		29126,
		29125,
		28910,
		28911,
		28912,
		28909,
		23600,
		29698,
		29677,
		24294,
		31780,
		--The Sha'tar
		25904,
		29180,
		29179,
		24182,
		29191,
		22915,
		28281,
		13517,
		22537,
		33159,
		30826,
		29195,
		28273,
		33155,
		29717,
		30634,
		29177,
		29175,
		29176,
		33153,
		31354,
		31781,
		--The Violet Eye
		29280,
		29281,
		29282,
		29283,
		29284,
		29285,
		29286,
		29287,
		29288,
		29289,
		29291,
		29290,
		29276,
		29277,
		29278,
		29279,
		31113,
		31395,
		31393,
		31401,
		29187,
		33209,
		34581,
		34582,
		31394,
		33205,
		33124,
		33165,
		--Thrallmar
		25738,
		31359,
		24000,
		24006,
		24009,
		25824,
		25823,
		25739,
		25740,
		29197,
		29232,
		24001,
		31361,
		30637,
		29168,
		29167,
		32882,
		31358,
		29190,
		24003,
		34201,
		29155,
		29165,
		29152,
		33151,
		24002,
		31362,
		24004,
	}

	function addon:SafeQuery()
		for i in pairs(t) do
			GameTooltip:SetHyperlink("item:"..i..":0:0:0:0:0:0:0")
		end
	end

end
