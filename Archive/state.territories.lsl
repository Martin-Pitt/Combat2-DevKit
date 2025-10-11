list Territories = [/* string Name */];
/* Related linkset data:
vector <Territory>_center - Center of the territory
string[] <Territory>_neighbours - Connected territories
float[] <Territory>_vertices - Polygon as pairs of 2D vectors
integer[] <Territory>_lines - Indicates which line between vertices borders a neighbour
string <Territory>_team - Team ownership
*/

onTerritoryFound(string payload)
{
    string territory = llJsonGetValue(payload, ["territory"]);
    if(llListFindList(Territories, [territory]) != -1) return;
    
    Territories += territory;
    llLinksetDataWrite("territories", llList2Json(JSON_ARRAY, Territories));
    llLinksetDataWrite(territory + "_center", llJsonGetValue(payload, ["center"]));
    llLinksetDataWrite(territory + "_neighbours", llJsonGetValue(payload, ["neighbours"]));
    llLinksetDataWrite(territory + "_vertices", llJsonGetValue(payload, ["vertices"]));
    llLinksetDataWrite(territory + "_lines", llJsonGetValue(payload, ["lines"]));
    llLinksetDataWrite(territory + "_team", "");
    
    llMessageLinked(LINK_SET, MESSAGE_TERRITORY_FOUND, territory, "");
}

onTerritoryUpdate(string payload)
{
    string territory = llJsonGetValue(payload, ["territory"]);
    if(territory == "*")
    {
        list data = llJson2List(payload);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "event" && name != "territory")
            {
                string value = llList2String(data, iterator + 1);
                integer pointer = llGetListLength(Territories);
                while(pointer --> 0)
                {
                    territory = llList2String(Territories, pointer);
                    llLinksetDataWrite(territory + "_" + name, value);
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
            if(name != "event" && name != "territory")
                llLinksetDataWrite(territory + "_" + name, llList2String(data, iterator + 1));
        }
    }
    
    llMessageLinked(LINK_SET, MESSAGE_TERRITORY_UPDATED, territory, "");
}

onTerritoryRemoved(string payload)
{
    string territory = llJsonGetValue(payload, ["territory"]);
    integer index = llListFindList(Territories, [territory]);
    if(index == -1) return;
    Territories = llDeleteSubList(Territories, index, index);
    llLinksetDataWrite("territories", llList2Json(JSON_ARRAY, Territories));
    llLinksetDataDelete(territory + "_center");
    llLinksetDataDelete(territory + "_neighbours");
    llLinksetDataDelete(territory + "_vertices");
    llLinksetDataDelete(territory + "_lines");
    llLinksetDataDelete(territory + "_team");
    
    llMessageLinked(LINK_SET, MESSAGE_TERRITORY_REMOVED, territory, "");
}

onTerritoryList(string payload)
{
    string eventName = llJsonGetValue(payload, ["event"]);
    list bucket = llJson2List(llJsonGetValue(payload, ["list"]));
    integer count = llGetListLength(bucket);
    while(count --> 0)
    {
        string item = llList2String(bucket, count);
        string territory = llJsonGetValue(item, ["territory"]);
        list data = llJson2List(item);
        integer iterator; integer total = llGetListLength(data);
        for(; iterator < total; iterator += 2)
        {
            string name = llList2String(data, iterator);
            if(name != "territory")
                llLinksetDataWrite(territory + "_" + name, llList2String(data, iterator + 1));
        }
        
        Territories += territory;
    }
    
    if(eventName == "territory.list.end")
    {
        llLinksetDataWrite("territories", llList2Json(JSON_ARRAY, Territories));
        llMessageLinked(LINK_SET, MESSAGE_TERRITORY_FOUND, "*", "");
    }
}



