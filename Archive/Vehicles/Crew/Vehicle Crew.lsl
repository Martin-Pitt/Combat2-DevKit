//
string Seating = "[
    {
        \"name\": \"Pilot\",
        \"agent\": null,
        \"position\": \"<1,0,0.194092>\"
    },
    {
        \"name\": \"Gunner\",
        \"agent\": null,
        \"position\": \"<-0.89,0,0.92>\"
    },
    {
        \"name\": \"Outrider Back\",
        \"agent\": null,
        \"position\": \"<-3.0397,0,0.062256>\",
        \"isExternal\": true
    },
    {
        \"name\": \"Outrider Left\",
        \"agent\": null,
        \"position\": \"<-1.847031,1.314011,0.256836>\",
        \"isExternal\": true
    },
    {
        \"name\": \"Outrider Right\",
        \"agent\": null,
        \"position\": \"<-1.847031,-1.314011,0.256836>\",
        \"isExternal\": true
    },
    {
        \"name\": \"Outrider Top\",
        \"agent\": null,
        \"position\": \"<-0.973229,0,2.349121>\",
        \"isExternal\": true
    }
]";
integer TotalSeats;

vector HatchPos = <1.25, 0, 1>;
vector HatchSize = <1.3, 1.1, 0.3>;


integer awaitingSeat = -1;
key awaitingAgent;

#define SIT_TIMEOUT 2.0
#define SIT_MAX_DISTANCE 5.0
#define SIT_EXTERNAL_DISTANCE 0.8

