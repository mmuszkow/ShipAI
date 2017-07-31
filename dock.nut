require("utils.nut");

class Dock {
    tile = -1;
    orientation = -1;
    is_artificial = false;
    is_on_water = false;
    
    constructor(dock, artificial_orientation = -1, _is_on_water = false) {
        this.tile = dock;
        this.is_on_water = _is_on_water;
        
        if(!_is_on_water) {
            /* We need to find the hill tile. */
            if(AIMarine.IsDockTile(dock) && AITile.GetSlope(dock) == AITile.SLOPE_FLAT) {
                if(AIMarine.IsDockTile(dock + AIMap.GetTileIndex(0, 1)))
                    this.tile = dock + AIMap.GetTileIndex(0, 1);
                else if(AIMarine.IsDockTile(dock + AIMap.GetTileIndex(0, -1)))
                    this.tile = dock + AIMap.GetTileIndex(0, -1);
                else if(AIMarine.IsDockTile(dock + AIMap.GetTileIndex(1, 0)))
                    this.tile = dock + AIMap.GetTileIndex(1, 0);
                else if(AIMarine.IsDockTile(dock + AIMap.GetTileIndex(-1, 0)))
                    this.tile = dock + AIMap.GetTileIndex(-1, 0);
            }
            
            if(artificial_orientation != -1) {
                /* Artificial dock. */
                this.orientation = artificial_orientation;
                this.is_artificial = true;
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
                    this.is_artificial = true;
            }
        }
    }
}

function Dock::GetName() {
    return AIStation.GetName(AIStation.GetStationID(this.tile));
}

/* Line pathfinder takes 2 water tiles as input.
   Coast pathfinder takes 2 coast tiles as input.
   Canal pathfinder takes 2 canal tiles as input. */   
function Dock::GetPfTile(dest = -1) {
    /* Some industries (offshores only?) can have a dock built on water which will break the line pathfinder. 
       We need to find a tile that is not obstructed by the industry itself. */
    if(this.is_on_water) {
        if(dest == -1)
            return -1;
        
        local water = AITileList();
        SafeAddRectangle(water, this.tile, 4);
        water.Valuate(AIMap.DistanceManhattan, dest);
        water.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        if(water.IsEmpty())
            return -1; /* Something's wrong... */
        
        //AISign.BuildSign(water.Begin(), "x");
        return water.Begin();
    }
    
    /* For artificial industries (canal pathfinder) we take the canal tile in front of the dock. */
    if(this.is_artificial) {
        switch(this.orientation) {
            case 0:
                /* West. */
                return this.tile + AIMap.GetTileIndex(2, 0);
            case 1:
                /* South. */
                return this.tile + AIMap.GetTileIndex(0, 2);
            case 2:
                /* North. */
                return this.tile + AIMap.GetTileIndex(0, -2);
            case 3:
                /* East. */
                return this.tile + AIMap.GetTileIndex(-2, 0);
            default:
                return -1;
        }
    }
    
    /* For coast dock (line, coast pathfinder) we return the coast tile itself. */
    return this.tile;
}

