if _G["qol"] then
    reloading = true
    qol.print ("Reloading Quality of Life")
end

local mod = RegisterMod("Quality of Life", 1)
mod._debug = pcall(function() require("debug") end)

if mod._debug then
    Isaac.DebugString("Debug mode")
end

_G["qol"] = mod

if mod._debug then
    qol.print = function(...)
        local vals = {...}
        local s = ""
        for k, v in pairs(vals) do
            s = s .. tostring(v)
            if k ~= #vals then
                s = s .. "\t"
            end
        end
        
        Isaac.ConsoleOutput(s .. "\n")
    end
    
    qol.include = function(s)
        s = string.gsub(s, ".lua", "")
        Isaac.DebugString("include2: " .. s)
        local result, extra = pcall(function () require(s) end)
        if result then
            Isaac.DebugString("Module correctly loaded, this is problematic: " .. s)
        elseif not result then
            if not string.match(extra, "%[DEBUG%] Intentional error") then
                qol.print(extra)
                qol.print("[ERROR] Error while loading " .. s .. ": " .. extra)
            end
        end
    end
    
    mod._error = function()
        error("[DEBUG] Intentional error because Lua and Nicalis and everything")
    end
else
    qol.print = print
    qol.include = include
end

local json = require ("json")

qol.include ("qol_api.lua")
qol.include ("qol_config.lua")
qol.include ("qol_logging.lua")
qol.include ("qol_utilities.lua")

qol._logging:Init()

-- Fix IV - The Emperor? not spawning a door after defeating bonus Mom

do

mod.ReverseEmperor = {}
mod.ReverseEmperor.Data = {}
mod.ReverseEmperor.Data.DoorGridSlot = 7
mod.ReverseEmperor.Data.DistanceSquared = 125
mod.ReverseEmperor.Data.Filename = "gfx/grid/door_10_bossroomdoor.anm2"

function mod.ReverseEmperor.CheckCorrectLevel()
    return qol.Level():GetStage() == LevelStage.STAGE2_2
end

function mod.ReverseEmperor.CheckCorrectRoom()
    return qol.Level():GetCurrentRoomIndex() == GridRooms.ROOM_EXTRA_BOSS_IDX
end

function mod.ReverseEmperor.CheckConditions()
    return mod.ReverseEmperor.CheckCorrectLevel() and mod.ReverseEmperor.CheckCorrectRoom() and not Game():IsGreedMode()
end

function mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(withAnimation)
    local slot = mod.ReverseEmperor.Data.DoorGridSlot
    local room = qol.Room()
    local door = qol.GridEntity(slot)
    
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
    qol.Level().LeaveDoor = DoorSlot.UP0
end

-- This function is used both to force the collision class of the grid entity 
-- because the game keeps resetting it, and to teleport the player.
function mod.ReverseEmperor:ForceExitDoorForExtraMomFight()
    if not mod.ReverseEmperor.CheckConditions() then
        return
    end
    
    if not qol.RoomDesc().Clear then
        return
    end
    
    local entity = qol.GridEntity(mod.ReverseEmperor.Data.DoorGridSlot)
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
        local player = qol.Player(i)
        local distance = entity.Position:DistanceSquared(player.Position)
        if distance < mod.ReverseEmperor.Data.DistanceSquared then
            Game():StartRoomTransition(qol.Level():GetPreviousRoomIndex(), Direction.UP)
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
        if qol.RoomDesc().Clear then
            -- qol.print ("Entering the extra boss room (cleared)")
            mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(false)
        else
            -- qol.print ("Entering the extra boss room (not cleared)")
        end
    -- MC_POST_NPC_DEATH
    else
        mod.ReverseEmperor.SpawnExitDoorForExtraMomFightFn(true)
    end
end

if qol.Config.ReverseEmperor then
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.ReverseEmperor.SpawnExitDoorForExtraMomFight, EntityType.ENTITY_MOM)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.ReverseEmperor.SpawnExitDoorForExtraMomFight)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.ReverseEmperor.ForceExitDoorForExtraMomFight)
end

