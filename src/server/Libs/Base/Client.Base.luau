--@author: yyumchi
--@date: 2025-09-07
--[[@description:
    Client-specific Base class. Inherits from Shared Base.
    - Creates client-only visuals (owner arrow).
    - If the local player owns this base, sets the local character into OwnerBypass collision group.
    - Assumes collision groups (OwnerBypass) are created on server setup.
]]
-----------------------------
-- VARIABLES --
-----------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Packets)

local ClientBase = {}
ClientBase.LocalPlayerData = {}


 type InitPreq = {
    Owner: Player,
    BaseModel: Model,
    playerData: {
        BaseSlots: number?,
        BaseLevel: number?,
        BaseState: string?
    }
}

export type ClientBase = {
    _client: {
        internalId: string,
    },
    Init: (params: InitPreq) -> ClientBase,
    Start: (self: ClientBase) -> (),
}

-- CONSTANTS --
local GROUP_OWNER_BYPASS = "OwnerBypass"

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function _CreateOwnerArrow(BaseModel:Model)
    if not BaseModel then return end
    local ownerFolder = BaseModel:FindFirstChild("Owner")

    local OwnerGui = Instance.new("BillboardGui")
    OwnerGui.Name = "OwnerGui"
    OwnerGui.Active = true
    OwnerGui.ResetOnSpawn = false
    OwnerGui.ExtentsOffset = Vector3.new(0.00, 1.50, 0.00)
    OwnerGui.LightInfluence = 1
    OwnerGui.AlwaysOnTop = true
    OwnerGui.Size = UDim2.fromScale(8.00, 4.00)
    OwnerGui.MaxDistance = 1000
    OwnerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    OwnerGui.Parent = ownerFolder

    local YourBase = Instance.new("TextLabel")
    YourBase.Name = "YourBase"
    YourBase.TextWrapped = true
    YourBase.BorderSizePixel = 0
    YourBase.TextScaled = true
    YourBase.BackgroundColor3 = Color3.new(1.00, 1.00, 1.00)
    YourBase.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    YourBase.AnchorPoint = Vector2.new(0.50, 0.50)
    YourBase.TextSize = 30
    YourBase.Size = UDim2.fromScale(1.00, 0.5)
    YourBase.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
    YourBase.Text = "Your Base"
    YourBase.TextColor3 = Color3.new(1.00, 1.00, 1.00)
    YourBase.BackgroundTransparency = 1
    YourBase.Position = UDim2.fromScale(0.50, 0.25)
    YourBase.Parent = OwnerGui

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.new(0.07, 0.07, 0.08)
    UIStroke.Thickness = 5
    UIStroke.Parent = YourBase

    local Arrow = Instance.new("TextLabel")
    Arrow.Name = "Arrow"
    Arrow.TextWrapped = true
    Arrow.BorderSizePixel = 0
    Arrow.TextScaled = true
    Arrow.BackgroundColor3 = Color3.new(1.00, 1.00, 1.00)
    Arrow.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    Arrow.AnchorPoint = Vector2.new(0.50, 0.50)
    Arrow.TextSize = 30
    Arrow.Size = UDim2.fromScale(1.00, 0.50)
    Arrow.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
    Arrow.Text = "↓"
    Arrow.TextColor3 = Color3.new(1.00, 1.00, 1.00)
    Arrow.BackgroundTransparency = 1
    Arrow.Position = UDim2.fromScale(0.50, 0.75)
    Arrow.Parent = OwnerGui

    local UIStroke_1 = Instance.new("UIStroke")
    UIStroke_1.Color = Color3.new(0.07, 0.07, 0.08)
    UIStroke_1.Thickness = 5
    UIStroke_1.Parent = Arrow
end

-- Apply OwnerBypass collision group to every BasePart of the local player's character
local function _applyOwnerBypassToCharacter(character: Model)
    if not character then return end
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.CollisionGroup = GROUP_OWNER_BYPASS
        end
    end
end

local function _RetrieveBase(BaseName:string)
    return workspace.Bases:FindFirstChild(BaseName)
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function ClientBase:Init()

    local params = Packets.ReqBaseData.queries.ReqData.invoke("RequestBaseData")

    if params["Msg"] ~= "success" then
        warn(params["Msg"])
        -- basically trying again in another 5 secs
    end

    ClientBase.Owner = Players:GetPlayerByUserId(params.Owner)
    ClientBase.BaseModel = _RetrieveBase(params.BaseModel)
    ClientBase.BaseId = ClientBase.BaseModel.Name
    ClientBase.Level = params.playerData.BaseLevel or 1
    ClientBase.BaseSlots = params.playerData.BaseSlots
    ClientBase.BaseState = params.playerData.BaseState

    return ClientBase
end

function ClientBase:Start()
    -- client-side visuals
    _CreateOwnerArrow(self.BaseModel)

    -- If the local player is the owner, ensure their character is placed into OwnerBypass
    local localPlayer = Players.LocalPlayer
    if localPlayer and self.Owner and localPlayer.UserId == self.Owner.UserId then
        -- apply immediately if character exists
        if localPlayer.Character or localPlayer.CharacterAdded:Wait() then
            _applyOwnerBypassToCharacter(localPlayer.Character)
        end
        
        -- keep applied on respawn
        localPlayer.CharacterAdded:Connect(function(char)
            char:WaitForChild("HumanoidRootPart", 5)
            _applyOwnerBypassToCharacter(char)
        end)
    end
end

-----------------------------
--MAIN--
-----------------------------
return ClientBase
