if not qol then
    error("You cannot use qol_config.lua without loading the Quality of Life mod first")
end

qol.Config = {}

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

-- Enable Delirium fixes (in progress, there is a lot to fix)
qol.Config.Delirium

-- Amount of time in LOGIC frames (30 LOGIC frames / second) during which the 
-- player is immune to contact damage with Delirium (whatever form it has taken) 
-- and to the bullets he spawns. The grace window starts on the immediate frame 
-- during which Delirium teleported / morphed / spawned a tear while transformed as 
-- certain bosses.
-- 
-- Current bosses: Mom's Foot, Big Horn (only if underground), Mega Satan (head and hands)
qol.Config.DeliriumGraceTime = 30

if qol._debug then
    qol._error()
end