#include "Combat2-DevKit/Combat2-Polyfill.lsl"

#define FLECS_SYSTEM_CHANNEL -1
#define FLECS_HUD_CHANNEL -2
#define RESPAWN_SYSTEM "Basic"

list Battlefields = [ // Areas where combat is allowed
    <0, 0, 0>, <256, 256, 1024>
];
list Safezones = []; // Safe areas within the battlefields
list Respawns = [
    "308bf5d3-ee6f-2ffc-9cf3-21b88cb4c549",
    "a2562aa5-53d0-2a0e-f972-d22e1c93d930"
];

list DefenderGroups = [
    "64064c89-25aa-008b-cfe7-0c34e28ae523", 
    "86376bab-a5c9-d551-1866-7f6ac222c96f"
];

integer isActiveSystem;
list Queue;

float lastGroupCheck;
#define GROUP_CHECK_INTERVAL 30.0


AutoAssignTeam(string agent)
{
    integer isDefender = FALSE;
    list attachments = llGetAttachedList(agent);
    integer attachmentIterator = llGetListLength(attachments);
    while(attachmentIterator --> 0)
    {
        key attachment = llList2Key(attachments, attachmentIterator);
        key attachmentGroup = llList2Key(llGetObjectDetails(attachment, [OBJECT_GROUP]), 0);
        integer groupsIterator = llGetListLength(DefenderGroups);
        while(groupsIterator --> 0)
        {
            key defenderGroup = llList2String(DefenderGroups, groupsIterator);
            if(attachmentGroup == defenderGroup)
            {
                isDefender = TRUE;
                attachmentIterator = groupsIterator = 0;
            }
        }
    }
    
    integer team;
    if(isDefender) team = 1; // Ashguard
    else team = 2; // Raiders
    
    integer prevTeam = llGetTeam(agent);
    if(prevTeam != team)
    {
        llSetTeam(agent, team);
        string teamName = (string)llGetTeamDetails(team, [TEAM_NAME]);
        llRegionSayTo(agent, PUBLIC_CHANNEL, "Assigned to team " + teamName);
        llOwnerSay("Assigned agent secondlife:///app/agent/" + agent + "/inspect to team " + teamName);
    }
}



