class CoastPathfinder { 
    path = [];
};

class CoastPathfinder.Path {
    source = null;
    goal = null;
    path = null;

    _go_right = null;
    _tile = -1;
    _max_len = 100;
   
    /* go_right is from the front point of view on tile */ 
    constructor(source, goal, go_right, max_path_len) {
        this.source = source;
        this.goal = goal;
        this.path = [source];
        this._tile = source;
        this._go_right = go_right;
        this._max_len = max_path_len;
    }
};

function CoastPathfinder::Path::_GoRight(tile) {
    local next = -1;
    local slope = AITile.SLOPE_INVALID;
    switch(AITile.GetSlope(tile)) {
        case AITile.SLOPE_NW:
        case AITile.SLOPE_STEEP_W:
        case AITile.SLOPE_NWS:
        case AITile.SLOPE_N:
            next = tile + EAST;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_NW ||
               slope == AITile.SLOPE_ENW ||
               slope == AITile.SLOPE_W ||
               slope == AITile.SLOPE_STEEP_N)
                return next;
            return -1;
        case AITile.SLOPE_SE:
        case AITile.SLOPE_STEEP_E:
        case AITile.SLOPE_SEN:
        case AITile.SLOPE_S:
            next = tile + WEST;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_SE ||
               slope == AITile.SLOPE_WSE ||
               slope == AITile.SLOPE_E ||
               slope == AITile.SLOPE_STEEP_S)
                return next;
            return -1;
        case AITile.SLOPE_SW:
        case AITile.SLOPE_STEEP_S:
        case AITile.SLOPE_WSE:
        case AITile.SLOPE_W:
            next = tile + NORTH;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_SW ||
               slope == AITile.SLOPE_NWS ||
               slope == AITile.SLOPE_S ||
               slope == AITile.SLOPE_STEEP_W)
                return next;
            return -1;
        case AITile.SLOPE_NE:
        case AITile.SLOPE_STEEP_N:
        case AITile.SLOPE_ENW:
        case AITile.SLOPE_E:
            next = tile + SOUTH;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_NE ||
               slope == AITile.SLOPE_SEN ||
               slope == AITile.SLOPE_N ||
               slope == AITile.SLOPE_STEEP_E)
                return next;
            return -1;
        default:
            return -1;
    }

    return -1;    
}

function CoastPathfinder::Path::_GoLeft(tile) {
    local next = -1;
    local slope = AITile.SLOPE_INVALID;
    switch(AITile.GetSlope(tile)) {
        case AITile.SLOPE_NW:
        case AITile.SLOPE_W:
        case AITile.SLOPE_ENW:
        case AITile.SLOPE_STEEP_N:
            next = tile + WEST;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_NW ||
               slope == AITile.SLOPE_N ||
               slope == AITile.SLOPE_STEEP_W ||
               slope == AITile.SLOPE_NWS)
                return next;
            return -1;
        case AITile.SLOPE_SE:
        case AITile.SLOPE_E:
        case AITile.SLOPE_WSE:
        case AITile.SLOPE_STEEP_S:
            next = tile + EAST;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_SE ||
               slope == AITile.SLOPE_S ||
               slope == AITile.SLOPE_SEN ||
               slope == AITile.SLOPE_STEEP_E)
                return next;
            return -1;
        case AITile.SLOPE_SW:
        case AITile.SLOPE_S:
        case AITile.SLOPE_STEEP_W:
        case AITile.SLOPE_NWS:
            next = tile + SOUTH;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_SW ||
               slope == AITile.SLOPE_W ||
               slope == AITile.SLOPE_WSE ||
               slope == AITile.SLOPE_STEEP_S)
                return next;
            return -1;
        case AITile.SLOPE_N:
        case AITile.SLOPE_NE:
        case AITile.SLOPE_SEN:
        case AITile.SLOPE_STEEP_E:
            next = tile + NORTH;
            slope = AITile.GetSlope(next);
            if(slope == AITile.SLOPE_NE ||
               slope == AITile.SLOPE_E ||
               slope == AITile.SLOPE_ENW ||
               slope == AITile.SLOPE_STEEP_N)
                return next;
            return -1;
        default:
            return -1;
    }

    return -1;    
}

/* Returns estimated distance to the goal, -1 in case of max_len exceeded
 * or bad tile, 0 if the goal was reached. */
