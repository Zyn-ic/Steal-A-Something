# LuckService — README 🧠✨

A compact guide to how the `LuckService` (luck library) works, how to use it, and what we did to keep it safe from easy prediction. Short, practical, and full of examples.

---

## Quick summary ✅

`LuckService` turns "luck" into **extra sampling attempts** when choosing rarities (and similar rolls).

* `luck` = how many roll **attempts** you get (fractional luck gives a probabilistic extra attempt).
* Multipliers (global, event, per-player) multiply together to produce **effective luck**.
* We **cap** luck at `MaxAttempts` to prevent runaway sampling and server cost.
* Rolls sample a **weighted rarity pool**, then keep the *rarest* (best) result across attempts.
* The library includes RNG-hardening to make the system **harder to predict**.

---

## Table of contents

1. Concepts (luck, multipliers, attempts, cap)
2. How a roll works (weights → attempts → best pick)
3. Predictability — analysis and mitigation (what we changed) 🔐
4. API (functions & return values) 📚
5. Examples (short code snippets) 🧪
6. Paid-weight boost feature (optional monetized advantage) 💸
7. Tuning tips & FAQ ⚙️

---

## 1) Core concepts — short & sweet 🍬

### Luck

* The base `Module.BaseLuck` (default `1.0`) is the baseline number of attempts.
* Effective luck is `BaseLuck × EventMultiplier × PlayerMultiplier` (multiplicative stacking).

### Multiplier sources

* `Module.BaseLuck` — global base.
* `Module.EventMultipliers[eventName]` — event-specific (e.g. `PixelFestival`).
* `Module.PlayerLuck[userId]` — per-player temporary bonuses.

All are **multiplicative**.

### Attempts

* `attempts = floor(effectiveLuck)`, plus a `fractional` chance to get `+1` attempt.
  Example: `effLuck = 2.7` → 2 guaranteed attempts + 70% chance at a 3rd.

### Cap (safety)

* `Module.MaxAttempts` (default `8`) is the maximum number of attempts allowed.
* We **cap the *luck* itself** to `MaxAttempts`, so fractional behaviour is evaluated on the capped value.
  Example: If `rawLuck = 15` and `MaxAttempts = 8`, `effLuck` becomes `8` (so attempts are 8 or sometimes 8 depending on fractional part).

Why? Keeps sampling predictable for performance and prevents corner-case exploits where extremely high luck causes heavy compute or trivializes loot.

---

## 2) How a single roll works 🎲

