// Manages team configuration and assignments of agents & objects

#define EVENT_TRACKED 1 // [key agent]
#define EVENT_UNTRACKED 2 // [key agent]
#define EVENT_TRACKED_RESET 3 // []

#define FLECS_TEAMS_CHANNEL -1521008922
#define EVENT_TEAM_MEMBER 20 // [integer team, key agent]
#define EVENT_TEAM_OBJECT 21 // [integer team, string object]
#define ASSIGN_TEAM 22 // [integer team, key agent/object]
#define EVENT_TEAMS_RESET 23 // []
#define EVENT_TEAM_UNASSIGN 24 // [key agent/object]
#define REQUEST_TEAMS_MEMBERS 25 // []
#define REQUEST_TEAMS_OBJECTS 26 // []
#define EVENT_TEAMS_CONFIG 27 // [json teams]
#define UPDATE_TEAMS_CONFIG 28 // [json teams]
#define REQUEST_TEAMS_CONFIG 29 // []
// Linkset Data:
// "Team:<key agent>" = integer team
// "Team;<key object>" = integer team
// "Teams" = json [{ string name, vector color }]


Debug(string log) { llOwnerSay(log); }

GarbageCollectObjects() {
    list nonexistent;
    integer index;
    integer steps = 50;
    integer count = llLinksetDataCountFound("^Team;");
    for(; index < count; index += steps)
    {
        list objects = llLinksetDataFindKeys("^Team;", index, steps);
        integer iterator = llGetListLength(objects);
        while(iterator --> 0)
        {
            string lookup = llList2Key(objects, iterator);
            key object = llGetSubString(lookup, 11, -1);
            if(llKey2Name(object) == "") nonexistent += lookup;
        }
    }
    
    // Cleanup
    integer iterator = llGetListLength(nonexistent);
    while(iterator --> 0)
    {
        string lookup = llList2String(nonexistent, iterator);
        llLinksetDataDelete(lookup);
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAM_UNASSIGN) + llGetSubString(lookup, 11, -1));
    }
}


SetTeam(key target, integer team)
{
    string name = llKey2Name(target);
    if(name == "") { Debug("Attempted to assign team to invalid target " + (string)target); return; }
    
    integer isAgent = llGetAgentSize(target) != ZERO_VECTOR;
    string lookup;
    
    string config = llLinksetDataRead("Teams");
    list teams = llJson2List(config);
    integer count = llGetListLength(teams);
    if(config == JSON_INVALID || config == "" || count == 0) { Debug("Teams configuration is invalid, cannot assign"); return; }
    if(team < 0 || team >= count)
    {
        if(isAgent) Debug("Out of bounds team assignment " + (string)team + " attempted for secondlife:///app/agent/" + string(target) + "/inspect");
        else Debug("Out of bounds team assignment " + (string)team + " attempted for object '" + name + "'");
        return; // Invalid team
    }
    
    integer type;
    if(isAgent) { type = EVENT_TEAM_MEMBER; lookup = "Team:" + (string)target; }
    else { type = EVENT_TEAM_OBJECT; lookup = "Team;" + (string)target; }
    
    string currentTeam = llLinksetDataRead(lookup);
    if(currentTeam == (string)team) // No change
    {
        // llRegionSayTo(identifier, FLECS_TEAMS_CHANNEL, llChar(type) + llChar(1 + team) + (string)target); // Re-affirm assignment to requester
        return;
    }
    llLinksetDataWrite(lookup, (string)team);
    llRegionSay(FLECS_TEAMS_CHANNEL, llChar(type) + llChar(1 + team) + (string)target);
    llMessageLinked(LINK_SET, type, (string)team, target);
    
    string teamName = llJsonGetValue(llList2String(teams, team), ["name"]);
    if(isAgent) Debug("Assigned secondlife:///app/agent/" + string(target) + "/inspect to team " + teamName);
    else Debug("Assigned object '" + name + "' to team " + teamName);
}



