// Common: https://github.com/Martin-Pitt/LSL
#include "Common/utilities.lsl"
#include "Common/geometric.lsl"

// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#define TRACKING_SERVER
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/tracking.lsl"


list Prechecks = [/* key Agent, integer checks*/];
integer TrackingExperienceScripts;


// Completely customise this function to your needs, or just return a single string if you cover the whole sim
string withinArea(vector pos) {
    string currentRegion = llGetRegionName();
    vector gPos = llGetRegionCorner() + pos; // Global position coordinates -- pretty useful for defining areas across multiple sims
    
    // Within Balmora or Balmora's Outskirts
    if(100 < pos.z && pos.z < 869) return "Balmora";
    
    // Region Hub
    if(
        gPos.x > (161792-64) && gPos.y > (320256-64) && gPos.z > (3008-64) &&
        gPos.x < (161792+64) && gPos.y < (320256+64) && gPos.z < (3008+64)
    ) return "Hub";
    
    // Arena
    if(896 < pos.z && pos.z < 1000)
    {
        if(
            currentRegion == "Vertical Sim" &&
            995 < pos.z && pos.z < 1011 &&
            120 < pos.x && pos.x < 136 &&
            120 < pos.y && pos.y < 136
        ) return "Arena.Hub";
        
        return "Arena";
    }
    
    // Development Platform
    if(1000 < pos.z && pos.z < 1100) return "Dev Platform";
    
    // Else Vertical Sim everywhere above but not in the central cylinder
    if(
        pos.z >= 1088 &&
        llVecDist(<gPos.x, gPos.y, 0>, <161792, 320256, 0>) >= 64
    ) return "Vertical Sim";
    
    return "";
}




