#include "Combat2 Respawns/constants.lsl"
#include "Common/geometric.lsl"


list Vertices = [/* key Vertice */];
list Objectives = [/* key Objective */];
list RespawnPoints = [/* key RespawnPoint */];
list Areas = [/* key Area */];


vector homePos;
string scanTarget;
#define SCAN_DENSITY 4
#define SCAN_HEIGHT 900
integer scanIndex;
integer scanCheck()
{
    if(scanIndex --> 0)
    {
        integer row = scanIndex / SCAN_DENSITY;
        integer col = scanIndex % SCAN_DENSITY;
        float step = 256.0 / SCAN_DENSITY;
        llSetRegionPos(<step/2 + step*row, step/2 + step*col, SCAN_HEIGHT>);
        llSensor(scanTarget, "", ACTIVE|PASSIVE, 96.0, TWO_PI);
        return FALSE;
    }
    
    if(scanTarget == "Territory Corner")
    {
        scanTarget = "Objective Flag";
        scanIndex = SCAN_DENSITY * SCAN_DENSITY;
        return scanCheck();
    }
    
    if(scanTarget == "Objective Flag")
    {
        scanTarget = "Objective Base";
        scanIndex = SCAN_DENSITY * SCAN_DENSITY;
        return scanCheck();
    }
    
    if(scanTarget == "Objective Base")
    {
        scanTarget = "Respawn Point";
        scanIndex = SCAN_DENSITY * SCAN_DENSITY;
        return scanCheck();
    }
    
    if(scanTarget == "Respawn point")
    {
        scanTarget = "Area";
        scanIndex = SCAN_DENSITY * SCAN_DENSITY;
        return scanCheck();
    }
    
    return TRUE;
}


default
{
    state_entry()
    {
        llListen(C2R_CHANNEL, "", "", "");
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        if(llGetOwnerKey(identifier) != llGetOwner()) return;
        
        string action = llJsonGetValue(message, ["action"]);
        if(action == "scan") state scan;
    }
}


state scan
{
    state_entry()
    {
        homePos = llGetPos();
        scanTarget = "Territory Corner";
        scanIndex = SCAN_DENSITY * SCAN_DENSITY;
        scanCheck();
    }
    
    sensor(integer detected)
    {
        while(detected --> 0)
        {
            key object = llDetectedKey(detected);
            if(llGetOwnerKey(object) != llGetOwner()) jump continue;
            // if(!withinArena(llDetectedPos(detected))) jump continue;
            
            if(scanTarget == "Territory Corner")
            {
                if(llListFindList(Vertices, [object]) != -1) jump continue;
                Vertices += object;
            }
            
            else if(scanTarget == "Objective Flag" || scanTarget == "Objective Base")
            {
                if(llListFindList(Objectives, [object]) != -1) jump continue;
                Objectives += object;
            }
            
            else if(scanTarget == "Respawn Point")
            {
                if(llListFindList(RespawnPoints, [object]) != -1) jump continue;
                RespawnPoints += object;
            }
            
            else if(scanTarget == "Area")
            {
                if(llListFindList(Areas, [object]) != -1) jump continue;
                Areas += object;
            }
            
            @continue;
        }
        
        if(scanCheck()) state process;
    }
    
    no_sensor()
    {
        if(scanCheck()) state process;
    }
    
    state_exit()
    {
        llSetRegionPos(homePos);
    }
}

