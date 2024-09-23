list RespawnPoints = [/* key RespawnPoint */];
/* Related linkset data:
string <RespawnPoint>_territory
string <RespawnPoint>_team
*/

onRespawnPointFound(string payload)
{
    string respawn = llJsonGetValue(payload, ["respawn"]);
    if(llListFindList(RespawnPoints, [respawn]) != -1) return;
    
    RespawnPoints += respawn;
    llLinksetDataWrite("respawnPoints", llList2Json(JSON_ARRAY, RespawnPoints));
    llLinksetDataWrite(respawn + "_team", llJsonGetValue(payload, ["team"]));
    llLinksetDataWrite(respawn + "_territory", llJsonGetValue(payload, ["territory"]));
    
    llMessageLinked(LINK_SET, MESSAGE_RESPAWN_FOUND, respawn, "");
}

onRespawnPointUpdate(string payload)
{
    string respawn = llJsonGetValue(payload, ["respawn"]);
    if(respawn == "*")
    {
        list data = llJson2List(payload);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "event" && name != "respawn")
            {
                string value = llList2String(data, iterator + 1);
                integer pointer = llGetListLength(RespawnPoints);
                while(pointer --> 0)
                {
                    respawn = llList2String(RespawnPoints, pointer);
                    llLinksetDataWrite(respawn + "_" + name, value);
                }
            }
        }
    }
    
    else
    {
        list data = llJson2List(payload);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "event" && name != "respawn")
                llLinksetDataWrite(respawn + "_" + name, llList2String(data, iterator + 1));
        }
    }
    
    llMessageLinked(LINK_SET, MESSAGE_RESPAWN_UPDATED, respawn, "");
}

onRespawnPointRemoved(string payload)
{
    string respawn = llJsonGetValue(payload, ["respawn"]);
    integer index = llListFindList(RespawnPoints, [respawn]);
    if(index == -1) return;
    RespawnPoints = llDeleteSubList(RespawnPoints, index, index);
    llLinksetDataWrite("respawnpoints", llList2Json(JSON_ARRAY, RespawnPoints));
    llLinksetDataDelete(respawn + "_team");
    llLinksetDataDelete(respawn + "_territory");
    
    llMessageLinked(LINK_SET, MESSAGE_RESPAWN_REMOVED, respawn, "");
}

onRespawnPointList(string payload)
{
    string eventName = llJsonGetValue(payload, ["event"]);
    list bucket = llJson2List(llJsonGetValue(payload, ["list"]));
    integer count = llGetListLength(bucket);
    while(count --> 0)
    {
        string item = llList2String(bucket, count);
        string respawn = llJsonGetValue(item, ["respawn"]);
        list data = llJson2List(item);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "respawn")
                llLinksetDataWrite(respawn + "_" + name, llList2String(data, iterator + 1));
        }
        
        RespawnPoints += respawn;
    }
    
    if(eventName == "respawn.list.end")
    {
        llLinksetDataWrite("respawnPoints", llList2Json(JSON_ARRAY, RespawnPoints));
        llMessageLinked(LINK_SET, MESSAGE_RESPAWN_FOUND, "*", "");
    }
}

