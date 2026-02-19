default
{
    state_entry()
    {
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
    }
    
    // Check Combat Log for DEATH events of people who did not accept the experience and deal with them
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
                string status = llLinksetDataRead("FLECS." + target + "_status");
                if(status != "active") llTeleportAgentHome(target);
            }
        }
    }
}
