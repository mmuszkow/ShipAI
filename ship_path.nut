class ShipPath {
    dock1 = null;
    dock2 = null;
    
    canal1 = [];
    open_water = [];
    canal2 = [];
    
    buoy_distance = 25;
    
    constructor(dock1, dock2, canal1 = [], open_water = [], canal2 = []) {
        this.dock1 = dock1;
        this.dock2 = dock2;
        this.canal1 = canal1;
        this.open_water = open_water;
        this.canal2 = canal2;
    }
}

function ShipPath::IsValid() {
    return (this.canal1.len() > 0) || (this.open_water.len() > 0) || (this.canal2.len() > 0);
}

function ShipPath::Length() {
    return (this.canal1.len() + this.open_water.len() + this.canal2.len());
}

function ShipPath::BuildCanals() {
    foreach(tile in this.canal1) {
        if(!AITile.IsWaterTile(tile) && !AIMarine.IsCanalTile(tile) && !AIMarine.IsBuoyTile(tile)  && !AIMarine.IsLockTile(tile)) {
            if(IsSimpleSlope(tile)) {
                if(!AIMarine.BuildLock(tile)) {
                    /*foreach(tile_err in this.canal1)
                        if(tile_err != tile)
                            AISign.BuildSign(tile_err, "x");*/
                    AISign.BuildSign(tile, "lock failed");
                    return false;
                }
            } else {
                if(!AIMarine.BuildCanal(tile)) {
                    foreach(tile_err in this.canal1)
                        if(tile_err != tile)
                            AISign.BuildSign(tile_err, "x");
                    AISign.BuildSign(tile, "canal failed");
                    return false;
                }
            }
        }
    }
    foreach(tile in this.canal2) {
        if(!AITile.IsWaterTile(tile) && !AIMarine.IsCanalTile(tile) && !AIMarine.IsBuoyTile(tile) && !AIMarine.IsLockTile(tile)) {
            if(IsSimpleSlope(tile)){
                if(!AIMarine.BuildLock(tile)) {
                    /*foreach(tile_err in this.canal2)
                        if(tile_err != tile)
                            AISign.BuildSign(tile_err, "x");*/
                    AISign.BuildSign(tile, "lock failed");
                    return false;
                }
            } else{
                if(!AIMarine.BuildCanal(tile)) {
                    foreach(tile_err in this.canal2)
                        if(tile_err != tile)
                            AISign.BuildSign(tile_err, "x");
                    AISign.BuildSign(tile, "canal failed");
                    return false;
                }
            }
        }
    }
    return true;
}

function ShipPath::Print() {
    local i = 1;
    foreach(tile in this.canal1)
        AISign.BuildSign(tile, "c1-"+(i++));
    foreach(tile in this.open_water)
        AISign.BuildSign(tile, "w-"+(i++));
    foreach(tile in this.canal2)
        AISign.BuildSign(tile, "c2-"+(i++));
}

function ShipPath::EstimateBuoysCost() {
    return AIMarine.GetBuildCost(AIMarine.BT_BUOY) * (((this.canal1.len() + this.open_water.len() + this.canal2.len()) / this.buoy_distance) + 1);
}

function ShipPath::EstimateCanalsCost() {
    /* TODO */
    local test = AITestMode();
    local costs = AIAccounting();
    this.BuildCanals();
    return costs.GetCosts();
    //return (this.canal1.len() + this.canal2.len()) * 1000 + 7000;
}

function ShipPath::_GetNearbyBuoy(tile) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, tile, 3);
    tiles.Valuate(AIMarine.IsBuoyTile);
    tiles.KeepValue(1);
    if(!tiles.IsEmpty())
        return tiles.Begin();
    
    if(AIMarine.BuildBuoy(tile))
        return tile;
    
    return -1;
}

/* Buoys are essential for longer paths and also speed up the ship pathfinder. 
   This function places a buoy every n tiles. Existing buoys are reused. */
function ShipPath::BuildBuoys() {    
    local total = [];
    total.extend(this.canal1);
    total.extend(this.open_water);
    total.extend(this.canal2);
    local buoys = [];
    for(local i = this.buoy_distance/2; i<total.len()-(this.buoy_distance/2); i += this.buoy_distance) {
        local buoy = _GetNearbyBuoy(total[i]);
        if(buoy == -1)
            buoy = _GetNearbyBuoy(total[i+1]);
        if(buoy == -1)
            buoy = _GetNearbyBuoy(total[i-1]);
        if(buoy != -1)
            buoys.push(buoy);
    }
    return buoys;
}
