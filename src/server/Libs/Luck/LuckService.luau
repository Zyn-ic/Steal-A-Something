--@author: yyumchi
--@date: 2025-09-03
--[[@description:
    A secure, stateless luck service that combines high-entropy seeded RNG with
    distinct luck mechanics. It supports multiple rolls, roll quality boosts,
    and additive rarity chance boosts. Works with a dictionary-based rarity pool.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Module = {}

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-- CONSTANTS --

local DEFAULT_LUCK_CAP = 8 -- Default maximum number of rolls.

-----------------------------
-- PRIVATE VARIABLES --
-----------------------------

local _rollCounter = 0

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

--[[
    Creates a high-entropy seed for the Random object by mixing multiple sources.
]]
local function _makeSeed(playerUserId: number?): number
	_rollCounter += 1
	local guid = HttpService:GenerateGUID(false)
	local digits = guid:gsub("%D", "")
	local guidPart = tonumber(digits:sub(1, 9)) or 0
	local timePart = math.floor(tick() * 1000) % 2147483647
	local counterPart = _rollCounter % 2147483647
	local playerPart = (playerUserId or 0) % 2147483647
	local seed = (
		((guidPart * 1664525) % 2147483647)
		+ ((timePart * 1013904223) % 2147483647)
		+ ((counterPart * 1103515245) % 2147483647)
		+ ((playerPart * 22695477) % 2147483647)
	) % 2147483647
	return (seed <= 0 and seed + 1 or seed)
end

--[[
    Calculates the final number of rolls, applying multipliers and the cap.
]]
local function _calculateRolls(baseLuck: number, multiplier: number, luckCap: number): number
	local totalRolls = math.floor(baseLuck * multiplier)
	return math.min(totalRolls, luckCap)
end

--[[
    Filters the base rarity pool to include/exclude EventOnly items.
]]
local function _buildValidRarityPool(basePool: {}, eventName: string?): {}
	local validPool = {}
	for name, config in pairs(basePool) do
		-- Include if it's not an event item, OR if it IS an event item and an event is active.
		if not config.EventOnly or (config.EventOnly and eventName) then
			validPool[name] = config
		end
	end
	return validPool
end

--[[
    Creates a temporary, modified rarity pool with specific rarity chances boosted.
]]
local function _getBoostedRarityPool(originalPool: {}, rarityBooster: { [string]: number }): {}
	local boostedPool = {}
	for name, config in pairs(originalPool) do boostedPool[name] = table.clone(config) end
	
	local totalBoost = 0
	local unboostedChanceSum = 0

	for name, config in pairs(boostedPool) do
		if rarityBooster[name] then
			local boostAmount = rarityBooster[name]
			config.Chance += boostAmount
			totalBoost += boostAmount
		else
			unboostedChanceSum += config.Chance
		end
	end

	if totalBoost == 0 or unboostedChanceSum <= 0 then return boostedPool end

	for name, config in pairs(boostedPool) do
		if not rarityBooster[name] then
			local proportion = config.Chance / unboostedChanceSum
			config.Chance -= totalBoost * proportion
		end
	end

	return boostedPool
end

--[[
    Performs a single roll against a rarity pool to determine the outcome.
]]
local function _getRollResult(rarityPool: {}, luckBooster: number, rng: Random): {Name: string, Config: {}}?
	local entries = {}
	local totalChance = 0
	for name, config in pairs(rarityPool) do
		table.insert(entries, { Name = name, Config = config })
		totalChance = totalChance + config.Chance
	end

	if totalChance <= 0 then return #entries > 0 and entries[1] or nil end

	local randomNumber = rng:NextNumber() * totalChance
	local boostedRandomNumber = randomNumber / luckBooster

	local cumulativeChance = 0
	for _, entry in ipairs(entries) do
		cumulativeChance += entry.Config.Chance
		if boostedRandomNumber <= cumulativeChance then
			return entry -- Return the entry: { Name = "Rare", Config = { ... } }
		end
	end

	return #entries > 0 and entries[#entries] or nil -- Fallback
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Module:Init() end
function Module:Start() end

--[[@description:
    Performs rolls and returns the single best result.
    @param options table - Parameters for the roll:
        .BaseLuck, .RarityPool, .LuckMultiplier?, .LuckBooster?,
        .RarityBooster?, .LuckCap?, .PlayerUserId?, .EventName?
    @returns table? - The best rarity entry: { Name: string, Config: {} }
]]
function Module:Roll(options: {})
	local summary = self:RollSummary(options)
	return summary and summary.BestRoll or nil
end

--[[@description:
    Performs rolls and returns a detailed summary.
    @param options table - Parameters for the roll:
        .BaseLuck, .RarityPool, .LuckMultiplier?, .LuckBooster?,
        .RarityBooster?, .LuckCap?, .PlayerUserId?, .EventName? (string)
    @returns table? - A summary table with details about the rolls.
]]
function Module:RollSummary(options: {
	BaseLuck: number?,
	RarityPool: Rarities.Rarities?,
	LuckMultiplier: number?,
	LuckBooster: number?,
	RarityBooster: number?,
	LuckCap: number?,
	EventName: string?,
	PlayerUserId: number?
})
	local baseLuck = options.BaseLuck or 1
	local baseRarityPool = options.RarityPool or {}
	local multiplier = options.LuckMultiplier or 1
	local luckBooster = options.LuckBooster or 0
	local rarityBooster = options.RarityBooster or 0
	local luckCap = options.LuckCap or DEFAULT_LUCK_CAP
	local eventName = options.EventName
	
	if not baseRarityPool or next(baseRarityPool) == nil then
		warn("[LuckService] RollSummary called with an empty or nil RarityPool.")
		return nil
	end

	local rng = Random.new(_makeSeed(options.PlayerUserId))
	local totalRolls = _calculateRolls(baseLuck, multiplier, luckCap)
    
	local validPool = _buildValidRarityPool(baseRarityPool, eventName)
	local rollPool = rarityBooster and _getBoostedRarityPool(validPool, rarityBooster) or validPool
	
	local allRolls = {}
	local bestResult = nil
	
	for _ = 1, totalRolls do
		local currentResult = _getRollResult(rollPool, luckBooster, rng)
		if currentResult then
			table.insert(allRolls, currentResult)
			-- The "best" result is the one with the highest VisualTier
			if not bestResult or currentResult.Config.VisualTier > bestResult.Config.VisualTier then
				bestResult = currentResult
			end
		end
	end

	local summary = {
		LuckDetails = { Base = baseLuck, Multiplier = multiplier, Booster = luckBooster, Cap = luckCap },
		RollsMade = totalRolls,
		EventName = eventName or "None",
		AllRolls = allRolls,
		BestRoll = bestResult,
		RarityBoosterApplied = rarityBooster or "None",
	}

	return summary
end

-----------------------------
--MAIN--
-----------------------------

return Module