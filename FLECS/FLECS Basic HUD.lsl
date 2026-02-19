#include "Combat2-DevKit/Combat2-Polyfill.lsl"

#define FLECS_SYSTEM_CHANNEL -1
#define FLECS_HUD_CHANNEL -2

list Battlefields = []; // Areas where combat is allowed
list Safezones = []; // Safe areas within the battlefields

integer inDamageableArea(vector pos) {
    integer a;
    integer b = llGetListLength(Battlefields);
    for(; a < b; a += 2)
    {
        vector min = llList2Vector(Battlefields, a);
        vector max = llList2Vector(Battlefields, a + 1);
        if(min.x <= pos.x && pos.x <= max.x &&
           min.y <= pos.y && pos.y <= max.y &&
           min.z <= pos.z && pos.z <= max.z)
        {
            integer c;
            integer d = llGetListLength(Safezones);
            for(; c < d; c += 2)
            {
                vector min = llList2Vector(Safezones, c);
                vector max = llList2Vector(Safezones, c + 1);
                if(min.x <= pos.x && pos.x <= max.x &&
                   min.y <= pos.y && pos.y <= max.y &&
                   min.z <= pos.z && pos.z <= max.z)
                {
                    // Safezone within the Battlefield
                    return FALSE;
                }
            }
            
            // Battlefield
            return TRUE;
        }
    }
    
    // Not a battlefield
    return FALSE;
}

string agent;

default
{
    on_rez(integer param)
    {
        if(!param) return;
        
        string data = llGetStartString();
        
        string system = llJsonGetValue(data, ["system"]);
        Battlefields = llJson2List(llJsonGetValue(data, ["battlefields"]));
        Safezones = llJson2List(llJsonGetValue(data, ["safezones"]));
        
        // Typecast lists
        integer iterator = llGetListLength(Battlefields);
        while(iterator --> 0) Battlefields = llListReplaceList(Battlefields, [
            (vector)llList2String(Battlefields, iterator)
        ], iterator, iterator);
        iterator = llGetListLength(Safezones);
        while(iterator --> 0) Safezones = llListReplaceList(Safezones, [
            (vector)llList2String(Safezones, iterator)
        ], iterator, iterator);
        
        agent = llJsonGetValue(data, ["agent"]);
        llRequestExperiencePermissions(agent, "");
        llSetTimerEvent(30); // Self destruct
        llListen(FLECS_HUD_CHANNEL, "", "", "");
        
        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
            "type", "rezzed-hud",
            "system", system,
            "agent", agent,
            "hud", llGetKey()
        ]));
    }
    
    timer()
    {
        if(llGetAgentSize(agent) == ZERO_VECTOR) llDie();
        if(!llGetAttached()) llDie();
    }
    
    attach(key attachee)
    {
        if(attachee)
        {
            llSetTimerEvent(FALSE);
            llTakeControls(CONTROL_DOWN, TRUE, TRUE);
            llRegionSay(FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "attached",
                "agent", attachee
            ]));
            // llOwnerSay("Ready");
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        string type = llJsonGetValue(message, ["type"]);
        if(type == "detach")
        {
            llDetachFromAvatar();
            llDie();
        }
    }
    
    experience_permissions(key agent)
    {
        if(!llGetAttached())
        {
            // llOwnerSay("Got perms, attaching HUD");
            llAttachToAvatarTemp(ATTACH_HUD_CENTER_2);
        }
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        llDetachFromAvatar();
        llDie();
    }
    
    on_damage(integer count)
    {
        if(inDamageableArea(llGetPos())) return;
        
        while(count--) llAdjustDamage(count, 0);
    }
    
    on_death()
    {
        vector pos = llGetPos();
        if(!inDamageableArea(pos)) return;
        
        integer team = llGetTeam(agent);
        string teamName = (string)llGetTeamDetails(team, [TEAM_NAME]);
        list respawns = llGetTeamRespawns(team);
        integer count = llGetListLength(respawns);
        if(count == 0)
        {
            llOwnerSay("Died; No respawn points available for team " + teamName);
            return; // No respawns available, do nothing
        }
        
        string respawn = llList2String(respawns, (integer)llFrand((float)count));
        string respawnName = llKey2Name(respawn);
        if(respawnName == "")
        {
            llOwnerSay("Died; Respawn point for team " + teamName + " is not rezzed in the region");
            return; // Respawn point is not rezzed, do nothing
        }
        
        list details = llGetObjectDetails(respawn, [OBJECT_POS, OBJECT_SCALE, OBJECT_ROT]);
        vector respawnPos = llList2Vector(details, 0);
        vector respawnScale = llList2Vector(details, 1);
        rotation respawnRot = llList2Rot(details, 2);
        vector spawnPoint = respawnPos + <
            (llFrand(1) - 0.5) * (respawnScale.x - 0.4),
            (llFrand(1) - 0.5) * (respawnScale.y - 0.4),
            0
        > * respawnRot;
        vector lookAt = llVecNorm(<1, 0, 0> * respawnRot);
        
        llOwnerSay("Died; Respawning at " + respawnName);
        
        llTeleportAgent(agent, "", spawnPoint, lookAt);
    }
}