function CoastPathfinder::Path::Estimate() {
    /* We failed before. */
    if(this._tile == -1)
        return -1;

    /* We reached the target. */
    if(this._tile == this.goal)
        return 0;
   
    /* Get the next tile. */
    if(this._go_right)
        this._tile = _GoRight(this._tile);
    else
        this._tile = _GoLeft(this._tile);
    if(this._tile == -1) {
        this.path = [];
        return -1;
    }
 
    /* We looped. */
    if(this._tile == this.source) {
        this._tile = -1;
        this.path = [];
        return -1;
    }
   
    /* We should check if the tile is a coast tile, however...
     * AITile.IsCoastTile doesn't work for bridges, buildings and roads
     * src/script/api/script_tile.cpp:70
	 * return (::IsTileType(tile, MP_WATER) && ::IsCoast(tile)) ||
	 *     (::IsTileType(tile, MP_TREES) && ::GetTreeGround(tile) == TREE_GROUND_SHORE);
     */

    /* This will eliminate the slopes on the map edges (we can't get around those). */
    if(AIMap.DistanceFromEdge(this._tile) <= 1) {
        this._tile = -1;
        this.path = [];
        return -1;
    }

    /* This will eliminate "dry" valleys, where coast tiles are in front eachother.
     * By setting the tile to the tile in front, we should be able to continue going the coast. 
     * In theory, this shouldn't cause a loop.
     */
    local front = GetHillFrontTile(this._tile, 1); // returns -1 for non-simple slopes
    if(front != -1 && AITile.GetSlope(this._tile) == AITile.GetComplementSlope(AITile.GetSlope(front)))
        this._tile = front;
 
    /* Add next and check if path length is within limit. */
    this.path.push(this._tile);
    if(this.path.len() > this._max_len) {
        this._tile = -1;
        this.path = [];
        return -1;
    }

    /* If the estimated distance to goal exceeds the limit,
     * it means we wouldn't be able to make this path anyway. */
    local estimate = AIMap.DistanceManhattan(this._tile, this.goal);
    if(estimate > this._max_len) {
        this._tile = -1;
        this.path = [];
        return -1;
    }

    return estimate;
}

function CoastPathfinder::GetCoastAdjacentToTile(tile, direction) {
    local adjacent = AITileList();
    adjacent.AddRectangle(tile + AIMap.GetTileIndex(-1, -1), tile + AIMap.GetTileIndex(1, 1));
    adjacent.Valuate(AIMap.IsValidTile);
    adjacent.KeepValue(1);
    adjacent.Valuate(AITile.IsCoastTile);
    adjacent.KeepValue(1);
    if(adjacent.IsEmpty())
        return -1;
    adjacent.Valuate(AIMap.DistanceManhattan, direction);
    adjacent.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return adjacent.Begin();
}

function CoastPathfinder::_IsWaterTile(tile) {
    return AITile.IsWaterTile(tile) ||
           AIMarine.IsBuoyTile(tile) ||
           AIMarine.IsDockTile(tile) ||
           AIMarine.IsLockTile(tile) ||
           AIMarine.IsWaterDepotTile(tile);
}

/* We follow coast, but we need to return the water path. */
function CoastPathfinder::GetWaterAdjacentToCoastPath(path) {
    local water_path = [];
    local adj = -1;
    foreach(coast in path) {
        switch(AITile.GetSlope(coast)) {
            case AITile.SLOPE_NW:
                adj = coast + SOUTH;
                break;
            case AITile.SLOPE_SE:
                adj = coast + NORTH;
                break;
            case AITile.SLOPE_NE:
                adj = coast + WEST;
                break;
            case AITile.SLOPE_SW:
                adj = coast + EAST;
                break;
            case AITile.SLOPE_N:
                adj = coast + SOUTH + WEST;
                break;
            case AITile.SLOPE_S:
                adj = coast + NORTH + EAST;
                break;
            case AITile.SLOPE_E:
                adj = coast + NORTH + WEST;
                break;
            case AITile.SLOPE_W:
                adj = coast + SOUTH + EAST;
                break;
            default:
                adj = -1;
        }

        if(adj == -1)
            continue;
        
        /* Don't put the same tile twice. */
        if(water_path.len() > 0 && water_path.top() == adj)
            continue;
           
        if(_IsWaterTile(adj))
            water_path.push(adj);    
    }
    return water_path;
}

/* start and end must be water tiles adjacent to coast. */
function CoastPathfinder::FindPath(start, end, max_path_len) {
    /* Check if arguments are valid. */
    if(!AIMap.IsValidTile(start) || !AIMap.IsValidTile(end)
        || start == end || max_path_len <= 0
        || AIMap.DistanceManhattan(start, end) > max_path_len)
        return false;

    /* This pathfinder operates on coast tiles. */
    local coast1 = GetCoastAdjacentToTile(start, end);
    if(coast1 == -1)
        return false;
    local coast2 = GetCoastAdjacentToTile(end, start);
    if(coast2 == -1)
        return false;

    /* We go both directions simultaneously. */
    local path_r = Path(coast1, coast2, true, max_path_len);
    local path_l = Path(coast1, coast2, false, max_path_len);
    local estimate_r = path_r.Estimate();
    local estimate_l = path_l.Estimate();
    while(estimate_r != -1 || estimate_l != -1) {
        /* We reached the destination. */
        if(estimate_r == 0) {
            this.path = [start];
            this.path.extend(GetWaterAdjacentToCoastPath(path_r.path));
            this.path.push(end);
            return true;
        }
        if(estimate_l == 0) {
            this.path = [start];
            this.path.extend(GetWaterAdjacentToCoastPath(path_l.path));
            this.path.push(end);
            return true;
        }
        
        if(estimate_r != -1 && estimate_l != -1) {
            /* Follow the path that is closer to our destination. */
            if(estimate_r <= estimate_l)
                estimate_r = path_r.Estimate();
            else
                estimate_l = path_l.Estimate();
        } else {
            /* No need to worry about any conditions, as Estimate returns -1 on failed paths. */
            estimate_r = path_r.Estimate();
            estimate_l = path_l.Estimate();
        }
    }

    return false;
}

