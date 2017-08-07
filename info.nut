class ShipAI extends AIInfo {
	function GetAuthor()      { return "mmuszkow"; }
	function GetName()        { return "ShipAI"; }
	function GetDescription() { return "AI using only ships"; }
	function GetVersion()     { return 3; }
	function GetDate()        { return "2017-09-07"; }
	function CreateInstance() { return "ShipAI"; }
	function GetShortName()   { return "SHIP"; }
    function GetSettings() {
        AddSetting({
            name = "build_canals",
            description = "Build canals",
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME
        });
    }
}

RegisterAI(ShipAI());
