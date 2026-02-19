/*
    Flexible Experience-based Combat System
    
    Allows other objects to programmatically control the respawning mechanics for combat via the experience HUD
    
    ---
    
    Possible system implementations:
    * Basic - the original, defense and raid teams with a fixed respawn point
    * Multi - Builds on original with multiple respawn points to spice up combat a bit
    * Rush - Fast-paced team deathmatch with the spawn points moving with the team location
    * Medic - Players are knocked down instead of dying and can be revived by teammates or choose where they want to respawn
    * Conquest - Spawn points picked from closest owned territory, encouraging teams to fight for control of the map
    * Drop - Players drop via aurbisal conjunctions / orbital drop pods
    * Reinforcement - Players spawn in groups into temporary armored transport vehicles they can drive into combat with
    * Contested - Spawn via closest team spawn points that are not contested, a kind of soft/organic territorial control purely through actual presence
    * Frontline - Spawn points are placed at frontline of combat, moving with the tug of war across the map
    * Overview - Similar to Medic but you are thrown directly to the respawn map to pick your spawn location
    * Round - Combat is split into rounds where its down to the last member of the team, entire teams are respawned at the start of a round
    * Squads - Teams are split into small squads, squadmates can spawn on eachother, markers track position onscreen, HUD shows squad status
    
    
    Spawning is controlled for each system as defined starting with the HUD attachment.
    So that means, to switch the combat system on the fly all we have to do is swap out the HUD.
    
    Therefore we just have to handoff the responsibility of the HUD to the active combat system
    and all we have to do here is doing the agent and experience permission tracking
*/

#include "Combat2-DevKit/Combat2-Polyfill.lsl"

#define FLECS_SYSTEM_CHANNEL -1
#define FLECS_HUD_CHANNEL -2

list Tracked;
list Active;
string RespawnSystem;

integer hasFreeAttachmentSlot(key agent)
{
    return llList2Integer(llGetObjectDetails(agent, [OBJECT_ATTACHED_SLOTS_AVAILABLE]), 0) > 0;
}

Debug(string log)
{
    llOwnerSay(log);
}

string GetAgentStatus(key agent)
{
    return llLinksetDataRead("FLECS." + (string)agent + "_status");
}

SetAgentStatus(key agent, string status)
{
    string statusKey = "FLECS." + (string)agent + "_status";
    string prevStatus = llLinksetDataRead(statusKey);
    if(prevStatus == status) return;
    
    llLinksetDataWrite(statusKey, status);
    Debug("secondlife:///app/agent/" + string(agent) + "/inspect: " + status);
    
    if(status == "active")
    {
        Active += agent;
        // llSetTeam(agent, 0); // Default to unassigned team
        // llSleep(0.25);
        // There are some race conditions with the sync, so lets leave it to the active system to assign team on new agents
        
        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
            "type", "added-agent",
            "agent", agent
        ]));
    }
    else if(prevStatus == "active")
    {
        integer pointer = llListFindList(Active, [agent]);
        if(pointer != -1) Active = llDeleteSubList(Active, pointer, pointer);
        
        // Cleanup team assignment
        string team = llLinksetDataRead("C2_Teams:" + (string)agent);
        list members = llJson2List(llLinksetDataRead("C2_Teams." + team));
        pointer = llListFindList(members, [(string)agent]);
        if(pointer != -1)
        {
            members = llDeleteSubList(members, pointer, pointer);
            llLinksetDataWrite("C2_Teams." + team, llList2Json(JSON_ARRAY, members));
        }
        llLinksetDataDelete("C2_Teams:" + (string)agent);
        
        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
            "type", "dropped-agent",
            "agent", agent
        ]));
    }
    llLinksetDataWrite("FLECS_Agents", llList2Json(JSON_ARRAY, Active));
}


