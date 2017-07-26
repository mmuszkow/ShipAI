/* Greedy path search, much faster than A* */
/* TODO: caching */
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
            return tile + AIMap.GetTileIndex(0, -1);
        /* West. */
        case 1:
            if(x >= AIMap.GetMapSizeX()) return -1;
            return tile + AIMap.GetTileIndex(1, 0);
        /* South. */
        case 2:
            if(y >= AIMap.GetMapSizeY()) return -1;
            return tile + AIMap.GetTileIndex(0, 1);
        /* East. */
        case 3:
            if(x <= 1) return -1;
            return tile + AIMap.GetTileIndex(-1, 0);
    }
    return -1;
}

function CoastPathfinder::_IsCoastTile(tile) {
    return AITile.IsCoastTile(tile) || AIMarine.IsDockTile(tile);
}

function _val_IsWaterTile(tile, include_docks = false) {
    return  (AITile.IsWaterTile(tile) && AITile.GetMaxHeight(tile) == 0) || /* exclude rivers */
            (include_docks && AIMarine.IsDockTile(tile)) ||
            AIMarine.IsBuoyTile(tile) ||
            (AIMarine.IsLockTile(tile) && AITile.GetMaxHeight(tile) == 0) ||
            AIMarine.IsWaterDepotTile(tile);
}

/* Checks if we are next to coast. */
function CoastPathfinder::_IsWaterNextToCoast(water) {
    if(!_val_IsWaterTile(water))
        return false;
    
    local tiles = AITileList();
    SafeAddRectangle(tiles, water, 1);
    tiles.Valuate(_val_IsWaterTile, false);
    tiles.RemoveValue(1);
    return tiles.Count() > 0;
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

function CoastPathfinder::FindPath(coast1, coast2, max_path_len) {
    if(coast1 == -1 || coast2 == -1 || coast1 == coast2 || max_path_len <= 0)
        return false;
    
    if(!_IsCoastTile(coast1) || !_IsCoastTile(coast2))
        return false;
    
    /* In case of fail_point use, coast1 tile may be the other dock tile, not the one on the coast. */
    if(AIMarine.IsDockTile(coast1) && AITile.GetSlope(coast1) == AITile.SLOPE_FLAT) {
        if(AIMarine.IsDockTile(coast1 + AIMap.GetTileIndex(1, 0)))
            coast1 = coast1 + AIMap.GetTileIndex(1, 0);
        else if(AIMarine.IsDockTile(coast1 + AIMap.GetTileIndex(0, 1)))
            coast1 = coast1 + AIMap.GetTileIndex(0, 1);
        else if(AIMarine.IsDockTile(coast1 + AIMap.GetTileIndex(-1, 0)))
            coast1 = coast1 + AIMap.GetTileIndex(-1, 0);
        else if(AIMarine.IsDockTile(coast1 + AIMap.GetTileIndex(0, -1)))
            coast1 = coast1 + AIMap.GetTileIndex(0, -1);
    }
    local start = -1;        
    local forward = 0;
    switch(AITile.GetSlope(coast1)) {
        /* West. */
        case AITile.SLOPE_E:
        case AITile.SLOPE_NE:
            start = coast1 + AIMap.GetTileIndex(1, 0);
            forward = 2;
            break;
        /* South. */
        case AITile.SLOPE_N:
        case AITile.SLOPE_NW:
            start = coast1 + AIMap.GetTileIndex(0, 1);
            forward = 2;
            break;
        /* North. */
        case AITile.SLOPE_S:
        case AITile.SLOPE_SE:
            start = coast1 + AIMap.GetTileIndex(0, -1);
            forward = 0;
            break;
        /* East. */
        case AITile.SLOPE_W:
        case AITile.SLOPE_SW:
            start = coast1 + AIMap.GetTileIndex(-1, 0);
            forward = 3;
            break;
        case AITile.SLOPE_NWS:
            start = coast1 + AIMap.GetTileIndex(-1, 1);
            break;
        case AITile.SLOPE_ENW:
            start = coast1 + AIMap.GetTileIndex(1, 1);
            break;
        case AITile.SLOPE_WSE:
            start = coast1 + AIMap.GetTileIndex(-1, -1);
            break;
        case AITile.SLOPE_SEN:
            start = coast1 + AIMap.GetTileIndex(1, -1);
            break;
    }
    
    if(start == -1) {
        AISign.BuildSign(coast1, "wrong dir: " + AITile.GetSlope(coast1));
        return false;
    }
  
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
            local dist = AIMap.DistanceManhattan(this.next, coast2);
            if(dist != -1 && dist <= 2) { /* wtf, DistanceManhattan returns -1 sometimes */
                succ[iter] = true;
                //AILog.Info("succ:" + this.next + "," + coast2 + "," + AIMap.DistanceManhattan(this.next, coast2));
                break;
            }
            
            /* Nowhere to go. */
            if(!_IsWaterNextToCoast(this.next) && !_Turn(turns[iter][this.direction]))
                break;
            
            len[iter]++;
            this.tile = this.next;
            _path[iter].push(this.tile);
            //AISign.BuildSign(this.tile, "" + iter);
        
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
