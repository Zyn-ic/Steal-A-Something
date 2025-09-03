-- LuckService (library)
-- Handles luck multipliers + roll logic for rarities/mutations/traits.
-- This is intentionally a "lib" (no Roblox-specific side-effects); services call it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require Rarities config from ReplicatedStorage.Shared.Config.Rarities
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rarities"))

local Module = {}

-- Base luck multiplier (1.0 = default)
Module.BaseLuck = 1.0

-- Per-event multipliers (string->multiplier)
Module.EventMultipliers = {} :: { [string]: number }

-- Optional per-player luck (userId -> multiplier)
Module.PlayerLuck = {} :: { [number]: number }

-- Maximum attempts we will allow (safety cap)
Module.MaxAttempts = 8

-- Fractional luck will probabilistically grant an extra attempt
-- e.g. luck = 2.7 -> 2 attempts + 70% chance of a 3rd attempt

-- Helper: clamp
local function clamp(val: number, a: number, b: number)
	if val < a then return a end
	if val > b then return b end
	return val
end

-- Helper: sample weighted map. weights: { key -> weight }
local function sampleWeighted(weights: { [string]: number })
	local total = 0
	for _, v in pairs(weights) do
		total += v
	end
	if total <= 0 then
		-- no weights, return any key
		for k, _ in pairs(weights) do
			return k
		end
		return nil
	end

	local roll = math.random() * total
	local sum = 0
	for k, v in pairs(weights) do
		sum += v
		if roll <= sum then
			return k
		end
	end
	-- fallback
	for k, _ in pairs(weights) do
		return k
	end
	return nil
end

-- Helper: compute "rarity score" to pick best result from multiple samples.
-- Uses VisualTier (higher = rarer) if provided; otherwise uses Chance (lower chance -> rarer).
local function rarityScore(cfg: any)
	-- prefer VisualTier as primary
	if type(cfg.VisualTier) == "number" then
		-- larger VisualTier => rarer => we want higher score
		return cfg.VisualTier * 1000 -- scale to dominate chance differences
	end
	-- fallback: smaller Chance is rarer, invert it.
	local chance = cfg.Chance or 1
	-- invert (smaller chance => larger score)
	return 1 / math.max(tonumber(chance) or 1, 0.0001)
end

-- Build rarity weight map for sampling, respecting eventOnly flags
-- context = { eventName = string? }
function Module.BuildRarityWeights(context: { eventName: string? }?)
	local eventName
	if context then
		eventName = context.eventName
	end

	local weights = {} :: { [string]: number }

	for name, cfg in pairs(Rarities) do
		local include = true
		if cfg.EventOnly then
			-- only include event-only rarities when an event is active AND matches prefix or exact event
			if not eventName then
				include = false
			else
				-- include event rarities when an eventName is provided
				include = true
			end
		end

		if include then
			weights[name] = cfg.Chance or 0
		end
	end

	return weights
end

-- Returns effective luck multiplier for a given context
-- context = { eventName = string?, playerUserId = number? }
-- NOTE: This now enforces the MaxAttempts cap so the returned luck will never exceed Module.MaxAttempts.
function Module.GetEffectiveLuck(context: { eventName: string?, playerUserId: number? }?)
	local luck = Module.BaseLuck or 1.0

	if context then
		-- apply event multiplier if present
		if context.eventName and Module.EventMultipliers[context.eventName] then
			luck = luck * (Module.EventMultipliers[context.eventName] or 1.0)
		end

		-- apply player-specific luck if present (multiplicative)
		if context.playerUserId and Module.PlayerLuck[context.playerUserId] then
			luck = luck * (Module.PlayerLuck[context.playerUserId] or 1.0)
		end
	end

	-- safety lower bound
	if luck <= 0 then
		luck = 1.0
	end

	-- Enforce the maximum luck cap so luck itself cannot exceed MaxAttempts.
	-- This ensures later math.floor/fractional logic will only operate on a capped value.
	if Module.MaxAttempts and type(Module.MaxAttempts) == "number" then
		luck = math.min(luck, Module.MaxAttempts)
	end

	return luck
