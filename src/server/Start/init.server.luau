--!strict
-- Start / bootstrap script for ModuleLoader (server entry)
-- Drops into ServerScriptService.StartServer via Rojo mapping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local ModuleLoader = require(ReplicatedStorage.ModuleLoader)


-- Ensure clients that wait for the server will block until loader finishes.
-- Leave as false or nil until the loader sets it to true.
Workspace:SetAttribute("ServerLoaded", false)

ModuleLoader.ChangeSettings({
	FOLDER_SEARCH_DEPTH = 3,    -- how deep in folders the loader will scan
	YIELD_THRESHOLD = 2,        -- warn if module Init/Start yields longer than this
	VERBOSE_LOADING = false,    -- set true while debugging load order
	WAIT_FOR_SERVER = true,     -- clients will wait for `workspace.ServerLoaded`
	USE_COLLECTION_SERVICE = false,
})


ModuleLoader.Start(ServerScriptService.Services)
