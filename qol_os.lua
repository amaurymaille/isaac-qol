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