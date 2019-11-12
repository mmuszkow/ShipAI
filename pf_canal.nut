require("pf_coast.nut");
require("lock.nut");
require("utils.nut");

class CanalPathfinder {
    _aystar_class = null;
    _aystar = null;
    _dest = -1;
    _max_length = 100;

    /* max tiles left/right when we can place a lock (for reusing locks). */
    _max_adj_lock = 5;

    _reuse_cost = 1;
    _canal_cost = 5;

    path = [];
    
    constructor() {
        _aystar_class = import("graph.aystar", "", 6);
        _aystar = _aystar_class(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
        // not worth it, there is almost no performance gain
        //_aystar._queue_class = import("queue.fibonacci_heap", "", 3);
    }
}

function CanalPathfinder::UseInterLocks() {
    return AIController.GetSetting("build_interlocks");
}

function CanalPathfinder::UseAqueducts() {
    return AIController.GetSetting("build_aqueducts");
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
    if(!AIMap.IsValidTile(start) || !AIMap.IsValidTile(end) 
        || start == end || max_distance <= 0)
        return false;
    
    local dist = AIMap.DistanceManhattan(start, end);
    max_distance = min(max_distance, 50); /* TODO: improve performance instead */
    if(dist == -1 || dist > max_distance)
        return false;

    local lock1 = Lock(-1);
    local lock2 = Lock(-1);

    /* There is no array.find in Squirrel 2 so we convert it to AIList. */
    local sea_ignored_list = AITileList();
    foreach(tile in sea_ignored)
        sea_ignored_list.AddTile(tile); 
 
    /* Pathfinder operates on land only, if we are on the sealevel or the
       coast where the lock should be built is blocked, we need to find a place to put the lock. */
    if((AITile.GetMaxHeight(start) == 0) || sea_ignored_list.HasItem(start)) {
        lock1.tile = _FindAdjacentLockTile(start, end, sea_ignored_list);
        if(lock1.tile == -1)
            return false;

        /* Locks cannot be entered from sides. */
        foreach(tile in lock1.GetLowerSideTiles())
            sea_ignored_list.AddTile(tile);
        land_ignored.extend(lock1.GetUpperSideTiles());

        /* We start after leaving the lock. */
        land_ignored.push(lock1.GetUpperTile());
        start = lock1.GetUpperWaterTile();
    
    } else if(AIMarine.IsDockTile(start)) { /* height > 0 */
        /* Because we compare height in next step, we need to ensure we have the proper tile. */
        local dock = Dock(start);
        if(dock.is_landdock)
            start = dock.GetPfTile(end);
    }
    
    /* Do the same for the destination tile. */
    if((AITile.GetMaxHeight(end) == 0) || sea_ignored_list.HasItem(end)) {
        lock2.tile = _FindAdjacentLockTile(end, start, sea_ignored_list);
        if(lock2.tile == -1)
            return false;

        foreach(tile in lock2.GetLowerSideTiles())
            sea_ignored_list.AddTile(tile);
        land_ignored.extend(lock2.GetUpperSideTiles());
        land_ignored.push(lock2.GetUpperTile());
        end = lock2.GetUpperWaterTile();
    } else if(AIMarine.IsDockTile(end)) {
        local dock = Dock(end);
        if(dock.is_landdock)
            end = dock.GetPfTile(start);
    }

    if(start == -1 || end == -1 || (start == end))
        return false;

    /* We don't use locks in canals, so we won't be able to deal with height difference. */
    if(AITile.GetMaxHeight(start) != AITile.GetMaxHeight(end))
        return false;

    this._dest = end;
    this._max_length = max_distance;
    this._aystar.InitializePath([[start, this._GetDominantDirection(start, end)]], [end], land_ignored);
    local tmp_path = this._aystar.FindPath(10000);
    if(tmp_path == false || tmp_path == null)
        return false;
    if(lock2.tile != -1)
        this.path.append(lock2.tile);
    while(tmp_path != null) {
        this.path.append(tmp_path.GetTile());
        tmp_path = tmp_path.GetParent();
    }
    if(lock1.tile != -1)
        this.path.append(lock1.tile);
    this.path.reverse();
    
    return true;
}

function CanalPathfinder::_Cost(self, path, new_tile, new_direction) {
    if(path == null) return 0;
   
    /* Using existing canal. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsBuoyTile(new_tile) || 
        AITile.IsWaterTile(new_tile))
        return path.GetCost() + self._reuse_cost;
    
    /* Creating new canal tile */
    return path.GetCost() + self._canal_cost;
}

function CanalPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
    /* Result of this function can be multiplied by value greater than 1 to 
     * get results faster, but they won't be optimal */
    return AIMap.DistanceManhattan(cur_tile, self._dest);
}

function CanalPathfinder::_Neighbours(self, path, cur_node) {
    if(path.GetLength() + AIMap.DistanceManhattan(cur_node, self._dest) > self._max_length)
        return [];
    
    local tiles = [];
    local offsets = [
        cur_node + NORTH,
        cur_node + SOUTH,
        cur_node + WEST,
        cur_node + EAST
    ];
    foreach(tile in offsets) {
        if(tile == self._dest || ((AITile.GetSlope(tile) == AITile.SLOPE_FLAT) &&
            (AITile.IsBuildable(tile) || AIMarine.IsCanalTile(tile) ||
             AIMarine.IsBuoyTile(tile) || AITile.IsWaterTile(tile)) && 
            !AIMarine.IsWaterDepotTile(tile)) && !AIMarine.IsLockTile(tile))
            tiles.append([tile, self._GetDirection(cur_node, tile)]);
    }

    return tiles;
}

function CanalPathfinder::_CheckDirection(self, tile, existing_direction, new_direction) {
    return false;
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

