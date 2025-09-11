--@author: yyumchi
--@date: 2025-09-10
--[[@description:
    Simple CollisionService (server-side). Keeps a map of base -> { players } and
    creates per-player NoCollisionConstraint(s) against the base's hitboxes.
    Provides targeted cleanup functions (remove only friend constraints, remove base entry, cleanup all).
]]
-----------------------------
-- TYPES (brief)
-----------------------------
type collection = { [string]: { Player } }

-----------------------------
-- VARIABLES --
-----------------------------
local CollisionService = {}

-- CONSTANTS --
local COLLISION_COLLECTION = {} :: collection -- [BaseName] = { Player, ... }

-----------------------------
-- PRIVATE HELPERS --
-----------------------------

local function _CreateConstraint(ConstraintName: string, BaseName: string)
    local Constraint = Instance.new("NoCollisionConstraint")
    -- consistent, searchable name: BaseName_ConstraintName_NoColl
    Constraint.Name = string.format("%s_%s_NoColl", tostring(BaseName), tostring(ConstraintName))
    return Constraint
end

local function _ReturnBaseHitbox(BaseModel: Model)
    if not BaseModel or not BaseModel:IsA("Model") then return {} end
    local hitboxes = {}
    local floors = BaseModel:FindFirstChild("Floors")
    if not floors then return hitboxes end
    for _, floor in ipairs(floors:GetChildren()) do
        -- accept either "Hitbox" or "HitBox"
        local hit = floor:FindFirstChild("Hitbox") or floor:FindFirstChild("HitBox")
        if hit and hit:IsA("BasePart") then
            table.insert(hitboxes, hit)
        end
    end
    return hitboxes
end

-- create constraints between every BasePart of character and a single hitbox part
local function _CreateForChar(Character: Model, HitboxPart: BasePart, ConstraintName: string, BaseName: string)
    if not Character or not HitboxPart then return end
    for _, v in ipairs(Character:GetDescendants()) do
        if v:IsA("BasePart") then
            local const = _CreateConstraint(ConstraintName, BaseName)
            const.Part0 = v
            const.Part1 = HitboxPart
            -- parent to player's character part to keep cleanup trivial
            const.Parent = v
        end
    end
end

-- removes constraints on a character that match the base+constraintName pattern
local function _RemoveConstraintsForPlayer(Character: Model?, BaseName: string, ConstraintName: string)
    if not Character then return end
    local pattern = ("%s_%s_NoColl"):format(tostring(BaseName), tostring(ConstraintName))
    for _, v in ipairs(Character:GetDescendants()) do
        if v:IsA("NoCollisionConstraint") and type(v.Name) == "string" and string.find(v.Name, pattern, 1, true) then
            v:Destroy()
        end
    end
end

-- remove all NoCollisionConstraints (any) on character created by this system for a given base (owner/friend both)
local function _RemoveAllBaseConstraintsForPlayer(Character: Model?, BaseName: string)
    if not Character then return end
    local basePrefix = tostring(BaseName) .. "_"
    for _, v in ipairs(Character:GetDescendants()) do
        if v:IsA("NoCollisionConstraint") and type(v.Name) == "string" and v.Name:sub(1, #basePrefix) == basePrefix then
            v:Destroy()
        end
    end
end

-- add constraints for player across all hitboxes of the base using given constraintName
local function _AddConstraints(BaseName: string, Player: Player, ConstraintName: string)
    local baseModel = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild(BaseName)
    if not baseModel then return end
    local hitboxes = _ReturnBaseHitbox(baseModel)
    -- ensure character exists
    local character = Player.Character or Player.CharacterAdded:Wait()
    for _, hb in ipairs(hitboxes) do
        _CreateForChar(character, hb, ConstraintName, BaseName)
    end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function CollisionService:Init()
    -- no-op for now; left for symmetry
end

function CollisionService:Start()
    -- no-op for now
end

-- Ensure collection entry exists for BaseName
function CollisionService:SetUpBase(BaseName: string)
    if not BaseName or BaseName == "" then return false end
    if not COLLISION_COLLECTION[BaseName] then
        COLLISION_COLLECTION[BaseName] = {}
    end
    return true
end

-- Retrieve bypass table (returns direct reference - caller should not mutate unexpectedly)
function CollisionService:GetBypassedFromBase(BaseName: string)
    return COLLISION_COLLECTION[BaseName] or nil
end

-- Add a player to the base bypass list and create constraints for them.
-- ConstraintName: e.g. "Owner" or "Friend" - used to selectively remove constraints later.
function CollisionService:AddBaseBypass(BaseName: string, Player: Player, ConstraintName: string)
    if not BaseName or not Player or not ConstraintName then return false end
    local list = COLLISION_COLLECTION[BaseName]
    -- avoid duplicates
    if table.find(list, Player) then
        -- still ensure constraints exist (in case they were cleared)
        _AddConstraints(BaseName, Player, ConstraintName)
        return true
    end
    table.insert(list, Player)
    _AddConstraints(BaseName, Player, ConstraintName)
    return true
end

-- Remove a player from a base's bypass list and remove only constraints matching ConstraintName
function CollisionService:RemoveBaseBypass(BaseName: string, Player: Player, ConstraintName: string)
    if not BaseName or not Player or not ConstraintName then return false end
    local list = COLLISION_COLLECTION[BaseName]
    if not list then return false end

    -- remove from table
    for i = #list, 1, -1 do
        if list[i] == Player then
            table.remove(list, i)
            break
        end
    end

    -- remove only constraints matching this constraint name (e.g. "Friend")
    _RemoveConstraintsForPlayer(Player.Character, BaseName, ConstraintName)
    return true
end

-- Remove only *friend* constraints (ConstraintName = "Friend") for every player listed on that base.
-- Constraints for "Owner" remain.
function CollisionService:RemoveFriendsConstraints(BaseName: string)
    if not BaseName then return false end
    local list = COLLISION_COLLECTION[BaseName]
    if not list then return false end
    for _, player in ipairs(list) do
        _RemoveConstraintsForPlayer(player.Character, BaseName, "Friend")
    end
    return true
end

-- Clean a single base: remove all constraints for all players and delete the entry (so base can be re-Setup)
function CollisionService:CleanBase(BaseName: string)
    if not BaseName then return false end
    local list = COLLISION_COLLECTION[BaseName]
    if list then
        for _, player in ipairs(list) do
            _RemoveAllBaseConstraintsForPlayer(player.Character, BaseName)
        end
    end
    COLLISION_COLLECTION[BaseName] = nil
    return true
end

-- Cleanup everything (intended to be called on BindToClose)
function CollisionService:CleanupAll()
    for baseName, list in pairs(COLLISION_COLLECTION) do
        for _, player in ipairs(list) do
            _RemoveAllBaseConstraintsForPlayer(player.Character, baseName)
        end
        COLLISION_COLLECTION[baseName] = nil
    end
    return true
end

-----------------------------
-- MAIN --
-----------------------------
return CollisionService
