--!strict
-- Simple TestService to exercise LuckService
-- This service demonstrates how to call LuckService and prints results

local ServerScriptService = game:GetService("ServerScriptService")

-- Require the LuckService (lib) from ServerScriptService.Libs
-- (Rojo mapping: src/server/Libs -> ServerScriptService.Libs)
local LuckService = require(ServerScriptService.Libs.LuckService)

local Module = {}

function Module:Init()
	-- no-op for now
end

function Module:Start()
	-- Basic test: run a few rolls under different conditions
	print("[TestService] Starting luck tests...")

	-- 1) baseline luck (default)
	local summary, _data = LuckService.RollSummary()
	print("[TestService] Default roll ->", summary)

	-- 2) bump base luck to 2.5
	LuckService.SetBaseLuck(2.5)
	local summary2 = LuckService.RollSummary()
	print("[TestService] After SetBaseLuck(2.5) ->", summary2)

	-- 3) test event multiplier (x2) for a fake event "PixelFestival"
	LuckService.SetEventMultiplier("PixelFestival", 2.0, 10) -- lasts 10s
	local summary3 = LuckService.RollSummary({ eventName = "PixelFestival" })
	print("[TestService] During PixelFestival (x2 event multiplier) ->", summary3)

	-- 4) test player-specific luck (user id 12345)
	LuckService.SetPlayerLuck(12345, 3.0, 5) -- temporary
	local summary4 = LuckService.RollSummary({ playerUserId = 12345 })
	print("[TestService] Player 12345 with x3 luck ->", summary4)

	-- 5) run a short randomized batch to see distribution
	print("[TestService] Batch sampling (20 rolls) with current multipliers...")
	for i = 1, 20 do
		local s, _d = LuckService.RollSummary({ eventName = "PixelFestival", playerUserId = 12345 })
		print("[TestService] Roll", i, s)
	end

	-- reset base luck for safety (optional)
	LuckService.SetBaseLuck(1.0)

	print("[TestService] Luck tests finished.")
end

return Module
