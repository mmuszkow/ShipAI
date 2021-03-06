require("global.nut");
require("utils.nut");

class Dock {
    tile = -1;
    orientation = -1;
    is_landdock = false;
    is_offshore = false;
   
    /* Don't use too big value here, it may cause the depots on the other
     * waterbody to be chosen. */
    max_depot_distance = 5; 
 
    constructor(dock, artificial_orientation = -1, _is_offshore = false) {
        this.tile = dock;
        this.is_offshore = _is_offshore;
        
        if(!_is_offshore) {
            /* We need to find the hill tile. */
            if(AIMarine.IsDockTile(dock) && AITile.GetSlope(dock) == AITile.SLOPE_FLAT) {
                if(AIMarine.IsDockTile(dock + NORTH))
                    this.tile = dock + NORTH;
                else if(AIMarine.IsDockTile(dock + SOUTH))
                    this.tile = dock + SOUTH;
                else if(AIMarine.IsDockTile(dock + WEST))
                    this.tile = dock + WEST;
                else if(AIMarine.IsDockTile(dock + EAST))
                    this.tile = dock + EAST;
            }
            
            if(artificial_orientation != -1) {
                /* Artificial dock. */
                this.orientation = artificial_orientation;
                this.is_landdock = true;
            } else {
                /* Coast dock or existing one. */
                switch(AITile.GetSlope(this.tile)) {
                    case AITile.SLOPE_NE:
                        /* West. */
                        this.orientation = 0;
                        if(AIMarine.IsCanalTile(this.tile + WEST + WEST))
                            this.is_landdock = true;
                        break;
                    case AITile.SLOPE_NW:
                        /* South. */
                        this.orientation = 1;
                        if(AIMarine.IsCanalTile(this.tile + SOUTH + SOUTH))
                            this.is_landdock = true;
                        break;
                    case AITile.SLOPE_SE:
                        /* North. */
                        if(AIMarine.IsCanalTile(this.tile + NORTH + NORTH))
                            this.is_landdock = true;
                        this.orientation = 2;
                        break;
                    case AITile.SLOPE_SW:
                        /* East. */
                        if(AIMarine.IsCanalTile(this.tile + EAST + EAST))
                            this.is_landdock = true;
                        this.orientation = 3;
                        break;
                    default:
                        this.orientation = -1;
                        break;
                }
            }
        }
    }
}

function Dock::IsValidStation() {
    return AIStation.IsValidStation(AIStation.GetStationID(this.tile));
}

function Dock::GetStationID() {
    return AIStation.GetStationID(this.tile);
}

function Dock::GetName() {
    return AIStation.GetName(AIStation.GetStationID(this.tile));
}

/* Returns the dock's tile which is a target for pathfinder
   - standard coast dock - front part of the dock (for line or coast pathfinder)
   - offshore dock - water tile in the destination direction, not obscured by oil rig
   - land dock - canal tile in front of the dock
 */
function Dock::GetPfTile(dest = -1) {
    /* Some industries (offshores only?) can have a dock built on water which will break the line pathfinder. 
       We need to find a tile that is not obstructed by the industry itself. */
    if(this.is_offshore) {
        if(dest == -1)
            return -1;
        
        local water = AITileList();
        SafeAddRectangle(water, this.tile, 4);
        water.Valuate(AIMap.DistanceManhattan, dest);
        water.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        if(water.IsEmpty())
            return -1; /* Something's wrong... */
        
        return water.Begin();
    }

    /* canal pathfinder needs to start from water tile, not dock tile */   
    local front = 1;
    if(this.is_landdock)
        front = 2;
 
    switch(this.orientation) {
        case 0:
            /* West. */
            return this.tile + AIMap.GetTileIndex(front, 0);
        case 1:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, front);
        case 2:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, -front);
        case 3:
            /* East. */
            return this.tile + AIMap.GetTileIndex(-front, 0);
        default:
            return -1;
    }
}

