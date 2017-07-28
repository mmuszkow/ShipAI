/* Draws straight line and checks if all tiles are water tiles. */
class StraightLinePathfinder {
    
    /* Point where pathfinder reached an obstacle. */
    fail_point = -1;
    
    path = [];
    
    constructor() {}
}

function StraightLinePathfinder::_IsWater(tile) {
    return (AITile.IsWaterTile(tile) && AITile.GetMaxHeight(tile) == 0) || /* eliminates rivers */
            AIMarine.IsBuoyTile(tile) ||
            AIMarine.IsDockTile(tile) ||
            AIMarine.IsLockTile(tile) ||
            AIMarine.IsWaterDepotTile(tile);
}

/* Bresenham algorithm. */
function StraightLinePathfinder::FindPath(start, end, max_path_len) {
    this.path = [];
    this.fail_point = -1;
    if(start == -1 || end == -1 || start == end || max_path_len <= 0)
        return false;
    
    local x0 = AIMap.GetTileX(start), y0 = AIMap.GetTileY(start);
    local x1 = AIMap.GetTileX(end), y1 = AIMap.GetTileY(end);
    local dx = abs(x1 - x0), dy = abs(y1 - y0);
    local sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    local err = (dx > dy ? dx : -dy)/2, e2;
    
    local len = 0;
    while(true) {
        local tile = AIMap.GetTileIndex(x0, y0);
        //AISign.BuildSign(tile, "x");
        path.push(tile);
        if(tile == end)
            return true;
        if(tile != start && !_IsWater(tile)) {
            this.fail_point = tile;
            return false;
        }
        if(len++ > max_path_len)
            return false;
        e2 = err;
        if(e2 >-dx) { err -= dy; x0 += sx; }
        if(e2 < dy) { err += dx; y0 += sy; }
    }
    return false;
}
