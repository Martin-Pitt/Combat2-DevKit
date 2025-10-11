default
{
    state_entry()
    {
        llLinksetDataWrite("MEBCS_Teams", llList2Json(JSON_ARRAY, [
            llList2Json(JSON_OBJECT, ["name", "unassigned", "color", <0,0,0>]),
            llList2Json(JSON_OBJECT, ["name", "Defenders", "color", <0,0.5,1>]),
            llList2Json(JSON_OBJECT, ["name", "Attackers", "color", <1,0,0>])
        ]));
        llLinksetDataWrite("MEBCS_Team.0", llList2Json(JSON_ARRAY, []));
        llLinksetDataWrite("MEBCS_Team.1", llList2Json(JSON_ARRAY, []));
        llLinksetDataWrite("MEBCS_Team.2", llList2Json(JSON_ARRAY, []));
    }
}
