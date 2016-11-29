require("vehicle_model.nut");
require("utils.nut");

/* Water utils. */
class Water {
    /* Max connection length. */
    max_path_len = 450;
    /* Max dock distance from the city center. */
    max_dock_distance = 20;
    /* Minimal money left after buying something. */
    min_balance = 20000;
    /* Path buoys distance. */
    buoy_distance = 25;
    
    constructor() {}
}

/* These functions needs to be global so we can use them in Valuate. */
function GetCoastTilesNearTown(town, range, cargo_id) {
    local city = AITown.GetLocation(town);
    local tiles = AITileList();
    SafeAddRectangle(tiles, city, range);
    tiles.Valuate(AITile.IsCoastTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.IsBuildable);
    tiles.KeepValue(1);
    tiles.Valuate(IsSimpleSlope);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetClosestTown);
    tiles.KeepValue(town);
    /* Tile must accept passangers. */
    tiles.Valuate(AITile.GetCargoAcceptance, cargo_id, 1, 1,
                  AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    tiles.KeepAboveValue(7); /* as doc says */
    return tiles;
}
function GetCoastTileNearestTown(town, range, cargo_id) {
    local tiles = GetCoastTilesNearTown(town, range, cargo_id);
    if(tiles.IsEmpty())
        return -1;
    
    local city = AITown.GetLocation(town);
    tiles.Valuate(AIMap.DistanceManhattan, city);
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return tiles.Begin();
}
function GetCoastTilesNearIndustry(industry, is_producer) {
    local tiles;
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    if(is_producer)
        tiles = AITileList_IndustryProducing(industry, radius);
    else
        tiles = AITileList_IndustryAccepting(industry, radius);
    tiles.Valuate(AITile.IsCoastTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.IsBuildable);
    tiles.KeepValue(1);
    tiles.Valuate(IsSimpleSlope);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetDistanceManhattanToTile, AIIndustry.GetLocation(industry));
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return tiles;
}
function GetCoastTileNearestIndustry(industry, is_producer) {
    local tiles = GetCoastTilesNearIndustry(industry, is_producer);
    if(tiles.IsEmpty())
        return -1;
    
    local loc = AIIndustry.GetLocation(industry);
    tiles.Valuate(AIMap.DistanceManhattan, loc);
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return tiles.Begin();
}
function IndustryCanHaveDock(industry, is_producer) {
    return AIIndustry.HasDock(industry) || !GetCoastTilesNearIndustry(industry, is_producer).IsEmpty();
}

/* Checks if building ships is possible. */
function Water::AreShipsAllowed() {
    /* Ships disabled. */
    if(AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_WATER))
        return false;
    
    /* Max 0 ships. */
    local veh_allowed = AIGameSettings.GetValue("vehicle.max_ships");
    if(veh_allowed == 0)
        return false;
    
    /* Current ships < ships limit. */
    local veh_list = AIVehicleList();
    veh_list.Valuate(AIVehicle.GetVehicleType);
    veh_list.KeepValue(AIVehicle.VT_WATER);
    if(veh_list.Count() >= veh_allowed)
        return false;
    
    return true;
}

function Water::BuildShip(depot, cargo, round_trip_distance, monthly_production) {
    local engine = GetBestVehicleModelForCargo(AIVehicle.VT_WATER, cargo, round_trip_distance, monthly_production);
    if(!AIEngine.IsValidEngine(engine))
        return -1;
        
    /* Wait until we have the money. */
    while(AIEngine.IsValidEngine(engine) && 
        (AIEngine.GetPrice(engine) > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance)) {}
        
    local vehicle = AIVehicle.BuildVehicle(depot, engine);
    if(!AIVehicle.IsValidVehicle(vehicle))
        return -1;
    
    /* Refit if needed. */
    if(AIEngine.GetCargoType(engine) != cargo) {
        if(AIVehicle.RefitVehicle(vehicle, cargo))
            AIVehicle.SetName(vehicle, AICargo.GetCargoLabel(cargo) + " #" + vehicle);
        else {
            AILog.Error("Failed to refit the ship: " + AIError.GetLastErrorString());
            AIVehicle.SellVehicle(vehicle);
            return -1;
        }
    }    
    
    return vehicle;
}

