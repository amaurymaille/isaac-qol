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

--[[

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

--]]

-- Delirium misc fixes

do

mod.Delirium = {}

local deliriumLogger = qol._logging:GetLogger("delirium")

mod.Delirium.Marked = nil
mod.Delirium.SpeedMultX = 1
mod.Delirium.SpeedMultY = 1
mod.Delirium.NewVelocity = Vector(1, 1)

-- Frames at which Delirium / Mom entered the MC_NPC_POST_INIT callback. 
-- Give the player some immunity to immediate contact damage.
mod.Delirium.DeliriumMorphFrame = -1
mod.Delirium.MomSpawnFrame = -1

mod.Delirium.BigHornStates = {
    NULL,
    POP_UP,
    POP_DOWN
}

mod.Delirium.BigHornState = mod.Delirium.BigHornStates.NULL

-- Delirium current boss form
mod.Delirium.MorphedAs = -1
mod.Delirium.MorphedAsVariant = -1

mod.Delirium.Harbringers = {
    HARBRINGER_VARIANT_NORMAL = 0,
    DEATH_VARIANT_HORSE = 20
}

mod.Delirium.DeliriumMaxHitPoints = 10000

local function isDeliriumRoom()
    return qol.Room():GetType() == RoomType.ROOM_BOSS and 
        qol.Room():GetRoomShape() == RoomShape.ROOMSHAPE_2x2 and
        qol.Level():GetStage() == LevelStage.STAGE7
end

function mod.Delirium.GetDelirium()
    if not isDeliriumRoom() then
        return nil
    end
    
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

local function isHarbringerID(id, variant)
    return (id == EntityType.ENTITY_FAMINE or
        id == EntityType.ENTITY_PESTILENCE or
        id == EntityType.ENTITY_WAR or
        id == EntityType.ENTITY_DEATH) and variant == mod.Delirium.Harbringers.HARBRINGER_VARIANT_NORMAL
end

local function isDeathHorseID(id, variant)
    return id == EntityType.ENTITY_DEATH and 
        variant == mod.Delirium.Harbringers.DEATH_VARIANT_HORSE
end

local function isHarbringer(entity)
    return isHarbringerID(entity.Type, entity.Variant)
end

local function isSinID(id)
    return id == EntityType.ENTITY_SLOTH or
        id == EntityType.ENTITY_LUST or
        id == EntityType.ENTITY_WRATH or 
        id == EntityType.ENTITY_GLUTTONY or
        id == EntityType.ENTITY_GREED or
        id == EntityType.ENTITY_ENVY or 
        id == EntityType.ENTITY_PRIDE
end

local function isSin(entity)
    return isSinID(entity.Type)
end

local function isAngelID(id)
    return id == EntityType.ENTITY_URIEL or
        id == EntityType.ENTITY_GABRIEL
end

local function isAngel(entity)
    return isAngelID(entity.Type)
end

local function isMegaSatanSummonID(id, variant)
    return isHarbringerID(id, variant) or
        isSinID(id) or
        isAngelID(id)
end

local function isMegaSatanSummon(entity)
    return (isHarbringer(entity) or isSin(entity) or isAngel(entity)) and 
        entity.MaxHitPoints ~= mod.Delirium.DeliriumMaxHitPoints
end

