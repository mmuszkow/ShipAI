require("ship_model.nut");

/* This is global to have single vehicle capacity cache. */
ship_model <- ShipModel();

/* Directions, used in multiple places. */
NORTH <- AIMap.GetTileIndex(0, -1);
SOUTH <- AIMap.GetTileIndex(0, 1);
WEST <- AIMap.GetTileIndex(1, 0);
EAST <- AIMap.GetTileIndex(-1, 0);

