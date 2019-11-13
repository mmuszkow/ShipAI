require("aystar.nut");
require("pf_coast.nut");
require("aqueduct.nut");
require("lock.nut");
require("utils.nut");

class CanalPathfinder {
    _aystar = null;
    _max_length = 100;

    /* max tiles left/right when we can place a lock (for reusing locks). */
    _max_adj_lock = 5;

    _reuse_cost = 1;
    _canal_cost = 5;
    _lock_cost = 14;
    _bridge_cost_multiplier = 2; /* canal cost is multiplied by that */
    
    path = [];
    infrastructure = [];    

    constructor() {
        _aystar = AyStar(this, this._Cost, this._Estimate, this._Neighbours);
    }
}

function _val_IsLockCapableCoast(tile, ignored) {
    if(!AITile.IsCoastTile(tile) || !IsSimpleSlope(tile))
        return false;
    local front1 = GetHillFrontTile(tile, 1);
    local front2 = GetHillFrontTile(tile, 2);
    local back1 = GetHillBackTile(tile, 1);
    foreach(item in ignored)
        if(item == tile || item == front1 || item == front2 || item == back1)
            return false;
    return  AITile.IsWaterTile(front1) && (AITile.GetSlope(front1) == AITile.SLOPE_FLAT) &&
            /* dont destroy existing canals */
            !AIMarine.IsCanalTile(back1) &&
            /* we need space in front so ship can enter */
            AITile.IsWaterTile(front2) && (AITile.GetSlope(front2) == AITile.SLOPE_FLAT) &&
            /* additional space so we don't block lock in front */
            AITile.IsWaterTile(GetHillFrontTile(tile, 3)) &&
            AITile.IsBuildable(back1) && (AITile.GetSlope(back1) == AITile.SLOPE_FLAT);
}

/* Finds a lock/possible lock tile next to the water tile. */
function CanalPathfinder::_FindAdjacentLockTile(water, direction, ignored) {
    /* Get coast tile next to water. */
    local adj = AITileList();
    SafeAddRectangle(adj, water, 1);
    adj.Valuate(AITile.GetSlope);
    adj.RemoveValue(AITile.SLOPE_FLAT);
    if(adj.IsEmpty())
        return -1;
    adj.Valuate(AIMap.DistanceManhattan, direction);
    adj.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    local coast = adj.Begin();

    /* Follow few tiles each way. */
    local path_r = CoastPathfinder.Path(coast, direction, true, 999999);
    local path_l = CoastPathfinder.Path(coast, direction, false, 999999);
    local coastal = AITileList();
    for(local i=0 ; i<this._max_adj_lock; i++) {
        if(path_r.Estimate() > 0) coastal.AddTile(path_r._tile);
        if(path_l.Estimate() > 0) coastal.AddTile(path_l._tile);
    }
    coastal.RemoveList(ignored);
    if(coastal.IsEmpty())
        return -1;

    /* Let's look for existing locks first. */
    local locks = AITileList();
    locks.AddList(coastal);
    locks.Valuate(AIMarine.IsLockTile);
    locks.KeepValue(1);
    if(!locks.IsEmpty()) {
        locks.Valuate(AIMap.DistanceManhattan, direction);
        locks.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return locks.Begin();
    }

    /* No locks? Take coast closest to direction. */
    coastal.Valuate(_val_IsLockCapableCoast, ignored);
    coastal.KeepValue(1);
    coastal.Valuate(AIMap.DistanceManhattan, direction);
    coastal.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    if(coastal.IsEmpty())
        return -1;
    return coastal.Begin();
}

