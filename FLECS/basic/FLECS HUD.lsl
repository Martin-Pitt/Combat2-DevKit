

#define SYSTEM_HUD_CHANNEL -1820510000
#define EVENT_HUD_REZZED 80 // [key agent]
#define EVENT_HUD_ATTACHED 81 // []; untrusted
#define EVENT_HUD_DETACHED 84 // []; untrusted
#define DETACH_HUD 82 // []
#define PREP_RESPAWN 83 // [key respawn]
list Battlefields = []; // Areas where combat is allowed
list Safezones = []; // Safe areas within the battlefields
key PreppedRespawn;
string RespawnName;
vector RespawnPos;
PrepareRespawnPoint()
{
    string respawnName = llKey2Name(PreppedRespawn);
    list details = llGetObjectDetails(PreppedRespawn, [OBJECT_POS, OBJECT_SCALE, OBJECT_ROT]);
    vector respawnPos = llList2Vector(details, 0);
    vector respawnScale = llList2Vector(details, 1);
    rotation respawnRot = llList2Rot(details, 2);
    vector spawnPoint = respawnPos + <
        (llFrand(1) - 0.5) * (respawnScale.x - 0.4),
        (llFrand(1) - 0.5) * (respawnScale.y - 0.4),
        0
    > * respawnRot;
    
    RespawnName = respawnName;
    RespawnPos = spawnPoint;
}

#define SYSTEM_COMBAT_CHANNEL -1820510001
#define RESPAWN_AGENT 100 // []; untrusted
#define AGENT_DEATH 101 // []; untrusted



integer target;
#define TARGET_RANGE 3.0

integer isDamageable;
integer inDamageableArea(vector pos) {
    integer a;
    integer b = llGetListLength(Battlefields);
    for(; a < b; a += 2)
    {
        vector min = llList2Vector(Battlefields, a);
        vector max = llList2Vector(Battlefields, a + 1);
        if(min.x <= pos.x && pos.x <= max.x &&
           min.y <= pos.y && pos.y <= max.y &&
           min.z <= pos.z && pos.z <= max.z)
        {
            integer c;
            integer d = llGetListLength(Safezones);
            for(; c < d; ++c)
            {
                string object = llList2String(Safezones, c);
                list details = llGetObjectDetails(object, [OBJECT_POS]);
                vector objectPos = llList2Vector(details, 0);
                list box = llGetBoundingBox(object);
                vector min = objectPos + llList2Vector(box, 0);
                vector max = objectPos + llList2Vector(box, 1);
                if(min.x <= pos.x && pos.x <= max.x &&
                   min.y <= pos.y && pos.y <= max.y &&
                   min.z <= pos.z && pos.z <= max.z)
                {
                    // Safezone within the Battlefield
                    return FALSE;
                }
            }
            
            // Battlefield
            return TRUE;
        }
    }
    
    // Not a battlefield
    return FALSE;
}

string owner;
string agent;


