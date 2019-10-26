require("dock.nut");
require("utils.nut");

class Industry {
    id = -1;
    is_producer = false;
    
    constructor(id, is_producer) {
        this.id = id;
        this.is_producer = is_producer;
    }
}

function Industry::GetName() {
    if(this.is_producer)
        return AIIndustry.GetName(this.id) + "(producer)";
    else
        return AIIndustry.GetName(this.id) + "(acceptor)";
}

function Industry::GetNearbyCoastTiles() {
    local tiles;
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    if(this.is_producer)
        tiles = AITileList_IndustryProducing(this.id, radius);
    else
        tiles = AITileList_IndustryAccepting(this.id, radius);
    tiles.Valuate(AITile.IsCoastTile);
    tiles.KeepValue(1);
    tiles.Valuate(_val_IsDockCapable);
    tiles.KeepValue(1);
    return tiles;
}

function Industry::GetNearestCoastTile() {
    local tiles = GetNearbyCoastTiles();
    if(tiles.IsEmpty())
        return -1;
    tiles.Valuate(AIMap.DistanceManhattan, AIIndustry.GetLocation(this.id));
    tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return tiles.Begin();
}

/* Checks if we can build an artificial port on flat ground near the industry,
   orientation - 0 - W, 1 - S, 2 - N, 3 - E 
   returns dock tile, port size is 3x5 or 5x3 depending on it's orientation */
 
function Industry::GetPossiblePortTile(orientation) {   
    /* Get tiles that accept the cargo */
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    local tiles;
    if(this.is_producer)
        tiles = AITileList_IndustryProducing(this.id, radius);
    else
        tiles = AITileList_IndustryAccepting(this.id, radius);
    tiles.Valuate(AITile.IsBuildable);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetSlope);
    tiles.KeepValue(AITile.SLOPE_FLAT);
    if(tiles.IsEmpty())
        return -1;
        
    /* todo: get center */
    local src = AIIndustry.GetLocation(this.id);
    local src_x = AIMap.GetTileX(src);
    local src_y = AIMap.GetTileY(src);
       
    if(orientation == 0 || orientation == 3) {      
        /* Let's keep it simple, dock can be build only in a straight horizontal line from source */
        tiles.Valuate(AIMap.GetTileY);
        tiles.KeepValue(src_y);
        tiles.Valuate(AIMap.GetTileX);
        if(orientation == 0)
            tiles.KeepAboveValue(src_x);
        else
            tiles.KeepBelowValue(src_x);
        tiles.Valuate(AIMap.DistanceManhattan, src);
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
            
        /* It's furter in W-E direction, we need 3x5 flat tiles. */        
        for(local possible = tiles.Begin(); !tiles.IsEnd(); possible = tiles.Next()) {
            local flat = AITileList();
            local top_left;
            if(orientation == 0) {
                /* To the West. */
                top_left = possible + AIMap.GetTileIndex(3, -1);
                local bottom_right = top_left + AIMap.GetTileIndex(-4, 2);
                flat.AddRectangle(top_left, bottom_right);
            } else {
                /* To the East. */
                top_left = possible + AIMap.GetTileIndex(1, -1);
                local bottom_right = top_left + AIMap.GetTileIndex(-4, 2);
                flat.AddRectangle(top_left, bottom_right);
            }
            flat.Valuate(AITile.IsBuildable);
            flat.KeepValue(1);
            flat.Valuate(AITile.GetSlope);
            flat.KeepValue(AITile.SLOPE_FLAT);
            if(flat.Count() == 15)
                return possible;
        }
    } else {       
        /* Let's keep it simple, dock can be build only in a straight vertical line from source. */
        tiles.Valuate(AIMap.GetTileX);
        tiles.KeepValue(src_x);
        tiles.Valuate(AIMap.GetTileY);
        if(orientation == 1)
            tiles.KeepAboveValue(src_y);
        else
            tiles.KeepBelowValue(src_y);
        tiles.Valuate(AIMap.DistanceManhattan, src);
        tiles.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        
        /* It's further in N-S direction, we need 5x3 flat tiles */
        for(local possible = tiles.Begin(); !tiles.IsEnd(); possible = tiles.Next()) {
            local flat = AITileList();
            local top_left;
            if(orientation == 1) {
                /* To the South. */
                top_left = possible + AIMap.GetTileIndex(1, 3);
                local bottom_right = top_left + AIMap.GetTileIndex(-2, -4);
                flat.AddRectangle(top_left, bottom_right);           
            } else {
                /* To the North. */
                top_left = possible + AIMap.GetTileIndex(1, 1);
                local bottom_right = top_left + AIMap.GetTileIndex(-2, -4);
                flat.AddRectangle(top_left, bottom_right);
            }
            flat.Valuate(AITile.IsBuildable);
            flat.KeepValue(1);
            flat.Valuate(AITile.GetSlope);
            flat.KeepValue(AITile.SLOPE_FLAT);
            if(flat.Count() == 15)
                return possible;
        }
    }
    
    return -1;
}

/* Checks all 4 sides of the industry, returns tile-orientation pairs. */
function Industry::GetPossiblePorts() {
    local ports = [];
    for(local orientation = 0; orientation <= 3; orientation++) {
        local port = GetPossiblePortTile(orientation);
        if(port != -1)
            ports.append(Dock(port, orientation));
    }
    return ports;
}

/* Checks all 4 sides of the industry, returns true if any port location is found. */
function Industry::CanHaveLandPort() {
    for(local orientation = 0; orientation <= 3; orientation++)
        if(GetPossiblePortTile(orientation) != -1)
            return true;
    return false;
}

function Industry::CanHaveDock() {
    return   AIIndustry.HasDock(this.id) || 
            !GetNearbyCoastTiles().IsEmpty() ||
            (AreCanalsAllowed() && CanHaveLandPort());
}

/* Valuator. */
function _val_IndustryCanHaveDock(industry, is_producer) {
    return Industry(industry, is_producer).CanHaveDock();
}

function Industry::GetExistingDock() {
    if(AIIndustry.HasDock(this.id))
        return Dock(AIIndustry.GetDockLocation(this.id), -1, true);
    
    local tiles;
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    if(this.is_producer)
        tiles = AITileList_IndustryProducing(this.id, radius);
    else
        tiles = AITileList_IndustryAccepting(this.id, radius);
    tiles.Valuate(AIMarine.IsDockTile);
    tiles.KeepValue(1);
    tiles.Valuate(AITile.GetOwner);
    tiles.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
    tiles.Valuate(IsSimpleSlope);
    tiles.KeepValue(1);
    if(tiles.IsEmpty())
        return null;
    
    return Dock(tiles.Begin());
}

/* Gets monthly production to determine the potential ship size. */
function Industry::GetMonthlyProduction(cargo) {
    return AIIndustry.GetLastMonthProduction(this.id, cargo) - AIIndustry.GetLastMonthTransported(this.id, cargo);
}
