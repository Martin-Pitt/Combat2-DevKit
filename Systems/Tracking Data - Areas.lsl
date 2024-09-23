// Common: https://github.com/Martin-Pitt/LSL
#include "Common/utilities.lsl"
#include "Common/geometric.lsl"

// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#define TRACKING_SERVER
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/tracking.lsl"




// Completely customise this function to your needs, just simply return a string for the area based on the pos, or just return a single string if you cover the whole sim
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
        llSetTimerEvent(1.0);
    }
    
    link_message(integer sender, integer value, string text, key identifier)
    {
        if(value == MESSAGE_PRECHECK)
        {
            string agent = identifier;
            vector agentPos = llList2Vector(llGetObjectDetails(agent, [OBJECT_POS]), 0);
            string area = withinArea(agentPos);
            
            llLinksetDataWrite(agent + "_area", area);
            
            llMessageLinked(LINK_THIS, MESSAGE_PRECHECKED, "[\"area\"]", agent);
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
            
            
            string area = llLinksetDataRead(agent + "_area");
            vector agentPos = llList2Vector(llGetObjectDetails(agent, [OBJECT_POS]), 0);
            string currentArea = withinArea(agentPos);
            
            if(currentArea != area)
            {
                llLinksetDataWrite(agent + "_area", currentArea);
                llMessageLinked(LINK_THIS, MESSAGE_DELTA, "[\"area\"]", agent);
            }
            
            @continue;
        }
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
}
