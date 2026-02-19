#define RESPAWN_CHANNEL -960
#define HUD "MEBCS HUD"
#define SitDowned "Downed Combatant"

list Safezones = [
    <0, 0, 500>, <256, 256, 4096>
];
list Tracked;

integer isAgentReady(key agent)
{
    if(agent == NULL_KEY) return FALSE;
    
    string animation = llGetAnimation(agent);
    string legacyName = llKey2Name(agent); // Ghosted avatars have an empty string
    string displayName = llGetDisplayName(agent); // May not always be non-empty string?
    string userName = llGetUsername(agent); // May not always be non-empty string?
    list attachments = llGetAttachedList(agent); // If still logging in or teleport will be empty
    
    if(animation == ""
    || animation == "Init"
    || legacyName == ""
    || displayName == ""
    || userName == ""
    || llGetListLength(attachments) == 0){
        return FALSE;
    }
    
    return TRUE;
}

integer doesAgentHaveHUD(key agent)
{
    list attachments = llGetAttachedListFiltered(agent, [
        FILTER_INCLUDE, ATTACH_ANY_HUD,
        FILTER_FLAGS, FILTER_FLAG_HUDS
    ]);
    integer iterator = llGetListLength(attachments);
    while(iterator --> 0)
    {
        key attachment = llList2Key(attachments, iterator);
        if(llKey2Name(attachment) == HUD) return TRUE;
    }
    return FALSE;
}

handleAgent(key agent)
{
    string prefix = "HANDLE_" + (string)agent;
    string status = llLinksetDataRead(prefix + ".status");
    
    if(status == "active")
    {
        key hud = llLinksetDataRead(prefix + ".hud");
        if(llKey2Name(hud) != "") return;
        
        else
        {
            // HUD is gone, reset status
            llLinksetDataWrite(prefix + ".status", "detached");
            llLinksetDataDelete(prefix + ".hud");
        }
    }
    
    if(doesAgentHaveHUD(agent))
    {
        if(status != "active") llLinksetDataWrite(prefix + ".status", "active");
        return;
    }
    
    
    if(status == "attaching") // Already in the process of attaching
    {
        key hud = llLinksetDataRead(prefix + ".hud");
        if(llKey2Name(hud) == "")
        {
            // HUD is gone, reset status
            llLinksetDataWrite(prefix + ".status", "detached");
            llLinksetDataDelete(prefix + ".hud");
        }
        
        else
        {
            // Still attaching, do nothing
        }
    }
    
    else if(llAgentInExperience(agent))
    {
        if(hasFreeAttachmentSlot(agent))
        {
            if(status != "attaching")
            {
                key hud = llRezObjectWithParams(HUD, [
                    REZ_POS, llList2Vector(llGetObjectDetails(agent, [OBJECT_POS]), 0), FALSE, TRUE,
                    REZ_FLAGS, REZ_FLAG_TEMP,
                    REZ_PARAM, TRUE,
                    REZ_PARAM_STRING, llList2Json(JSON_OBJECT, [
                        "agent", (string)agent,
                        "safezones", llDumpList2String(Safezones, ";")
                    ])
                ]);
                llLinksetDataWrite(prefix + ".status", "attaching");
                llLinksetDataWrite(prefix + ".hud", (string)hud);
            }
        }
        
        else if(status != "no slot")
        {
            llRegionSayTo(agent, 0, "A free attachment slot is required to participate in combat. Please clear an attachment slot.");
            llLinksetDataWrite(prefix + ".status", "no slot");
        }
    }
    
    else if(status != "requested")
    {
        llRequestExperiencePermissions(agent, "");
        llLinksetDataWrite(prefix + ".status", "requested");
    }
}

integer hasFreeAttachmentSlot(key agent)
{
    return llList2Integer(llGetObjectDetails(agent, [OBJECT_ATTACHED_SLOTS_AVAILABLE]), 0) > 0;
}


default
{
    state_entry()
    {
        llLinksetDataDeleteFound("^HANDLE_", "");
        llRegionSay(RESPAWN_CHANNEL, llList2Json(JSON_OBJECT, ["event", "detach"]));
        
        llSetTimerEvent(4.0);
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(llSubStringIndex(message, "\"DEATH\"") == -1) return;
        
        list payloads = llJson2List(message);
        integer iterator = llGetListLength(payloads);
        while(iterator --> 0)
        {
            string payload = llList2String(payloads, iterator);
            string eventName = llJsonGetValue(payload, ["event"]);
            if(eventName == "DEATH")
            {
                string target = llJsonGetValue(payload, ["target"]);
                string status = llLinksetDataRead("HANDLE_" + target + ".status");
                if(status != "active") llTeleportAgentHome(target);
            }
        }
    }
    
    timer()
    {
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        integer iterator = llGetListLength(agents);
        
        while(iterator --> 0)
        {
            key agent = llList2Key(agents, iterator);
            
            integer isKnown = (llLinksetDataRead("HANDLE_" + (string)agent + ".status") != "");
            integer isReady = isAgentReady(agent);
            
            // Arrived
            if(!isKnown && isReady)
            {
                llLinksetDataWrite("HANDLE_" + (string)agent + ".status", "arrived");
                Tracked += agent;
            }
            
            // Leaving
            else if(isKnown && !isReady)
            {
                llLinksetDataDeleteFound("^HANDLE_" + (string)agent, "");
                integer pointer = llListFindList(Tracked, [agent]);
                if(pointer != -1) Tracked = llDeleteSubList(Tracked, pointer, pointer);
            }
        }
        
        iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            key agent = llList2Key(Tracked, iterator);
            handleAgent(agent);
        }
    }
    
    experience_permissions(key agent)
    {
        handleAgent(agent);
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        if(reason != 0 && reason != XP_ERROR_REQUEST_PERM_TIMEOUT) return;
        
        list details = llGetExperienceDetails(NULL_KEY);
        string experience = llList2Key(details, 2);
        llRegionSayTo(agent, PUBLIC_CHANNEL, "By declining the experience, you cannot use the combat system in this region. If you die, you will be teleported home. For details of the experience and whether to allow it see: secondlife:///app/experience/" + experience + "/profile");
        
        llLinksetDataWrite("HANDLE_" + (string)agent + ".status", "denied");
    }
}
