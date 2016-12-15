/* Utils for choosing the best vehicle model for specific cargo amount. */

/* Checks if the vehicle model can transport cargo (natively or refitably). */
function VehicleModelCanTransportCargo(model, cargo) {
    return AIEngine.GetCargoType(model) == cargo || AIEngine.CanRefitCargo(model, cargo);
}

/* This function is used to check if the vehicle model is not too big for the expected cargo amount. */
function VehicleModelHasProperCapacity(model, distance, monthly_production) {
    local daily_production = monthly_production / 30.4375;
    local travel_time_days = 27 * distance / AIEngine.GetMaxSpeed(model); // X km/h => X/27 tiles/day
    /* This is a capacity for the main cargo, 
       there is no nice way to determine the capacity for the specific cargo. 
       https://www.tt-forums.net/viewtopic.php?t=61021
     */
    local capacity = AIEngine.GetCapacity(model);
    //AILog.Info("Production: " + (travel_time_days * daily_production) + " travel time: " + travel_time_days);
    return capacity <= 300 && capacity <= travel_time_days * daily_production;
}

/* For finding the best vehicle model. */
function VehicleModelRating(model) {
    /* This is a capacity for the main cargo, 
       there is no nice way to determine the capacity for the specific cargo. 
       https://www.tt-forums.net/viewtopic.php?t=61021
     */
    return (AIEngine.GetCapacity(model) * AIEngine.GetMaxSpeed(model) * AIEngine.GetReliability(model) / 100.0).tointeger()
}

function GetBestVehicleModelForCargo(vehicle_type, cargo, round_trip_distance, monthly_production) {
    local models = AIEngineList(vehicle_type);
    models.Valuate(VehicleModelCanTransportCargo, cargo);
    models.KeepValue(1);
    
    if(models.IsEmpty())
        return -1;
    if(models.Count() == 1)
        return models.Begin();
    
    /* Get rid of vessels that are too big for our cargo. */
    models.Valuate(VehicleModelHasProperCapacity, round_trip_distance, monthly_production);
    models.KeepValue(1);
    
    /* If there are no small vessels, use the big ones. */
    if(models.IsEmpty()) {
        models = AIList();
        AIEngineList(AIVehicle.VT_WATER);
        models.Valuate(VehicleModelCanTransportCargo, cargo);
        models.KeepValue(1);
    }
    
    models.Valuate(VehicleModelRating);
    models.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return models.IsEmpty() ? -1 : models.Begin();
}

/* True if there is any vehicle that can transport this cargo. */
function VehicleModelForCargoExists(vehicle_type, cargo) {
    local models = AIEngineList(vehicle_type);
    models.Valuate(VehicleModelCanTransportCargo, cargo);
    models.KeepValue(1);
    return !models.IsEmpty();
}

/* Returns the minimal capacity of vehicle that can transport this cargo. */
function VehicleModelMinCapacity(vehicle_type, cargo) {
    local models = AIEngineList(vehicle_type);
    models.Valuate(VehicleModelCanTransportCargo, cargo);
    models.KeepValue(1);
    
    if(models.IsEmpty())
        return -1;
    
    /* This is a capacity for the main cargo, 
       there is no nice way to determine the capacity for the specific cargo. 
       https://www.tt-forums.net/viewtopic.php?t=61021
     */
    models.Valuate(AIEngine.GetCapacity);
    models.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return AIEngine.GetCapacity(models.Begin());
}
