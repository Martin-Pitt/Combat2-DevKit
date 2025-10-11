list Tracked = [/* key Agent */];
// Related linkset data keys: (also see AgentDataKeys)
// integer <Agent>_TTL -- Time to live, before being removed (waits to see if agent crossed regions)  [Server only]
// string <Agent>_region -- Name of region
// string <Agent>_displayName -- llGetDisplayName only works in current region and avoids having to llRequestDisplayName
// string <Agent>_userName -- Same issue as displayName
// key <Agent>_group -- Active group key; Empty string or NULL_KEY is (none)

// Additional custom data available beyond the core set:
// string <Agent>_team -- Team the agent is part of, an empty string is effectively 'Neutral', 'Unassigned' or 'Civilians' as you see fit
// string <Agent>_area -- Within an area, such as "Hub", "Vertical Sim" or "Resdayn"; Requires Tracking Data: Area script on Tracking servers
// string[] <Agent>_experiences -- JSON array of named experiences that the user has; Requires Tracking Data: Experience - * script(s) on Tracking servers

#define TRACKING_TTL 30

#define sendMessage(message) internalMessage(message); borderMessage(message); externalMessage(message)
#define internalMessage(message) llRegionSay(TRACKING_INTERNAL_CHANNEL, message)
#define borderMessage(message) llWhisper(TRACKING_BORDER_CHANNEL, message)
#define externalMessage(message) llRegionSay(TRACKING_CHANNEL, message)

// These are the related linkset data keys for tracked agents, this list can grow dynamically
// via script link messages (MESSAGE_DELTA, see any Tracking Data: ... scripts)
// or even just any JSON {"action":"delta","agent":...} listener messages sent to TRACKING_CHANNEL (verified / owner-only)
list AgentDataKeys = ["region", "displayName", "userName", "group"];

// Overview of these functions:
// onTracking* -- all functions are handling events/messages related to Tracking
// onTrackingAgent* -- Listener events processing agent events from other Tracking Servers, helps coordinate multiple regions together
// onTrackingServer* -- Listener events related to handshaking between Tracking Servers
// onTrackingLink* -- Handling link messages received in the main script of the Tracking Server
// -- There used to be more here but have been integrated back into their respective scripts to minimise memory. Too many UDFs = less free memory for working data

onTrackingAgentEntered(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    if(llListFindList(Tracked, [(key)agent]) != -1) return; // Only add if doesn't already exist
    
    // Add to Tracked list
    Tracked += (key)agent;
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
    
    // Default data
#ifdef TRACKING_SERVER
    llLinksetDataWrite(agent + "_TTL", (string)TRACKING_TTL);
#endif
    
    // Import data
    list data = llJson2List(payload);
    integer index; integer total;
    for(index = 0, total = llGetListLength(data); index < total; index += 2)
    {
        string name = llList2String(data, index);
        string value = llList2String(data, index + 1);
        if(name != "type" && name != "agent")
        {
            if(llListFindList(AgentDataKeys, [name]) == -1) AgentDataKeys += name;
            llLinksetDataWrite(agent + "_" + name, value);
        }
    }
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, "", agent);
}

onTrackingAgentUpdated(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    if(llListFindList(Tracked, [(key)agent]) == -1) return; // Only update if exists
    
    // Import data
    list data = llJson2List(payload);
    integer index; integer total;
    for(index = 0, total = llGetListLength(data); index < total; index += 2)
    {
        string name = llList2String(data, index);
        string value = llList2String(data, index + 1);
        if(name != "type" && name != "agent")
        {
            if(llListFindList(AgentDataKeys, [name]) == -1) AgentDataKeys += name;
            llLinksetDataWrite(agent + "_" + name, value);
        }
    }
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, "", agent);
}

onTrackingAgentLeft(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    integer index = llListFindList(Tracked, [(key)agent]);
    if(index == -1) return;
    
    Tracked = llDeleteSubList(Tracked, index, index);
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
    llLinksetDataDeleteFound("^" + agent + "_", "");
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_LEFT, "", agent);
}


// We can't use llGetOwnerKey across borders, so the only way to trust chat across sim boundaries is via verification of eachother
// You could use llSetRegionPos if it's neighbouring sim, but what if it's 2 sims away or further?
list VerifiedIdentifiers = [];

#define generateHandshake() llSignRSA(llLinksetDataRead("trackingPrivateKey"), (string)llGetKey() + " " + llGetDate(), "sha512")
#define verifyHandshake(signature, identifier) llVerifyRSA(llLinksetDataRead("trackingPublicKey"), (string)identifier + " " + llGetDate(), signature, "sha512")