function mod.Delirium:PostRender()
    if not isDeliriumRoom() then
        return
    end

    local delirium = mod.Delirium.GetDelirium()
    if not delirium then
        return
    end
    
    if mod.Delirium.MorphedAs ~= EntityType.ENTITY_BIG_HORN then
        mod.Delirium.BigHornState = mod.Delirium.BigHornStates.NULL
    end
    
    if not mod.Delirium.Marked then
        mod.Delirium.Marked = Sprite()
        mod.Delirium.Marked:Load("gfx/1000.030_dr. fetus target.anm2", true)
        local marked = mod.Delirium.Marked
        marked.Rotation = 0
        marked.Color = Color(1, 1, 1)
        local frameNum = 0
        local split = Game():GetFrameCount() % 10
        if split < 5 then
            frameNum = 0
        else
            frameNum = 1
        end
        marked:SetFrame("Blink", frameNum)
    end
    
    local marked = mod.Delirium.Marked
    
    if marked:IsLoaded() then
        local frameNum = 0
        local split = Game():GetFrameCount() % 10
        if split < 5 then
            frameNum = 0
        else
            frameNum = 1
        end
        marked:SetFrame("Blink", frameNum)
        marked:Render(Isaac.WorldToScreen(delirium.Position))
    end
    
    -- Stop all Mega Satan animations in order to prevent it from spawning tears,
    -- because destroying the harbringers / sins / angels makes MS cycle his phases
    -- properly.
    -- if string.find(delirium:GetSprite():GetFilename(), "274%.000") then
    if mod.Delirium.MorphedAs == EntityType.ENTITY_MEGA_SATAN then
        delirium:GetSprite():SetFrame("Idle", 0)
    elseif mod.Delirium.MorphedAs == EntityType.ENTITY_BIG_HORN then
        local sprite = delirium:GetSprite()
        local animation = sprite:GetAnimation()
        
        if animation == "PopUp" or animation == "Appear" then
            -- deliriumLogger:info("Big Horn UP")
            mod.Delirium.BigHornState = mod.Delirium.BigHornStates.POP_UP
        elseif animation == "PopDown" then
            -- deliriumLogger:info("Big Horn DOWN")
            mod.Delirium.BigHornState = mod.Delirium.BigHornStates.POP_DOWN
        end
    end
end

function mod.Delirium.SetSpeedMultiplier(x, y)
    mod.Delirium.SpeedMultX = x
    mod.Delirium.SpeedMultY = y
end

function mod.Delirium:NpcUpdate(npc)
    if not isDeliriumRoom() then
        return
    end
    
    -- Remove Mega Satan's summons. This is normally not necessary because stopping its
    -- animations should prevent him from summoning anyway, but considering that most 
    -- animations are sped up later... Let's be sure.
    if isMegaSatanSummon(npc) then
        deliriumLogger:info("Deleting Mega Satan summon " .. tostring(npc.Type) .. " (variant: " .. tostring(npc.Variant) .. ") with " .. tostring(npc.MaxHitPoints) .. " health")
        npc:Remove()
    -- Remove Death's Horse that spawns when Delirium transforms into Death with
    -- less than 50% HP.
    elseif npc.Type == EntityType.ENTITY_DEATH and npc.Variant == mod.Delirium.Harbringers.DEATH_VARIANT_HORSE and npc.MaxHitPoints ~= mod.Delirium.DeliriumMaxHitPoints then
        deliriumLogger:info("Deleting Death's horse")
        npc:Remove()
    end

    local delirium = mod.Delirium.GetDelirium()
    if not delirium then
        return
    end
    
    -- delirium.Visible = true
    if delirium.Velocity ~= mod.Delirium.NewVelocity then
        -- delirium.Velocity = delirium.Velocity * Vector(mod.Delirium.SpeedMultX, mod.Delirium.SpeedMultY)
        mod.Delirium.NewVelocity = delirium.Velocity
    end
end

local function checkDeliriumGraceTime() 
    return Game():GetFrameCount() - mod.Delirium.DeliriumMorphFrame <= qol.Config.DeliriumGraceTime
end

local function checkMomGraceTime()
    return Game():GetFrameCount() - mod.Delirium.MomSpawnFrame <= qol.Config.DeliriumMomGraceTime
end

local function newProjectileNeedsTreatement()
    local morphedAs = mod.Delirium.MorphedAs
    local delirium = mod.Delirium.GetDelirium()
    
    return morphedAs == EntityType.ENTITY_MOM or 
        morphedAs == EntityType.ENTITY_MEGA_SATAN or
        (morphedAs == EntityType.ENTITY_BIG_HORN and mod.Delirium.BigHornState == mod.Delirium.BigHornStates.POP_DOWN)
end

