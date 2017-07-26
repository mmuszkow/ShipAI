/* Utils for choosing the best vehicle model for specific cargo amount. */
class ShipModel {
    _capacity_cache = AIList();
    
    constructor() {}
}

/* Checks if the vehicle model can transport cargo (natively or refitably). */
function _val_ShipModelCanTransportCargo(model, cargo) {
    return AIEngine.GetCargoType(model) == cargo || AIEngine.CanRefitCargo(model, cargo);
}

/* As there is no AIEngine.GetCapacity(model, specific_cargo): https://www.tt-forums.net/viewtopic.php?t=61021 */
function _val_GetVehicleModelCapacity(model, cargo, capacity_cache) {
    
    local pair = model << 16 | cargo;
    if(capacity_cache.HasItem(pair))
        return capacity_cache.GetValue(pair);
    
    local vehicles = AIVehicleList();
    vehicles.Valuate(AIVehicle.GetEngineType);
    vehicles.KeepValue(model);
    vehicles.Valuate(AIVehicle.GetCapacity, cargo);
    vehicles.KeepAboveValue(0);
    
    /* There are no vehicles of this vehicle model yet. */
    if(vehicles.IsEmpty())
        return AIEngine.GetCapacity(model);
    
    local real_capacity = AIVehicle.GetCapacity(vehicles.Begin(), cargo);
    capacity_cache.AddItem(pair, real_capacity);

    //AILog.Info(AIEngine.GetName(AIVehicle.GetEngineType(vehicles.Begin())) + " " + AICargo.GetCargoLabel(cargo) + " capacity " + real_capacity);
    
    return real_capacity;
}

/* This function is used to check if the vehicle model is not too big for the expected cargo amount. */
function _val_VehicleModelHasProperCapacity(model, cargo, capacity_cache, distance, monthly_production) {
    local daily_production = monthly_production / 30.4375;
    local travel_time_days = 27 * distance / AIEngine.GetMaxSpeed(model); // X km/h => X/27 tiles/day
    local capacity = _val_GetVehicleModelCapacity(model, cargo, capacity_cache);
    //AILog.Info("Production: " + (travel_time_days * daily_production) + " travel time: " + travel_time_days);
    return capacity <= 300 && capacity <= travel_time_days * daily_production;
}

/* For finding the best vehicle model. */
function _val_ShipModelRating(model, cargo, capacity_cache) {
    return (_val_GetVehicleModelCapacity(model, cargo, capacity_cache) * AIEngine.GetMaxSpeed(model) * AIEngine.GetReliability(model) / 100.0).tointeger()
}

function ShipModel::GetBestModelForCargo(cargo, round_trip_distance, monthly_production) {
    local models = AIEngineList(AIVehicle.VT_WATER);
    models.Valuate(_val_ShipModelCanTransportCargo, cargo);
    models.KeepValue(1);
    if(models.IsEmpty())
        return -1;
    
    if(models.Count() == 1)
        return models.Begin();
    
    /* Get rid of vessels that are too big for our cargo. */
    models.Valuate(_val_VehicleModelHasProperCapacity, cargo, this._capacity_cache, round_trip_distance, monthly_production);
    models.KeepValue(1);
    
    /* If there are no small vessels, use the big ones. */
    if(models.IsEmpty()) {
        models = AIEngineList(AIVehicle.VT_WATER);
        models.Valuate(_val_ShipModelCanTransportCargo, cargo);
        models.KeepValue(1);
    }
    
    models.Valuate(_val_ShipModelRating, cargo, this._capacity_cache);
    models.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return models.IsEmpty() ? -1 : models.Begin();
}

/* True if there is any vehicle that can transport this cargo. */
function ShipModel::ExistsForCargo(cargo) {
    local models = AIEngineList(AIVehicle.VT_WATER);
    models.Valuate(_val_ShipModelCanTransportCargo, cargo);
    models.KeepValue(1);
    return !models.IsEmpty();
}

/* Returns the minimal capacity of vehicle that can transport this cargo. */
function ShipModel::GetMinCapacityForCargo(cargo) {
    local models = AIEngineList(AIVehicle.VT_WATER);
    models.Valuate(_val_ShipModelCanTransportCargo, cargo);
    models.KeepValue(1);
    
    if(models.IsEmpty())
        return -1;
    
    models.Valuate(_val_GetVehicleModelCapacity, cargo, this._capacity_cache);
    models.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return AIEngine.GetCapacity(models.Begin());
}
