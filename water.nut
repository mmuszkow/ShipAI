require("dock.nut");
require("industry.nut");
require("global.nut");
require("maintenance.nut");
require("ship_path.nut");
require("town.nut");
require("utils.nut");
require("pathfinder/canal.nut");
require("pathfinder/coast.nut");
require("pathfinder/line.nut");

/* Water utils. */
class Water {
    /* Min Manhattan distance between 2 points to open a new connection. */
    min_distance = 30;
    /* Max Manhattan distance between 2 points to open a new connection. */
    max_distance = 300;
    /* Max path length. */
    max_path_len = 400;
    /* Max dock distance from the city center. */
    max_city_dock_distance = 20;
    /* Minimal money left after buying something. */
    min_balance = 20000;
    
    /* Maintenance helper. */
    _maintenance = null;
    /* Cache for points that are not connected. */
    _not_connected_cache = AIList();
    
    /* Pathfinders. */
    _line_pathfinder = StraightLinePathfinder();
    _coast_pathfinder = CoastPathfinder();
    _canal_pathfinder = CanalPathfinder();
    
    constructor() {
        _maintenance = Maintenance();
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
    while(cost > AICompany.GetBankBalance(AICompany.COMPANY_SELF) - this.min_balance) {}
}

/* Finds a path between 2 points on sea/lakes. */
function Water::FindOpenWaterPath(start, end, max_len) {
    if( this._not_connected_cache.HasItem(start << 32 | end) ||
        this._not_connected_cache.HasItem(end << 32 | start))
        return [];
    
    /* We have a straight line connection - great! */
    if(this._line_pathfinder.FindPath(start, end, max_len))
        return this._line_pathfinder.path;

    /* Try to continue along the coast. */
    if((AITile.IsCoastTile(this._line_pathfinder.fail_point) || AIMarine.IsDockTile(this._line_pathfinder.fail_point)) &&
        this._coast_pathfinder.FindPath(this._line_pathfinder.fail_point, end, max_len - this._line_pathfinder.path.len())) {
        local path = this._line_pathfinder.path;
        path.extend(this._coast_pathfinder.path);
        return path;
    }
    
    /* Try the other way. */
    if(this._line_pathfinder.FindPath(end, start, max_len)) {
        this._line_pathfinder.path.reverse();
        return this._line_pathfinder.path;
    }
    if((AITile.IsCoastTile(this._line_pathfinder.fail_point) || AIMarine.IsDockTile(this._line_pathfinder.fail_point)) &&
        this._coast_pathfinder.FindPath(this._line_pathfinder.fail_point, start, max_len - this._line_pathfinder.path.len())) {
        local path = this._line_pathfinder.path;
        path.extend(this._coast_pathfinder.path);
        path.reverse();
        return path;
    }
    
    /* Just following the coast */
    //if(this._coast_pathfinder.FindPath(start, end, max_len))
        //return this._coast_pathfinder.path;
    
    this._not_connected_cache.AddItem(start << 32 | end, 1);
    return [];
}

function Water::_FindLockPlace(coast, dock1_tile, dock2_tile) {
    /* Find any existing lock. */
    local neighbours = AITileList();
    SafeAddRectangle(neighbours, coast, 5);
    neighbours.Valuate(AIMarine.IsLockTile);
    neighbours.KeepValue(1);
    neighbours.Valuate(AITile.GetSlope);
    neighbours.RemoveValue(AITile.SLOPE_FLAT);
    if(!neighbours.IsEmpty()) {
        neighbours.Valuate(AIMap.DistanceManhattan, coast);
        neighbours.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return neighbours.Begin();
    }
    
    neighbours = AITileList();
    SafeAddRectangle(neighbours, coast, 5);
    neighbours.RemoveItem(dock1_tile);
    neighbours.RemoveItem(dock2_tile);
    neighbours.Valuate(AITile.IsCoastTile);
    neighbours.KeepValue(1);
    neighbours.Valuate(_val_IsLockCapable);
    neighbours.KeepValue(1);
    if(neighbours.IsEmpty())
        return -1;
    
    neighbours.Valuate(AIMap.DistanceManhattan, coast);
    neighbours.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return neighbours.Begin();
}

/* Same as _FindWaterPath, but including canals and taking docks as input. */
function Water::FindWaterPath(dock1, dock2, max_len) {
    if( this._not_connected_cache.HasItem(dock1.tile << 32 | dock2.tile) ||
        this._not_connected_cache.HasItem(dock2.tile << 32 | dock1.tile))
        return ShipPath(dock1, dock2);
    
    /* Both docks are on sea/lake. */
    if(!dock1.is_artificial && !dock2.is_artificial) {       
        local open_water = FindOpenWaterPath(dock1.GetPfTile(dock2.tile), dock2.GetPfTile(dock2.tile), max_len);
        if(open_water.len() == 0)
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
        return ShipPath(dock1, dock2, [], open_water, []);
    }
    
    /* One of the docks is artificial, so we won't be able to reach it. */
    if(!areCanalsAllowed)
        return ShipPath(dock1, dock2);
    
    //AISign.BuildSign(dock1.tile, "artificial:"+dock1.is_artificial);
    //AISign.BuildSign(dock2.tile, "artificial:"+dock2.is_artificial);
    
    /* Don't use tiles occupied by docks and locks. */ 
    local coast_cross = dock1.GetNecessaryCoastCrossesTo(dock2);       
    local ignored_tiles = dock1.GetOccupiedTiles();
    ignored_tiles.extend(dock2.GetOccupiedTiles());
    
    /* No locks needed (in theory). */
    if(coast_cross.len() == 0) {
        if(dock1.is_artificial && dock2.is_artificial) {            
            local canal = this._canal_pathfinder.FindPath(dock1.GetPfTile(), dock2.GetPfTile(), max_len, ignored_tiles);
            if(canal.len() == 0)
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2, canal, [], []);
        }

        /* GetNecessaryCoastCrossesTo may return empty list, this means the artificial dock is exactly behind us. */
        if(dock1.is_artificial && !dock2.is_artificial) {
            local lock = dock2.GetLockNearby();
            if(lock == -1) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            ignored_tiles.append(GetHillBackTile(lock, 1));
            local canal = this._canal_pathfinder.FindPath(dock1.GetPfTile(), GetHillBackTile(lock, 2), max_len, ignored_tiles);
            if(canal.len() == 0)
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            else
                canal.append(lock);
            return ShipPath(dock1, dock2, canal, [], []);
        }
        
        if(!dock1.is_artificial && dock2.is_artificial) {
            local lock = dock1.GetLockNearby();
            if(lock == -1) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            ignored_tiles.append(GetHillBackTile(lock, 1));
            local canal = this._canal_pathfinder.FindPath(GetHillBackTile(lock, 2), dock2.GetPfTile(), max_len, ignored_tiles);
            if(canal.len() == 0)
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            else
                canal.insert(0, lock);
            return ShipPath(dock1, dock2, canal, [], []);
        }

        //AILog.Info("not expected (1):"+dock1.is_artificial+","+dock2.is_artificial);
        return ShipPath(dock1, dock2);
    }
    
