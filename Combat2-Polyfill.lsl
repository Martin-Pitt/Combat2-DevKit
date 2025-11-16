// This script is intended to help research, test and scope out the draft Combat 2.1 specification

// A polyfill is a script that creates fallback functions in place of standard library system calls, emulating the intended functionality of the system
// See https://community.secondlife.com/forums/topic/516319-combat-21-teams-respawn/ for the specification and the following for the feedback requests:
// https://feedback.secondlife.com/scripting-features/p/combat-21-teams
// https://feedback.secondlife.com/scripting-features/p/combat-21-respawns

// Unfortunately LSL doesn't support fallbacks, so you must remove this script when these functions are native before you can recompile your scripts
// However any existing running scripts will continue to work as normal but would not be interacting with the native implementation
// ⚠ YOU AGREE TO EXPECT THIS SCRIPT TO BE IMMEDIATELY DEPRECATED AND CAUSE SCRIPT COMPILATION ERRORS WHEN THESE FUNCTIONS ARE NATIVELY IMPLEMENTED

// Synced LinksetData keys and what they contain:
// C2_Teams_Config -- Team definitions as an [array of objects] with [name and color properties]; includes special hardcoded 'unassigned' team at 0
// C2_Teams.<team_no> -- Array of agents assigned to that team_no
// C2_Teams:<uuid> -- Agent or object team_no assigment, if not defined assume 0, e.g. special 'unassigned' team
// C2_Respawns.<team_no> -- Array of objects assigned as respawn points for that team_no
// C2_Respawns:<uuid> -- team_no of object assignment as a respawn point
// C2_Respawns_Preferred:<uuid> -- object set as preferred respawn point


#define TEAM_OK 0 // Success
#define TEAM_UNKNOWN -1 // Team number is outside the range of 0 to 8
#define TEAM_NOTACTIVE -2 // Team has not been activated
#define TEAM_NORESPAWN -3 // The object is not a valid respawn target
#define TEAM_MISMATCH -4 // Assigned teams do not match

// Returns the current team assigned of the object or avatar. If this was not previously assigned to a team this function returns team 0 (the default unassigned team)
integer llGetTeam(key target) {
    string assignment = llLinksetDataRead("C2_Teams:" + (string)target);
    if(assignment) return (integer)assignment;
    else return 0;
}

// Alias towards llGetTeam; Would return team number of task detected in sensor sweep, collision, or damage event.
integer llDetectedTeam(integer index) { return llGetTeam(llDetectedKey(index)); }

// Returns the number of teams activated on the region
integer llGetRegionTeamCount() {
    string teamsConfig = llLinksetDataRead("C2_Teams_Config");
    if(teamsConfig == "") teamsConfig = "[{\"name\":\"unassigned\",\"color\":\"<0,0,0>\"}]";
    list teams = llJson2List(teamsConfig);
    return llGetListLength(teams);
}

// Returns a list of the team names that have been defined on this region
list llGetRegionTeamList() {
    string teamsConfig = llLinksetDataRead("C2_Teams_Config");
    if(teamsConfig == "") teamsConfig = "[{\"name\":\"unassigned\",\"color\":\"<0,0,0>\"}]";
    list teams = llJson2List(teamsConfig);
    list names;
    integer iterator = 1; // Skip the special 'unassigned' team
    integer total = llGetListLength(teams);
    for(; iterator < total; ++iterator) names += llJsonGetValue(llList2String(teams, iterator), ["name"]);
    return names;
}

// Returns a list of IDs of agents that have been assigned to a team on this region. Does not include non-agents assigned to a team.
list llGetTeamMemberList(integer team_no) { return llJson2List(llLinksetDataRead("C2_Teams." + (string)team_no)); }

// Returns the number of agents in the region that have been assigned to a team. Does not include non-agents assigned to a team.
integer llGetTeamMemberCount(integer team_no) { return llGetListLength(llGetTeamMemberList(team_no)); }

