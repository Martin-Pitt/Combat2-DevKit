// FLECS System Script
// A system is an external object that interfaces with the FLECS platform object.
// FLECS itself doesnt enforce or implement the logic, rather just providing a central source of truth.
// Systems on the other hand are the modules that provide the actual game logic:
// - how teams are managed,
// - how respawns work, etc.
// 
// The Basic system here provides the fundamentals for a typical SLMC game:
// - two teams
// - fixed respawns
// - team auto-assignment based on attachment group
// It also serves a template for how to implement a system, and how to interface with the
// FLECS platform via the listen message protocol
// 
// Listen Message Protocol:
// - FLECS_*_CHANNEL is used for the listen channel
// - EVENT_* are events sent from the source of truth to notify something happened, actual changes committed etc
// - VERB_* are commands sent to the source of truth to request something to happen
// - Comments are the arguments for the event/verb, sent as a string after the type character
// - SYSTEM_*_CHANNEL are unique to this system object
// - Messages are sent on the relevant channel as: llChar(EVENT_* / VERB_*) + arguments



#define FLECS_SYSTEM_CHANNEL -1521008920
#define EVENT_SYSTEM 60 // [string system]
#define CHANGE_SYSTEM 61 // [string system]
#define REQUEST_SYSTEM 62 // []
// Linkset Data:
// "System" = string name
// "ActiveSystem" = boolean
#define SYSTEM "Basic"
integer isActiveSystem = FALSE;



#define FLECS_TRACKER_CHANNEL -1521008921
#define EVENT_TRACKED 1 // [key agent]
#define EVENT_UNTRACKED 2 // [key agent]
#define EVENT_TRACKED_RESET 3 // []
#define REQUEST_TRACKED 4 // []
// Linkset Data:
// "Tracked" = json [key agent]
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
#define GROUP_ASHGUARD "64064c89-25aa-008b-cfe7-0c34e28ae523"
#define GROUP_MILITIA "86376bab-a5c9-d551-1866-7f6ac222c96f"
#define GROUP_LAND "127ed99a-37c2-c620-4908-85da85180ea9"
#define TEAM_RAIDERS 2
#define TEAM_ASHGUARD 1
AutoAssignTeam(key agent)
{
    integer team = TEAM_RAIDERS;
    list attachments = llGetAttachedList(agent);
    // integer attachmentIterator = llGetListLength(attachments);
    // while(attachmentIterator --> 0)
    if(attachments)
    {
        key attachment = llList2Key(attachments, 0); // attachmentIterator);
        key attachmentGroup = llList2Key(llGetObjectDetails(attachment, [OBJECT_GROUP]), 0);
        if(attachmentGroup == GROUP_ASHGUARD
        || attachmentGroup == GROUP_MILITIA
        || attachmentGroup == GROUP_LAND)
        {
            team = TEAM_ASHGUARD;
            // attachmentIterator = 0;
        }
    }
    
    integer prevTeam = (integer)llLinksetDataRead("Team:" + (string)agent);
    if(prevTeam != team)
    {
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(ASSIGN_TEAM) + llChar(team + 1) + (string)agent);
        string teamName = llJsonGetValue(llLinksetDataRead("Teams"), [team, "name"]);
        if(teamName == JSON_INVALID) teamName = (string)team;
        else teamName = (string)team + ": " + teamName;
        llRegionSayTo(agent, PUBLIC_CHANNEL, "Assigned to team " + teamName);
        //Debug("Auto-assigning agent secondlife:///app/agent/" + agent + "/inspect to team " + teamName);
    }
}



