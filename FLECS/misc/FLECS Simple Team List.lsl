
#define FLECS_TRACKER_CHANNEL -1521008921
#define EVENT_TRACKED 1 // [key agent]
#define EVENT_UNTRACKED 2 // [key agent]
#define EVENT_TRACKED_RESET 3 // []
#define REQUEST_TRACKED 4 // []
list Tracked;

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

#define TIMEOUT 0.2


default
{
    state_entry()
    {
        llLinksetDataDeleteFound("^Team", "");
        llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_TEXT, "", <1,1,1>, 1]);
        
        llListen(FLECS_TRACKER_CHANNEL, "", "", "");
        llListen(FLECS_TEAMS_CHANNEL, "", "", "");
        llRegionSay(FLECS_TRACKER_CHANNEL, llChar(REQUEST_TRACKED));
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(REQUEST_TEAMS_CONFIG));
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(REQUEST_TEAMS_MEMBERS));
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(llGetOwnerKey(identifier) != llGetOwner()) return;
        integer type = llOrd(message, 0);
        
        if(channel == FLECS_TRACKER_CHANNEL)
        {
            if(type == EVENT_TRACKED)
            {
                key agent = llGetSubString(message, 1, -1);
                integer needle = llListFindList(Tracked, [agent]);
                if(needle != -1) return;
                Tracked += agent;
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
            else if(type == EVENT_UNTRACKED)
            {
                key agent = llGetSubString(message, 1, -1);
                integer needle = llListFindList(Tracked, [agent]);
                if(needle == -1) return;
                Tracked = llDeleteSubList(Tracked, needle, needle);
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
            else if(type == EVENT_TRACKED_RESET)
            {
                Tracked = [];
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
        }
        
        else if(channel == FLECS_TEAMS_CHANNEL)
        {
            if(type == EVENT_TEAM_MEMBER)
            {
                integer team = llOrd(message, 1) - 1;
                string agent = llGetSubString(message, 2, -1);
                llLinksetDataWrite("Team:" + agent, (string)team);
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
            
            else if(type == EVENT_TEAM_UNASSIGN)
            {
                string target = llGetSubString(message, 1, -1);
                llLinksetDataDelete("Team:" + target);
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
            
            else if(type == EVENT_TEAMS_RESET)
            {
                llLinksetDataDeleteFound("^Team", "");
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
            
            else if(type == EVENT_TEAMS_CONFIG)
            {
                llLinksetDataWrite("Teams", llGetSubString(message, 1, -1));
                llSetTimerEvent(FALSE);
                llSetTimerEvent(TIMEOUT);
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(FALSE);
        
        list params;
        string config = llLinksetDataRead("Teams");
        
        integer l;
        integer lines;
        list Team0;
        list Team1;
        list Team2;
        
        integer iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            key agent = llList2Key(Tracked, iterator);
            integer team = (integer)llLinksetDataRead("Team:" + (string)agent);
            if(team == 0) Team0 += agent;
            else if(team == 1) Team1 += agent;
            else if(team == 2) Team2 += agent;
        }
        
        string text;
        iterator = llGetListLength(Team0);
        if(iterator)
        {
            lines++;
            string text = (string)iterator + "× " + llJsonGetValue(config, [0, "name"]) + "\n"; ++lines;
            while(iterator --> 0)
            {
                key agent = llList2Key(Team0, iterator);
                text += "\n" + llGetUsername(agent); ++lines;
            }
            
            params += [
                PRIM_LINK_TARGET, 1,
                PRIM_TEXT, text, (vector)llJsonGetValue(config, [0, "color"]), 1
            ];
        }
        
        
        
        iterator = llGetListLength(Team1);
        if(iterator)
        {
            ++lines;
            l = lines;
            text = (string)iterator + "× " + llJsonGetValue(config, [1, "name"]) + "\n"; ++lines;
            while(iterator --> 0)
            {
                key agent = llList2Key(Team1, iterator);
                text += "\n" + llGetUsername(agent); ++lines;
            }
            
            // Stack teams ontop of eachother
            while(l --> 0) text += " \n";
            
            params += [
                PRIM_LINK_TARGET, 2,
                PRIM_TEXT, text, (vector)llJsonGetValue(config, [1, "color"]), 1
            ];
        }
        
        
        
        iterator = llGetListLength(Team2);
        if(iterator)
        {
            ++lines;
            l = lines;
            text = (string)iterator + "× " + llJsonGetValue(config, [2, "name"]) + "\n"; ++lines;
            while(iterator --> 0)
            {
                key agent = llList2Key(Team2, iterator);
                text += "\n" + llGetUsername(agent); ++lines;
            }
            
            // Stack teams ontop of eachother
            while(l --> 0) text += " \n";
            
            params += [
                PRIM_LINK_TARGET, 3,
                PRIM_TEXT, text, (vector)llJsonGetValue(config, [2, "color"]), 1
            ];
        }
        
        llSetLinkPrimitiveParamsFast(0, params);
    }
}
