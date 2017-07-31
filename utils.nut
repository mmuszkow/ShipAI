/* AITileList.AddRectangle with map size constraints. */
function SafeAddRectangle(list, tile, range) {
    local tile_x = AIMap.GetTileX(tile);
    local tile_y = AIMap.GetTileY(tile);
    local x1 = max(1, tile_x - range);
    local y1 = max(1, tile_y - range);
    local x2 = min(AIMap.GetMapSizeX() - 2, tile_x + range);
    local y2 = min(AIMap.GetMapSizeY() - 2, tile_y + range);
    list.AddRectangle(AIMap.GetTileIndex(x1, y1), AIMap.GetTileIndex(x2, y2)); 
}

/* For determining if we can build dock on such slope. */
function IsSimpleSlope(tile) {
    local slope = AITile.GetSlope(tile);
    return slope == AITile.SLOPE_NW
        || slope == AITile.SLOPE_NE
        || slope == AITile.SLOPE_SE
        || slope == AITile.SLOPE_SW;
}

function GetHillFrontTile(hill, dist) {
    switch(AITile.GetSlope(hill)) {
        case AITile.SLOPE_NE:
            /* West */
            return hill + AIMap.GetTileIndex(dist, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return hill + AIMap.GetTileIndex(0, dist);
        case AITile.SLOPE_SE:
            /* North. */
            return hill + AIMap.GetTileIndex(0, -dist);
        case AITile.SLOPE_SW:
            /* East. */
            return hill + AIMap.GetTileIndex(-dist, 0);
        default:
            return -1;
    }
}

function GetHillBackTile(hill, dist) {
    switch(AITile.GetSlope(hill)) {
        case AITile.SLOPE_NE:
            /* West */
            return hill + AIMap.GetTileIndex(-dist, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return hill + AIMap.GetTileIndex(0, -dist);
        case AITile.SLOPE_SE:
            /* North. */
            return hill + AIMap.GetTileIndex(0, dist);
        case AITile.SLOPE_SW:
            /* East. */
            return hill + AIMap.GetTileIndex(dist, 0);
        default:
            return -1;
    }
}
