
/* If canals are allowed in settings and we have enough money. */
function AreCanalsAllowed() {
    return AIController.GetSetting("build_canals") && 
          (AICompany.GetBankBalance(AICompany.COMPANY_SELF) -
           AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER)
           > 2 * AICompany.GetMaxLoanAmount());
}

/* AITileList.AddRectangle with map size constraints. */
function SafeAddRectangle(list, tile, range_x, range_y = -1) {
    if(range_y == -1)
        range_y = range_x;
    local tile_x = AIMap.GetTileX(tile);
    local tile_y = AIMap.GetTileY(tile);
    local x1 = max(1, tile_x - range_x);
    local y1 = max(1, tile_y - range_y);
    local x2 = min(AIMap.GetMapSizeX() - 2, tile_x + range_x);
    local y2 = min(AIMap.GetMapSizeY() - 2, tile_y + range_y);
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

/* Finds other end for a potential bridge. */
function FindOtherBridgeEnd(edge) {
    /* Follow down the slope. */
    local slope = AITile.GetSlope(edge);
    local dir = -1;
    switch(slope) {
        case AITile.SLOPE_NE:
            dir = WEST;
            break;
        case AITile.SLOPE_NW:
            dir = SOUTH;
            break;
        case AITile.SLOPE_SE:
            dir = NORTH;
            break;
        case AITile.SLOPE_SW:
            dir = EAST;
            break;
        default:
            return -1;
    }
    
    /* Everything on the way must be under the bridge. */
    local height = AITile.GetMaxHeight(edge);
    local complementary = AITile.GetComplementSlope(slope);
    edge += dir;
    local i = 0;
    while(i++ < 10) {
        if(AITile.GetSlope(edge) == complementary)
            return edge;
        if(AITile.GetMaxHeight(edge) == height)
            break;
        edge += dir;
    }
    return -1;
}

