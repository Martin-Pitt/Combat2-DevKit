// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/tracking.lsl"

/*
    This script helps support cross-sim communication of Tracking Servers if they cannot be situated next to eachother 
    
    Instead this relay can be placed at the sim borders which will relay local border chats to the region-wide chats and vice versa
    
    This would be used in situations where you have multiple regions. For example a 3x1 layout would be setup as follows:
        ┌───┐┌───┐┌───┐    Where:
        │   TT   RT   │      T = Tracking Server
        └───┘└───┘└───┘      R = Tracking Relay
    
    Note: Relays pass messages regardless, so avoid setting a feedback loops!
*/


default
{
    state_entry()
    {
        llListen(TRACKING_INTERNAL_CHANNEL, "", "", "");
        llListen(TRACKING_BORDER_CHANNEL, "", "", "");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        string type = llJsonGetValue(message, ["type"]);
        
        // Signatures are identifier-dependant, so we will verify the Tracking Server at the Tracking Relay to check we can trust the incoming messages
        // and then have the Tracking Relay replace the signature with it's own, which creates a chain of trust
        if(type == "init" || type == "reinit")
        {
            if(!onTrackingServerVerify(identifier, llJsonGetValue(message, ["signature"]))) return;
            message = llJsonSetValue(message, ["signature"], generateHandshake());
        }
        
        // Verify before moving on
        if(!(llGetOwnerKey(identifier) == llGetOwner() || llListFindList(VerifiedIdentifiers, [identifier]) != -1)) return;
        
        // Proxy events to the other channel, internal <-> border
        if(channel == TRACKING_INTERNAL_CHANNEL) borderMessage(message);
        else if(channel == TRACKING_BORDER_CHANNEL) internalMessage(message);
    }
}