function mod.Delirium:OnProjectileInit(projectile)
    if not isDeliriumRoom() or not newProjectileNeedsTreatement() then
        return
    end
    
    local data = projectile:GetData()
    data["needsTreatement"] = true
    data["spawn"] = Game():GetFrameCount()
end

function mod.Delirium:PostNPCInit(npc)
    if not isDeliriumRoom() then
        return
    end
    
    if npc:IsBoss() then
        deliriumLogger:info("A boss spawned: " .. tostring (npc.Type))
        mod.Delirium.MorphedAs = npc.Type
        mod.Delirium.DeliriumMorphFrame = Game():GetFrameCount()
    end

    -- deliriumLogger:info("Initializing entity " .. tostring(npc.Type))
    if npc.Type == EntityType.ENTITY_MOM then
        mod.Delirium.MomSpawnFrame = Game():GetFrameCount()
    elseif npc.Type == EntityType.ENTITY_MEGA_SATAN then
        mod.Delirium.MegaSatanSpawnFrame = Game():GetFrameCount()
    end
end

function mod.Delirium:EntityTakeDmg(victim, amount, flags, src, invFrames)
    local player = victim:ToPlayer()
    if not player then
        return true
    end
    
    src = src.Entity
    
    if not src then
        deliriumLogger:info("Player took damage from unknown entity")
        return true
    end
    
    local sourceType = ""
    local sourceExtra = ""
    
    if src:ToProjectile() then
        local data = src:GetData()
        if data["needsTreatement"] then
            if Game():GetFrameCount() - data["spawn"] <= qol.Config.DeliriumGraceTime then
                deliriumLogger:info("Negating damage from projectile")
                return false
            end
        end
        
        sourceType = "projectile"
        sourceExtra = ""
    elseif src:ToNPC() then
        if src.Type == EntityType.ENTITY_DELIRIUM then
            if checkDeliriumGraceTime() then
                deliriumLogger:info("Negating damage from Delirium")
                return false
            end
            
            deliriumLogger:info("Delirium spawned at " .. tostring(mod.Delirium.DeliriumSpawnFrame) .. ", time is " .. tostring(Game():GetFrameCount()))
        end
        sourceType = "NPC"
        sourceExtra = tostring(src.Type)
    end
    
    deliriumLogger:info("Player took damage from " .. sourceType .. " (extra info: " .. sourceExtra .. ")")
    return true
end

-- Called every logic time to have the correct ID in mod.Delirium.MorphedAs.
-- It is impossible to guess in a call to the NPC_INIT callback if Delirium transformed
-- into one of Mega Satan summons or if Delirium as Mega Satan spawned one of Mega 
-- Satan summons. Therefore, if Delirium is transformed into one of Mega Satan summons, 
-- check if Delirium is using the animations of Mega Satan to deduce if he is still 
-- transformed as Mega Satan or if he is transformed into one of Mega Satan summons.
function mod.Delirium:StabilizeMorphGuess()
    if not isDeliriumRoom() then
        return
    end
    
    local delirium = mod.Delirium.GetDelirium()
    if not delirium then
        return
    end
    
    if isMegaSatanSummonID(mod.Delirium.MorphedAs, mod.Delirium.MorphedAsVariant) or 
        isDeathHorseID(mod.Delirium.MorphedAs, mod.Delirium.MorphedAsVariant) then
        local filename = delirium:GetSprite():GetFilename()
        if string.find(filename, "274.00%d_megasatan") then
            mod.Delirium.MorphedAs = EntityType.ENTITY_MEGA_SATAN
            mod.Delirium.MorphedAsVariant = 0
        end
    end
end

if qol.Config.Delirium then
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.Delirium.PostNPCInit)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.Delirium.PostRender)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.Delirium.NpcUpdate)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.Delirium.EntityTakeDmg)
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, mod.Delirium.OnProjectileInit)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.Delirium.StabilizeMorphGuess)
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