// When a tracking server is initialised, we verify that it is legit and respond back by sharing current data
onTrackingServerInit(key identifier, string message) {
    // Verify before continuing
    if(!onTrackingServerVerify(identifier, llJsonGetValue(message, ["signature"]))) return;
    
    // Send a response to let them verify us too
    string json = llList2Json(JSON_OBJECT, [
        "type", "reinit",
        "region", llGetRegionName(),
        "signature", generateHandshake()
    ]);
    internalMessage(json);
    borderMessage(json);
    
    // Server initialised, clear data from their region
    string region = llJsonGetValue(message, ["region"]);
    integer iterator = llGetListLength(Tracked);
    while(iterator --> 0)
    {
        string agent = llList2Key(Tracked, iterator);
        string agentRegion = llLinksetDataRead(agent + "_region");
        if(region == agentRegion)
        {
            integer index = llListFindList(Tracked, [(key)agent]);
            Tracked = llDeleteSubList(Tracked, index, index);
            llLinksetDataDeleteFound("^" + agent + "_", "");
        }
    }
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
    
    // Send over data of our current region
    integer keys = llGetListLength(AgentDataKeys);
    integer total = llGetListLength(Tracked);
    for(iterator = 0; iterator < total; ++iterator)
    {
        string agent = llList2Key(Tracked, iterator);
        list data = [
            "type", "entered",
            "agent", agent
        ];
        integer keyIterator = keys;
        while(keyIterator --> 0)
        {
            string k = llList2String(AgentDataKeys, keyIterator);
            string v = llLinksetDataRead(agent + "_" + k);
            data += [k, v];
        }
        string json = llList2Json(JSON_OBJECT, data);
        internalMessage(json);
        borderMessage(json);
        llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, "", agent);
    }
}

// Helps verify that a tracking server message is authentic based on the signature
integer onTrackingServerVerify(key identifier, string signature) {
    // Already verified?
    if(llListFindList(VerifiedIdentifiers, [identifier]) != -1) return TRUE;
    
    // Check signature
    if(!verifyHandshake(signature, identifier)) return FALSE;
    VerifiedIdentifiers += identifier;
    return TRUE;
}


// Before the Tracking Server announces that an agent has entered the region it makes sure they are fully logged in / teleported in
// During that short moment we can also make sure we have everything collected on the agent before sending out a full data packet
// Which helps scripts start out with all the info available to them from the get go instead of processing a flood of updates
onTrackingLinkPrechecked(key identifier, string message)
{
    // Check if still part of precheck list
    integer pre = llListFindList(Prechecks, (list)identifier);
    if(pre == -1) return;
    
    // Increment the checks
    integer checks = llList2Integer(Prechecks, pre + 1) + 1;
    Prechecks = llListReplaceList(Prechecks, [checks], pre + 1, pre + 1);
    
    // See if the precheck had added new custom data
    list dataKeys = llJson2List(message);
    integer iterator = llGetListLength(dataKeys);
    while(iterator --> 0)
    {
        string name = llList2String(dataKeys, iterator);
        if(llListFindList(AgentDataKeys, [name]) == -1) AgentDataKeys += name;
    }
}

// Delta messages are when we tell the main Tracking Server script that there was an update to the agent data
// TODO: Batch/collect all delta changes up to quarter of a second?
onTrackingLinkDelta(key identifier, string message)
{
    list data = [
        "type", "updated",
        "agent", identifier
    ];
    list keysUpdated = llJson2List(message);
    integer iterator = llGetListLength(keysUpdated);
    while(iterator --> 0)
    {
        string k = llList2String(keysUpdated, iterator);
        string v = llLinksetDataRead((string)identifier + "_" + k);
        data += [k, v];
    }
    string json = llList2Json(JSON_OBJECT, data);
    sendMessage(json);
    llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, "", identifier);
}

// Ask the main Tracking Server to send a message on our behalf
onTrackingLinkSend(string message)
{
    sendMessage(message);
}


/*
onTrackingLinkExperienceAccepted(string message)
{
    string agent = llJsonGetValue(message, ["agent"]);
    string experience = llJsonGetValue(message, ["experience"]);
    string json = llList2Json(JSON_OBJECT, [
        "type", "experience-accepted",
        "agent", agent,
        "experience", experience
    ]);
    sendMessage(json);
}

onTrackingLinkExperienceDenied(string message)
{
    string agent = llJsonGetValue(message, ["agent"]);
    string experience = llJsonGetValue(message, ["experience"]);
    integer reason = (integer)llJsonGetValue(message, ["reason"]);
    string json = llList2Json(JSON_OBJECT, [
        "type", "experience-denied",
        "agent", agent,
        "experience", experience,
        "reason", llGetExperienceErrorMessage(reason)
    ]);
    sendMessage(json);
}

onTrackingLinkExperienceAdded(key identifier)
{
    string experiences = llLinksetDataRead((string)identifier + "_experiences");
    string json = llList2Json(JSON_OBJECT, [
        "type", "updated",
        "agent", identifier,
        "experiences", experiences
    ]);
    sendMessage(json);
}

onTrackingLinkExperienceRemoved(key identifier)
{
    string experiences = llLinksetDataRead((string)identifier + "_experiences");
    string json = llList2Json(JSON_OBJECT, [
        "type", "updated",
        "agent", identifier,
        "experiences", experiences
    ]);
    sendMessage(json);
}

onTrackingLinkExperienceTested(key identifier)
{
    integer pre = llListFindList(Prechecks, (list)identifier);
    if(pre == -1) return;
    integer checks = llList2Integer(Prechecks, pre + 1) + 1;
    Prechecks = llListReplaceList(Prechecks, [checks], pre + 1, pre + 1);
}
*/
