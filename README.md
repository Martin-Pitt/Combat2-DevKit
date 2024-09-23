# Combat2 Respawns

Respawns, teams, game objectives and more for Combat2.

At its core Combat2 Respawns (C2R) is an opensource system for Combat2 regions which allows them to have team-based respawns and objective systems.

The system would be managed by the region owner / SLMC / game developer.

There are also additional scripts/systems that can be used by weapon and vehicle creators to add standardised functionality (Layers) or integration with C2R (Vehicle Respawns). Avatar appearance could also be modified, e.g. changing uniform appearances based on teams like Attacker or Defender, Blue or Red teams, etc, or if entering a snowy-themed area and switching to a snow camouflage texture set.

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

> Status: Working Implementation

The *Tracking Server* is a script that provides an event-based alternative to `llGetAgentList()` as well as a platform to attach custom data per agent.

Tracking Servers work in a distributed way, allowing for multi-region setups. For that to work well, servers need to be next to eachother on region boundaries.

The server will send out an event when an agent has entered or left your region or multi-region estate and there are also update events for any changes to data, such as their active group or for custom data like what team they are part of, which area they are located in, experiences they have allowed or any other custom scripts that interact with the server to provide additional data. The Tracking Server will remember any custom data that you save to that agent until they leave.

Tracking consists of:
- Only one Tracking Server per region that keeps track of agents and data related to them
- A Replica Tracking script in your scripted objects -- this script listens to the Tracking Server and keeps the object in sync with the server data, this is known as data replication


#### Data Replication

> Status: Todo examples of all combinations

With the Tracking Server keeping well, track of everything, how does your scripted object get insight into that information?

There are two ways:

1. Directly listen to the public tracking channel yourself at -906433013
2. Use a *Replica* script, which will do the work for you and grab the full or filtered list of data and stay in sync with little updates

There's also two particular usecases:
a. Info for a specific agent
b. Info across many or all agents



<a name="respawns"></a>
### Respawns

> Status: Reimplement to work with latest Tracking Server

The respawn system helps manage respawns and respawn points. When an agent dies in the region the script will respawn them at a suitable location based on criteria.

For the respawn system to be able to work, the region settings need to configured. The region's `death_action` needs to be set to `3` (No Action) which prevents the region from inteferring. Also the system needs to be associated with an Allowed Experience within the region for the teleportations to work. This project offers an experience called *Combat2 Respawns* that can be used.

Scripts with the *Combat2 Respawns* experience set are available on the marketplace at (TBD), or you can find the scripts available in-world at my region [Vertical Sim]((http://maps.secondlife.com/secondlife/Vertical%20Sim/244/19/3002)) (TBD).


<a name="teams"></a>
### Teams

> Status: Working Implementation

Agents can be assigned to teams. This is simply a string name in the Tracking custom data that exists against each agent.

You can compute a team list by going through each tracked agent and checking what team they belong to.


<a name="territories"></a>
### Territories

> Status: Reimplement to work with latest Tracking Server

Territories are high-level 2D areas that can be owned by a team. Territories are typically linked to an objective, such as a capture point.

These have a 2D polygon shape and can have borders shared with other territories. Territories can be created using objects with a specially formatted name and description. These objects don't need any script and should be owned by you. There is a scanner that can be triggered which will scan the entire region for these objects to update the configuration.

With territories connected to eachother and capture points setup you can force a sequential progress in your game design.


<a name="objectives"></a>
### Objectives

> Status: Reimplement to work with latest Tracking Server

Objectives can take many forms and can provide a sequential order of goals. They can also help provide an endgame to conclude a session or you can design an indefinite game.

Objectives can control territorial ownership to teams. These can be reversible such as capture points, or irreversible like Breakthrough/Rush game modes where attackers move the frontline forward or the defenders try to hold them back.


<a name="areas"></a>
### Areas

> Status: Simple Implementation, but could use some better tools to manage

Areas are volumes defined in 3D that zone and subdivide your region into named areas. The preferred naming convention is to use dot-separated names to indicate hierarchy, e.g. `Hub` -> `Hub.Store`, `City` -> `City.Skyscraper 1` -> `City.Skyscraper 1.Rooftop` etc. You can be as detailed or high level as you wish. However, this can also increase amount of data updates passed along to all objects listening, so find a balance for a busy region or detailed areas.

The top level area is generally a *zone* and zones help define the largest areas of your region, for example where the hub(s), game(s), arena(s) or battlefield(s) are. There are many areas you could have, for example you could have a hub with a shop, there could also be a lobby area in the hub zone before players enter the game, there could also be training or tutorial zones separate from the main game zone. Many ways to slice and dice. The areas could have uses for defining safe and dangerous areas more detailed than parcels allow. Areas can also be helpful for metrics/diagnostics.

The Respawn system should be restricted to a zone so that you can manage safe areas and where respawns can happen.


<a name="layers"></a>
### Layers

> Status: Concept

Equipment layers are a system that allows you to easily switch weapons and equipment via hotkey gestures for your avatar.

You attach your equipment before combat and then can use your hotkeyed gestures to swap your active weapon/equipment (or active layer) in the middle of combat easily. A supported HUD can also show which layers you have currently and their status, such as cooldowns or ammo count.

Note that only one piece of equipment can be attached in a specific layer. The equipment creator defines the layer of their attachment.

The system is inspired by many games, from Half Life, Battlefield to Helldivers 2, etc.

The convention within the SLMC is to have three weapon layers. Currently most throwables are part of a HUD, however for balancing there is a desire to move to having throwables take up a layer slot as being able to throw grenades while in the middle of shooting is problematic, there is also the benefit of being able to clearly telegraph the action and this also allows the user to cook grenades or have better control and flexibility around their throwables. Grenades could still be setup to auto-throw automatically for those who prefer: 1) press hotkey G, 2) attached grenade changes active layer to throwable layer, 3) becomes visible, plays throw animation, 4) rezzes grenade projectile, and then 5) swaps to gun or equipment on previous active layer.

