if not qol then
    error("You cannot use qol_config.lua without loading the Quality of Life mod first")
end

qol.Config = {}

-- (Internal, debug only) Name of the directory that holds the mod
qol.Config.ModPath = "Quality of Life"

-- Loggers file (more useful for modders).
-- This is the path to the file that contains the definition of loggers for
-- the logging API.
qol.Config.LoggersFile = "logs.json"

-- Enable Reverse Emperor Mom's softlock patch.
qol.Config.ReverseEmperor = true

-- Enable Reverse Moon (Super) Secret Room softlock patch.
qol.Config.ReverseMoonSecrets = true

-- Enable Genesis not allowing you to go to Sheol patch.
qol.Config.GenesisSheol = true

-- Enable WIP stuff that may or may not crash your game at random because I'm 
-- working on too much stuff at the same time.
qol.Config.WIP = true

if qol._debug then
    qol._error()
end