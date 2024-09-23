// Common: https://github.com/Martin-Pitt/LSL
#include "Common/utilities.lsl"
#include "Common/geometric.lsl"

// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#define TRACKING_SERVER
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/tracking.lsl"

// For additional custom per-agent data, such as experiences, areas, hud attachment tracking, etc
// we provide an additional startup pre-check before an agent is considered having entered the sim
// so we can have a full data packet in one go before sending it off into the tracking channels
list Prechecks = [/* key Agent, integer checks*/];
integer TrackingDataScripts;


default
{
    state_entry()
    {
        llSetObjectName("Tracking Server (" + llGetRegionName() + ")");
        
        llLinksetDataDeleteFound("^[a-f0-9\\-]{36}_", "");
        llLinksetDataWrite("tracked", "[]");
        llListen(TRACKING_CHANNEL, "", "", "");
        llListen(TRACKING_INTERNAL_CHANNEL, "", "", "");
        llListen(TRACKING_BORDER_CHANNEL, "", "", "");
        llSetTimerEvent(0.25);
        string init = llList2Json(JSON_OBJECT, [
            "type", "init",
            "region", llGetRegionName(),
            "signature", generateHandshake()
        ]);
        string reset = llList2Json(JSON_OBJECT, ["type", "reset"]);
        internalMessage(init);
        borderMessage(init);
        externalMessage(reset);
        
        TrackingDataScripts = 0;
        integer iterator = llGetInventoryNumber(INVENTORY_SCRIPT);
        while(iterator --> 0)
        {
            string script = llGetInventoryName(INVENTORY_SCRIPT, iterator);
            if(llGetSubString(script, 0, 14) == "Tracking Data: ") TrackingDataScripts++;
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(channel == TRACKING_INTERNAL_CHANNEL || channel == TRACKING_BORDER_CHANNEL)
        {
            string type = llJsonGetValue(message, ["type"]);
            
            // Check for other tracking servers that had been initialised and if so verify them
            if(type == "init") { onTrackingServerInit(identifier, message); return; }
            else if(type == "reinit") { onTrackingServerVerify(identifier, llJsonGetValue(message, ["signature"])); return; }
            else if(!(llGetOwnerKey(identifier) == llGetOwner() || llListFindList(VerifiedIdentifiers, [identifier]) != -1)) return;
            
            // Agent events
            if(type == "entered") onTrackingAgentEntered(message);
            else if(type == "updated") onTrackingAgentUpdated(message);
            else if(type == "left") onTrackingAgentLeft(message);
            
            // Proxy all events onto the public channel
            externalMessage(message);
        }
        
        else if(channel == TRACKING_CHANNEL)
        {
            string action = llJsonGetValue(message, ["action"]);
            
            // Get a full list of all the tracking data
            if(action == "get-list")
            {
                list bucket;
                integer keys = llGetListLength(AgentDataKeys);
                integer iterator = llGetListLength(Tracked);
                integer fill;
                while(iterator --> 0)
                {
                    string agent = llList2Key(Tracked, iterator);
                    list data = [
                        "agent", agent
                    ];
                    integer keyIterator = keys;
                    while(keyIterator --> 0)
                    {
                        string k = llList2String(AgentDataKeys, keyIterator);
                        string v = llLinksetDataRead(agent + "_" + k);
                        data += [k, v];
                    }
                    string payload = llList2Json(JSON_OBJECT, data);
                    integer size = llStringLength(payload);
                    
                    if(fill + size + 64 >= 1024)
                    {
                        llRegionSayTo(identifier, TRACKING_CHANNEL, llList2Json(JSON_OBJECT, [
                            "type", "echo-fragment",
                            "list", llList2Json(JSON_ARRAY, bucket)
                        ]));
                        bucket = [];
                        fill = 0;
                    }
                    
                    bucket += payload;
                    fill += size;
                }
                
                llRegionSayTo(identifier, TRACKING_CHANNEL, llList2Json(JSON_OBJECT, [
                    "type", "echo-end",
                    "list", llList2Json(JSON_ARRAY, bucket)
                ]));
            }
            
            // Get tracking data of specific agent
            else if(action == "get")
            {
                string agent = llJsonGetValue(message, ["agent"]);
                
                list data = [
                    "type", "echo",
                    "agent", agent
                ];
                integer keyIterator = llGetListLength(AgentDataKeys);
                while(keyIterator --> 0)
                {
                    string k = llList2String(AgentDataKeys, keyIterator);
                    string v = llLinksetDataRead(agent + "_" + k);
                    data += [k, v];
                }
                
                llRegionSayTo(identifier, TRACKING_CHANNEL, llList2Json(JSON_OBJECT, data));
            }
            
            // Commands afterwards are owner only / private
            else if(llGetOwnerKey(identifier) != llGetOwner()) return;
            
            // Allow you to update any agent data
            else if(action == "delta")
            {
                // Import data
                string agent = llJsonGetValue(message, ["agent"]);
                list data = llJson2List(message);
                integer index; integer total; integer patched;
                for(index = 0, total = llGetListLength(data); index < total; index += 2)
                {
                    string name = llList2String(data, index);
                    string newValue = llList2String(data, index + 1);
                    if(name != "type" && name != "agent")
                    {
                        if(llListFindList(AgentDataKeys, [name]) == -1) AgentDataKeys += name;
                        string oldValue = llLinksetDataRead(agent + "_" + name);
                        if(newValue != oldValue)
                        {
                            llLinksetDataWrite(agent + "_" + name, newValue);
                            patched++;
                        }
                        else llJsonSetValue(message, [name], JSON_DELETE); // Drop from export below
                    }
                }
                
                // Only if anything actually changed
                if(!patched) return;
                
                // Export out, can use most of the message as-is
                message = llJsonSetValue(message, ["action"], JSON_DELETE);
                message = llJsonSetValue(message, ["type"], "updated");
                sendMessage(message);
                llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, "", agent);
            }
            
            // Send a RegionSayTo message directly to the target agent (but should work with objects too?)
            else if(action == "message")
            {
                key target = (key)llJsonGetValue(message, ["target"]);
                if(llKey2Name(target) != "")
                {
                    llRegionSayTo(
                        target,
                        (integer)llJsonGetValue(message, ["channel"]),
                        llJsonGetValue(message, ["message"])
                    );
                }
                
                // Relay to other Tracking Servers
                else if(llJsonValueType(message, ["_relayed"]) != JSON_TRUE)
                {
                    message = llJsonSetValue(message, ["_relayed"], JSON_TRUE);
                    borderMessage(message);
                }
            }
            
            // Ask a experience script to request experience permissions
            else if(action == "request-experience")
            {
                string agent = (key)llJsonGetValue(message, ["agent"]);
                if(llListFindList(Tracked, [(key)agent]) != -1) return;
                
                string region = llLinksetDataRead(agent + "_region");
                string experience = llJsonGetValue(message, ["experience"]);
                
                if(region == llGetRegionName())
                {
                    llRegionSayTo(agent, PUBLIC_CHANNEL, llJsonGetValue(message, ["message"]));
                    llMessageLinked(LINK_SET, MESSAGE_EXPERIENCE_REQUEST, experience, agent);
                }
                
                // Relay to other Tracking Servers
                else if(llJsonValueType(message, ["_relayed"]) != JSON_TRUE)
                {
                    message = llJsonSetValue(message, ["_relayed"], JSON_TRUE);
                    borderMessage(message);
                }
            }
        }
    }
    
    timer()
    {
        string currentRegion = llGetRegionName();
        
        // Loop through region agents to see if there are new additions
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        integer dataKeys = llGetListLength(AgentDataKeys);
        integer iterator = llGetListLength(agents);
        while(iterator --> 0)
        {
            string agent = llList2Key(agents, iterator);
            if(agent == NULL_KEY) jump continue;
            
            integer index = llListFindList(Tracked, [(key)agent]);
            
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
                if(TrackingDataScripts)
                {
                    integer pre = llListFindList(Prechecks, [(key)agent]);
                    if(pre == -1)
                    {
                        Prechecks += [(key)agent, 0];
                        llMessageLinked(LINK_SET, MESSAGE_PRECHECK, "", agent);
                        jump continue; // Add to prechecks first
                    }
                    
                    integer checks = llList2Integer(Prechecks, pre + 1);
                    if(checks < TrackingDataScripts) jump continue; // Do not consider until prechecks are complete
                    
                    // Prechecks all complete
                    Prechecks = llDeleteSubList(Prechecks, pre, pre + 1);
                }
                
                // Event: Agent entered region
                Tracked += (key)agent;
                key group = llList2Key(llGetObjectDetails(llList2Key(attachments, 0), [OBJECT_GROUP]), 0);
                
                llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
                llLinksetDataWrite(agent + "_TTL", (string)TRACKING_TTL);
                llLinksetDataWrite(agent + "_region", currentRegion);
                llLinksetDataWrite(agent + "_displayName", displayName);
                llLinksetDataWrite(agent + "_userName", userName);
                llLinksetDataWrite(agent + "_group", group);
                
                list data = [
                    "type", "entered",
                    "agent", agent
                ];
                integer keyIterator = dataKeys;
                while(keyIterator --> 0)
                {
                    string k = llList2String(AgentDataKeys, keyIterator);
                    string v = llLinksetDataRead(agent + "_" + k);
                    data += [k, v];
                }
                string json = llList2Json(JSON_OBJECT, data);
                sendMessage(json);
                llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, "", agent);
            }
            
            else
            {
                string region = llLinksetDataRead(agent + "_region");
                integer changedRegion = region != currentRegion;
                
                if(changedRegion)
                {
                    // Event: Agent changed region
                    llLinksetDataWrite(agent + "_region", currentRegion);
                    
                    string json = llList2Json(JSON_OBJECT, [
                        "type", "updated",
                        "agent", agent,
                        "region", currentRegion
                    ]);
                    sendMessage(json);
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, "", agent);
                }
            }
            
            @continue;
        }
        
        // Loop through tracked to see if agents have left
        iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            string agent = llList2Key(Tracked, iterator);
            integer TTL = (integer)llLinksetDataRead(agent + "_TTL");
            string region = llLinksetDataRead(agent + "_region");
            if(region != currentRegion) jump continue2;
            key group = (key)llLinksetDataRead(agent + "_group");
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
                    llLinksetDataDeleteFound("^" + agent + "_", "");
                    
                    string json = llList2Json(JSON_OBJECT, [
                        "type", "left",
                        "agent", agent
                    ]);
                    sendMessage(json);
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_LEFT, "", agent);
                }
            }
            
            // Tracking in region
            else
            {
                // We'll need to check changes to these:
                // - Group
                
                key currentGroup = llList2Key(llGetObjectDetails(llList2Key(attachments, -1), [OBJECT_GROUP]), 0);
                
                integer isUpdated = FALSE;
                string updated = llList2Json(JSON_OBJECT, [
                    "type", "updated",
                    "agent", agent
                ]);
                
                if(currentGroup != group)
                {
                    llLinksetDataWrite((string)agent + "_group", currentGroup);
                    updated = llJsonSetValue(updated, ["group"], currentGroup);
                    isUpdated = TRUE;
                }
                
                
                if(isUpdated)
                {
                    sendMessage(updated);
                    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, "", agent);
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
        if(value == MESSAGE_PRECHECKED) onTrackingLinkPrechecked(identifier, text);
        else if(value == MESSAGE_DELTA) onTrackingLinkDelta(identifier, text);
        else if(value == MESSAGE_SEND) onTrackingLinkSend(text);
        
        // else if(value == MESSAGE_EXPERIENCE_ACCEPTED) onTrackingLinkExperienceAccepted(text);
        // else if(value == MESSAGE_EXPERIENCE_DENIED) onTrackingLinkExperienceDenied(text);
        // else if(value == MESSAGE_EXPERIENCE_ADDED) onTrackingLinkExperienceAdded(identifier);
        // else if(value == MESSAGE_EXPERIENCE_REMOVED) onTrackingLinkExperienceRemoved(identifier);
        // else if(value == MESSAGE_EXPERIENCE_TESTED) onTrackingLinkExperienceTested(identifier);
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

