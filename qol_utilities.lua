if not qol then
    error("You cannot use qol_utilities.lua without loading the Quality of Life mod first")
end

local json = require("json")

-- Utility functions

qol.Utils = {}
qol.Utils.Data = {}
qol.Utils.Data.ForgetMeNow = "forget"
qol.Utils.Data.GlowingHourGlass = "glow"
qol.Utils.Data.WhiteRooms = {}

function qol.Utils:GlowingHourGlass(cmd)
    if cmd == qol.Utils.Data.GlowingHourGlass then
        qol.Player(1):UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS)
    end
end

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

-- Return the grid indices at which doors could naturally appear. Note that this
-- doesn't take into account whether a door can actually be put there.
function qol.Utils.DoorSlotsIn1x1()
    return {7, 60, 74, 127}
end

-- Red/white rooms helpers

function qol.Utils:SaveWhiteRooms()
    if Game():IsGreedMode() then
        return
    end

    local rooms = Game():GetLevel():GetRooms()
    
    local data = {}
    data.Rooms = {}
    
    for i = 0, #rooms - 1 do
        local room = rooms:Get(i)
        -- print ("Room " .. room.GridIndex .. " is a normal room")
        -- Hey, did you know that the game doesn't have multiple indices for a
        -- non 1x1 room, but instead uses the top-left corner as the grid index
        -- for all the rooms?
        -- Yes, even for L shaped rooms that don't have a top left corner.
        -- I hate this API.
        
        local shape = room.Data.Shape
        if shape ~= RoomShape.ROOMSHAPE_LTL then
            table.insert(data.Rooms, room.GridIndex)
        end
        
        -- There is "another" room below
        if shape == RoomShape.ROOMSHAPE_1x2 or shape == RoomShape.ROOMSHAPE_IIV or
           shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LTL or 
           shape == RoomShape.ROOMSHAPE_LTR or shape == RoomShape.ROOMSHAPE_LBR then
            assert(room.GridIndex <= 13 * 12)
            table.insert(data.Rooms, room.GridIndex + 13)
        end
        
        -- There is "another" room to the right
        if shape == RoomShape.ROOMSHAPE_2x1 or shape == RoomShape.ROOMSHAPE_IIH or 
           shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LTL or 
           shape == RoomShape.ROOMSHAPE_LBL or shape == RoomShape.ROOMSHAPE_LBR then
            assert(room.GridIndex % 13 ~= 0)
            table.insert(data.Rooms, room.GridIndex + 1)
        end
        
        -- There is "another" room to the right below
        if shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LTL or
           shape == RoomShape.ROOMSHAPE_LTR or shape == RoomShape.ROOMSHAPE_LBL then
            assert(room.GridIndex % 13 ~= 0)
            assert(room.GridIndex <= 13 * 12)
            table.insert(data.Rooms, room.GridIndex + 14)
        end
    end
    
    qol:SaveData(json.encode(data))
    
    qol.Utils.Data.WhiteRooms = data.Rooms
end

function qol.Utils:LoadWhiteRooms(continued)
    if not continued then
        return
    end
    
    if qol:HasData() then
        local data = json.decode(qol:LoadData())
        qol.Utils.Data.WhiteRooms = data.Rooms
        
        --[[ for _, idx in pairs(qol.ReverseMoon.Data.Rooms) do
            print ("Room " .. idx .. " is a normal room")
        end --]] 
    end
end

function qol.Utils.IsWhiteRoom(index)
    return not qol.utils.IsRedRoom(index)
end

function qol.Utils.IsRedRoom(index)
    for _, roomIndex in pairs(qol.Utils.Data.WhiteRooms) do
        if roomIndex == index then
            return false 
        end
    end
    
    return true
end

qol:AddCallback(ModCallbacks.MC_EXECUTE_CMD, qol.Utils.ForgetMeNow)
qol:AddCallback(ModCallbacks.MC_EXECUTE_CMD, qol.Utils.GlowingHourGlass)
qol:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, qol.Utils.SaveWhiteRooms)
qol:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, qol.Utils.LoadWhiteRooms)