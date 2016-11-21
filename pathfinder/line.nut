/* Draws straight line and checks if all tiles are water tiles. */
class StraightLinePathfinder {
    
    /* If the docks are too close to eachother, we have very little profit. */
    min_length = 30;
    /* Point where pathfinder reached an obstacle. */
    fail_point = -1;
    
    path = [];
    
    constructor() {}
}

function StraightLinePathfinder::_IsWater(tile) {
    return AITile.IsWaterTile(tile) ||
        AIMarine.IsDockTile(tile) ||
        AIMarine.IsBuoyTile(tile) ||
        AIMarine.IsWaterDepotTile(tile);
}

/* Bresenham algorithm. */
function StraightLinePathfinder::FindPath(coast1, coast2, max_distance) {
    local x0 = AIMap.GetTileX(coast1), y0 = AIMap.GetTileY(coast1);
    local x1 = AIMap.GetTileX(coast2), y1 = AIMap.GetTileY(coast2);
    local dx = abs(x1 - x0), dy = abs(y1 - y0);
    local sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    local err = (dx > dy ? dx : -dy)/2, e2;
    
    this.path = [];
    this.fail_point = -1;
    local len = 0;
    while(true) {
        local tile = AIMap.GetTileIndex(x0, y0);
        //AISign.BuildSign(tile, "x");
        path.push(tile);
        if(tile == coast2)
            return (len > this.min_length);
        if(tile != coast1 && !_IsWater(tile)) {
            this.fail_point = tile;
            return false;
        }
        if(x0 == x1 && y0 == y1)
            return false;
        if(len++ > max_distance)
            return false;
        e2 = err;
        if(e2 >-dx) { err -= dy; x0 += sx; }
        if(e2 < dy) { err += dx; y0 += sy; }
    }
    return false;
}