#define FLECS_RESPAWNS_CHANNEL -1521008923
#define EVENT_RESPAWN_SET 40 // [integer team, key object]
#define EVENT_RESPAWN_UNSET 41 // [integer team, key object]
#define EVENT_RESPAWN_RESET 42 // []
#define SET_RESPAWN 43 // [integer team, key object]
#define UNSET_RESPAWN 44 // [key object]
#define REQUEST_RESPAWNS 45 // []
#define CLEAR_RESPAWNS 46 // []
#define EVENT_RESPAWN_PREFERRED 47 // [key agent, key respawn]
#define PREFER_RESPAWN 48 // [key agent, key respawn]
// Linkset Data:
// "Respawn:<key respawn>" = integer team
// "Respawns.<integer team>" = json [key respawn]
// "LastDeath:<key agent>" = integer frame
#define OBJECT_RESPAWN_CASTLE "a2562aa5-53d0-2a0e-f972-d22e1c93d930"
#define OBJECT_RESPAWN_MARKET "308bf5d3-ee6f-2ffc-9cf3-21b88cb4c549"



#define SYSTEM_HUD_CHANNEL -1820510000
#define EVENT_HUD_REZZED 80 // [key agent]
#define EVENT_HUD_ATTACHED 81 // []; untrusted
#define EVENT_HUD_DETACHED 84 // []; untrusted
#define DETACH_HUD 82 // []
#define PREP_RESPAWN 83 // [key respawn]
// Linkset Data:
// "HUD:<key agent>" = key hud
list HUDs;
TrackHUD(key agent, key hud)
{
    llLinksetDataWrite("HUD:" + (string)agent, (string)hud);
    if(llListFindList(HUDs, [hud]) == -1)
    {
        HUDs += hud;
    }
}
UntrackHUD(key agent)
{
    key hud = llLinksetDataRead("HUD:" + (string)agent);
    llLinksetDataDelete("HUD:" + (string)agent);
    if(hud == "" || hud == NULL_KEY) return;
    llRegionSayTo(hud, SYSTEM_HUD_CHANNEL, llChar(DETACH_HUD));
    integer needle = llListFindList(HUDs, [hud]);
    if(needle == -1) return;
    HUDs = llDeleteSubList(HUDs, needle, needle);
}
CheckHUD(key agent)
{
    key hud = llLinksetDataRead("HUD:" + (string)agent);
    if(hud == "") RezHUD(agent); // No HUD, rez new one
    else if(hud == "rezzing") return; // Rez in progress
    else if(hud == "no-slots") { if(hasFreeAttachmentSlot(agent)) RezHUD(agent); }
    else if(llKey2Name(hud) == "") RezHUD(agent); // It is gone, re-rez
}
RezHUD(key agent)
{
    llRegionSayTo(agent, SYSTEM_HUD_CHANNEL, llChar(DETACH_HUD));
    
    if(!hasFreeAttachmentSlot(agent))
    {
        llRegionSayTo(agent, PUBLIC_CHANNEL, "You have no free attachment points, please unequip something and try again otherwise you cannot use the combat system in this region.");
        llLinksetDataWrite("HUD:" + (string)agent, "no-slots");
        // Debug("Cannot rez HUD for secondlife:///app/agent/" + string(agent) + "/inspect because they have no free attachment points");
        return;
    }
    
    llRezObjectWithParams("FLECS HUD", [
        REZ_FLAGS, REZ_FLAG_TEMP,
        REZ_PARAM, TRUE,
        REZ_PARAM_STRING, llList2Json(JSON_OBJECT , [
            "agent", agent,
            "battlefields", llList2Json(JSON_ARRAY, [<0, 0, 0>, <256, 256, 1024>]), // Areas where combat is allowed [min1, max1, min2, max2, etc]
            "safezones", llList2Json(JSON_ARRAY, [OBJECT_RESPAWN_CASTLE, OBJECT_RESPAWN_MARKET])
        ])
    ]);
    llLinksetDataWrite("HUD:" + (string)agent, "rezzing");
    // TODO: Rez timeout? Might be really long rez queue though
}
integer hasFreeAttachmentSlot(key agent)
{
    return llList2Integer(llGetObjectDetails(agent, [OBJECT_ATTACHED_SLOTS_AVAILABLE]), 0) > 0;
}
PrepareRespawn(key agent)
{
    // Pick respawn point
    key respawn;
    integer team = (integer)llLinksetDataRead("Team:" + (string)agent);
    // string preferred = llLinksetDataRead("Preferred:" + (string)agent);
    // integer preferredTeam = (integer)llLinksetDataRead("Respawn:" + preferred);
    // if(preferred != "" && llKey2Name(preferred) != "" && preferredTeam == team) respawn = preferred;
    // else
    // {
        list respawns = llJson2List(llLinksetDataRead("Respawns." + (string)team));
        if(llGetListLength(respawns) == 0) return; // No respawns for team
        
        // Pick a random respawn point (could also pick closest)
        integer choice = llFloor(llFrand(llGetListLength(respawns)));
        respawn = llList2Key(respawns, choice);
    // }
    if(llKey2Name(respawn) == "") return; // Respawn doesnt exist

    // Debug("Sending prep respawn for " + llKey2Name(respawn) + " to " + llKey2Name(agent));
    key hud = llLinksetDataRead("HUD:" + (string)agent);
    llRegionSayTo(hud, SYSTEM_HUD_CHANNEL, llChar(PREP_RESPAWN) + (string)respawn);
}



