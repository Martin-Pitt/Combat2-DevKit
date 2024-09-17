
- Tracking Server reimplemented in C2R
    - Can this be more modular to allow for custom per-agent data?
        - Perhaps a way to split the tracking server entirely down to individual data pieces, for e.g. area, experience, group, etc. Use a counter to check if all data pieces been processed pre-enter
    - Support 3x1 region layouts
        - I think we can resolve this via a Tracking Relay that converts llRegionSay delivered messages on internal -> llWhisper across the sim boundary; Much like how the tracking server itself also is able to deliver messages across a nearby boundary via llWhisper
- Be able to define areas via in-world objects, similar as you do with territories
    - Areas defined as bounding boxes
    - Multiple bounding boxes for one area
    - Bounding box corners can be rotated to create rotated bounding boxes
    - Procedurally generate the function code for Tracking servers to parse a position down to the area
    - Could areas be defined as cylindrical or spherical shapes?
    - Could reflection probes be reused to define areas?
- Be able to visualise areas, territories, etc to show what the system has recognised
    - llDerezObject visuals
    - Maybe realtime?
- Vertical Sim / artificial gravity orientation support?
    - Maybe easiest to just place an Orientation cube for a top level area (e.g. zone)?
    - Orientation will help correctly orient territory 2D shapes, so that I can do vertical territories
- HUD that shows territories, objectives and respawn points
    - Show closest/current respawn points that will be used on death or allow someone to set a preferred respawn point
    - Able to teleport back to the hub or (re)deploy into the game when in hub through active respawn points
- Vehicle respawns? Teleporting vehicles on OBJECT_DEATH
    - Possibly via generateVehicleChannel(...)
- Fold the layers system idea into C2R
    - Differentiate avatar and vehicle weapons, so that one can OPTIONALLY disable avatar weapons depending on the vehicle seat. For example some vehicle seats might allow someone to poke out of a vulnerable spot to be able to shoot outwards. Another vehicle seat might instead be pilot who has no weapons at all. Another vehicle seat might be a gunner which allows a person to control different vehicle weapons, such as the cannon on a tank or switch over to the secondary which is a machine gun to mow down people.
- Redo the Flag objective as a 'Control Point' instead
    - Perhaps work based on area instead? Use sensor only for moving control points
- Convoy objective (moving control point)
- CTF objective
- Cross-sim respawns -- may need to figure out a way to have relays and proxies in other sims


Concepts:
- Respawns
- Teams
- Territories
- Objectives
- Areas
- Layers
- Vehicle Respawns
- Vehicle Layers


Respawns are points where someone can respawn. If a respawn point is contained within a territory it is linked to it. Respawn points can be restricted to a specific team. When contained within a territory it'll disable/enable based on territory team ownership.


Teams are defined by a name and can be assigned to an agent. Avoid using the same team name across different areas unless intended. If you want to separate your games then avoid team naming conflicts.


Areas are 3D volumes and hierarchical. Area names are dot separated, with the top level area being a zone. A zone is a separate gameplay area.


Territories are more conceptual and have a 2D polygon shape. They can be linked to an objective, which can be used to affect team ownership of that territory. Territories are optional.


Objectives are a sequence of goals. They can take many forms, a common objective is control points, where you capture territories by standing in a specific area by being the majority within that area.




