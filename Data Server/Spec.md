Data Server
===========

The "Data Server" solves the problem of sharing settings or state to a lot of different objects.
Any script can make changes to the settings/state and that data is then shared across all your objects.

Your usecase is that you want to deploy a large system for your project across a region.
The security model is simple in that these are all objects owned by the same user.

I will be using this terminology to describe two kinds of data structures:
1. Entities
2. Singletons

Entity data is when you have a list of 'objects' that you want track pieces of data of, per object.
For example, you have a list of 'player's for your game and you wanted to track the score of each 'player'.
The server helps solve the problem of wanting to share 'data per thing' across all your objects.

Singletons is instead the opposite: one global configuration object. For example your game has settings
such as the current difficulty level, or how much money/score each player should receive for solving an objective.
It solves the problem of sharing common data across all your objects.


Messages are sent on the listener channel as JSON objects (`{}`) with an "event" property (e.g. `{"event":"…"}`)
This channel can be configured depending on your system to make it project-specific.


Entities
========

"event" is a string with one of the following:

Script -> Server
Adding, updating and removing
- "entity.add"
    Used to tell the Data Server to add an entity
    -- or if it already exists to reset the entity with the given properties
- "entity.patch"
    Tell Data Server to apply a partial update to the entity, e.g. updating one or a few properties
- "entity.remove"
    Tell Data Server to remove an entity

Server -> Script(s)
- "entity.added"
    Sent by Data Server to tell other scripts that an entity has been added
- "entity.patched"
    Sent by Data Server on updated properties for an entity
- "entity.removed"
    Sent by Data Server when an entity has been removed

Get a list of all entities
- "entity.get" (with "*" wildcard as identifier)
    Used to request a list of entities from a Data Server
- "entity.list.fragment"
    Sent by Data Server directly (`llRegionSayTo`) for a list fragment if there's a lot of data
- "entity.list.end"
    Sent by Data Server directly for the end of the list

Get a specific entity an the entire singleton
- "entity.get"
    Used to request a specific entity or singleton from a Data Server
- "entity.result"
    Sent by Data Server directly to a "get" request of the result


Now the trick here is that "entity" in the event names above is replaced with one of the custom types
defined in the Entities list of the server.

For example if Entities is set to:
```lsl
list Entities = ["agent", "objective"];
```

This means that you can use commands like "agent.add", "agent.patch", "objective.list" in your scripts and
consequently also receive corresponding events like "agent.added", "agent.patched", etc.

You can track all kinds of entities and this is where the flexibility of the server really starts to shine.
The limit is pretty much as much data can be stored within linkset data of the server object.

Entities should have a unique key, "identifier" property used in the messages above.
For example with the case of our 'agent' entities this would be the agent keys.
We would then format our messages like so:
```json
{
    "event": "agent.add",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca"
}
```

We can pass in additional data as any extra properties like so:
```json
{
    "event": "agent.add",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "score": 100,
    "money": 0,
    "equipment": []
}
```

The server will then announce the change like so to all objects:
```json
{
    "event": "agent.added",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "score": 100,
    "money": 0,
    "equipment": [],
    "skills": []
}
```

If we want to make a change, for example adding to the score and changing the money:
```json
{
    "event": "agent.patch",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "score": 140,
    "money": 10
}
```

The Data server will save the data locally in linkset data and announce the change to other scripts:
```json
{
    "event": "agent.patched",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "score": 140,
    "money": 10
}
```

However if the score was already at 140, the server would have announced only this instead:
```json
{
    "event": "agent.patched",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "money": 10
}
```
The server only announces actual changes that were made.


"*" may be used as a wildcard in some cases, such as in entity.patch to target all entities of that type.
For example to reset the score of all our agents back to 0:
```json
{
    "event": "agent.patch",
    "identifier": "*",
    "score": 0
}
```

Vice versa the server can also use wildcards in update announcements as well:
```json
{
    "event": "agent.patched",
    "identifier": "*",
    "score": 0
}
```


Singletons
==========

The API for singletons is the same apart from the fact that singletons do not have an identifier.
You can define multiple singletons to cover different usecases.
