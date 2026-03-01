// https://github.com/Martin-Pitt/NexiiLSL
#include "NexiiLSL/linkset.lsl"
#include "NexiiLSL/damage-types.lsl"

// https://github.com/Martin-Pitt/NexiiUI
#include "NexiiUI/progress-bar.lsl"

#define EVENT_CHANNEL (COMBAT_CHANNEL - 10)

#define PERMISSIONS PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS | PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA

#define SCREEN_FPS <0,0,-1>
#define SCREEN_DOWN <0,0,0>
#define SCREEN_REDEPLOY <0,0,-2>

list RespawnPoints;
string DownAnimation;
list DownAnimations = [
    "Crouch Death",
    "dead 1",
    "dead 2",
    "Death",
    "Death From The Back",
    "Death From The Front",
    "Dying 1",
    "Dying 2",
    "Dying 5",
    "Dying 6"
];

integer LinkProgress;
integer LinkIcon;
integer LinkStruggle;
integer LinkRedeploy;

float DownTime;
integer DownStruggle;
#define DOWN_TIMER 0.25
#define DOWN_TIME 6.0
#define DOWN_STRUGGLE 0.3

key Reviving = NULL_KEY;
key Medic = NULL_KEY;
float ReviveTime;
#define REVIVE_TIMER 0.25
#define REVIVE_TIME 4.0

integer Tick;

