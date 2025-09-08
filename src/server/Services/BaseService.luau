--@author: yyumchi
--@date: 2025-09-06
--[[@description:
    BaseService
    - Maintains a registry of bases in workspace.Bases
    - Assigns free bases to players on join (simple allocation)
    - Frees assigned bases when players leave
]]
-----------------------------
-- VARIABLES --
-----------------------------
local PlayerDataService = require(script.Parent.PlayerDataService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local workspace = game:GetService("Workspace")
local Packets = require(ReplicatedStorage.Shared.Packets)
local ServerBase = require(ServerScriptService.Libs.ServerBase)



local BaseService = {}

-- Map of unoccupied bases: [baseName] = BaseModel
local UnOpcupiedBases = {} :: { [string]: Instance }

-- Map of assigned bases: [player] = BaseModel
local AssignedBases = {} :: { [Player]: ServerBase.ServerBase}

-- CONSTANTS --
local BASES_FOLDER_NAME = "Bases"

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Populate UnOpcupiedBases from workspace.Bases
local function _rebuildUnoccupiedCache()

    local basesFolder = workspace:FindFirstChild(BASES_FOLDER_NAME)
    if not basesFolder then
        warn("[BaseService] workspace." .. BASES_FOLDER_NAME .. " not found.")
        return
    end

    for _, baseModel in ipairs(basesFolder:GetChildren()) do
        if baseModel.Configuration.Player.Value == nil then
            UnOpcupiedBases[baseModel.Name] = baseModel
        end
    end
end

-- Find first unoccupied base (optionally prefer a specific name)
local function _getFreeBase(preferredName: string?)
    -- prefer preferredName if provided and available
    if preferredName and UnOpcupiedBases[preferredName] then
        return UnOpcupiedBases[preferredName], preferredName
    end

    for name, model in pairs(UnOpcupiedBases) do
        return model, name
    end

    return nil, nil
end

-- Mark base as occupied (remove from UnOpcupiedBases)
local function _markBaseOccupied(baseModel)
    if not baseModel or not baseModel.Name then return end
    UnOpcupiedBases[baseModel.Name] = nil
end

-- Mark base unoccupied (add back to UnOpcupiedBases)
local function _markBaseFree(baseModel)
    if not baseModel or not baseModel.Name then return end
    UnOpcupiedBases[baseModel.Name] = baseModel
end

-- Helper: set the Configuration.Player.Value on the baseModel to the player (or nil to clear)
local function _setBaseOwner(baseModel, player)
    if not baseModel then return false end

    local config = baseModel:FindFirstChild("Configuration")
    if not config then
        warn(("[BaseService] Base '%s' missing Configuration; cannot set owner"):format(baseModel:GetFullName()))
        return false
    end

    local playerValue = config:FindFirstChild("Player")

    playerValue.Value = player
    return true
end

-- Helper: Replace the workspace baseModel with a template from ReplicatedStorage.Bases
local function _replaceWorkspaceBaseWithTemplate(baseModel: Model, playerRebirths: number)
	if not baseModel or not baseModel:IsA("Model") then
		return baseModel -- nothing to do
	end
    
	local basesFolder = ReplicatedStorage:WaitForChild("Bases")

	-- Try to find a template container that matches the baseModel's name (ex: "Base1")
	local templateContainer = basesFolder:FindFirstChild(baseModel.Name)

	-- Try to find a model inside the template container - prefer "CommonBase"
	local templateModel = templateContainer:FindFirstChild("CommonBase"):GetChildren()[1]

	-- Clone the template
	local clone = templateModel:Clone()
	clone.Name = baseModel.Name -- keep the same workspace name

    -- Clamp rebirths: allow at least Floor1 to remain
	local keepUpTo = math.max(1, playerRebirths)

	-- If clone has a Floors folder, delete floors greater than keepUpTo
	local floorsFolder = clone:FindFirstChild("Floors")
	if floorsFolder then
		for _, floor in pairs(floorsFolder:GetChildren()) do
			-- assume naming like "Floor1", "Floor2", ...
			local num = tonumber(string.match(floor.Name, "%d+"))
			if num and num > keepUpTo then
				floor:Destroy()
			end
		end
	end

    -- Remove the original model from workspace
	baseModel:Destroy()

	-- Parent clone into workspace.Bases and then destroy original
	local workspaceBases = workspace:FindFirstChild("Bases")
	clone.Parent = workspaceBases

	return clone
end

-- Updated function: _assignBaseInternal
local function _assignBaseInternal(player: Player, preferredBaseName: string?)
	if not player then return nil end

	-- don't reassign if player already has a base
	if AssignedBases[player] then
		return AssignedBases[player]
	end

	-- find a free base in workspace
	local baseModel, _baseName = _getFreeBase(preferredBaseName)
	if not baseModel then
		warn(("[BaseService] No free bases available to assign to player %s"):format(player.Name))
		return nil
	end

	-- read player's rebirths from leaderstats (safe)
    local PlayerData = PlayerDataService:GetPlayerData(player)
	local rebirths = PlayerData.Rebirths

    if not rebirths then

        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local rebValue = leaderstats:FindFirstChild("Rebirths")
            if rebValue and typeof(rebValue.Value) == "number" then
                rebirths = rebValue.Value
            end
        end
    else
        rebirths = rebirths.Value
    end
	

	-- Replace the workspace base with template from ReplicatedStorage.Bases (per-player customization)
	local finalBaseModel = _replaceWorkspaceBaseWithTemplate(baseModel, rebirths)
	if not finalBaseModel then
		warn(("[BaseService] Failed to prepare base for player %s"):format(player.Name))
		return nil
	end

	-- Attempt to set owner
	local ok = _setBaseOwner(finalBaseModel, player)
	if not ok then
		warn(("[BaseService] Failed to set owner on base '%s' for player %s"):format(finalBaseModel.Name, player.Name))
		return nil
	end

	_markBaseOccupied(finalBaseModel)
	AssignedBases[player] = ServerBase:Init({
        Owner = player,
        BaseModel = finalBaseModel,
        playerData = { BaseSlots = PlayerData.BaseSlots, BaseLevel = rebirths, BaseState = "Closed" }
    } :: ServerBase.InitPreq)

    AssignedBases[player]:Start()

	-- set respawn location and pivot the character to Floor1 spawn (if available)
	player.RespawnLocation = finalBaseModel.Spawn 
    player.CharacterAdded:Wait():PivotTo(finalBaseModel.Floors.Floor1.Build.Spawn.SpawnPoint:GetPivot())

	return finalBaseModel
end

local function _MakepreferredBaseName(AssignedBaseId:number)
    local preferredBaseName = AssignedBaseId > 0 and "Base" .. AssignedBaseId or ""
    
    return preferredBaseName
end


-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function BaseService:Init()
    -- Build initial unoccupied base cache
    _rebuildUnoccupiedCache()

    Players.PlayerAdded:Connect(function(plr)
        local plrdata = PlayerDataService:GetPlayerData(plr) 

        BaseService:AssignBaseToPlayer(plr, _MakepreferredBaseName(plrdata.AssignedBaseId))
    end)

    Players.PlayerRemoving:Connect(function(plr)
        BaseService:FreePlayerBase(plr)
    end)

    Packets.ReqBaseData.queries.ReqData.listen(function(msg, player)
        
        local plrtofind = AssignedBases[player]

        if plrtofind then
            return plrtofind:ReturnBaseData(msg)
        end

        return {
                Msg = "Player Does Not Have A Base",
                Owner = plrtofind.Owner.UserId,
                BaseModel = "",
                playerData = {
                    BaseLevel = 0,
                    BaseSlots = 0,
                    BaseState = "unknown"
                }
            }
    end)

end

function BaseService:Start()
    -- runtime code if you want to tick or maintain states.
    -- For now, BaseService is event-driven so no periodic loop is necessary.
    print("[BaseService] Started. Available bases:", (function() local n=0; for _ in pairs(UnOpcupiedBases) do n=n+1 end; return n end)())
end

-- Public API: assign base on demand; returns assigned base model or nil
function BaseService:AssignBaseToPlayer(player:Player, preferredBaseName:string)
    if not player then return nil end
    return _assignBaseInternal(player, preferredBaseName)
end

-- Public: free base for a player (used on leave or manual clear)
function BaseService:FreePlayerBase(player:Player)
    if not player then return false end
    local baseModel = AssignedBases[player].BaseModel
    if not baseModel then
        -- try to find base by scanning workspace (in case mapping lost)
        local basesFolder = workspace:FindFirstChild(BASES_FOLDER_NAME)
        if basesFolder then
            for _, bm in ipairs(basesFolder:GetChildren()) do
                local cfg = bm:FindFirstChild("Configuration")
                if cfg then
                    local pv = cfg:FindFirstChild("Player")
                    if pv and pv.Value == player then
                        baseModel = bm
                        break
                    end
                end
            end
        end
    end

    if not baseModel then
        -- nothing to free
        AssignedBases[player] = nil
        return false
    end

    -- clear owner
    _setBaseOwner(baseModel, nil)
    AssignedBases[player] = nil
    _markBaseFree(baseModel)

    print(("[BaseService] Freed base '%s' from player %s"):format(baseModel.Name, player.Name))
    return true
end

function BaseService:RefreshBase(player:Player)
    if not player then return end

    BaseService:FreePlayerBase(player)

	local baseModel = AssignedBases[player].BaseModel
	if not baseModel then
		warn(("[BaseService] No free bases available to assign to player %s"):format(player.Name))
		return nil
	end

	-- read player's rebirths from leaderstats (safe)
    local PlayerData = PlayerDataService:GetPlayerData(player)

    if not baseModel or not baseModel:IsA("Model") then
		return baseModel -- nothing to do
	end
    
	local basesFolder = ReplicatedStorage:WaitForChild("Bases")

	-- Try to find a template container that matches the baseModel's name (ex: "Base1")
	local templateContainer = basesFolder:FindFirstChild(baseModel.Name)

	-- Try to find a model inside the template container - prefer "CommonBase"
    local PlrBaseType = PlayerData.BaseType .. "Base"
	local templateModel = templateContainer:FindFirstChild(PlrBaseType):GetChildren()[1]

	-- Clone the template
	local clone = templateModel:Clone()
	clone.Name = baseModel.Name -- keep the same workspace name

    -- Clamp rebirths: allow at least Floor1 to remain
	local keepUpTo = math.max(1, PlayerData.Rebirths.Value)
    --local KeepUpTo2 = math.max(6, PlayerData.BaseSlots)
    --whenever we get a better module base then we can TODO: remove 2 slots so it visually shows for the gamepass 

	-- If clone has a Floors folder, delete floors greater than keepUpTo
	local floorsFolder = clone:FindFirstChild("Floors")

	if floorsFolder then
		for _, floor in pairs(floorsFolder:GetChildren()) do
			-- assume naming like "Floor1", "Floor2", ...
			local num = tonumber(string.match(floor.Name, "%d+"))
			if num and num > keepUpTo then
				floor:Destroy()
			end
		end
	end

    baseModel:Destroy()

	-- Parent clone into workspace.Bases and then destroy original
	local workspaceBases = workspace:FindFirstChild("Bases")
	clone.Parent = workspaceBases

    local ok = _setBaseOwner(clone, player)
	if not ok then
		warn(("[BaseService] Failed to set owner on base '%s' for player %s"):format(clone.Name, player.Name))
		return nil
	end

	_markBaseOccupied(clone)
	AssignedBases[player] = ServerBase:Init({
        Owner = player,
        BaseModel = clone,
        playerData = { BaseSlots = PlayerData.BaseSlots, BaseLevel = PlayerData.Rebirths.Value, BaseState = "Closed" }
    } :: ServerBase.InitPreq)

    AssignedBases[player]:Start()
	
    return baseModel
end

-----------------------------
-- MAIN --
-----------------------------
return BaseService
