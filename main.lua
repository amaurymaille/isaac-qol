local mod = RegisterMod("Quality of Life", 1)
assert (not _G["qol"], "qol is already defined")

_G["qol"] = mod

local json = require ("json")

include ("qol_config.lua")
include ("qol_utilities.lua")

-- Fix IV - The Emperor? not spawning a door after defeating bonus Mom

mod.ReverseEmperor = {}
mod.ReverseEmperor.Data = {}
mod.ReverseEmperor.Data.DoorGridSlot = 7
mod.ReverseEmperor.Data.DistanceSquared = 32
mod.ReverseEmperor.Data.Filename = "gfx/grid/door_10_bossroomdoor.anm2"

function mod.ReverseEmperor.CheckCorrectLevel()
    return Game():GetLevel():GetStage() == LevelStage.STAGE2_2
end

function mod.ReverseEmperor.CheckCorrectRoom()
    return Game():GetLevel():GetCurrentRoomIndex() == GridRooms.ROOM_EXTRA_BOSS_IDX
end

function mod.ReverseEmperor.CheckConditions()
    return mod.ReverseEmperor.CheckCorrectLevel() and mod.ReverseEmperor.CheckCorrectRoom() and not Game():IsGreedMode()
end

function mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(withAnimation)
    local slot = mod.ReverseEmperor.Data.DoorGridSlot
    local door = room:GetGridEntity(slot)
    
    local sprite = door:GetSprite()
    sprite:Load(mod.ReverseEmperor.Data.Filename, true)
    sprite:Play("Open", true)
    
    if not withAnimation then
        sprite:SetFrame(11)
        sprite:SetLayerFrame(4, 0)
    end
    
    sprite.Offset = Vector(0, 13) -- Shift the position down to align it with the wall
    
    door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
    door:Update()
    
    -- Make the player appear at the bottom of the previous room because we are existing 
    -- from the upper door of the boss room.
    Game():GetLevel().LeaveDoor = DoorSlot.UP0
end

-- This function is used both to force the collision class of the grid entity 
-- because the game keeps resetting it, and to teleport the player.
function mod.ReverseEmperor:ForceExitDoorForExtraMomFight()
    if not mod.ReverseEmperor.CheckConditions() then
        return
    end
    
    if not Game():GetLevel():GetCurrentRoomDesc().Clear then
        return
    end
    
    local entity = Game():GetLevel():GetCurrentRoom():GetGridEntity(mod.ReverseEmperor.Data.DoorGridSlot)
    if entity.CollisionClass ~= GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER then
        entity.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
    end
            
    -- Disable upper layers of the animation that display the glowing red 
    -- lights of the door
    local sprite = entity:GetSprite()
    if sprite:GetFilename() == mod.ReverseEmperor.Data.Filename then
        sprite:Update()
        sprite:SetLayerFrame(4, 0)
    end
    
    for i = 1, Game():GetNumPlayers() do
        local player = Game():GetPlayer(i)
        if entity.Position:DistanceSquared(player.Position) < mod.ReverseEmperor.Data.DistanceSquared then
            Game():StartRoomTransition(Game():GetLevel():GetPreviousRoomIndex(), Direction.UP)
            return 
        end
    end
end

-- Called after entering the room and after Mom is killed
function mod.ReverseEmperor:SpawnExitDoorForExtraMomFight(entity)
    if not mod.ReverseEmperor.CheckConditions() then
        return
    end
    
    -- MC_POST_NEW_ROOM
    if not entity then
        if Game():GetLevel():GetCurrentRoomDesc().Clear then
            -- print ("Entering the extra boss room (cleared)")
            mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(false)
        else
            -- print ("Entering the extra boss room (not cleared)")
        end
    -- MC_POST_NPC_DEATH
    else
        mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(true)
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.ReverseEmperor.SpawnExitDoorForExtraMomFight, EntityType.ENTITY_MOM)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.ReverseEmperor.SpawnExitDoorForExtraMomFight)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.ReverseEmperor.ForceExitDoorForExtraMomFight)

-- Test updating a door spawned by force

mod.TestDoor = {}
mod.TestDoor.Data = {}
mod.TestDoor.Data.DoorSpawnRoom = -1
mod.TestDoor.Data.DoorSpawned = false
mod.TestDoor.Data.DoorGridSlot = 20
mod.TestDoor.Data.Command = "testdoor"

