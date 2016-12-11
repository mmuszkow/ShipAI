/* Freight ships. */

require("water.nut");
require("pathfinder/line.nut");
require("pathfinder/coast.nut");

class FreightShip extends Water {
    /* Max Manhattan distance between 2 industries to open a new connection. */
    max_distance = 300;
    /* Less this percent of the cargo transported to open a new route. */
    percent_to_open_new_route = 61;
    
    /* Pathfinders. */
    _line_pathfinder = StraightLinePathfinder();
    _coast_pathfinder = CoastPathfinder();
        
    constructor() {}
}

function FreightShip::BuildTownFreightRoutes() {
    local ships_built = 0;
    if(!AreShipsAllowed())
        return ships_built;
    
    local cargos = AICargoList();
    cargos.Valuate(AICargo.IsFreight); 
    cargos.KeepValue(1); /* Only freight cargo. */
    cargos.Valuate(AICargo.GetTownEffect);
    cargos.RemoveValue(AICargo.TE_NONE); /* Only cargos that are accepted by towns. */
    
    for(local cargo = cargos.Begin(); cargos.HasNext(); cargo = cargos.Next()) {
        
        /* Check if we can transport this cargo. */
        if(!VehicleModelForCargoExists(AIVehicle.VT_WATER, cargo))
            continue;
        
        local producers = AIIndustryList_CargoProducing(cargo);
        producers.Valuate(AIIndustry.GetLastMonthProduction, cargo);
        producers.KeepAboveValue(0); /* production more than 0. */
        producers.Valuate(AIIndustry.GetLastMonthTransportedPercentage, cargo);
        producers.KeepBelowValue(this.percent_to_open_new_route); /* Less than 60% of cargo transported. */
        producers.Valuate(IndustryCanHaveDock, true);
        producers.RemoveValue(0);
   
        for(local producer = producers.Begin(); producers.HasNext(); producer = producers.Next()) {
            
            /* Industry may cease to exist. */
            if(!AIIndustry.IsValidIndustry(producer))
                continue;
                        
            /* Get acceptors. */
            local acceptors = AITownList();
            acceptors.Valuate(AITown.GetDistanceManhattanToTile, AIIndustry.GetLocation(producer));
            acceptors.KeepBelowValue(this.max_distance);
            acceptors.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
            
            /* Skip those serviced and with less than 100 units of cargo waiting. */
            local dock1 = FindDockNearIndustry(producer, true);
            if(dock1 != 1) {
                local station_id = AIStation.GetStationID(dock1);
                if(    AIStation.HasCargoRating(station_id, cargo)
                    && AIStation.GetCargoWaiting(station_id, cargo) < 100)
                    continue;
            }
            
            /* For path finding. */
            local coast1 = dock1;
            if(coast1 == -1)
                coast1 = GetCoastTileNearestIndustry(producer, true);
            if(coast1 == -1){
                AILog.Error("Weird, producer " + AIIndustry.GetName(producer) + " is not close to the coast")
                continue;
            }
            
            /* Get monthly production to determine the potential ship size. */
            local monthly_production = AIIndustry.GetLastMonthProduction(producer, cargo);
            if(monthly_production == 0)
                continue;
            
            for(local acceptor = acceptors.Begin(); acceptors.HasNext(); acceptor = acceptors.Next()) {
                local dock2 = FindDockNearTown(acceptor, cargo);
                
                /* If there is already a vehicle servicing this route, clone it, it's much faster. */
                if(dock1 != -1 && dock2 != -1) {
                    local clone_res = CloneShip(dock1, dock2, cargo);
                    if(clone_res == 2) {
                        AILog.Info("Adding next " + AICargo.GetCargoLabel(cargo) + " route between " 
                                + AIStation.GetName(AIStation.GetStationID(dock1)) + " and " 
                                + AIStation.GetName(AIStation.GetStationID(dock2)));
                        ships_built++;
                        break;
                    } else if(clone_res == 1) {
                        /* Error. */
                        if(!AreShipsAllowed())
                            return ships_built;
                        break;
                    }
                }
                
                local coast2 = dock2;
                if(coast2 == -1)
                    coast2 = GetCoastTileNearestTown(acceptor, this.max_city_dock_distance, cargo);
                if(coast2 == -1)
                    continue;
                
                local path = []
                if(this._line_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                    path = this._line_pathfinder.path;
                else if(this._coast_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                    path = this._coast_pathfinder.path;
                else
                    continue;
                
                
                /* Find/build docks. */
                if(dock1 == -1)
                    dock1 = BuildDockNearIndustry(producer, true);
                if(dock1 == -1) {
                    AILog.Error("Failed to build the dock: " + AIError.GetLastErrorString());
                    break;
                }
                if(dock2 == -1)
                    dock2 = BuildDockInTown(acceptor, cargo);
                if(dock2 == -1) {
                    AILog.Error("Failed to build the dock: " + AIError.GetLastErrorString());
                    break;
                }
                
                /* Build vehicle. */
                if(BuildAndStartShip(dock1, dock2, cargo, path, true, monthly_production)) {
                    AILog.Info("Building " + AICargo.GetCargoLabel(cargo) + " route between "
                                + AIStation.GetName(AIStation.GetStationID(dock1)) + " and "
                                + AIStation.GetName(AIStation.GetStationID(dock2)));
                    ships_built++;
                    break;
                } else if(!AreShipsAllowed())
                    return ships_built;                
            }
        }
    }
    
    return ships_built;
}

function FreightShip::BuildIndustryFreightRoutes() {
    local ships_built = 0;
    if(!AreShipsAllowed())
        return ships_built;
    
    local cargos = AICargoList();
    cargos.Valuate(AICargo.IsFreight); 
    cargos.KeepValue(1); /* Only freight cargo. */
    cargos.Valuate(AICargo.GetTownEffect);
    cargos.KeepValue(AICargo.TE_NONE); /* Only cargos that are accepted by other industries. */
    
    for(local cargo = cargos.Begin(); cargos.HasNext(); cargo = cargos.Next()) {
        
        /* Check if we can transport this cargo. */
        if(!VehicleModelForCargoExists(AIVehicle.VT_WATER, cargo))
            continue;
        
        /* Get producers. */
        local producers = AIIndustryList_CargoProducing(cargo);
        producers.Valuate(AIIndustry.GetLastMonthProduction, cargo);
        producers.KeepAboveValue(0); /* production more than 0. */
        producers.Valuate(AIIndustry.GetLastMonthTransportedPercentage, cargo);
        producers.KeepBelowValue(this.percent_to_open_new_route); /* Less than 60% of cargo transported. */
        producers.Valuate(IndustryCanHaveDock, true);
        producers.RemoveValue(0);
        
        /* Get acceptors. */
        local acceptors = AIIndustryList_CargoAccepting(cargo);
        acceptors.Valuate(IndustryCanHaveDock, false);
        acceptors.RemoveValue(0);
        
        for(local producer = producers.Begin(); producers.HasNext(); producer = producers.Next()) {
            
            /* Industry may cease to exist. */
            if(!AIIndustry.IsValidIndustry(producer))
                continue;

            local dock1 = FindDockNearIndustry(producer, true);
            
            /* Skip those serviced and with less than 100 units of cargo waiting. */
            if(dock1 != 1) {
                local station_id = AIStation.GetStationID(dock1);
                if(    AIStation.HasCargoRating(station_id, cargo)
                    && AIStation.GetCargoWaiting(station_id, cargo) < 100)
                    continue;
            }
            
            local coast1 = dock1;
            
            /* In case of an industry with a dock on water (offshore only?), we cannot use standard pathfinding algorithms. */
            local is_on_water = AIIndustry.IsBuiltOnWater(producer);
            local water_tiles_around = AITileList();
            if(is_on_water) {
                if(dock1 == -1) {
                    AILog.Error(AIIndustry.GetName(producer) + " is on water but has no dock");
                    continue;
                }
                SafeAddRectangle(water_tiles_around, dock1, 3); /* not super flexible... */
                water_tiles_around.Valuate(AITile.IsWaterTile);
                water_tiles_around.KeepValue(1);
                if(water_tiles_around.IsEmpty()) {
                    AILog.Error(AIIndustry.GetName(producer) + " is on water but has no water around");
                    continue;
                }
            } else {
                if(coast1 == -1)
                    coast1 = GetCoastTileNearestIndustry(producer, true);
                if(coast1 == -1) {
                    AILog.Error("Weird, producer " + AIIndustry.GetName(producer) + " is not close to the coast")
                    continue;
                }
            }
            
            /* Find the closest acceptor. */
            local close_acceptors = AIList()
            close_acceptors.AddList(acceptors); /* No clone method... */
            close_acceptors.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(producer));
            close_acceptors.KeepBelowValue(this.max_distance);
            close_acceptors.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
            
            /* Get monthly production to determine the potential ship size. */
            local monthly_production = AIIndustry.GetLastMonthProduction(producer, cargo);
            if(monthly_production == 0)
                continue;
            
            for(local acceptor = close_acceptors.Begin(); close_acceptors.HasNext(); acceptor = close_acceptors.Next()) {
                
                /* Industries may get closed. */
                if(!AIIndustry.IsValidIndustry(acceptor))
                    continue;
                
                /* For symmetric cargo. */
                if(acceptor == producer)
                    continue;
                
                local dock2 = FindDockNearIndustry(acceptor, false);
                
                /* If there is already a vehicle servicing this route, clone it, it's much faster. */
                if(dock1 != -1 && dock2 != -1) {
                    local clone_res = CloneShip(dock1, dock2, cargo);
                    if(clone_res == 2) {
                        AILog.Info("Adding next " + AICargo.GetCargoLabel(cargo) + " route between " 
                                + AIStation.GetName(AIStation.GetStationID(dock1)) + " and " 
                                + AIStation.GetName(AIStation.GetStationID(dock2)));
                        ships_built++;
                        break;
                    } else if(clone_res == 1) {
                        /* Error. */
                        if(!AreShipsAllowed())
                            return ships_built;
                        break;
                    }
                }
                
                local coast2 = dock2;
                if(coast2 == -1)
                    coast2 = GetCoastTileNearestIndustry(acceptor, false);
                if(coast2 == -1) {
                    AILog.Error("Weird, acceptor " + AIIndustry.GetName(acceptor) + " is not close to the coast")
                    continue;
                }
                
                local path = [];
                if(is_on_water) {
                    /* On-water industries (offshore only?). */
                    water_tiles_around.Valuate(AIMap.DistanceManhattan, coast2);
                    water_tiles_around.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
                    if(!this._line_pathfinder.FindPath(water_tiles_around.Begin(), coast2, this.max_path_len)) {
                        if(!AITile.IsCoastTile(this._line_pathfinder.fail_point))
                            continue;
                        /* Try to continue along the coast. */
                        if(!this._coast_pathfinder.FindPath(this._line_pathfinder.fail_point, coast2, this.max_path_len - this._line_pathfinder.path.len()))
                            continue;
                        
                        path = this._line_pathfinder.path;
                        path.extend(this._coast_pathfinder.path);
                    } else
                        path = this._line_pathfinder.path;
                } else {                        
                    /* Coast industries. */
                    if(this._line_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                        path = this._line_pathfinder.path;
                    else if(this._coast_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                        path = this._coast_pathfinder.path;
                    else
                        continue;
                }
                
                /* Find/build docks. */
                if(dock1 == -1)
                    dock1 = BuildDockNearIndustry(producer, true);
                if(dock1 == -1) {
                    AILog.Error("Failed to build the dock: " + AIError.GetLastErrorString());
                    break;
                }
                if(dock2 == -1)
                    dock2 = BuildDockNearIndustry(acceptor, false);
                if(dock2 == -1) {
                    AILog.Error("Failed to build the dock: " + AIError.GetLastErrorString());
                    break;
                }
                
                /* Build vehicle. */
                if(BuildAndStartShip(dock1, dock2, cargo, path, true, monthly_production)) {
                    AILog.Info("Building " + AICargo.GetCargoLabel(cargo) + " route between " 
                                + AIStation.GetName(AIStation.GetStationID(dock1)) + " and " 
                                + AIStation.GetName(AIStation.GetStationID(dock2)));
                    ships_built++;
                    break;
                } else if(!AreShipsAllowed())
                    return ships_built;
            }
        }
    }
    
    return ships_built;
}
