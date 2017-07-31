/* Ferries part of AI.
   Builds ferries/hovercrafts. */

require("water.nut");

class Ferry extends Water {
    /* Open new connections only in cities with this population. */
    min_population = 500;
    
    /* Passengers cargo id. */
    _passenger_cargo_id = -1;
    
    constructor() {
        Water.constructor();
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

function Ferry::GetTownsThatCanHavePassengerDock() {
    local towns = AITownList();
    towns.Valuate(AITown.GetPopulation);
    towns.KeepAboveValue(this.min_population);
    towns.Valuate(_val_TownCanHaveDock, this.max_city_dock_distance, this._passenger_cargo_id);
    towns.RemoveValue(0);
    return towns;
}

/* Estimate passengers production per month. This is veeery rough. */
function Ferry::EstimatePassengersPerMonth(dock) {
    local station_id = AIStation.GetStationID(dock.tile);
    /* TODO */
    
    // it always return 0 ...
    //local cargo_per_month = AIStation.GetCargoPlanned(station_id, this._passenger_cargo_id);
    local cargo_per_month = AITile.GetCargoAcceptance(dock.tile, this._passenger_cargo_id, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    
    /* Some % of cargo is already transported. */
    if(AIStation.HasCargoRating(station_id, this._passenger_cargo_id))
        return (((100 - AIStation.GetCargoRating(station_id, this._passenger_cargo_id)) / 100.0) * cargo_per_month).tointeger()
    
    /* Virgin station. */
    return cargo_per_month;
}

function Ferry::BuildFerryRoutes() {
    local ferries_built = 0;
    if(!this.AreFerriesAllowed())
        return 0;
    
    SetCanalsAllowedFlag();
    
    local min_capacity = ship_model.GetMinCapacityForCargo(this._passenger_cargo_id);
    if(min_capacity == -1)
        return 0;
        
    local towns = GetTownsThatCanHavePassengerDock();
    
    for(local town_id = towns.Begin(); towns.HasNext(); town_id = towns.Next()) {
        
        this._maintenance.PerformIfNeeded();
        
        local town = Town(town_id);
        local dock1 = town.GetExistingDock(this._passenger_cargo_id);
        
        /* If there is already a dock in the city and there 
           are not many passengers waiting there, there is no point
           in opening a new route. */
        if(dock1 != null && AIStation.GetCargoWaiting(AIStation.GetStationID(dock1.tile), this._passenger_cargo_id) < 2 * min_capacity)
            continue;
        
        /* Find a city suitable for connection closest to ours. */
        local towns2 = AIList();
        towns2.AddList(towns);
        towns2.RemoveItem(town_id);
        towns2.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_id));
        towns2.KeepBelowValue(this.max_distance); /* Cities too far away. */
        towns2.KeepAboveValue(this.min_distance); /* Cities too close. */
        
        for(local town2_id = towns2.Begin(); towns2.HasNext(); town2_id = towns2.Next()) {
            local town2 = Town(town2_id);
            local dock2 = town2.GetExistingDock(this._passenger_cargo_id);
            
            /* If there is already a dock in the city and there 
               are not many passengers waiting there, there is no point
               in opening a new route. */
            if(dock2 != null && AIStation.GetCargoWaiting(AIStation.GetStationID(dock2.tile), this._passenger_cargo_id) < 2 * min_capacity)
                continue;
            
            if(dock1 == null) {
                local coast1 = town.GetBestCargoAcceptingCoastTile(this.max_city_dock_distance, this._passenger_cargo_id);
                if(coast1 != -1)
                    dock1 = Dock(coast1);
            }
            if(dock1 == null) {
                AILog.Warning(town.GetName() + " no longer can have the dock built nearby");
                break;
            }
            
            if(dock2 == null) {
                local coast2 = town2.GetBestCargoAcceptingCoastTile(this.max_city_dock_distance, this._passenger_cargo_id);
                if(coast2 != -1)
                    dock2 = Dock(coast2);
            }
            if(dock2 == null) {
                AILog.Warning(town2.GetName() + " no longer can have the dock built nearby");
                continue;
            }
            
            /* Buy and schedule ship. */
            local monthly_production = max(EstimatePassengersPerMonth(dock1), EstimatePassengersPerMonth(dock2));
            if(BuildAndStartShip(dock1, dock2, this._passenger_cargo_id, false, monthly_production)) {
                AILog.Info("Building ferry between " + town.GetName() + " and " + town2.GetName());
                ferries_built++;
            } else if(!AreFerriesAllowed())
                return ferries_built;
        }
    }
            
    this._maintenance.Perform();
    
    return ferries_built;
}