function Dock::GetOccupiedTiles() {
    local tiles = AITileList();
    tiles.AddTile(this.tile);
    switch(orientation) {
        case 0:
            /* West */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
            if(this.is_landdock) {        
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(2, -1));
            }
            return tiles;
        case 1:
            /* South. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 2));
            }
            return tiles;
        case 2:
            /* North. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -2));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -3));
            }
            return tiles;
        case 3:
            /* East. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-2, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            }
            return tiles;
        default:
            return tiles;
    }
}

function _val_IsDockCapable(tile) {
    if(!AITile.IsBuildable(tile) || !IsSimpleSlope(tile))
        return false;
    
    local front1 = GetHillFrontTile(tile, 1);
    local front2 = GetHillFrontTile(tile, 2);
    if(AITile.GetSlope(front1) != AITile.SLOPE_FLAT ||
       AITile.GetSlope(front2) != AITile.SLOPE_FLAT)
        return false;

    /* TODO: we should check if front1 is not a bridge somehow
     * AITile.IsBuildable doesn't work for water
     * AIBridge.IsBridge tile works only for bridge's start/end
     * AIBridge.GetBridgeID precondition is that AIBridge.IsBridge returns true
     * AIRoad.IsRoadTile returns false (I didn't try it on land..)
     * AITile.HasTransportType same
     */
    return AITile.IsWaterTile(front1) && AITile.IsWaterTile(front2) && 
          !AIMarine.IsWaterDepotTile(front2);
}

/* Should be used only for sea */
function _val_IsWaterDepotCapable(tile, orientation) {
    /* TODO: we should somehow check if it is not a bridge tile */
    if(!AITile.IsWaterTile(tile) || AITile.GetMaxHeight(tile) > 0)
        return false;
    
    /* depot is the 2nd depot tile, front is the tile in front of the depot,
     * left/right are side tiles. */
    local depot2, front, left1, left2, right1, right2;
    switch(orientation) {
        /* West. */
        case 0:
            depot2 = tile + WEST;
            front = depot2 + WEST;
            left1 = tile + SOUTH;
            left2 = depot2 + SOUTH;
            right1 = tile + NORTH;
            right2 = depot2 + NORTH;
            break;
        /* South. */
        case 1:
            depot2 = tile + SOUTH;
            front = depot2 + SOUTH;
            left1 = tile + EAST;
            left2 = depot2 + EAST;
            right1 = tile + WEST;
            right2 = depot2 + WEST;
            break;
        /* North. */
        case 2:
            depot2 = tile + NORTH;
            front = depot2 + NORTH;
            left1 = tile + WEST;
            left2 = depot2 + WEST;
            right1 = tile + EAST;
            right2 = depot2 + EAST;
            break;
        /* East. */
        default:
            depot2 = tile + WEST;
            front = depot2 + EAST;
            left1 = tile + NORTH;
            left2 = depot2 + NORTH;
            right1 = tile + SOUTH;
            right2 = depot2 + SOUTH;
            break;
    }
    
    /* Must have at least one exit and shouldn't block
       any infrastructure on the sides (like dock or lock). */
    return AITile.IsWaterTile(depot2) && AITile.IsWaterTile(front) &&
           AITile.IsWaterTile(left1) && AITile.IsWaterTile(left2) &&
           AITile.IsWaterTile(right1) && AITile.IsWaterTile(right2) &&
           !AIMarine.IsLockTile(depot2) && !AIMarine.IsLockTile(front) &&
           !AIMarine.IsLockTile(left1) && !AIMarine.IsLockTile(left2) &&
           !AIMarine.IsLockTile(right1) && !AIMarine.IsLockTile(right2);
}

function Dock::EstimateCost() {
    if(this.is_offshore || AIMarine.IsDockTile(this.tile))
        return 0;
    
    if(!this.is_landdock)
        return  AIMarine.GetBuildCost(AIMarine.BT_DOCK) + 
                AITile.GetBuildCost(AITile.BT_CLEAR_FIELDS); /* building on the coast is more expensive + we may need to clear it */
    
    /* AITestMode + AIAccounting doesn't seem to work properly */
    return  AIMarine.GetBuildCost(AIMarine.BT_DOCK) + 
            2 * AITile.GetBuildCost(AITile.BT_TERRAFORM) + /* raise */
            12 * AITile.GetBuildCost(AITile.BT_CLEAR_FIELDS) + /* worst case */
            48000; /* canals, how to get the canal cost?? */
}

