/*

JSON Server is an LSL script that saves useful data into LSD, other scripts can make
changes and those changes are distributed and synchronised to other scripted objects.

The JSON Server either tracks a list of named objects called Entities or
singular objects called a Singleton. This is to differentiate for example
a list of objects versus a global configuration object.

Such as a list of agents or game settings.

Messages are sent on the JSON_CHANNEL as JSON objects with an "event" property.

event is a string with one of the following:
- "entity.add"
    Used to tell the JSON Server to add an object or
    if already exists to reset object with the given properties
- "entity.patch"
    Tell JSON Server to apply new property settings
- "entity.remove"
    Tell JSON Server to remove an object
- "entity.added"
    Sent by JSON Server to tell other scripts that an object has been added
- "entity.patched"
    Sent by JSON Server on updated properties for an object
- "entity.removed"
    Sent by JSON Server when an object has been removed
- "entity.list"
    Used to request a list of entities from a JSON Server
- "entity.list.fragment"
    Sent by JSON Server directly for a list fragment if there's a lot of data
- "entity.list.end"
    Sent by JSON Server directly for the end of the list
- "entity.get"
    Used to request a specific entity or singleton from a JSON Server
- "entity.result"
    Sent by JSON Server directly to a "get" request of the result
- Where "entity" in the event names is one of the entity types per the Entities list, e.g. "agent.added"
- Entities should have a unique key, "identifier" property used in the messages above
- "*" may be used as a wildcard in some cases, such as in entity.patch to target all entities of that type
- "entities.list"
    Special wildcard to get all entities, will output the respective
    "entity.list.fragment" / "entity.list.end" for each entity type
- "singleton.init"
    Initialise a singleton with the given properties
- "singleton.patch"
    Tell JSON Server to apply new property settings
- "singleton.patched"
    Sent by JSON Server when properties have been updated on a singleton
- "singleton.get"
    Request JSON Server for the singleton's properties
- "singleton.result"
    Sent by JSON Server directly to a "get" request
- Where "singleton" is one of the singleton types per the Singletons list, e.g. "arena.patch"
- "singletons.list"
    Special wildcard to get all singletons, will output "singleton.result" for each

For example if you have an agent entity it will have these event names:
    agent.add, agent.patch, agent.remove,
    agent.added, agent.patched, agent.removed,
    agent.list, agent.list.fragment, agent.list.end,
    agent.get, agent.result

For example to add an agent:
{
    "event": "agent.add",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "some key": "some value"
}
And the JSON Server may then spit out with a llRegionSay:
{
    "event": "agent.added",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "some key": "some value"
}

Then if we want to add some property to that agent:
{
    "event": "agent.patch",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "fancy": "pants"
}
Which will save it into the server and spit out:
{
    "event": "agent.patched",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "fancy": "pants"
}

When you try to get the get info of that agent:
{
    "event": "agent.get",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca"
}
And at this point the server will send your object:
{
    "event": "agent.result",
    "identifier": "75078730-ebc8-4a80-adb9-1cfd2d95b5ca",
    "some key": "some value",
    "fancy": "pants"
}


*/

list Entities = ["agent", "objective", "territory", "point"];
list Singletons = ["arena"];

default
{
    state_entry()
    {
        llListen(JSON_CHANNEL, "", "", "");
        
        string init = llList2Json(JSON_OBJECT, [
            "type", "init",
            "signature", llSignRSA(llLinksetDataRead("trackingPrivateKey"), (string)llGetKey() + " " + llGetDate(), "sha512")
        ]);
        
        // llSay(JSON_CHANNEL, );
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        
        
        
        
        
    }
}
