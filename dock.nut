require("global.nut");
require("utils.nut");

class Dock {
    tile = -1;
    orientation = -1;
    is_landdock = false;
    is_offshore = false;
    
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
                        break;
                    case AITile.SLOPE_NW:
                        /* South. */
                        this.orientation = 1;
                        break;
                    case AITile.SLOPE_SE:
                        /* North. */
                        this.orientation = 2;
                        break;
                    case AITile.SLOPE_SW:
                        /* East. */
                        this.orientation = 3;
                        break;
                    default:
                        this.orientation = -1;
                        break;
                }
                
                if(this.orientation != -1 && AIMarine.IsCanalTile(GetHillFrontTile(this.tile, 2)))
                    this.is_landdock = true;
            }
        }
    }
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
    local tiles = [];
    tiles.append(this.tile);
    switch(orientation) {
        case 0:
            /* West */
            tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
            tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
            if(this.is_landdock) {        
                tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(2, -1));
            }
            return tiles;
        case 1:
            /* South. */
            tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
            tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
            if(this.is_landdock) {
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 2));
            }
            return tiles;
        case 2:
            /* North. */
            tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
            tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
            if(this.is_landdock) {
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -2));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -3));
            }
            return tiles;
        case 3:
            /* East. */
            tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
            tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
            if(this.is_landdock) {
                tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(-2, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 1));
            }
            return tiles;
        default:
            return [];
    }
}

function _val_IsDockCapable(tile) {
    if(!AITile.IsBuildable(tile) || !IsSimpleSlope(tile))
        return false;
    
    local front1 = GetHillFrontTile(tile, 1);
    local front2 = GetHillFrontTile(tile, 2);
    if(AITile.GetSlope(front1) != AITile.SLOPE_FLAT || AITile.GetSlope(front2) != AITile.SLOPE_FLAT)
        return false;
    
    return AITile.IsWaterTile(front1) && !AIBridge.IsBridgeTile(front1) &&
        AITile.IsWaterTile(front2) && !AIMarine.IsWaterDepotTile(front2);
}

/* Should be used only for sea */
function _val_IsWaterDepotCapable(tile, orientation) {
    if(!AITile.IsWaterTile(tile) || AITile.GetMaxHeight(tile) > 0 || AIBridge.IsBridgeTile(tile))
        return false;
    
    /* back is the depot tile, front is the tile in front of the depot,
     * left/right are side tiles. */
    local back, front, left1, left2, right1, right2;
    switch(orientation) {
        /* West. */
        case 0:
            back = tile + EAST;
            front = tile + WEST;
            left1 = tile + SOUTH;
            left2 = tile + SOUTH;
            right1 = tile + NORTH;
            right2 = tile + NORTH;
            break;
        /* South. */
        case 1:
            back = tile + NORTH;
            front = tile + SOUTH;
            left1 = tile + EAST;
            left2 = tile + EAST;
            right1 = tile + WEST;
            right2 = tile + WEST;
            break;
        /* North. */
        case 2:
            back = tile + SOUTH;
            front = tile + NORTH;
            left1 = tile + WEST;
            left2 = tile + WEST;
            right1 = tile + EAST;
            right2 = tile + EAST;
            break;
        /* East. */
        default:
            back = tile + WEST;
            front = tile + EAST;
            left1 = tile + NORTH;
            left2 = tile + NORTH;
            right1 = tile + SOUTH;
            right2 = tile + SOUTH;
            break;
    }
    
    /* Must have at least one exit and shouldn't block
       any infrastructure on the sides (like dock or lock). */
    return AITile.IsWaterTile(back) && !AIBridge.IsBridgeTile(back) &&
           AITile.IsWaterTile(front) && AITile.IsWaterTile(left1) &&
           AITile.IsWaterTile(left2) && AITile.IsWaterTile(right1) &&
           AITile.IsWaterTile(right2);
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
    /* Already there. */
    if(this.is_offshore ||
        (AIMarine.IsDockTile(this.tile)  && (AITile.GetOwner(this.tile) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))))
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
            return this.tile + AIMap.GetTileIndex(2, -1);
        /* South. */
        case 1:
            return this.tile + AIMap.GetTileIndex(1, 2);
            /* North. */
        case 2:
            return this.tile + AIMap.GetTileIndex(-1, -2);
            /* East. */ 
        default:
            return this.tile + AIMap.GetTileIndex(-2, 1);
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
    depots.Valuate(AIMap.DistanceManhattan, this.tile);
    depots.KeepBelowValue(6);
    if(depots.IsEmpty())
        return -1;
    depots.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return depots.Begin();    
}

function Dock::_BuildWaterDepot(depot) {
    switch(this.orientation) {
        /* West. */
        case 0:
            /* BuildWaterDepot has some weird direction interpretation. */
            if(AIMarine.BuildWaterDepot(depot + EAST, depot + WEST))
                return depot;
            return -1;
        /* South. */
        case 1:
            /* BuildWaterDepot has some weird direction interpretation. */
            if(AIMarine.BuildWaterDepot(depot + NORTH, depot + SOUTH))
                return depot;
            return -1;
        /* North. */
        case 2:
            if(AIMarine.BuildWaterDepot(depot, depot + NORTH))
                return depot;
            return -1;
        /* East. */
        default:
            if(AIMarine.BuildWaterDepot(depot, depot + EAST))
                return depot;
            return -1;
    }
}

/* Builds water depot. */
function Dock::BuildWaterDepot() {
    if(this.is_landdock)
        return _BuildWaterDepot(_GetLandDockDepotLocation());   
 
    local depotarea = AITileList();
    SafeAddRectangle(depotarea, this.tile, 5);
    depotarea.RemoveItem(this.tile);
    if(!this.is_offshore) {
        depotarea.RemoveItem(GetHillFrontTile(this.tile, 1));
        depotarea.RemoveItem(GetHillFrontTile(this.tile, 2));
    }
    depotarea.Valuate(_val_IsWaterDepotCapable, this.orientation);
    depotarea.KeepValue(1);
    depotarea.Valuate(AIMap.DistanceManhattan, this.tile);
    depotarea.KeepAboveValue(3);
    depotarea.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING); 
    for(local depot = depotarea.Begin(); !depotarea.IsEnd(); depot = depotarea.Next())
        if(_BuildWaterDepot(depot) != -1)
            return depot;
    return -1;
}

function Dock::GetCargoWaiting(cargo) {
    local station_id = AIStation.GetStationID(this.tile);
    if(!AIStation.IsValidStation(station_id) || !AIStation.HasCargoRating(station_id, cargo))
        return 0;
    return AIStation.GetCargoWaiting(station_id, cargo)
}