1. Build the rarity weight table from `Rarities` config. Event-only rarities are included only if an `eventName` is passed in the roll context.
2. Compute effective luck (applies base, event, player multipliers), then **cap it** to `MaxAttempts`.
3. Determine attempts from `effLuck` (floor + fractional probabilistic extra).
4. For each attempt:

   * Sample once from the weighted rarity map (weights come from rarities' `Chance`).
   * Compute a `rarityScore` — rarer == higher score (we use `VisualTier` if present, otherwise inverse of `Chance`).
   * Keep the rarity with **highest** score across attempts.
5. Return the chosen rarity along with metadata (`luck`, `attempts`, `weights`).

This approach gives better odds to rare outcomes as luck increases but prevents single-roll runaway mechanics.

---

## 3) Predictability: can the luck be predicted? — analysis & mitigation 🔍➡️🔒

### Is it predictable?

* `math.random()` and the global PRNG are deterministic and can be predicted if an attacker sees enough outputs or can influence server timing. We considered this and implemented per-roll RNG isolation with blended entropy.

### What we changed (mitigation)

* **Per-roll RNG instance** using `Random.new(seed)` instead of the global `math.random()` state.
* Seed is constructed from a mix of:

  * `HttpService:GenerateGUID(false)` (grab numeric substring),
  * `os.time()` (server time),
  * a module-private counter incremented every roll,
  * optional `playerUserId` from the roll context.
* This reduces the chance an attacker can predict the next roll because the seed mixes GUID entropy and server-local state.

> ⚠️ Note: Roblox does not provide cryptographically secure RNG. This reduces practical prediction risk but is not cryptographically secure. For cryptographic guarantees use an external/third-party randomness oracle.

---

## 4) API reference (functions & returns) 📘

> All functions are on `LuckService` (module). `context` tables use keys: `{ eventName = string?, playerUserId = number? }`.

### Read-only data

* `Module.BaseLuck` (number) — default 1.0.
* `Module.MaxAttempts` (number) — default 8.

### Configuration / setters

* `Module.SetBaseLuck(newLuck: number) -> (bool, error?)`
  Set global base luck. Must be > 0.

* `Module.SetEventMultiplier(eventName: string, multiplier: number, durationSeconds: number?) -> bool`
  Add/replace an event multiplier. If `durationSeconds` provided it auto-cleans.

* `Module.SetPlayerLuck(userId: number, multiplier: number, durationSeconds: number?) -> bool`
  Set per-player multiplier. Auto-cleans if `durationSeconds`.

* **New:** `Module.SetPlayerWeightBoost(userId: number, rarityName: string, multiplier: number, durationSeconds: number?) -> bool`
  Temporarily multiplies the weight (Chance) of a specific `rarityName` for a single player (useful for paid boosts). This affects `BuildRarityWeights` when `playerUserId` is present in the context.

### Core roll functions

* `Module.GetEffectiveLuck(context?) -> number`
  Returns the **capped** effective luck (applies base, event, player multipliers and caps to `MaxAttempts`).

* `Module.RollRarity(context?) -> { rarity = string, luck = number, attempts = number, weights = table }`
  Performs the roll per the algorithm described and returns details.

* `Module.RollSummary(context?) -> (stringSummary, dataTable)`
  Convenience wrapper returning a formatted string and the raw data table from `RollRarity`.

---

## 5) Examples — usage patterns ✨

### Simple roll (default)

```lua
local LuckService = require(ServerScriptService.Libs.LuckService)
local summary, data = LuckService.RollSummary()
print(summary) -- e.g. "Luck=1.00 Attempts=1 Rarity=Common"
```

### Event roll (include event-only rarities)

```lua
LuckService.SetEventMultiplier("PixelFestival", 2.0, 3600) -- x2 for 1 hour
local summary, data = LuckService.RollSummary({ eventName = "PixelFestival" })
print(summary)
```

### Player special luck

```lua
LuckService.SetPlayerLuck(12345, 3.0, 30) -- player 12345 gets x3 luck for 30s
local summary = LuckService.RollSummary({ playerUserId = 12345 })
print(summary)
```

### Paid boost example (shop purchase)

```lua
-- When a player buys a "Legendary Boost" we call:
LuckService.SetPlayerWeightBoost(player.UserId, "Legendary", 2.0, 3600) -- doubles Legendary weight for 1 hour

-- When rolling for that player:
local s, d = LuckService.RollSummary({ playerUserId = player.UserId })
print(s) -- shows boosted probability for Legendary
```

---

## 6) Paid-weight boost feature (monetization) 💸

* **What it does:** Temporarily multiplies the weight (Chance) of a specific rarity for a single player. This is intended for cosmetic/vanity purchases like "boost your chance to get Legendary for 1 hour".
* **How it affects rolls:** `BuildRarityWeights(context)` checks `Module.PlayerWeightBoosts[playerUserId]` and multiplies that player's target rarity weight by the configured multiplier before sampling.
* **Fairness notes:** Use tempered multipliers (e.g., 1.5–3.0), limit duration, and never make boosts guarantees (never promise "guaranteed Legendary"). Log and audit purchases to prevent abuse.

---

## 7) Tuning tips & FAQ 🛠️

### Q: Should rarities' `Chance` sum to 100?

A: Not necessary. `Chance` entries are **weights**. Relative sizes matter (80/20 == 8/2).

### Q: Should `MaxAttempts` equal the highest possible luck?

A: `MaxAttempts` is a server safety cap. Set it to what your server budget allows. If you expect players to buy huge multipliers, clamp luck (as implemented) to keep roll cost bounded.

### Q: Can a skilled player "game" RNG?

A: We reduce predictability using per-roll RNG seeds mixed with GUIDs and server-state. This is not cryptographically secure but reduces practical predictability for most attackers. For absolute unpredictability use an external randomness oracle.

---