function CanalPathfinder::FindPath(start, end, max_distance, land_ignored, sea_ignored) {
    this.path = [];
    this.infrastructure = [];
    if(!AIMap.IsValidTile(start) || !AIMap.IsValidTile(end) 
        || start == end || max_distance <= 0)
        return false;
    
    local dist = AIMap.DistanceManhattan(start, end);
    max_distance = min(max_distance, 50); /* TODO: improve performance instead */
    if(dist == -1 || dist > max_distance)
        return false;

    local lock1 = Lock(-1);
    local lock2 = Lock(-1);

    /* Pathfinder operates on land only, if we are on the sealevel or the
       coast where the lock should be built is blocked, we need to find a place to put the lock. */
    if((AITile.GetMaxHeight(start) == 0) || sea_ignored.HasItem(start)) {
        lock1.tile = _FindAdjacentLockTile(start, end, sea_ignored);
        if(lock1.tile == -1)
            return false;

        /* Locks cannot be entered from sides. */
        sea_ignored.AddList(lock1.GetLowerSideTiles());
        land_ignored.AddList(lock1.GetUpperSideTiles());

        /* We start after leaving the lock. */
        land_ignored.AddTile(lock1.GetUpperTile());
        start = lock1.GetUpperWaterTile();
    
    } else if(AIMarine.IsDockTile(start)) { /* height > 0 */
        /* Because we compare height in next step, we need to ensure we have the proper tile. */
        local dock = Dock(start);
        if(dock.is_landdock)
            start = dock.GetPfTile(end);
    }
    
    /* Do the same for the destination tile. */
    if((AITile.GetMaxHeight(end) == 0) || sea_ignored.HasItem(end)) {
        lock2.tile = _FindAdjacentLockTile(end, start, sea_ignored);
        if(lock2.tile == -1)
            return false;

        sea_ignored.AddList(lock2.GetLowerSideTiles());;
        land_ignored.AddList(lock2.GetUpperSideTiles());
        land_ignored.AddTile(lock2.GetUpperTile());
        end = lock2.GetUpperWaterTile();
    } else if(AIMarine.IsDockTile(end)) {
        local dock = Dock(end);
        if(dock.is_landdock)
            end = dock.GetPfTile(start);
    }

    if(start == -1 || end == -1 || (start == end))
        return false;

    // TODO: inner lock pf, for now we can't change heights
    if(AITile.GetMaxHeight(start) != AITile.GetMaxHeight(end))
        return false;

    this._max_length = max_distance;
    this._aystar.InitializePath([start, this._GetDominantDirection(start, end), null], end, land_ignored);
    local tmp_path = this._aystar.FindPath(10000);
    if(tmp_path == false || tmp_path == null)
        return false;
    if(lock2.tile != -1)
        this.infrastructure.append(lock2);
    while(tmp_path != null) {
        this.path.append(tmp_path.tile);
        if(tmp_path.infrastructure != null)
            this.infrastructure.append(tmp_path.infrastructure);
        tmp_path = tmp_path.prev;
    }
    if(lock1.tile != -1)
        this.infrastructure.append(lock1);
    this.path.reverse();
    
    return true;
}

function CanalPathfinder::_Cost(self, path, new_tile, new_direction) {
    if(path == null)
        return 0;
   
    /* Building infrastructure cost. */
    local cost = 0;
    if(path.infrastructure != null) {
        if(path.infrastructure.Exists())
            cost += AIMap.DistanceManhattan(path.tile, new_tile) * self._reuse_cost;
        else if(path.infrastructure instanceof Aqueduct)
            cost += path.infrastructure.Length() * self._canal_cost * self._bridge_cost_multiplier;
        else
            cost += self._lock_cost;
    }

    /* Reusing existing tile. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsBuoyTile(new_tile) || 
        AITile.IsWaterTile(new_tile))
        return path.cost + cost + self._reuse_cost;
    
    /* Creating new canal tile */
    return path.cost + cost + self._canal_cost;
}

function CanalPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
    /* Result of this function can be multiplied by value greater than 1 to 
     * get results faster, but they won't be optimal */
    return AIMap.DistanceManhattan(cur_tile, self._aystar._goal);
}

function CanalPathfinder::_CanBeCanal(tile) {
    return AITile.GetSlope(tile) == AITile.SLOPE_FLAT &&
          (AITile.IsBuildable(tile) || AIMarine.IsCanalTile(tile) ||
           AIMarine.IsBuoyTile(tile) || AITile.IsWaterTile(tile)) &&
          !AIMarine.IsWaterDepotTile(tile);
}

