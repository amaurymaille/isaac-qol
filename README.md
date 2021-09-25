# The Binding of Isaac Repentance - Quality of Life

This mod aims to bring some quality of life fixes to The Binding of Isaac Repentance,
both on the modders and on the players ends.

Players fixes include bugs, balancing of mechanics and so on.
Modders quality of life changes include a logging API, helper functions around some of
the weird things in the modding API, and so on.

# Bug fixes

As of now (2021-09-25) there are the following bug fixes:
* IV - The Emperor? Softlock. When used on Caves / Catacombs / Flooded Caves / 
Mines / Ashpit II, IV - The Emperor? teleports the player to a Mom fight that
has no exit door. This mod spawns an exit door each time the player goes to 
this room.
* XVIII - The Moon? Softlock. Sometimes, the path leading back from the Ultra
Secret Room will lead the player to a locked (Super) Secret Room. This mod 
forcibly opens a door out of the (Super) Secret Room.
* Exiting the Genesis room through the beam of light no longer prevents the 
player from reaching the Cathedral. Additionnaly, using Glowing Hourglass at
the beginning of the Cathedral and returning to Womb II doesn't prevent the 
player from reaching Sheol if they want.

# Mechanics 

# Version history

* 2021-07-07: entering a (super) secret room from a red room will open a door 
out of the room that leads to a non red room. If there are enemies in the 
(super) secret room, the newly opened door will automatically close. 
* 2021-09-25: added logging API.

# Planned work

- [ ] When playing as Tainted Jacob, getting hit by Dark Esau gives the player a 
Book of Shadows effect for a few seconds, in order for the player to find where
Tainted Jacob is and avoid instant death.
- [ ] When playing as Tainted Jacob, Dark Esau cannot be damaged until the floor's
boss has been defeated (Nightmare Wave beaten in Greed(ier) mode) or until 
Tainted Jacob has been turned into The Lost.
- [ ] In Greed(ier) mode, prevent the Light White and Pulsating Red champions from 
appearing simultaneously as this can lead to unwinnable situations.
- [ ] If the player reaches The Chest / Dark Room with only half the key to open the
door to Mega Satan, and can still access an Angel Room, spawn a ladder that leads
the player to an extra room where they can fight an angel for the second key 
piece.
- [ ] Prevent the player from crashing / killing themselves because of other bugs.
This includes, and is not limited to:
	- [ ] Preventing the player from using Joker in the mirrored version of 
Downpour / Dross II
	- [ ] Preventing the player from using Dull Razor in the mirrored version
of Downpour / Dross II
	- [ ] Preventing the player from using 0 - The Fool? when all their red
hearts are empty
- [ ] Fix some of Delirium's unavoidable attacks, such as instant damage when it 
morphs into Mom's Foot.
- [ ] Add a visual indication around Tainted Eve's hearts to indicate how much health
will get refilled when using Sumptorium.
- [ ] Prevent both Tainted Eve and Tainted Magdalene from receiving Curse of the 
Unknown as both characters rely heavily on knowing how much health they have.
- [ ] Curse of the Lost no longer appears in The Void.
- [ ] Defeating Hush guarantees a portal to The Void on the next end boss fought 
(??? / The Lamb / Mega Satan (this one is going to be tricky))
- [ ] Trapdoors should lead to special areas where the player can chose to branch
towards the alternate path, in case they were sent to an error room. This is 
complicated because the secret exit room is only generated once the boss of
the floor is defeated.
- [ ] The player should not receive Curse of the Lost or Curse of the Maze during 
the "Cursed" challenge.
- [ ] Prevent Curse of the Lost and Curse of the Maze from stacking with each other.
- [ ] Attempt to rework Greed(ier) mode to make it a bit more interesting (long term)
- [ ] Attempt to fix as many bugs as possible on Delirium, or even rewrite the entire
fight (long term)
- [ ] Attempt to change the way The Void generates (long term)
- [ ] When (Tainted) Lost uses XIV - Temperance or XX - Judgement, give him a few
frames of complete invulnerability to the spawned machine / devil beggar to avoid 
instant death.
- [ ] When XVIII - The Moon? doesn't open any door at all in the Ultra Secret 
Room, give a way out to the player.
