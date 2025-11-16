default
{
    state_entry()
    {
        // Define the team settings
        llLinksetDataWrite("C2_Teams_Config", llList2Json(JSON_ARRAY, [
            llList2Json(JSON_OBJECT, ["name", "unassigned", "color", <0,0,0>]), // Always leave this as-is, this is a special hardcoded unassigned team 0, per the Combat2.1 spec
            llList2Json(JSON_OBJECT, ["name", "Defenders", "color", <0,0.5,1>]),
            llList2Json(JSON_OBJECT, ["name", "Attackers", "color", <1,0,0>])
        ]));
        
        // Resetting the agent lists for each team to the initial value
        llLinksetDataWrite("C2_Teams.0", llList2Json(JSON_ARRAY, []));
        llLinksetDataWrite("C2_Teams.1", llList2Json(JSON_ARRAY, []));
        llLinksetDataWrite("C2_Teams.2", llList2Json(JSON_ARRAY, []));
        
        // Clearing out team assignments for agents/objects
        llLinksetDataDeleteFound("^C2_Teams:", "");
    }
}