function Dock::Build() {
    /* If already there return the existing dock's tile. */
    if(this.is_offshore || IsValidStation())
        return this.tile;
   
    /* Artificial dock. */
    if(this.is_landdock) {      
        switch(this.orientation) {
            case 0:
                /* To the West. */
                if( AITile.RaiseTile(this.tile, AITile.SLOPE_NE) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 1)) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 2)) &&                
                    AIMarine.BuildDock(this.tile, AIStation.STATION_NEW) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(1, -1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(2, -1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(3, -1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(3, 0)))
                    return this.tile;
                return -1;
            case 1:
                /* To the South. */
                if( AITile.RaiseTile(this.tile, AITile.SLOPE_NW) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 1)) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 2)) &&
                    AIMarine.BuildDock(this.tile, AIStation.STATION_NEW) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(1, 1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(1, 2)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(1, 3)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(0, 3)))
                    return this.tile;
                return -1;
            case 2:
                /* To the North. */
                if( AITile.RaiseTile(this.tile, AITile.SLOPE_SE) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 1)) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 2)) &&
                    AIMarine.BuildDock(this.tile, AIStation.STATION_NEW) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-1, -1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-1, -2)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-1, -3)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(0, -3)))
                    return this.tile;
                return -1;
            case 3:
                /* To the East. */
                if( AITile.RaiseTile(this.tile, AITile.SLOPE_SW) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 1)) &&
                    AIMarine.BuildCanal(GetHillFrontTile(this.tile, 2)) &&        
                    AIMarine.BuildDock(this.tile, AIStation.STATION_NEW) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-1, 1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-2, 1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-3, 1)) &&
                    AIMarine.BuildCanal(this.tile + AIMap.GetTileIndex(-3, 0)))
                    return this.tile;
                return -1;
            default:
                return -1;
        }
    }
        
    /* Regular on coast dock. */
    if(AIMarine.BuildDock(tile, AIStation.STATION_NEW))
        return this.tile;
    
    return -1;
}

/* Land docks have its water depot in fixed place. */
function Dock::_GetLandDockDepotLocation() {
    if(!this.is_landdock)
        return -1;
    switch(this.orientation) {
        /* West. */ 
        case 0:
            return this.tile + WEST + NORTH;
        /* South. */
        case 1:
            return this.tile + SOUTH + WEST;
        /* North. */
        case 2:
            return this.tile + NORTH + EAST;
        /* East. */ 
        default:
            return this.tile + EAST + SOUTH;
    }
}

/* Finds water depot close to the dock. */
function Dock::FindWaterDepot() {
    /* Artificial docks have its water depot in fixed place. */
    if(this.is_landdock) {
        local depot = _GetLandDockDepotLocation();
        if(!AIMarine.IsWaterDepotTile(depot))
            return -1;
        return depot;
    }
    
    /* Let's look nearby. */
    local depots = AIDepotList(AITile.TRANSPORT_WATER);
    depots.Valuate(AIMap.DistanceMax, this.tile);
    depots.KeepBelowValue(this.max_depot_distance + 1);
    if(depots.IsEmpty())
        return -1;
    depots.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return depots.Begin();    
}

function Dock::_BuildWaterDepot(depot) {
    switch(this.orientation) {
        /* West. */
        case 0:
            if(AIMarine.BuildWaterDepot(depot, depot + WEST))
                return depot;
            return -1;
        /* South. */
        case 1:
            if(AIMarine.BuildWaterDepot(depot, depot + SOUTH))
                return depot;
            return -1;
        /* North. */
        case 2:
            if(AIMarine.BuildWaterDepot(depot + NORTH, depot))
                return depot;
            return -1;
        /* East. */
        default:
            if(AIMarine.BuildWaterDepot(depot + EAST, depot))
                return depot;
            return -1;
    }
}

function Dock::_GetPossibleWaterDepotLocations() {
    local depotarea = AITileList();
    SafeAddRectangle(depotarea, this.tile, this.max_depot_distance);
    depotarea.RemoveItem(this.tile);
    if(!this.is_offshore) {
        /* We need to make sure we don't block the entry to the dock,
         * dock front, front and side entry tiles are removed from the list. */
        switch(this.orientation) {
            /* West. */
            case 0:
                depotarea.RemoveItem(this.tile + WEST);
                depotarea.RemoveItem(this.tile + WEST + WEST);
                depotarea.RemoveItem(this.tile + WEST + WEST + NORTH);
                depotarea.RemoveItem(this.tile + WEST + WEST + SOUTH);
                break;
            /* South. */
            case 1:
                depotarea.RemoveItem(this.tile + SOUTH);
                depotarea.RemoveItem(this.tile + SOUTH + SOUTH);
                depotarea.RemoveItem(this.tile + SOUTH + SOUTH + WEST);
                depotarea.RemoveItem(this.tile + SOUTH + SOUTH + EAST);
                break;
            /* North. */
            case 2:
                depotarea.RemoveItem(this.tile + NORTH);
                depotarea.RemoveItem(this.tile + NORTH + NORTH);
                depotarea.RemoveItem(this.tile + NORTH + NORTH + WEST);
                depotarea.RemoveItem(this.tile + NORTH + NORTH + EAST);
                break;
            /* East. */
            case 3:
                depotarea.RemoveItem(this.tile + EAST);
                depotarea.RemoveItem(this.tile + EAST + EAST);
                depotarea.RemoveItem(this.tile + EAST + EAST + NORTH);
                depotarea.RemoveItem(this.tile + EAST + EAST + SOUTH);
                break;
        }
    }
    depotarea.Valuate(_val_IsWaterDepotCapable, this.orientation);
    depotarea.KeepValue(1);
    depotarea.Valuate(AIMap.DistanceManhattan, this.tile);
    depotarea.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING); 
    return depotarea;
}