default
{
    state_entry()
    {
        // Treat respawn points as safezones
        integer iterator = llGetListLength(Respawns);
        while(iterator --> 0)
        {
            string respawn = llList2String(Respawns, iterator);
            if(llKey2Name(respawn) == "")
            {
                llOwnerSay("Error: Respawn point with key " + respawn + " is not rezzed in the region.");
                return;
            }
            
            list details = llGetObjectDetails(respawn, [OBJECT_POS]);
            vector pos = llList2Vector(details, 0);
            list bbox = llGetBoundingBox(respawn);
            vector min = llList2Vector(bbox, 0);
            vector max = llList2Vector(bbox, 1);
            Safezones += pos + min;
            Safezones += pos + max;
            
            string desc = (string)llGetObjectDetails(respawn, [OBJECT_DESC]);
            llOwnerSay("Added respawn point at " + (string)pos + " for " + desc);
        }
        
        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
            "type", "check-active-system"
        ]));
        llListen(FLECS_SYSTEM_CHANNEL, "", NULL_KEY, "");
        llSetTimerEvent(0.5);
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        // Was this message intended for us?
        string system = llJsonGetValue(message, ["system"]);
        if(system != JSON_INVALID && system != RESPAWN_SYSTEM) return;
        
        // What type of message is this?
        string type = llJsonGetValue(message, ["type"]);
        if(type == JSON_INVALID) return;
        
        if(type == "active-system")
        {
            system = llJsonGetValue(message, ["name"]);
            llLinksetDataWrite("ActiveSystem", system);
            isActiveSystem = (system == RESPAWN_SYSTEM);
            
            if(isActiveSystem)
            {
                /*integer teamIterator = 3;
                while(teamIterator --> 0)
                {
                    list prevRespawns = llGetTeamRespawns(teamIterator);
                    integer prevIterator = llGetListLength(prevRespawns);
                    while(prevIterator --> 0)
                    {
                        llSetTeamRespawn(llList2Key(prevRespawns, prevIterator), teamIterator);
                    }
                }*/
                
                // Define the team settings
                llLinksetDataWrite("C2_Teams_Config", llList2Json(JSON_ARRAY, [
                    llList2Json(JSON_OBJECT, ["name", "unassigned", "color", <0,0,0>]), // Always leave this as-is, this is a special hardcoded unassigned team 0, per the Combat2.1 spec
                    llList2Json(JSON_OBJECT, ["name", "Ashguard", "color", <0,0.5,1>]),
                    llList2Json(JSON_OBJECT, ["name", "Raiders", "color", <1,0,0>])
                ]));
                
                
                integer iterator = llGetListLength(Respawns);
                while(iterator --> 0)
                {
                    string respawn = llList2String(Respawns, iterator);
                    if(llKey2Name(respawn) == "")
                    {
                        llOwnerSay("Error: Respawn point with key " + respawn + " is not rezzed in the region.");
                        return;
                    }
                    
                    string desc = (string)llGetObjectDetails(respawn, [OBJECT_DESC]);
                    integer team;
                    if(desc == "Defenders") team = 1;
                    else if(desc == "Raiders") team = 2;
                    else
                    {
                        llOwnerSay("Error: Respawn point with key " + respawn + " has invalid description, must be either 'Defenders' or 'Raiders'.");
                        return;
                    }
                    
                    llSetTeamRespawn(respawn, team);
                    llOwnerSay("Set respawn point " + (string)respawn + " for team " + desc);
                }
                
                // Team auto-assignment based on group
                list agents = llJson2List(llLinksetDataRead("FLECS_Agents"));
                integer agentIterator = llGetListLength(agents);
                while(agentIterator --> 0) AutoAssignTeam(llList2String(agents, agentIterator));
            }
        }
        
        else if(type == "attach-hud")
        {
            string agent = llJsonGetValue(message, ["agent"]);
            if(llListFindList(Queue, [agent]) != -1) return; // Already queued
            Queue += agent;
            // llOwnerSay("Queued secondlife:///app/agent/" + string(agent) + "/inspect for HUD attachment");
        }
        
        else if(type == "added-agent")
        {
            // Assign team based on group
            string agent = llJsonGetValue(message, ["agent"]);
            llOwnerSay("Adding agent secondlife:///app/agent/" + string(agent) + "/inspect to the system.");
            AutoAssignTeam(agent);
        }
        
        else if(type == "dropped-agent")
        {
            
        }
    }
    
    timer()
    {
        float time = llGetTime();
        
        if(Queue)
        {
            string agent = llList2String(Queue, 0);
            Queue = llDeleteSubList(Queue, 0, 0);
            
            llRezObjectWithParams("FLECS " + RESPAWN_SYSTEM + " HUD", [
                REZ_FLAGS, REZ_FLAG_TEMP,
                REZ_PARAM, TRUE,
                REZ_PARAM_STRING, llList2Json(JSON_OBJECT , [
                    "agent", agent,
                    "system", RESPAWN_SYSTEM,
                    "battlefields", llList2Json(JSON_ARRAY, Battlefields),
                    "safezones", llList2Json(JSON_ARRAY, Safezones)
                ])
            ]);
        }
        
        
        if(time - lastGroupCheck > GROUP_CHECK_INTERVAL)
        {
            lastGroupCheck = time;
            
            list agents = llJson2List(llLinksetDataRead("FLECS_Agents"));
            integer agentIterator = llGetListLength(agents);
            while(agentIterator --> 0) AutoAssignTeam(llList2String(agents, agentIterator));
        }
    }
}