end

-- Test updating a door spawned by force

do

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
        qol.print("Door already spawned!")
        return
    end
    
    local room = Game():GetLevel():GetCurrentRoom()
    local entity = room:GetGridEntity(mod.TestDoor.Data.DoorGridSlot)
    
    if entity then
        qol.print("Cannot spawn door, entity already present on grid slot " .. tostring(mod.TestDoor.Data.DoorGridSlot))
        return
    end
    
    local bossRoomIdx = mod.Utils.FindBossRoomIndex()
    if not bossRoomIdx then
        qol.print("Unable to find the index of the boss room")
        return
    end
    
    local spawnResult = room:SpawnGridEntity(mod.TestDoor.Data.DoorGridSlot, GridEntityType.GRID_DOOR, DoorVariant.DOOR_UNLOCKED, 0, 0)
    
    if not spawnResult then
        qol.print("Error while spawning door")
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
        qol.print ("[ERROR] Door is spawned but I cannot get a pointer to it?")
        return
    end
    
    local door = entity:ToDoor()
    if not door then
        qol.print ("[ERROR] Cannot cast entity to door")
        return
    end
    
    if not door:IsOpen() then
        door:Open()
    end
    
    door:Update()
    qol.print ("Updating door")
end

-- mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.TestDoor.SpawnTestDoor)
-- mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.TestDoor.UpdateTestDoor)

end

-- Fix XVIII - The Moon? sometimes softlocking the player

do

mod.ReverseMoon = {}
mod.ReverseMoon.Data = {}
mod.ReverseMoon.Data.EnterSecretRoomFrame = -1
mod.ReverseMoon.Data.DelayFrames = 1

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
    
    -- qol.print ("Entering a normal (super) secret room")
    
    local doorGridSlots = qol.Utils.DoorSlotsIn1x1()
    local openDoors = {}
    local allDoors = {}
    
    for _, slot in pairs(doorGridSlots) do
        local entity = qol.GridEntity(slot)
        if entity and entity:GetType() == GridEntityType.GRID_DOOR then
            local door = entity:ToDoor()
        
            if (door:IsOpen() or door:IsLocked()) and not mod.Utils.IsRedRoom(door.TargetRoomIndex) then
                table.insert(openDoors, door)
            end
            
            table.insert(allDoors, door)
        end
    end
    
    if #openDoors == 0 then
        local firstCandidate = nil
        local secondCandidate = nil
        
        for _, door in pairs(allDoors) do
            if not mod.Utils.IsRedRoom(door.TargetRoomIndex) then
                if not firstCandidate then
                    firstCandidate = door
                else
                    secondCandidate = door
                end
            end
        end
        
        if not firstCandidate then
            qol.print ("Unfortunately, there is no way out...")
            return
        end
        
        -- Avoid opening the way to the curse room if possible, as some low life characters may 
        -- die or be severely impaired when exiting the curse room.
        if qol.Level():GetRoomByIdx(firstCandidate.TargetRoomIndex).Data.Type == RoomType.ROOM_CURSE then
            if secondCandidate then
                secondCandidate:SetLocked(false)
            else
                -- Spawn a Fool card.
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_FOOL, Vector(320, 280), Vector(0, 0), nil)
            end
        else
            firstCandidate:SetLocked(false)
        end
    end
end

function mod.ReverseMoon:OnEnterNewRoom()
    if mod.Utils.Data.WhiteRooms == {} then
        return
    end
    
    -- Do not do anything in a red room
    if mod.Utils.IsRedRoom(mod.Utils.GetCurrentRoomIndex()) then
        return
    end
    
    if mod.Utils.IsRoom(RoomType.ROOM_SECRET) or mod.Utils.IsRoom(RoomType.ROOM_SUPERSECRET) then
        mod.ReverseMoon.Data.EnterSecretRoomFrame = Game():GetFrameCount()
    end
