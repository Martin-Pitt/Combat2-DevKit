// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#define TRACKING_SERVER
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/tracking.lsl"

// Change this to the name of your experience that this script was set to
#define EXPERIENCE_NAME "Combat2 Respawns"


default
{
    state_entry()
    {
        llSetTimerEvent(1.0);
    }
    
    link_message(integer sender, integer value, string text, key identifier)
    {
        if(value == MESSAGE_EXPERIENCE_REQUEST && text == EXPERIENCE_NAME)
        {
            llRequestExperiencePermissions(identifier, "");
        }
        
        else if(value == MESSAGE_PRECHECK)
        {
            string agent = identifier;
            list experiences = llJson2List(llLinksetDataRead(agent + "_experiences"));
            integer inExperience = llAgentInExperience(agent);
            integer hasExperience = llListFindList(experiences, [EXPERIENCE_NAME]) != -1;
            
            // Add experience
            if(inExperience && !hasExperience)
            {
                experiences += EXPERIENCE_NAME;
                llLinksetDataWrite(agent + "_experiences", llList2Json(JSON_ARRAY, experiences));
            }
            
            // Remove experience
            else if(!inExperience && hasExperience)
            {
                integer pointer = llListFindList(experiences, [EXPERIENCE_NAME]);
                experiences = llDeleteSubList(experiences, pointer, pointer);
                llLinksetDataWrite(agent + "_experiences", llList2Json(JSON_ARRAY, experiences));
            }
            
            llMessageLinked(LINK_SET, MESSAGE_PRECHECKED, "[\"experiences\"]", agent);
        }
    }
    
    timer()
    {
        string currentRegion = llGetRegionName();
        list Tracked = llJson2List(llLinksetDataRead("tracked"));
        integer iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            string agent = llList2Key(Tracked, iterator);
            string region = llLinksetDataRead(agent + "_region");
            if(region != currentRegion) jump continue;
            
            // The agent could be in limbo
            if(llGetAgentSize(agent) == ZERO_VECTOR
            || llGetAnimation(agent) == ""
            || llKey2Name(agent) == "") jump continue;
            
            
            list experiences = llJson2List(llLinksetDataRead(agent + "_experiences"));
            integer inExperience = llAgentInExperience(agent);
            integer hasExperience = llListFindList(experiences, [EXPERIENCE_NAME]) != -1;
            
            // Add experience
            if(inExperience && !hasExperience)
            {
                experiences += EXPERIENCE_NAME;
                llLinksetDataWrite(agent + "_experiences", llList2Json(JSON_ARRAY, experiences));
                llMessageLinked(LINK_SET, MESSAGE_DELTA, "[\"experiences\"]", agent);
            }
            
            // Remove experience
            else if(!inExperience && hasExperience)
            {
                integer pointer = llListFindList(experiences, [EXPERIENCE_NAME]);
                experiences = llDeleteSubList(experiences, pointer, pointer);
                llLinksetDataWrite(agent + "_experiences", llList2Json(JSON_ARRAY, experiences));
                llMessageLinked(LINK_SET, MESSAGE_DELTA, "[\"experiences\"]", agent);
            }
            
            @continue;
        }
    }
    
    experience_permissions(key agent)
    {
        // Write experiences into LSD
        list experiences = llJson2List(llLinksetDataRead((string)agent + "_experiences"));
        experiences += EXPERIENCE_NAME;
        llLinksetDataWrite((string)agent + "_experiences", llList2Json(JSON_ARRAY, experiences));
        
        // Event message to the tracking channel
        llMessageLinked(LINK_SET, MESSAGE_SEND, llList2Json(JSON_OBJECT, [
            "type", "experience-accepted",
            "agent", agent,
            "experience", EXPERIENCE_NAME
        ]), "");
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        // Event message to the tracking channel
        llMessageLinked(LINK_SET, MESSAGE_SEND, llList2Json(JSON_OBJECT, [
            "type", "experience-denied",
            "agent", agent,
            "experience", EXPERIENCE_NAME,
            "reason", llGetExperienceErrorMessage(reason)
        ]), "");
    }
    
    changed(integer change)
    {
        if(change & (CHANGED_REGION_START | CHANGED_REGION))
        {
            llSleep(0.25);
            llResetScript();
        }
    }
}