default
{
    state_entry()
    {
        TotalSeats = llGetListLength(llJson2List(Seating));
        HatchSize /= 2.0;
        
        llLinkSitTarget(LINK_SET, ZERO_VECTOR, ZERO_ROTATION);
        integer index = 0;
        for(; index < TotalSeats; ++index)
        {
            integer link = 1 + index;
            vector seatPos = (vector)llJsonGetValue(Seating, [index, "position"]);
            rotation seatRot = ZERO_ROTATION;
            integer isExternal = llJsonGetValue(Seating, [index, "isExternal"]) == JSON_TRUE;
            
            if(link != LINK_ROOT)
            {
                list details = llGetLinkPrimitiveParams(link, [PRIM_POS_LOCAL, PRIM_ROT_LOCAL]);
                vector linkPos = llList2Vector(details, 0);
                rotation linkRot = llList2Rot(details, 1);
                seatPos = (seatPos - linkPos) / linkRot;
                seatRot /= linkRot;
            }
            
            llLinkSitTarget(link, seatPos, seatRot);
            llSetLinkSitFlags(link, SIT_FLAG_ALLOW_UNSIT | SIT_FLAG_SCRIPTED_ONLY | SIT_FLAG_NO_COLLIDE | SIT_FLAG_NO_DAMAGE);
            
            
            key agentOnLink = llAvatarOnLinkSitTarget(link);
            if(agentOnLink)
            {
                Seating = llJsonSetValue(Seating, [index, "agent"], agentOnLink);
                llLinksetDataWrite("CREW_" + llJsonGetValue(Seating, [index, "name"]), agentOnLink);
            }
        }
        llLinksetDataWrite("SEATING", Seating);
        
        llSetClickAction(CLICK_ACTION_TOUCH);
        llSetStatus(STATUS_BLOCK_GRAB | STATUS_BLOCK_GRAB_OBJECT, TRUE);
    }
    
    touch_start(integer detected)
    {
        key agent = llDetectedKey(0);
        
        // TODO: Replace this with llDetectedTeam later
        key myGroup = (string)llGetObjectDetails(llGetKey(), [OBJECT_GROUP]);
        key agentGroup = (string)llGetObjectDetails(llList2Key(llGetAttachedList(agent), 1), [OBJECT_GROUP]);
        if(agent != llGetOwner() && myGroup != agentGroup) return;
        
        if(awaitingSeat != -1) {
            if(agent != awaitingAgent) llRegionSayTo(agent, PUBLIC_CHANNEL, "Please wait, another user has an open seat waiting for them");
            return;
        }
        
        vector agentPos = llDetectedPos(0);
        vector touchPos = llDetectedTouchPos(0);
        touchPos = (touchPos - llGetRootPosition()) / llGetRootRotation();
        
        integer freeSeat = -1;
        
        // Was the hatch clicked on
        vector tPos = touchPos - HatchPos;
        if(-HatchSize.x <= tPos.x && tPos.x <= HatchSize.x &&
           -HatchSize.y <= tPos.y && tPos.y <= HatchSize.y &&
           -HatchSize.z <= tPos.z && tPos.z <= HatchSize.z)
        {
            // Check if any internal seats are available
            integer index;
            for(index = 0; index < TotalSeats; ++index)
            {
                if(llJsonValueType(Seating, [index, "isExternal"]) != JSON_TRUE && llJsonValueType(Seating, [index, "agent"]) == JSON_NULL)
                {
                    freeSeat = index;
                    jump breakSeatCheck;
                }
            }
            @breakSeatCheck;
            
            if(freeSeat == -1)
            {
                llRegionSayTo(agent, PUBLIC_CHANNEL, "No internal seats available");
                return;
            }
            
            if(llVecDist(HatchPos * llGetRootRotation() + llGetRootPosition(), agentPos) > SIT_MAX_DISTANCE)
            {
                llRegionSayTo(agent, PUBLIC_CHANNEL, "Too far away to sit");
                return;
            }
        }
        
        else
        {
            integer index;
            for(index = 0; index < TotalSeats; ++index)
            {
                integer isExternal = llJsonValueType(Seating, [index, "isExternal"]) == JSON_TRUE;
                if(!isExternal) jump continueSeatCheck;
                
                vector seatPosition = (vector)llJsonGetValue(Seating, [index, "position"]);
                if(llVecDist(touchPos, seatPosition) > SIT_EXTERNAL_DISTANCE) jump continueSeatCheck;
                
                key agentOnSeat = llJsonGetValue(Seating, [index, "agent"]);
                if(agent == agentOnSeat) jump breakSeatCheck2; // Crew member clicked on their own seat
                if(agentOnSeat != JSON_NULL)
                    llRegionSayTo(agent, PUBLIC_CHANNEL, "Someone is already sitting here");
                
                else freeSeat = index;
                
                jump breakSeatCheck2;
                
                @continueSeatCheck;
            }
            @breakSeatCheck2;
            
            if(freeSeat != -1)
            {
                vector seatPosition = (vector)llJsonGetValue(Seating, [freeSeat, "position"]);
                if(llVecDist(seatPosition * llGetRootRotation() + llGetRootPosition(), agentPos) > SIT_MAX_DISTANCE)
                {
                    llRegionSayTo(agent, PUBLIC_CHANNEL, "Too far away to sit");
                    return;
                }
            }
        }
        
        if(freeSeat != -1)
        {
            integer link = 1 + freeSeat;
            integer hasExperience = llAgentInExperience(agent);
            
            // Check if they were already crew, and if so allow them to swap over to the new seat
            integer index;
            for(index = 0; index < TotalSeats; ++index)
            {
                key agentOnSeat = llJsonGetValue(Seating, [index, "agent"]);
                if(agent == agentOnSeat)
                {
                    Seating = llJsonSetValue(Seating, [index, "agent"], agent);
                    llLinksetDataWrite("CREW_" + llJsonGetValue(Seating, [index, "name"]), agent);
                    llLinksetDataWrite("SEATING", Seating);
                    if(!hasExperience) llUnSit(agent);
                }
            }
            
            // Sit the agent immediately as part of crew
            if(hasExperience)
            {
                llSitOnLink(agent, link);
                
                llRequestPermissions(agent, PERMISSION_TRIGGER_ANIMATION);
                llStopAnimation("sit");
                
                Seating = llJsonSetValue(Seating, [freeSeat, "agent"], agent);
                llLinksetDataWrite("CREW_" + llJsonGetValue(Seating, [freeSeat, "name"]), agent);
                llLinksetDataWrite("SEATING", Seating);
            }
            
            // In foreign regions we will need to use a delayed sit system to verify
            else
            {
                awaitingSeat = freeSeat;
                awaitingAgent = agent;
                llSetLinkSitFlags(link, SIT_FLAG_ALLOW_UNSIT | SIT_FLAG_NO_COLLIDE | SIT_FLAG_NO_DAMAGE);
                llSetClickAction(CLICK_ACTION_SIT);
                llSetTimerEvent(SIT_TIMEOUT);
                llRegionSayTo(agent, PUBLIC_CHANNEL, "Opened " + llJsonGetValue(Seating, [freeSeat, "name"]) + " seat, click again to sit");
            }
        }
    }
    
    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            integer index;
            for(; index < TotalSeats; ++index)
            {
                integer link = 1 + index;
                key agentOnSeat = llJsonGetValue(Seating, [index, "agent"]);
                key agentOnLink = llAvatarOnLinkSitTarget(link);
                
                // We are awaiting an agent for this seat
                if(index == awaitingSeat)
                {
                    // Agent becomes part of the crew
                    if(agentOnLink == awaitingAgent)
                    {
                        llRequestPermissions(agentOnLink, PERMISSION_TRIGGER_ANIMATION);
                        Seating = llJsonSetValue(Seating, [index, "agent"], agentOnLink);
                        llLinksetDataWrite("CREW_" + llJsonGetValue(Seating, [index, "name"]), agentOnLink);
                        llLinksetDataWrite("SEATING", Seating);
                        
                        llSetTimerEvent(FALSE);
                        llSetLinkSitFlags(1 + awaitingSeat, SIT_FLAG_ALLOW_UNSIT | SIT_FLAG_SCRIPTED_ONLY | SIT_FLAG_NO_COLLIDE | SIT_FLAG_NO_DAMAGE);
                        llSetClickAction(CLICK_ACTION_NONE);
                        awaitingSeat = -1;
                        awaitingAgent = NULL_KEY;
                    }
                    
                    // Unknown agent sat on the expected seat
                    else if(agentOnLink)
                    {
                        llUnSit(agentOnLink);
                    }
                }
                
                // Unknown agent on a seat
                else if(agentOnLink != NULL_KEY && agentOnSeat == JSON_NULL)
                {
                    llUnSit(agentOnLink);
                }
                
                // Crew member unsat
                else if(agentOnLink == NULL_KEY && agentOnSeat != JSON_NULL)
                {
                    Seating = llJsonSetValue(Seating, [index, "agent"], JSON_NULL);
                    llLinksetDataWrite("CREW_" + llJsonGetValue(Seating, [index, "name"]), "");
                    llLinksetDataWrite("SEATING", Seating);
                }
            }
        }
    }
    
    run_time_permissions(integer perm)
    {
        if(perm & PERMISSION_TRIGGER_ANIMATION) 
            llStopAnimation("sit");
    }
    
    // Timeout for seats we were expecting to be sat on
    timer()
    {
        llSetTimerEvent(FALSE);
        if(awaitingSeat == -1) return;
        
        llRegionSayTo(awaitingAgent, PUBLIC_CHANNEL, "Seat timed out");
        llSetLinkSitFlags(1 + awaitingSeat, SIT_FLAG_ALLOW_UNSIT | SIT_FLAG_SCRIPTED_ONLY | SIT_FLAG_NO_COLLIDE | SIT_FLAG_NO_DAMAGE);
        llSetClickAction(CLICK_ACTION_NONE);
        awaitingSeat = -1;
        awaitingAgent = NULL_KEY;
    }
}
