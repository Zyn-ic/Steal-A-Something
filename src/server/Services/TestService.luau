--@author: yyumchi
--@date: 2025-09-03
--[[@description:
	Short description here.
]]
-----------------------------
-- VARIABLES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LuckService = require(ServerScriptService.Libs.LuckService)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestService = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --

-----------------------------
-- PUBLIC FUNCTIONS --

function TestService:Init()
	-- initialization code
end

function TestService:Start()
	-- start / runtime code
	print("--- Performing a normal roll ---")
	local normalRollSummary = LuckService:RollSummary({
		BaseLuck = 2,
		RarityPool = Rarities,
		LuckMultiplier = 2,
	})

	if normalRollSummary and normalRollSummary.BestRoll then
		print("Best normal roll:", normalRollSummary.BestRoll.Name)
	end

	-- Example 2: A roll during the "Pixel" event
	print("\n--- Performing a roll during the Pixel event ---")
	local eventRollSummary = LuckService:RollSummary({
		BaseLuck = 10,
		RarityPool = Rarities,
		LuckMultiplier = 2,
		EventName = "PixelFestival" -- This activates the EventOnly items
	})

	if eventRollSummary and eventRollSummary.BestRoll then
		print("Best event roll:", eventRollSummary.BestRoll.Name)
		print("VFX:", eventRollSummary.BestRoll.Config.VFX)
		print("Announcement:", eventRollSummary.BestRoll.Config.ChatAnnouncement)
	end
end

-----------------------------
--MAIN--
-----------------------------

return TestService