default
{
    on_rez(integer param)
    {
        if(!param) return;
        
        owner = llGetOwner();
        
        // Retrieve configuration
        string data = llGetStartString();
        Battlefields = llJson2List(llJsonGetValue(data, ["battlefields"]));
        Safezones = llJson2List(llJsonGetValue(data, ["safezones"]));
        agent = llJsonGetValue(data, ["agent"]);
        PreppedRespawn = llJsonGetValue(data, ["respawn"]);
        if(PreppedRespawn == JSON_INVALID) PreppedRespawn = NULL_KEY;
        else PrepareRespawnPoint();
        
        // Verification
        string error;
        if(data == "") error = "No data provided";
        else if(llGetListLength(Battlefields) == 0) error = "No battlefields provided";
        else if(llGetListLength(Safezones) == 0) error = "No safezones provided";
        else if(agent == "" || agent == JSON_INVALID) error = "No agent provided";
        if(error != "")
        {
            llOwnerSay("Error: " + error);
            llDie();
            return; // Cancel startup
        }
        
        // Typecast lists
        integer iterator = llGetListLength(Battlefields);
        while(iterator --> 0) Battlefields = llListReplaceList(Battlefields, [
            (vector)llList2String(Battlefields, iterator)
        ], iterator, iterator);
        
        // Startup
        llRequestExperiencePermissions(agent, "");
        llAttachToAvatarTemp(ATTACH_HUD_CENTER_2);
        llSetTimerEvent(30); // Self destruct
        llListen(SYSTEM_HUD_CHANNEL, "", "", "");
        llRegionSay(SYSTEM_HUD_CHANNEL, llChar(EVENT_HUD_REZZED) + agent);
    }
    
    timer()
    {
        if(llGetAgentSize(agent) == ZERO_VECTOR) llDie();
        if(!llGetAttached()) llDie();
    }
    
    not_at_target()
    {
        llTargetRemove(target);
        vector pos = llGetPos();
        target = llTarget(pos, TARGET_RANGE);
        isDamageable = inDamageableArea(pos);
    }
    
    attach(key attachee)
    {
        if(attachee)
        {
            llSetTimerEvent(FALSE);
            llTakeControls(CONTROL_DOWN, TRUE, TRUE);
            llRegionSay(SYSTEM_HUD_CHANNEL, llChar(EVENT_HUD_ATTACHED));
            target = llTarget(llGetPos(), TARGET_RANGE);
            isDamageable = inDamageableArea(llGetPos());
        }
    }
    
    experience_permissions_denied(key agent, integer reason)
    {
        if(llGetAttached())
        {
            llRegionSay(SYSTEM_HUD_CHANNEL, llChar(EVENT_HUD_DETACHED));
            llRequestPermissions(agent, PERMISSION_ATTACH);
            llDetachFromAvatar();
        }
        llDie();
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        integer isSameOwner = llGetOwnerKey(identifier) == owner;
        integer type = llOrd(message, 0);
        
        if(type == DETACH_HUD && isSameOwner)
        {
            if(llGetAttached())
            {
                llRegionSay(SYSTEM_HUD_CHANNEL, llChar(EVENT_HUD_DETACHED));
                llRequestPermissions(agent, PERMISSION_ATTACH);
                llDetachFromAvatar();
            }
            llDie();
        }
        
        else if(type == PREP_RESPAWN && isSameOwner)
        {
            PreppedRespawn = llGetSubString(message, 1, -1);
            PrepareRespawnPoint();
            // llRegionSayTo("75078730-ebc8-4a80-adb9-1cfd2d95b5ca", PUBLIC_CHANNEL, "PreppedRespawn set to " + llKey2Name(PreppedRespawn));
        }
    }
    
    on_damage(integer count)
    {
        if(isDamageable) return;
        while(count--) llAdjustDamage(count, 0);
    }
    
    on_death()
    {
        if(PreppedRespawn)
        {
            /*
            // Dynamic lookup:
            string respawnName = llKey2Name(PreppedRespawn);
            list details = llGetObjectDetails(PreppedRespawn, [OBJECT_POS, OBJECT_SCALE, OBJECT_ROT]);
            vector respawnPos = llList2Vector(details, 0);
            vector respawnScale = llList2Vector(details, 1);
            rotation respawnRot = llList2Rot(details, 2);
            vector spawnPoint = respawnPos + <
                (llFrand(1) - 0.5) * (respawnScale.x - 0.4),
                (llFrand(1) - 0.5) * (respawnScale.y - 0.4),
                0
            > * respawnRot;
            llOwnerSay("Died; Respawning at " + respawnName);
            llTeleportAgent(agent, "", spawnPoint, <128,128,0>);
            */
            
            // Fixed lookup:
            llTeleportAgent(agent, "", RespawnPos, <128,128,0>);
            llOwnerSay("Died; Respawning at " + RespawnName);
        }
        else llRegionSay(SYSTEM_COMBAT_CHANNEL, llChar(RESPAWN_AGENT));
        llRegionSay(SYSTEM_COMBAT_CHANNEL, llChar(AGENT_DEATH));
        if(PreppedRespawn) PrepareRespawnPoint(); // Recompute after teleport (Fixed lookup)
    }
}