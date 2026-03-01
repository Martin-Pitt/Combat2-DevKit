// Tracks agents in the region and whether they are ready combatants

#define FLECS_TRACKER_CHANNEL -1521008921
#define EVENT_TRACKED 1 // [key agent]
#define EVENT_UNTRACKED 2 // [key agent]
#define EVENT_TRACKED_RESET 3 // []
#define REQUEST_TRACKED 4 // []
// Linkset Data:
// "Tracked" = json [key agent]
// "Known" = json [key agent]
// "Status.<key agent>" = "" | "requested" | "denied" | "ready" | "dropped"

list Tracked;
TrackAgent(key agent) {
    integer needle = llListFindList(Tracked, [agent]);
    if(needle != -1) return; // Already tracking
    Tracked += agent;
    llLinksetDataWrite("Tracked", llList2Json(JSON_ARRAY, Tracked));
    llRegionSay(FLECS_TRACKER_CHANNEL, llChar(EVENT_TRACKED) + (string)agent);
    llMessageLinked(LINK_SET, EVENT_TRACKED, "", agent);
}
UntrackAgent(key agent) {
    integer needle = llListFindList(Tracked, [agent]);
    if(needle == -1) return; // Not tracking
    Tracked = llDeleteSubList(Tracked, needle, needle);
    llLinksetDataWrite("Tracked", llList2Json(JSON_ARRAY, Tracked));
    llRegionSay(FLECS_TRACKER_CHANNEL, llChar(EVENT_UNTRACKED) + (string)agent);
    llMessageLinked(LINK_SET, EVENT_UNTRACKED, "", agent);
}

list Known;
integer IsKnownAgent(key agent) { return llListFindList(Known, [agent]) != -1; }
KnownAgent(key agent)
{
    if(llListFindList(Known, [agent]) != -1) return; // Already known
    Known += agent;
    llLinksetDataWrite("Known", llList2Json(JSON_ARRAY, Known));
    Debug("secondlife:///app/agent/" + string(agent) + "/inspect entered");
}
DropAgent(key agent)
{
    integer needle = llListFindList(Known, [agent]);
    if(needle == -1) return; // Not known
    Known = llDeleteSubList(Known, needle, needle);
    llLinksetDataWrite("Known", llList2Json(JSON_ARRAY, Known));
    needle = llListFindList(Requests, [agent]);
    if(needle != -1) Requests = llDeleteSubList(Requests, needle, needle);
    UntrackAgent(agent);
    llLinksetDataDelete("Status." + (string)agent);
    Debug("secondlife:///app/agent/" + string(agent) + "/inspect dropped");
}

integer IsAgentPresent(key agent) {
    string animation = llGetAnimation(agent);
    if(animation == "" || animation == "init") return FALSE; // During login, region teleports and logout
    
    string legacyName = llKey2Name(agent);
    if(legacyName == "") return FALSE; // dropped avatars have an empty string
    
    vector size = llGetAgentSize(agent);
    if(size == ZERO_VECTOR) return FALSE; // Certain types of ghosts can return key but not exist
    
    list attachments = llGetAttachedList(agent);
    if(llGetListLength(attachments) == 0) return FALSE; // Not finished logging in, teleporting in or crossing
    
    return TRUE;
}

integer InBattlefield(key agent)
{
    list details = llGetObjectDetails(agent, [OBJECT_POS]);
    vector pos = llList2Vector(details, 0);
    return (0 < pos.z && pos.z < 1024.);
}

list Requests;
SetAgentStatus(key agent, string status)
{
    string name = "Status." + (string)agent;
    
    string previous = llLinksetDataRead(name);
    if(previous == status) return; // No change
    
    llLinksetDataWrite(name, status);
    /* Agent status:
    - "" (listed), they are in the region's agent list
    - requested, requested experience permissions from agent / waiting for them to accept or decline
    - denied, agent denied or forgot experience permissions
    - ready, accepted experience permissions / is already in experience -- ready to be a combatant in the battlefield
    - dropped, maybe left battlefield, logging out or entered god mode -- not fully left region yet
    */
    
    // Side effects
    if(status == "ready") TrackAgent(agent);
    else if(previous == "ready") UntrackAgent(agent);
    
    if(status == "requested")
    {
        if(Requests) Requests += agent;
        else
        {
            Requests += agent;
            list details = llGetExperienceDetails(NULL_KEY);
            string experience = llList2Key(details, 2);
            llRegionSayTo(agent, PUBLIC_CHANNEL, "This combat region uses an experience to help with respawning combatants. For details of the experience see: secondlife:///app/experience/" + experience + "/profile");
            llRequestExperiencePermissions(agent, ""); // Start processing first requests
        }
    }
    else if(previous == "requested")
    {
        integer needle = llListFindList(Requests, [agent]);
        if(needle != -1) Requests = llDeleteSubList(Requests, needle, needle);
        if(Requests) llRequestExperiencePermissions(llList2Key(Requests, 0), ""); // Process next request
    }
    
    if(status == "denied")
    {
        list details = llGetExperienceDetails(NULL_KEY);
        string experience = llList2Key(details, 2);
        llRegionSayTo(agent, PUBLIC_CHANNEL, "By declining the experience, you cannot use the combat system in this region. For details of the experience and whether to allow it manually see: secondlife:///app/experience/" + experience + "/profile");
    }
    
    if(previous) Debug("secondlife:///app/agent/" + string(agent) + "/inspect -- status: " + previous + " -> " + status);
    else Debug("secondlife:///app/agent/" + string(agent) + "/inspect -- status: " + status);
}


Debug(string log) { llOwnerSay(log); }


