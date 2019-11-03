require("utils.nut");

class CanalPathfinder {
    _aystar_class = null;
    _aystar = null;
    _dest = -1;
    _max_length = 100;

    path = [];
    
    constructor() {
        _aystar_class = import("graph.aystar", "", 6);
        _aystar = _aystar_class(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    }
}

function _val_IsLockCapableCoast(tile, ignored) {
    if(!AITile.IsCoastTile(tile) || !IsSimpleSlope(tile))
        return false;
    if(AIMarine.IsLockTile(tile))
        return true;
    local front1 = GetHillFrontTile(tile, 1);
    local back1 = GetHillBackTile(tile, 1);
    return  AITile.IsWaterTile(front1) && !AIMarine.IsCanalTile(back1) &&
            AITile.IsWaterTile(GetHillFrontTile(tile, 2)) && /* we need space in front so ship can enter */
            AITile.IsWaterTile(GetHillFrontTile(tile, 3)) && /* additional space so we don't block lock in front */
            AITile.IsBuildable(back1) && (AITile.GetSlope(back1) == AITile.SLOPE_FLAT)
            !ArrayContains(ignored, tile) && !ArrayContains(ignored, back1) && !ArrayContains(ignored, front1);
}

/* Finds a lock/possible lock tile next to the water tile. */
function CanalPathfinder::_FindAdjacentLockTile(water, direction, ignored) {
    /* Let's look for existing locks first. */
    local tiles = AITileList();
    SafeAddRectangle(tiles, water, 3);
    tiles.Valuate(IsSimpleSlope);
    tiles.KeepValue(1);
    tiles.Valuate(AIMarine.IsLockTile);
    tiles.KeepValue(1);
    if(!tiles.IsEmpty()) {
        tiles.Valuate(AIMap.DistanceManhattan, direction);
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return tiles.Begin();
    }

    tiles = AITileList();
    SafeAddRectangle(tiles, water, 3);
    tiles.Valuate(_val_IsLockCapableCoast, ignored);
    tiles.KeepValue(1);
    tiles.Valuate(AIMap.DistanceManhattan, direction);
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    if(tiles.IsEmpty())
        return -1;
    return tiles.Begin();
}

function CanalPathfinder::_LockGetExitSideTiles(lock) {
    switch(AITile.GetSlope(lock)) {
        case AITile.SLOPE_NE:
            /* West */
            return [lock + AIMap.GetTileIndex(-1, -1), lock + AIMap.GetTileIndex(-1, 1)];
        case AITile.SLOPE_NW:
            /* South. */
            return [lock + AIMap.GetTileIndex(-1, -1), lock + AIMap.GetTileIndex(1, -1)];
        case AITile.SLOPE_SE:
            /* North. */
            return [lock + AIMap.GetTileIndex(-1, 1), lock + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_SW:
            /* East. */
            return [lock + AIMap.GetTileIndex(1, -1), lock + AIMap.GetTileIndex(1, 1)];
        default:
            return [];
    }
}

function CanalPathfinder::_LockGetEntrySideTiles(lock) {
    switch(AITile.GetSlope(lock)) {
        case AITile.SLOPE_NE:
            /* West */
            return [lock + AIMap.GetTileIndex(1, -1), lock + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_NW:
            /* South. */
            return [lock + AIMap.GetTileIndex(-1, 1), lock + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_SE:
            /* North. */
            return [lock + AIMap.GetTileIndex(-1, -1), lock + AIMap.GetTileIndex(1, -1)];
        case AITile.SLOPE_SW:
            /* East. */
            return [lock + AIMap.GetTileIndex(-1, -1), lock + AIMap.GetTileIndex(-1, 1)];
        default:
            return [];
    }
}

/* There is no 'find' in Squirrel 2. */
function ArrayContains(arr, elem) {
    foreach(item in arr) if(item == elem) return true;
    return false;
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

    local lock1 = -1;
    local lock2 = -1;
    
    //foreach(item in land_ignored) AISign.BuildSign(item, "l");
    //foreach(item in sea_ignored) AISign.BuildSign(item, "s");

    /* Pathfinder operated on land only, if we are on the sealevel or the
       coast where the lock should be is blocked, we need to find a place to put the lock. */
    if((AITile.GetMaxHeight(start) == 0) || ArrayContains(sea_ignored, start)) {
        lock1 = _FindAdjacentLockTile(start, end, sea_ignored);
        if(lock1 == -1)
            return false;

        /* Locks cannot be entered from sides. */
        sea_ignored.extend(_LockGetEntrySideTiles(lock1));
        land_ignored.extend(_LockGetExitSideTiles(lock1));

        /* We start after leaving the lock. */
        land_ignored.push(GetHillBackTile(lock1, 1));
        start = GetHillBackTile(lock1, 2);
    
    } else if(AIMarine.IsDockTile(start)) { /* height > 0 */
        /* Because we compare height in next step, we need to ensure we have the proper tile. */
        local dock = Dock(start);
        if(dock.is_landdock)
            start = dock.GetPfTile(end);
    }
    
    /* Do the same for the destination tile. */
    if((AITile.GetMaxHeight(end) == 0) || ArrayContains(sea_ignored, end)) {
        lock2 = _FindAdjacentLockTile(end, start, sea_ignored);
        if(lock2 == -1)
            return false;

        sea_ignored.extend(_LockGetEntrySideTiles(lock2));
        land_ignored.extend(_LockGetExitSideTiles(lock2));
        land_ignored.push(GetHillBackTile(lock2, 1));
        end = GetHillBackTile(lock2, 2);
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
    if(lock2 != -1)
        this.path.append(lock2);
    while(tmp_path != null) {
        this.path.append(tmp_path.GetTile());
        tmp_path = tmp_path.GetParent();
    }
    if(lock1 != -1)
        this.path.append(lock1);
    this.path.reverse();
    
    //local r = AIBase.Rand() % 100;
    //AISign.BuildSign(start, "s"+r+"_"+this.path.len());
    //AISign.BuildSign(end, "e"+r+"_"+this.path.len());;

    return true;
}

function CanalPathfinder::_Cost(self, path, new_tile, new_direction) {
    if(path == null) return 0;
   
    /* Using existing canal. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsBuoyTile(new_tile) || 
        AITile.IsWaterTile(new_tile))
        return path.GetCost() + 1;
    
    /* Creating new canal tile */
    return path.GetCost() + 5;
}

function CanalPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
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
            !AIMarine.IsWaterDepotTile(tile)))
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