So it would be three weapon layers (Layers 1, 2 and 3), as well as a layer for throwables (Layer 4).

Layer 1, 2 and 3 are typically: Primary, Secondary and Special weapons/gadgets.


<a name="vehicle-respawns"></a>
### Vehicle Respawns / Teleports

> Status: Concept

Vehicle respawns/teleports are currently a non-standard feature that each content creator designs themselves or that a vehicle lacks. Here C2R provides a standard that vehicle creators can use, or for vehicle users to add to their vehicles if they are modifiable.


<a name="vehicle-layers"></a>
### Vehicle Layers

> Status: Concept

Vehicles may also have their own loadouts and this could work in a similar way to avatar equipment layers. This would allow HUDs to show the vehicle loadout as layers and the active layer for the vehicle as well as any cooldowns or ammo counts.

Additionally a vehicle seat may be designed in such a way to leave an avatar vulnerable to gunfire but allow them to use their own avatar equipment instead of disabling them by default.





## FAQ
<dl>
  <dt>How do I set this up in my region?</dt>
  <dd>Follow the [quickstart guide](Quickstart.md) (TBD)</dd>
  
  <dt>Can I customise this for my SLMC/Game?</dt>
  <dd>Yes, it's all opensource. Although keep in mind if you deviate on the listener message protocol it could cause issues with existing HUD or other systems (Layers, Vehicle Respawns, etc)</dd>
  
  <dt>Can I just use the Tracking Server alone?</dt>
  <dd>Yes, it can be used fully standalone if you just need an event-based `llGetAgentList` and add whatever custom data you want. It's really quite helpful and avoids bugs around managing a list of agents and distributing that along with extra data.</dd>
  
  <dt>I'm making my own game, what do I get out of this?</dt>
  <dd>This is a full platform to help make the most out of the new Combat2 tools by adding extra systems. You can use the project as-is or fork it.</dd>
  
  <dt>I'm weapon creator, what is this?</dt>
  <dd>As a weapons creator the most directly useful feature is the Layers system. Typically with a weapon you can draw/sling. The layers system automates the draw/sling feature and whether the weapon should detach to avoid a layer conflict if it occupies the same layer. Additionally it provides an API so that data around cooldowns and ammo can be passed to HUDs.</dd>
  
  <dt>I'm a vehicle creator, what?</dt>
  <dd>Vehicle creators can enjoy being able to use the layers system for their vehicles, which can help skip steps in HUD dev and/or use a standard one. Additionally the teleport/respawn system allows vehicles to be able to move about the level and respawn in a similar way to avatars. Also send out logs into the Combat Log so that vehicle deaths can be picked up by PvP/PvE/Damage/Kill Feed HUDs.</dd>
  
  <dt>I design levels, hmmm?</dt>
  <dd>Without needing to do scripting, apart from maybe resetting scripts, you can configure and tweak with scriptless objects how the respawn points are placed, as well as how territories and areas are shaped or connected -- it's all set based on the name and descriptions of prims. There are also ready to use objectives that you can drop into each territory to give them goals.</dd>
  
  <dt>I got a question?</dt>
  <dd>Ask away, feel free to IM me in-world</dd>
  
  <dt>Who made this?</dt>
  <dd>Nexii Malthus</dd>
</dl>

<!--
  TODO:
  - Continue working on status of each concept
  - Quickstart guides for single regions up to multi-region estates
  - Level Design guide
    - Setting up territories
    - Areas?
  - Game Dev scripting guide
    - Custom data
    - Scripting objectives
  - Weapon Creator guide
    - Layers
  - Vehicle Creator guide
    - Vehicle Layers
    - Teleports
    - Respawns / Deaths
-->
