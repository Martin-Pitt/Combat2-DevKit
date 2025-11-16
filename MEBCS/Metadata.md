# MEBCS Metadata

Combat2 DevKit:
* Teams
	- Config
	- List of agents per team
	- Individual agent and object team assignments
* Respawns
	- List of objects assigned as a respawn point per team
	- Individual respawn point team assignments (which team a respawn point belongs to)


Usecases:
- Need to know downed teammates
	- to track their location in the HUD
	- allow the combatant to revive them
- Teamboard tracks active combatants
	- This avoids AFK or people not actually participating from being listed on teamboards / scoreboards / announcements / HUDs
- Neutral hazards part of the region build should be assigned to an Environment team, so even if the owner participates in combat / has a different team their region build hazards are treated as from the ownerless environment respectively


More clear states on the lifecycle of a combatant/player are needed in the combat system:
- **Spectator**
- **Active**
- **Downed**
- **Dead**


Logic:
- Combatant can become Active from Spectator if they are:
	have entered mouselook recently
	OR
	caused damage to someone
	OR
	are sitting on a health-based object (that is a vehicle or deployable)
- Combatants can become Spectator from Active if:
	they are unassigned
	OR for a while / >5mins (
		haven't entered mouselook
		OR
		caused damage to someone
	) AND are not sitting on a health-based object
- If someone has been dead for an extended while (20-30mins), just respawn them to the hub and unassign them


So I need to enhance the Teams lists with additional meta:
* MEBCS_Combatant.Activity:<uuid> = enum Active | Spectator
* MEBCS_Combatant.Status:<uuid> = enum Alive | Downed | Dead
* MEBCS_Combatant.Downed:<uuid> = optional enum Downed | Requested | Reviving
* MEBCS_Teams_Active.<team_no> = List of active combatants per team
* MEBCS_Teams_Downed.<team_no> = List of downed combatants per team




