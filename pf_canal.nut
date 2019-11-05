require("utils.nut");

class CanalPathfinder {
    _queue_class = import("queue.binary_heap", "", 1);
	_open = null;
	_closed = null;
	_goal = null;    

    _max_length = 100;
    
    path = [];
};

class CanalPathfinder.Path {
	parentt = null; /* parent is a reserved keyword */
	tile = null;
	direction = null;
	cost = null;
	length = null;

	constructor(old_path, new_tile, new_direction) {
		this.parentt = old_path;
		this.tile = new_tile;
		this.direction = new_direction;
		this.cost = _Cost(old_path, new_tile);
		if (old_path == null)
			this.length = 0;
		else
			this.length = old_path.length + AIMap.DistanceManhattan(old_path.tile, new_tile);
	};
};

function _val_IsLockCapableCoast(tile, ignored) {
    if(!AITile.IsCoastTile(tile) || !IsSimpleSlope(tile))
        return false;
    if(AIMarine.IsLockTile(tile))
        return true;
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

function CanalPathfinder::_AystarFindPath(source, goal, ignored_tiles) {
    this._open = this._queue_class();
	this._closed = AIList();

	this._goal = goal;
	local new_path = this.Path(null, source, _GetDominantDirection(source, goal));
	this._open.Insert(new_path, new_path.cost + _Estimate(source));

	foreach (tile in ignored_tiles)
		this._closed.AddItem(tile, ~0);

	while (this._open.Count() > 0) {
		/* Get the path with the best score so far */
		local path = this._open.Pop();
		local cur_tile = path.tile;
		/* Make sure we didn't already passed it */
		if (this._closed.HasItem(cur_tile)) {
			/* If the direction is already on the list, skip this entry */
			if ((this._closed.GetValue(cur_tile) & path.direction) != 0) continue;

			/* Add the new direction */
			this._closed.SetValue(cur_tile, this._closed.GetValue(cur_tile) | path.direction);
		} else {
			/* New entry, make sure we don't check it again */
			this._closed.AddItem(cur_tile, path.direction);
		}
		/* Check if we found the end */
		if (cur_tile == goal) {
			_AystarCleanPath();
			return path;
		}
		/* Scan all neighbours */
		local neighbours = _Neighbours(path, cur_tile);
		foreach (node in neighbours) {
			if (node[1] <= 0) throw("directional value should never be zero or negative.");

			if ((this._closed.GetValue(node[0]) & node[1]) != 0) continue;
			/* Calculate the new paths and add them to the open list */
			local new_path = this.Path(path, node[0], node[1]);
			this._open.Insert(new_path, new_path.cost + _Estimate(node[0]));
		}
	}

	if (this._open.Count() > 0) return false;
	_AystarCleanPath();
	return null;

}

function CanalPathfinder::_AystarCleanPath() {
	this._closed = null;
	this._open = null;
	this._goal = null;
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

    this._max_length = max_distance;
    local tmp_path = _AystarFindPath(start, end, land_ignored);
    if(tmp_path == false || tmp_path == null)
        return false;
    if(lock2 != -1)
        this.path.append(lock2);
    while(tmp_path != null) {
        this.path.append(tmp_path.tile);
        tmp_path = tmp_path.parentt;
    }
    if(lock1 != -1)
        this.path.append(lock1);
    this.path.reverse();
    
    return true;
}

function CanalPathfinder::Path::_Cost(path, new_tile) {
    if(path == null) return 0;
   
    /* Using existing canal. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsBuoyTile(new_tile) || 
        AITile.IsWaterTile(new_tile))
        return path.cost + 1;
    
    /* Creating new canal tile */
    return path.cost + 5;
}

function CanalPathfinder::_Estimate(cur_tile) {
    /* performance comparison, 1024x1024 map, infinite funds:
     * x 1 : 5602 days, 190 paths
     * x 1 : 5490 days, 174 paths
     * x 5 : 3408 days, 198 paths
     * x 5 : 3524 days, 197 paths
     * x 8 : 3276 days, 198 paths
     * x 10: 3184 days, 196 paths 
     * after upgrade:
     * x 5 : 3164 days, 205 paths */
    return AIMap.DistanceManhattan(cur_tile, this._goal) * 5;
}

function CanalPathfinder::_Neighbours(path, cur_node) {
    if(path.length + AIMap.DistanceManhattan(cur_node, this._goal) > this._max_length)
        return [];
    
    local tiles = [];
    local offsets = [
        cur_node + NORTH,
        cur_node + SOUTH,
        cur_node + WEST,
        cur_node + EAST
    ];
    foreach(tile in offsets) {
        if(tile == this._goal || ((AITile.GetSlope(tile) == AITile.SLOPE_FLAT) &&
            (AITile.IsBuildable(tile) || AIMarine.IsCanalTile(tile) ||
             AIMarine.IsBuoyTile(tile) || AITile.IsWaterTile(tile)) && 
            !AIMarine.IsWaterDepotTile(tile)) && !AIMarine.IsLockTile(tile))
            tiles.append([tile, _GetDirection(cur_node, tile)]);
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