// Marks an object as a respawn point for the given team. If the object was not assigned to this team it is reassigned. Setting the team_no to -1 will clear the respawn point. If the objects team assignment changes it will unset the respawn point.
integer llSetTeamRespawn(key object_id, integer team_no) {
    if(team_no < 0 || team_no > 8) return TEAM_UNKNOWN;
    if(llLinksetDataRead("C2_Teams." + (string)team_no)); else return TEAM_NOTACTIVE;
    if(llKey2Name(object_id) == "") return TEAM_NORESPAWN;
    
    // Unassign from previous team
    string previousTeam = llLinksetDataRead("C2_Respawns:" + (string)object_id);
    if(previousTeam)
    {
        list previousRespawns = llJson2List(llLinksetDataRead("C2_Respawns." + previousTeam));
        integer index = llListFindList(previousRespawns, [(string)object_id]);
        if(index != -1)
        {
            previousRespawns = llDeleteSubList(previousRespawns, index, index);
            llLinksetDataWrite("C2_Respawns." + previousTeam, llList2Json(JSON_ARRAY, previousRespawns));
        }
    }
    
    // Assign to new team if not already
    list respawns = llJson2List(llLinksetDataRead("C2_Respawns." (string)team_no));
    if(llListFindList(respawns, [(string)object_id]) == -1)
    {
        respawns += object_id;
        llLinksetDataWrite("C2_Respawns." + (string)team_no, llList2Json(JSON_ARRAY, respawns));
        llLinksetDataWrite("C2_Respawns:" + (string)object_id, (string)team_no);
    }
    
    return TEAM_OK;
}

integer llSetAgentPreferredRespawn(key agent_id, key object_id) {
    if(llKey2Name(object_id) == "") return TEAM_NORESPAWN;
    string agentTeam = llLinksetDataRead("C2_Teams:" + (string)agent_id);
    if(agentTeam); else return FALSE; // Not assigned to a team
    string respawnTeam = llLinksetDataRead("C2_Respawns:" + (string)object_id);
    if(respawnTeam); else return TEAM_NORESPAWN;
    if(agentTeam != respawnTeam) return TEAM_MISMATCH;
    
    // Assign preferred respawn point for agent
    llLinksetDataWrite("C2_Respawns_Preferred:" + (string)agent_id, (string)object_id);
    
    return TEAM_OK;
}

// Returns a list of objects assigned as respawn points for a team
list llGetTeamRespawns(integer team_no) { return llJson2List(llLinksetDataRead("C2_Respawns." + (string)team_no)); }

// Returns the number of respawn points for a team
integer llGetTeamRespawnCount(integer team_no) { return llGetListLength(llGetTeamRespawns(team_no)); }

// Returns details about a team. If the team has not been activated the list is empty
#define TEAM_NAME 0 // [string name] -- The name of the team
#define TEAM_COLOR 1 // [vector color] -- An RGB color assigned to the team
#define TEAM_COUNT 2 // [integer agents] -- Number of agents on this region belonging to the team
#define TEAM_RESPAWN 3 // [integer home, integer respawns] -- If this is the team's "home" region and the number of respawn points configured in *this* region
list llGetTeamDetails(integer team_no, list params) {
    string teamsConfig = llLinksetDataRead("C2_Teams_Config");
    if(teamsConfig == "") teamsConfig = "[{\"name\":\"unassigned\",\"color\":\"<0,0,0>\"}]";
    list data;
    integer iterator;
    integer total = llGetListLength(params);
    for(; iterator < total; ++iterator)
    {
        integer param = llList2Integer(params, iterator);
        if(param == TEAM_NAME) data += llJsonGetValue(teamsConfig, [team_no, "name"]);
        else if(param == TEAM_COLOR) data += llJsonGetValue(teamsConfig, [team_no, "color"]);
        else if(param == TEAM_COUNT) data += llGetTeamMemberCount(team_no);
        else if(param == TEAM_RESPAWN) data += [TRUE, llGetTeamRespawnCount(team_no)];
    }
    return data;
}