--[[
-- III - The Empress? removing too many heart containers

do

qol.ReverseEmpress = {}
qol.ReverseEmpress.Data = {}

function qol.ReverseEmpress.HasBug(player)
    local playerType = player.SubType
    
    return playerType == PlayerType.PLAYER_XXX or 
        playerType == PlayerType.PLAYER_BLACKJUDAS or
        playerType == PlayerType.PLAYER_KEEPER or
        playerType == PlayerType.PLAYER_JUDAS_B or 
        playerType == PlayerType.PLAYER_XXX_B or
        playerType == PlayerType.PLAYER_BETHANY_B
end

function qol.ReverseEmpress:OnCardUse(card, player, flags)
    if qol.ReverseEmpress.HasBug(player) then
        local id = qol.Utils.GetPlayerID(player) 
        qol.print ("Player " .. tostring(id) .. " (" .. tostring(player.SubType) .. ") has bug")
        qol.ReverseEmpress.Data[id] = {
            as = player.SubType, -- In case of character change
            timer = Game():GetFrameCount(),
            hearts = player:GetMaxHearts() + player:GetSoulHearts()
        }
    end
end

function qol.ReverseEmpress:OnUpdate()
    for id, data in pairs(qol.ReverseEmpress.Data) do
        local player = Game():GetPlayer(id)
        local diffTime = Game():GetFrameCount() - 60 * qol.LOGIC_FPS
        
        if diffTime == data.timer then
            qol.print("Effect of Reverse Empress should have disappeared")
            qol.print("Player has " .. tostring(player:GetMaxHearts() + player:GetSoulHearts()) .. " hearts")
        elseif diffTime == data.timer - qol.LOGIC_FPS then
            qol.print("Effect of Reverse Empress is about to disappear")
            qol.print("Player has " .. tostring(player:GetMaxHearts() + player:GetSoulHearts()) .. " hearts")
        end
    end
end

if qol.Config.ReverseEmpress then
    mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.ReverseEmpress.OnCardUse, Card.CARD_REVERSE_EMPRESS)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.ReverseEmpress.OnUpdate)
end

end

--]]

-- R Key not resetting the Mausoleum Mom's Heart beaten flag.

do

qol.RKeyMausoleumHeart = {}

function qol.RKeyMausoleumHeart:PreUseItem(collectible, rng, player, flags, slot, varData)
    Game():SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
end

if qol.Config.RKeyMausoleumHeart then
    mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, mod.RKeyMausoleumHeart.PreUseItem, CollectibleType.COLLECTIBLE_R_KEY)
end

end

-- Dark Esau doesn't allow White Eternal Champions to be defeated
-- Fix this by replacing each white champion that spawn with another 
-- champion.

do

qol.DarkEsauEternalChampions = {}

local function isPlayingTaintedJacob()
    local nPlayers = Game():GetNumPlayers()
    for i = 0, nPlayers - 1 do
        local player = Game():GetPlayer(i)
        if player:GetPlayerType() == PlayerType.PLAYER_JACOB2_B or player:GetPlayerType() == PlayerType.PLAYER_JACOB_B then
            return true
        end
    end
    
    return false
end

function qol.DarkEsauEternalChampions:OnNPCUpdate(npc)
    if not isPlayingTaintedJacob() then
        return
    end
    
    if npc:IsChampion() and npc:GetChampionColorIdx() == ChampionColor.WHITE then
        -- qol.print("Trying to replace eternal champion")
        local entity = nil
        repeat
            if entity ~= nil then
                entity:Remove()
            end
            entity = Game():Spawn(npc.Type, npc.Variant, npc.Position, npc.Velocity, nil, npc.SubType, Game():GetRoom():GetSpawnSeed())
        until not (entity:ToNPC():IsChampion() and entity:ToNPC():GetChampionColorIdx() == ChampionColor.WHITE)
        
        npc:Remove()
    end
end

if qol.Config.DarkEsauEternalChampions then
    qol:AddCallback(ModCallbacks.MC_NPC_UPDATE, qol.DarkEsauEternalChampions.OnNPCUpdate)
end

end