function Water::FindDockNearTown(town, cargo) {
    local docks = AIStationList(AIStation.STATION_DOCK);
    docks.Valuate(AIStation.GetNearestTown);
    docks.KeepValue(town);
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    for(local dock = docks.Begin(); docks.HasNext(); dock = docks.Next()) {
        local dock_loc = AIStation.GetLocation(dock);
        if(AITile.GetCargoAcceptance(dock_loc, cargo, 1, 1, radius) > 7)
            return dock_loc;
    }
    return -1;
}

function Water::BuildDockInTown(town, cargo) {
    local coast = GetCoastTilesNearTown(town, this.max_dock_distance, cargo);
    local city = AITown.GetLocation(town);
    coast.Valuate(AIMap.DistanceManhattan, city);
    coast.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    
    /* Wait until we have the money. */
    while(AIMarine.GetBuildCost(AIMarine.BT_DOCK) > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance) {}
    
    for(local tile = coast.Begin(); coast.HasNext(); tile = coast.Next()) {
        if(AIMarine.BuildDock(tile, AIStation.STATION_NEW))
            return tile;
    }
    return -1;
}

function Water::FindDockNearIndustry(industry, is_producer) {
    if(AIIndustry.HasDock(industry))
        return AIIndustry.GetDockLocation(industry);
    
    local tiles;
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    if(is_producer)
        tiles = AITileList_IndustryProducing(industry, radius);
    else
        tiles = AITileList_IndustryAccepting(industry, radius);
    tiles.Valuate(AIMarine.IsDockTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetOwner);
    tiles.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
    if(!tiles.IsEmpty())
        return tiles.Begin();
    
    return -1;
}

function Water::BuildDockNearIndustry(industry, is_producer) {
    local coast = GetCoastTilesNearIndustry(industry, is_producer);
    coast.Valuate(AIMap.DistanceManhattan, AIIndustry.GetLocation(industry));
    coast.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    
    /* Wait until we have the money. */
    while(AIMarine.GetBuildCost(AIMarine.BT_DOCK) > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance) {}
    
    for(local tile = coast.Begin(); coast.HasNext(); tile = coast.Next()) {
        if(AIMarine.BuildDock(tile, AIStation.STATION_NEW))
            return tile;
    }
    return -1;
}

/* Buoys are essential for longer paths and also speed up the ship pathfinder. */
function Water::GetBuoy(tile) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, tile, 3);
    tiles.Valuate(AIMarine.IsBuoyTile);
    tiles.KeepValue(1);
    if(tiles.IsEmpty()) {
        AIMarine.BuildBuoy(tile);
        return tile;
    } else
        return tiles.Begin();
}

/* Finds water depot close to the dock. */
function Water::FindWaterDepot(dock, range) {
    local depots = AIDepotList(AITile.TRANSPORT_WATER);
    depots.Valuate(AIMap.DistanceManhattan, dock);
    depots.KeepBelowValue(range);
    depots.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    if(depots.IsEmpty())
        return -1;
    else
        return depots.Begin();
}

/* Builds water depot. */
function Water::BuildWaterDepot(dock, max_distance) {
    local depotarea = AITileList();
    SafeAddRectangle(depotarea, dock, max_distance);
    depotarea.Valuate(AITile.IsWaterTile);
    depotarea.KeepValue(1);
    depotarea.Valuate(AIMap.DistanceManhattan, dock);
    depotarea.KeepAboveValue(4); /* let's not make it too close to docks */
    depotarea.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    
    /* Wait until we have the money. */
    while(AIMarine.GetBuildCost(AIMarine.BT_DEPOT) > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance) {}
    
    for(local depot = depotarea.Begin(); depotarea.HasNext(); depot = depotarea.Next()) {
        local x = AIMap.GetTileX(depot);
        local y = AIMap.GetTileY(depot);
        local front = AIMap.GetTileIndex(x, y+1);
        
        /* To avoid building a depot on a river. */
        if(!AITile.IsWaterTile(front) ||
            !AITile.IsWaterTile(AIMap.GetTileIndex(x, y-1)) ||
            !AITile.IsWaterTile(AIMap.GetTileIndex(x-1, y)) ||
            !AITile.IsWaterTile(AIMap.GetTileIndex(x+1, y)))
            continue;
            
        if(AIMarine.BuildWaterDepot(depot, front))
            return depot;
    }
    return -1;
}