#define SYSTEM_COMBAT_CHANNEL -1820510001
#define RESPAWN_AGENT 100 // []; untrusted
#define AGENT_DEATH 101 // []; untrusted



#define TIMER 0.3
#define CHECK_INTERVAL 1.0
float lastCheck;
integer check;


Debug(string log) { llOwnerSay(log); }


default
{
    state_entry()
    {
        llLinksetDataDelete("System");
        llLinksetDataDelete("ActiveSystem");
        llLinksetDataDelete("Tracked");
        llLinksetDataDeleteFound("^Team", "");
        llLinksetDataDeleteFound("^Respawn", ""); // ^(Respawn|Preferred)
        llLinksetDataDeleteFound("^HUD", "");
        llLinksetDataDeleteFound("^LastDeath", "");
        
        llListen(FLECS_TRACKER_CHANNEL, "", "", "");
        llListen(FLECS_TEAMS_CHANNEL, "", "", "");
        llListen(FLECS_RESPAWNS_CHANNEL, "", "", "");
        llListen(FLECS_SYSTEM_CHANNEL, "", "", "");
        llListen(SYSTEM_HUD_CHANNEL, "", "", "");
        llListen(SYSTEM_COMBAT_CHANNEL, "", "", "");
        
        llRegionSay(FLECS_SYSTEM_CHANNEL, llChar(REQUEST_SYSTEM)); // Check active system
        llRegionSay(SYSTEM_HUD_CHANNEL, llChar(DETACH_HUD)); // Just in case, drop current HUDs
        llRegionSay(FLECS_TRACKER_CHANNEL, llChar(REQUEST_TRACKED)); // Request currently tracked agents
        llRegionSay(FLECS_TEAMS_CHANNEL, llChar(REQUEST_TEAMS_MEMBERS)); // Request current team assignments
        llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(REQUEST_RESPAWNS)); // Request current respawn points
        
        Debug("FLECS Comms initialized; " + (string)(llGetFreeMemory()/1024) + "KB free");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer isSameOwner = llGetOwnerKey(identifier) == llGetOwner();
        integer type = llOrd(message, 0);
        
        if(channel == SYSTEM_COMBAT_CHANNEL)
        {
            if(type == RESPAWN_AGENT)
            {
                key agent = llGetOwnerKey(identifier);
                // Handled by Respawn script directly
            }
            
            else if(type == AGENT_DEATH)
            {
                key agent = llGetOwnerKey(identifier);
                
            }
        }
        
        else if(channel == SYSTEM_HUD_CHANNEL)
        {
            if(type == EVENT_HUD_REZZED && isSameOwner)
            {
                key agent = llGetSubString(message, 1, -1);
            }
            
            else if(type == EVENT_HUD_ATTACHED)
            {
                key agent = llGetOwnerKey(identifier);
                TrackHUD(agent, identifier);
                
                // Side Effects
                PrepareRespawn(agent);
            }
            
            else if(type == EVENT_HUD_DETACHED)
            {
                key agent = llGetOwnerKey(identifier);
                UntrackHUD(agent);
            }
        }
        
        else if(channel == FLECS_TRACKER_CHANNEL && isSameOwner)
        {
            if(type == EVENT_TRACKED)
            {
                key agent = llGetSubString(message, 1, -1);
                integer needle = llListFindList(Tracked, [agent]);
                if(needle != -1) return;
                Tracked += agent;
                llLinksetDataWrite("Tracked", llList2Json(JSON_ARRAY, Tracked));
                llMessageLinked(LINK_SET, type, "", agent);
                
                // Side Effects
                llRegionSayTo(agent, SYSTEM_HUD_CHANNEL, llChar(DETACH_HUD));
                llLinksetDataWrite("Team:" + (string)identifier, "0"); // Default to unassigned team
                AutoAssignTeam(agent);
                CheckHUD(agent);
            }
            
            else if(type == EVENT_UNTRACKED)
            {
                key agent = llGetSubString(message, 1, -1);
                integer needle = llListFindList(Tracked, [agent]);
                if(needle == -1) return;
                Tracked = llDeleteSubList(Tracked, needle, needle);
                llLinksetDataWrite("Tracked", llList2Json(JSON_ARRAY, Tracked));
                llLinksetDataDeleteFound("^(Team:|HUD|LastDeath):" + (string)agent, "");
                llMessageLinked(LINK_SET, type, "", agent);
                
                // Side Effects
                UntrackHUD(agent);
            }
            
            else if(type == EVENT_TRACKED_RESET)
            {
                Tracked = [];
                llLinksetDataDelete("Tracked");
                llLinksetDataDeleteFound("^(Team:|HUD|LastDeath)", "");
                llMessageLinked(LINK_SET, type, "", "");
            }
        }
        
        else if(channel == FLECS_TEAMS_CHANNEL && isSameOwner)
        {
            if(type == EVENT_TEAM_MEMBER)
            {
                integer team = llOrd(message, 1) - 1;
                key agent = llGetSubString(message, 2, -1);
                llLinksetDataWrite("Team:" + (string)agent, (string)team);
                
                // Side Effects
                if(llLinksetDataRead("HUD:" + (string)agent)) PrepareRespawn(agent);
            }
            
            // else if(type == EVENT_TEAM_OBJECT)
            // {
            //     integer team = llOrd(message, 1) - 1;
            //     key object = llGetSubString(message, 2, -1);
            //     llLinksetDataWrite("Team;" + (string)object, (string)team);
            // }
            
            else if(type == EVENT_TEAMS_RESET)
            {
                llLinksetDataDeleteFound("^Team", "");
            }
            
            else if(type == EVENT_TEAM_UNASSIGN)
            {
                key target = llGetSubString(message, 1, -1);
                llLinksetDataDelete("Team:" + (string)target);
            }
            
            else if(type == EVENT_TEAMS_CONFIG)
            {
                string config = llGetSubString(message, 1, -1);
                llLinksetDataWrite("Teams", config);
            }
        }
        
        else if(channel == FLECS_RESPAWNS_CHANNEL && isSameOwner)
        {
            if(type == EVENT_RESPAWN_SET)
            {
                integer team = llOrd(message, 1) - 1;
                key respawn = llGetSubString(message, 2, -1);
                string previous = llLinksetDataRead("Respawn:" + (string)respawn);
                if(previous)
                {
                    if(team == (integer)previous) return; // No change
                    list respawns = llJson2List(llLinksetDataRead("Respawns." + previous));
                    integer index = llListFindList(respawns, [respawn]);
                    if(index != -1) {
                        respawns = llDeleteSubList(respawns, index, index);
                        llLinksetDataWrite("Respawns." + previous, llList2Json(JSON_ARRAY, respawns));
                    }
                }
                list respawns = llJson2List(llLinksetDataRead("Respawns." + (string)team));
                llLinksetDataWrite("Respawns." + (string)team, llList2Json(JSON_ARRAY, respawns + respawn));
                llLinksetDataWrite("Respawn:" + (string)respawn, (string)team);
                
                // Side Effects
                integer iterator = llGetListLength(Tracked);
                while(iterator --> 0)
                {
                    key agent = llList2Key(Tracked, iterator);
                    if(llLinksetDataRead("HUD:" + (string)agent)) PrepareRespawn(agent);
                }
            }
            
            else if(type == EVENT_RESPAWN_UNSET)
            {
                integer team = llOrd(message, 1) - 1;
                key respawn = llGetSubString(message, 2, -1);
                string previous = llLinksetDataRead("Respawn:" + (string)respawn);
                llLinksetDataDelete("Respawn:" + (string)respawn);
                
                if(previous)
                {
                    list respawns = llJson2List(llLinksetDataRead("Respawns." + previous));
                    integer index = llListFindList(respawns, [respawn]);
                    if(index != -1) {
                        respawns = llDeleteSubList(respawns, index, index);
                        llLinksetDataWrite("Respawns." + previous, llList2Json(JSON_ARRAY, respawns));
                    }
                }
                
                // Side Effects
                integer iterator = llGetListLength(Tracked);
                while(iterator --> 0)
                {
                    key agent = llList2Key(Tracked, iterator);
                    if(llLinksetDataRead("HUD:" + (string)agent)) PrepareRespawn(agent);
                }
            }
            
            else if(type == EVENT_RESPAWN_RESET)
            {
                llLinksetDataDeleteFound("^Respawn", "");
                
                // Side Effects
                llRegionSay(SYSTEM_HUD_CHANNEL, llChar(PREP_RESPAWN) + (string)"");
            }
            
            else if(type == EVENT_RESPAWN_PREFERRED)
            {
                key agent = llGetSubString(message, 1, 1 + 35);
                key respawn = llGetSubString(message, 37, 37 + 35);
                // TODO: Implement preferred respawn behaviour, not used in Basic system
            }
        }
        
        else if(channel == FLECS_SYSTEM_CHANNEL && isSameOwner)
        {
            if(type == EVENT_SYSTEM)
            {
                string newSystem = llGetSubString(message, 1, -1);
                string prevSystem = llLinksetDataRead("System");
                if(newSystem == prevSystem) return; // No change
                
                isActiveSystem = newSystem == SYSTEM;
                if(isActiveSystem) llLinksetDataWrite("ActiveSystem", SYSTEM);
                else llLinksetDataDelete("ActiveSystem");
                
                // Side Effects
                if(isActiveSystem)
                {
                    // Boostrap
                    llRegionSay(FLECS_TEAMS_CHANNEL, llChar(UPDATE_TEAMS_CONFIG) + llList2Json(JSON_ARRAY, [
                        llList2Json(JSON_OBJECT, ["name", "unassigned", "color", <0,0,0>]), // Always leave this as-is, this is a special hardcoded unassigned team 0, per the Combat2.1 spec
                        llList2Json(JSON_OBJECT, ["name", "Ashguard", "color", <0,0.5,1>]),
                        llList2Json(JSON_OBJECT, ["name", "Raiders", "color", <1,0,0>])
                    ]));
                    
                    llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(CLEAR_RESPAWNS));
                    llSleep(0.5);
                    llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(SET_RESPAWN) + llChar(TEAM_ASHGUARD + 1) + OBJECT_RESPAWN_CASTLE);
                    llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(SET_RESPAWN) + llChar(TEAM_RAIDERS + 1) + OBJECT_RESPAWN_MARKET);
                    
                    llSetTimerEvent(TIMER);
                    
                    Debug(SYSTEM + " system active");
                }
                
                else
                {
                    // Strapdown
                    llSetTimerEvent(FALSE);
                    llRegionSay(SYSTEM_HUD_CHANNEL, llChar(DETACH_HUD));
                }
            }
        }
    }
    
    timer()
    {
        float time = llGetTime();
        
        if(time - lastCheck > CHECK_INTERVAL)
        {
            lastCheck = time;
            
            if(Tracked)
            {
                integer total = llGetListLength(Tracked);
                key agent = llList2String(Tracked, (check++) % total);
                AutoAssignTeam(agent);
                CheckHUD(agent);
            }
        }
    }
}