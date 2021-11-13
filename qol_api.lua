-- Functions that extend the Lua API.

if not _G["qol"] then
    error("You cannot include qol_api.lua without loading the Quality of Life mod first")
end

qol.include("qol_utilities.lua")

qol.LOGIC_FPS = 30
qol.RENDER_FPS = 60

function qol.Level()
    return Game():GetLevel()
end

function qol.Player(idx)
    return Game():GetPlayer(idx)
end

function qol.Room()
    return qol.Level():GetCurrentRoom()
end

function qol.RoomDesc()
    return qol.Level():GetCurrentRoomDesc()
end

function qol.GridEntity(idx)
    return qol.Room():GetGridEntity(idx)
end

function qol.Entities()
    return qol.Room():GetEntities()
end

function qol.ReplaceChampion(npc, preventColors)
    local entity = nil
    repeat
        if entity ~= nil then
            entity:Remove()
        end
        
        entity = Game():Spawn(npc.Type, npc.Variant, npc.Position, npc.Velocity, nil, npc.SubType, Game():GetRoom():GetSpawnSeed())
    until not qol.Utils.In(preventColors, entity:ToNPC():GetChampionColorIdx())
    
    npc:Remove()
end

if qol._debug then
    qol._error()
end