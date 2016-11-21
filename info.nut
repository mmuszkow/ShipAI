class ShipAI extends AIInfo {
	function GetAuthor()      { return "mmuszkow"; }
	function GetName()        { return "ShipAI"; }
	function GetDescription() { return "AI using only ships"; }
	function GetVersion()     { return 1; }
	function GetDate()        { return "2016-10-30"; }
	function CreateInstance() { return "ShipAI"; }
	function GetShortName()   { return "SHIP"; }
}

RegisterAI(ShipAI());