default
{
    state_entry()
    {
        list details = llGetExperienceDetails(NULL_KEY);
        // string ExperienceName = llList2String(details, 0);
        string experience = llList2Key(details, 2);
        integer expState = llList2Integer(details, 3);
        string expStateMessage = llList2String(details, 4);
        
        string error;
        if(experience == NULL_KEY) "This script must be compiled with an experience to work";
        else if(expState == XP_ERROR_NOT_PERMITTED_LAND) error = "Experience is not permitted on this land";
        else if(expState == XP_ERROR_MATURITY_EXCEEDED) error = "Experience maturity level is too high for this region";
        else if(expState == XP_ERROR_NOT_FOUND) error = "The sim was unable to verify the validity of the experience. Retry after a short wait";
        else if(expState == XP_ERROR_INVALID_EXPERIENCE) error = "Experience is invalid, it no longer exists";
        else if(expState == XP_ERROR_EXPERIENCE_DISABLED) error = "The experience owner has temporarily disabled the experience";
        else if(expState == XP_ERROR_EXPERIENCES_DISABLED) error = "The region currently has experiences disabled";
        else if(expState == XP_ERROR_EXPERIENCE_SUSPENDED) error = "The experience has been disabled by Linden Lab customer support";
        else if(expState == XP_ERROR_UNKNOWN_ERROR) error = "An unknown experience error with the region occurred";
        
        if(error)
        {
            Debug("Error: " + error + "; " + expStateMessage);
            return;
        }
        
        //*
        // Recover last state
        llRegionSay(FLECS_TRACKER_CHANNEL, llChar(EVENT_TRACKED_RESET));
        llMessageLinked(LINK_SET, EVENT_TRACKED_RESET, "", "");
        Tracked = llJson2List(llLinksetDataRead("Tracked"));
        Known = llJson2List(llLinksetDataRead("Known"));
        integer iterator = llGetListLength(Known);
        while(iterator --> 0) Known = llListReplaceList(Known, [(key)llList2String(Known, iterator)], iterator, iterator); // Typecast list
        iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            key agent = llList2String(Tracked, iterator);
            Tracked = llListReplaceList(Tracked, [agent], iterator, iterator); // Typecast list
            llRegionSay(FLECS_TRACKER_CHANNEL, llChar(EVENT_TRACKED) + (string)agent);
        }
        /*/
        // Clear stale data
        llLinksetDataDelete("Tracked");
        llLinksetDataDelete("Known");
        llLinksetDataDeleteFound("^Status", "");
        //*/
        
        llListen(FLECS_TRACKER_CHANNEL, "", NULL_KEY, "");
        llSetTimerEvent(1.0);
        Debug("FLECS Tracker initialized w/ secondlife:///app/experience/" + experience + "/profile");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer type = llOrd(message, 0);
        if(type == REQUEST_TRACKED)
        {
            integer iterator = llGetListLength(Tracked);
            while(iterator --> 0)
            {
                key agent = llList2String(Tracked, iterator);
                llRegionSayTo(identifier, FLECS_TRACKER_CHANNEL, llChar(EVENT_TRACKED) + (string)agent);
            }
        }
    }
    
    timer()
    {
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        
        // Check for [new arrivals] and [monitor status]
        integer iterator = llGetListLength(agents);
        while(iterator --> 0)
        {
            key agent = llList2String(agents, iterator);
            if(agent == NULL_KEY) jump continue; // [Ghosts] and [God Mode] can return NULL_KEY
            string status = llLinksetDataRead("Status." + (string)agent);
            if(status == "") KnownAgent(agent);
            if(status == "" || status == "dropped")
            {
                if(IsAgentPresent(agent) && InBattlefield(agent))
                {
                    if(llAgentInExperience(agent)) SetAgentStatus(agent, status = "ready"); // Skip straight to ready
                    else SetAgentStatus(agent, status = "requested"); // Start experience permission flow
                }
            }
            else if(status == "requested" || status == "denied")
            {
                // Waiting for user to accept or decline the experience, via dalog or manually
                if(llAgentInExperience(agent)) SetAgentStatus(agent, status = "ready");
            }
            else if(status == "ready")
            {
                // Agent is good to go!
                
                // Now we monitor
                if(!InBattlefield(agent))
                {
                    SetAgentStatus(agent, status = "dropped"); // [Left battlefield]
                }
                // else if(llGetAgentSize(agent) == ZERO_VECTOR)
                // {
                //     SetAgentStatus(agent, status = "dropped"); // [Left region], [logging out], [ghosted]
                // }
                else if(!llAgentInExperience(agent))
                {
                    if(IsAgentPresent(agent)) SetAgentStatus(agent, status = "denied"); // [Manually disabled experience]
                    else SetAgentStatus(agent, status = "dropped"); // [Ghosted], [logging out], [leaving region] or [entered god mode]
                }
            }
            
            @continue;
        }
        
        
        // Check for drops
        iterator = llGetListLength(Known);
        while(iterator --> 0)
        {
            key agent = llList2Key(Known, iterator);
            if(llListFindList(agents, [agent]) == -1) DropAgent(agent);
            // Can be due to [logging out], [leaving region], [ghosting] or [god mode]
        }
    }
    
    experience_permissions(key agent)
    {
        string status = llLinksetDataRead("Status." + (string)agent);
        if(status != "requested") return; // Not expected, either approved manually or sim loaded details for llAgentInExperience
        SetAgentStatus(agent, "ready");
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        if(reason != XP_ERROR_REQUEST_PERM_TIMEOUT && reason != XP_ERROR_NOT_PERMITTED) return; // Other errors are not expected
        if(!IsKnownAgent(agent)) return; // Is this even an agent we know about?
        if(llAgentInExperience(agent)) return; // Did user approve manually and left the dialog to timeout?
        SetAgentStatus(agent, "denied");
    }
}
