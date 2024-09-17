# Combat2 Respawns

Respawns, teams, game objectives and more for Combat2.

At its core Combat2 Respawns (C2R) is an opensource system for Combat2 regions which allows them to have team-based respawns and objective systems.

The system would be managed by the region owner / SLMC / game developer and there are also additional scripts.

Concepts and scripts introduced are:
- [Tracking](#tracking)
- [Respawns](#respawns)
- [Teams](#teams)
- [Territories](#territories)
- [Objectives](#objectives)
- [Areas](#areas)
- [Layers](#layers)
- [Vehicle Respawns](#vehicle-respawns)
- [Vehicle Layers](#vehicle-layers)

The minimum necessary for C2R are: Tracking and Respawns. Everything else adds value and allows more complex gameplay.

Although Tracking can also be used standalone if you just want to enjoy an event-based `llGetAgentList` and being able to easily distribute custom data per agent. Like if you are developing a game for an event like halloween or christmas.


## Concepts

<a name="tracking"></a>
### Tracking

The tracking server is a script that provides an event-based alternative to `llGetAgentList()` as well as custom data per-agent, e.g. what team they are part of.

The servers work in a distributed way, allowing for multi-region setups. The servers need to be positioned closely next to eachother across sim boundaries for data to be shared with eachother, otherwise a relay near the border can help.

In addition to events on agents entering or leaving your region or multi-region estate, there are also update events for any changes in the custom data, e.g. if they had joined or changed teams.

Tracking consists of:
- One server in the region that tracks agents via a llGetAgentList timer
- Script in your objects that listens to the server and keep in sync with the server data locally via Linkset Data


<a name="respawns"></a>
### Respawns

The respawn system itself is an experience-based teleporter system currently where the region setting `death_action` needs to be set to `3` (No Action) and scripts need to be set to an allowed experience within the region. The project offers an experience called Combat2 Respawns that can be used.

Scripts with the Combat2 Respawns experience set are available on the marketplace at (TBD), or you can find the scripts available in-world at my region [Vertical Sim]((http://maps.secondlife.com/secondlife/Vertical%20Sim/244/19/3002)) (TBD).


<a name="teams"></a>
### Teams

Agents can be assigned to teams. This is simply a string of custom data that exists against each agent. You can compute a list by going through each agent and checking what team they are assigned to.


<a name="territories"></a>
### Territories

Territories are high-level 2D areas that can be owned by a team. Territories are typically linked to an objective, such as a capture point.

These have a 2D polygon shape and can have borders shared with other territories.

This can allow for objectives to force a sequential progress on a team, such as having to own a neighbouring territory before that team is allowed to capture a point.


<a name="objectives"></a>
### Objectives

Objectives are pretty much that and can take many forms. They provide sequential order of goals. They can also help provide an endgame to conclude a session or you can design a game to be indefinite rather than having a start or end.

Objectives can control territorial ownership to teams. These can be reversible such as capture points, or irreversible such as in Breakthrough or Rush game modes in Battlefield 2042 where the attackers move the frontline forward or the defenders try to hold them back.


<a name="areas"></a>
### Areas

Areas are volumes defined in 3D that zone and subdivide your region into named areas. Areas are named using dot separated string, e.g. "Hub", "Hub.Store", "City.Skyscraper", "City.Skyscraper.Kitchen" etc. You can be detailed or high level as you wish.

The top level area is generally a zone and zones help define areas of your region, for example where the hub is and where the game, arena or battlefields are.

The Respawn system should be restricted to a zone so that you can manage safe areas and where respawns due to combat can happen.


<a name="layers"></a>
### Layers

Equipment layers are a system that allows you to easily switch weapons and equipment via hotkey gestures for your avatar. You attach your equipment before combat and then can use your hotkeyed gestures to swap your active weapon/equipment (or active layer) in the middle of combat easily. A supported HUD can also show which layers you have currently and their status, such as cooldowns or ammo count.

Note that only one piece of equipment can be attached in a specific layer. The equipment creator defines the layer of their attachment.

The system is inspired by many games, from Half Life, Battlefield to Helldivers 2, etc.

The convention within the SLMC is to have three weapon layers, although currently most throwables are part of a HUD. However for balancing there is a desire to move to having throwables take up a layer slot as being able to throw grenades while in the middle of shooting is problematic, there is also the benefit of being able to clearly telegraph the action and also allows the user to cook grenades or have better control and flexibility around their throwables.

So it would be three weapon layers (Layers 1, 2 and 3), as well as a layer for throwables (Layer 4).

Layer 1, 2 and 3 are typically: Primary, Secondary and Special weapons/gadgets.


<a name="vehicle-respawns"></a>
### Vehicle Respawns / Teleports

Vehicle respawns/teleports are currently a non-standard feature that each content creator designs themselves or that a vehicle lacks. Here C2R provides a standard that vehicle creators can use, or for vehicle users to add to their vehicles if they are modifiable.


<a name="vehicle-layers"></a>
### Vehicle Layers

Vehicles may also have their own loadouts and this could work in a similar way to avatar equipment layers. This would allow HUDs to show the vehicle loadout as layers and the active layer for the vehicle as well as any cooldowns or ammo counts.

Additionally a vehicle seat may be designed in such a way to leave an avatar vulnerable to gunfire but allow them to use their own avatar equipment instead of disabling them by default.




## FAQ
<dl>
  <dt>How do I set this up in my region?</dt>
  <dd>Follow the [quickstart guide](Quickstart.md)</dd>
  
  <dt>Can I customise this for my SLMC/Game?</dt>
  <dd>Yes, it's all opensource. Although keep in mind if you deviate on the listener message protocol it could cause issues with existing HUD or other systems (Layers, Vehicle Respawns, etc)</dd>
  
  <dt>I got a question?</dt>
  <dd>Ask away, feel free to IM me in-world</dd>
  
  <dt>Who made this?</dt>
  <dd>Nexii Malthus</dd>
</dl>





