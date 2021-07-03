if not qol then
    error("You cannot use qol_config.lua without loading the Quality of Life mod first")
end

qol.Config = {}

-- Global enabler for the quality of life fixes on Tainted Jacob
qol.Config.TJacob = true

-- Makes Dark Esau invulnerable as long as the boss of the floor has not been defeated.
-- In Greed Mode, Dark Esau will remain invulnerable as long as the Nightmare Wave has
-- not been completed.
-- If Tainted Jacob becomes The Lost, Dark Esau will become vulnerable whether 
-- the boss / nightmare wave has been defeated.
qol.Config.DarkEsauInvulnerable = qol.Config.TJacob and true

-- Add a Book of Shadows shield effect on Tainted Jacob when he gets it by Dark
-- Esau.
qol.Config.TaintedJacobBOS = qol.Config.TJacob and true

-- Configure the duration of the Book of Shadows shield effect on Tainted Jacob. 
-- Has no effect if the configuration disables the shielding. Value is in seconds.
qol.Config.TaintedJacobBOSDuration = 2