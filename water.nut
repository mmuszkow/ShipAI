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
    
    constructor() {
        maintenance = Maintenance();
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

function Water::GetTownsThatCanHaveDock(cargo, towns = AITownList()) {
    /* To avoid exceeding CPU limit in Valuator, we split the list in parts */
    local merged = AIList();
    for(local i=0; i<towns.Count(); i+=50) {
        local splitted = AIList();
        splitted.AddList(towns);
        splitted.RemoveTop(i);
        splitted.KeepTop(50);
        splitted.Valuate(_val_TownCanHaveDock, this.max_city_dock_distance, cargo);
        splitted.RemoveValue(0);
        merged.AddList(splitted);
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
    local station1 = AIStation.GetStationID(dock1.tile);
    if(!AIStation.IsValidStation(station1))
        return -1;

    local station2 = AIStation.GetStationID(dock2.tile);
    if(!AIStation.IsValidStation(station2))
        return -1;

    local vehicles = AIVehicleList_Station(station1);
    vehicles.KeepList(AIVehicleList_Station(station2));
    vehicles.KeepList(AIVehicleList_Depot(depot));
    vehicles.Valuate(AIVehicle.GetCapacity, cargo);
    vehicles.KeepAboveValue(0);
    if(vehicles.IsEmpty())
        return -1;
    
    return vehicles.Begin();
}

function Water::BuildAndStartShip(dock1, dock2, cargo, full_load, monthly_production) {
    if(monthly_production <= 0 || !ship_model.ExistsForCargo(cargo))
        return false;
    
    /* Too close or too far. */
    local dist = AIMap.DistanceManhattan(dock1.tile, dock2.tile);
    if(dist < this.min_distance || dist > this.max_distance)
        return false;
   
    /* If we already have a vehicle serving this route, we just clone it. */ 
    local depot = dock1.FindWaterDepot();
    if(depot != -1) {
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
    } 

    /* No possible water connection. */
    if(!pf.FindPath(dock1, dock2, this.max_path_len, this.max_parts))
        return false;
 
    /* Build infrastructure. */
    WaitToHaveEnoughMoney(dock1.EstimateCost());
    if(dock1.Build() == -1) {
        AILog.Error("Failed to build dock: " + AIError.GetLastErrorString());
        return false;
    }
    if(depot == -1) {
        WaitToHaveEnoughMoney(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
        depot = dock1.BuildWaterDepot();
    }
    if(depot == -1) {
        AILog.Error("Failed to build the water depot near " + dock1.GetName() + ": " + AIError.GetLastErrorString());
        return false;
    }
    WaitToHaveEnoughMoney(dock2.EstimateCost());
    if(dock2.Build() == -1) {
        AILog.Error("Failed to build dock: " + AIError.GetLastErrorString());
        return false;
    }
    WaitToHaveEnoughMoney(pf.EstimateCanalsCost());
    if(!pf.BuildCanals()) {
        AILog.Error("Failed to build the canal for " + dock1.GetName() + "-" + dock2.GetName() + " route: " + AIError.GetLastErrorString());
        return false;
    }
    local vehicle = BuildShip(depot, cargo, pf.Length() * 2, monthly_production);
    if(!AIVehicle.IsValidVehicle(vehicle)) {
        AILog.Error("Failed to build ship for " + dock1.GetName() + "-" + dock2.GetName() + " route");
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
