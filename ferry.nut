/* Ferries part of AI.
   Builds ferries/hovercrafts. */

require("water.nut");

class Ferry extends Water {
    /* Open new connections only in cities with this population. */
    min_population = 500;
    
    /* Passengers cargo id. */
    _passenger_cargo_id = -1;
    
    constructor(maintenance) {
        Water.constructor(maintenance);
        this._passenger_cargo_id = _GetPassengersCargoId();
    }
}
   
function Ferry::AreFerriesAllowed() {
    return AreShipsAllowed() && ship_model.ExistsForCargo(this._passenger_cargo_id);
}

/* Gets passengers cargo ID. */
function Ferry::_GetPassengersCargoId() {
    local cargo_list = AICargoList();
    cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
    cargo_list.KeepValue(1);
    cargo_list.Valuate(AICargo.GetTownEffect);
    cargo_list.KeepValue(AICargo.TE_PASSENGERS);
    return cargo_list.Begin();
}

function Ferry::GetTownsThatCanHaveOrHavePassengerDockOrderedByPop() {
    local towns = AITownList();
    towns.Valuate(AITown.GetPopulation);
    towns.KeepAboveValue(this.min_population);
    
    local dock_capable = GetTownsThatCanHaveOrHaveDock(this._passenger_cargo_id, towns);
    dock_capable.Valuate(AITown.GetPopulation);
    dock_capable.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return dock_capable;
}

function Ferry::BuildFerryRoutes() {
    local ferries_built = 0;
    if(!this.AreFerriesAllowed())
        return 0;
    
    local min_capacity = ship_model.GetMinCapacityForCargo(this._passenger_cargo_id);
    if(min_capacity == -1)
        return 0;
        
    local towns = GetTownsThatCanHaveOrHavePassengerDockOrderedByPop();
 
    for(local town_id = towns.Begin(); !towns.IsEnd(); town_id = towns.Next()) {
        
        this.maintenance.PerformIfNeeded();
        
        local town = Town(town_id);
        local dock1 = town.GetExistingDock(this._passenger_cargo_id);
        
        /* Monthly production is used to determine the potential ship size. */
        if(town.GetMonthlyProduction(this._passenger_cargo_id) <= min_capacity)
            continue;
        
        if(dock1 != null) {
            if(dock1.HadOperatedCargo(this._passenger_cargo_id)) {
                /* If there is already an operated dock in the city and there 
                 * are not many passengers waiting there, there is no point
                 * in opening a new route. */
                if(dock1.GetCargoWaiting(this._passenger_cargo_id) < 2 * min_capacity)
                    continue;
            } else {
                /* We may have built a dock nearby city for a different cargo,
                 * which accept passengers but is far away from city center.
                 * Let's try to look for a better location. */
                local best_spot = town.GetBestCargoAcceptingBuildableCoastTile(this.max_city_dock_distance, this._passenger_cargo_id);
                if(best_spot != -1 && AIMap.DistanceManhattan(dock1.tile, best_spot) > 5) {
                    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
                    /* We use acceptance here because the passenger cargo is symmetric.
                     * This means - the more "passenger" tiles dock has in it's radius,
                     * the more passenger production it will have. */
                    local best_prod = AITile.GetCargoAcceptance(best_spot, this._passenger_cargo_id, 1, 1, radius);
                    local existing_prod = AITile.GetCargoAcceptance(dock1.tile, this._passenger_cargo_id, 1, 1, radius);
                    if(best_prod > existing_prod)
                        dock1.tile = best_spot;
                }
            }
        }

        /* Find a city suitable for connection closest to ours. */
        local towns2 = AIList();
        towns2.AddList(towns);
        towns2.RemoveItem(town_id);
        towns2.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_id));
        towns2.KeepBelowValue(this.max_distance); /* Cities too far away. */
        towns2.KeepAboveValue(this.min_distance); /* Cities too close. */
        
        for(local town2_id = towns2.Begin(); !towns2.IsEnd(); town2_id = towns2.Next()) {
            local town2 = Town(town2_id);
            local dock2 = town2.GetExistingDock(this._passenger_cargo_id);
            
            if(dock1 == null) {
                local coast1 = town.GetBestCargoAcceptingBuildableCoastTile(
                    this.max_city_dock_distance, this._passenger_cargo_id);
                if(coast1 != -1)
                    dock1 = Dock(coast1);
            }
            if(dock1 == null) {
                AILog.Warning(town.GetName() + " can no longer have the dock built nearby");
                break;
            }
            
            if(dock2 == null) {
                local coast2 = town2.GetBestCargoAcceptingBuildableCoastTile(
                    this.max_city_dock_distance, this._passenger_cargo_id);
                if(coast2 != -1)
                    dock2 = Dock(coast2);
            }
            if(dock2 == null) {
                AILog.Warning(town2.GetName() + " can no longer have the dock built nearby");
                continue;
            }
           
            /* Buy and schedule ship. */
            if(BuildAndStartShip(dock1, dock2, this._passenger_cargo_id, false, false, town.GetMonthlyProduction(this._passenger_cargo_id))) {
                AILog.Info("Building ferry between " + town.GetName() + " and " + town2.GetName());
                ferries_built++;
            } else if(!AreFerriesAllowed())
                return ferries_built;
        }
    }
            
    return ferries_built;
}
