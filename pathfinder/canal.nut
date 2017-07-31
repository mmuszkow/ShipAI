require("../global.nut");
require("../utils.nut")

class CanalPathfinder {
    _aystar_class = null;
    _aystar = null;
    _dest = -1;
    _max_length = 100;
    
    constructor() {
        _aystar_class = import("graph.aystar", "", 6);
        _aystar = _aystar_class(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    }
}

function CanalPathfinder::FindPath(start, end, max_distance, ignored = []) {
    if(start == -1 || end == -1 || start == end || max_distance <= 0)
        return [];
    
    local dist = AIMap.DistanceManhattan(start, end);
    if(dist == -1 || dist > max_distance)
        return [];

    this._dest = end;
    this._max_length = max_distance;
    this._aystar.InitializePath([[start, this._GetDominantDirection(start, end)]], [end], ignored);
    local path = this._aystar.FindPath(10000);
    if(path == false || path == null)
        return [];
    local ret = [];
    while(path != null) {
        ret.append(path.GetTile());
        path = path.GetParent();
    }
    ret.reverse();
    return ret;
}

function _IsRiverTile(tile) {
    /* slope is flat */
    return AITile.IsWaterTile(tile) && (AITile.GetMaxHeight(tile) > 0);
}

function CanalPathfinder::_Cost(self, path, new_tile, new_direction) {
    if(path == null) return 0;
    
    /* Using existing canal. */
    if( AIMarine.IsCanalTile(new_tile) || 
        AIMarine.IsLockTile(new_tile) ||
        AIMarine.IsBuoyTile(new_tile) || 
        _IsRiverTile(new_tile))
        return path.GetCost() + 1;
    
    /* Creating new canal tile */
     return path.GetCost() + 5;
}

function CanalPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
    return AIMap.DistanceManhattan(cur_tile, self._dest);
}

function CanalPathfinder::_Neighbours(self, path, cur_node) {
    if(path.GetLength() + AIMap.DistanceManhattan(cur_node, self._dest) > self._max_length)
        return [];
    
    local tiles = [];
    local offsets = [
        cur_node + NORTH,
        cur_node + SOUTH,
        cur_node + WEST,
        cur_node + EAST
    ];
    foreach(tile in offsets)
        if((AITile.GetSlope(tile) == AITile.SLOPE_FLAT) && 
            (AITile.IsBuildable(tile) || AIMarine.IsCanalTile(tile) || AIMarine.IsLockTile(tile) || AIMarine.IsBuoyTile(tile) || _IsRiverTile(tile)) &&
            !AIMarine.IsWaterDepotTile(tile))
            tiles.append([tile, self._GetDirection(cur_node, tile)]);

    return tiles;
}

function CanalPathfinder::_CheckDirection(self, tile, existing_direction, new_direction) {
    return false;
}

function CanalPathfinder::_GetDominantDirection(from, to) {
	local xDistance = AIMap.GetTileX(from) - AIMap.GetTileX(to);
	local yDistance = AIMap.GetTileY(from) - AIMap.GetTileY(to);
	if (abs(xDistance) >= abs(yDistance)) {
		if (xDistance < 0) return 2;					// Left
		if (xDistance > 0) return 1;					// Right
	} else {
		if (yDistance < 0) return 8;					// Down
		if (yDistance > 0) return 4;					// Up
	}
}

function CanalPathfinder::_GetDirection(from, to) {
	if (from - to >= AIMap.GetMapSizeX()) return 4;		// Up
	if (from - to > 0) return 1;						// Right
	if (from - to <= -AIMap.GetMapSizeX()) return 8;	// Down
	if (from - to < 0) return 2;						// Left
}
