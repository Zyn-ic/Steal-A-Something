
--@author: yyumchi
--@date: 2025-09-07
--[[@description:
    Short description here.
]]
-----------------------------
-- VARIABLES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Bytenet = require(ReplicatedStorage.Shared.Packages.Bytenet)
return {

    ReqBaseData = Bytenet.defineNamespace("ReqBaseData", function()
        return {
            packets = {},
            queries = {
                ReqData = Bytenet.defineQuery({
                    request = Bytenet.string,
                    response = Bytenet.struct({
                        Msg = Bytenet.string,
                        Owner = Bytenet.uint32,
                        BaseModel = Bytenet.string,
                        playerData = Bytenet.struct({
                            BaseLevel = Bytenet.uint8,
                            BaseSlots =  Bytenet.uint8,
                            BaseState = Bytenet.string
                        })
                    })
                })
            }
        }
    end)
}