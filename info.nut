class ShipAI extends AIInfo {
    function GetAuthor()      { return "mmuszkow"; }
    function GetName()        { return "ShipAI"; }
    function GetDescription() { return "AI using only ships"; }
    function GetVersion()     { return 8; }
    function GetDate()        { return "2019-11-05"; }
    function GetAPIVersion () { return "1.2"; } /* for AICompany.GetQuarterlyExpenses */
    function GetURL()         { return "https://www.tt-forums.net/viewtopic.php?f=65&t=75531"; }
    function CreateInstance() { return "ShipAI"; }
    function GetShortName()   { return "SHIP"; }
    function GetSettings() {
        AddSetting({
            name = "build_canals",
            description = "Build canals",
            easy_value = 1,
            medium_value = 1,
            hard_value = 1,
            custom_value = 1,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });
        AddSetting({
            name = "build_interlocks",
            description = "Build locks between canals",
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });
        AddSetting({
            name = "build_aqueducts",
            description = "Build aqueducts",
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });

    }
}

RegisterAI(ShipAI());

