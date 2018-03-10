class ShipAI extends AIInfo {
    function GetAuthor()      { return "mmuszkow"; }
    function GetName()        { return "ShipAI"; }
    function GetDescription() { return "AI using only ships"; }
    function GetVersion()     { return 5; }
    function GetDate()        { return "2018-03-07"; }
    function GetAPIVersion () { return "1.0"; } /* for AIMarine.GetBuildCost */
    function GetURL()         { return "https://www.tt-forums.net/viewtopic.php?f=65&t=75531"; }
    function CreateInstance() { return "ShipAI"; }
    function GetShortName()   { return "SHIP"; }
    function GetSettings() {
        AddSetting({
            name = "build_canals",
            description = "Build canals (experimental)",
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });
    }
}

RegisterAI(ShipAI());

