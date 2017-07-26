class Lock {
    front = -1;
    tile = -1;
    back = -1;
    
    constructor(coast) {
        
    }
}

function CanHaveLock(tile) {
    if(AIMarine.IsLockTile(tile))
        return true;
    if(!AITile.IsBuildable(tile))
        return false;
    
    local back = GetHillBackTile(tile, 1);
    if(back == -1)
        return false;
    local front = GetHillFrontTile(tile, 1);
    if(front == -1)
        return false;
    
    return  (AITile.GetSlope(back) == AITile.SLOPE_FLAT) &&
             AITile.IsBuildable(back) &&
            (AITile.GetSlope(front) == AITile.SLOPE_FLAT);
}

function _val_IsLockCapable(tile) {
    if(AIMarine.IsLockTile(tile))
        return true;
    if(!AITile.IsCoastTile(tile) || !IsSimpleSlope(tile))
        return false;
    return  AITile.IsWaterTile(GetHillFrontTile(tile, 1)) &&
            AITile.IsBuildable(GetHillBackTile(tile, 1));
}
