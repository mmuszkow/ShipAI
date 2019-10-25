require("ferry.nut");
require("freight.nut");
require("utils.nut");

class ShipAI extends AIController {
    constructor() {}
}

function ShipAI::Save() { return {}; }

function ShipAI::Start() {
    SetCompanyName();    
    
    local freight = Freight();
    local ferry = Ferry();
    
    /* Check if we have anything to do, if not repay the loan and wait. */
    if(!freight.AreShipsAllowed()) {
        AILog.Warning("Not possible to build ships - falling asleep");
        AICompany.SetLoanAmount(0);
    }
    while(!freight.AreShipsAllowed()) { this.Sleep(1000); }
    
    /* Get max loan. */
    AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
    
    while(true) {          
        /* Build industry-industry & industry-town connections. */
        local new_freights = freight.BuildIndustryFreightRoutes();
        new_freights += freight.BuildTownFreightRoutes();
        
        /* Build town-town connections. */
        local new_ferries = ferry.BuildFerryRoutes();

        /* Return the loan if we have the money. */
        if( AICompany.GetBankBalance(AICompany.COMPANY_SELF) - 
            AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) -
            2 * AICompany.GetLoanInterval() > AICompany.GetLoanAmount())
            AICompany.SetLoanAmount(0);
        
        /* Build statues if we have a lot of money left, they increase the stations ratings. */
        local statues_founded = BuildStatuesIfRich();
        
        /* Print summary/ */
        if(new_freights > 0) AILog.Info("New freight routes: " + new_freights);
        if(new_ferries > 0) AILog.Info("New ferry routes: " + new_ferries);
        if(statues_founded > 0) AILog.Info("Statues founded: " + statues_founded);
        
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

function ShipAI::WeAreRich() {
    return AICompany.GetBankBalance(AICompany.COMPANY_SELF) -
           AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) >
           10 * AICompany.GetMaxLoanAmount();
}

/* Build statues in the cities we have any station. */
function ShipAI::BuildStatuesIfRich() {
    local founded = 0;
   
    if(!WeAreRich())
        return founded;
    
    local towns = AITownList();
    towns.Valuate(AITown.GetRating, AICompany.COMPANY_SELF);
    towns.RemoveValue(AITown.TOWN_RATING_NONE);
    towns.Valuate(AITown.HasStatue);
    towns.KeepValue(0);
    towns.Valuate(AITown.IsActionAvailable, AITown.TOWN_ACTION_BUILD_STATUE);
    towns.KeepValue(1);
    
    for(local town = towns.Begin(); !towns.IsEnd(); town = towns.Next()) {
        if(!WeAreRich())
            return founded;
        if(AITown.PerformTownAction(town, AITown.TOWN_ACTION_BUILD_STATUE)) {
            AILog.Info("Building statue in " + AITown.GetName(town));
            founded++;
        } else
            AILog.Error("Failed to build statue in " + AITown.GetName(town) + ": " + AIError.GetLastErrorString());
    }
    
    return founded;
}