    local lock1_coast = coast_cross[0];
    local lock2_coast = coast_cross[coast_cross.len()-1];
    
    /* One lock needed. */
    if(lock1_coast == lock2_coast) {
        local lock = _FindLockPlace(lock1_coast, dock1.tile, dock2.tile);
        if(lock == -1) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }        
        ignored_tiles.append(GetHillBackTile(lock, 1));
        
        if(dock1.is_artificial && !dock2.is_artificial) {
            /* Fast things first, find open water path. */
            local open_water = FindOpenWaterPath(lock, dock2.GetPfTile(dock1.tile), max_len);
            if(open_water.len() == 0) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            
            /* Then find canal to reach the lock. */
            local canal = this._canal_pathfinder.FindPath(dock1.GetPfTile(), GetHillBackTile(lock, 2), max_len - open_water.len(), ignored_tiles);
            if(canal.len() == 0) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            
            canal.append(lock);            
            return ShipPath(dock1, dock2, canal, open_water, []);
        }
        
        if(!dock1.is_artificial && dock2.is_artificial) {
            /* Fast things first, find open water path. */
            local open_water = FindOpenWaterPath(dock1.GetPfTile(dock2.tile), lock, max_len);
            if(open_water.len() == 0) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            
            /* Then find canal to reach dock2. */
            local canal = this._canal_pathfinder.FindPath(GetHillBackTile(lock, 2), dock2.GetPfTile(), max_len - open_water.len(), ignored_tiles);                      
            if(canal.len() == 0) {
                this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
                return ShipPath(dock1, dock2);
            }
            
            canal.insert(0, lock);
            return ShipPath(dock1, dock2, [], open_water, canal);
        }
        
        //AILog.Info("not expected (2):"+dock1.is_artificial+","+dock2.is_artificial);
        return ShipPath(dock1, dock2);
    }
    
    /* Two locks needed. */
    if(dock1.is_artificial && dock2.is_artificial) {
        local lock1 = _FindLockPlace(lock1_coast, dock1.tile, dock2.tile);
        if(lock1 == -1) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }        
            
        local lock2 = _FindLockPlace(lock2_coast, dock1.tile, dock2.tile);
        if(lock2 == -1) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }                
        
        /* Find sea/lake path between the 2 locks. */
        local open_water = FindOpenWaterPath(lock1, lock2, max_len);
        if(open_water.len() == 0) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }
        
        /* Find canals to 2 locks. */
        ignored_tiles.append(GetHillBackTile(lock1, 1));
        ignored_tiles.append(GetHillBackTile(lock2, 1));
                
        local canal1 = this._canal_pathfinder.FindPath(dock1.GetPfTile(), GetHillBackTile(lock1, 2), max_len - open_water.len(), ignored_tiles);                      
        if(canal1.len() == 0) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }
        canal1.append(lock1);
        
        local canal2 = this._canal_pathfinder.FindPath(GetHillBackTile(lock2, 2), dock2.GetPfTile(), max_len - open_water.len(), ignored_tiles);                      
        if(canal2.len() == 0) {
            this._not_connected_cache.AddItem(dock1.tile << 32 | dock2.tile, 1);
            return ShipPath(dock1, dock2);
        }
        canal2.insert(0, lock2);
        return ShipPath(dock1, dock2, canal1, open_water, canal2);
    }

    //AILog.Info("not expected (3):"+dock1.is_artificial+","+dock2.is_artificial);
    return ShipPath(dock1, dock2);
}

