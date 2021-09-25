local socket
local result = pcall(function() socket = require("socket") end)

if not result then
    socket = {
        connect = function(ip, port)
            local result = {}
            result.send = function(self, data, i, j)
                return 0
            end
            
            return result
        end
    }
end

qol._socket = socket

if qol._debug then
    qol._error()
end