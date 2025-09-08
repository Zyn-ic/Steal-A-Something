
--@author: yyumchi
--@date: 2025-09-07
--[[@description:
    Short description here.
]]

-----------------------------
-- VARIABLES --
-----------------------------
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Base = require(ReplicatedStorage.Shared.Base)
local ServerBase = {}
ServerBase.__index = ServerBase
setmetatable(ServerBase, { __index = Base }) -- inherit

export type InitPreq = Base.InitPreq
export type Base = Base.BaseInstance

export type ServerBase = Base & {
    _server: {
        internalId: string,
    },
    Init: (params: InitPreq) -> ServerBase,
    Start: (self: ServerBase) -> (),
    SetState: (string) -> (),
    ReturnBaseData: (Msg:string) -> (InitPreq, string)

}


-- CONSTANTS --

local GROUP_BASE_OPEN = "Open"
local GROUP_BASE_CLOSED = "Closed"

-----------------------------
-- PRIVATE FUNCTIONS --

-- Collects base parts that should be assigned to a collision group.
local function _collectBaseParts(baseModel: Model)
    local parts = {}
    if not baseModel then
        return parts
    end

    for _, desc in ipairs(baseModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            table.insert(parts, desc)
        end
    end
    return parts
end

-- Assigns given collision group to all relevant parts of the base.
-- NOTE: collision groups must exist (created by a one-time setup).
local function _setBaseCollisionGroup(baseModel: Model, groupName: string)
    if not baseModel then return end
    local Floors = baseModel:FindFirstChild("Floors")
    
    for _, Floor in ipairs(Floors:GetChildren()) do
        local hitbox = Floor:FindFirstChild("HitBox")
        if hitbox then
            hitbox.CollisionGroup = groupName
        end
    end
    
end

local function _CreateBaseOwnerLabel(BaseModel:Model, PlayerName:string)
    if not BaseModel then return end

    local SurfaceGui = Instance.new("SurfaceGui")
    SurfaceGui.LightInfluence = 1
    SurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    SurfaceGui.ClipsDescendants = true
    SurfaceGui.MaxDistance = 1000
    SurfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SurfaceGui.Parent = BaseModel:FindFirstChild("Owner")

    local Name = Instance.new("TextLabel")
    Name.Name = "Name"
    Name.TextWrapped = true
    Name.BorderSizePixel = 0
    Name.RichText = true
    Name.TextScaled = true
    Name.BackgroundColor3 = Color3.new(1, 1, 1)
    Name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    Name.TextDirection = Enum.TextDirection.LeftToRight
    Name.TextSize = 100
    Name.Size = UDim2.fromOffset(1850, 350)
    Name.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
    Name.Text = PlayerName
    Name.TextColor3 = Color3.new(1, 1, 1)
    Name.BackgroundTransparency = 1
    Name.Position = UDim2.fromOffset(0, 10)
    Name.Parent = SurfaceGui
end

local function _RemoveBaseOwnerLabel(BaseModel:Model)
    if not BaseModel then return end
    local visualstuff = BaseModel:FindFirstChild("Owner")
    for _, v in visualstuff:GetChildren() do
        Debris:AddItem(v) 
    end
end

-----------------------------
-- PUBLIC FUNCTIONS --

function ServerBase:Init(params)
    -- initialization code
    local _self = Base.Init(self, params)  -- 'self' is BaseShared table here, returns a Base instance
    setmetatable(_self, ServerBase) -- change metatable so method lookups use ServerBase
    
    -- server-specific runtime state
    _self._server = {}
    _self._server.internalId = "srv_" .. tostring(tick())
    _self._server.LastDataRequest = 0

    return _self
end

function ServerBase:Start()
    -- start / runtime code
    _CreateBaseOwnerLabel(self.BaseModel, self.Owner.DisplayName)

    if self.BaseState == "Opened" then
        _setBaseCollisionGroup(self.BaseModel, GROUP_BASE_OPEN)
    else
        _setBaseCollisionGroup(self.BaseModel, GROUP_BASE_CLOSED)
    end
end

function ServerBase:SetState(newState)
    if newState ~= "Opened" and newState ~= "Closed" then return end
    self.BaseState = newState
    if newState == "Opened" then
        _setBaseCollisionGroup(self.BaseModel, GROUP_BASE_OPEN)
    else
        _setBaseCollisionGroup(self.BaseModel, GROUP_BASE_CLOSED)
    end
end

function ServerBase:ReturnBaseData(Req:string)
    if Req ~= "RequestBaseData" then return {
                Msg = "invalid",
                Owner = self.Owner.UserId,
                BaseModel = "",
                playerData = {
                    BaseLevel = 0,
                    BaseSlots = 0,
                    BaseState = "unknown"
                }
            } end

    local _timenow = os.clock()
    --

    if (_timenow - self._server.LastDataRequest) >= 5 or self._server.LastDataRequest == 0 then
        -- if you asked for data 5secs or more ago or this is your first time asking for a data request
        self._server.LastDataRequest = _timenow
            return {
                Msg = "success",
                Owner = self.Owner.UserId,
                BaseModel = self.BaseId,
                playerData = {
                    BaseLevel = self.Level,
                    BaseSlots = self.BaseSlots,
                    BaseState = self.BaseState
                }
            }
    end

    return {
                Msg = "cooldown",
                Owner = self.Owner.UserId,
                BaseModel = "",
                playerData = {
                    BaseLevel = 0,
                    BaseSlots = 0,
                    BaseState = "unknown"
                }
            }
end

-----------------------------
--MAIN--
-----------------------------

return ServerBase