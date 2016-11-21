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
        /* Up. */
        case 0:
            if(y <= 1) return -1;
            return AIMap.GetTileIndex(x, y - 1);
        /* Right. */
        case 1:
            if(x >= AIMap.GetMapSizeX()) return -1;
            return AIMap.GetTileIndex(x + 1, y);
        /* Down. */
        case 2:
            if(y >= AIMap.GetMapSizeY()) return -1;
            return AIMap.GetTileIndex(x, y + 1);
        /* Left. */
        case 3:
            if(x <= 1) return -1;
            return AIMap.GetTileIndex(x - 1, y);
    }
}

/* It's not 100% accurate but finds most of the coast rivers. */
function CoastPathfinder::_IsRiverTile(water) {
    local x = AIMap.GetTileX(water);
    local y = AIMap.GetTileY(water);
    return (!AITile.IsWaterTile(AIMap.GetTileIndex(x - 1, y)) && !AITile.IsWaterTile(AIMap.GetTileIndex(x + 1, y))) ||
            (!AITile.IsWaterTile(AIMap.GetTileIndex(x, y - 1)) && !AITile.IsWaterTile(AIMap.GetTileIndex(x, y + 1)));
}

/* Checks if we are next to coast. */
function CoastPathfinder::_IsWaterNextToNonWater(water) {
    if(!(
        AITile.IsWaterTile(water) ||
        AIMarine.IsDockTile(water) ||
        AIMarine.IsBuoyTile(water) ||
        AIMarine.IsWaterDepotTile(water)) || _IsRiverTile(water))
        return false;
    
    local tiles = AITileList();
    SafeAddRectangle(tiles, water, 1);
    tiles.Valuate(AITile.IsWaterTile);
    tiles.RemoveValue(1);
    return tiles.Count() > 0;
}

/* Changes direction, options is a possible directions list. */
function CoastPathfinder::_Turn(options) {
    this.next = _GetNextTile(this.tile, options[0]);
    if(_IsWaterNextToNonWater(this.next))
        this.direction = options[0];
    else {
        this.next = _GetNextTile(this.tile, options[1]);
        if(_IsWaterNextToNonWater(this.next))
            this.direction = options[1];
        else
            return false;
    }
    return true;
}

/* Gets the water tile in front of the dock. */
function CoastPathfinder::_GetWaterTile(coast) {
    local x = AIMap.GetTileX(coast);
    local y = AIMap.GetTileY(coast);
    if(_IsWaterNextToNonWater(AIMap.GetTileIndex(x, y - 1)))
        return AIMap.GetTileIndex(x, y - 1);
    if(_IsWaterNextToNonWater(AIMap.GetTileIndex(x, y + 1)))
        return AIMap.GetTileIndex(x, y + 1);
    if(_IsWaterNextToNonWater(AIMap.GetTileIndex(x - 1, y)))
        return AIMap.GetTileIndex(x - 1, y);
    if(_IsWaterNextToNonWater(AIMap.GetTileIndex(x + 1, y )))
        return AIMap.GetTileIndex(x + 1, y);
    return -1;
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

function CoastPathfinder::FindPath(coast1, coast2, max_distance) {
    if(coast1 == coast2)
        return true;
    
    if(coast1 == -1 || coast2 == -1)
        return false;
    
    local water1 = _GetWaterTile(coast1);
    local water2 = _GetWaterTile(coast2);
    
    /* Let's start with going forward. */
    local forward = 3;
    switch(AITile.GetSlope(coast1)) {
        case AITile.SLOPE_NW:
            forward = 2; break;
        case AITile.SLOPE_NE:
            forward = 1; break;
        case AITile.SLOPE_SE:
            forward = 0; break;
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
        this.tile = water1;
        this.next = -1;
        this.direction = turns[iter][forward][0];
        
        local loop_det = CircularBuffer();
    
        _path[iter].push(this.tile);
        while(true) {
            /* If next tile is water - follow, otherwise turn right or left. */    
            next = _GetNextTile(this.tile, this.direction);
            if(!_IsWaterNextToNonWater(this.next) && !_Turn(turns[iter][this.direction])) break;
            len[iter]++;
            this.tile = this.next;
            _path[iter].push(this.tile);
            //if(iter == 0)
                //AISign.BuildSign(this.tile, "R");
            //else
                //AISign.BuildSign(this.tile, "L");
            
            /* Short loop detection. */
            if(loop_det.contains(this.tile))
                break;
            loop_det.add(this.tile);
            
            /* We looped. */
            if(this.tile == water1)
                break;
        
            /* We reached second dock. */
            if(this.tile == water2) {
                succ[iter] = true;
                break;
            }
        
            /* Max distance exceeded or better result achieved already. */
            if(len[iter] > max_distance || (iter == 1 && succ[0] && len[1] > len[0]))
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
