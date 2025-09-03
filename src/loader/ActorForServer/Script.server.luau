--!strict
--@author: crusherfire
--@date: 5/8/24
--[[@description:
	General code for loading parallel module scripts.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ParallelModuleLoader = require(ReplicatedStorage.ModuleLoader.ParallelModuleLoader)

-----------------------------
-- VARIABLES --
-----------------------------
local actor = script.Parent

-----------------------------
-- HANDLERS --
-----------------------------
actor:BindToMessage("RequireModule", function(module: ModuleScript)
	ParallelModuleLoader.onRequireModule(script, module)
end)

actor:BindToMessage("InitModule", function()
	ParallelModuleLoader.onInitModule(script)
end)

actor:BindToMessage("StartModule", function()
	ParallelModuleLoader.onStartModule(script)
end)

-----------------------------
-- MAIN --
-----------------------------
script:SetAttribute("Loaded", true)