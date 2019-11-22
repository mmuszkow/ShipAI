require("dock.nut");
require("industry.nut");
require("global.nut");
require("maintenance.nut");
require("pf_water.nut");
require("town.nut");
require("utils.nut");

/* Water utils. */
class Water {
    /* Min Manhattan distance between 2 points to open a new connection. */
    min_distance = 20;
    /* Max Manhattan distance between 2 points to open a new connection. */
    max_distance = 300;
    /* Max path length. */
    max_path_len = 400;
    /* Max dock distance from the city center. */
    max_city_dock_distance = 15;
    /* Max path parts. */
    max_parts = 1;

    /* Maintenance helper. */
    maintenance = null;
    /* Cache for points that are not connected. */
    _not_connected_cache = AIList();
    
    /* Pathfinder. */
    pf = WaterPathfinder();
    
    constructor(maintenance) {
        this.maintenance = maintenance;
    }
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

function Water::WaitToHaveEnoughMoney(cost) {
    while(cost + 2 * AICompany.GetLoanInterval() >
          AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) 
        + AICompany.GetBankBalance(AICompany.COMPANY_SELF)) {}
}

function Water::GetTownsThatCanHaveOrHaveDock(cargo, towns = AITownList()) {
    /* Randomize, to process towns in random order. */
    towns.Valuate(AIBase.RandItem);
    towns.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

    /* To avoid exceeding CPU limit in Valuator, we split the list in parts */
    local merged = AIList();
    local start_time = AIDate.GetCurrentDate();
    for(local i=0; i<towns.Count(); i+=25) {
        local chunk = AIList();
        chunk.AddList(towns);
        chunk.RemoveTop(i);
        chunk.KeepTop(25);
        chunk.Valuate(_val_TownCanHaveOrHasDock, this.max_city_dock_distance, cargo);
        chunk.RemoveValue(0);
        merged.AddList(chunk);

        /* On big maps this can take forever, we stop after 6 months. */
        if(AIDate.GetCurrentDate() - start_time > 180)
            break;
    }
    return merged;
}