function Water::BuildAndStartShip(dock1, dock2, cargo, path, full_load, monthly_production) {
    if(!VehicleModelForCargoExists(AIVehicle.VT_WATER, cargo))
        return false;
    
    /* Find or build the water depot. Don't go too far to avoid finding depot from other lake/sea. */
    local depot = FindWaterDepot(dock1, 10);
    if(depot == -1) {
        depot = BuildWaterDepot(dock1, 10);
        if(depot == -1) {
            AILog.Error("Failed to build the water depot: " + AIError.GetLastErrorString());
            return false;
        }
    }
    
    local distance = path.len();
    local vehicle = BuildShip(depot, cargo, distance * 2, monthly_production);
    if(vehicle == -1) {
        AILog.Error("Failed to build the ship: " + AIError.GetLastErrorString());
        return false;
    }
    
    /* Build buoys every n tiles. */
    local buoys = [];
    for(local i = this.buoy_distance; i<distance-this.buoy_distance/2; i += this.buoy_distance)
        buoys.push(GetBuoy(path[i]));
    
    /* Schedule path. */
    local load_order = full_load ? AIOrder.OF_FULL_LOAD : AIOrder.OF_NONE;
    //if(full_load) {
        //local expected_cargo = (monthly_production * (distance * 2)) / 30.0;
        //AILog.Info("Expected cargo: " + expected_cargo);
        /* We don't do the full load if the capacity of the vehicle is too big. */
        //if(AIVehicle.GetCapacity(vehicle, cargo) < 2 * expected_cargo)
            //load_order = AIOrder.OF_FULL_LOAD;
    //}
    
    if(!AIOrder.AppendOrder(vehicle, dock1, load_order)) {
        AILog.Error("Failed to schedule the ship: " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* Buoys. */
    foreach(buoy in buoys)
        AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE);
        
    if(!AIOrder.AppendOrder(vehicle, dock2, AIOrder.OF_NONE)) {
        AILog.Error("Failed to schedule the ship: " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* The way back buoys. */
    buoys.reverse();
    foreach(buoy in buoys)
        AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE);
        
    /* Send for maintanance if too old. This is safer here, cause the vehicle won't get lost
       and also saves us some opcodes. */
    if(    !AIOrder.InsertConditionalOrder(vehicle, 0, 0)
        || !AIOrder.InsertOrder(vehicle, 1, depot, AIOrder.OF_NONE) /* why OF_SERVICE_IF_NEEDED doesn't work? */
        || !AIOrder.SetOrderCondition(vehicle, 0, AIOrder.OC_REMAINING_LIFETIME)
        || !AIOrder.SetOrderCompareFunction(vehicle, 0, AIOrder.CF_MORE_THAN)
        || !AIOrder.SetOrderCompareValue(vehicle, 0, 0)
        ) {
        AILog.Error("Failed to schedule the autoreplacement order: " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    //AIVehicle.SetName(vehicle, "");
    if(!AIVehicle.StartStopVehicle(vehicle)) {
        AILog.Error("Failed to start the ship: " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    return true;
}

/* 0 - no existing route, 1 - error, 2 - success */
function Water::CloneShip(dock1, dock2, cargo) {    
    /* Check if these 2 docks are indeed served by an existing vehicle. */
    local dock1_vehs = AIVehicleList_Station(AIStation.GetStationID(dock1));
    dock1_vehs.Valuate(AIVehicle.GetCapacity, cargo);
    dock1_vehs.KeepAboveValue(0);
    local dock2_vehs = AIVehicleList_Station(AIStation.GetStationID(dock2));
    dock1_vehs.KeepList(dock2_vehs);
    if(dock1_vehs.IsEmpty())
        return 0;
    
    /* Find the depot where we can clone the vehicle. */
    local depot = FindWaterDepot(dock1, 10);
    if(depot == -1)
        depot = FindWaterDepot(dock2, 10);
    if(depot == -1)
        depot = BuildWaterDepot(dock1, 10);
    if(depot == -1) {
        AILog.Error("Failed to build the water depot: " + AIError.GetLastErrorString());
        return 1;
    }
    
    local vehicle = dock1_vehs.Begin();
    local engine = AIVehicle.GetEngineType(vehicle);
    
    /* Wait until we have the money. */
    while(AIEngine.IsValidEngine(engine) && 
         (AIEngine.GetPrice(engine) > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance)) {}
    
    local cloned = AIVehicle.CloneVehicle(depot, vehicle, true);
    if(!AIVehicle.IsValidVehicle(cloned)) {
        if(AIError.GetLastError() != AIVehicle.ERR_VEHICLE_TOO_MANY)
            AILog.Error("Failed to clone vehicle: " + AIError.GetLastErrorString());
        return 1;
    }
    
    AIVehicle.StartStopVehicle(cloned);
    return 2;
}
