if not qol then
    error("You cannot use qol_utilities.lua without loading the Quality of Life mod first")
end

-- Utility functions

qol.Utils = {}
qol.Utils.Data = {}
qol.Utils.Data.ForgetMeNow = "forget"

function qol.Utils.FindBossRoomIndex()
    local rooms = Game():GetLevel():GetRooms()
    
    for i = 0, #rooms do
        local room = rooms:Get(i)
        if room.Data.Type == RoomType.ROOM_BOSS then
            return room.GridIndex
        end
    end
    
    return nil
end

function qol.Utils.GetCurrentRoom()
    return Game():GetLevel():GetCurrentRoom()
end

function qol.Utils.GetCurrentRoomIndex()
    return Game():GetLevel():GetCurrentRoomIndex()
end

function qol.Utils.GetCurrentRoomDesc()
    return Game():GetLevel():GetCurrentRoomDesc()
end

function qol.Utils.GetCurrentRoomType()
    return qol.Utils.GetCurrentRoomDesc().Data.Type
end

function qol.Utils:ForgetMeNow(cmd)
    if cmd == qol.Utils.Data.ForgetMeNow then
        Game():GetPlayer(1):UseActiveItem(CollectibleType.COLLECTIBLE_FORGET_ME_NOW)
    end
end

function qol.Utils.IsRoom(roomType)
    return qol.Utils.GetCurrentRoomType() == roomType
end

qol:AddCallback(ModCallbacks.MC_EXECUTE_CMD, qol.Utils.ForgetMeNow)
