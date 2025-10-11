list Objectives = [/* key Objective */];
/* Related linkset data:
string <Objective>_territory
string <Objective>_type
string <Objective>_state
*/

onObjectiveFound(string payload)
{
    string objective = llJsonGetValue(payload, ["objective"]);
    if(llListFindList(Objectives, [objective]) != -1) return;
    
    Objectives += objective;
    llLinksetDataWrite("objectives", llList2Json(JSON_ARRAY, Objectives));
    llLinksetDataWrite(objective + "_territory", llJsonGetValue(payload, ["territory"]));
    llLinksetDataWrite(objective + "_type", llJsonGetValue(payload, ["type"]));
    llLinksetDataWrite(objective + "_state", "");
    
    llMessageLinked(LINK_SET, MESSAGE_OBJECTIVE_FOUND, objective, "");
}

onObjectiveUpdate(string payload)
{
    string objective = llJsonGetValue(payload, ["objective"]);
    if(objective == "*")
    {
        list data = llJson2List(payload);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "event" && name != "objective")
            {
                string value = llList2String(data, iterator + 1);
                integer pointer = llGetListLength(Objectives);
                while(pointer --> 0)
                {
                    objective = llList2String(Objectives, pointer);
                    llLinksetDataWrite(objective + "_" + name, value);
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
            if(name != "event" && name != "objective")
                llLinksetDataWrite(objective + "_" + name, llList2String(data, iterator + 1));
        }
    }
    
    llMessageLinked(LINK_SET, MESSAGE_OBJECTIVE_UPDATED, objective, "");
}

onObjectiveRemoved(string payload)
{
    string objective = llJsonGetValue(payload, ["objective"]);
    integer index = llListFindList(Objectives, [objective]);
    if(index == -1) return;
    Objectives = llDeleteSubList(Objectives, index, index);
    llLinksetDataWrite("objectives", llList2Json(JSON_ARRAY, Objectives));
    llLinksetDataDelete(objective + "_territory");
    llLinksetDataDelete(objective + "_type");
    llLinksetDataDelete(objective + "_state");
    
    llMessageLinked(LINK_SET, MESSAGE_OBJECTIVE_REMOVED, objective, "");
}

onObjectiveList(string payload)
{
    string eventName = llJsonGetValue(payload, ["event"]);
    list bucket = llJson2List(llJsonGetValue(payload, ["list"]));
    integer count = llGetListLength(bucket);
    while(count --> 0)
    {
        string item = llList2String(bucket, count);
        string objective = llJsonGetValue(item, ["objective"]);
        list data = llJson2List(item);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "objective")
                llLinksetDataWrite(objective + "_" + name, llList2String(data, iterator + 1));
        }
        
        Objectives += objective;
    }
    
    if(eventName == "objective.list.end")
    {
        llLinksetDataWrite("objectives", llList2Json(JSON_ARRAY, Objectives));
        llMessageLinked(LINK_SET, MESSAGE_OBJECTIVE_FOUND, "*", "");
    }
}

