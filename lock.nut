class Lock {
    /* Middle lock tile. */
    tile = -1;

    constructor(hill) {
        this.tile = hill;
    }
}

function Lock::Exists() {
    return AIMarine.IsLockTile(this.tile);
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

/* The lower tile (part of the lock). */
function Lock::GetLowerTile() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return this.tile + AIMap.GetTileIndex(1, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, 1);
        case AITile.SLOPE_SE:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, -1);
        case AITile.SLOPE_SW:
            /* East. */
            return this.tile + AIMap.GetTileIndex(-1, 0);
        default:
            return -1;
    }
}

/* 2 tiles on the sides of the upper tile (lock cannot be entered from sides). */
function Lock::GetUpperSideTiles() {
    local ret = AITileList();
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            break;
        case AITile.SLOPE_NW:
            /* South. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
            break;
        case AITile.SLOPE_SE:
            /* North. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
            break;
        case AITile.SLOPE_SW:
            /* East. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
            break;
        default:
            break;
    }
    return ret;
}

/* 2 tiles on the sides of the lower tile (lock cannot be entered from sides). */
function Lock::GetLowerSideTiles() {
    local ret = AITileList();
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
            break;
        case AITile.SLOPE_NW:
            /* South. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
            break;
        case AITile.SLOPE_SE:
            /* North. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
            break;
        case AITile.SLOPE_SW:
            /* East. */
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
            ret.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            break;
        default:
            break;
    }
    return ret;
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

/* First non-lock tile on the lower side. */
function Lock::GetLowerWaterTile() {
    switch(AITile.GetSlope(this.tile)) {
        case AITile.SLOPE_NE:
            /* West */
            return this.tile + AIMap.GetTileIndex(2, 0);
        case AITile.SLOPE_NW:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, 2);
        case AITile.SLOPE_SE:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, -2);
        case AITile.SLOPE_SW:
            /* East. */
            return this.tile + AIMap.GetTileIndex(-2, 0);
        default:
            return -1;
    }
}

