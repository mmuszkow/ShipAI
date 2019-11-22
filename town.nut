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

function Town::GetCargoAcceptingBuildableCoastTiles(range, cargo) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, AITown.GetLocation(this.id), range);
    /* AITile.IsCoastTile returns only buildable tiles. */
    tiles.Valuate(AITile.IsCoastTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetClosestTown);
    tiles.KeepValue(this.id);
    tiles.Valuate(_val_IsDockCapable);
    tiles.KeepValue(1);
    /* Tile must accept cargo. */
    tiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1,
                  AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    tiles.KeepAboveValue(7); /* as doc says */
    return tiles;
}

function Town::GetBestCargoAcceptingBuildableCoastTile(range, cargo) {
    local tiles = GetCargoAcceptingBuildableCoastTiles(range, cargo);
    if(tiles.IsEmpty())
        return -1;
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return tiles.Begin();
}

/* Valuator. */
function _val_TownCanHaveOrHasDock(town_id, range, cargo) {
    local town = Town(town_id);
    return town.GetExistingDock(cargo) != null || 
          !town.GetCargoAcceptingBuildableCoastTiles(range, cargo).IsEmpty();
}

/* Returns existing dock with biggest cargo acceptance. */
function Town::GetExistingDock(cargo) {
    /* We need to get each station tile, as there is no function
     * to determine if station is accepting a specific cargo.
     * AIStation.HasCargoRating is not enough, as it is true
     * only if the specific cargo was taken from the station
     * at least once. Also, Dock class takes tile, not ID as 
     * the argument in constructor. */
    local stations = AIStationList(AIStation.STATION_DOCK);
    local docks = AITileList();
    stations.Valuate(AIStation.GetNearestTown);
    stations.KeepValue(this.id);
    for(local station_id = stations.Begin(); !stations.IsEnd(); station_id = stations.Next())
        docks.AddTile(AIStation.GetLocation(station_id));

    /* Sort by acceptance. */
    docks.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
    docks.KeepAboveValue(7); /* as doc says */
    if(docks.IsEmpty())
        return null;
    docks.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return Dock(docks.Begin());
}

function Town::GetMonthlyProduction(cargo) {
    return (((100 - AITown.GetLastMonthTransportedPercentage(this.id, cargo))/100.0) * AITown.GetLastMonthProduction(this.id, cargo)).tointeger();
}

function Town::GetInfluencedArea() {
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

