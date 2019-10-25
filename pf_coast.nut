require("utils.nut");

/* Greedy path search, much faster than A* */
class CoastPathfinder {   
    tile = -1;
    next = -1;
    direction = 0;
    path = [];
    
    constructor() {}
}

/* Gets next tile in specified direction. */
function CoastPathfinder::_GetNextTile(tile, dir) {
    local x = AIMap.GetTileX(tile);
    local y = AIMap.GetTileY(tile);
    switch(dir) {
        /* North. */
        case 0:
            if(y <= 1) return -1;
            return tile + NORTH;
        /* West. */
        case 1:
            if(x >= AIMap.GetMapSizeX()) return -1;
            return tile + WEST;
        /* South. */
        case 2:
            if(y >= AIMap.GetMapSizeY()) return -1;
            return tile + SOUTH;
        /* East. */
        case 3:
            if(x <= 1) return -1;
            return tile + EAST;
    }
    return -1;
}

function CoastPathfinder::_IsWaterTile(tile) {
    return  (AITile.IsWaterTile(tile) && AITile.GetMaxHeight(tile) == 0) || /* exclude rivers */
            AIMarine.IsBuoyTile(tile) ||
            AIMarine.IsDockTile(tile) ||
            (AIMarine.IsLockTile(tile) && (AITile.GetMaxHeight(tile) == 0)) ||
            AIMarine.IsWaterDepotTile(tile);
}

/* Checks if we are next to coast. */
function CoastPathfinder::_IsWaterNextToCoast(water) {
    return (_IsWaterTile(water) && (
        !_IsWaterTile(water + NORTH) || 
        !_IsWaterTile(water + SOUTH) || 
        !_IsWaterTile(water + EAST) || 
        !_IsWaterTile(water + WEST) || 
        !_IsWaterTile(water + AIMap.GetTileIndex(-1, 1)) || 
        !_IsWaterTile(water + AIMap.GetTileIndex(1, 1)) || 
        !_IsWaterTile(water + AIMap.GetTileIndex(-1, -1)) || 
        !_IsWaterTile(water + AIMap.GetTileIndex(1, -1))
    ));
}

/* Changes direction, options is a possible directions list. */
function CoastPathfinder::_Turn(options) {
    this.next = _GetNextTile(this.tile, options[0]);
    if(_IsWaterNextToCoast(this.next))
        this.direction = options[0];
    else {
        this.next = _GetNextTile(this.tile, options[1]);
        if(_IsWaterNextToCoast(this.next))
            this.direction = options[1];
        else
            return false;
    }
    return true;
}

/* Fixed-size circular buffer. */
class CircularBuffer {
    
    data = [-1, -1, -1, -1];
    index = 0;
    
    constructor() {}
}

function CircularBuffer::contains(tile) {
    return this.data[0] == tile
        || this.data[1] == tile
        || this.data[2] == tile
        || this.data[3] == tile;
}

function CircularBuffer::add(tile) {
    this.data[this.index] = tile;
    this.index++;
    if(this.index > 3)
        this.index = 0;
}

/* Start and end tiles should be adjacent to coast. */
function CoastPathfinder::FindPath(start, end, max_path_len) {
    if(start == -1 || end == -1 || start == end || max_path_len <= 0)
        return false;
   
    /* Get coast tile for start water tile. */
    local adjacent = AITileList();
    SafeAddRectangle(adjacent, start, 1);
    adjacent.Valuate(AITile.GetSlope);
    adjacent.RemoveValue(AITile.SLOPE_FLAT);;
    adjacent.Valuate(AIMap.DistanceManhattan, start);
    adjacent.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    if(adjacent.IsEmpty())
        return false;
    local coast = adjacent.Begin();
 
    local forward = 0;
    switch(AITile.GetSlope(coast)) {
        /* West. */
        case AITile.SLOPE_E:
        case AITile.SLOPE_NE:
            start = coast + WEST;
            forward = 1;
            break;
        /* South. */
        case AITile.SLOPE_N:
        case AITile.SLOPE_NW:
            start = coast + SOUTH;
            forward = 2;
            break;
        /* North. */
        case AITile.SLOPE_S:
        case AITile.SLOPE_SE:
            start = coast + NORTH;
            forward = 0;
            break;
        /* East. */
        case AITile.SLOPE_W:
        case AITile.SLOPE_SW:
            start = coast + EAST;
            forward = 3;
            break;
        case AITile.SLOPE_NWS:
            start = coast + AIMap.GetTileIndex(-1, 1);
            break;
        case AITile.SLOPE_ENW:
            start = coast + AIMap.GetTileIndex(1, 1);
            break;
        case AITile.SLOPE_WSE:
            start = coast + AIMap.GetTileIndex(-1, -1);
            break;
        case AITile.SLOPE_SEN:
            start = coast + AIMap.GetTileIndex(1, -1);
            break;
    }
    
    local initial_dist = AIMap.DistanceManhattan(start, end);
  
    /* First iteration we turn right, second left. */
    local turns = [
        [[1, 3], [2, 0], [3, 1], [0, 2]],
        [[3, 1], [0, 2], [1, 3], [2, 0]]
    ];
    
    /* Both paths can succeed, in such case we choose the shorter one. */
    local len = [0, 0];    
    local _path = [[], []];
    local succ = [false, false];
    
    for(local iter = 0; iter <= 1; iter++) {
        /* Current moving tiles position, direction and path length. */
        this.tile = start;
        this.next = -1;
        this.direction = turns[iter][forward][0];
        
        local loop_det = CircularBuffer();
    
        _path[iter].push(this.tile);
        while(true) {
            /* If next tile is water - follow, otherwise turn right or left. */    
            this.next = _GetNextTile(this.tile, this.direction);
            if(this.next == -1)
                break;
            
            /* Short loop detection. */
            if(loop_det.contains(this.next))
                break;
            
            loop_det.add(this.next);
            
            /* We looped. */
            if(this.next == start)
                break;
            
            /* We reached second dock. */
            local dist = AIMap.DistanceManhattan(this.next, end);
            
            /* This means we would need to get back 100 tiles to reach the destination. */
            if(dist > initial_dist + 100)
                break;
            
            if(dist != -1 && dist == 0) { /* wtf, DistanceManhattan returns -1 sometimes */
                succ[iter] = true;
                break;
            }
            
            /* Nowhere to go. */
            if(!_IsWaterNextToCoast(this.next) && !_Turn(turns[iter][this.direction]))
                break;
            
            len[iter]++;
            this.tile = this.next;
            _path[iter].push(this.tile);
        
            /* Max distance exceeded or better result achieved already. */
            if(len[iter] > max_path_len || (iter == 1 && succ[0] && len[1] > len[0]))
                break;
        }
    }
    
    if(succ[0] && succ[1]) {
        if(len[1] < len[0])
            this.path = _path[1];
        else
            this.path = _path[0];
        return true;
    } else if(succ[0]) {
        this.path = _path[0];
        return true;
    } else if(succ[1]) {
        this.path = _path[1];
        return true;
    }
    
    return false;
}
