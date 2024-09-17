list Tracked = [/* key Agent */];
// Related linkset data keys:
// integer <Agent>_TTL -- Time to live, before being removed (waits to see if agent crossed regions)  [Server only]
// integer <Agent>_TTE -- Time to enter, before being entered (decrements per custom data script)  [Server only]
// string <Agent>_region -- Name of region
// string <Agent>_area -- Within an area, such as "Hub", "Vertical Sim" or "Resdayn"
// string <Agent>_displayName
// string <Agent>_userName
// key <Agent>_group -- Active group key
// string <Agent>_team

// string[] <Agent>_experiences -- JSON array of named experiences that the user has
// key[] <Agent>_huds -- JSON array of HUD keys to track

#define TRACKING_TTL 30

#define sendMessage(message) internalMessage(message) externalMessage(message)
#define internalMessage(message) llWhisper(TRACKING_INTERNAL_CHANNEL, message); llRegionSay(TRACKING_INTERNAL_CHANNEL, message);
#define externalMessage(message) llRegionSay(TRACKING_CHANNEL, message);

#define MESSAGE_EXPERIENCE_REQUEST 100
#define MESSAGE_EXPERIENCE_ACCEPTED 101
#define MESSAGE_EXPERIENCE_DENIED 102
#define MESSAGE_EXPERIENCE_ADDED 103
#define MESSAGE_EXPERIENCE_REMOVED 104
#define MESSAGE_EXPERIENCE_TEST 105
#define MESSAGE_EXPERIENCE_TESTED 106

onTrackingAgentEntered(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    if(llListFindList(Tracked, [(key)agent]) != -1) return;
    
    // Add to Tracked list
    Tracked += (key)agent;
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
    
    // Default data
#ifdef TRACKING_SERVER
    llLinksetDataWrite(agent + "_TTL", (string)TRACKING_TTL);
    llLinksetDataWrite(agent + "_TTE", "0");
#endif
    llLinksetDataWrite(agent + "_team", "");
    llLinksetDataWrite(agent + "_experiences", "");
    llLinksetDataWrite(agent + "_huds", "");
    
    // Import data
    list data = llJson2List(payload);
    integer index; integer total;
    for(index = 0, total = llGetListLength(data); index < total; index += 2)
    {
        string name = llList2String(data, index);
        string value = llList2String(data, index + 1);
        if(name != "type" && name != "agent")
            llLinksetDataWrite(agent + "_" + name, value);
    }
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_ENTERED, agent, "");
}

onTrackingAgentUpdated(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    if(llListFindList(Tracked, [(key)agent]) != -1) return;
    
    // Import data
    list data = llJson2List(payload);
    integer index; integer total;
    for(index = 0, total = llGetListLength(data); index < total; index += 2)
    {
        string name = llList2String(data, index);
        string value = llList2String(data, index + 1);
        if(name != "type" && name != "agent")
            llLinksetDataWrite(agent + "_" + name, value);
    }
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_UPDATED, agent, "");
}

onTrackingAgentLeft(string payload) {
    string agent = llJsonGetValue(payload, ["agent"]);
    integer index = llListFindList(Tracked, [(key)agent]);
    if(index == -1) return;
    
    Tracked = llDeleteSubList(Tracked, index, index);
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
#ifdef TRACKING_SERVER
    llLinksetDataDelete(agent + "_TTL");
    llLinksetDataDelete(agent + "_TTE");
#endif
    llLinksetDataDelete(agent + "_region");
    llLinksetDataDelete(agent + "_area");
    llLinksetDataDelete(agent + "_displayName");
    llLinksetDataDelete(agent + "_userName");
    llLinksetDataDelete(agent + "_group");
    llLinksetDataDelete(agent + "_team");
    llLinksetDataDelete(agent + "_experiences");
    llLinksetDataDelete(agent + "_huds");
    
    llMessageLinked(LINK_SET, MESSAGE_AGENT_LEFT, agent, "");
}

onTrackingServerInit(string payload) {
    // Server initialised, clear data from their region
    string region = llJsonGetValue(payload, ["region"]);
    integer iterator = llGetListLength(Tracked);
    while(iterator --> 0)
    {
        string agent = llList2Key(Tracked, iterator);
        string agentRegion = llLinksetDataRead(agent + "_region");
        if(region == agentRegion)
        {
            integer index = llListFindList(Tracked, [(key)agent]);
            Tracked = llDeleteSubList(Tracked, index, index);
            llLinksetDataDelete(agent + "_TTL");
            llLinksetDataDelete(agent + "_region");
            llLinksetDataDelete(agent + "_area");
            llLinksetDataDelete(agent + "_displayName");
            llLinksetDataDelete(agent + "_userName");
            llLinksetDataDelete(agent + "_group");
            llLinksetDataDelete(agent + "_team");
            llLinksetDataDelete(agent + "_experiences");
            llLinksetDataDelete(agent + "_huds");
        }
    }
    llLinksetDataWrite("tracked", llList2Json(JSON_ARRAY, Tracked));
    
    // Send over data of our current region
    integer total = llGetListLength(Tracked);
    for(iterator = 0; iterator < total; ++iterator)
    {
        string agent = llList2Key(Tracked, iterator);
        string region = llLinksetDataRead(agent + "_region");
        string area = llLinksetDataRead(agent + "_area");
        string displayName = llLinksetDataRead(agent + "_displayName");
        string userName = llLinksetDataRead(agent + "_userName");
        key group = (key)llLinksetDataRead(agent + "_group");
        string team = llLinksetDataRead(agent + "_team");
        string experiences = llLinksetDataRead(agent + "_experiences");
        string huds = llLinksetDataRead(agent + "_huds");
        
        internalMessage(llList2Json(JSON_OBJECT, [
            "type", "entered",
            "agent", agent,
            "region", region,
            "area", area,
            "displayName", displayName,
            "userName", userName,
            "group", group,
            "team", team,
            "experiences", experiences,
            "huds", huds
        ]));
    }
}

