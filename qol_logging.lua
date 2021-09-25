if not qol then
    error("You cannot use qol_logging.lua without loading the Quality of Life mod first")
end

local json = require("json")

qol.include ("qol_config.lua")
qol.include ("qol_io.lua")
qol.include ("qol_os.lua")
qol.include ("qol_socket.lua")
qol.include ("qol_utilities.lua")

local logging = {}
logging._initialized = false

qol.LogLevels = qol.Utils.Enum {
    "MIN",
    "DEBUG",
    "INFO",
    "WARN",
    "ERROR",
    "CRITICAL",
    "MAX"
}

local function validate_handler_type(t)
    return t == "socket" or t == "file" or t == "console"
end

local function validate_file_mode(mode)
    return mode == "a" or mode == "w"
end

local function validate_socket_target(t)
    local ip, port = string.match(t, "(.+):(%d+)")
    if not ip or not port then
        qol.print ("[ERROR] Invalid <ip>:<port> couple in handler: " .. t)
        return
    end
    
    port = tonumber(port)
    if port <= 1024 or port >= 65535 then
        qol.print ("[ERROR] Invalid port " .. port)
        return 
    end
    
    local ip1, ip2, ip3, ip4 = string.match(ip, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
    if not ip1 or not ip2 or not ip3 or not ip4 then
        qol.print ("[ERROR] Invalid IPv4 address: " .. ip)
        return 
    end
    
    return ip, port
end

local function validate_log_level(level)
    return level == "DEBUG" or level == "INFO" or level == "WARN" or level == "ERROR" or level == "CRITICAL" or level == "MIN" or level == "MAX"
end

local function log_level_text2int(level)
    return qol.LogLevels[level]
end

local function validate_formatter_level(level)
    local symbol, text = string.match(level, "([<>=])(%u+)")
    if not symbol then
        symbol = "="
        text = string.match(level, "(%u+)")
        if not text then
            qol.print ("[ERROR] Invalid log level " .. level)
            return
        end
        
        if not validate_log_level(text) then
            qol.print ("[ERROR] Invalid log level " .. level)
            return
        end
        
        qol.print ("[INFO] No comparison operator specified for level " .. level .. ", will use =")
        return symbol, text
    else
        if not text then
            qol.print ("[ERROR] Invalid format level " .. level)
            return
        end
        
        if not validate_log_level(text) then
            qol.print ("[ERROR] Invalid log level " .. level)
            return
        end
        
        return symbol, log_level_text2int(text)
    end
end

local function process_handlers_section(tbl, handlers)
    for _, handler in ipairs(handlers) do
        local htype = handler.type
        
        local name = handler.name
            
        if not name then
            qol.print ("[ERROR] Anonymous handler is not supported in the handlers section")
            goto next_handler
        end
        
        if not htype then
            qol.print ("[WARN] No type provided for handler " .. name .. ", setting it to \"console\"")
            htype = "console"
        end
    
        if not validate_handler_type(htype) then
            qol.print ("[ERROR] Invalid handler type " .. htype .. " for handler " .. name)
            goto next_handler
        end
        
        if htype == "socket" then
            local target = handler.target
            if not target then
                qol.print ("[ERROR] No target provided for socket handler " .. name)
                goto next_handler
            end
            
            local ip, port = validate_socket_target(target)
            if not ip or not port then
                goto next_handler
            end
            
            local socket, sockerror = qol._socket.connect(ip, port)
            if sockerror then
                qol.print ("[ERROR] Unable to connect to socket at (" .. ip .. ", " .. port .. "). Skipping handler " .. name)
                goto next_handler
            end
            
            tbl._handlers[name] = { type = htype, socket = socket }
        elseif htype == "console" then
            tbl._handlers[name] = { type = htype }
        elseif htype == "file" then
            local target = handler.target
            local mode = handler.mode
            
            if not validate_file_mode(mode) then
                qol.print ("[ERROR] Invalid mode for file in handler " .. name)
            end
            
            local file = qol._io.open(target, mode)
            if not file then
                qol.print ("[ERROR] Unable to open file " .. target .. " in mode " .. mode)
                goto next_handler
            end
            
            tbl._handlers[name] = { type = htype, file = file }
        end
        
        ::next_handler::
    end
end

local function default_format()
    return "[%(level) - (%d-%m-%y %H:%M:%S)] %(message)"
end

local function all_levels()
    return qol.LogLevels
end

--[[
Format sequences that can be used (mostly inspired by strftime in Python):
    %d: day of the month in decimal representation (01 - 31)
    %H: hour of the day in the range 0-24
    %m: month in range 1-12
    %M: minutes in range 00-59
    %S: seconds in range 00-59
    %Y: year in range 00-99
    %%: the % character
    %%(message): replaced with message
    %%(level): the level of the log
    %%(logger): the name of the logger
    %%(handler): the name of the handler
--]]
local function do_format(format, logger_name, handler_name, level, ...)
    local result = qol._os.date(format)
    local msg = ""
    local parts = {...}
    for i, value in ipairs(parts) do
        msg = msg .. tostring(value)
        
        if i ~= #parts then
            msg = msg .. " "
        end
    end
    
    result = string.gsub(result, "%%%(message%)", msg)
    result = string.gsub(result, "%%%(level%)", qol.LogLevels[level])
    result = string.gsub(result, "%%%(logger%)", logger_name)
    result = string.gsub(result, "%%%(handler%)", handler_name)
    
    return result
end

local function process_formatters_section(tbl, formatters)
    for _, formatter in ipairs(formatters) do
        local name = formatter.name
        -- Cannot be moved forward, as goto would cross the declaration
        local format = formatter.format
        
        if not name then
            qol.print ("[ERROR] Anonymous formatter not supported")
            goto next_formatter
        end
        
        if not format then
            format = default_format()
        end
        
        tbl._formatters[name] = format
        
        ::next_formatter::
    end
end

local function process_loggers_section(tbl, loggers)
    for _, logger in ipairs(loggers) do
        local name = logger.name
        local handlers = logger.handlers
        
        if not name then
            qol.print ("[ERROR] Anonymous loggers are not supported")
            goto next_logger
        end
        
        tbl._loggers[name] = {}
        tbl._loggers[name]["handlers"] = {}
        
        for _, handler in ipairs(handlers) do
            local hname = handler.name
            local formatters = handler.formatters
            
            if not hname then
                qol.print ("[ERROR] Missing handler name for logger " .. name)
                goto next_logger
            end
            
            if not tbl._handlers[hname] then
                qol.print ("[ERROR] Unknown handler " .. hname .. " for logger " .. name)
                goto next_handler
            end
            
            tbl._loggers[name]["handlers"][hname] = {}
            tbl._loggers[name]["handlers"][hname].log = function(self, level, ...)
                for _, formatter in ipairs(self) do
                    if formatter.cond == "<" then
                        if level >= formatter.level then 
                            goto next_formatter
                        end
                    elseif formatter.cond == "=" then
                        if level ~= formatter.level then
                            goto next_formatter
                        end
                    elseif formatter.cond == ">" then
                        if level <= formatter.level then
                            goto next_formatter
                        end
                    end
                    
                    local format = formatter.formatter
                    local content = do_format(format, name, hname, level, ...)
                    
                    self:emit(level, content)
                    ::next_formatter::
                end
            end
            
            tbl._loggers[name]["handlers"][hname].emit = function(self, level, content)
                local handler = tbl._handlers[hname]
                
                if handler.type == "console" then
                    Isaac.ConsoleOutput(content .. "\n")
                elseif handler.type == "socket" then
                    local data = {
                        name = name,
                        handler = hname,
                        level = level,
                        content = content
                    }
                    handler.socket:send(json.encode(data))
                elseif handler.type == "file" then
                    handler.file:write(content .. "\n")
                end
            end
            
            if not formatters then
                qol.print ("[WARN] No formatter provided for handler " .. hname .. " in logger " .. name .. ". Will use a default formatter for all levels instead")
                formatters = {
                    { name = "__DEFAULT__", levels = qol.LogLevels }
                }
            end
            
            for _, formatter in ipairs(formatters) do
                local fname = formatter.name
                local internal_formatter = tbl._formatters[fname]
                local level = formatter.level
                local level_cond
                local level_int
                
                if not fname then
                    qol.print ("[ERROR] Missing formatter name for handler " .. hname .. " in logger " .. name)
                    goto next_formatter
                end
                
                if not internal_formatter then
                    qol.print ("[ERROR] Unknown formatter name " .. fname .. " for handler " .. hname .. " in logger " .. name)
                    goto next_formatter
                end
                
                level_cond, level_int = validate_formatter_level(level)
                
                if not level_cond or not level_int then
                    goto next_formatter
                end
                
                table.insert(tbl._loggers[name]["handlers"][hname], { cond = level_cond, level = level_int, formatter = internal_formatter })
                ::next_formatter::
            end
            ::next_handler::
        end
        
        tbl._loggers[name].log = function(self, level, ...)
            for _, handler in pairs(self["handlers"]) do
                handler:log(level, ...)
            end
        end
        
        for _, level_name in ipairs { "debug", "info", "warn", "error", "critical" } do
            tbl._loggers[name][level_name] = function(self, ...)
                self:log(qol.LogLevels[string.upper(level_name)], ...)
            end
        end
        
        ::next_logger::
    end
end

local function process_file(tbl, content)
    local handlers = content["handlers"]
    if not handlers then
        qol.print ("[CRITICAL] No handlers section provided in logging configuration file")
        return
    end
    
    local formatters = content["formatters"]
    if not formatters then
        qol.print ("[WARN] No formatters section provided in logging configuration file, will use default format for all loggers")
        formatters = {}
    end
    
    local loggers = content["loggers"]
    if not loggers then
        qol.print ("[WARN] No loggers section provided in logging configuration file, no logging will occur")
        loggers = {}
    end
    
    process_handlers_section(tbl, handlers)
    process_formatters_section(tbl, formatters)
    process_loggers_section(tbl, loggers)
end

function logging:Init()
    --if self._initialized then
    --    return
    --end
    
    self._initialized = true
    self._loggers = {}
    self._handlers = {}
    self._formatters = {}
    self._formatters["__DEFAULT__"] = default_format()

    local file = qol._io.open(qol.Config.LoggersFile)
    if not file then
        qol.print ("No loggers file " .. qol.Config.LoggersFile .. " found")
        return
    end
    
    local content
    
    local result, msg = pcall(function() 
        content = json.decode(file:read("a"))
        file:close()
    end)
    
    if not result then
        qol.print ("[ERROR] Error while processing loggers file " .. qol.Config.LoggersFile .. ": " .. msg)
        return
    end
    
    process_file(self, content)
end

function logging:log(logger, ...)
    if not self._loggers[logger] then
        return
    end
    
    self._loggers[logger]:info(...)
end

for _, log_level in ipairs{ "debug", "info", "warn", "error", "critical" } do
    logging[log_level] = function(self, logger, ...)
        if not self._loggers[logger] then
            return
        end
        
        self._loggers[logger]:log(qol.LogLevels[string.upper(log_level)], ...)
    end
end

function logging:GetLogger(name)
    return self._loggers[name]
end

qol._logging = logging

if qol._debug then
    qol._error()
end