default
{
    state_entry()
    {
        llResetOtherScript("FLECS Config");
        llSleep(1.0);
        llListen(FLECS_SYSTEM_CHANNEL, "", NULL_KEY, "");
        llSetTimerEvent(1.0);
        llLinksetDataDeleteFound("^FLECS", "");
        
        RespawnSystem = llLinksetDataRead("ActiveSystem");
        if(RespawnSystem == "")
        {
            llLinksetDataWrite("ActiveSystem", RespawnSystem = "Basic");
            llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                "type", "change-system",
                "name", RespawnSystem
            ]));
        }
        else
        {
            llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                "type", "active-system",
                "name", RespawnSystem
            ]));
        }
        
        llRegionSay(FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
            "type", "detach"
        ]));
        
        llOwnerSay("Initialised system to: " + RespawnSystem);
    }
    
    timer()
    {
        //*
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        /*
        list agents = [
            (key)"75078730-ebc8-4a80-adb9-1cfd2d95b5ca", // Nexii Malthus
            (key)"814081ed-3f16-411b-af21-5897eb9b803e", // Kaira Overdrive
            (key)"6f37a320-820e-426f-9e5c-716700e65afc", // Soap Frenzy
            (key)"933e5bd9-8501-4d31-ba68-c940437df3b4" // Too Smart
        ];
        integer t = llGetListLength(agents);
        while(t-->0)
        {
            string agent = llList2String(agents, t);
            if(llKey2Name(agent) == "") agents = llDeleteSubList(agents, t, t);
        }//*/
        
        integer iterator = llGetListLength(agents);
        
        while(iterator --> 0)
        {
            string agent = llList2String(agents, iterator);
            
            // Check if agent is valid (not a ghost, finished logging/crossing etc)
            // otherwise we can end up with a bunch of issues, such as being unable to request
            // experience permissions or with temp attaching the HUD
            if(agent == NULL_KEY) jump continue;
            
            string status = GetAgentStatus(agent);
            
            // Before we move on, check if agent is really present
            if(status == "")
            {
                string animation = llGetAnimation(agent);
                if(animation == "" || animation == "init") jump continue;
                
                string legacyName = llKey2Name(agent);
                if(legacyName == "") jump continue; // Ghosted avatars have an empty string
                
                list attachments = llGetAttachedList(agent);
                if(llGetListLength(attachments) == 0) jump continue; // Not finished logging in, teleporting in or crossing
                
                SetAgentStatus(agent, status = "arrived");
            }
            
            // Is the agent new?
            integer needle = llListFindList(Tracked, [(key)agent]);
            if(needle == -1)
            {
                // New agent
                Tracked += (key)agent;
                Debug("Tracking new agent secondlife:///app/agent/" + agent + "/inspect");
            }
            
            if(status == "arrived")
            {
                if(llAgentInExperience(agent))
                {
                    SetAgentStatus(agent, "experienced");
                }
                else
                {
                    list details = llGetExperienceDetails(NULL_KEY);
                    string experience = llList2Key(details, 2);
                    llRegionSayTo(agent, PUBLIC_CHANNEL, "This combat region uses an experience to help with respawning combatants. For details of the experience see: secondlife:///app/experience/" + experience + "/profile");
                    llRequestExperiencePermissions(agent, "");
                    SetAgentStatus(agent, "requested");
                }
            }
            
            else if(status == "denied")
            {
                if(llAgentInExperience(agent))
                {
                    // User had manually enabled the experience after denying/ignoring
                    SetAgentStatus(agent, "experienced");
                }
            }
            
            else if(status == "experienced" || status == "active")
            {
                string hudKey = "FLECS." + agent + "_hud";
                
                if(!llAgentInExperience(agent))
                {
                    // User had manually disabled the experience after accepting
                    llRegionSayTo(agent, FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
                        "type", "detach"
                    ]));
                    list details = llGetExperienceDetails(NULL_KEY);
                    string experience = llList2Key(details, 2);
                    llRegionSayTo(agent, PUBLIC_CHANNEL, "By disabling the experience, you cannot use the combat system in this region. If you die, you will be teleported home. For details of the experience and whether to allow it manually see: secondlife:///app/experience/" + experience + "/profile");
                    SetAgentStatus(agent, "denied");
                    llLinksetDataWrite(hudKey, "");
                    Debug("Agent secondlife:///app/agent/" + agent + "/inspect disabled experience");
                    jump continue;
                }
                
                
                string hud = llLinksetDataRead(hudKey);
                if(hud == "rezzing")
                {
                    // Still waiting for HUD to be rezzed, do nothing for now
                    // Debug("Waiting for HUD to be rezzed");
                }
                
                else if(hud == "no-slots")
                {
                    // No free attachment slots, notify user to clear some space
                    if(hasFreeAttachmentSlot(agent))
                    {
                        llLinksetDataWrite(hudKey, "");
                        Debug("Agent secondlife:///app/agent/" + agent + "/inspect now has free attachment slots");
                    }
                }
                
                else if(hud)
                {
                    string hudName = llKey2Name(hud);
                    if(hudName == "")
                    {
                        // HUD is missing
                        list otherHUDs = llGetAttachedListFiltered(agent, [
                            FILTER_INCLUDE, ATTACH_ANY_HUD,
                            FILTER_FLAGS, FILTER_FLAG_HUDS
                        ]);
                        llRegionSayTo(agent, FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
                            "type", "detach"
                        ]));
                        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                            "system", RespawnSystem,
                            "type", "attach-hud",
                            "agent", agent
                        ]));
                        llLinksetDataWrite(hudKey, "rezzing");
                        if(llGetListLength(otherHUDs))
                             Debug("HUD is missing but found " + (string)llGetListLength(otherHUDs) + " other attachments secondlife:///app/agent/" + agent + "/inspect");
                        else Debug("HUD is missing secondlife:///app/agent/" + agent + "/inspect");
                    }
                    
                    else
                    {
                        list details = llGetObjectDetails(hud, [OBJECT_ATTACHED_POINT]);
                        integer attachPoint = llList2Integer(details, 0);
                        if(attachPoint && status == "experienced")
                        {
                            SetAgentStatus(agent, "active");
                        }
                        
                        else if(attachPoint == 0 && status == "active")
                        {
                            SetAgentStatus(agent, "experienced");
                        }
                    }
                }
                
                else
                {
                    // No HUD attached
                    list otherHUDs = llGetAttachedListFiltered(agent, [
                        FILTER_INCLUDE, ATTACH_ANY_HUD,
                        FILTER_FLAGS, FILTER_FLAG_HUDS
                    ]);
                    llRegionSayTo(agent, FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
                        "type", "detach"
                    ]));
                    
                    if(hasFreeAttachmentSlot(agent))
                    {
                        llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                            "system", RespawnSystem,
                            "type", "attach-hud",
                            "agent", agent
                        ]));
                        llLinksetDataWrite(hudKey, "rezzing");
                        
                        if(llGetListLength(otherHUDs))
                             Debug("No HUD attached but found " + (string)llGetListLength(otherHUDs) + " other attachments secondlife:///app/agent/" + agent + "/inspect");
                        else Debug("No HUD attached secondlife:///app/agent/" + agent + "/inspect");
                    }
                    
                    else
                    {
                        llLinksetDataWrite(hudKey, "no-slots");
                        llRegionSayTo(agent, PUBLIC_CHANNEL, "You have no free attachment points, please unequip something and try again otherwise you cannot use the combat system in this region.");
                        Debug("No free attachment slots for secondlife:///app/agent/" + agent + "/inspect");
                    }
                }
            }
            
            @continue;
        }
        
        
        // Check for any agents that have left and cleanup if so
        iterator = llGetListLength(Tracked);
        while(iterator --> 0)
        {
            string agent = llList2String(Tracked, iterator);
            if(llListFindList(agents, [(key)agent]) == -1)
            {
                // Agent is gone
                Tracked = llDeleteSubList(Tracked, iterator, iterator);
                llLinksetDataDeleteFound("^FLECS\." + agent, "");
                integer pointer = llListFindList(Active, [agent]);
                if(pointer != -1) Active = llDeleteSubList(Active, pointer, pointer);
                llLinksetDataWrite("FLECS_Agents", llList2Json(JSON_ARRAY, Active));
                Debug("Stopped tracking agent secondlife:///app/agent/" + agent + "/inspect");
            }
        }
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        string type = llJsonGetValue(message, ["type"]);
        if(type == JSON_INVALID) return;
        
        if(type == "change-system")
        {
            RespawnSystem = llJsonGetValue(message, ["name"]);
            llLinksetDataWrite("ActiveSystem", RespawnSystem);
            llRegionSay(FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                "type", "active-system",
                "name", RespawnSystem
            ]));
            llRegionSay(FLECS_HUD_CHANNEL, llList2Json(JSON_OBJECT, [
                "type", "detach"
            ]));
            Debug("Changed system to: " + RespawnSystem);
        }
        
        else if(type == "check-active-system")
        {
            llRegionSayTo(identifier, FLECS_SYSTEM_CHANNEL, llList2Json(JSON_OBJECT, [
                "type", "active-system",
                "name", RespawnSystem
            ]));
        }
        
        else if(type == "rezzed-hud")
        {
            string system = llJsonGetValue(message, ["system"]);
            if(system != RespawnSystem) return;
            
            string hud = llJsonGetValue(message, ["hud"]);
            string agent = llJsonGetValue(message, ["agent"]);
            
            llLinksetDataWrite("FLECS." + agent + "_hud", hud);
            Debug("HUD rezzed secondlife:///app/agent/" + agent + "/inspect");
        }
    }
    
    experience_permissions(key agent)
    {
        SetAgentStatus(agent, "experienced");
        Debug("Has experience secondlife:///app/agent/" + string(agent) + "/inspect");
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        // Debug("experience_permissions_denied(secondlife:///app/agent/" + string(agent) + "/inspect, [" + (string)reason + "] " + llGetExperienceErrorMessage(reason) + ")");
        
        if(reason != XP_ERROR_REQUEST_PERM_TIMEOUT && reason != XP_ERROR_NOT_PERMITTED) return;
        if(llListFindList(Tracked, [agent]) == -1)
        {
            Debug("Agent secondlife:///app/agent/" + string(agent) + "/inspect denied experience permissions but is not being tracked");
            return; // Not tracking this agent, ignore
        }
        
        list details = llGetExperienceDetails(NULL_KEY);
        string experience = llList2Key(details, 2);
        llRegionSayTo(agent, PUBLIC_CHANNEL, "By declining the experience, you cannot use the combat system in this region. If you die, you will be teleported home. For details of the experience and whether to allow it manually see: secondlife:///app/experience/" + experience + "/profile");
        Debug("Agent secondlife:///app/agent/" + string(agent) + "/inspect denied experience permissions");
        
        SetAgentStatus(agent, "denied");
    }
}
