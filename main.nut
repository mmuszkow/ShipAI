require("ferry.nut");
require("freight.nut");
require("maintenance.nut");
require("terraforming.nut");
require("utils.nut");

class ShipAI extends AIController {
    /* Water construction utils. */
    _water = Water();
    
    constructor() {}
}

function ShipAI::Save() { return {}; }


function ShipAI::Start() {
    SetCompanyName();    
    
    local freight = FreightShip();
    local ferry = Ferry();
    local maintenance = Maintenance();
    local terra = Terraforming();
    
    /* Check if we have anything to do, if not repay the loan and wait. */
    if(!this._water.AreShipsAllowed()) {
        AILog.Warning("Not possible to build ships - falling asleep");
        AICompany.SetLoanAmount(0);
    }
    while(!this._water.AreShipsAllowed()) { this.Sleep(1000); }
    
    local loan_limit = AICompany.GetMaxLoanAmount();
    AICompany.SetLoanAmount(loan_limit);
    
    local cargos = AICargoList();
    while(true) {    
        /* Build new ships. */
        local new_freights = freight.BuildIndustryFreightRoutes();
        new_freights += freight.BuildTownFreightRoutes();
        local new_ferries = ferry.BuildFerryRoutes();
        
        /* Sell unprofiltable vehicles. */
        local unprofitable_sold = maintenance.SellUnprofitable();

        local upgraded = 0;
        for(local cargo = cargos.Begin(); cargos.HasNext(); cargo = cargos.Next())
            upgraded += maintenance.UpgradeModel(AIVehicle.VT_WATER, this._water.GetBestShipModelForCargo(cargo), cargo);
        
        /* Build statues when nothing better to do, they increase the stations rating. */
        local statues_founded = 0;
        if(new_freights == 0 && new_ferries == 0 && upgraded == 0)
            statues_founded = BuildStatues();
        
        /* Print summary/ */
        if(new_freights > 1) AILog.Info("New freight routes: " + new_freights);
        if(new_ferries > 1) AILog.Info("New ferry routes: " + new_ferries);
        if(unprofitable_sold > 0) AILog.Info("Unprofitable vehicles sold: " + unprofitable_sold);
        if(upgraded > 0) AILog.Info("Ships sent for upgrading: " + upgraded);
        if(statues_founded > 1) AILog.Info("Statues founded: " + statues_founded);
        
        terra.BuildCanals();
        
        AICompany.SetLoanAmount(0);        
        this.Sleep(50);
    }
}
 
function ShipAI::SetCompanyName() {
    if(!AICompany.SetName("ShipAI")) {
        local i = 2;
        while(!AICompany.SetName("ShipAI #" + i)) {
            i = i + 1;
            if(i > 255) break;
        }
    }
    
    if(AICompany.GetPresidentGender(AICompany.COMPANY_SELF) == AICompany.GENDER_MALE)
        AICompany.SetPresidentName("Mr. Moshe Goldbaum");
    else
        AICompany.SetPresidentName("Mrs. Rivkah Blumfeld");
}

/* Build statues in the cities we have any stations. */
function ShipAI::BuildStatues() {
    local founded = 0;
    
    if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 10000000)
        return founded;
    
    local towns = AITownList();
    towns.Valuate(AITown.GetRating, AICompany.COMPANY_SELF);
    towns.RemoveValue(AITown.TOWN_RATING_NONE);
    towns.Valuate(AITown.HasStatue);
    towns.KeepValue(0);
    towns.Valuate(AITown.IsActionAvailable, AITown.TOWN_ACTION_BUILD_STATUE);
    towns.KeepValue(1);
    
    for(local town = towns.Begin(); towns.HasNext(); town = towns.Next()) {
        if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 10000000)
            return founded;
        if(AITown.PerformTownAction(town, AITown.TOWN_ACTION_BUILD_STATUE)) {
            AILog.Info("Building statue in " + AITown.GetName(town));
            founded++;
        } else
            AILog.Error("Failed to build statue in " + AITown.GetName(town) + ": " + AIError.GetLastErrorString());
    }
    
    return founded;
}
