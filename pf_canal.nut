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

function _val_IsLockCapableCoast(tile) {
    if(!AITile.IsCoastTile(tile) || !IsSimpleSlope(tile))
        return false;
    if(AIMarine.IsLockTile(tile))
        return true;
    return  AITile.IsWaterTile(GetHillFrontTile(tile, 1)) &&
            AITile.IsBuildable(GetHillBackTile(tile, 1));
}

/* Finds a lock/possible lock tile next to the water tile. */
function CanalPathfinder::_FindAdjacentLockTile(water, direction) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, water, 1);
    tiles.Valuate(_val_IsLockCapable);
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

function CanalPathfinder::FindPath(start, end, max_distance, ignored = []) {
    this.path = [];
    if(start == -1 || end == -1 || start == end || max_distance <= 0)
        return false;
    
    local dist = AIMap.DistanceManhattan(start, end);
    max_distance = min(max_distance, 50); /* TODO: improve performance instead */
    if(dist == -1 || dist > max_distance)
        return false;

    /* We operate on land only, so if any of the points is on water we need to 
     * find adjacent tile capable of hosting a lock */
    if(AITile.IsWaterTile(start) && (AITile.GetMaxHeight(start) == 0)) {
        start = _FindAdjacentLockTile(start, end);
        /* Locks cannot be entered from sides. */
        if(start != -1)
            ignored.extend(_LockGetExitSideTiles(start));
    }
    if(AITile.IsWaterTile(end) && (AITile.GetMaxHeight(end) == 0)) {
        end = _FindAdjacentLockTile(end, start);
        /* Locks cannot be entered from sides. */
        if(end != -1)
            ignored.extend(_LockGetExitSideTiles(end));
    }
    if(start == -1 || end == -1)
        return false;

    this._dest = end;
    this._max_length = max_distance;
    this._aystar.InitializePath([[start, this._GetDominantDirection(start, end)]], [end], ignored);
    local tmp_path = this._aystar.FindPath(10000);
    if(tmp_path == false || tmp_path == null)
        return false;
    while(tmp_path != null) {
        this.path.append(tmp_path.GetTile());
        tmp_path = tmp_path.GetParent();
    }
    this.path.reverse();

    return true;
}

function CanalPathfinder::_Cost(self, path, new_tile, new_direction) {
    if(path == null) return 0;
    
    /* Using existing canal. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsLockTile(new_tile) ||
        AIMarine.IsBuoyTile(new_tile) || 
        (AITile.IsWaterTile(new_tile) && (AITile.GetMaxHeight(new_tile) > 0))) /* river */
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
        if(AITile.GetSlope(tile) != AITile.SLOPE_FLAT)
            continue;
        if((AITile.IsBuildable(tile) || AIMarine.IsCanalTile(tile) ||
            AIMarine.IsLockTile(tile) || AIMarine.IsBuoyTile(tile) || 
            (AITile.IsWaterTile(tile) && (AITile.GetMaxHeight(tile) > 0)))
            && !AIMarine.IsWaterDepotTile(tile))
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

