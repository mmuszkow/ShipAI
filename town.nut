require("dock.nut");

class Town {
    id = -1;
    
    constructor(id) {
        this.id = id;
    }
}

function Town::GetName() {
    return AITown.GetName(this.id);
}

function Town::GetCargoAcceptingCoastTiles(range, cargo) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, AITown.GetLocation(this.id), range);
    tiles.Valuate(AITile.IsCoastTile);
    tiles.KeepValue(1);
    tiles.Valuate(_val_IsDockCapable);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetClosestTown);
    tiles.KeepValue(this.id);
    /* Tile must accept passangers. */
    tiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1,
                  AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    tiles.KeepAboveValue(7); /* as doc says */
    return tiles;
}

function Town::GetBestCargoAcceptingCoastTile(range, cargo) {
    local tiles = GetCargoAcceptingCoastTiles(range, cargo);
    if(tiles.IsEmpty())
        return -1;
    tiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1,
                  AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return tiles.Begin();
}

/* Valuator. */
function _val_TownCanHaveDock(town_id, range, cargo) {
    return !Town(town_id).GetCargoAcceptingCoastTiles(range, cargo).IsEmpty();
}

function Town::GetExistingDock(cargo) {
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    local docks = AIStationList(AIStation.STATION_DOCK);
    docks.Valuate(AIStation.GetNearestTown);
    docks.KeepValue(this.id);    
    for(local dock = docks.Begin(); docks.HasNext(); dock = docks.Next()) {
        local dock_loc = AIStation.GetLocation(dock);
        if(AITile.GetCargoAcceptance(dock_loc, cargo, 1, 1, radius) > 7)
            return Dock(dock_loc);
    }
    return null;
}
