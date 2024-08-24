#define MESSAGE_INITIALISED 1
#define MESSAGE_DIED 2
#define MESSAGE_RESPAWNED 3
#define MESSAGE_DIED_WITHOUT_EXPERIENCE 4
#define MESSAGE_EXPERIENCE_DENIED 5


default
{
    state_entry()
    {
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
        llMessageLinked(LINK_THIS, MESSAGE_INITIALISED, "", "");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(llSubStringIndex(message, "\"DEATH\"") == -1) return; // Quick pre-check
        if((integer)llGetEnv("death_action") != 3) return; // Is the region setting not set to No Action?
        
        // Parse through combat event messages
        list payloads = llJson2List(message);
        integer count = llGetListLength(payloads);
        while(count --> 0)
        {
            string payload = llList2String(payloads, count);
            string eventName = llJsonGetValue(payload, ["event"]);
            if(eventName == "DEATH")
            {
                key target = llJsonGetValue(payload, ["target"]);
                llMessageLinked(LINK_THIS, MESSAGE_DIED, "", target);
                
                if(llAgentInExperience(target))
                {
                    llRequestExperiencePermissions(target, "");
                }
                
                else
                {
                    llRequestExperiencePermissions(target, "");
                    llRegionSayTo(target, PUBLIC_CHANNEL, "You have died from your health reaching 0%, however you are not part of the secondlife:///app/experience/b14afc84-6261-11ef-92f8-0242ac110003/profile experience and are thus unable to be teleported to a spawn point.\n\nCreated by secondlife:///app/agent/75078730-ebc8-4a80-adb9-1cfd2d95b5ca/im as an open system for setting up spawn systems for combat sims.");
                    llMessageLinked(LINK_THIS, MESSAGE_DIED_WITHOUT_EXPERIENCE,  "", target);
                }
            }
        }
    }
    
    experience_permissions(key agent)
    {
        llTeleportAgent(agent, "", llGetPos(), llRot2Fwd(llGetRot()) + llGetPos());
        llMessageLinked(LINK_THIS, MESSAGE_RESPAWNED, (string)llGetPos(), agent);
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        if(reason == XP_ERROR_EXPERIENCES_DISABLED) return llOwnerSay("Region currently has experiences disabled");
        if(reason == XP_ERROR_NO_EXPERIENCE) return llOwnerSay("This script is not accociated with an experience");
        if(reason == XP_ERROR_NOT_FOUND) return llOwnerSay("The sim was unable to verify the validity of the experience");
        if(reason == XP_ERROR_INVALID_EXPERIENCE) return llOwnerSay("The script is associated with an experience that no longer exists");
        if(reason == XP_ERROR_EXPERIENCE_DISABLED) return llOwnerSay("The experience owner has temporarily disabled the experience");
        if(reason == XP_ERROR_EXPERIENCE_SUSPENDED) return llOwnerSay("The experience has been suspended by Linden Lab customer support");
        if(reason == XP_ERROR_UNKNOWN_ERROR) return llOwnerSay("An unknown error not covered by any of the other predetermined error states");
        if(reason == XP_ERROR_MATURITY_EXCEEDED) return llOwnerSay("The content rating of the experience exceeds that of the region");
        if(reason == XP_ERROR_NOT_PERMITTED_LAND) return llOwnerSay("The experience is blocked or not enabled for this land");
        if(reason == XP_ERROR_REQUEST_PERM_TIMEOUT) return llOwnerSay("The request for experience permissions was ignored by secondlife:///app/agent/" + (string)agent + "/inspect");
        if(reason == XP_ERROR_NOT_PERMITTED)
        {
            llRegionSayTo(agent, PUBLIC_CHANNEL, "If you are a combat participant you must accept the experience or refrain from combat.\n\nIf you engage in combat without an experience you may be asked to leave or be removed");
        }
        
        llMessageLinked(LINK_THIS, MESSAGE_EXPERIENCE_DENIED, (string)reason, agent);
    }
}
