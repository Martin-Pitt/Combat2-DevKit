// Manages respawn point team assignments as well as agent preferred respawn points

#define EVENT_UNTRACKED 2 // [key agent]

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

Debug(string log) { llOwnerSay(log); }



list Respawns;
SetTeamRespawn(key target, integer team)
{
    string previous = llLinksetDataRead("Respawn:" + (string)target);
    if(previous != "" && team == -1)
    {
        integer needle = llListFindList(Respawns, [target]);
        if(needle == -1) return;
        Respawns = llDeleteSubList(Respawns, needle, needle);
        llLinksetDataDelete("Respawn:" + (string)target);
        llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_UNSET) + llChar(1 + team) + (string)target);
        llMessageLinked(LINK_SET, EVENT_RESPAWN_UNSET, (string)team, target);
    }
    else if(team >= 0 && llKey2Name(target) != "")
    {
        integer needle = llListFindList(Respawns, [target]);
        if(needle == -1) Respawns += target;
        llLinksetDataWrite("Respawn:" + (string)target, (string)team);
        llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_SET) + llChar(1 + team) + (string)target);
        llMessageLinked(LINK_SET, EVENT_RESPAWN_SET, (string)team, target);
    }
}

SetAgentPreferredRespawn(key agent, key respawn)
{
    integer agentTeam = (integer)llLinksetDataRead("Team:" + (string)agent);
    integer respawnTeam = (integer)llLinksetDataRead("Respawn:" + (string)respawn);
    if(agentTeam != respawnTeam)
    {
        Debug("secondlife:///app/agent/" + string(agent) + "/inspect attempted to set preferred respawn " + (string)respawn + " which is assigned to team " + (string)respawnTeam + " while agent is on team " + (string)agentTeam);
        return;
    }
    
    llLinksetDataWrite("Respawn_Preferred:" + (string)agent, (string)respawn);
    llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_PREFERRED) + (string)agent + (string)respawn);
    llMessageLinked(LINK_SET, EVENT_RESPAWN_PREFERRED, (string)agent, respawn);
}


default
{
    state_entry()
    {
        llLinksetDataDeleteFound("^Respawn", "");
        llListen(FLECS_RESPAWNS_CHANNEL, "", "", "");
        llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_RESET));
        llMessageLinked(LINK_SET, EVENT_RESPAWN_RESET, "", "");
        Debug("FLECS Respawns initialized");
    }
    
    link_message(integer sender, integer value, string text, key identifier)
    {
        if(value == EVENT_UNTRACKED)
        {
            llLinksetDataDelete("Respawn_Preferred:" + (string)identifier);
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer isSameOwner = llGetOwnerKey(identifier) == llGetOwner();
        integer type = llOrd(message, 0);
        
        if(type == SET_RESPAWN && isSameOwner)
        {
            integer team = llOrd(message, 1) - 1;
            key respawn = llGetSubString(message, 2, -1);
            SetTeamRespawn(respawn, team);
        }
        
        else if(type == UNSET_RESPAWN && isSameOwner)
        {
            key respawn = llGetSubString(message, 1, -1);
            SetTeamRespawn(respawn, -1);
        }
        
        else if(type == REQUEST_RESPAWNS)
        {
            integer iterator = llGetListLength(Respawns);
            while(iterator --> 0)
            {
                key respawn = llList2Key(Respawns, iterator);
                integer team = (integer)llLinksetDataRead("Respawn:" + (string)respawn);
                llRegionSayTo(identifier, FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_SET) + llChar(1 + team) + (string)respawn);
            }
        }
        
        else if(type == PREFER_RESPAWN)
        {
            key agent = llGetOwnerKey(identifier);
            key respawn = llGetSubString(message, 1, -1);
            SetAgentPreferredRespawn(agent, respawn);
        }
        
        else if(type == CLEAR_RESPAWNS && isSameOwner)
        {
            Respawns = [];
            llLinksetDataDeleteFound("^Respawn", "");
            llRegionSay(FLECS_RESPAWNS_CHANNEL, llChar(EVENT_RESPAWN_RESET));
            llMessageLinked(LINK_SET, EVENT_RESPAWN_RESET, "", "");
        }
    }
}

