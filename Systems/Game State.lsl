// Combat2 Respawns: https://github.com/Martin-Pitt/Combat2-Respawns
#define GAME_SERVER
#include "Combat2 Respawns/constants.lsl"
#include "Combat2 Respawns/state.lsl"
#include "Combat2 Respawns/state.territories.lsl"
#include "Combat2 Respawns/state.objectives.lsl"
#include "Combat2 Respawns/state.points.lsl"

// Customise this to the prefix of the area that this state server covers
#define GAME_AREA "Arena"


default
{
    state_entry()
    {
        llSetObjectName("Game State");
        
        llLinksetDataWrite("territories", llList2Json(JSON_ARRAY, Territories));
        llLinksetDataWrite("objectives", llList2Json(JSON_ARRAY, Objectives));
        llLinksetDataWrite("respawnpoints", llList2Json(JSON_ARRAY, RespawnPoints));
        
        llListen(C2R_CHANNEL, "", "", "");
        
        #ifdef GAME_AREA
        llSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, ["action", "scan", "area", GAME_AREA]));
        #else
        llSay(C2R_CHANNEL, llList2Json(JSON_OBJECT, ["action", "scan"]));
        #endif
    }
    
    listen(integer channel, string name, key identifier, string message)
    {
        // Restrict to owner only
        if(llGetOwnerKey(identifier) != llGetOwner()) return;
        
        string type = llJsonGetValue(message, ["type"]);
        
        if(type == "territory.update") onTerritoryUpdate(message);
        else if(type == "objective.update") onObjectiveUpdate(message);
        else if(type == "respawn.update") onRespawnPointUpdate(message);
        
        else if(llGetSubString(type, -6, -1) == ".found")
        {
            #ifdef GAME_AREA
            // Restrict to a specific area prefix
            string area = llJsonGetValue(message, ["area"]);
            if(area == JSON_INVALID) return;
            if(llSubStringIndex(area, GAME_AREA) != 0) return;
            #endif
            
            if(type == "territory.found") onTerritoryFound(message);
            else if(type == "objective.found") onObjectiveFound(message);
            else if(type == "respawn.found") onRespawnPointFound(message);
        }
        
        else if(type == "territory.removed") onTerritoryRemoved(message);
        else if(type == "objective.removed") onObjectiveRemoved(message);
        else if(type == "respawn.removed") onRespawnPointRemoved(message);
        
        else if(llGetSubString(type, -5, -1) == ".list")
        {
            #ifdef GAME_AREA
            // Restrict to a specific area prefix
            string area = llJsonGetValue(message, ["area"]);
            if(area == JSON_INVALID) return;
            if(area != "*" && llSubStringIndex(area, GAME_AREA) != 0) return;
            #endif
            
            if(type == "territory.list" || type == "*.list")
            {
                list bucket;
                integer iterator = llGetListLength(Territories);
                integer fill;
                while(iterator --> 0)
                {
                    string territory = llList2String(Territories, iterator);
                    string payload = llList2Json(JSON_OBJECT, [
                        "territory", territory,
                        "center", llLinksetDataRead(territory + "_center"),
                        "neighbours", llLinksetDataRead(territory + "_neighbours"),
                        "vertices", llLinksetDataRead(territory + "_vertices"),
                        "lines", llLinksetDataRead(territory + "_lines"),
                        "team", llLinksetDataRead(territory + "_team")
                    ]);
                    integer size = llStringLength(payload);
                    
                    if(fill + size + 64 >= 1024)
                    {
                        llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                            "event", "territory.list.fragment",
                            "list", llList2Json(JSON_ARRAY, bucket)
                        ]));
                        bucket = [];
                        fill = 0;
                    }
                    
                    bucket += payload;
                    fill += size;
                }
                
                llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                    "event", "territory.list.end",
                    "list", llList2Json(JSON_ARRAY, bucket)
                ]));
            }
            
            if(type == "objective.list" || type == "*.list")
            {
                list bucket;
                integer iterator = llGetListLength(Objectives);
                integer fill;
                while(iterator --> 0)
                {
                    string objective = llList2String(Objectives, iterator);
                    string payload = llList2Json(JSON_OBJECT, [
                        "objective", objective,
                        "territory", llLinksetDataRead(objective + "_territory"),
                        "type", llLinksetDataRead(objective + "_type"),
                        "state", llLinksetDataRead(objective + "_state")
                    ]);
                    integer size = llStringLength(payload);
                    
                    if(fill + size + 64 >= 1024)
                    {
                        llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                            "event", "objective.list.fragment",
                            "list", llList2Json(JSON_ARRAY, bucket)
                        ]));
                        bucket = [];
                        fill = 0;
                    }
                    
                    bucket += payload;
                    fill += size;
                }
                
                llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                    "event", "objective.list.end",
                    "list", llList2Json(JSON_ARRAY, bucket)
                ]));
            }
            
            if(type == "respawn.list" || type == "*.list")
            {
                list bucket;
                integer iterator = llGetListLength(RespawnPoints);
                integer fill;
                while(iterator --> 0)
                {
                    string respawn = llList2String(RespawnPoints, iterator);
                    string payload = llList2Json(JSON_OBJECT, [
                        "respawn", respawn,
                        "team", llLinksetDataRead(respawn + "_team"),
                        "territory", llLinksetDataRead(respawn + "_territory")
                    ]);
                    integer size = llStringLength(payload);
                    
                    if(fill + size + 64 >= 1024)
                    {
                        llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                            "event", "respawn.list.fragment",
                            "list", llList2Json(JSON_ARRAY, bucket)
                        ]));
                        bucket = [];
                        fill = 0;
                    }
                    
                    bucket += payload;
                    fill += size;
                }
                
                llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                    "event", "respawn.list.end",
                    "list", llList2Json(JSON_ARRAY, bucket)
                ]));
            }
        }
        
        else if(type == "territory.ping")
        {
            string territory = llJsonGetValue(message, ["territory"]);
            if(llListFindList(Territories, [territory]) == -1) return;
            
            llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "territory.pong",
                "territory", territory,
                "center", llLinksetDataRead(territory + "_center"),
                "neighbours", llLinksetDataRead(territory + "_neighbours"),
                "vertices", llLinksetDataRead(territory + "_vertices"),
                "lines", llLinksetDataRead(territory + "_lines"),
                "team", llLinksetDataRead(territory + "_team")
            ]));
        }
        
        else if(type == "objective.ping")
        {
            string objective = llJsonGetValue(message, ["objective"]);
            if(llListFindList(Objectives, [objective]) == -1) return;
            
            llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "objective.pong",
                "objective", objective,
                "territory", llLinksetDataRead(objective + "_territory"),
                "type", llLinksetDataRead(objective + "_type"),
                "state", llLinksetDataRead(objective + "_state")
            ]));
        }
        
        else if(type == "respawn.ping")
        {
            string respawn = llJsonGetValue(message, ["respawn"]);
            if(llListFindList(RespawnPoints, [respawn]) == -1) return;
            
            llRegionSayTo(identifier, C2R_CHANNEL, llList2Json(JSON_OBJECT, [
                "event", "respawn.pong",
                "respawn", respawn,
                "team", llLinksetDataRead(respawn + "_team"),
                "territory", llLinksetDataRead(respawn + "_territory")
            ]));
        }
    }
}
