/* Ferries part of AI.
   Builds ferries/hovercrafts. */

require("water.nut");
require("hashset.nut");
require("pathfinder/line.nut");
require("pathfinder/coast.nut");

class Ferry extends Water {
    /* Open new connections only in cities with this population. */
    min_population = 500;
    /* Max Manhattan distance between 2 cities to open a new connection. */
    max_distance = 300;
    /* Min passengers to open a new route. */
    min_passengers = 150;
    
    /* Passengers cargo id. */
    _passenger_cargo_id = -1;
    /* Pathfinders. */
    _line_pathfinder = StraightLinePathfinder();
    _coast_pathfinder = CoastPathfinder();
    /* Cache of which cities are not connected. */
    _not_connected = null;
    
    constructor() {
        this._passenger_cargo_id = GetPassengersCargo();
        
        /* Dynamic hashset size. */
        local size = AIMap.GetMapSize();
        
        if(size > 4194304) /* bigger than 2048x2048 */
            this._not_connected = HashSet(65536);
        else if(size > 1048576) /* bigger than 1024x1024 */
            this._not_connected = HashSet(32768);
        else if(size > 262144)  /* bigger than 512x512 */
            this._not_connected = HashSet(16384);
        else
            this._not_connected = HashSet(8192);
    }
}
   
function Ferry::AreFerriesAllowed() {
    return AreShipsAllowed() && VehicleModelForCargoExists(AIVehicle.VT_WATER, this._passenger_cargo_id);
}

function Ferry::BuildFerryRoutes() {
    local ferries_built = 0;
    if(!this.AreFerriesAllowed())
        return ferries_built;
    
    local towns = AITownList();
    towns.Valuate(AITown.GetPopulation);
    towns.KeepAboveValue(this.min_population);
    towns.Valuate(GetCoastTileNearestTown, this.max_city_dock_distance, this._passenger_cargo_id);
    towns.RemoveValue(-1);
    
    for(local town = towns.Begin(); towns.HasNext(); town = towns.Next()) {        
        local dock1 = FindDockNearTown(town, this._passenger_cargo_id);
        /* If there is already a dock in the city and there 
           are not many passengers waiting there, there is no point
           in opening a new route. */
        if(dock1 != -1 && AIStation.GetCargoWaiting(AIStation.GetStationID(dock1), this._passenger_cargo_id) < this.min_passengers)
            continue;
        
        /* Find dock or potential place for dock. */
        local coast1 = dock1;
        if(coast1 == -1)
            coast1 = GetCoastTileNearestTown(town, this.max_city_dock_distance, this._passenger_cargo_id);
        
        /* Find a city suitable for connection closest to ours. */
        local towns2 = AIList();
        towns2.AddList(towns);
        towns2.RemoveItem(town);
        towns2.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
        towns2.KeepBelowValue(this.max_distance); /* Cities too far away. */
        towns2.KeepAboveValue(20); /* Cities too close. */
        towns2.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        
        for(local town2 = towns2.Begin(); towns2.HasNext(); town2 = towns2.Next()) {
            local dock2 = FindDockNearTown(town2, this._passenger_cargo_id);
            /* If there is already a dock in the city and there 
               are not many passengers waiting there, there is no point
               in opening a new route. */
            if(dock2 != -1 && AIStation.GetCargoWaiting(AIStation.GetStationID(dock2), this._passenger_cargo_id) < this.min_passengers)
                continue;
            
            /* If there is already a vehicle servicing this route, clone it, it's much faster. */
            if(dock1 != -1 && dock2 != -1) {
                local clone_res = CloneShip(dock1, dock2, this._passenger_cargo_id);
                if(clone_res == 2) {
                    AILog.Info("Adding next ferry between " + AITown.GetName(town) + " and " + AITown.GetName(town2));
                    ferries_built++;
                    continue;
                } else if(clone_res == 1) {
                    /* Error. */
                    if(!AreFerriesAllowed())
                        return ferries_built;
                    continue;
                }
            }
                        
            /* Find dock or potential place for dock. */
            local coast2 = dock2;
            if(coast2 == -1)
                coast2 = GetCoastTileNearestTown(town2, this.max_city_dock_distance, this._passenger_cargo_id);
            if(coast2 == -1)
                continue;
            
            /* Too close. */
            if(AIMap.DistanceManhattan(coast1, coast2) < 20)
                continue;

            if(this._not_connected.ContainsPair(coast1, coast2))
                continue;
            
            /* Skip cities that are not connected by water. */
            local path = null;
            if(this._line_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                path = this._line_pathfinder.path;
            else if(this._coast_pathfinder.FindPath(coast1, coast2, this.max_path_len))
                path = this._coast_pathfinder.path;
            else {
                this._not_connected.AddPair(coast1, coast2);
                continue;
            }
            
            AILog.Info("Building ferry between " + AITown.GetName(town) + " and " + AITown.GetName(town2));
            /* Build docks if needed. */
            if(dock1 == -1)
                dock1 = BuildDockInTown(town, this._passenger_cargo_id);
            if(dock1 == -1) {
                AILog.Error("Failed to build the dock in " + AITown.GetName(town) + ": " + AIError.GetLastErrorString());
                continue;
            }
            if(dock2 == -1)
                dock2 = BuildDockInTown(town2, this._passenger_cargo_id);
            if(dock2 == -1) {
                AILog.Error("Failed to build the dock in " + AITown.GetName(town2) + ": " + AIError.GetLastErrorString());
                continue;
            }
        
            /* Buy and schedule ship. */
            if(BuildAndStartShip(dock1, dock2, this._passenger_cargo_id, path, false, 150))
                ferries_built++;
            else if(!AreFerriesAllowed())
                return ferries_built;
        }
    }
            
    //this._not_connected.Debug();
    
    return ferries_built;
}
