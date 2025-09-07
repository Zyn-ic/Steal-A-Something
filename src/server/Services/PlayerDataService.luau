-- PlayerDataService.luau
--@author: yyumchi
--@date: 2025-09-04
-- Short description: Manages runtime player data.

-----------------------------
-- VARIABLES --
-----------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Shared.Packages.Janitor)

local PlayerDataService = {}

export type PlayerData = {
    JoinTime : number,
    BaseLuck : number,
    LuckCapOverride : number,

    AssignedBaseId : number,
    BaseSlots : number,
    DoorCloseDuration : number,
    AllowFriends : boolean,

    Gold : IntValue,
    Diamonds : IntValue,
    Steals : IntValue,
    Rebirths : IntValue
}

export type PlayerDataTable = {[Player]: PlayerData}
-- CONSTANTS --
local PlayerData:PlayerDataTable = {}
local ServerJanitor

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
function GetPlayerData(plr: Player): PlayerData
    return PlayerData[plr]
end

function RemovePlayerData(plr: Player): nil
    PlayerData[plr] = nil
    if Players:GetPlayers()[plr] then plr:Destroy() end
    return
end

function OnPlayerAdded(plr:Player)
        print("Creating data for", plr.Name)

        local dataFolder = Instance.new("Folder")
        dataFolder.Name = "leaderstats"

        local _self = {
            JoinTime = os.time(),
            BaseLuck = 1,
            LuckCapOverride = 8,

            AssignedBaseId = 0,
            BaseSlots = 6,
            DoorCloseDuration = 60,
            AllowFriends = false,
            ConstantBaseNumber = 1,

            Gold = Instance.new("IntValue"),
            Diamonds = Instance.new("IntValue"),
            Steals = Instance.new("IntValue"),
            Rebirths = Instance.new("IntValue"),
        }

        _self.Gold.Name = "Gold"; _self.Gold.Value = 1000
        _self.Diamonds.Name = "Diamonds"; _self.Diamonds.Value = 1000
        _self.Steals.Name = "Steals"; _self.Steals.Value = 0
        _self.Rebirths.Name = "Rebirths"; _self.Rebirths.Value = 0

        dataFolder.Parent = plr
        _self.Gold.Parent = dataFolder
        _self.Diamonds.Parent = dataFolder
        _self.Steals.Parent = dataFolder
        _self.Rebirths.Parent = dataFolder

        PlayerData[plr] = _self
end

function OnPlayerRemoving(plr:Player)
    RemovePlayerData(plr)
end

function Clean()
    ServerJanitor:Destroy()
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function PlayerDataService:Init()
    print("PlayerDataService initializing...")
    -- store singleton fields directly on self
    ServerJanitor = Janitor.new()
    ServerJanitor:Add(function() 
        if next(PlayerData) ~= nil then
            table.clear(PlayerData)
        end
    end)
end

function PlayerDataService:Start()
    ServerJanitor:Add(Players.PlayerAdded:Connect(OnPlayerAdded))
    ServerJanitor:Add(Players.PlayerRemoving:Connect(OnPlayerRemoving))
    game:BindToClose(Clean)
end

function PlayerDataService:GetPlayerData(plr:Player): PlayerData | nil
    if GetPlayerData(plr) then
        return table.clone(PlayerData[plr])
    end

    return nil
end

-----------------------------
-- MAIN --
-----------------------------

return PlayerDataService
