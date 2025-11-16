// https://github.com/Martin-Pitt/Combat2-DevKit
#include "Combat2-DevKit/Combat2-Polyfill.lsl"

string DownAnimation;
list DownAnimations = ["Crouch Death", "dead 1", "dead 2", "Death", "Death From The Back", "Death From The Front", "Dying 1", "Dying 2", "Dying 5", "Dying 6"];

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
        llLinksetDataWrite("Screen", "Normal");
        llLinksetDataWrite("Down.Status", "");
        llLinksetDataWrite("Down.Progress", "1.0");
        llLinksetDataWrite("Revive.Progress", "0.0");
        if(llGetAttached()) llRequestExperiencePermissions(llGetOwner(), "");
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    attach(key agent) { if(agent) llRequestExperiencePermissions(agent, ""); }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    experience_permissions(key agent) {
        integer channel = (integer)("0x" + llGetSubString(llMD5String((string)llGetKey(), 5), 0, 4));
        llListen(channel, "", llGetOwner(), "");
        llOwnerSay("@versionnum=" + (string)channel);
        llSetTimerEvent(1.0);
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    experience_permissions_denied(key agent, integer reason)
    {
        if(reason == XP_ERROR_NOT_PERMITTED || reason == XP_ERROR_REQUEST_PERM_TIMEOUT)
        {
            llOwnerSay("⚠ By declining the experience, you cannot use the combat system in this region. You will not be able to participate in combat. You can see details about the experience and join it here: secondlife:///app/experience/" + llList2String(llGetExperienceDetails(NULL_KEY), 2) + "/profile");
        }
        else if(reason == XP_ERROR_NOT_PERMITTED_LAND) llDetachFromAvatar();
        else llOwnerSay(llGetExperienceErrorMessage(reason));
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    listen(integer channel, string name, key identifier, string text)
    {
        llSetTimerEvent(FALSE);
        integer version = (integer)text;
        if(version > 2900000) llLinksetDataWrite("RLV", text);
        else
        {
            llLinksetDataDelete("RLV");
            llOwnerSay("The RLV API on your viewer is too old to be supported (need at least v2.9)");
        }
        
        state alive;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    timer()
    {
        llSetTimerEvent(FALSE);
        llOwnerSay("⚠ No RLV detected; It is highly recommended to have RLV enabled with the experience-based combat system for it to kick you out of mouselook when you are downed in combat. This avoids confusion / awkward user experience as there is no way to do this with LSL alone.");
        state alive;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    changed(integer change) { if(change & CHANGED_OWNER) llResetScript(); }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
state alive
{
    state_entry()
    {
        llOwnerSay("@clear");
        llLinksetDataWrite("MEBCS_Combatant.Status:" + llGetOwner(), "Active");
        llLinksetDataWrite("Screen", "Normal");
        llTakeControls(0, FALSE, TRUE);
        if(DownAnimation) { llStopAnimation(DownAnimation); DownAnimation = ""; }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    on_death()
    {
        // Transition to Downed
        llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
            "event", "DOWN",
            "time", llGetTimestamp(),
            "position", llGetPos()
        ]));
        state downed;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    changed(integer change) { if(change & CHANGED_OWNER) llResetScript(); }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
state downed
{
    state_entry()
    {
        llOwnerSay("Downed");
        llLinksetDataWrite("MEBCS_Combatant.Status:" + llGetOwner(), "Downed");
        llLinksetDataWrite("MEBCS_Combatant.Downed:" + llGetOwner(), "Downed");
        string nameTeamsDowned = "MEBCS_Teams_Downed." + llGetTeam(llGetOwner());
        list team = llJson2List(llLinksetDataRead(nameTeamsDowned));
        team += llGetOwner();
        llLinksetDataWrite(llList2Json(JSON_ARRAY, team));
        
        llLinksetDataWrite("Screen", "Down");
        llLinksetDataWrite("Status.Down", "Down");
        
        DownAnimation = llList2String(DownAnimations, llFloor(llFrand(llGetListLength(DownAnimations))));
        llStartAnimation(DownAnimation);
        
        llTakeControls(0, FALSE, FALSE);
        if(llLinksetDataRead("RLV"))
        {
            // Kick out ouf mouselook
            llOwnerSay("@camdistmin:5=n");
            
            // Visual feedback/flair
            llOwnerSay("@setsphere=n,setsphere_mode:0=force,setsphere_param:0.2/0.2/0.2/0=force,setsphere_distmin:32=force,setsphere_distmax:64=force,setsphere_valuemin:0=force,setsphere_valuemax:0=force,setsphere_tween:2.0=force");
            llOwnerSay("@setsphere=n,setsphere_mode:0=force,setsphere_param:0.06/0.06/0.06/0=force,setsphere_distmin:2=force,setsphere_distmax:24=force,setsphere_valuemin:0=force,setsphere_valuemax:0.85=force,setsphere_tween:0.1=force");
        }
        
        DownTime = DOWN_TIME;
        llSetTimerEvent(0.5);
        llListen(EVENT_CHANNEL, "", "", "");
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    state_exit()
    {
        llSetTimerEvent(FALSE);
        llStopMoveToTarget();
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    touch_start(integer touches)
    {
        integer link = llDetectedLinkNumber(0);
        string name = llGetLinkName(link);
        
        if(name == "Redeploy")
        {
            // Transition to Deploy
            llOwnerSay("Redeploying");
            llLinksetDataWrite("MEBCS_Combatant.Status:" + llGetOwner(), "Dead");
            llLinksetDataDelete("MEBCS_Combatant.Downed:" + llGetOwner());
            llRegionSay(EVENT_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "DEAD",
                "time", llGetTimestamp(),
                "position", llGetPos()
            ]));
            state deploy;
        }
        
        else if(name == "Request")
        {
            string downStatus = llLinksetDataRead("Down.Status");
            if(downStatus == "Down")
            {
                llLinksetDataWrite("Down.Status", "Requested");
                llLinksetDataRead("MEBCS_Teams:" + llGetOwner() + ".Status", "Requested");
            }
            
            else if(downStatus == "Requested")
            {
                llLinksetDataWrite("Down.Status", "Down");
                llLinksetDataRead("MEBCS_Teams:" + llGetOwner() + ".Status", "Down");
            }
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
}