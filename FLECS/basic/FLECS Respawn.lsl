
#define SYSTEM_COMBAT_CHANNEL -1820510001
#define RESPAWN_AGENT 100 // []; untrusted
#define AGENT_DEATH 101 // []; untrusted

HandleRespawn(key agent)
{
    integer lastDeath = (integer)llLinksetDataRead("LastDeath:" + (string)agent);
    integer frame = (integer)llGetEnv("frame_number");
    if(frame < lastDeath) lastDeath = 0; // Account for sim resets
    if(frame - lastDeath < 4*45) return; // Prevent multiple death messages in quick succession from causing multiple respawns
    llLinksetDataWrite("LastDeath:" + (string)agent, (string)frame);
    
    integer team = (integer)llLinksetDataRead("Team:" + (string)agent);
    string respawn = llLinksetDataRead("Preferred:" + (string)agent);
    integer preferredTeam = (integer)llLinksetDataRead("Respawn:" + respawn);
    
    if(!(respawn != "" && llKey2Name(respawn) != "" && preferredTeam == team))
    {
        list respawns = llJson2List(llLinksetDataRead("Respawns." + (string)team));
        if(llGetListLength(respawns) == 0)
        {
            Debug("No respawns found for team " + (string)team + " when handling respawn for secondlife:///app/agent/" + string(agent) + "/inspect");
            return; // No respawns for team, do nothing
        }
        
        // Pick a random respawn point (could also pick closest)
        integer choice = llFloor(llFrand(llGetListLength(respawns)));
        respawn = llList2Key(respawns, choice);
    }
    
    if(llKey2Name(respawn) == "")
    {
        Debug("Attempted to respawn agent secondlife:///app/agent/" + string(agent) + "/inspect at invalid respawn " + (string)respawn);
        return; // Respawn doesnt exist, do nothing
    }
    
    string respawnName = llKey2Name(respawn);
    list details = llGetObjectDetails(respawn, [OBJECT_POS, OBJECT_SCALE, OBJECT_ROT]);
    vector respawnPos = llList2Vector(details, 0);
    vector respawnScale = llList2Vector(details, 1);
    rotation respawnRot = llList2Rot(details, 2);
    vector spawnPoint = respawnPos + <
        (llFrand(1) - 0.5) * (respawnScale.x - 0.4),
        (llFrand(1) - 0.5) * (respawnScale.y - 0.4),
        0
    > * respawnRot;
    
    details = llGetObjectDetails(agent, [OBJECT_POS]);
    vector agentPos = llList2Vector(details, 0);
    float dist = llVecDist(agentPos, respawnPos);
    float minDist = llVecMag(respawnScale);
    if(dist < minDist)
    {
        vector rel = (agentPos - respawnPos) / respawnRot;
        respawnScale /= 2;
        if(-respawnScale.x < rel.x && rel.x < respawnScale.x
        && -respawnScale.y < rel.y && rel.y < respawnScale.y
        && -respawnScale.z < rel.z && rel.z < respawnScale.z)
        {
            // Debug("Not teleporting secondlife:///app/agent/" + string(agent) + "/inspect because they are already near the respawn point " + respawnName);
            return;
        }
    }
    
    llRegionSayTo(agent, PUBLIC_CHANNEL, "Died; Respawning at " + respawnName);
    // Debug("Respawning secondlife:///app/agent/" + string(agent) + "/inspect " + respawnName + " @ " + llGetEnv("frame_number"));
    llRequestExperiencePermissions(agent, "");
    llTeleportAgent(agent, "", spawnPoint, <128, 128, 0>);
}

Debug(string log) { llOwnerSay(log); }

integer Node;
#define NODES 6


default
{
    state_entry()
    {
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
        llListen(SYSTEM_COMBAT_CHANNEL, "", "", "");
        
        list temp = llParseString2List(llGetScriptName(), [" "], []);
        Node = llList2Integer(temp, -1);
        Debug("FLECS Respawn node " + (string)Node + " initialized");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer tick;
        llLinksetDataWrite("tick", string(tick = 1 + integer(llLinksetDataRead("tick"))));
        if((tick % NODES) != Node) return;
        
        if(channel == SYSTEM_COMBAT_CHANNEL)
        {
            integer type = llOrd(message, 0);
            
            if(type == RESPAWN_AGENT)
            {
                key agent = llGetOwnerKey(identifier);
                // Debug("Received respawn request for secondlife:///app/agent/" + (string)agent + "/inspect @ " + llGetEnv("frame_number"));
                HandleRespawn(agent);
            }
        }
        
        else if(channel == COMBAT_CHANNEL)
        {
            if(llSubStringIndex(message, "\"DEATH\"") == -1) return; // Stop processing if there is no "DEATH" string in the message
            
            list payloads = llJson2List(message);
            integer index = llGetListLength(payloads);
            while(index --> 0)
            {
                string payload = llList2String(payloads, index);
                if(llJsonGetValue(payload, ["event"]) == "DEATH")
                {
                    key agent = llJsonGetValue(payload, ["target"]);
                    integer team = (integer)llLinksetDataRead("Team:" + (string)agent);
                    if(team != 0)
                    {
                        list details = llGetObjectDetails(agent, [OBJECT_POS]);
                        vector agentPos = llList2Vector(details, 0);
                        vector deathPos = (vector)("<" + llGetSubString(llJsonGetValue(payload, ["target_pos"]), 1, -2) + ">");
                        if(llVecDist(agentPos, deathPos) < 16.0)
                        {
                            // Debug("Handling respawn via combat log for secondlife:///app/agent/" + string(agent) + "/inspect @ " + llGetEnv("frame_number"));
                            HandleRespawn(agent);
                        }
                    }
                }
            }
        }
    }
    
    // TODO: Handle denied? Shouldn't be possible since only tracked agents can trigger respawns, but just in case
    // experience_permissions_denied(key agent, integer reason) {
    //     llOwnerSay("Experience permissions denied for secondlife:///app/agent/" + string(agent) + "/inspect with reason " + (string)reason);
    // }
}