////////////////////////////////////////////////////////////////////////////////////////////////////
default
{
    state_entry()
    {
        vector pos = llGetPos();
        RespawnPoints = [
            (key)"e387aa51-1ee4-715a-3660-b8ec2424cdd7",
            <32, 32, pos.z>,
            <224, 224, pos.z>,
            <160, 96, pos.z>
        ];
        
        LinksetScan(
            if(linkName == "Down Progress") LinkProgress = link;
            else if(linkName == "Down Icon") LinkIcon = link;
            else if(linkName == "Struggle") LinkStruggle = link;
            else if(linkName == "Redeploy") LinkRedeploy = link;
        );
        LinksetResourceSetup("RespawnDotsFree", "Respawn");
        LinksetResourceReset("RespawnDotsFree", [PRIM_POS_LOCAL, <0,0,3>]);
        
        if(llGetAttached()) llRequestExperiencePermissions(llGetOwner(), "");
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    attach(key agent) { if(agent) llRequestExperiencePermissions(agent, ""); }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    run_time_permissions(integer permissions) { state down; }
    experience_permissions(key agent) { state down; }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    changed(integer change) { if(change & CHANGED_OWNER) llResetScript(); }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
state alive
{
    state_entry()
    {
        llOwnerSay("@clear");
        llTakeControls(0, FALSE, TRUE);
        llStopAnimation(DownAnimation);
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [PRIM_POSITION, SCREEN_FPS]);
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    on_death()
    {
        llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
            "event", "DOWN",
            "time", llGetTimestamp(),
            "position", llGetPos()
        ]));
        state down;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    changed(integer change) { if(change & CHANGED_OWNER) llResetScript(); }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
state down
{
    state_entry()
    {
        llOwnerSay("Downed");
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [
            PRIM_POSITION, SCREEN_DOWN,
            PRIM_LINK_TARGET, LinkIcon, PRIM_TEXTURE, 4] + DamageTypeAsIcon(-106) + [
            PRIM_LINK_TARGET, LinkProgress] + progressBar(1.0, 0.0, 1.0) + [
            PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, 0, -.2>,
            PRIM_COLOR, 0, <1, 1, 1>, 1,
            PRIM_LINK_TARGET, LinkStruggle,
            PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, 0.3, -.2>,
            PRIM_COLOR, 4, <0,0,0>, 0.7,
            PRIM_LINK_TARGET, LinkRedeploy,
            PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, -.3, -.2>
        ]);
        llSetObjectDesc(llList2Json(JSON_OBJECT, []));
        
        DownAnimation = llList2String(DownAnimations, llFloor(llFrand(llGetListLength(DownAnimations))));
        llStartAnimation(DownAnimation);
        
        llTakeControls(0, FALSE, FALSE);
        llOwnerSay("@camdistmin:5=n");
        llOwnerSay("@setsphere=n,setsphere_mode:0=force,setsphere_param:0.2/0.2/0.2/0=force,setsphere_distmin:32=force,setsphere_distmax:64=force,setsphere_valuemin:0=force,setsphere_valuemax:0=force,setsphere_tween:2.0=force");
        llOwnerSay("@setsphere=n,setsphere_mode:0=force,setsphere_param:0.06/0.06/0.06/0=force,setsphere_distmin:2=force,setsphere_distmax:24=force,setsphere_valuemin:0=force,setsphere_valuemax:0.85=force,setsphere_tween:0.1=force");
        
        DownTime = DOWN_TIME;
        llSetTimerEvent(0.5);
        llListen(EVENT_CHANNEL, "", "", "");
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    state_exit()
    {
        llSetTimerEvent(FALSE);
        llSetObjectDesc(llList2Json(JSON_OBJECT, []));
        llStopMoveToTarget();
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    touch_start(integer total_number)
    {
        integer link = llDetectedLinkNumber(0);
        string name = llGetLinkName(link);
        
        if(name == "Redeploy")
        {
            llOwnerSay("Redeploying");
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "DEAD",
                "time", llGetTimestamp(),
                "position", llGetPos()
            ]));
            state deploy;
        }
        
        else if(name == "Struggle")
        {
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "MEDIC_REQUEST",
                "time", llGetTimestamp(),
                "position", llGetPos()
            ]));
            DownStruggle = TRUE;
            llSetLinkPrimitiveParamsFast(LinkStruggle, [
                PRIM_COLOR, 4, <0, 0.25, 0.5>, 0.7
            ]);
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    touch_end(integer total_number)
    {
        integer link = llDetectedLinkNumber(0);
        string name = llGetLinkName(link);
        
        if(name == "Struggle")
        {
            DownStruggle = FALSE;
            llSetLinkPrimitiveParamsFast(LinkStruggle, [
                PRIM_COLOR, 4, <0, 0, 0>, 0.3
            ]);
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    timer()
    {
        ++Tick;
        
        if(Medic)
        {
            float delta = REVIVE_TIMER;
            ReviveTime += delta;
            if(ReviveTime > REVIVE_TIME) ReviveTime = REVIVE_TIME;
            
            llSetLinkPrimitiveParamsFast(LinkProgress, progressBar(ReviveTime, delta, REVIVE_TIME));
            llSetObjectDesc(llList2Json(JSON_OBJECT, ["r", ReviveTime]));
            
            if(ReviveTime >= REVIVE_TIME)
            {
                llOwnerSay("Revived");
                llDamage(llGetOwner(), -100, DAMAGE_TYPE_RESPAWN);
                llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                    "event", "REVIVE_DONE",
                    "time", llGetTimestamp(),
                    "position", llGetPos(),
                    "medic", Medic
                ]));
                Medic = NULL_KEY;
                state alive;
            }
            
            else
            {
                list details = llGetObjectDetails(Medic, [OBJECT_POS, OBJECT_ROT]);
                vector medicPos = llList2Vector(details, 0);
                vector delta = medicPos - llGetPos();
                float distance = llVecMag(delta);
                
                if(distance > 8.0)
                {
                    // Too far, cancel revive
                    llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                        "event", "REVIVE_STOP",
                        "time", llGetTimestamp(),
                        "position", llGetPos(),
                        "medic", Medic
                    ]));
                    Medic = NULL_KEY;
                    llSetLinkPrimitiveParamsFast(0, [
                        PRIM_LINK_TARGET, LinkIcon, PRIM_TEXTURE, 4] + DamageTypeAsIcon(-108) + [
                        PRIM_LINK_TARGET, LinkProgress] + progressBar(ReviveTime, 0.0, REVIVE_TIME) + [
                        PRIM_COLOR, 0, <1, 1, 1>, 1,
                        PRIM_LINK_TARGET, LinkStruggle, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, 0.3, -.2>,
                        PRIM_LINK_TARGET, LinkRedeploy, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, -.3, -.2>
                    ]);
                    return;
                }
                
                else if(distance > 1.2)
                {
                    vector direction = llVecNorm(delta);
                    llSetAgentRot(llRotBetween(<1,0,0>, -direction), 0);
                    // llSetVelocity(direction * 6.0, FALSE);
                    llMoveToTarget(llGetPos() + direction, 1.0);
                }
                
                else
                {
                    llStopMoveToTarget();
                }
            }
        }
        
        else
        {
            integer beat = FALSE;
            float delta = DOWN_TIMER;
            if(DownStruggle)
            {
                delta *= DOWN_STRUGGLE;
                beat = Tick/2 % 2;
            }
            else beat = Tick % 2;
            DownTime -= delta;
            if(DownTime < 0.0) DownTime = 0.0;
            
            llSetLinkPrimitiveParamsFast(LinkIcon, [
                PRIM_TEXTURE, 4] + DamageTypeAsIcon(-106 - beat) + [
                PRIM_LINK_TARGET, LinkProgress] + progressBar(DownTime, -delta, DOWN_TIME)
            );
            
            if(DownTime <= 0.0)
            {
                llOwnerSay("Dead");
                llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                    "event", "DEAD",
                    "time", llGetTimestamp(),
                    "position", llGetPos()
                ]));
                state deploy;
            }
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    listen(integer channel, string name, key identifier, string message)
    {
        string eventName = llJsonGetValue(message, ["event"]);
        if(eventName != "MEDIC_START"
        && eventName != "MEDIC_CANCEL") return; // Not a medic event
        
        key target = llJsonGetValue(message, ["target"]);
        if(target != llGetOwner()) return; // Not aimed at our owner
        key source = identifier; // llGetOwnerKey(identifier);
        
        if(eventName == "MEDIC_START")
        {
            if(Medic) return; // Already have a Medic
            if(Medic == source) return; // Already reviving
            
            vector sourcePos = llList2Vector(llGetObjectDetails(source, [OBJECT_POS]), 0);
            if(llVecDist(llGetPos(), sourcePos) > 10.0) return; // Too far
            
            // Start reviving
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "REVIVE_START",
                "time", llGetTimestamp(),
                "position", llGetPos(),
                "medic", Medic = source
            ]));
            ReviveTime = 0.0;
            llSetLinkPrimitiveParamsFast(0, [
                PRIM_LINK_TARGET, LinkIcon, PRIM_TEXTURE, 4] + DamageTypeAsIcon(-108) + [
                PRIM_LINK_TARGET, LinkProgress] + progressBar(ReviveTime, 0.0, REVIVE_TIME) + [
                PRIM_COLOR, 0, <0.1, 0.6, 0.1>, 1,
                PRIM_LINK_TARGET, LinkStruggle, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, 0.3, -.6>,
                PRIM_LINK_TARGET, LinkRedeploy, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, -.3, -.6>
            ]);
        }
        
        else if(eventName == "MEDIC_CANCEL")
        {
            if(Medic == NULL_KEY) return; // Nothing to stop
            if(Medic != source) return // Not from medic
            
            // Revival was cancelled
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "REVIVE_STOP",
                "time", llGetTimestamp(),
                "position", llGetPos(),
                "medic", Medic
            ]));
            Medic = NULL_KEY;
            llSetLinkPrimitiveParamsFast(0, [
                PRIM_LINK_TARGET, LinkIcon, PRIM_TEXTURE, 4] + DamageTypeAsIcon(-108) + [
                PRIM_LINK_TARGET, LinkProgress] + progressBar(ReviveTime, 0.0, REVIVE_TIME) + [
                PRIM_COLOR, 0, <1, 1, 1>, 1,
                PRIM_LINK_TARGET, LinkStruggle, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, 0.3, -.2>,
                PRIM_LINK_TARGET, LinkRedeploy, PRIM_POS_LOCAL, SCREEN_DOWN + <-.2, -.3, -.2>
            ]);
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
state deploy
{
    state_entry()
    {
        llOwnerSay("@clear");
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [PRIM_POSITION, SCREEN_REDEPLOY]);
        
        vector pos = llGetPos();
        vector camPos = <128 + 160, 128 + 160, pos.z + 192>;
        vector camFocus = <128 + 32, 128 + 32, pos.z>;
        
        llSetCameraParams([
            CAMERA_ACTIVE, TRUE,
            CAMERA_FOCUS, camFocus,
            CAMERA_FOCUS_LOCKED, TRUE,
            CAMERA_POSITION, camPos,
            CAMERA_POSITION_LOCKED, TRUE
        ]);
        
        list params;
        integer iterator = llGetListLength(RespawnPoints);
        while(iterator --> 0)
        {
            integer link = LinksetResourceUse("RespawnDotsFree", "RespawnDotsUsed");
            params += [PRIM_LINK_TARGET, link, PRIM_DESC, (string)iterator];
        }
        llSetLinkPrimitiveParamsFast(0, params);
        
        llSetTimerEvent(20/45.);
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    state_exit()
    {
        llStopAnimation(DownAnimation);
        LinksetResourceReset("RespawnDotsUsed", [PRIM_POS_LOCAL, <0,0,3>]);
        LinksetResourceFreeAll("RespawnDotsFree", "RespawnDotsUsed");
        llSetCameraParams([CAMERA_ACTIVE, FALSE]);
        llSetTimerEvent(FALSE);
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    timer()
    {
        llSetTimerEvent(10/45.);
        
        list params = [];
        
        string pool = llLinksetDataRead("RespawnDotsUsed");
        integer iterator = llGetListLength(RespawnPoints);
        while(iterator --> 0)
        {
            integer link = 1 + llOrd(pool, iterator);
            integer type = llGetListEntryType(RespawnPoints, iterator);
            if(type == TYPE_VECTOR)
            {
                vector point = llList2Vector(RespawnPoints, iterator);
                point = llWorldPosToHUD(point);
                
                params += [
                    PRIM_LINK_TARGET, link,
                    PRIM_POS_LOCAL, <0,0,2> + point,
                    PRIM_ROT_LOCAL, ZERO_ROTATION // / llGetCameraRot()
                ];
            }
            
            else if(type == TYPE_KEY)
            {
                key point = llList2Key(RespawnPoints, iterator);
                list details = llGetObjectDetails(point, [OBJECT_POS, OBJECT_ROT]);
                vector pos = llList2Vector(details, 0);
                rotation rot = llList2Rot(details, 1);
                pos = llWorldPosToHUD(pos);
                
                params += [
                    PRIM_LINK_TARGET, link,
                    PRIM_POS_LOCAL, <0,0,2> + pos,
                    PRIM_ROT_LOCAL, rot / llGetCameraRot()
                ];
            }
        }
        
        if(params) llSetLinkPrimitiveParamsFast(0, params);
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    touch_start(integer total_number)
    {
        integer link = llDetectedLinkNumber(0);
        string name = llGetLinkName(link);
        
        if(name == "Respawn")
        {
            integer index = (integer)((string)llGetLinkPrimitiveParams(link, [PRIM_DESC]));
            integer type = llGetListEntryType(RespawnPoints, index);
            vector point;
            if(type == TYPE_VECTOR) point = llList2Vector(RespawnPoints, index);
            else if(type == TYPE_KEY)
            {
                key object = llList2Key(RespawnPoints, index);
                list details = llGetObjectDetails(object, [OBJECT_POS, OBJECT_ROT]);
                point = llList2Vector(details, 0);
                llSetAgentRot(llList2Rot(details, 1), 0);
            }
            
            llTeleportAgent(llGetOwner(), "", point, ZERO_VECTOR);
            
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "RESPAWN",
                "time", llGetTimestamp(),
                "position", point
            ]));
            
            llDamage(llGetOwner(), -100, DAMAGE_TYPE_RESPAWN);
            
            state alive;
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////