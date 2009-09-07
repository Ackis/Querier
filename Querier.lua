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
	self:RegisterChatCommand("iqr", "ResetItemLock")
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

	--- Resets the lock on querying to allow you to bypass the safeguards in place.
	-- @name Querier:ResetItemLock
	-- @usage Querier:ResetItemLock()
	function addon:ResetItemLock()
		self:Print("Reseting item lockout.  You may still have a chance to be disconnected.")
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

		-- Original Reps
		-- Argent Dawn
		22689,		22690,		22681,		22680,		22688,		22679,
		22638,		22523,		22667,		22668,		22657,		22659,
		22678,		22656,		22636,		22524,		13724,		13482,
		19203,		19446,		19442,		19328,		19216,		12844,
		18171,		18169,		18170,		18172,		18173,		19205,
		19447,		19329,		19217,		13810,		13813,		18182,
		--Bloodsail Buccaneers & Hydraxian Waterlords
		22742,		22743,		22745,		22744,		12185,		18399,
		18398,		17333,		22754,
		--Brood of Nozdormu
		21201,		21202,		21203,		21204,		21205,		21206,
		21207,		21208,		21209,		21210,		21196,		21197,
		21198,		21199,		21200,
		--Cenarion Circle
		22209,		22768,		20732,		22769,		20509,		20506,
		22772,		22310,		20802,		20800,		21515,		21187,
		21178,		21179,		20801,		21508,		22767,		22214,
		20733,		22770,		20510,		20507,		22773,		21183,
		21182,		21181,		22766,		22219,		22771,		20511,
		20508,		22683,		22312,		22774,		21186,		21184,
		21189,		21185,		22221,		20382,		21190,		21180,
		21188,

		--Stormpike Guard & Frostwolf Clan
		17904,		17903,		17902,		17901,		17900,		17691,
		20648,		19106,		19108,		19107,		17909,		17908,
		17907,		17906,		17905,		17690,
		--Thorium Brotherhood
		17051,		20761,		19444,		17023,		17022,		17018,
		17060,		17059,		17049,		19206,		19448,		17025,
		19330,		17017,		19219,		18592,		17052,		17053,
		19209,		19208,		19207,		19449,		19331,		19332,
		19333,		19220,		19211,		20040,		19210,		19212,
		--Timbermaw Hold
		13484,		22392,		20254,		20253,		16768,		16769,
		19202,		19445,		19326,		19215,		19204,		19327,
		19218,		21326,
		-- Zandalar Tribe
		20012,		19778,		19781,		20757,		20001,		19771,
		19766,		19858,		20014,		19777,		19780,		20756,
		20000,		19773,		19770,		19765,		20031,		20080,
		20079,		20081,		20011,		19776,		19779,		19772,
		19769,		19764,		20077,		20076,		20078,		20013,

		-- BC Reps
		-- Ashtongue
		32444,		32442,		32436,		32435,		32430,		32429,
		32440,		32438,		32443,		32441,		32433,		32434,
		32431,		32432,		32447,		32439,		32437,		32486,
		32487,		32488,		32489,		32490,		32492,		32491,
		32493,		32485,
		--Cenarion Expedition
		25737,		24417,		23814,		24429,		25838,		25836,
		25835,		25735,		25736,		29194,		25869,		32070,
		23618,		28632,		25526,		29720,		30623,		31392,
		31391,		29174,		29173,		31949,		24183,		29192,
		22918,		28271,		29170,		29172,		29171,		33999,
		31390,		31402,		33149,		31356,		22922,		29721,
		31804,
		-- Honor Hold
		29213,		23142,		22531,		24007,		24008,		25826,
		25825,		29214,		29215,		29196,		25870,		22905,
		29719,		30622,		29169,		29166,		32883,		24180,
		29189,		22547,		34218,		29153,		29156,		29151,
		33150,		23619,		29722,		23999,
		-- KoT
		29198,		28272,		22536,		25910,		33160,		29713,
		30635,		29184,		29185,		24181,		24174,		29186,
		33158,		29183,		29181,		29182,		33152,		31355,
		31777,
		--Kurenai
		29217,		29144,		29219,		34175,		34173,		30444,
		29148,		29142,		29146,		29218,		30443,		29227,
		29229,		29230,		29231,		31830,		31832,		31834,
		31836,		29140,		29136,		29138,		31774,
		--- Lower City ---
		23138,		30836,		30835,		30841,		24179,		24175,
		30846,		22910,		33157,		34200,		29199,		22538,
		30833,		30633,		30834,		30832,		30830,		33148,
		31357,		31778,
		--Netherwing
		32694,		32695,		32863,		32864,		32858,		32859,
		32857,		32860,		32861,		32862,
		--Ogri'la
		32910,		32909,		32784,		32783,		32572,		32653,
		32654,		32652,		32650,		32647,		32648,		32651,
		32645,		32828,		32569,
		--Sha'tari Skyguard ---
		32722,		32721,		32539,		32538,		32770,		32771,
		32319,		32314,		32317,		32316,		32318,		38628,
		32445,
		--Shattered Sun Offensive
		35244,		35245,		35255,		35246,		35256,		35262,
		35248,		35260,		35263,		35264,		35249,		35250,
		35261,		34780,		35238,		35251,		35266,		35239,
		35240,		35253,		35268,		35269,		35254,		34872,
		35500,		35769,		35768,		35767,		35766,		34665,
		34667,		34672,		34666,		34671,		34670,		34673,
		34674,		29193,		35252,		35697,		35695,		35696,
		35699,		35698,		35259,		35241,		35271,		35505,
		35502,		35708,		34678,		34679,		34680,		34677,
		34676,		34675,		35325,		35322,		35323,		35221,
		35247,		35257,		35267,		35258,		37504,		35242,
		35243,		35265,		35270,		35755,		35752,		35754,
		35753,
		--Sporeggar
		27689,		30156,		25548,		24539,		25827,		25828,
		25550,		24245,		29150,		29149,		22916,		38229,
		34478,		22906,		31775,
		--The Aldor
		23149,		23601,		30842,		29129,		28881,		28878,
		28885,		28882,		23145,		23603,		29704,		29693,
		30843,		24293,		29127,		29128,		29130,		24177,
		23604,		29703,		29691,		25721,		29123,		29124,
		28886,		28887,		28888,		28889,		23602,		29702,
		29689,		24295,		30844,		31779,
		--The Consortium
		25732,		28274,		23146,		23136,		29457,		29456,
		29118,		25733,		23134,		23155,		23150,		22552,
		25908,		25902,		24314,		29117,		29116,		29115,
		24178,		25734,		22535,		23874,		25903,		33156,
		33305,		29122,		29119,		29121,		33622,		31776,
		--The Mag'har
		25741,		29143,		25742,		34174,		34172,		29664,
		29147,		29141,		29145,		25743,		22917,		29102,
		29104,		29105,		29103,		31829,		31831,		31833,
		31835,		29139,		29135,		29137,		31773,
		--The Scale of the Sands
		29298,		29299,		29300,		29301,		29294,		29295,
		29296,		29297,		29302,		29303,		29304,		29305,
		29307,		29306,		29308,		29309,		32274,		32283,
		32277,		32282,		32284,		32281,		32288,		32286,
		32287,		32290,		32293,		32291,		32294,		35763,
		32306,		32305,		32304,		35762,		32299,		32301,
		32300,		32311,		35765,		32312,		32310,		35764,
		31737,		31735,		32292,		32308,		32309,		32302,
		--The Scryers
		23133,		23597,		28907,		28908,		28904,		28903,
		23143,		23598,		29701,		29682,		24292,		29131,
		29134,		29132,		29133,		24176,		22908,		23599,
		29700,		29684,		25722,		29126,		29125,		28910,
		28911,		28912,		28909,		23600,		29698,		29677,
		24294,		31780,
		--The Sha'tar
		25904,		29180,		29179,		24182,		29191,		22915,
		28281,		13517,		22537,		33159,		30826,		29195,
		28273,		33155,		29717,		30634,		29177,		29175,
		29176,		33153,		31354,		31781,
		--The Violet Eye
		29280,		29281,		29282,		29283,		29284,		29285,
		29286,		29287,		29288,		29289,		29291,		29290,
		29276,		29277,		29278,		29279,		31113,		31395,
		31393,		31401,		29187,		33209,		34581,		34582,
		31394,		33205,		33124,		33165,
		--Thrallmar
		25738,		31359,		24000,		24006,		24009,		25824,
		25823,		25739,		25740,		29197,		29232,		24001,
		31361,		30637,		29168,		29167,		32882,		31358,
		29190,		24003,		34201,		29155,		29165,		29152,
		33151,		24002,		31362,		24004,
		-- WotLK Reps
		--Alliance Vanguard
		38459,		38465,		38455,		38463,		38453,		38457,
		38464,		44503,		44937,		44701,
		--Argent Crusade
		43154,		44248,		44247,		44244,		44245,		44214,
		41726,		44150,		44216,		44240,		44239,		44139,
		44297,		44295,		44296,		44283,		42187,
		--Frenzyheart Tribe
		41561,		44064,		44072,		44719,		39671,		40067,
		40087,		44716,		44116,		44117,		44122,		44120,
		44121,		44123,		44118,		41723,		44717,		44073,
		--The Horde Expedition
		38458,		38461,		38454,		38452,		38462,		38456,
		38460,		44502,		44938,		44702,
		--Kirin Tor
		43157,		44167,		44170,		44171,		44166,		44141,
		44179,		44176,		44173,		44174,		44159,		44180,
		44181,		44182,		44183,		41718,		42188,
		--Knights of the Ebon Blade
		41562,		43155,		44242,		44243,		44241,		44512,
		44138,		44256,		44258,		44257,		44250,		44249,
		41721,		44149,		42183,		44302,		44303,		44305,
		44306,
		--The Kalu'ak
		41568,		44049,		44061,		44062,		44054,		44055,
		44059,		44060,		44057,		44058,		44511,		41574,
		44051,		44052,		44053,		44509,		45774,		44050,
		44723,
		--The Oracles
		41567,		44065,		44071,		44707,		39898,		44721,
		39896,		39899,		44722,		44104,		44106,		44110,
		44109,		44112,		44111,		44108,		41724,		39878,
		44074,
		--The Sons of Hodir
		44190,		44189,		44510,		44137,		44131,		44130,
		44132,		44129,		43958,		44080,		44194,		44195,
		44193,		44192,		43961,		44086,		44133,		44134,
		44136,		44135,		41720,		42184,
		--Winterfin Retreat
		36784,		37462,		37463,		37461,		36783,		37464,
		37449,		38351,		38350,		17058,		17057,		34597,
		--The Wyrmrest Accord
		43156,		44188,		44196,		44197,		44187,		44140,
		44200,		44198,		44201,		44199,		44152,		42185,
		44202,		44203,		44204,		44205,		43955,		41722,
		-- First Aid Recipes
		6454,		39152,		21992,		21993,
		-- Cooking Recipes
		2698,		2700,		27686,		5482,		3736,		3737,
		27684,		21025,		2889,		2697,		5486,		3679,
		22647,		18160,		728,		3678,		5487,		44977,
		3680,		2699,		2701,		3734,		3683,		3681,
		3735,		3682,		31674,		31675,		4609,		6325,
		12226,		17200,		27685,		6326,		5483,		17201,
		5484,		6892,		27687,		5485,		6329,		6328,
		6368,		21099,		5528,		6330,		5488,		5489,
		12227,		20075,		6369,		12232,		6039,		12229,
		12231,		17062,		12233,		12228,		21219,		12239,
		12240,		13940,		13941,		16110,		16111,		13939,
		18046,		16767,		13942,		13943,		35564,		35566,
		13945,		13946,		13949,		13947,		13948,		27694,
		30156,		27695,		27688,		27696,		27689,		27690,
		27697,
		--Blacksmithing
		 47645,
		 10424,
		 22214,
		 23635,
		 47643,
		 6046,
		 12699,
		 6735,
		 47642,
		 19776,
		 23594,
		 23605,
		 22220,
		 23636,
		 22388,
		 17052,
		 7984,
		 7991,
		 19777,
		 12836,
		 3611,
		 3612,
		 22390,
		 12700,
		 19778,
		 12837,
		 23607,
		 12162,
		 12701,
		 12163,
		 3870,
		 19779,
		 12838,
		 23596,
		 23621,
		 19202,
		 6044,
		 12702,
		 33792,
		 32441,
		 19780,
		 12839,
		 30321,
		 2881,
		 5578,
		 35208,
		 32442,
		 19204,
		 12698,
		 30322,
		 12711,
		 7985,
		 5543,
		 32443,
		 19781,
		 30323,
		 23597,
		 23618,
		 23628,
		 32444,
		 12685,
		 12703,
		 30324,
		 12720,
		 17060,
		 35211,
		 12687,
		 12714,
		 12725,
		 7995,
		 7983,
		 8028,
		 31390,
		 20040,
		 11610,
		 23599,
		 23611,
		 23620,
		 19203,
		 12688,
		 12705,
		 12827,
		 31391,
		 33954,
		 23612,
		 19205,
		 12706,
		 31392,
		 20553,
		 12726,
		 28632,
		 2883,
		 6047,
		 23637,
		 31393,
		 12728,
		 17049,
		 3610,
		 22221,
		 3871,
		 35210,
		 19210,
		 12716,
		 7976,
		 12690,
		 12707,
		 31394,
		 20555,
		 12727,
		 23591,
		 12819,
		 12830,
		 35531,
		 12825,
		 31395,
		 22767,
		 23600,
		 23609,
		 23613,
		 23630,
		 23629,
		 23608,
		 11615,
		 35532,
		 7978,
		 12261,
		 17059,
		 19211,
		 20554,
		 3875,
		 7992,
		 22389,
		 12821,
		 11614,
		 35529,
		 23606,
		 22768,
		 23590,
		 44938,
		 23601,
		 23610,
		 7981,
		 22766,
		 23631,
		 23598,
		 10858,
		 7975,
		 19206,
		 35530,
		 12715,
		 12834,
		 7980,
		 18264,
		 41120,
		 12692,
		 12696,
		 7979,
		 12717,
		 12718,
		 41124,
		 23625,
		 3866,
		 35296,
		 12823,
		 35553,
		 23623,
		 23622,
		 12835,
		 41123,
		 23602,
		 22209,
		 23632,
		 19207,
		 19212,
		 7982,
		 12719,
		 7989,
		 25526,
		 41122,
		 23603,
		 22219,
		 23615,
		 23633,
		 19208,
		 17053,
		 12824,
		 18592,
		 9367,
		 23604,
		 22222,
		 23617,
		 23634,
		 23639,
		 19209,
		 47460,
		 12695,
		 17051,
		 17706,
		 47641,
		 8029,
		 8030,
		 47644,
		--LEATHERWORKING
		 19327,
		 44584,
		 18514,
		 8385,
		 8395,
		 8397,
		 15729,
		 44511,
		 15775,
		 25736,
		 30301,
		 44585,
		 35546,
		 19328,
		 44586,
		 18515,
		 35541,
		 19769,
		 15730,
		 15760,
		 15776,
		 44538,
		 25737,
		 30302,
		 44587,
		 29669,
		 7452,
		 35214,
		 19329,
		 30303,
		 44588,
		 29672,
		 32429,
		 19770,
		 15731,
		 15744,
		 15777,
		 25726,
		 30304,
		 29673,
		 34262,
		 35216,
		 19330,
		 44539,
		 44589,
		 29674,
		 29720,
		 35217,
		 19771,
		 15745,
		 15762,
		 44521,
		 7290,
		 29214,
		 30305,
		 29675,
		 7453,
		 35218,
		 19331,
		 44522,
		 44541,
		 29677,
		 29721,
		 35549,
		 19772,
		 15763,
		 44542,
		 29215,
		 30306,
		 22771,
		 29682,
		 29723,
		 34491,
		 19332,
		 44523,
		 44543,
		 30307,
		 29684,
		 35302,
		 7613,
		 14635,
		 32433,
		 19773,
		 15764,
		 44544,
		 25728,
		 29217,
		 22770,
		 29691,
		 29725,
		 32434,
		 19333,
		 44524,
		 44545,
		 6710,
		 29689,
		 34218,
		 18518,
		 44509,
		 32435,
		 8404,
		 15748,
		 15765,
		 15781,
		 44525,
		 29219,
		 22769,
		 30444,
		 35303,
		 44510,
		 6474,
		 35523,
		 44546,
		 20506,
		 29693,
		 15768,
		 44526,
		 44547,
		 25729,
		 29218,
		 7361,
		 29698,
		 29729,
		 7451,
		 13288,
		 44548,
		 20507,
		 29700,
		 5083,
		 8403,
		 15769,
		 44527,
		 44549,
		 25731,
		 32430,
		 2408,
		 35517,
		 44550,
		 20508,
		 29702,
		 29730,
		 35524,
		 25721,
		 25730,
		 29703,
		 35300,
		 35520,
		 5787,
		 44530,
		 20509,
		 17022,
		 8384,
		 8405,
		 35521,
		 15771,
		 44513,
		 44531,
		 44559,
		 25722,
		 29713,
		 33205,
		 6475,
		 44532,
		 20510,
		 34175,
		 15724,
		 15738,
		 20254,
		 44533,
		 44560,
		 7363,
		 29732,
		 44534,
		 20511,
		 17025,
		 8387,
		 15725,
		 44561,
		 15755,
		 18252,
		 35527,
		 8406,
		 15739,
		 44514,
		 44535,
		 8408,
		 44512,
		 4294,
		 4296,
		 4298,
		 4301,
		 44528,
		 44551,
		 44519,
		 20576,
		 44933,
		 15753,
		 15726,
		 15756,
		 15773,
		 44515,
		 44536,
		 25725,
		 29726,
		 17023,
		 7364,
		 34173,
		 44520,
		 44552,
		 15751,
		 15749,
		 32431,
		 15740,
		 44516,
		 18239,
		 44562,
		 29704,
		 44553,
		 33124,
		 32432,
		 18516,
		 20382,
		 8409,
		 29734,
		 8407,
		 15732,
		 44517,
		 44537,
		 44540,
		 18949,
		 5973,
		 20253,
		 15758,
		 35215,
		 43097,
		 29213,
		 19326,
		 44518,
		 44563,
		 35519,
		 4297,
		 32436,
		 15759,
		 29701,
		 29728,
		 15735,
		 18731,
		 35301,
		 35528,
		 13287,
		 15728,
		 15774,
		 7289,
		 25735,
		 44932,
		 --JEWELCRAFTING
		 41784,
		 41818,
		 35266,
		 20976,
		 24211,
		 41797,
		 24215,
		 21955,
		 24162,
		 41747,
		 41795,
		 35244,
		 35270,
		 41723,
		 42300,
		 35271,
		 41711,
		 41724,
		 35262,
		 24209,
		 41694,
		 31870,
		 41574,
		 24163,
		 41725,
		 41698,
		 35252,
		 42309,
		 32411,
		 25902,
		 41709,
		 31875,
		 41697,
		 42303,
		 35254,
		 25903,
		 23151,
		 24220,
		 24193,
		 43597,
		 20854,
		 41701,
		 24214,
		 42304,
		 35251,
		 24204,
		 43497,
		 23141,
		 37504,
		 35695,
		 35250,
		 35253,
		 21940,
		 25906,
		 41707,
		 31871,
		 35696,
		 41693,
		 42305,
		 23140,
		 35697,
		 41796,
		 41699,
		 23152,
		 20970,
		 25907,
		 42648,
		 23130,
		 24165,
		 35698,
		 41703,
		 42298,
		 42306,
		 24166,
		 24183,
		 25909,
		 42649,
		 24195,
		 35306,
		 20855,
		 41820,
		 35247,
		 35304,
		 24203,
		 24206,
		 42650,
		 24208,
		 24212,
		 23147,
		 21952,
		 41562,
		 24174,
		 41702,
		 42307,
		 25910,
		 24213,
		 42651,
		 24216,
		 33160,
		 41726,
		 42301,
		 42308,
		 20971,
		 23137,
		 42652,
		 28596,
		 23131,
		 21941,
		 23153,
		 42310,
		 24171,
		 35246,
		 35248,
		 35245,
		 42653,
		 35249,
		 35263,
		 31877,
		 35264,
		 31401,
		 35265,
		 42299,
		 42311,
		 35259,
		 35243,
		 35242,
		 35239,
		 35241,
		 35269,
		 35268,
		 23133,
		 23148,
		 31876,
		 35305,
		 31402,
		 24176,
		 42314,
		 42312,
		 35267,
		 33158,
		 34689,
		 35708,
		 41705,
		 35260,
		 41718,
		 42302,
		 42313,
		 41577,
		 35255,
		 41687,
		 33783,
		 24177,
		 24181,
		 41794,
		 41692,
		 42315,
		 41696,
		 35238,
		 35768,
		 43320,
		 35322,
		 31873,
		 41719,
		 41582,
		 41819,
		 35256,
		 35323,
		 24173,
		 24172,
		 23143,
		 31874,
		 41561,
		 41567,
		 41578,
		 35307,
		 35261,
		 35699,
		 35325,
		 35502,
		 41817,
		 41792,
		 35258,
		 41704,
		 41790,
		 41689,
		 35257,
		 31878,
		 42138,
		 41686,
		 20973,
		 43485,
		 23135,
		 21947,
		 41568,
		 41688,
		 41706,
		 28291,
		 35505,
		 41581,
		 35198,
		 23145,
		 24158,
		 41690,
		 41793,
		 24200,
		 35538,
		 41721,
		 35240,
		 35200,
		 21944,
		 23149,
		 21956,
		 24159,
		 24168,
		 41720,
		 35201,
		 41708,
		 41576,
		 41580,
		 35769,
		 35533,
		 41798,
		 24160,
		 24169,
		 41791,
		 24210,
		 43317,
		 35766,
		 35535,
		 43318,
		 35767,
		 24161,
		 24170,
		 41579,
		 41722,
		 43319,
		 41710,
		 --TAILORING
		 14514,
		 35548,
		 19216,
		 21917,
		 24295,
		 24301,
		 34261,
		 44916,
		 20548,
		 14483,
		 5771,
		 7089,
		 21892,
		 21919,
		 35308,
		 35309,
		 22774,
		 18415,
		 45774,
		 22307,
		 10311,
		 10317,
		 19219,
		 42183,
		 24308,
		 30280,
		 6390,
		 22773,
		 18416,
		 17017,
		 42184,
		 14468,
		 14477,
		 14485,
		 30281,
		 22308,
		 22683,
		 32438,
		 19220,
		 21904,
		 21915,
		 24309,
		 20547,
		 30282,
		 30842,
		 4292,
		 21895,
		 5773,
		 22772,
		 18417,
		 17018,
		 21913,
		 14497,
		 38327,
		 4351,
		 7087,
		 14478,
		 21371,
		 21914,
		 14500,
		 22309,
		 19764,
		 10318,
		 21893,
		 42185,
		 21894,
		 24316,
		 21905,
		 30483,
		 21912,
		 21911,
		 32439,
		 37915,
		 21916,
		 44917,
		 32440,
		 24310,
		 18418,
		 18487,
		 42172,
		 21903,
		 14479,
		 14510,
		 19765,
		 22312,
		 5774,
		 7090,
		 42173,
		 6401,
		 4354,
		 10728,
		 24292,
		 18265,
		 24311,
		 32447,
		 21910,
		 14493,
		 21909,
		 14511,
		 14486,
		 35525,
		 21908,
		 42187,
		 17724,
		 30844,
		 14480,
		 14507,
		 30843,
		 19766,
		 10315,
		 19215,
		 42175,
		 21907,
		 2601,
		 32437,
		 24293,
		 35526,
		 24312,
		 35522,
		 24306,
		 38328,
		 35204,
		 42177,
		 42188,
		 14495,
		 14513,
		 21358,
		 35544,
		 4353,
		 19218,
		 42176,
		 21918,
		 14627,
		 24294,
		 24305,
		 24313,
		 30283,
		 21906,
		 10325,
		 14509,
		 35206,
		 20546,
		 19217,
		 22310,
		 10314,
		 10300,
		 14473,
		 34319,
		 14505,
	}

	function addon:SafeQuery()
		local count = 0
		for i,j in pairs(t) do
			if (count > 500) then
				self:Print("Queried 500 items.  Breaking now to let the server catch up.  Please use the command again in a few moments.")
				break
			end
			local item = GetItemInfo(j)
			if (not item) then
				self:Print("Item not in cache: " .. j)
				GameTooltip:SetHyperlink("item:"..j..":0:0:0:0:0:0:0")
				count = count + 1
			end
		end
	end

end
