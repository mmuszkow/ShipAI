class Lock {
    /* Middle lock tile. */
    tile = -1;

    constructor(hill) {
        this.tile = hill;
    }
}

/* The upper tile (part of the lock). */
function Lock::GetUpperTile() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return this.tile + AIMap.GetTileIndex(-1, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, -1);
        case AITile.SLOPE_SE:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, 1);
        case AITile.SLOPE_SW:
            /* East. */
            return this.tile + AIMap.GetTileIndex(1, 0);
        default:
            return -1;
    }
}

/* 2 tiles on the sides of the upper tile (lock cannot be entered from sides). */
function Lock::GetUpperSideTiles() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return [this.tile + AIMap.GetTileIndex(-1, -1), this.tile + AIMap.GetTileIndex(-1, 1)];
        case AITile.SLOPE_NW:
            /* South. */
            return [this.tile + AIMap.GetTileIndex(-1, -1), this.tile + AIMap.GetTileIndex(1, -1)];
        case AITile.SLOPE_SE:
            /* North. */
            return [this.tile + AIMap.GetTileIndex(-1, 1), this.tile + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_SW:
            /* East. */
            return [this.tile + AIMap.GetTileIndex(1, -1), this.tile + AIMap.GetTileIndex(1, 1)];
        default:
            return [];
    }
}

/* 2 tiles on the sides of the lower tile (lock cannot be entered from sides). */
function Lock::GetLowerSideTiles() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return [this.tile + AIMap.GetTileIndex(1, -1), this.tile + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_NW:
            /* South. */
            return [this.tile + AIMap.GetTileIndex(-1, 1), this.tile + AIMap.GetTileIndex(1, 1)];
        case AITile.SLOPE_SE:
            /* North. */
            return [this.tile + AIMap.GetTileIndex(-1, -1), this.tile + AIMap.GetTileIndex(1, -1)];
        case AITile.SLOPE_SW:
            /* East. */
            return [this.tile + AIMap.GetTileIndex(-1, -1), this.tile + AIMap.GetTileIndex(-1, 1)];
        default:
            return [];
    }
}

/* First non-lock tile on the upper side. */
function Lock::GetUpperWaterTile() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return this.tile + AIMap.GetTileIndex(-2, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, -2);
        case AITile.SLOPE_SE:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, 2);
        case AITile.SLOPE_SW:
            /* East. */
            return this.tile + AIMap.GetTileIndex(2, 0);
        default:
            return -1;
    }
}

