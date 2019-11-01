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

    local iter = 0;    
    while(true) {
        /* To speed-up the path finding, we search for the more complicated paths rarely. */
        if(iter % 11 == 5) {
            freight.max_parts = 2;
            ferry.max_parts = 2;
        } else if(iter % 11 == 10) {
            freight.max_parts = 3;
            ferry.max_parts = 3;
        } else {
            freight.max_parts = 1;
            ferry.max_parts = 1;
        }
      
        /* Build industry-industry & industry-town connections. */
        local new_freights = freight.BuildIndustryFreightRoutes();
        new_freights += freight.BuildTownFreightRoutes();
        freight.maintenance.PerformIfNeeded();
        
        /* Build town-town connections. */
        local new_ferries = ferry.BuildFerryRoutes();
        ferry.maintenance.PerformIfNeeded();

        /* Return the loan if we have the money. */
        if( AICompany.GetBankBalance(AICompany.COMPANY_SELF) - 
            AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) -
            2 * AICompany.GetLoanInterval() > AICompany.GetLoanAmount())
            AICompany.SetLoanAmount(0);
        
        /* Build statues if we have a lot of money left, they increase the stations ratings. */
        local statues_founded = BuildStatuesIfRich();
       
        /* Same with trees. */
        local trees_planted = (statues_founded > 0) ? 0 : PlantTreesIfRich();
 
        /* Print summary/ */
        if(new_freights > 0) AILog.Info("New freight routes: " + new_freights);
        if(new_ferries > 0) AILog.Info("New ferry routes: " + new_ferries);
        if(statues_founded > 0) AILog.Info("Statues founded: " + statues_founded);
        if(trees_planted > 0) AILog.Info("Trees planted: " + trees_planted);

        /* HQ will boost our eco in one city. */
        BuildHQ();

        this.Sleep(50);
        iter++;
    }
}

/* To check if tile can have HQ built on, HQ is 2x2. */
function _val_CanHaveHQ(tile) {
    return AITile.IsBuildable(tile) &&
           AITile.IsBuildable(tile + SOUTH) &&
           AITile.IsBuildable(tile + WEST) &&
           AITile.IsBuildable(tile + AIMap.GetTileIndex(1, 1));
}

function ShipAI::BuildHQ() {
    /* Check if we have HQ already built. */
    if(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) != AIMap.TILE_INVALID)
        return true;

    /* Get towns we have presence in (we have already built a port). */
    local towns = AITownList();
    towns.Valuate(AITown.GetRating, AICompany.COMPANY_SELF);
    towns.RemoveValue(AITown.TOWN_RATING_NONE);
    towns.Valuate(AITown.GetPopulation);
    towns.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

    for(local town = towns.Begin(); !towns.IsEnd(); town = towns.Next()) {
        /* Get our dock location in the biggest city. */
        local stations = AIStationList(AIStation.STATION_DOCK);
        stations.Valuate(AIStation.IsWithinTownInfluence, town);
        if(stations.IsEmpty())
            continue;
        local station = stations.Begin();
        local dock = AIStation.GetLocation(station);

        /* Get tiles around our dock sorted by distance from dock. */
        local location = AITileList();
        SafeAddRectangle(location, dock, 10);
        location.Valuate(_val_CanHaveHQ);
        location.KeepValue(1);
        if(location.IsEmpty())
            continue;
        location.Valuate(AITile.GetDistanceSquareToTile, dock);
        location.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
       
        /* Rename the dock. */ 
        if(AICompany.BuildCompanyHQ(location.Begin())) {
            AIStation.SetName(station, "ShipAI Headquarters");
            return true;
        }
    }

    return false;
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

function ShipAI::PlantTreesIfRich() {
    local planted = 0;
    if(!WeAreRich())
        return planted;

    local towns = AITownList();
    towns.Valuate(AITown.GetRating, AICompany.COMPANY_SELF);
	towns.KeepBelowValue(AITown.TOWN_RATING_GOOD);
	towns.RemoveValue(AITown.TOWN_RATING_NONE);
	towns.RemoveValue(AITown.TOWN_RATING_INVALID);    
    towns.Valuate(AITown.GetPopulation);
    towns.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

    local start = AIDate.GetCurrentDate();
    
    for(local town_id = towns.Begin(); !towns.IsEnd(); town_id = towns.Next()) {
        /* We plant trees for 3 months max */
        if(AIDate.GetCurrentDate() - start > 90)
            return founded;        
        
        local area = Town(town_id).GetArea();
        area.Valuate(AITile.IsBuildable);
        area.KeepValue(1);
        area.Valuate(AIBase.RandItem);
        for(local tile = area.Begin(); !area.IsEnd(); tile = area.Next()) {
            if(AITile.PlantTree(tile))
                planted++;
        }
    }

    return planted;
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