default
{
    state_entry()
    {
        llLinksetDataReset();
        llLinksetDataWrite("tracked", "[]");
        llListen(TRACKING_INTERNAL_CHANNEL, "", "", "");
        llListen(TRACKING_CHANNEL, "", "", "");
        llSetTimerEvent(0.25);
        sendMessage(llList2Json(JSON_OBJECT, ["type", "init", "region", llGetRegionName()]));
        externalMessage(llList2Json(JSON_OBJECT, ["type", "reset"]));
        
        TrackingExperienceScripts = 0;
        integer iterator = llGetInventoryNumber(INVENTORY_SCRIPT);
        while(iterator --> 0)
        {
            string script = llGetInventoryName(INVENTORY_SCRIPT, iterator);
            if(llGetSubString(script, 0, 19) == "Tracking Experience") TrackingExperienceScripts++;
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(channel == TRACKING_INTERNAL_CHANNEL)
        {
            if(notSameOwner(identifier)) return;
            
            string type = llJsonGetValue(message, ["type"]);
            
            if(type == "entered") onTrackingAgentEntered(message);
            else if(type == "updated") onTrackingAgentUpdated(message);
            else if(type == "left") onTrackingAgentLeft(message);
            else if(type == "init") onTrackingServerInit(message);
        }
        
        else if(channel == TRACKING_CHANNEL)
        {
            string action = llJsonGetValue(message, ["action"]);
            
            if(action == "get-list") onTrackingGetList(identifier);
            
            // Commands afterwards are owner only
            if(notSameOwner(identifier)) return;
            
            if(action == "message") onTrackingMessage(message);
            else if(action == "assign-team") onTrackingAssignTeam(message);
            else if(action == "request-experience") onTrackingRequestExperience(message);
        }
    }
    
    timer()
    {
        string currentRegion = llGetRegionName();
        
        // Loop through region agents to see if there are new additions
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        integer iterator = llGetListLength(agents);
        while(iterator --> 0)
        {
            key agent = llList2Key(agents, iterator);
            if(agent == NULL_KEY) jump continue;
            
            integer index = llListFindList(Tracked, (list)agent);
            
            string animation = llGetAnimation(agent);
            string legacyName = llKey2Name(agent); // Ghosted avatars have an empty string
            string displayName = llGetDisplayName(agent); // May not always be non-empty string?
            string userName = llGetUsername(agent); // May not always be non-empty string?
            list attachments = llGetAttachedList(agent);
            
            if(animation == ""
            || animation == "Init"
            || legacyName == ""
            || displayName == ""
            || userName == ""
            || llGetListLength(attachments) == 0)
                jump continue;
                // Do not consider agent having entered region yet while logging in or still teleporting
            
            if(index == -1)
            {
                if(TrackingExperienceScripts)
                {
                    integer pre = llListFindList(Prechecks, (list)agent);
                    if(pre == -1)
                    {
                        Prechecks += [agent, 0];
                        llLinksetDataWrite((string)agent + "_experiences", "");
                        llMessageLinked(LINK_THIS, MESSAGE_EXPERIENCE_TEST, "", agent);
                        jump continue; // Add to prechecks first
                    }
                    
                    integer checks = llList2Integer(Prechecks, pre + 1);
                    if(checks < TrackingExperienceScripts)
                        jump continue; // Do not consider until prechecks are complete
                    
                    Prechecks = llDeleteSubList(Prechecks, pre, pre + 1);
                }
                
                // Event: Agent entered region
                Tracked += agent;
                vector agentPos = llList2Vector(llGetObjectDetails(agent, [OBJECT_POS]), 0);
                string area = withinArea(agentPos);
                key group = llList2Key(llGetObjectDetails(llList2Key(attachments, 0), [OBJECT_GROUP]), 0);
                
                llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
                llLinksetDataWrite((string)agent + "_TTL", (string)TRACKING_TTL);
                llLinksetDataWrite((string)agent + "_region", currentRegion);
                llLinksetDataWrite((string)agent + "_area", area);
                llLinksetDataWrite((string)agent + "_displayName", displayName);
                llLinksetDataWrite((string)agent + "_userName", userName);
                llLinksetDataWrite((string)agent + "_group", group);
                llLinksetDataWrite((string)agent + "_huds", "");
                llLinksetDataWrite((string)agent + "_team", "");
                
                sendMessage(llList2Json(JSON_OBJECT, [
                    "type", "entered",
                    "agent", agent,
                    
                    "region", currentRegion,
                    "area", area,
                    "displayName", displayName,
                    "userName", userName,
                    "group", group
                ]));
                
                llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, agent, "");
            }
            
            else
            {
                string region = llLinksetDataRead((string)agent + "_region");
                // hud = (key)llLinksetDataRead((string)agent + "_hud"); TODO: multi-huds
                integer changedRegion = region != currentRegion;
                
                // The agent has crossed sim, but if we had a HUD, check if it's present yet
                // before we consider the agent as having crossed
                /*if(changedRegion && hud != NULL_KEY) TODO: multi-huds
                {
                    integer hasHUD = llList2Integer(llGetObjectDetails(hud, [OBJECT_TEMP_ATTACHED]), 0);
                    if(!hasHUD) changedRegion = FALSE;
                }*/
                
                if(changedRegion)
                {
                    // Event: Agent changed region
                    llLinksetDataWrite((string)agent + "_region", currentRegion);
                    
                    sendMessage(llList2Json(JSON_OBJECT, [
                        "type", "updated",
                        "agent", agent,
                        
                        "region", currentRegion
                    ]));
                    
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, agent, "");
                }
            }
            
            @continue;
        }
        
        // Loop through tracked to see if agents have left or HUDs are gone
        iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            string agent = llList2Key(Tracked, iterator);
            integer TTL = (integer)llLinksetDataRead(agent + "_TTL");
            string region = llLinksetDataRead(agent + "_region");
            if(region != currentRegion) jump continue2;
            
            string area = llLinksetDataRead(agent + "_area");
            key group = (key)llLinksetDataRead(agent + "_group");
            string experiences = llLinksetDataRead(agent + "_experiences");
            string huds = llLinksetDataRead(agent + "_huds");
            
            list attachments = llGetAttachedList(agent);
            
            // The agent could be logging out, teleporting away, crossing sims or be a ghosted avatar
            if(llGetAgentSize(agent) == ZERO_VECTOR
            || llGetAnimation(agent) == ""
            || llKey2Name(agent) == ""
            || llGetListLength(attachments) == 0)
            {
                // Let's check if they didn't simply cross regions by waiting an update event message
                if(TTL > 0)
                {
                    llLinksetDataWrite((string)agent + "_TTL", (string)(--TTL));
                }
                
                // Ran out of time, so lets consider them having left completely 
                else if(TTL <= 0)
                {
                    // Event: Agent left region
                    Tracked = llDeleteSubList(Tracked, iterator, iterator);
                    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
                    llLinksetDataDelete(agent + "_TTL");
                    llLinksetDataDelete(agent + "_region");
                    llLinksetDataDelete(agent + "_area");
                    llLinksetDataDelete(agent + "_displayName");
                    llLinksetDataDelete(agent + "_userName");
                    llLinksetDataDelete(agent + "_group");
                    llLinksetDataDelete(agent + "_experiences");
                    llLinksetDataDelete(agent + "_huds");
                    llLinksetDataDelete(agent + "_team");
                    
                    sendMessage(llList2Json(JSON_OBJECT, [
                        "type", "left",
                        "agent", agent
                    ]));
                    
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_LEFT, agent, "");
                }
            }
            
            // Tracking in region
            else
            {
                // We'll need to check changes to these:
                // - Area
                // - Group
                // - HUD
                
                vector agentPos = llList2Vector(llGetObjectDetails(agent, [OBJECT_POS]), 0);
                key currentGroup = llList2Key(llGetObjectDetails(llList2Key(attachments, -1), [OBJECT_GROUP]), 0);
                
                integer isUpdated = FALSE;
                string updated = llList2Json(JSON_OBJECT, [
                    "type", "updated",
                    "agent", agent
                ]);
                
                string currentArea = withinArea(agentPos);
                if(currentArea != area)
                {
                    llLinksetDataWrite((string)agent + "_area", currentArea);
                    updated = llJsonSetValue(updated, ["area"], currentArea);
                    isUpdated = TRUE;
                }
                
                if(currentGroup != group)
                {
                    llLinksetDataWrite((string)agent + "_group", currentGroup);
                    updated = llJsonSetValue(updated, ["group"], currentGroup);
                    isUpdated = TRUE;
                }
                
                /*if(hud != NULL_KEY) TODO: multi-huds
                {
                    integer hasHUD = llList2Integer(llGetObjectDetails(hud, [OBJECT_TEMP_ATTACHED]), 0);
                    if(!hasHUD)
                    {
                        llLinksetDataWrite((string)agent + "_hud", NULL_KEY);
                        updated = llJsonSetValue(updated, ["hud"], "");
                        isUpdated = TRUE;
                    }
                }*/
                
                
                if(isUpdated)
                {
                    sendMessage(updated);
                    
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, agent, "");
                }
            }
            
            @continue2;
        }
        
        // Debug
        llSetText(
            (string)llGetListLength(Tracked) + "\n" +
            (string)llGetFreeMemory() + "\n" +
            (string)llLinksetDataAvailable(),
            <1,1,1>, 1
        );
    }
    
    link_message(integer sender, integer value, string text, key identifier)
    {
        if(value == MESSAGE_EXPERIENCE_ACCEPTED) onTrackingLinkExperienceAccepted(text);
        else if(value == MESSAGE_EXPERIENCE_DENIED) onTrackingLinkExperienceDenied(text);
        else if(value == MESSAGE_EXPERIENCE_ADDED) onTrackingLinkExperienceAdded(identifier);
        else if(value == MESSAGE_EXPERIENCE_REMOVED) onTrackingLinkExperienceRemoved(identifier);
        else if(value == MESSAGE_EXPERIENCE_TESTED) onTrackingLinkExperienceTested(identifier);
    }
    
    changed(integer change)
    {
        if(change & (CHANGED_REGION_START | CHANGED_REGION))
        {
            llSleep(0.5 + llFrand(1.0));
            llResetScript();
        }
    }
}