end

-- Set global base luck (authoritative)
function Module.SetBaseLuck(newLuck: number)
	if type(newLuck) ~= "number" or newLuck <= 0 then
		return false, "invalid luck"
	end
	Module.BaseLuck = newLuck
	return true
end

-- Add / set a temporary event multiplier. Returns a cleanup function.
function Module.SetEventMultiplier(eventName: string, multiplier: number, durationSeconds: number?)
	if not eventName or multiplier == nil then return false end
	Module.EventMultipliers[eventName] = multiplier

	-- schedule cleanup if duration given
	if durationSeconds and type(durationSeconds) == "number" and durationSeconds > 0 then
		task.spawn(function()
			task.wait(durationSeconds)
			-- only clear if unchanged (prevents overwriting newer multipliers)
			if Module.EventMultipliers[eventName] == multiplier then
				Module.EventMultipliers[eventName] = nil
			end
		end)
	end

	return true
end

-- Set per-player multiplier (userId)
function Module.SetPlayerLuck(userId: number, multiplier: number, durationSeconds: number?)
	if type(userId) ~= "number" or type(multiplier) ~= "number" then return false end
	Module.PlayerLuck[userId] = multiplier

	if durationSeconds and durationSeconds > 0 then
		task.spawn(function()
			task.wait(durationSeconds)
			-- clear only if unchanged
			if Module.PlayerLuck[userId] == multiplier then
				Module.PlayerLuck[userId] = nil
			end
		end)
	end

	return true
end

-- Core: Roll a rarity given context
-- context = { eventName = string?, playerUserId = number? }
-- returns a table: { rarity = string?, luck = number, attempts = number, weights = table }
function Module.RollRarity(context: { eventName: string?, playerUserId: number? }?)
	context = context or {}

	-- Build weights (take into account event-only rarities)
	local weights = Module.BuildRarityWeights(context)
	if not weights or next(weights) == nil then
		-- fallback: if none, use Rarities keys
		for name, _ in pairs(Rarities) do
			weights[name] = 1
		end
	end

	-- effective luck (may be fractional) - note GetEffectiveLuck returns a luck capped at MaxAttempts
	local effLuck = Module.GetEffectiveLuck(context)
	-- determine attempts: floor + fractional chance of extra.
	local baseAttempts = math.floor(effLuck)
	local fractional = effLuck - baseAttempts
	local attempts = baseAttempts
	if math.random() <= fractional then
		attempts = attempts + 1
	end
	-- attempts are implicitly <= MaxAttempts because effLuck <= MaxAttempts
	attempts = clamp(attempts, 1, Module.MaxAttempts)

	-- For each attempt, sample a rarity and keep the "best" (rarest) by our scoring function
	local bestName = nil
	local bestScore = -math.huge

	for _i = 1, attempts do
		local pick = sampleWeighted(weights)
		if pick then
			local cfg = Rarities[pick] or {}
			local score = rarityScore(cfg)
			-- prefer higher score (rarer)
			if score > bestScore then
				bestScore = score
				bestName = pick
			end
		end
	end

	-- If no pick (shouldn't happen), fallback to random
	if not bestName then
		for name,_ in pairs(weights) do
			bestName = name
			break
		end
	end

	return {
		rarity = bestName,
		luck = effLuck,
		attempts = attempts,
		weights = weights
	}
end

-- Convenience wrapper: Roll and return a string summary
function Module.RollSummary(context: { eventName: string?, playerUserId: number? }?)
	local res = Module.RollRarity(context)
	return string.format("Luck=%.2f Attempts=%d Rarity=%s", res.luck or 0, res.attempts or 0, res.rarity or "Unknown"), res
end

-- Init / Start (loader-compatible)
function Module:Init()
	-- no heavy initialization; placeholder for loader.
end

function Module:Start()
	-- nothing required at start currently
end

return Module
