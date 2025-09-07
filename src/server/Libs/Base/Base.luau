--@author: yyumchi
--@date: 2025-09-06
--[[@description:
    Short description here.
]]

-----------------------------
-- TYPES
-----------------------------

export type BaseState = "Opened" | "Closed"

export type InitPreq = {
    owner: Player,
    baseModel: Model,
    playerData: {
        BaseSlots: number?,
        BaseLevel: number?,
        BaseState: BaseState?
    }
}

export type BaseInstance = {
    Owner: Player,
    BaseModel: Model,
    BaseId: string,
    Level: number,
    BaseSlots: number,
    BaseState: BaseState,

    Init: (self: any, req: InitPreq) -> any,
    Start: (self: any) -> ()
}

-----------------------------
-- VARIABLES --
-----------------------------
local Debris = game:GetService("Debris")
local Base = {}

Base.__index = Base

Base.__tostring = function(self)
    local ownerName = (self.Owner and (self.Owner.Name or self.Owner.DisplayName)) or "Unknown"
    local baseId = self.BaseId or "Unknown"
    local level = tostring(self.Level or "N/A")
    local slots = tostring(self.BaseSlots or "N/A")
    local state = tostring(self.BaseState or "Closed")
    return string.format("<Base Id=%s Owner=%s Level=%s Slots=%s State=%s>", baseId, ownerName, level, slots, state)
end

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --

local function CreateBaseOwnerLabel(BaseModel:Model, PlayerName:string)
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

local function CreateOwnerArrow(BaseModel:Model)

    if not BaseModel then return end
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
    OwnerGui.Parent = BaseModel:FindFirstChild("Owner")

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

local function RemoveBaseOwnerLabel(BaseModel:Model)
    if not BaseModel then return end
    local visualstuff = BaseModel:FindFirstChild("Owner")
    for _, v in visualstuff:GetChildren() do
        Debris:AddItem(v)
    end
end

-----------------------------
-- PUBLIC FUNCTIONS --

function Base:Init(Req:InitPreq)
    -- initialization code
    local self = setmetatable({}, Base)
    self.Owner = Req.owner
    self.BaseModel = Req.baseModel
    self.BaseId = self.BaseModel.Name
    self.Level = Req.playerData.BaseLevel or 1
    
    warn("init successful", self)
    return self
end

function Base:Start()
    -- start / runtime code
    CreateBaseOwnerLabel(self.BaseModel, self.Owner.DisplayName)
end

-----------------------------
--MAIN--
-----------------------------

return Base