default
{
    state_entry()
    {
        llListen(FLECS_TEAMS_CHANNEL, "", NULL_KEY, "");
        
        llLinksetDataDeleteFound("^Team", "");
        llLinksetDataWrite("Teams", llList2Json(JSON_ARRAY, [
            llList2Json(JSON_OBJECT, ["name", "unassigned", "color", <0,0,0>]), // Always leave this as-is, this is a special hardcoded unassigned team 0, per the Combat2.1 spec
            llList2Json(JSON_OBJECT, ["name", "Defenders", "color", <0,0.5,1>]),
            llList2Json(JSON_OBJECT, ["name", "Attackers", "color", <1,0,0>])
        ]));
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAMS_RESET));
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAMS_CONFIG) + llLinksetDataRead("Teams"));
        llMessageLinked(LINK_SET, EVENT_TEAMS_RESET, "", "");
        
        Debug("FLECS Teams initialized");
    }
    
    link_message(integer sender, integer value, string text, key identifier)
    {
        if(value == EVENT_TRACKED)
        {
            llLinksetDataWrite("Team:" + (string)identifier, "0"); // Default to unassigned team
        }
        else if(value == EVENT_UNTRACKED)
        {
            llLinksetDataDelete("Team:" + (string)identifier);
            llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAM_UNASSIGN) + (string)identifier);
        }
        else if(value == EVENT_TRACKED_RESET)
        {
            llLinksetDataDeleteFound("^Team:", "");
            llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAMS_RESET));
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer isSameOwner = llGetOwnerKey(identifier) == llGetOwner();
        integer type = llOrd(message, 0);
        
        if(type == ASSIGN_TEAM)
        {
            integer team = llOrd(message, 1) - 1;
            key target = llGetSubString(message, 2, -1);
            SetTeam(target, team);
        }
        else if(type == REQUEST_TEAMS_MEMBERS)
        {
            list Tracked = llJson2List(llLinksetDataRead("Tracked"));
            integer iterator = llGetListLength(Tracked);
            while(iterator --> 0)
            {
                key agent = llList2Key(Tracked, iterator);
                integer team = (integer)llLinksetDataRead("Team:" + (string)agent);
                llRegionSayTo(identifier, FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAM_MEMBER) + llChar(1 + team) + (string)agent);
            }
        }
        else if(type == REQUEST_TEAMS_OBJECTS)
        {
            list nonexistent;
            integer index;
            integer steps = 50;
            integer count = llLinksetDataCountFound("^Team;");
            for(; index < count; index += steps)
            {
                list objects = llLinksetDataFindKeys("^Team;", index, steps);
                integer iterator = llGetListLength(objects);
                while(iterator --> 0)
                {
                    string lookup = llList2Key(objects, iterator);
                    key object = llGetSubString(lookup, 11, -1);
                    if(llKey2Name(object) == "") nonexistent += lookup;
                    else llRegionSayTo(identifier, FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAM_OBJECT) + llLinksetDataRead(lookup) + (string)object);
                }
            }
            
            // Cleanup
            integer iterator = llGetListLength(nonexistent);
            while(iterator --> 0)
            {
                string lookup = llList2String(nonexistent, iterator);
                llLinksetDataDelete(lookup);
                llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAM_UNASSIGN) + llGetSubString(lookup, 11, -1));
            }
        }
        else if(type == REQUEST_TEAMS_CONFIG)
        {
            llRegionSayTo(identifier, FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAMS_CONFIG) + llLinksetDataRead("Teams"));
        }
        else if(type == UPDATE_TEAMS_CONFIG && isSameOwner)
        {
            string config = llGetSubString(message, 1, -1);
            // TODO: Validation
            llLinksetDataWrite("Teams", config);
            llRegionSay(FLECS_TEAMS_CHANNEL, llChar(EVENT_TEAMS_CONFIG) + config);
            llMessageLinked(LINK_SET, EVENT_TEAMS_CONFIG, config, "");
            
            
            string log = "Teams configuration updated:";
            list teams = llJson2List(config);
            integer index; integer count = llGetListLength(teams);
            for(; index < count; index++)
            {
                string teamName = llJsonGetValue(llList2String(teams, index), ["name"]);
                log += "\n- " + teamName;
            }
            Debug(log);
        }
    }
}
