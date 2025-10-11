integer DATA_CHANNEL = -200000;

list Entities = ["agent", "objective", "territory", "point"];
list Singletons = ["arena"];

////////////////////////////////////////////////////////////////////////////////////////////////

default
{
    state_entry()
    {
        llLinksetDataReset();
        
        llListen(DATA_CHANNEL, "", "", "");
        string init = llList2Json(JSON_OBJECT, ["event", "init"]);
        llRegionSay(DATA_CHANNEL, init);
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    listen(integer channel, string name, key object, string message)
    {
        // Restrict to owner only
        if(llGetOwnerKey(object) != llGetOwner()) return;
        
        //--------------------------------------------------------------------------------------
        
        // Parse event from message
        string packet = message;
        string temp = llJsonGetValue(packet, ["event"]);
        if(temp == JSON_INVALID) // Error
        {
            packet = llList2Json(JSON_OBJECT, [
                "event", "error",
                "code", 400,
                "description", "Not valid json, unable to parse event from json"
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
            return;
        }
        
        integer dot = llSubStringIndex(temp, ".");
        if(dot == -1) // Error
        {
            packet = llList2Json(JSON_OBJECT, [
                "event", "error",
                "code", 400,
                "description", "Event syntax doesn't match expected 'name.action' convention"
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
            return;
        }
        
        string eventName = llGetSubString(temp, 0, dot - 1);
        string eventAction = llGetSubString(temp, dot + 1, -1);
        packet = llJsonSetValue(packet, ["event"], JSON_DELETE);
        
        //--------------------------------------------------------------------------------------
        
        // Check and load data
        string identifier;
        string lookup;
        integer isEntity;
        integer isSingleton;
        list subscribers;
        string subscribersPacket;
        if(isEntity = llListFindList(Entities, [eventName]) != -1)
        {
            identifier = llJsonGetValue(packet, ["identifier"]);
            if(identifier == JSON_INVALID) identifier = "*";
            else packet = llJsonSetValue(packet, ["identifier"], JSON_DELETE);
            lookup = eventName + "." + identifier;
            subscribers = llJson2List(llLinksetDataRead(eventName + ".*.subscribers"));
            if(identifier != "*") subscribers += llJson2List(llLinksetDataRead(lookup + ".subscribers"));
        }
        else if(isSingleton = llListFindList(Entities, [eventName]) != -1)
        {
            lookup = eventName;
            subscribers = llJson2List(llLinksetDataRead(lookup + ".subscribers"));
        }
        else
        {
            packet = llList2Json(JSON_OBJECT, [
                "event", "error",
                "code", 422,
                "description", "No valid entity or singleton defined as '" + eventName + "'"
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
            return;
        }
        
        //--------------------------------------------------------------------------------------
        
        // Event Actions
        if(identifier == "*" && isEntity)
        {
            if(eventAction == "patch")
            {
                list changes;
                list patch = llJson2List(packet);
                integer accessor; integer length = llGetListLength(patch);
                
                list identifiers = llJson2List(llLinksetDataRead(eventName));
                integer index = llGetListLength(identifiers);
                while(index --> 0)
                {
                    string ident = llList2String(identifiers, index);
                    
                    list subs = llJson2List(llLinksetDataRead(eventName + "." + ident + ".subscribers"));
                    integer iterator = llGetListLength(subs);
                    while(iterator --> 0)
                    {
                        string subscriber = llList2String(subs, iterator);
                        if(llListFindList(subscribers, [subscriber]) == -1) subscribers += subscriber;
                    }
                    
                    string data = llLinksetDataRead(eventName + "." + ident);
                    for(accessor = 0; accessor < length; accessor += 2)
                    {
                        string property = llList2String(patch, accessor);
                        integer type = llGetListEntryType(patch, accessor + 1);
                        if(type == TYPE_STRING || type == TYPE_KEY)
                        {
                            string newValue = llList2String(patch, accessor + 1);
                            string oldValue = llJsonGetValue(data, [property]);
                            if(newValue != oldValue)
                            {
                                if(llListFindStrided(changes, [property], 0, -1, 2) == -1) changes += [property, newValue];
                                data = llJsonSetValue(data, [property], "\"" + newValue + "\"");
                            }
                        }
                        
                        else if(type == TYPE_INTEGER)
                        {
                            integer newValue = llList2Integer(patch, accessor + 1);
                            integer oldValue = (integer)llJsonGetValue(data, [property]);
                            if(newValue != oldValue)
                            {
                                if(llListFindStrided(changes, [property], 0, -1, 2) == -1) changes += [property, newValue];
                                data = llJsonSetValue(data, [property], (string)newValue);
                            }
                        }
                        
                        else if(type == TYPE_FLOAT)
                        {
                            float newValue = llList2Float(patch, accessor + 1);
                            float oldValue = (float)llJsonGetValue(data, [property]);
                            if(newValue != oldValue)
                            {
                                if(llListFindStrided(changes, [property], 0, -1, 2) == -1) changes += [property, newValue];
                                data = llJsonSetValue(data, [property], (string)newValue);
                            }
                        }
                    }
                    llLinksetDataWrite(eventName + "." + ident, data);
                }
                
                if(changes)
                {
                    subscribersPacket = llList2Json(JSON_OBJECT, [
                        "event", eventName + ".patched",
                        "identifier", identifier
                    ] + changes);
                }
            }
            
            //----------------------------------------------------------------------------------
            
            else if(eventAction == "remove")
            {
                list identifiers = llJson2List(llLinksetDataRead(eventName));
                integer index = llGetListLength(identifiers);
                while(index --> 0)
                {
                    string ident = llList2String(identifiers, index);
                    list subs = llJson2List(llLinksetDataRead(eventName + "." + ident + ".subscribers"));
                    integer iterator = llGetListLength(subs);
                    while(iterator --> 0)
                    {
                        string subscriber = llList2String(subs, iterator);
                        if(llListFindList(subscribers, [subscriber]) == -1) subscribers += subscriber;
                    }
                }
                llLinksetDataDeleteFound("^" + eventName + "\\.", "");
                
                subscribersPacket = llList2Json(JSON_OBJECT, [
                    "event", eventName + ".removed",
                    "identifier", identifier
                ]);
            }
            
            //----------------------------------------------------------------------------------
            
            else if(eventAction == "get")
            {
                list bucket;
                integer size;
                
                packet = llList2Json(JSON_OBJECT, [
                    "event", eventName + ".list",
                    "list", "[]",
                    "isLast", JSON_FALSE
                ]);
                integer base = llStringLength(packet);
                
                list identifiers = llJson2List(llLinksetDataRead(eventName));
                integer index = llGetListLength(identifiers);
                while(index --> 0)
                {
                    string ident = llList2String(identifiers, index);
                    string data = llLinksetDataRead(eventName + "." + ident);
                    data = llJsonSetValue(data, ["identifier"], ident);
                    
                    integer length = llStringLength(data) + 1;
                    
                    if(size + length >= 1024)
                    {
                        string fragment = llJsonSetValue(packet, ["list"], llList2Json(JSON_ARRAY, bucket));
                        llRegionSayTo(object, DATA_CHANNEL, fragment);
                        bucket = [];
                        size = 0;
                    }
                    
                    bucket += data;
                    size += length;
                }
                
                packet = llJsonSetValue(packet, ["isLast"], JSON_TRUE);
                packet = llJsonSetValue(packet, ["list"], llList2Json(JSON_ARRAY, bucket));
                llRegionSayTo(object, DATA_CHANNEL, packet);
            }
            
            //----------------------------------------------------------------------------------
            
            else if(eventAction == "subscribe")
            {
                lookup += ".subscribers";
                subscribers = llJson2List(llLinksetDataRead(lookup));
                if(llListFindList(subscribers, [(string)object]) != -1) return; // Already subscribed
                subscribers += object;
                llLinksetDataWrite(lookup, llList2Json(JSON_ARRAY, subscribers));
                
                subscribers = [object];
                subscribersPacket = llList2Json(JSON_OBJECT, ["event", eventName + ".subscribed"]);
            }
            
            //----------------------------------------------------------------------------------
            
            else if(eventAction == "unsubscribe")
            {
                lookup += ".subscribers";
                subscribers = llJson2List(llLinksetDataRead(lookup));
                integer index = llListFindList(subscribers, [(string)object]);
                if(index == -1) return; // Already unsubscribed
                subscribers = llDeleteSubList(subscribers, index, index);
                llLinksetDataWrite(lookup, llList2Json(JSON_ARRAY, subscribers));
                
                subscribers = [object];
                subscribersPacket = llList2Json(JSON_OBJECT, ["event", eventName + ".unsubscribed"]);
            }
            
            //----------------------------------------------------------------------------------
            
            else
            {
                packet = llList2Json(JSON_OBJECT, [
                    "event", "error",
                    "code", 405,
                    "description", "Not a valid action '" + eventAction + "' for entity wildcard"
                ]);
                llRegionSayTo(object, DATA_CHANNEL, packet);
            }
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "add" && isEntity)
        {
            llLinksetDataWrite(lookup, packet);
            
            list identifiers = llJson2List(llLinksetDataRead(eventName));
            if(llListFindList(identifiers, [identifier]) == -1)
            {
                identifiers += identifier;
                llLinksetDataWrite(eventName, llList2Json(JSON_ARRAY, identifiers));
            }
            
            subscribersPacket = llJsonSetValue(subscribersPacket, ["event"], eventName + ".added");
            subscribersPacket = llJsonSetValue(subscribersPacket, ["identifier"], identifier);
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "patch")
        {
            string data = llLinksetDataRead(lookup);
            
            // If entity doesnt exist then lets add it
            if(data == "")
            {
                llLinksetDataWrite(lookup, packet);
                
                list identifiers = llJson2List(llLinksetDataRead(eventName));
                if(llListFindList(identifiers, [identifier]) == -1)
                {
                    identifiers += identifier;
                    llLinksetDataWrite(eventName, llList2Json(JSON_ARRAY, identifiers));
                }
                
                subscribersPacket = llJsonSetValue(subscribersPacket, ["event"], eventName + ".added");
                subscribersPacket = llJsonSetValue(subscribersPacket, ["identifier"], identifier);
                jump end;
            }
            
            list changes;
            list patch = llJson2List(packet);
            integer index; integer length;
            for(length = llGetListLength(patch); index < length; index += 2)
            {
                string name = llList2String(patch, index);
                integer type = llGetListEntryType(patch, index + 1);
                if(type == TYPE_STRING || type == TYPE_KEY)
                {
                    string newValue = llList2String(patch, index + 1);
                    string oldValue = llJsonGetValue(data, [name]);
                    if(newValue != oldValue)
                    {
                        changes += [name, newValue];
                        data = llJsonSetValue(data, [name], "\"" + newValue + "\"");
                    }
                }
                
                else if(type == TYPE_INTEGER)
                {
                    integer newValue = llList2Integer(patch, index + 1);
                    integer oldValue = (integer)llJsonGetValue(data, [name]);
                    if(newValue != oldValue)
                    {
                        changes += [name, newValue];
                        data = llJsonSetValue(data, [name], (string)newValue);
                    }
                }
                
                else if(type == TYPE_FLOAT)
                {
                    float newValue = llList2Float(patch, index + 1);
                    float oldValue = (float)llJsonGetValue(data, [name]);
                    if(newValue != oldValue)
                    {
                        changes += [name, newValue];
                        data = llJsonSetValue(data, [name], (string)newValue);
                    }
                }
            }
            llLinksetDataWrite(lookup, data);
            
            if(changes)
            {
                subscribersPacket = llList2Json(JSON_OBJECT, [
                    "event", eventName + ".patched",
                    "identifier", identifier
                ] + changes);
            }
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "remove" && isEntity)
        {
            list identifiers = llJson2List(llLinksetDataRead(eventName));
            integer index = llListFindList(identifiers, [identifier]);
            if(index == -1) return; // Already removed
            identifiers = llDeleteSubList(identifiers, index, index);
            llLinksetDataWrite(eventName, llList2Json(JSON_ARRAY, identifiers));
            llLinksetDataDelete(lookup);
            llLinksetDataDelete(lookup + ".subscribers");
            
            subscribersPacket = llList2Json(JSON_OBJECT, [
                "event", eventName + ".removed",
                "identifier", identifier
            ]);
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "get")
        {
            string data = llLinksetDataRead(lookup);
            if(data == "")
            {
                packet = llList2Json(JSON_OBJECT, [
                    "event", "error",
                    "code", 404,
                    "description", "Not found"
                ]);
                llRegionSayTo(object, DATA_CHANNEL, packet);
                return;
            }
            
            packet = llJsonSetValue(data, ["event"], eventName + ".result");
            llRegionSayTo(object, DATA_CHANNEL, packet);
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "subscribe")
        {
            lookup += ".subscribers";
            list subscribers = llJson2List(llLinksetDataRead(lookup));
            if(llListFindList(subscribers, [(string)object]) != -1); // Already subscribed
            else
            {
                subscribers += object;
                llLinksetDataWrite(lookup, llList2Json(JSON_ARRAY, subscribers));
            }
            
            packet = llList2Json(JSON_OBJECT, [
                "event", eventName + ".subscribed",
                "identifier", identifier
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
        }
        
        //--------------------------------------------------------------------------------------
        
        else if(eventAction == "unsubscribe")
        {
            lookup += ".subscribers";
            list subscribers = llJson2List(llLinksetDataRead(lookup));
            integer index = llListFindList(subscribers, [(string)object]);
            if(index == -1); // Already unsubscribed
            else
            {
                subscribers = llDeleteSubList(subscribers, index, index);
                llLinksetDataWrite(lookup, llList2Json(JSON_ARRAY, subscribers));
            }
            
            packet = llList2Json(JSON_OBJECT, [
                "event", eventName + ".unsubscribed",
                "identifier", identifier
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
        }
        
        //--------------------------------------------------------------------------------------
        
        else
        {
            string type;
            if(isEntity) type = "entity";
            else if(isSingleton) type = "singleton";
            
            packet = llList2Json(JSON_OBJECT, [
                "event", "error",
                "code", 405,
                "description", "Not a valid action '" + eventAction + "' for " + type
            ]);
            llRegionSayTo(object, DATA_CHANNEL, packet);
        }
        
        //--------------------------------------------------------------------------------------
        
        @end;
        
        if(subscribersPacket)
        {
            integer index; integer length;
            for(index = 0, length = llGetListLength(subscribers); index < length; ++index)
            {
                string subscriber = llList2String(subscribers, index);
                llRegionSayTo(subscriber, DATA_CHANNEL, subscribersPacket);
            }
        }
    }
}