function Water::BuildShip(depot, cargo, round_trip_distance, monthly_production) {    
    local engine = ship_model.GetBestModelForCargo(cargo, round_trip_distance, monthly_production);
    if(!AIEngine.IsValidEngine(engine)) {
        AILog.Error("No vehicle model to transport " + AICargo.GetCargoLabel(cargo) +
                    " with monthly production = " + monthly_production +
                    " and distance = " + round_trip_distance);
        return -1;
    }

    /* Get price. */
    local vehicle_price = AIEngine.GetPrice(engine);
    if(!AIEngine.IsValidEngine(engine) || vehicle_price < 0) {
        AILog.Error("The chosen vehicle model is no longer produced");
        return -1;
    }
    WaitToHaveEnoughMoney(vehicle_price);
        
    local vehicle = AIVehicle.BuildVehicle(depot, engine);
    local last_err = AIError.GetLastErrorString();
    if(!AIVehicle.IsValidVehicle(vehicle)) {
        AILog.Error("Failed to build the ship in depot #" + depot + ": " + last_err);
        return -1;
    }
    
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

function Water::FindVehicleServingRoute(dock1, dock2, depot, cargo) {
    if(!dock1.IsValidStation() || !dock2.IsValidStation())
        return -1; 

    local vehicles = dock1.GetVehicles();
    vehicles.KeepList(dock2.GetVehicles());
    vehicles.KeepList(AIVehicleList_Depot(depot));
    vehicles.Valuate(AIVehicle.GetCapacity, cargo);
    vehicles.KeepAboveValue(0);
    if(vehicles.IsEmpty())
        return -1;
   
    /* Return the one with the lowest profit last year as we check this value later. */
    vehicles.Valuate(AIVehicle.GetProfitLastYear);
    vehicles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return vehicles.Begin();
}

function Water::BuildAndStartShip(dock1, dock2, cargo, full_load, use_canals, monthly_production) {
    if(monthly_production <= 0 || !ship_model.ExistsForCargo(cargo))
        return false;
    
    /* Too close or too far. */
    local dist = AIMap.DistanceManhattan(dock1.tile, dock2.tile);
    if(dist < this.min_distance || dist > this.max_distance)
        return false;
   
    local depot = dock1.FindWaterDepot();
    if(depot != -1) {
        /* If we already have a vehicle serving this route, we just clone it. */ 
        local existing_vehicle = FindVehicleServingRoute(dock1, dock2, depot, cargo);
        if(existing_vehicle != -1) {
            /* If the existing vehicle brings only losses/minimal gain it means that route is not worth it. */
            if(AIVehicle.GetProfitThisYear(existing_vehicle) < 100
            && AIVehicle.GetProfitLastYear(existing_vehicle) < 100)
                return false;

            /* Get price. */
            local engine = AIVehicle.GetEngineType(existing_vehicle);
            local vehicle_price = AIEngine.GetPrice(engine);
            if(!AIEngine.IsValidEngine(engine) || vehicle_price < 0) {
                AILog.Error("The chosen vehicle model is no longer produced");
                return false;
            }
            WaitToHaveEnoughMoney(vehicle_price);

            local vehicle = AIVehicle.CloneVehicle(depot, existing_vehicle, true);
            if(!AIVehicle.IsValidVehicle(vehicle)) {
                AILog.Error("Failed to clone ship: " + AIError.GetLastErrorString());
                return false;
            }    
 
            if(!AIVehicle.StartStopVehicle(vehicle)) {
                AILog.Error("Failed to start the ship: " + AIError.GetLastErrorString());
                AIVehicle.SellVehicle(vehicle);
                return false;
            }

            return true;
        }
    } else if(!dock1.CanHaveWaterDepotBuilt()) /* if we cannot build the depot, we won't be able to built the ship. */
        return false;

    /* No possible water connection. */
    if(!pf.FindPath(dock1, dock2, this.max_path_len, this.max_parts, use_canals))
        return false;
 
    /* Build infrastructure. */
    WaitToHaveEnoughMoney(dock1.EstimateCost());
    if(dock1.Build() == -1) {
        local err_str = AIError.GetLastErrorString();
        local x = AIMap.GetTileX(dock1.tile);
        local y = AIMap.GetTileY(dock1.tile);
        AILog.Error("Failed to build the dock at (" + x + "," + y + "): " + err_str);
        return false;
    }
    WaitToHaveEnoughMoney(dock2.EstimateCost());
    if(dock2.Build() == -1) {
        local err_str = AIError.GetLastErrorString();
        local x = AIMap.GetTileX(dock2.tile);
        local y = AIMap.GetTileY(dock2.tile);
        AILog.Error("Failed to build the dock at (" + x + "," + y + "): " + err_str);
        return false;
    }
    WaitToHaveEnoughMoney(pf.EstimateCanalsCost());
    if(!pf.BuildCanals())
        return false;
    if(depot == -1) {
        WaitToHaveEnoughMoney(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
        depot = dock1.BuildWaterDepot();
    }
    if(depot == -1) {
        AILog.Error("Failed to build the water depot near " + dock1.GetName());
        return false;
    }
    local vehicle = BuildShip(depot, cargo, pf.Length() * 2, monthly_production);
    if(!AIVehicle.IsValidVehicle(vehicle)) {
        AILog.Error("Failed to build the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route");
        return false;
    }
 
    /* Build buoys every n tiles. */
    WaitToHaveEnoughMoney(pf.EstimateBuoysCost());
    local buoys = pf.BuildBuoys();
    
    /* Schedule path. */
    local load_order = full_load ? AIOrder.OF_FULL_LOAD : AIOrder.OF_NONE;
    
    if(!AIOrder.AppendOrder(vehicle, depot, AIOrder.OF_SERVICE_IF_NEEDED)) {
        AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (1): " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }

    if(!AIOrder.AppendOrder(vehicle, dock1.tile, load_order)) {
        AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (2): " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* Buoys. */
    foreach(buoy in buoys)
        if(!AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE)) {
            AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (3): " + AIError.GetLastErrorString());
            AIVehicle.SellVehicle(vehicle);
            return false;
        }
        
    if(!AIOrder.AppendOrder(vehicle, dock2.tile, AIOrder.OF_NONE)) {
        AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (4): " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* The way back buoys. */
    buoys.reverse();
    foreach(buoy in buoys)
        if(!AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE)) {
            AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (5): " + AIError.GetLastErrorString());
            AIVehicle.SellVehicle(vehicle);
            return false;
        }
        
    if(!AIVehicle.StartStopVehicle(vehicle)) {
        AILog.Error("Failed to start the ship: " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    return true;
}