function Water::BuildShip(depot, cargo, round_trip_distance, monthly_production) {    
    local engine = ship_model.GetBestModelForCargo(cargo, round_trip_distance, monthly_production);
    if(!AIEngine.IsValidEngine(engine)) {
        AILog.Error("No vehicle model to transport " + AICargo.GetCargoLabel(cargo) +
                    " with monthly production = " + monthly_production +
                    " and distance = " + round_trip_distance);
        return -1;
    }

    WaitToHaveEnoughMoney(AIEngine.GetPrice(engine));
    if(!AIEngine.IsValidEngine(engine)) {
        AILog.Error("The chosen vehicle model is no longer produced");
        return -1;
    }
        
    local vehicle = AIVehicle.BuildVehicle(depot, engine);
    local last_err = AIError.GetLastErrorString();
    if(!AIVehicle.IsValidVehicle(vehicle)) {
        AILog.Error("Failed to build the ship in depot #" + depot + ": " + last_err);
        AISign.BuildSign(depot, "ship failed")
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

function Water::BuildAndStartShip(dock1, dock2, cargo, full_load, monthly_production) {
    if(monthly_production <= 0 || !ship_model.ExistsForCargo(cargo))
        return false;
    
    /* Too close or too far. */
    local dist = AIMap.DistanceManhattan(dock1.tile, dock2.tile);
    if(dist < this.min_distance || dist > this.max_distance)
        return false;
    
    /* No possible water connection. */
    local path = FindWaterPath(dock1, dock2, this.max_path_len);
    if(!path.IsValid())
        return false;
    
    /* Build infrastructure. */
    WaitToHaveEnoughMoney(dock1.EstimateCost());
    if(dock1.Build() == -1) {
        AILog.Error("Failed to build dock: " + AIError.GetLastErrorString());
        AISign.BuildSign(dock1.tile, "dock fail");
        return false;
    }
    local depot = dock1.FindWaterDepot();
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
        AISign.BuildSign(dock2.tile, "dock fail");
        return false;
    }
    WaitToHaveEnoughMoney(path.EstimateCanalsCost());
    if(!path.BuildCanals()) {
        AILog.Error("Failed to build the canal for " + dock1.GetName() + "-" + dock2.GetName() + " route: " + AIError.GetLastErrorString());
        return false;
    }
    local vehicle = BuildShip(depot, cargo, path.Length() * 2, monthly_production);
    if(!AIVehicle.IsValidVehicle(vehicle)) {
        AILog.Error("Failed to build ship for " + dock1.GetName() + "-" + dock2.GetName() + " route");
        return false;
    }
    
    /* Build buoys every n tiles. */
    WaitToHaveEnoughMoney(path.EstimateBuoysCost());
    local buoys = path.BuildBuoys();
    
    /* Schedule path. */
    local load_order = full_load ? AIOrder.OF_FULL_LOAD : AIOrder.OF_NONE;
    
    if(!AIOrder.AppendOrder(vehicle, dock1.tile, load_order)) {
        AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (1): " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* Buoys. */
    foreach(buoy in buoys)
        if(!AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE)) {
            AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (2): " + AIError.GetLastErrorString());
            AIVehicle.SellVehicle(vehicle);
            return false;
        }
        
    if(!AIOrder.AppendOrder(vehicle, dock2.tile, AIOrder.OF_NONE)) {
        AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (3): " + AIError.GetLastErrorString());
        AIVehicle.SellVehicle(vehicle);
        return false;
    }
    
    /* The way back buoys. */
    buoys.reverse();
    foreach(buoy in buoys)
        if(!AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE)) {
            AILog.Error("Failed to schedule the ship for " + dock1.GetName() + "-" + dock2.GetName() + " route (4): " + AIError.GetLastErrorString());
            AIVehicle.SellVehicle(vehicle);
            return false;
        }
        
    /* Send for maintanance if too old. This is safer here, cause the vehicle won't get lost
       and also saves us some opcodes. */
    if(    !AIOrder.InsertConditionalOrder(vehicle, 0, 0)
        || !AIOrder.InsertOrder(vehicle, 1, depot, AIOrder.OF_NONE) /* why OF_SERVICE_IF_NEEDED doesn't work? */
        || !AIOrder.SetOrderCondition(vehicle, 0, AIOrder.OC_REMAINING_LIFETIME)
        || !AIOrder.SetOrderCompareFunction(vehicle, 0, AIOrder.CF_MORE_THAN)
        || !AIOrder.SetOrderCompareValue(vehicle, 0, 0)
        ) {
        AILog.Error("Failed to schedule the autoreplacement order for " + dock1.GetName() + "-" + dock2.GetName() + " route: " + AIError.GetLastErrorString());
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
