class ShipAI extends AIInfo {
    function GetAuthor()      { return "mmuszkow"; }
    function GetName()        { return "ShipAI"; }
    function GetDescription() { return "AI using only ships"; }
    function GetVersion()     { return 10; }
    function GetDate()        { return "2019-11-11"; }
    function GetAPIVersion () { return "1.2"; } /* for AICompany.GetQuarterlyExpenses */
    function GetURL()         { return "https://www.tt-forums.net/viewtopic.php?f=65&t=75531"; }
    function CreateInstance() { return "ShipAI"; }
    function GetShortName()   { return "SHIP"; }
    function GetSettings() {
        AddSetting({
            name = "build_canals",
            description = "Build canal infrastructure",
            easy_value = 1,
            medium_value = 1,
            hard_value = 1,
            custom_value = 1,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });
    }
}

RegisterAI(ShipAI());

