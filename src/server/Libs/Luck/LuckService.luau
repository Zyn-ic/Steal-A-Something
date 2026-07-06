--@author: yyumchi
--@date: 2025-09-03
--[[@description:
    Server-authoritative luck service.

    Uses one high-entropy startup seed, then reuses one Random instance for all rolls.
    Supports multiple rolls, roll count multipliers, higher-tier luck bias, additive
    rarity chance boosts, event filtering, and dictionary-based rarity pools.

    This module may be stored in shared space, but Roll and RollSummary only run on server.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local LuckService = {}

-----------------------------
-- SERVICES --
-----------------------------

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-----------------------------
-- CONSTANTS --
-----------------------------

local DEFAULT_LUCK_CAP = 8
local MAX_SEED = 2147483647
local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619

-----------------------------
-- TYPES --
-----------------------------

export type RarityBooster = {
	RarityName: string,
	RarityBoost: number,
}

export type Options = {
	BaseLuck: number?,
	RarityPool: Rarities.RaritiesTable?,
	LuckMultiplier: number?,
	LuckBooster: number?,
	RarityBooster: RarityBooster?,
	LuckCap: number?,
	EventName: string?,
	PlayerUserId: number?,
}

export type RollResult = {
	Name: string,
	Config: any,
}

export type RollSummary = {
	BestRoll: RollResult?,
	RollsMade: number,
	LuckDetails: {
		Base: number,
		Multiplier: number,
		Booster: number,
		Cap: number,
	},
	EventName: string?,
}

-----------------------------
-- PRIVATE VARIABLES --
-----------------------------

local SharedRarities = Rarities
local _rng: Random? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

--[[
    Blocks roll execution from client-side require/calls.
]]
local function _assertServer()
	if not RunService:IsServer() then
		error("[LuckService] This function can only run on the server.", 3)
	end
end

--[[
    Hashes mixed startup entropy into one valid Random seed.

    This is not cryptographic RNG. It is practical server-side game RNG.
    Main security comes from server-only execution and server-only reward granting.
]]
local function _makeStartupSeed(): number
	local combined = table.concat({
		tostring(os.time()),
		tostring(os.clock()),
		tostring(tick()),
		tostring(game.JobId),
		HttpService:GenerateGUID(false),
		tostring(math.random()),
	}, "|")

	local hash = FNV_OFFSET

	for index = 1, #combined do
		hash = bit32.bxor(hash, string.byte(combined, index))
		hash = bit32.band(hash * FNV_PRIME, 0xFFFFFFFF)
	end

	local seed = hash % MAX_SEED

	if seed <= 0 then
		seed = 1
	end

	return seed
end

--[[
    Returns one persistent server RNG. Seeded once.
]]
local function _getRng(): Random
	_assertServer()

	if _rng == nil then
		_rng = Random.new(_makeStartupSeed())
	end

	return _rng
end

--[[
    Calculates final roll count.

    BaseLuck * LuckMultiplier, floored, minimum 1, capped by LuckCap.
]]
local function _calculateRolls(baseLuck: number, multiplier: number, luckCap: number): number
	local totalRolls = math.floor((baseLuck or 1) * (multiplier or 1))

	if totalRolls < 1 then
		totalRolls = 1
	end

	return math.min(totalRolls, luckCap or DEFAULT_LUCK_CAP)
end

--[[
    Filters rarity pool.

    Non-event rarities always allowed.
    EventOnly rarities require EventName.

    If config.EventName exists, it must match EventName.
    If config.EventNames exists as array, EventName must be inside it.
]]
local function _buildValidRarityPool(basePool: Rarities.RaritiesTable, eventName: string?): Rarities.RaritiesTable
	local validPool = {}

	if not basePool then
		return validPool
	end

	for name, config in pairs(basePool) do
		if type(config) ~= "table" then
			continue
		end

		local isEventOnly = config.EventOnly == true

		if not isEventOnly then
			validPool[name] = config
			continue
		end

		if not eventName then
			continue
		end

		if config.EventName ~= nil then
			if config.EventName == eventName then
				validPool[name] = config
			end

			continue
		end

		if type(config.EventNames) == "table" then
			for _, allowedEventName in ipairs(config.EventNames) do
				if allowedEventName == eventName then
					validPool[name] = config
					break
				end
			end

			continue
		end

		validPool[name] = config
	end

	return validPool
end

--[[
    Creates boosted rarity pool without mutating original pool.

    RarityBooster adds Chance to one target rarity.
    Non-boosted entries reduce proportionally to keep total weight stable.
]]
local function _getBoostedRarityPool(
	originalPool: Rarities.RaritiesTable,
	rarityBooster: RarityBooster?
): Rarities.RaritiesTable
	local boostedPool: Rarities.RaritiesTable = {}

	for name, config in pairs(originalPool) do
		if type(config) == "table" then
			boostedPool[name] = table.clone(config)
		end
	end

	if not rarityBooster then
		return boostedPool
	end

	if type(rarityBooster.RarityName) ~= "string" then
		return boostedPool
	end

	if type(rarityBooster.RarityBoost) ~= "number" or rarityBooster.RarityBoost <= 0 then
		return boostedPool
	end

	local targetName = rarityBooster.RarityName
	local boostAmount = rarityBooster.RarityBoost
	local targetConfig = boostedPool[targetName]

	if type(targetConfig) ~= "table" then
		return boostedPool
	end

	local unboostedChanceSum = 0

	for name, config in pairs(boostedPool) do
		if name ~= targetName and type(config) == "table" then
			unboostedChanceSum += math.max(0, tonumber(config.Chance) or 0)
		end
	end

	targetConfig.Chance = math.max(0, tonumber(targetConfig.Chance) or 0) + boostAmount

	if unboostedChanceSum <= 0 then
		return boostedPool
	end

	for name, config in pairs(boostedPool) do
		if name ~= targetName and type(config) == "table" then
			local chance = math.max(0, tonumber(config.Chance) or 0)
			local proportion = chance / unboostedChanceSum
			local reduction = boostAmount * proportion

			config.Chance = math.max(0, chance - reduction)
		end
	end

	return boostedPool
end

--[[
    Converts dictionary pool to sorted roll entries.

    Sorting removes unstable pairs() order from roll behavior.
]]
local function _buildRollEntries(rarityPool: Rarities.RaritiesTable): ({any}, number, number, number)
	local entries = {}
	local totalChance = 0
	local minTier = math.huge
	local maxTier = -math.huge

	for name, config in pairs(rarityPool) do
		if type(config) ~= "table" then
			continue
		end

		local chance = tonumber(config.Chance) or 0
		local visualTier = tonumber(config.VisualTier) or 0

		if chance > 0 then
			table.insert(entries, {
				Name = name,
				Config = config,
				Chance = chance,
				VisualTier = visualTier,
			})

			totalChance += chance
			minTier = math.min(minTier, visualTier)
			maxTier = math.max(maxTier, visualTier)
		end
	end

	table.sort(entries, function(left, right)
		if left.VisualTier == right.VisualTier then
			return left.Name < right.Name
		end

		return left.VisualTier < right.VisualTier
	end)

	if minTier == math.huge then
		minTier = 0
	end

	if maxTier == -math.huge then
		maxTier = 0
	end

	return entries, totalChance, minTier, maxTier
end

--[[
    Applies LuckBooster as a higher-tier weight bias.

    LuckBooster = 1 means no bias.
    LuckBooster > 1 increases higher VisualTier weights.
    Lowest tier remains unchanged. Highest tier receives strongest boost.
]]
local function _getLuckAdjustedChance(entry: any, luckBooster: number, minTier: number, maxTier: number): number
	if type(luckBooster) ~= "number" or luckBooster <= 1 then
		return entry.Chance
	end

	if maxTier <= minTier then
		return entry.Chance
	end

	local tierAlpha = (entry.VisualTier - minTier) / (maxTier - minTier)
	local multiplier = 1 + ((luckBooster - 1) * tierAlpha)

	return entry.Chance * multiplier
end

--[[
    Performs one weighted roll.
]]
local function _getRollResult(rarityPool: Rarities.RaritiesTable, luckBooster: number, rng: Random): RollResult?
	if not rarityPool or next(rarityPool) == nil then
		return nil
	end

	local entries, _, minTier, maxTier = _buildRollEntries(rarityPool)

	if #entries == 0 then
		for name, config in pairs(rarityPool) do
			return {
				Name = name,
				Config = config,
			}
		end

		return nil
	end

	if type(luckBooster) ~= "number" or luckBooster <= 0 then
		luckBooster = 1
	end

	local adjustedTotalChance = 0

	for _, entry in ipairs(entries) do
		entry.AdjustedChance = _getLuckAdjustedChance(entry, luckBooster, minTier, maxTier)
		adjustedTotalChance += entry.AdjustedChance
	end

	if adjustedTotalChance <= 0 then
		return nil
	end

	local randomNumber = rng:NextNumber(0, adjustedTotalChance)
	local cumulative = 0

	for _, entry in ipairs(entries) do
		cumulative += entry.AdjustedChance

		if randomNumber <= cumulative then
			return {
				Name = entry.Name,
				Config = entry.Config,
			}
		end
	end

	local lastEntry = entries[#entries]

	return {
		Name = lastEntry.Name,
		Config = lastEntry.Config,
	}
end

--[[
    Returns better roll by VisualTier.
]]
local function _isBetterRoll(currentBest: RollResult?, newResult: RollResult): boolean
	if not currentBest then
		return true
	end

	local bestTier = 0
	local newTier = 0

	if type(currentBest.Config) == "table" then
		bestTier = tonumber(currentBest.Config.VisualTier) or 0
	end

	if type(newResult.Config) == "table" then
		newTier = tonumber(newResult.Config.VisualTier) or 0
	end

	return newTier > bestTier
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function LuckService:Init() end
function LuckService:Start() end

--[[
    Performs rolls and returns single best result.
]]
function LuckService:Roll(options: Options): RollResult?
	_assertServer()

	local summary = LuckService:RollSummary(options)
	return summary and summary.BestRoll or nil
end

--[[
    Performs rolls and returns compact summary.
]]
function LuckService:RollSummary(options: Options): RollSummary?
	_assertServer()

	options = options or {}

	local baseRarityPool = options.RarityPool or SharedRarities

	if not baseRarityPool or next(baseRarityPool) == nil then
		error("[LuckService] Provided bad rarity pool.", 2)
	end

	local baseLuck = options.BaseLuck or 1
	local multiplier = options.LuckMultiplier or 1
	local luckBooster = options.LuckBooster or 1
	local rarityBooster = options.RarityBooster
	local luckCap = options.LuckCap or DEFAULT_LUCK_CAP
	local eventName = options.EventName

	local totalRolls = _calculateRolls(baseLuck, multiplier, luckCap)
	local validPool = _buildValidRarityPool(baseRarityPool, eventName)

	if next(validPool) == nil then
		warn("[LuckService] No valid rarities after event filtering.")
		return nil
	end

	local rollPool = rarityBooster and _getBoostedRarityPool(validPool, rarityBooster) or validPool
	local rng = _getRng()

	local bestResult: RollResult? = nil

	for _ = 1, totalRolls do
		local result = _getRollResult(rollPool, luckBooster, rng)

		if result and _isBetterRoll(bestResult, result) then
			bestResult = result
		end
	end

	return {
		BestRoll = bestResult,
		RollsMade = totalRolls,
		LuckDetails = {
			Base = baseLuck,
			Multiplier = multiplier,
			Booster = luckBooster,
			Cap = luckCap,
		},
		EventName = eventName,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return LuckService