function mod.TestDoor:SpawnTestDoor(command, args)
    if command ~= mod.TestDoor.Data.Command then
        return
    end
    
    if mod.TestDoor.Data.DoorSpawned then
        print("Door already spawned!")
        return
    end
    
    local room = Game():GetLevel():GetCurrentRoom()
    local entity = room:GetGridEntity(mod.TestDoor.Data.DoorGridSlot)
    
    if entity then
        print("Cannot spawn door, entity already present on grid slot " .. tostring(mod.TestDoor.Data.DoorGridSlot))
        return
    end
    
    local bossRoomIdx = mod.Utils.FindBossRoomIndex()
    if not bossRoomIdx then
        print("Unable to find the index of the boss room")
        return
    end
    
    local spawnResult = room:SpawnGridEntity(mod.TestDoor.Data.DoorGridSlot, GridEntityType.GRID_DOOR, DoorVariant.DOOR_UNLOCKED, 0, 0)
    
    if not spawnResult then
        print("Error while spawning door")
        return
    end
    
    entity = room:GetGridEntity(mod.TestDoor.Data.DoorGridSlot)
    assert (entity, "Unable to get pointer to newly spawned door")
    
    local door = entity:ToDoor()
    assert (door, "Unable to cast entity to door")
    
    door:SetRoomTypes(Game():GetLevel():GetCurrentRoomDesc().Data.Type, RoomType.ROOM_BOSS)
    door.TargetRoomIndex = bossRoomIdx
    
    mod.TestDoor.Data.DoorSpawned = true
    mod.TestDoor.Data.DoorSpawnRoom = Game():GetLevel():GetCurrentRoomIndex()
    
    return
end

function mod.TestDoor:UpdateTestDoor()
    if not mod.TestDoor.Data.DoorSpawned then
        return
    end
    
    if Game():GetLevel():GetCurrentRoomIndex() ~= mod.TestDoor.Data.DoorSpawnRoom then
        return
    end
    
    local entity = Game():GetLevel():GetCurrentRoom():GetGridEntity(mod.TestDoor.Data.DoorGridSlot)
    if not entity then
        print ("[ERROR] Door is spawned but I cannot get a pointer to it?")
        return
    end
    
    local door = entity:ToDoor()
    if not door then
        print ("[ERROR] Cannot cast entity to door")
        return
    end
    
    if not door:IsOpen() then
        door:Open()
    end
    
    door:Update()
    print ("Updating door")
end

-- mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.TestDoor.SpawnTestDoor)
-- mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.TestDoor.UpdateTestDoor)

-- Fix XVIII - The Moon? sometimes softlocking the player

mod.ReverseMoon = {}
mod.ReverseMoon.Data = {}
mod.ReverseMoon.Data.Rooms = {}
mod.ReverseMoon.Data.EnterSecretRoomFrame = -1
mod.ReverseMoon.Data.DelayFrames = 1

function mod.ReverseMoon.IsRedRoom(index)
    for _, roomIndex in pairs(mod.ReverseMoon.Data.Rooms) do
        if roomIndex == index then
            return false 
        end
    end
    
    return true
end

