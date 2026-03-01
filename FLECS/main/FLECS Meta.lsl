// Metadata management for FLECS, specifically active systems
// Basically the "active system" is the external object that actually handles game logic
// This allows for external objects to fully manage how team assignments work, handling respawn mechanism, etc.

#define FLECS_SYSTEM_CHANNEL -1521008920
#define EVENT_SYSTEM 60 // [string system]
#define CHANGE_SYSTEM 61 // [string system]
#define REQUEST_SYSTEM 62 // []
// Linkset Data:
// "System" = string name

Debug(string log) { llOwnerSay(log); }

string ActiveSystem = "Basic";


default
{
    state_entry()
    {
        llListen(FLECS_SYSTEM_CHANNEL, "", "", "");
        llLinksetDataWrite("System", ActiveSystem);
        llRegionSay(FLECS_SYSTEM_CHANNEL, llChar(EVENT_SYSTEM) + ActiveSystem);
        llMessageLinked(LINK_SET, EVENT_SYSTEM, ActiveSystem, "");
        Debug("FLECS Meta initialized w/ " + ActiveSystem + " system");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer isSameOwner = llGetOwnerKey(identifier) == llGetOwner();
        integer type = llOrd(message, 0);
        
        if(type == CHANGE_SYSTEM && isSameOwner)
        {
            string system = llGetSubString(message, 1, -1);
            if(ActiveSystem == system) return; // No change
            
            ActiveSystem = system;
            llLinksetDataWrite("System", ActiveSystem);
            llRegionSay(FLECS_SYSTEM_CHANNEL, llChar(EVENT_SYSTEM) + ActiveSystem);
            llMessageLinked(LINK_SET, EVENT_SYSTEM, ActiveSystem, "");
            
            Debug("Active system changed to " + ActiveSystem);
        }
        
        else if(type == REQUEST_SYSTEM)
        {
            llRegionSayTo(identifier, FLECS_SYSTEM_CHANNEL, llChar(EVENT_SYSTEM) + ActiveSystem);
        }
    }
}
