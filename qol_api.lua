-- Functions that extend the Lua API.

if not _G["qol"] then
    error("You cannot include qol_api.lua without loading the Quality of Life mod first")
end

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

if qol._debug then
    qol._error()
end