function Dock::GetOccupiedTiles() {
    local tiles = [];
    tiles.append(this.tile);
    switch(orientation) {
        case 0:
            /* West */
            tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
            if(this.is_artificial) {        
                tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(2, -1));
            }
            return tiles;
        case 1:
            /* South. */
            tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
            if(this.is_artificial) {
                tiles.append(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.append(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 2));
            }
            return tiles;
        case 2:
            /* North. */
            tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
            if(this.is_artificial) {
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
            if(this.is_artificial) {
                tiles.append(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.append(this.tile + AIMap.GetTileIndex(1, 0));
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

function _val_IsLockCapable(tile) {
    if(!IsSimpleSlope(tile) || (!AIMarine.IsLockTile(tile) && !AITile.IsBuildable(tile)))
        return false;

    local front1 = GetHillFrontTile(tile, 1);
    local front2 = GetHillFrontTile(tile, 2);
    local back1 = GetHillBackTile(tile, 1);
    local back2 = GetHillBackTile(tile, 2);
    if( AITile.GetSlope(front1) != AITile.SLOPE_FLAT || 
        AITile.GetSlope(front2) != AITile.SLOPE_FLAT || 
        AITile.GetSlope(back1) != AITile.SLOPE_FLAT || 
        AITile.GetSlope(back2) != AITile.SLOPE_FLAT)
        return false;
    
    if(AIMarine.IsLockTile(tile) && AIMarine.IsLockTile(front1) && AIMarine.IsLockTile(back1))
        return true;
    
    return  ((AITile.IsWaterTile(front1) && !AIMarine.IsWaterDepotTile(front1) && !AIBridge.IsBridgeTile(front1)) &&
             (AITile.IsWaterTile(front2) && !AIMarine.IsWaterDepotTile(front2)) &&
             (AITile.IsBuildable(back1) || AITile.IsWaterTile(back1)) &&
             (AITile.IsBuildable(back2)  || AITile.IsWaterTile(back2)));
}

function _val_IsWaterDepotCapable(tile, orientation) {
    if(!AITile.IsWaterTile(tile) || AIBridge.IsBridgeTile(tile))
        return false;
    
    local back, front;
    switch(orientation) {
        /* West. */
        case 0:
            back = tile + AIMap.GetTileIndex(-1, 0);
            front = tile + AIMap.GetTileIndex(1, 0);
            break;
        /* South. */
        case 1:
            back = tile + AIMap.GetTileIndex(0, -1);
            front = tile + AIMap.GetTileIndex(0, 1);
            break;
        /* North. */
        case 2:
            back = tile + AIMap.GetTileIndex(0, 1);
            front = tile + AIMap.GetTileIndex(0, -1);
            break;
        /* East. */
        default:
            back = tile + AIMap.GetTileIndex(1, 0);
            front = tile + AIMap.GetTileIndex(-1, 0);
            break;
    }
    return AITile.IsWaterTile(back) && !AIBridge.IsBridgeTile(back) && AITile.IsWaterTile(front);
}

function Dock::GetNecessaryCoastCrossesTo(dock2) {
    local coasts = [];
    local tmp = this.tile;
    local x0 = AIMap.GetTileX(this.tile), y0 = AIMap.GetTileY(this.tile);
    local x1 = AIMap.GetTileX(dock2.tile), y1 = AIMap.GetTileY(dock2.tile);
    local dx = abs(x1 - x0), dy = abs(y1 - y0);
    local sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    local err = (dx > dy ? dx : -dy)/2, e2;
    while(true) {
        tmp = AIMap.GetTileIndex(x0, y0);
        if(AITile.IsCoastTile(tmp))
            coasts.append(tmp);
        if(tmp == dock2.tile)
            break;        
        e2 = err;
        if(e2 >-dx) { err -= dy; x0 += sx; }
        if(e2 < dy) { err += dx; y0 += sy; }
    }
    return coasts;
}

function Dock::GetLockNearby() {
    local tiles = AITileList();
    SafeAddRectangle(tiles, this.tile, 5);
    tiles.Valuate(AIMarine.IsLockTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetSlope);
    tiles.RemoveValue(AITile.SLOPE_FLAT);
    /* Return existing lock. */
    if(!tiles.IsEmpty()) {
        tiles.Valuate(AIMap.DistanceManhattan, this.tile);
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return tiles.Begin();
    }
    
    /* Find possible lock location. */
    tiles = AITileList();
    SafeAddRectangle(tiles, this.tile, 5);
    tiles.Valuate(_val_IsLockCapable);
    tiles.KeepValue(1);
    if(tiles.IsEmpty())
        return -1;
    
    tiles.Valuate(AIMap.DistanceManhattan, this.tile);
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return tiles.Begin();
}

function Dock::EstimateCost() {
    if(this.is_on_water || AIMarine.IsDockTile(this.tile))
        return 0;
    if(!this.is_artificial)
        return AIMarine.GetBuildCost(AIMarine.BT_DOCK);
    
    /* TODO */
    //return  AIMarine.GetBuildCost(AIMarine.BT_DOCK) + 
    //        2 * AITile.GetBuildCost(BT_TERRAFORM) + /* raise */
    //        12 * AITile.GetBuildCost(BT_CLEAR_FIELDS) + /* worst case */
    //        6000;
    local test = AITestMode();
    local costs = AIAccounting();
    this.Build();
    return costs.GetCosts();
}

function Dock::Build() {
    /* Already there. */
    if(this.is_on_water ||
        (AIMarine.IsDockTile(this.tile)  && (AITile.GetOwner(this.tile) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))))
        return this.tile;
        
    /* Artificial dock. */
    if(this.is_artificial) {      
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

/* This is the default water depot location. */
function Dock::_GetBestWaterDepotLocation() {
    local best = -1;
    switch(this.orientation) {
        /* West. */
        case 0:
            if(this.is_artificial)
                best = this.tile + AIMap.GetTileIndex(2, -1);
            else
                best = this.tile + AIMap.GetTileIndex(4, 0);
            break;
        /* South. */
        case 1:
            if(this.is_artificial)
                best = this.tile + AIMap.GetTileIndex(1, 2);
            else
                best = this.tile + AIMap.GetTileIndex(0, 4);
            break;
        /* North. */
        case 2:
            if(this.is_artificial)
                best = this.tile + AIMap.GetTileIndex(-1, -2);
            else
                best = this.tile + AIMap.GetTileIndex(0, -4);
            break;
        /* East. */
        default:
            if(this.is_artificial)
                best = this.tile + AIMap.GetTileIndex(-2, 1);
            else
                best = this.tile + AIMap.GetTileIndex(-4, 0);
            break;
    }
    return best;
}

/* Finds water depot close to the dock. */
function Dock::FindWaterDepot() {
    local best = _GetBestWaterDepotLocation();
    
    /* Artificial docks have fixed place to build the water depot. */
    if(this.is_artificial && best == -1)
        return -1;
    
    if(best != -1 &&
        AIMarine.IsWaterDepotTile(best) && 
        (AITile.GetOwner(best) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)))
        return best;

    /* Let's look nearby. */
    local depots = AIDepotList(AITile.TRANSPORT_WATER);
    depots.Valuate(AIMap.DistanceManhattan, this.tile);
    depots.KeepBelowValue(6);
    if(depots.IsEmpty())
        return -1;
    
    depots.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return depots.Begin();    
}

function Dock::_TryBuildWaterDepot(depot) {
    if(AIMarine.IsWaterDepotTile(depot) &&
        (AITile.GetOwner(depot) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)))
        return depot;
    
    switch(this.orientation) {
        /* West. */
        case 0:
            /* BuildWaterDepot has some weird direction interpretation. */
            if(AIMarine.BuildWaterDepot(depot + AIMap.GetTileIndex(-1, 0), depot + AIMap.GetTileIndex(1, 0)))
                return depot;
            return -1;
        /* South. */
        case 1:
            /* BuildWaterDepot has some weird direction interpretation. */
            if(AIMarine.BuildWaterDepot(depot + AIMap.GetTileIndex(0, -1), depot + AIMap.GetTileIndex(0, 1)))
                return depot;
            return -1;
        /* North. */
        case 2:
            if(AIMarine.BuildWaterDepot(depot, depot + AIMap.GetTileIndex(0, -1)))
                return depot;
            return -1;
        /* East. */
        default:
            if(AIMarine.BuildWaterDepot(depot, depot + AIMap.GetTileIndex(-1, 0)))
                return depot;
            return -1;
    }
}

/* Builds water depot. */
function Dock::BuildWaterDepot() {
    /* Let's try best locations first. */
    local best = _GetBestWaterDepotLocation();
    
    /* Artificial docks have fixed place to build the water depot. */
    if(this.is_artificial && best == -1)
        return -1;
    
    if(_TryBuildWaterDepot(best) != -1)
        return best;
    
    local depotarea = AITileList();
    SafeAddRectangle(depotarea, this.tile, 5);
    depotarea.RemoveItem(this.tile);
    if(!is_artificial && !is_on_water) {
        depotarea.RemoveItem(GetHillFrontTile(this.tile, 1));
        depotarea.RemoveItem(GetHillFrontTile(this.tile, 2));
    }
    depotarea.Valuate(_val_IsWaterDepotCapable, this.orientation);
    depotarea.KeepValue(1);
    depotarea.Valuate(AIMap.DistanceManhattan, this.tile);
    depotarea.KeepAboveValue(3);
    depotarea.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    
    for(local depot = depotarea.Begin(); depotarea.HasNext(); depot = depotarea.Next())
        if(_TryBuildWaterDepot(depot) != -1)
            return depot;
    return -1;
}

function Dock::GetCargoWaiting(cargo) {
    local station_id = AIStation.GetStationID(this.tile);
    if(!AIStation.IsValidStation(station_id) || !AIStation.HasCargoRating(station_id, cargo))
        return 0;
    return AIStation.GetCargoWaiting(station_id, cargo)
}