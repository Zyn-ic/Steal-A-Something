# LuckService — README 🎲✨

A concise guide to the stateless `LuckService` module. This document explains the core concepts, how to perform rolls, and how the system is designed to be less predictable. It's practical and full of examples to get you started quickly.

-----

## Quick Summary ✅

`LuckService` provides a set of tools to perform complex, weighted random rolls. The core idea is that "luck" translates into more chances to get a better outcome.

  * **Rolls (or Attempts):** Determined by `BaseLuck` and a `LuckMultiplier`. More rolls mean more chances at a rare item.
  * **Luck Booster:** Improves the *quality* of each roll, nudging the outcome toward rarer items on the list.
  * **Rarity Booster:** Temporarily increases the base `Chance` of specific rarities, making them more likely to be rolled.
  * **Best of N:** The system performs all rolls and returns the single **best** result based on the rarity's `VisualTier`.
  * **Secure RNG:** Each roll operation uses a newly seeded `Random` object with blended server-side entropy to make outcomes **hard to predict**.

-----

## Table of Contents

1.  [**Core Concepts**](#1-core-concepts-) — Luck, Multipliers, and Boosters
2.  [**How a Roll Works**](#2-how-a-roll-works-️) — The step-by-step process
3.  [**Predictability & Security**](#3-predictability--security-) — How we make rolls harder to guess
4.  [**API Reference**](#4-api-reference-) — How to use the functions
5.  [**Examples**](#5-examples-) — Putting it all together

-----

## 1\) Core Concepts 🍬 

These are the main inputs that control the outcome of a roll. They are all passed in a single `options` table for each call.

### Rolls (`BaseLuck` & `LuckMultiplier`)

This determines **how many attempts** you get. A higher number is always better.

  * `BaseLuck`: The starting number of rolls.
  * `LuckMultiplier`: A factor applied to `BaseLuck` (e.g., `1.5` for a 50% boost).
  * **Total Rolls** = `floor(BaseLuck × LuckMultiplier)`, capped by `LuckCap`.

<!-- end list -->

```lua
-- Example: A player with 10 base luck and a x2 multiplier gets 20 rolls.
local options = { BaseLuck = 10, LuckMultiplier = 2, RarityPool = ... }
local summary = LuckService:RollSummary(options)
-- summary.RollsMade will be 20
```

### Luck Booster

This makes **each individual roll better**. It works by dividing the random number generated for a roll, pushing it closer to the rarer items (which are typically at the start of the probability list).

  * A `LuckBooster` of `1` (the default) has no effect.
  * A `LuckBooster` of `2` makes a roll twice as "lucky." A random result of 50 would become 25, potentially moving from "Uncommon" to "Rare."

<!-- end list -->

```lua
-- Example: Give a player a powerful boost on their roll quality.
local options = { BaseLuck = 5, LuckBooster = 2.5, RarityPool = ... }
local bestItem = LuckService:Roll(options)
-- This player's 5 rolls are 2.5x more likely to land on rare items.
```

### Rarity Booster

This temporarily makes specific rarities **physically larger** on the "prize wheel" by adding to their `Chance`.

  * It takes a dictionary mapping rarity names to a percentage to add (e.g., `{ Legendary = 0.5, Epic = 1 }`).
  * The service automatically re-normalizes the other chances so the total probability remains 100%.

<!-- end list -->

```lua
-- Example: Make Legendary and Epic items slightly more common for this one roll.
local options = {
    BaseLuck = 10,
    RarityBooster = { Legendary = 0.5, Epic = 1.0 }, -- +0.5% to Legendary, +1% to Epic
    RarityPool = ...
}
local summary = LuckService:RollSummary(options)
```

-----

## 2\) How a Roll Works ⚙️

Every call to `:Roll()` or `:RollSummary()` is a self-contained operation that follows these steps:

1.  **Filter Pool:** A temporary `RarityPool` is built, including `EventOnly` items only if an `eventName` is provided in the options.
2.  **Apply Rarity Boosts:** If a `RarityBooster` is provided, the chances in the temporary pool are modified and re-normalized.
3.  **Calculate Rolls:** `BaseLuck`, `LuckMultiplier`, and `LuckCap` are used to determine the final number of roll attempts.
4.  **Create Secure RNG:** A new `Random` object is created with a high-entropy seed for this specific operation.
5.  **Perform Rolls:** For each attempt:
      * A random number is generated and modified by the `LuckBooster`.
      * The outcome (e.g., "Rare") is determined from the weighted pool.
6.  **Find Best Result:** All roll outcomes are compared, and the one with the highest **`VisualTier`** is kept as the final result.
7.  **Return:** The function returns either the single best item or a detailed summary of the entire process.

> This stateless "best-of-N" approach ensures that luck provides a significant advantage without guaranteeing a specific outcome.

-----

## 3\) Predictability & Security 🔐

### Can the outcome be guessed?

No. While no computer-generated number is truly random, this service is designed to make outcomes **practically impossible to predict** by an exploiter, even if they have the source code.

### How is this achieved?

  * **Server-Side Authority:** All calculations happen on the server. The client has no control over the process.
  * **Per-Roll Seeded RNG:** Instead of using the global `math.random()`, each call to `Roll` creates its own unique `Random.new(seed)` instance. The seed is generated using a mix of unpredictable, server-only information:
      * `HttpService:GenerateGUID()`: A unique ID generated by the server.
      * `tick()`: The server's high-precision clock time.
      * `_rollCounter`: A private counter that increments on every roll from **any player**.
      * `playerUserId`: The specific player's ID.

> This blending of entropy sources means an exploiter cannot know the "secret ingredients" the server uses to create the random seed, making the outcome secure.

-----

## 4\) API Reference 📚 

All functions are on the main `LuckService` module. The primary way to use the service is by passing an `options` table to the `Roll` or `RollSummary` functions.

### Core Functions

  * `Roll(options: table) -> table?`
      * Performs the entire luck operation and returns the **single best rarity entry** found. The entry is a table containing `{ Name: string, Config: {} }`.
  * `RollSummary(options: table) -> table?`
      * Performs the same operation but returns a **detailed summary table** containing `LuckDetails`, `RollsMade`, `AllRolls`, `BestRoll`, etc.

### `options` Table Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `BaseLuck` | `number` | `1` | The starting number of rolls. |
| `RarityPool` | `table` | **Required** | The dictionary of rarities to roll from. |
| `LuckMultiplier` | `number` | `1` | Multiplies `BaseLuck` to get more rolls. |
| `LuckBooster` | `number` | `1` | Divisor to improve roll quality (higher is better). |
| `RarityBooster`| `table` | `nil` | Dictionary of rarities to boost, e.g., `{ Rare = 5 }`. |
| `LuckCap` | `number` | `100` | The absolute maximum number of rolls allowed. |
| `PlayerUserId` | `number` | `nil` | Player's `UserId` for enhanced RNG security. |
| `eventName` | `string` | `nil` | Name of an active event to include `EventOnly` rarities. |

-----

## 5\) Examples ✨

```lua
-- Assuming you've required the LuckService and your Rarities config table
local LuckService = require(ServerScriptService.LuckService)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-- A player is about to open a chest
local player = ... -- Get the player object
local playerBaseLuck = 5 -- e.g., from a player stat

--== Example 1: A simple, standard roll ==--
local summary = LuckService:RollSummary({
    BaseLuck = playerBaseLuck,
    RarityPool = Rarities,
    PlayerUserId = player.UserId
})
print(string.format("%s rolled %d times and got a %s!", player.Name, summary.RollsMade, summary.BestRoll.Name))


--== Example 2: A roll with a weekend x2 luck event and a potion boost ==--
local options = {
    BaseLuck = playerBaseLuck,
    RarityPool = Rarities,
    PlayerUserId = player.UserId,
    LuckMultiplier = 2.0, -- Weekend Event!
    LuckBooster = 1.5     -- Player used a "Lucky Potion"
}
local bestItem = LuckService:Roll(options)
print(string.format("With event and potion boosts, %s got a %s!", player.Name, bestItem.Name))


--== Example 3: An event roll with a specific rarity boost ==--
local eventOptions = {
    BaseLuck = 20,
    RarityPool = Rarities,
    PlayerUserId = player.UserId,
    EventName = "PixelFestival", -- This will include Pixel_* rarities
    RarityBooster = { Pixel_Mythic = 0.25 } -- Add a 0.25% chance to Pixel_Mythic
}
local eventSummary = LuckService:RollSummary(eventOptions)
print(string.format("During the %s, %s rolled a %s!", eventSummary.EventName, player.Name, eventSummary.BestRoll.Name))
```