function CanalPathfinder::_Neighbours(self, path, cur_node) {
    if(path.length + AIMap.DistanceManhattan(cur_node, self._aystar._goal) > self._max_length)
        return [];
    
    local tiles = [];
    local offsets = [
        NORTH,
        SOUTH,
        WEST,
        EAST
    ];

    foreach(offset in offsets) {
        local next = cur_node + offset;
        if(next == self._aystar._goal) {
            tiles.append([next, self._GetDirection(cur_node, next), null]);
            continue;
        }

        switch(AITile.GetSlope(next)) {
            case AITile.SLOPE_FLAT:
                // TODO: lock pf
                //if(AIMarine.IsLockTile(next)) {
                //    /* Reuse existing lock if not leading to the sea. */
                //    local lock_tile = next + offset;
                //    if(AIMarine.IsLockTile(lock_tile) && AITile.GetMinHeight(lock_tile) > 0) {
                //        local lock = Lock(lock_tile);
                //        local exit = -1;
                //        if(next == lock.GetUpperTile())
                //            exit = lock.GetLowerWaterTile();
                //        else
                //            exit = lock.GetUpperWaterTile(); 
                //        if(exit != -1 && self._CanBeCanal(exit))
                //            tiles.append([exit, self._GetDirection(cur_node, exit), lock]);
                //    }  
                //} else if(self._CanBeCanal(next))
                //    tiles.append([next, self._GetDirection(cur_node, next), null]);
                
                if(self._CanBeCanal(next))
                    tiles.append([next, self._GetDirection(cur_node, next), null]);

                /* Check if can place a lock two tiles ahead. */
                //local next_2 = next + offset;
                //if(!AIMap.IsValidTile(next_2) || AITile.GetMinHeight(next_2) == 0 || !IsSimpleSlope(next_2))
                //    continue;
                //local next_3 = next_2 + offset;
                //if(!AIMap.IsValidTile(next_3) || !self._CanBeCanal(next_3))
                //    continue;
                //local lock_exit = next_3 + offset;
                //if(AIMap.IsValidTile(lock_exit) || self._CanBeCanal(lock_exit)) {
                //    local lock = Lock(next_2);
                //    tiles.append([lock_exit, self._GetDirection(cur_node, lock_exit), lock]);
                //}
                break;
            /* Simple slopes. */
            case AITile.SLOPE_NE:
            case AITile.SLOPE_NW:
            case AITile.SLOPE_SE:
            case AITile.SLOPE_SW:
                /* Slope down, not leading to the sea - candidate for the aqueduct. */
                if(AITile.GetMinHeight(next) > 0 && AITile.GetMinHeight(next) < AITile.GetMinHeight(cur_node)) {
                    /* Check for existing bridge. */
                    if(AIBridge.IsBridgeTile(next)) {
                        /* Must be water, not rail or road bridge. */
                        if(AITile.HasTransportType(next, AITile.TRANSPORT_WATER)) {
                            /* Reuse existing aqueduct. */
                            local aqueduct = Aqueduct(next);
                            local exit = aqueduct.GetFront2();
                            if(exit != -1 && self._CanBeCanal(exit))
                                tiles.append([exit, self._GetDirection(cur_node, exit), aqueduct]);
                        }
                    } else {
                        /* Build new aqueduct. */
                        local aqueduct = Aqueduct(next);
                        local exit = aqueduct.GetFront2();
                        if(exit != -1 && self._CanBeCanal(exit))
                            tiles.append([exit, self._GetDirection(cur_node, exit), aqueduct]);
                    }
                }
                break;
            default:
                break; 
        }
    }

    return tiles;
}

function CanalPathfinder::_GetDominantDirection(from, to) {
    local xDistance = AIMap.GetTileX(from) - AIMap.GetTileX(to);
    local yDistance = AIMap.GetTileY(from) - AIMap.GetTileY(to);
    if (abs(xDistance) >= abs(yDistance)) {
        if (xDistance < 0) return 2;                    // Left
        if (xDistance > 0) return 1;                    // Right
    } else {
        if (yDistance < 0) return 8;                    // Down
        if (yDistance > 0) return 4;                    // Up
    }
}

function CanalPathfinder::_GetDirection(from, to) {
    if (from - to >= AIMap.GetMapSizeX()) return 4;     // Up
    if (from - to > 0) return 1;                        // Right
    if (from - to <= -AIMap.GetMapSizeX()) return 8;    // Down
    if (from - to < 0) return 2;                        // Left
}

