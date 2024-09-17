#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/territories.lsl"

/*
    This script replicates territorial data received via the C2R channel into Linkset Data
    Linkset Data keys and their types are:
    string[] territories - List of Territory names
    vector <Territory>_center - Center of the Territory
    string[] <Territory>_neighbours - Connected Territories
    float[] <Territory>_vertices - Polygon as pairs of 2D vectors [x0,y0, x1,y1, ...] in region coordinates
    integer[] <Territory>_lines - Indicates which line between vertices borders a neighbour, the integer is index to <Territory>_neighbours or -1
    string <Territory>_team - Team ownership, e.g. "" (neutral), "Red" or "Blue" for example
*/

default
{
    state_entry()
    {
        initTerritories();
        llListen(C2R_CHANNEL, "", "", "");
        llRegionSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, ["event", "territory.list"]));
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(llGetOwnerKey(identifier) != llGetOwner()) return; // Optional security check - disable on attachments
        string eventName = llJsonGetValue(message, ["event"]);
        
        if(eventName == "territory.update") onTerritoryUpdate(message);
        else if(eventName == "territory.found") onTerritoryFound(message);
        else if(eventName == "territory.removed") onTerritoryRemoved(message);
        else if(eventName == "territory.list.fragment" || eventName == "territory.list.end") onTerritoryList(message);
    }
}
