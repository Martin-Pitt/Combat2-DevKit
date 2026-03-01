# Medic Experience-Based Combat System
MEBCS is a system designed for Combat Regions, providing similar functionality of [EBCS](../EBCS.md) in terms of using Experience permissions, handling `on_death` events, creating and managing safezones as well as teleporting agents.

However MEBCS is much more extensive, aiming to provide a similar experience inspired by modern games like Battlefield 6, Apex Legends, etc.

* *Combatants* enter a 'downed' state on agent death
* *Downed Combatants* have a small window where they can be revived otherwise they become *Dead Combatants*
* *Downed Combatants* can request a revive, their available downed time is extended during this
* *Downed Combatants* can also skip their down phase to redeploy immediately, they'll become *Dead Combatants* instead
* *Teammates* can revive them by crouching and aiming at the *Downed Combatant* to initiate the revival state and also drag their bodies with them into cover
* *Teammates* nearby will have a revive request of nearby *Downed Combatants* marked on their HUDs
* *Dead Combatants* have to deploy, via an overview of the combat region, and select available respawn points

To support this functionality the system uses **Teams** and **Respawn Points**.
This is based on the feedback proposals:
- https://feedback.secondlife.com/scripting-features/p/combat-21-respawns
- https://feedback.secondlife.com/scripting-features/p/combat-21-teams

The Combat2 DevKit supports the datastructures of **Teams** and **Respawn Points** via [*synchronised linkset data*](./Sync-LSD.lsl) across objects and the temp-attach HUDs. The DevKit implements the specification as a polyfill based on the proposals in [Combat2-Polyfill.lsl](./Combat2-Polyfill.js)