end

if qol.Config.ReverseMoonSecrets then
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.ReverseMoon.OnEnterNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.ReverseMoon.OnUpdate)
end

end

-- Fix the Ultra Secret Room sometimes not opening doors (when there are enemies 
-- inside for example).

do

mod.UltraSecret = {}
mod.UltraSecret.Data = {}
mod.UltraSecret.Data.EnterFrame = -1
mod.UltraSecret.Data.FrameDiff = 1
mod.UltraSecret.Data.PillColor = PillColor.PILL_BLUE_BLUE
mod.UltraSecret.Data.TelepillsFromUltraSecret = false
mod.UltraSecret.Data.DoorIdx = -1
mod.UltraSecret.Data.DoorSlot = nil

function mod.UltraSecret.SpawnFoolOrTelepillsAndConsiderErrorRoom()
    qol.print ("[QOL] I need to finish this function, but I secretly hope that I don't have to")
end

function mod.UltraSecret:OnNewRoom()
    if not mod.Utils.IsRoom(RoomType.ROOM_ULTRASECRET) then
        if not mod.Utils.IsRoom(RoomType.ROOM_ERROR) then
            return
        else
            if not mod.UltraSecret.Data.TelepillsFromUltraSecret then
                return
            else
                mod.UltraSecret.SpawnFoolOrTelepillsAndConsiderErrorRoom()
                return
            end
        end
    end
    
    mod.UltraSecret.Data.EnterFrame = Game():GetFrameCount()
end

function mod.UltraSecret:Update()
    if mod.UltraSecret.Data.EnterFrame == -1 then
        return
    end
    
    if Game():GetFrameCount() - mod.UltraSecret.Data.EnterFrame < mod.UltraSecret.Data.FrameDiff then
        return
    end
    
    if not mod.Utils.IsRoom(RoomType.ROOM_ULTRASECRET) then
        return
    end
    
    local slots = qol.Utils.DoorSlotsIn1x1()
    local nDoors = 0
    local nOpenedDoors = 0
    
    for _, idx in pairs(slots) do
        local entity = qol.GridEntity(idx)
        if entity:GetType() == GridEntityType.GRID_DOOR then
            nDoors = nDoors + 1
            
            if entity:ToDoor():IsOpen() then
                nOpenedDoors = nOpenedDoors + 1
            end
        end
    end
    
    if nDoors ~= 0 then
        if nOpenedDoors ~= 0 then
            return
        else
            qol.print ("[QOL] I'm not sure what to do. Apparently there is a door somewhere, but it isn't opened, and I don't understand how it is possible. Here's something to get out if needed.")
            mod.UltraSecret.SpawnFoolOrTelepillsAndConsiderErrorRoom()
        end
    else
       
        mod.UltraSecret.OpenDoorToNormalRooms()
    end
end

