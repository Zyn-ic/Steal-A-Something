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

local LuckService = {}

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-- CONSTANTS --

local DEFAULT_LUCK_CAP = 8 -- Default maximum number of rolls. make it a dynamic delcaration

export type Options = {
	BaseLuck: number?,
	RarityPool: Rarities.RaritiesTable?,
	LuckMultiplier: number?,
	LuckBooster: number?,
	RarityBooster: {RarityName: string, RarityBoost: number}?, 
	LuckCap: number?,
	EventName: string?,
	PlayerUserId: number?
}
-----------------------------
-- PRIVATE VARIABLES --
-----------------------------

local _rollCounter = 0
local SharedRarities = require(ReplicatedStorage.Shared.Config.Rarities)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

--[[
    Creates a high-entropy seed for the Random object by mixing multiple sources.
]]
local function _makeSeed(playerUserId: number?): number
	_rollCounter += 1
	local guid = HttpService:GenerateGUID(false) or ""
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
    Uses floor(baseLuck * multiplier). Ensures at least 1 roll.
]]
local function _calculateRolls(baseLuck: number, multiplier: number, luckCap: number): number
	local totalRolls = math.floor((baseLuck or 1) * (multiplier or 1))
	if totalRolls < 1 then totalRolls = 1 end
	return math.min(totalRolls, luckCap or DEFAULT_LUCK_CAP)
end

--[[
    Filters the base rarity pool to include/exclude EventOnly items.
    basePool: table mapping name -> config
    eventName: if nil, event-only rarities are excluded
]]
local function _buildValidRarityPool(basePool: Rarities.RaritiesTable, eventName: string?): Rarities.RaritiesTable
	local validPool = {}
	if not basePool then return validPool end -- this line can be delete if needed.
	for name, config in pairs(basePool) do
		-- config could be nil; guard
		local isEventOnly = type(config) == "table" and config.EventOnly
		if not isEventOnly or (isEventOnly and eventName) then
			validPool[name] = config
		end
	end
	return validPool
end

--[[
    Creates a temporary, modified rarity pool with specific rarity chances boosted.
    rarityBooster: table { [rarityName] = boostAmount } (additive boost)
    Returns a shallow-cloned pool with adjusted Chance fields; non-boosted entries
    are proportionally reduced to keep the total relative weight roughly stable.
]]
local function _getBoostedRarityPool(originalPool: Rarities.RaritiesTable, rarityBooster: {RarityName: string, RarityBoost: number}): Rarities.RaritiesTable
	-- shallow-clone configs to avoid mutating caller data
	local boostedPool: Rarities.RaritiesTable = {}
	for name, config in pairs(originalPool) do
		-- clone if table, else keep as-is
		if type(config) == "table" then
			boostedPool[name] = table.clone(config)
		end
	end

	if not rarityBooster or next(rarityBooster) == nil then
		return boostedPool
	end

	local totalBoost = 0
	local unboostedChanceSum = 0
	for name, config in pairs(boostedPool) do
		local cfgChance = (type(config) == "table" and config.Chance) or 0
		local boostAmount = rarityBooster.RarityName == name and rarityBooster.RarityBoost or 0
		if boostAmount and type(boostAmount) == "number" and boostAmount > 0 then
			-- apply additive boost
			if type(config) == "table" then
				config.Chance = cfgChance + boostAmount
			end

			totalBoost = totalBoost + boostAmount
		else
			unboostedChanceSum = unboostedChanceSum + cfgChance
		end
	end

	-- If there's no unboosted mass to re-balance against, return as-is.
	if totalBoost == 0 or unboostedChanceSum <= 0 then
		return boostedPool
	end

	-- Reduce non-boosted entries proportionally to balance added boost mass.
	for name, config in pairs(boostedPool) do
		if config.Chance == originalPool[name].Chance then
			local cfgChance = (type(config) == "table" and config.Chance) or 0
			local proportion = cfgChance / unboostedChanceSum
			local reduction = totalBoost * proportion
			if type(config) == "table" then
				config.Chance = math.max(0, cfgChance - reduction)
			else
				boostedPool[name] = { Chance = math.max(0, cfgChance - reduction) }
			end
		end
	end

	return boostedPool
end

