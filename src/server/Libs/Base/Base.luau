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
    Owner: Player,
    BaseModel: Model,
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

-----------------------------
-- PUBLIC FUNCTIONS --

function Base:Init(Req:InitPreq)
    -- initialization code
    local _self = setmetatable({}, Base)
    _self.Owner = Req.Owner
    _self.BaseModel = Req.BaseModel
    _self.BaseId = _self.BaseModel.Name
    _self.Level = Req.playerData.BaseLevel or 1
    _self.BaseSlots = Req.playerData.BaseSlots
    _self.BaseState = Req.playerData.BaseState
    
    warn("init successful", _self)
    return _self
end

function Base:Start()
    -- start / runtime code
end

-----------------------------
--MAIN--
-----------------------------

return Base