onTrackingGetList(key identifier)
{
    list bucket;
    integer iterator = llGetListLength(Tracked);
    integer fill;
    while(iterator --> 0)
    {
        string agent = llList2Key(Tracked, iterator);
        string region = llLinksetDataRead(agent + "_region");
        string area = llLinksetDataRead(agent + "_area");
        string displayName = llLinksetDataRead(agent + "_displayName");
        string userName = llLinksetDataRead(agent + "_userName");
        key group = (key)llLinksetDataRead(agent + "_group");
        string team = llLinksetDataRead(agent + "_team");
        string experiences = llLinksetDataRead(agent + "_experiences");
        string huds = llLinksetDataRead(agent + "_huds");
        
        string payload = llList2Json(JSON_OBJECT, [
            "agent", agent,
            "region", region,
            "area", area,
            "displayName", displayName,
            "userName", userName,
            "group", group,
            "team", team,
            "experiences", experiences,
            "huds", huds
        ]);
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

onTrackingMessage(string payload)
{
    key target = (key)llJsonGetValue(payload, ["target"]);
    if(llKey2Name(target) != "")
    {
        llRegionSayTo(
            target,
            (integer)llJsonGetValue(payload, ["channel"]),
            llJsonGetValue(payload, ["message"])
        );
    }
    
    // Relay to other Tracking Servers
    else if(llJsonValueType(payload, ["_relayed"]) != JSON_TRUE)
    {
        payload = llJsonSetValue(payload, ["_relayed"], JSON_TRUE);
        llWhisper(TRACKING_CHANNEL, payload);
    }
}

onTrackingAssignTeam(string payload)
{
    key agent = (key)llJsonGetValue(payload, ["agent"]);
    string team = llJsonGetValue(payload, ["team"]);
    
    integer index = llListFindList(Tracked, [agent]);
    if(index == -1) return;
    
    string currentTeam = llLinksetDataRead((string)agent + "_team");
    if(currentTeam == team) return;
    
    llLinksetDataWrite((string)agent + "_team", team);
    sendMessage(llList2Json(JSON_OBJECT, [
        "type", "updated",
        "agent", agent,
        
        "team", team
    ]));
}

onTrackingRequestExperience(string payload)
{
    string agent = (key)llJsonGetValue(payload, ["agent"]);
    if(llListFindList(Tracked, [(key)agent]) != -1) return;
    
    string region = llLinksetDataRead(agent + "_region");
    string experience = llJsonGetValue(payload, ["experience"]);
    
    if(region == llGetRegionName())
    {
        llRegionSayTo(agent, PUBLIC_CHANNEL, llJsonGetValue(payload, ["message"]));
        llMessageLinked(LINK_THIS, MESSAGE_EXPERIENCE_REQUEST, experience, agent);
    }
    
    // Relay to other Tracking Servers
    else if(llJsonValueType(payload, ["_relayed"]) != JSON_TRUE)
    {
        payload = llJsonSetValue(payload, ["_relayed"], JSON_TRUE);
        llWhisper(TRACKING_CHANNEL, payload);
    }
}

onTrackingLinkExperienceAccepted(string payload)
{
    string agent = llJsonGetValue(payload, ["agent"]);
    string experience = llJsonGetValue(payload, ["experience"]);
    
    sendMessage(llList2Json(JSON_OBJECT, [
        "type", "experience-accepted",
        "agent", agent,
        "experience", experience
    ]));
}

onTrackingLinkExperienceDenied(string payload)
{
    string agent = llJsonGetValue(payload, ["agent"]);
    string experience = llJsonGetValue(payload, ["experience"]);
    integer reason = (integer)llJsonGetValue(payload, ["reason"]);
    
    sendMessage(llList2Json(JSON_OBJECT, [
        "type", "experience-denied",
        "agent", agent,
        "experience", experience,
        "reason", llGetExperienceErrorMessage(reason)
    ]));
}

onTrackingLinkExperienceAdded(key identifier)
{
    string experiences = llLinksetDataRead((string)identifier + "_experiences");
    
    sendMessage(llList2Json(JSON_OBJECT, [
        "type", "updated",
        "agent", identifier,
        
        "experiences", experiences
    ]));
}

onTrackingLinkExperienceRemoved(key identifier)
{
    string experiences = llLinksetDataRead((string)identifier + "_experiences");
    
    sendMessage(llList2Json(JSON_OBJECT, [
        "type", "updated",
        "agent", identifier,
        
        "experiences", experiences
    ]));
}

onTrackingLinkExperienceTested(key identifier)
{
    integer pre = llListFindList(Prechecks, (list)identifier);
    if(pre == -1) return;
    integer checks = llList2Integer(Prechecks, pre + 1);
    Prechecks = llListReplaceList(Prechecks, [checks + 1], pre + 1, pre + 1);
}