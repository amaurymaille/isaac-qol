if not qol then
    error("You cannot use qol_os.lua without loading the Quality of Life mod first")
end

local os
local result = pcall(function() os = require ("os") end)

if not result then
    os = {
        date = function(format)
            return ""
        end
    }
end

qol._os = os

if qol._debug then
    qol._error()
end