function mod.ReverseMoon:OnUpdate()
    if mod.ReverseMoon.Data.EnterSecretRoomFrame == -1 then
        return
    end
    
    if not (mod.Utils.IsRoom(RoomType.ROOM_SECRET) or mod.Utils.IsRoom(RoomType.ROOM_SUPERSECRET)) then
        mod.ReverseMoon.Data.EnterSecretRoomFrame = -1
        return
    end
    
    local frameCount = Game():GetFrameCount() - mod.ReverseMoon.Data.EnterSecretRoomFrame
    if frameCount < mod.ReverseMoon.Data.DelayFrames then
        return
    end
    
    mod.ReverseMoon.Data.EnterSecretRoomFrame = -1
    
    -- print ("Entering a normal (super) secret room")
    
    local doorGridSlots = {7, 60, 74, 127}
    local openDoors = {}
    local allDoors = {}
    local room = mod.Utils.GetCurrentRoom()
    
    for _, slot in pairs(doorGridSlots) do
        local entity = room:GetGridEntity(slot)
        if entity and entity:GetType() == GridEntityType.GRID_DOOR then
            if entity:ToDoor():IsOpen() then
                table.insert(openDoors, entity:ToDoor())
            end
            
            table.insert(allDoors, entity:ToDoor())
        end
        
        --[[ if not entity then
            print ("No entity at index " .. tostring(slot))
        elseif entity:GetType() ~= GridEntityType.GRID_DOOR then
            print ("Entity at index " .. tostring(slot) .. " is not a door: " .. tostring(entity:GetType()))
        elseif not entity:ToDoor():IsOpen() then
            print ("Entity at index " .. tostring(slot) .. " is a closed door")
            local door = entity:ToDoor()
            print (tostring(door.Busted) .. ", " .. tostring(door.State))
        end --]]
    end
    
    -- print ("There are " .. tostring(#openDoors) .. " open doors in this room")
    if #openDoors == 1 then
        local exitDoor = openDoors[1]
        local targetRoomIndex = exitDoor.TargetRoomIndex
        
        -- Does the door lead to a non red room?
        if not mod.ReverseMoon.IsRedRoom(targetRoomIndex) then 
            -- print ("There is only a single opened dooor in this room, but it leads to a normal room")
            return
        --[[ else
            -- Does the red room lead to a normal that is not a) A Curse Room, b) A Secret Room, c) A Super Secret Room ?
            -- If yes, do not open another exit. If no, open another exit.
            local otherPossibleRoomsIdx = {}
            if targetRoomIndex > 13 then 
                table.insert(otherPossibleRoomsIdx, targetRoomIndex - 13)
            end
            
            if targetRoomIndex < 13 * 12 then
                table.insert(otherPossibleRoomsIdx, targetRoomIndex + 13)
            end
                
            if targetRoomIndex % 13 ~= 1 then
                table.insert(otherPossibleRoomsIdx, targetRoomIndex - 1)
            end
                
            if targetRoomIndex % 13 ~= 0 then
                table.insert(otherPossibleRoomsIdx, targetRoomIndex + 1)
            end
                
            local otherPossibleRooms = {}
            for _, idx in pairs(otherPossibleRoomsIdx) do
                if idx ~= mod.Utils.GetCurrentRoomIndex() then
                    local otherRoom = Game():GetLevel():GetRoomByIdx(idx)
                    if otherRoom and not mod.ReverseMoon.IsRedRoom(idx) then
                        print ("OtherRoom has index " .. tostring(idx))
                        if otherRoom.Data.Type ~= RoomType.ROOM_CURSE and 
                           otherRoom.Data.Type ~= RoomType.ROOM_SECRET and
                           otherRoom.Data.Type ~= RoomType.ROOM_SUPERSECRET and 
                           otherRoom.Data.Type ~= RoomType.ROOM_ULTRASECRET then
                            table.insert(otherPossibleRooms, idx)
                        end
                    end
                end
            end
            
            if #otherPossibleRooms ~= 0 then
                return
            end
        end --]]
        end
        
        -- No.
        local hash = GetPtrHash(openDoors[1])
        local firstCandidate = nil
        local secondCandidate = nil
        
        for _, door in pairs(allDoors) do
            if GetPtrHash(door) ~= hash then
                if not mod.ReverseMoon.IsRedRoom(door.TargetRoomIndex) then
                    if not firstCandidate then
                        -- print ("First candidate door found")
                        firstCandidate = door
                    else
                        -- print ("Second candidate door found")
                        secondCandidate = door
                    end
                end
            end
        end
        
        if not firstCandidate then
            print ("Unfortunately, there is no way out...")
            return
        end
        
        -- Avoid opening the way to the curse room if possible, as some low life characters may 
        -- die or be severely impaired when exiting the curse room.
        if Game():GetLevel():GetRoomByIdx(firstCandidate.TargetRoomIndex).Data.Type == RoomType.ROOM_CURSE then
            if secondCandidate then
                -- print ("Blowing open door at index " .. tostring(secondCandidate:GetGridIndex()))
                secondCandidate:TryBlowOpen(true, Game():GetPlayer(1))
            else
                -- Spawn a Fool card.
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_FOOL, Vector(320, 280), Vector(0, 0), nil)
            end
        else
            firstCandidate:TryBlowOpen(true, Game():GetPlayer(1))
        end
    end
end

function mod.ReverseMoon:OnEnterNewRoom()
    if mod.ReverseMoon.Data.Rooms == {} then
        return
    end
    
    -- Do not do anything in a RED (Super) Secret Room
    if mod.ReverseMoon.IsRedRoom(mod.Utils.GetCurrentRoomIndex()) then
        -- print ("Entering a red room, do not do anything")
        return
    end
    
    if mod.Utils.IsRoom(RoomType.ROOM_SECRET) or mod.Utils.IsRoom(RoomType.ROOM_SUPERSECRET) then
        mod.ReverseMoon.Data.EnterSecretRoomFrame = Game():GetFrameCount()
    end
end

function mod.ReverseMoon:OnNewLevel()
    if Game():IsGreedMode() then
        return
    end

    local rooms = Game():GetLevel():GetRooms()
    
    local data = {}
    data.Rooms = {}
    
    for i = 0, #rooms - 1 do
        local room = rooms:Get(i)
        -- print ("Room " .. room.GridIndex .. " is a normal room")
        table.insert(data.Rooms, room.GridIndex)
    end
    
    mod:SaveData(json.encode(data))
    
    mod.ReverseMoon.Data.Rooms = data.Rooms
end

function mod.ReverseMoon:OnContinue(continued)
    if not continued then
        return
    end
    
    if mod:HasData() then
        local data = json.decode(mod:LoadData())
        mod.ReverseMoon.Data.Rooms = data.Rooms
        
        --[[ for _, idx in pairs(mod.ReverseMoon.Data.Rooms) do
            print ("Room " .. idx .. " is a normal room")
        end --]] 
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.ReverseMoon.OnEnterNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.ReverseMoon.OnNewLevel)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.ReverseMoon.OnContinue)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.ReverseMoon.OnUpdate)