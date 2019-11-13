require("utils.nut");

class Aqueduct {
    edge1 = -1;
    edge2 = -1;
   
    /* Aqueducts, other than road and rail bridges, can have unlimited length. */ 
    max_bridge_len = 10;

    constructor(edge, max_bridge_len = 10) {
        if(AIBridge.IsBridgeTile(edge)) {
            this.edge1 = edge;
            this.edge2 = AIBridge.GetOtherBridgeEnd(edge);
        } else {
            this.edge2 = _FindOtherBridgeEnd(edge);
            if(this.edge2 != -1)
                this.edge1 = edge;
        }
        this.max_bridge_len = max_bridge_len;
    }
}

function Aqueduct::Exists() {
    return AIBridge.IsBridgeTile(edge1);
}

function Aqueduct::GetMiddleTile() {
    local x1 = AIMap.GetTileX(this.edge1);
    local y1 = AIMap.GetTileY(this.edge1);
    local x2 = AIMap.GetTileX(this.edge2);
    local y2 = AIMap.GetTileY(this.edge2);
    return AIMap.GetTileIndex(((x1+x2)/2).tointeger(), ((y1+y2)/2).tointeger());
}

/* Finds other end for a potential bridge. */
function Aqueduct::_FindOtherBridgeEnd(edge) {
    if(!AITile.IsBuildable(edge))
        return -1;

    /* Follow down the slope. */
    local slope = AITile.GetSlope(edge);
    local dir = -1;
    switch(slope) {
        case AITile.SLOPE_NE:
            dir = WEST;
            break;
        case AITile.SLOPE_NW:
            dir = SOUTH;
            break;
        case AITile.SLOPE_SE:
            dir = NORTH;
            break;
        case AITile.SLOPE_SW:
            dir = EAST;
            break;
        default:
            return -1;
    }

    /* Everything on the way must be under the bridge. */
    local height = AITile.GetMaxHeight(edge);
    local complementary = AITile.GetComplementSlope(slope);
    edge += dir;
    local i = 0;
    while(i++ < this.max_bridge_len) {
        /* No aqueducts over sea. */
        if(AITile.GetMinHeight(edge) == 0)
            return -1;
      
        /* When we reach our start level again it's the decision time. */ 
        if(AITile.GetMaxHeight(edge) == height) {
            if(AITile.GetSlope(edge) == complementary && AITile.IsBuildable(edge))
                return edge;
            else
                return -1;
        }

        edge += dir;
    }
    return -1;
}

function Aqueduct::Length() {
    if(!AIBridge.IsBridgeTile(this.edge1))
        return 99999999;
    return AIMap.DistanceManhattan(this.edge1, this.edge2);
}

function Aqueduct::GetFront1() {
    return GetHillBackTile(this.edge1, 1);
}

function Aqueduct::GetFront2() {
    return GetHillBackTile(this.edge2, 1);
}

