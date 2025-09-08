--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ModuleLoader = require(ReplicatedStorage.ModuleLoader)

-- you can optionally modify settings (also change it via the attributes on ModuleLoader)
ModuleLoader.ChangeSettings({
	FOLDER_SEARCH_DEPTH = 3,
	YIELD_THRESHOLD = 10,
	VERBOSE_LOADING = true,
	WAIT_FOR_SERVER = true
})
-- pass any containers for your custom services to the Start() function
ModuleLoader.Start(StarterPlayer.StarterPlayerScripts.Services)