state process
{
    state_entry()
    {
        llOwnerSay((string)llGetListLength(Vertices) + " vertices");
        llOwnerSay((string)llGetListLength(Objectives) + " objectives");
        
        // list Vertices = [key Vertice];
        // string[] <Vertice>_connections
        // vector <Vertice>_position
        
        // list Objectives = [key Objective];
        
        // list RespawnPoints = [key RespawnPoint];
        
        // Parse vertice data
        integer iterator = llGetListLength(Vertices);
        while(iterator --> 0)
        {
            string vertice = llList2String(Vertices, iterator);
            list details = llGetObjectDetails(vertice, [OBJECT_DESC, OBJECT_POS]);
            llLinksetDataWrite(vertice + "_connections", llList2Json(JSON_ARRAY, llParseString2List(llList2String(details, 0), [","], [])));
            llLinksetDataWrite(vertice + "_position", llList2String(details, 1));
        }
        
        list BorderLines = [/* key Vertice A, key Vertice B */];
        // territory[] <Vertice A>_<Vertice B>_connections
        
        list Territories = [/* string Territory */];
        // string[] <Territory>_neighbours
        // vector <Territory>_center
        // float[] <Territory>_vertices
        // integer[] <Territory>_lines
        
        // Figure out territorial structure
        iterator = llGetListLength(Vertices);
        while(iterator --> 0)
        {
            string vertice = llList2String(Vertices, iterator);
            list connections = llJson2List(llLinksetDataRead(vertice + "_connections"));
            vector pos = (vector)llLinksetDataRead(vertice + "_position");
            integer count = llGetListLength(connections);
            while(count --> 0)
            {
                string connection = llList2String(connections, count);
                
                // Add territory
                if(llListFindList(Territories, [connection]) == -1)
                {
                    Territories += connection;
                    llLinksetDataWrite(connection + "_neighbours", "[]");
                    llLinksetDataWrite(connection + "_vertices", "[]");
                    llLinksetDataWrite(connection + "_lines", "[]");
                    llLinksetDataWrite(connection + "_center", "<0,0,0>");
                }
                
                
                // Add neighbours to territory
                list neighbours = llJson2List(llLinksetDataRead(connection + "_neighbours"));
                integer innerCount = llGetListLength(connections);
                while(innerCount --> 0)
                {
                    if(count != innerCount)
                    {
                        string neighbour = llList2String(connections, innerCount);
                        if(llListFindList(neighbours, [neighbour]) == -1) neighbours += neighbour;
                    }
                }
                
                llLinksetDataWrite(connection + "_neighbours", llList2Json(JSON_ARRAY, neighbours));
                
                
                // Add vertices to territory
                list vertices = llJson2List(llLinksetDataRead(connection + "_vertices"));
                integer total = llGetListLength(vertices);
                if(total)
                {
                    // TODO: Proximity check should really be checking against ANY other vertices rather than prev
                    vector prev = <llList2Float(vertices, total-3), llList2Float(vertices, total-2), 0>;
                    float dist = llFabs(prev.x - pos.x) + llFabs(prev.y - pos.y);
                    if(dist > 0.1) vertices += [pos.x, pos.y, vertice];
                }
                
                else
                {
                    vertices += [pos.x, pos.y, vertice]; // First vertice
                }
                
                llLinksetDataWrite(connection + "_vertices", llList2Json(JSON_ARRAY, vertices));
            }
        }
        
        // Loop through territories and sort the order of vertices to make sense
        iterator = llGetListLength(Territories);
        while(iterator --> 0)
        {
            string territory = llList2String(Territories, iterator);
            list vertices = llJson2List(llLinksetDataRead(territory + "_vertices"));
            float cx = llListStatistics(LIST_STAT_MEAN, llList2ListSlice(vertices, 0, -1, 3, 0));
            float cy = llListStatistics(LIST_STAT_MEAN, llList2ListSlice(vertices, 0, -1, 3, 1));
            llLinksetDataWrite(territory + "_center", (string)<cx, cy, 0>);
            list intermediary = [/* float x, float y, float angle */];
            integer count = llGetListLength(vertices);
            while((count -= 3) >= 0)
            {
                float x = llList2Float(vertices, count);
                float y = llList2Float(vertices, count + 1);
                string vertice = llList2String(vertices, count + 2);
                float angle = llAtan2(y - cy, x - cx);
                intermediary += [x, y, vertice, angle];
            }
            
            vertices = [];
            intermediary = llListSortStrided(intermediary, 4, 3, FALSE);
            count = llGetListLength(intermediary);
            while((count -= 4) >= 0) vertices += llList2List(intermediary, count, count + 2);
            
            llLinksetDataWrite(territory + "_vertices", llList2Json(JSON_ARRAY, vertices));
            
            // Check for lines
            count = llGetListLength(vertices);
            string verticeA = llList2String(vertices, -1);
            integer index;
            for(; index < count; index += 3)
            {
                string verticeB = llList2String(vertices, index + 2);
                
                // Found existing border line pair
                if(llListFindStrided(BorderLines, [verticeA, verticeB], 0, -1, 2) != -1)
                {
                    string name = verticeA + "_" + verticeB + "_connections";
                    llLinksetDataWrite(name, llList2Json(JSON_ARRAY, llJson2List(llLinksetDataRead(name)) + [territory]));
                }
                
                else
                {
                    // Found existing border line pair in reverse order
                    if(llListFindStrided(BorderLines, [verticeB, verticeA], 0, -1, 2) != -1)
                    {
                        string name = verticeB + "_" + verticeA + "_connections";
                        llLinksetDataWrite(name, llList2Json(JSON_ARRAY, llJson2List(llLinksetDataRead(name)) + [territory]));
                    }
                    
                    // First border line of this pair
                    else
                    {
                        BorderLines += [verticeA, verticeB];
                        llLinksetDataWrite(verticeA + "_" + verticeB + "_connections", llList2Json(JSON_ARRAY, [territory]));
                    }
                }
                
                verticeA = verticeB;
            }
        }
        
        
        // Loop through the lines to figure out which are edges and internal to the mesh
        integer size = llGetListLength(BorderLines);
        for(iterator = 0; iterator < size; iterator += 2)
        {
            string verticeA = llList2String(BorderLines, iterator);
            string verticeB = llList2String(BorderLines, iterator + 1);
            list connections = llJson2List(llLinksetDataRead(verticeA + "_" + verticeB + "_connections"));
            if(connections == []) connections = llJson2List(llLinksetDataRead(verticeB + "_" + verticeA + "_connections"));
            
            integer borderType = -1;
            integer index;
            integer total = llGetListLength(connections);
            for(index = 0; index < total; ++index)
            {
                string territory = llList2String(connections, index);
                list vertices = llJson2List(llLinksetDataRead(territory + "_vertices"));
                
                integer a = llListFindList(vertices, [verticeA]);
                integer b = llListFindList(vertices, [verticeB]);
                if(a == -1) return llOwnerSay("Assertion Failed: Missing verticeA!");
                if(b == -1) return llOwnerSay("Assertion Failed: Missing verticeB!");
                
                a = ((a-2)/3)*2;
                b = ((b-2)/3)*2;
                
                if(b < a)
                {
                    integer temp = a;
                    a = b;
                    b = temp;
                }
                
                if(total == 2)
                {
                    string neighbour = llList2String(connections, (total - 1) - index);
                    list neighbours = llJson2List(llLinksetDataRead(territory + "_neighbours"));
                    borderType = llListFindList(neighbours, [neighbour]);
                }
                
                list lines = llJson2List(llLinksetDataRead(territory + "_lines"));
                lines += [a, b, borderType];
                llLinksetDataWrite(territory + "_lines", llList2Json(JSON_ARRAY, lines));
            }
        }
        
        // Clean up the territory lists
        iterator = llGetListLength(Territories);
        while(iterator --> 0)
        {
            string territory = llList2String(Territories, iterator);
            
            // Remove the vertice key stride
            list vertices = llJson2List(llLinksetDataRead(territory + "_vertices"));
            integer index = llGetListLength(vertices);
            while(index --> 0) if(index % 3 == 2) vertices = llDeleteSubList(vertices, index, index);
            llLinksetDataWrite(territory + "_vertices", llList2Json(JSON_ARRAY, vertices));
            
            // Slice out the border type only after sorting into same order as vertices
            list lines = llJson2List(llLinksetDataRead(territory + "_lines"));
            lines = llListSortStrided(lines, 3, 1, FALSE);
            lines = llListSortStrided(lines, 3, 0, TRUE);
            lines = llList2ListSlice(lines, 0, -1, 3, 2);
            llLinksetDataWrite(territory + "_lines", llList2Json(JSON_ARRAY, lines));
        }
        
        
        
        
        // Loop through objectives
        iterator = llGetListLength(Objectives);
        while(iterator --> 0)
        {
            string objective = llList2Key(Objectives, iterator);
            list details = llGetObjectDetails(objective, [OBJECT_NAME, OBJECT_DESC, OBJECT_POS]);
            string type = llDeleteSubString(llList2String(details, 0), 0, llStringLength("Objective ") - 1);
            string territory = llList2String(details, 1);
            
            llLinksetDataWrite(objective + "_territory", territory);
            llLinksetDataWrite(objective + "_type", type);
        }
        
        // Loop through respawn points
        iterator = llGetListLength(RespawnPoints);
        while(iterator --> 0)
        {
            string respawn = llList2String(RespawnPoints, iterator);
            list details = llGetObjectDetails(respawn, [OBJECT_DESC, OBJECT_POS]);
            string desc = llList2String(details, 0);
            vector pos = llList2Vector(details, 1);
            
            llLinksetDataWrite(respawn + "_team", desc);
            
            integer count = llGetListLength(Territories);
            while(count --> 0)
            {
                string territory = llList2String(Territories, count);
                list vertices = llJson2List(llLinksetDataRead(territory + "_vertices"));
                if(pointInPolygon(pos, vertices))
                {
                    llLinksetDataWrite(respawn + "_territory", territory);
                    count = 0;
                }
            }
        }
        
        // Output
        iterator = llGetListLength(Territories);
        while(iterator --> 0)
        {
            string territory = llList2String(Territories, iterator);
            llRegionSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "territory.found",
                "territory", territory,
                "center", llLinksetDataRead(territory + "_center"),
                "neighbours", llLinksetDataRead(territory + "_neighbours"),
                "vertices", llLinksetDataRead(territory + "_vertices"),
                "lines", llLinksetDataRead(territory + "_lines")
            ]));
        }
        
        iterator = llGetListLength(Objectives);
        while(iterator --> 0)
        {
            string objective = llList2Key(Objectives, iterator);
            llRegionSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "objective.found",
                "objective", objective,
                "territory", llLinksetDataRead(objective + "_territory"),
                "type", llLinksetDataRead(objective + "_type")
            ]));
        }
        
        iterator = llGetListLength(RespawnPoints);
        while(iterator --> 0)
        {
            string respawn = llList2String(RespawnPoints, iterator);
            llRegionSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "respawn.found",
                "respawn", respawn,
                "team", llLinksetDataRead(respawn + "_team"),
                "territory", llLinksetDataRead(respawn + "_territory")
            ]));
        }
        
        iterator = llGetListLength(Areas);
        while(iterator --> 0)
        {
            string area = llList2String(Areas, iterator);
            llRegionSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "area.found",
                "area", area
            ]));
        }
        
        
        
        llLinksetDataReset();
        state default;
    }
}

