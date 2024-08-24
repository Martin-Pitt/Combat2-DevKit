# Combat2 Respawns
This is a set of scripts to implement a respawn system in Second Life with the new Combat2 features.

Combat2 Respawns system would be managed by the region owner / SLMC.

The region setting `death_action` needs to be set to `3` (No Action) and the scripts need to set to an experience.

To make it easy for the commnunity to use a singular experience around respawn systems, there is an experience called [Combat2 Respawns](secondlife:///app/experience/b14afc84-6261-11ef-92f8-0242ac110003/profile).

Scripts with the Combat2 Respawns experience set are available on the marketplace at (TBD), or you can find the scripts available in-world at the [opensource shop at Vertical Sim](http://maps.secondlife.com/secondlife/Vertical%20Sim/244/19/3002) (TBD).


## Respawn Systems
Here are respawn systems with increasing complexity.

### Simple Spawn Point
A single spawn point. Any deaths in the region are rerouted to the location of the object the script is in.

This is effectively similar to the `Teleport to parcel landing point` region setting.

### Multiple Spawn Points
Demonstrates multiple spawn points. Any deaths in the region are rerouted to a random spawn point marker that was found during initialisation.

### Group-based Spawn Points
Respawn system that is based on the detected group. Deaths for the agents are rerouted based on their group affiliation or lack thereof.

### Team-based Spawn Points
Respawn system that works with agents marked with a team. Deaths for agents are rerouted based on their team affiliation or lack thereof.

### Team-based Push-Pull Spawn Points
If you have a conquest or territorial control system, this system allows it to adjust the spawn points based on the current objective.

For example if each team has a headquarters/base and there are three territories inbetween called A, B and C, the spawn points should be placed as such:
![image](https://github.com/user-attachments/assets/437bbbd3-f16c-4ca7-b33f-c10b290ec73c)




## Interacting with the script

Link messages are used to send information from the respawn script to other custom scripts:

| Number                                    | String      | Key         | Description                                                  |
| ----------------------------------------- | ----------- | ----------- | ------------------------------------------------------------ |
| `MESSAGE_INITIALISED = 1`                 |             |             | Script was initialised                                       |
| `MESSAGE_DIED = 2`                        |             | Agent       | Agent has died                                               |
| `MESSAGE_RESPAWNED = 3`                   | Position    | Agent       | Agent respawned                                              |
| `MESSAGE_DIED_WITHOUT_EXPERIENCE = 4`     |             | Agent       | Agent respawned but they haven't accepted the experience     |
| `MESSAGE_EXPERIENCE_DENIED = 5`           | Reason      | Agent       | The experience permission was denied for some reason         |
