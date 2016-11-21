require("water.nut");
require("hashset.nut");

/* This part sucks, that's why it is disabled. */
class Terraforming {
    /* Minimal money left after buying something. */
    min_balance = 20000;
    
    /* Dock radius. */
    _dock_radius = 1;
    
    constructor() {
        _dock_radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    }
}

/* Gets next tile in specified direction. 
   0 - Up, 3 - Right, 2 - Down, 1 - Left.
   Returns -1 in case tile is over the map limits. */
function _TrfmGetTileInDirection(tile, dir) {
    local x = AIMap.GetTileX(tile);
    local y = AIMap.GetTileY(tile);
    switch(dir) {
        /* Up. */
        case 0:
            if(y <= 1) return -1;
            return AIMap.GetTileIndex(x, y - 1);
        /* Right. */
        case 3:
            if(x >= AIMap.GetMapSizeX()) return -1;
            return AIMap.GetTileIndex(x + 1, y);
        /* Down. */
        case 2:
            if(y >= AIMap.GetMapSizeY()) return -1;
            return AIMap.GetTileIndex(x, y + 1);
        /* Left. */
        case 1:
            if(x <= 1) return -1;
            return AIMap.GetTileIndex(x - 1, y);
    }
}

/* How many tiles are necessary to reach the coast in this direction. */
function NecessaryCanalTiles(tile, dir) {
    local len = 0;
    local tmp = tile;
    while(!AITile.IsCoastTile(tmp)) {
        if(!AITile.IsWaterTile(tmp) && !AITile.IsBuildable(tmp))
            return -1; /* Non terraformable. */
        tmp = _TrfmGetTileInDirection(tmp, dir);
        if(tmp == -1)
            return -1; /* Out of map limits. */
        if(len++ > 30)
            return -1; /* Too far away. */
    }
    return len;
}

function BuildCanal(tile, dir, len) {
    switch(dir) {
        case 0:
            return AITile.LevelTiles(tile + AIMap.GetTileIndex(2, -len), tile);
        case 1:
            return AITile.LevelTiles(tile + AIMap.GetTileIndex(-len, 2), tile);
        case 2:
            return AITile.LevelTiles(tile + AIMap.GetTileIndex(2, len), tile);
        case 3:
            return AITile.LevelTiles(tile + AIMap.GetTileIndex(len, 2), tile);
    }
    return false;
}

/* Let's see how much it will cost. */
function EstimateCanalCost(tile, dir) {
    local necessary = NecessaryCanalTiles(tile, dir);
    if(necessary == -1)
        return 0;
    
    necessary++; /* to get the sea level .*/
    local test = AITestMode();
    local accounter = AIAccounting();
    BuildCanal(tile, dir, necessary);
    return accounter.GetCosts();
}

/* Get the furthest tiles that still accept the cargo. */
function Terraforming::_GetIndustryBoundaryTiles(industry, is_producer, dir) {
    local tiles = null;
    if(is_producer)
        tiles = AITileList_IndustryProducing(industry, this._dock_radius);
    else
        tiles = AITileList_IndustryAccepting(industry, this._dock_radius);   
    if(dir == 0 || dir == 2)
        tiles.Valuate(AIMap.GetTileY);
    else
        tiles.Valuate(AIMap.GetTileX);
    if(dir == 0 || dir == 1)
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    else
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    if(dir == 0 || dir == 2)
        tiles.KeepValue(AIMap.GetTileY(tiles.Begin()));
    else
        tiles.KeepValue(AIMap.GetTileX(tiles.Begin()));
    return tiles;
}

function Terraforming::BuildCanalToIndustry(industry, is_producer) {
    for(local dir = 0; dir < 4; dir++) {
        local tiles = _GetIndustryBoundaryTiles(industry, is_producer, dir);
        tiles.Valuate(NecessaryCanalTiles, dir);
        tiles.RemoveValue(-1);
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        for(local tile = tiles.Begin(); tiles.HasNext(); tile = tiles.Next()) {
            local necessary = NecessaryCanalTiles(tile, dir);
            local accounter = AIAccounting();
            if(BuildCanal(tile, dir, necessary+1)) {
                AISign.BuildSign(tile, "x");
                AILog.Info("Building canal near " + AIIndustry.GetName(industry) + " for " + accounter.GetCosts());
                return true;
            }
        }
    }
    return false;
}

function Terraforming::BuildCanals() {
    if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < this.min_balance)
        return;
    
    local cargos = AICargoList();
    cargos.Valuate(AICargo.IsFreight); 
    cargos.KeepValue(1); /* Only freight cargo. */
    
    /* avoid handling the same industry twice. */
    local handled = HashSet(512);
    
    for(local cargo = cargos.Begin(); cargos.HasNext(); cargo = cargos.Next()) {
        /* Let's find industries with no water access. */
        local acceptors = AIIndustryList_CargoAccepting(cargo);
        acceptors.Valuate(IndustryCanHaveDock, false);
        acceptors.RemoveValue(1);
        local producers = AIIndustryList_CargoProducing(cargo);
        producers.Valuate(IndustryCanHaveDock, true);
        producers.RemoveValue(1);

        /* And build canals leading to them. */
        for(local acceptor = acceptors.Begin(); acceptors.HasNext(); acceptor = acceptors.Next())
            if(!handled.Contains(acceptor)) {
                if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < this.min_balance)
                    return;
                BuildCanalToIndustry(acceptor, false);
                handled.Add(acceptor);
            }
        for(local producer = producers.Begin(); producers.HasNext(); producer = producers.Next())
            if(!handled.Contains(producer)) {
                if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < this.min_balance)
                    return;
                BuildCanalToIndustry(producer, true);
                handled.Add(producer);
            }
    }
}
