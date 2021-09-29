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
        -- Rooms have indices from top left to bottom right.
        -- The topleft room has grid index 0, the bottomright room has grind index 168.
        -- Rooms that span multiple grid slots have a single index when iterated over 
        -- through Level::GetRooms, which corresponds to the topleft corner of the
        -- room. This also includes L shaped rooms that don't have a topleft slot
        -- for some reason.
        
        local shape = room.Data.Shape
        -- Always add the the identifier of the room being iterated over unless 
        -- it is an L Shaped room without a topleft slot.
        if shape ~= RoomShape.ROOMSHAPE_LTL then
            table.insert(data.Rooms, room.GridIndex)
        else
            -- Process this corner case right now so it doesn't appear in the checks for
            -- every single other shape.
            assert(room.GridIndex % 13 ~= 12) -- Allow rooms to the right
            assert(room.GridIndex < 13 * 12) -- Allow rooms below
            table.insert(data.Rooms, room.GridIndex + 1) -- Right
            table.insert(data.Rooms, room.GridIndex + 13) -- Below
            table.insert(data.Rooms, room.GridIndex + 14) -- Below and right
        end
        
        -- There is "another" room below
        if shape == RoomShape.ROOMSHAPE_1x2 or shape == RoomShape.ROOMSHAPE_IIV or
           shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LTR or 
           shape == RoomShape.ROOMSHAPE_LBR then
            assert(room.GridIndex < 13 * 12)
            table.insert(data.Rooms, room.GridIndex + 13)
        end
        
        -- There is "another" room to the right
        if shape == RoomShape.ROOMSHAPE_2x1 or shape == RoomShape.ROOMSHAPE_IIH or 
           shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LBL or 
           shape == RoomShape.ROOMSHAPE_LBR then
            assert(room.GridIndex % 13 ~= 12)
            table.insert(data.Rooms, room.GridIndex + 1)
        end
        
        -- There is "another" room to the right below
        if shape == RoomShape.ROOMSHAPE_2x2 or shape == RoomShape.ROOMSHAPE_LTR or 
           shape == RoomShape.ROOMSHAPE_LBL then
            assert(room.GridIndex % 13 ~= 12)
            assert(room.GridIndex < 13 * 12)
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
            qol.print ("Room " .. idx .. " is a normal room")
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

local function DumpTableDepth(tbl, depth)
    for k, v in pairs(tbl) do
        local s = ""
        for i = 1, depth do
            s = s .. "\t"
        end
        
        s = (s .. tostring(k) .. " => ")
        if type(v) == "table" then
            s = s .. "{"
            qol.print(s)
            DumpTableDepth(v, depth + 1)
            local epilogue = ""
            for i = 1, depth do
                epilogue = epilogue .. "\t"
            end
            epilogue = epilogue .. "}"
            qol.print(epilogue)
        else
            qol.print(s .. tostring(v))
        end
    end
end

function qol.Utils.DumpTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    
    qol.print("{")
    DumpTableDepth(tbl, 1)
    qol.print("}")
end

function qol.Utils.Enum(tbl)
    for i = 1, #tbl do
        tbl[tbl[i]] = i
    end
    
    return tbl
end

function qol.Utils.ForEach(list, fn)
    for i = 0, #list - 1 do 
        fn(list:Get(i))
    end
end

function qol.Utils.ForEachEntity(fn)
    if qol.Room then
        qol.Utils.ForEach(qol.Room():GetEntities(), fn)
    else
        qol.Utils.ForEach(Game():GetRoom():GetEntities(), fn)
    end
end

function qol.Utils.GetPlayerID(player)
    local data = player:GetData()
    if not data["ID"] then
        for i = 0, Game():GetNumPlayers() - 1 do
            Game():GetPlayer(i):GetData()["ID"] = i
        end
    end
    
    return data["ID"]
end

qol:AddCallback(ModCallbacks.MC_EXECUTE_CMD, qol.Utils.ForgetMeNow)
qol:AddCallback(ModCallbacks.MC_EXECUTE_CMD, qol.Utils.GlowingHourGlass)
qol:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, qol.Utils.SaveWhiteRooms)
qol:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, qol.Utils.LoadWhiteRooms)

if qol._debug then
    qol._error()
end