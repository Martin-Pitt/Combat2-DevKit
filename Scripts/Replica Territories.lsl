#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/territories.lsl"

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
        if(llGetOwnerKey(identifier) != llGetOwner()) return;
        string eventName = llJsonGetValue(message, ["event"]);
        
        if(eventName == "territory.update") onTerritoryUpdate(message);
        else if(eventName == "territory.found") onTerritoryFound(message);
        else if(eventName == "territory.removed") onTerritoryRemoved(message);
        else if(eventName == "territory.list.fragment" || eventName == "territory.list.end") onTerritoryList(message);
    }
}