--[[
    Performs a single roll against a rarity pool to determine the outcome.
    luckBooster: numeric multiplier applied to the sampled value (must be > 0).
    rng: Random instance.
    Returns a table { Name = string, Config = table } or nil.
]]
local function _getRollResult(rarityPool: Rarities.RaritiesTable, luckBooster: number, rng: Random)
	if not rarityPool or next(rarityPool) == nil then return nil end

	local entries = {}
	local totalChance = 0
	for name, config in pairs(rarityPool) do
		local chance = type(config) == "table" and config.Chance or 0
		-- skip zero or negative chance entries
		if chance > 0 then
			table.insert(entries, { Name = name, Config = config, Chance = chance })
			totalChance = totalChance + chance
		end
	end

	if #entries == 0 then
		-- fallback: if pool had entries but none had positive chance, return first key
		for name, config in pairs(rarityPool) do
			return { Name = name, Config = config }
		end
		return nil
	end

	-- ensure luckBooster is sane
	if type(luckBooster) ~= "number" or luckBooster <= 0 then
		luckBooster = 1
	end

	local randomNumber = rng:NextNumber() * totalChance
	local adjustedRandom = randomNumber / luckBooster

	local cumulative = 0
	for _, entry in ipairs(entries) do
		cumulative = cumulative + entry.Chance
		if adjustedRandom <= cumulative then
			-- return { Name = ..., Config = ... }
			return { Name = entry.Name, Config = entry.Config }
		end
	end

	-- fallback: return last entry
	local last = entries[#entries]
	return last and { Name = last.Name, Config = last.Config } or nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function LuckService:Init() end
function LuckService:Start() end

--[[@description:
    Performs rolls and returns the single best result.
    @param options table - Parameters for the roll:
        .BaseLuck number?,
        .RarityPool table? (name -> config),
        .LuckMultiplier number? (defaults to 1),
        .LuckBooster number? (defaults to 1),
        .RarityBooster table? (name->additive boost),
        .LuckCap number? (defaults to DEFAULT_LUCK_CAP),
        .EventName string?,
        .PlayerUserId number?
    @returns table? - The best rarity entry: { Name = string, Config = table } or nil
]]


function LuckService:Roll(options: Options)
	local summary = LuckService:RollSummary(options)
	return summary and summary.BestRoll or nil
end

--[[@description:
    Performs rolls and returns a compact summary.
    @param options table - see Module:Roll above for accepted keys.
    @returns table? - summary with keys:
        BestRoll = { Name, Config } or nil,
        RollsMade = number,
        LuckDetails = { Base = number, Multiplier = number, Booster = number, Cap = number },
        EventName = string or nil
]]
function LuckService:RollSummary(options: Options)
	options = options or {}

	-- Resolve provided pool or fallback to shared rarities
	local baseRarityPool = options.RarityPool
	if next(baseRarityPool) == nil or next(SharedRarities) == nil then return error("Provided Bad Rarity Pools") end

	local baseLuck = options.BaseLuck or 1
	local multiplier = options.LuckMultiplier or 1
	local luckBooster = options.LuckBooster or 1 -- must be > 0
	local rarityBooster = options.RarityBooster or nil
	local luckCap = options.LuckCap or DEFAULT_LUCK_CAP
	local eventName = options.EventName or nil

	-- RNG instance for this roll batch
	local rng = Random.new(_makeSeed(options.PlayerUserId))

	-- determine how many rolls to perform
	local totalRolls = _calculateRolls(baseLuck, multiplier, luckCap)

	-- build the valid pool (respect event-only)
	local validPool = _buildValidRarityPool(baseRarityPool, eventName)

	-- if no valid entries after filtering, abort
	if not validPool or next(validPool) == nil then
		warn("[LuckService] No valid rarities after event filtering.")
		return nil
	end

	-- apply rarity boosts (if provided)
	local rollPool = rarityBooster and _getBoostedRarityPool(validPool, rarityBooster) or validPool

	-- perform rolls and pick best by VisualTier (higher wins); safe defaults for VisualTier
	local bestResult = nil
	for _ = 1, totalRolls do
		local result = _getRollResult(rollPool, luckBooster, rng)
		if result then
			local bestTier = (bestResult and type(bestResult.Config) == "table" and tonumber(bestResult.Config.VisualTier)) or 0
			local resTier = (type(result.Config) == "table" and tonumber(result.Config.VisualTier)) or 0
			if not bestResult or resTier > bestTier then
				bestResult = result
			end
		end
	end

	-- compose concise summary
	local summary = {
		BestRoll = bestResult,
		RollsMade = totalRolls,
		LuckDetails = {
			Base = baseLuck,
			Multiplier = multiplier,
			Booster = luckBooster,
			Cap = luckCap
		},
		EventName = eventName
	}

	return summary
end

-----------------------------
--MAIN--
-----------------------------

return LuckService