-- There are no really defined ways to connect the ultra secret room to the 
-- normal rooms. The wiki explains that sometimes there will be two adjacent
-- red rooms, sometimes there will be only one, and sometimes the player will 
-- need to traverse at least two red rooms to go back. Ideally, we could use a 
-- shortest path algorithm, but why would the API allow smart things?
-- Fuck you Nicalis.
function mod.UltraSecret.OpenDoorToNormalRooms()
    -- Spawn a beam of light that will take the player back
    local room = mod.Utils.GetCurrentRoom()
    
    if mod.UltraSecret.Data.DoorIdx == -1 then
        local gridIdx = -1
        local slots = {DoorSlot.UP0, DoorSlot.LEFT0, DoorSlot.DOWN0, DoorSlot.RIGHT0}
        local validSlot = nil
        for _, slot in pairs(slots) do
            if room:IsDoorSlotAllowed(slot) then
                validSlot = slot
                break
            end
        end
        
        if not validSlot then
            qol.print ("I fucking hate this game... Here's a Fool card / Telepills, sorry if this makes you lose something...")
            mod.UltraSecret.SpawnFoolOrTelepillsAndConsiderErrorRoom()
            return
        end
        
        local gridIdx = -1
        if validSlot == DoorSlot.UP0 then
            gridIdx = 7
        elseif validSlot == DoorSlot.LEFT0 then
            gridIdx = 60
        elseif validSlot == DoorSlot.DOWN0 then
            gridIdx = 127
        else
            gridIdx = 74
        end
        
        mod.UltraSecret.Data.DoorIdx = gridIdx
        mod.UltraSecret.Data.DoorSlot = validSlot
    end
    
    local entity = room:GetEntity(mod.UltraSecret.Data.DoorIdx)
    local sprite = entity:GetSprite()
    
    sprite:Load("gfx/grid/Door_08_HoleInWall.anm2", true)
    local slot = mod.UltraSecret.Data.DoorSlot
    
    local offset = nil
    if slot == DoorSlot.UP0 then
        offset = Vector(0, 13)
    elseif slot == DoorSlot.LEFT0 then
        
    elseif slot == DoorSlot.DOWN0 then
        
    else
        
    end
    
    if room:GetAliveEnemiesCount() > 0 then
        sprite:Play("Close", true)
    else
        sprite:Play("Opened", true)
    end
end

end

-- Delirium

do

mod.Delirium = {}

function mod.Delirium.GetDelirium()
    local entities = qol.Utils.GetCurrentRoom():GetEntities()
    for i = 0, #entities - 1 do
        local entity = entities:Get(i)
        if entity then 
            local npc = entity:ToNPC()
        
            if npc and npc.Type == EntityType.ENTITY_DELIRIUM then
                return npc
            end
        end
    end
    
    return nil
end

mod.Delirium.Marked = nil
mod.Delirium.SpeedMultX = 1
mod.Delirium.SpeedMultY = 1
mod.Delirium.NewVelocity = Vector(1, 1)

function mod.Delirium:PostRender()
    local delirium = mod.Delirium.GetDelirium()
    if not delirium then
        return
    end
    
    if not mod.Delirium.Marked then
        mod.Delirium.Marked = Sprite()
        mod.Delirium.Marked:Load("gfx/1000.030_dr. fetus target.anm2", true)
    end
    
    local marked = mod.Delirium.Marked
    
    if marked:IsLoaded() then
        marked.Rotation = 0
        marked.Color = Color(1, 0.1, 0.1)
        marked:SetFrame("Idle", 0)
        marked:Render(Isaac.WorldToScreen(delirium.Position))
        -- qol.print ("Rendering target at " .. delirium.Position.X .. ", " .. delirium.Position.Y)
    end
end

function mod.Delirium.SetSpeedMultiplier(x, y)
    mod.Delirium.SpeedMultX = x
    mod.Delirium.SpeedMultY = y
end

function mod.Delirium:UpdateSpeed()
    local delirium = mod.Delirium.GetDelirium()
    if not delirium then
        return
    end
    
    qol.print (delirium.Velocity)
    if delirium.Velocity ~= mod.Delirium.NewVelocity then
        -- delirium.Velocity = delirium.Velocity * Vector(mod.Delirium.SpeedMultX, mod.Delirium.SpeedMultY)
        mod.Delirium.NewVelocity = delirium.Velocity
    end
end

if qol.Config.WIP then
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.Delirium.PostRender)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.Delirium.UpdateSpeed)
end

end


-- Genesis preventing the player from reaching Sheol if they left the room
-- through the beam of light.

do

qol.Genesis = {}

function qol.Genesis:OnNewFloor()
    local stage = qol.Level():GetStage()
    if stage ~= LevelStage.STAGE5 then
        if stage ~= LevelStage.STAGE6 then
            Game():SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
        else
            if qol.Level():GetStageType() ~= StageType.STAGETYPE_WOTL then
                Game():SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
            end
        end
    end
end

if qol.Config.GenesisSheol then
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.Genesis.OnNewFloor)
end

end