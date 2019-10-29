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
    for(local dock = docks.Begin(); !docks.IsEnd(); dock = docks.Next()) {
        local dock_loc = AIStation.GetLocation(dock);
        if(AITile.GetCargoAcceptance(dock_loc, cargo, 1, 1, radius) > 7)
            return Dock(dock_loc);
    }
    return null;
}

function Town::GetMonthlyProduction(cargo) {
    return (((100 - AITown.GetLastMonthTransportedPercentage(this.id, cargo))/100.0) * AITown.GetLastMonthProduction(this.id, cargo)).tointeger();
}

function Town::GetArea() {
    local center = AITown.GetLocation(this.id);

    /* Determine borders. */
    local area_w = 5;
    while( AITile.IsWithinTownInfluence(center + area_w, this.id)
        || AITile.IsWithinTownInfluence(center - area_w, this.id))
        area_w += 5;
    local area_h = 5;
    while( AITile.IsWithinTownInfluence(center + area_h, this.id)
        || AITile.IsWithinTownInfluence(center - area_h, this.id))
        area_h += 5;

    /* Return tiles list. */
    local area = AITileList();
    SafeAddRectangle(area, center, area_w, area_h);
    area.Valuate(AITile.IsWithinTownInfluence, this.id);
    area.KeepValue(1);
    return area;
}

