# Medic Experience-Based Combat System
MEBCS is a system designed for Combat Regions, providing similar functionality of [EBCS](../EBCS.md) in terms of using Experience permissions, handling `on_death` events, creating and managing safezones as well as teleporting agents.

However MEBCS is much more extensive, aiming to provide a similar experience inspired by *Battlefield 6*.

* *Combatants* enter a 'downed' state on death.
* *Downed Combatants* have a small window where they can be revived. *Teammates* can revive them by crouching and aiming at the *Downed Combatant* to initiate the revival state and also drag their bodies with them into cover.
* *Downed Combatants* can request revive and by holding the button down their available downed time is extended significantly.
* *Teammates* nearby will have a revive request of nearby *Downed Combatants* marked on their HUDs
* *Downed Combatants* can also skip their down phase to redeploy immediately instead of waiting out, choosing from an overview of the combat region where they want to deploy based on available respawn points

To support this functionality the system introduces **Teams** and **Respawn Points** as [*synchronised linkset data*](./Sync-LSD.lsl) across objects and the HUDs.

This functionality is based on the feedback proposals:
- https://feedback.secondlife.com/scripting-features/p/combat-21-respawns
- https://feedback.secondlife.com/scripting-features/p/combat-21-teams
and implements fallback functions based on these proposals in [MEBCS-Polyfill.lsl](./MEBCS-Polyfill.lsl)