function Dock::CanHaveWaterDepotBuilt() {
    if(this.is_landdock)
        return true;

    return !_GetPossibleWaterDepotLocations().IsEmpty();
}

/* Builds water depot. */
function Dock::BuildWaterDepot() {
    if(this.is_landdock)
        return _BuildWaterDepot(_GetLandDockDepotLocation());   
 
    local depotarea = _GetPossibleWaterDepotLocations();
    for(local depot = depotarea.Begin(); !depotarea.IsEnd(); depot = depotarea.Next())
        if(_BuildWaterDepot(depot) != -1)
            return depot;
    return -1;
}

/* True if this dock had serviced specific cargo at some point. */
function Dock::HadOperatedCargo(cargo) {
    return AIStation.HasCargoRating(GetStationID(), cargo);
}

function Dock::GetCargoWaiting(cargo) {
    return AIStation.GetCargoWaiting(GetStationID(), cargo);
}

function Dock::GetVehicles() {
    return AIVehicleList_Station(GetStationID());
}

function Dock::GetDemolitionCost() {
    if(this.is_offshore)
        return 0;

    if(this.is_landdock)
        return 8 * AITile.GetBuildCost(AITile.BT_CLEAR_HOUSE) + 
               3 * AITile.GetBuildCost(AITile.BT_TERRAFORM);

    return 2 * AITile.GetBuildCost(AITile.BT_CLEAR_HOUSE);
}

function Dock::Demolish() {
    if(!IsValidStation())
        return false;

    if(this.is_offshore)
        return true;

    if(this.is_landdock) {
        switch(this.orientation) {
            case 0:
                /* To the West. */
                local ret = AITile.DemolishTile(this.tile);
                AITile.DemolishTile(GetHillFrontTile(this.tile, 1));
                AITile.DemolishTile(GetHillFrontTile(this.tile, 2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(1, -1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(2, -1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(3, -1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(3, 0));
                if(AITile.GetSlope(this.tile) == AITile.SLOPE_NE)
                    AITile.LowerTile(this.tile, AITile.SLOPE_NE);
                return ret;;
            case 1:
                /* To the South. */
                local ret = AITile.DemolishTile(this.tile);
                AITile.DemolishTile(GetHillFrontTile(this.tile, 1));
                AITile.DemolishTile(GetHillFrontTile(this.tile, 2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(1, 1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(1, 2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(1, 3));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(0, 3));
                if(AITile.GetSlope(this.tile) == AITile.SLOPE_NW)
                    AITile.LowerTile(this.tile, AITile.SLOPE_NW);
                return ret;
            case 2:
                /* To the North. */
                local ret = AITile.DemolishTile(this.tile);
                AITile.DemolishTile(GetHillFrontTile(this.tile, 1));
                AITile.DemolishTile(GetHillFrontTile(this.tile, 2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-1, -1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-1, -2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-1, -3));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(0, -3));
                if(AITile.GetSlope(this.tile) == AITile.SLOPE_SE)
                    AITile.LowerTile(this.tile, AITile.SLOPE_SE);
                return ret;
            case 3:
                /* To the East. */
                local ret = AITile.DemolishTile(this.tile);
                AITile.DemolishTile(GetHillFrontTile(this.tile, 1));
                AITile.DemolishTile(GetHillFrontTile(this.tile, 2));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-1, 1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-2, 1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-3, 1));
                AITile.DemolishTile(this.tile + AIMap.GetTileIndex(-3, 0));
                if(AITile.GetSlope(this.tile) == AITile.SLOPE_SW)
                    AITile.LowerTile(this.tile, AITile.SLOPE_SW);
                return ret;
            default:
                return false;
        }
    }

    return AITile.DemolishTile(this.tile);
}

