if not qol then
    error("You cannot use qol_io.lua without loading the Quality of Life mod first")
end

local io
local result = pcall(function() io = require("io") end)

if not result then
    io = {
        open = function(name, mode)
            local result = {}
            result.write = function(self, ...)
                
            end
            
            result.read = function(self, ...)
                return ""
            end
            
            result.close = function(self)
                return 0
            end
            
            return result
        end
    }
end

qol._io = io

if qol._debug then
    qol._error()
end