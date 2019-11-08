require("global.nut");

/* Class which handles selling unprofitable, upgrading and replacing old vehicles. */
class Maintenance {
    
    /* Group for vehicles to be sold. */
    _sell_group = -1;
    /* Last time when maintenance was performed. */
    _maintenance_last_performed = AIDate.GetCurrentDate();
    
    constructor() {
        /* Autorenew vehicles when old. */
        AICompany.SetAutoRenewMonths(0);
        AICompany.SetAutoRenewStatus(true);

        _sell_group = GetSellGroup();       
    }
}

function Maintenance::GetSellGroup() {
        /* Get existing one. */
        local groups = AIGroupList();
        for(local group = groups.Begin(); !groups.IsEnd(); group = groups.Next()) {
            if(AIGroup.GetName(group) == "Ships to sell")
                return group;
        }
 
        /* Create one. */
        local group = AIGroup.CreateGroup(AIVehicle.VT_WATER);
        if(!AIGroup.IsValidGroup(group)) {
            AILog.Error("Cannot create a vehicles group: " + AIError.GetLastErrorString());
            return -1;
        }
        if(!AIGroup.SetName(group, "Ships to sell")) {
            AILog.Error("Failed to set name for the maintenance group: " + AIError.GetLastErrorString());
            AIGroup.DeleteGroup(group);
            return -1;
        }
        return group;
}

function Maintenance::SellUnprofitable() {
    local sold = 0;
   
    if(this._sell_group == -1) {
        this._sell_group = GetSellGroup();
        if(this._sell_group == -1)
            return sold;
    }
 
    /* Sell unprofitable in depots. */
    local unprofitable = AIVehicleList_Group(this._sell_group);
    for(local vehicle = unprofitable.Begin(); !unprofitable.IsEnd(); vehicle = unprofitable.Next()) {
        if(AIVehicle.IsStoppedInDepot(vehicle)) {
            local depot = AIVehicle.GetLocation(vehicle);
            if(AIVehicle.SellVehicle(vehicle)) {
                sold++;
                
                /* Sell also the depot if it's unused to avoid the property maintenance costs. */
                if(AIMap.IsValidTile(depot) && AIVehicleList_Depot(depot).IsEmpty() && !AITile.DemolishTile(depot))
                    AILog.Error("Failed to demolish unused depot: " + AIError.GetLastErrorString());

                /* The unused stations are kept, to keep the 'good' spots. */
            } else
                AILog.Error("Failed to sell unprofitable vehicle: " + AIError.GetLastErrorString());
        }
    }

    /* Find unprofitable. */
    unprofitable = AIVehicleList_DefaultGroup(AIVehicle.VT_WATER);
    unprofitable.Valuate(AIVehicle.GetProfitLastYear);
    unprofitable.KeepBelowValue(100); /* Less than 100 cash */
    unprofitable.Valuate(AIVehicle.GetProfitThisYear);
    unprofitable.KeepBelowValue(100);
    unprofitable.Valuate(AIVehicle.GetAge);
    unprofitable.KeepAboveValue(1095); /* 3 years old minimum */
    unprofitable.Valuate(AIVehicle.IsValidVehicle);
    unprofitable.KeepValue(1);
    for(local vehicle = unprofitable.Begin(); !unprofitable.IsEnd(); vehicle = unprofitable.Next()) {
       
        /* We can't use AIVehicle.SendToDepot here because it chooses the closest depot,
         * not always the one on our route. */
        local current_order = AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT);
        local depot = AIOrder.GetOrderDestination(vehicle, 0);
        local buoys = []; 

        /* This way we ensure that we will be able to get back from where we started. */
        for(local order = current_order - 1; order >= 1; order--)
            buoys.append(AIOrder.GetOrderDestination(vehicle, order));

        /* We can be sharing orders with other ships, so we need to clean previous ones. */
        AIOrder.UnshareOrders(vehicle);
        foreach(buoy in buoys)
            AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE);
        AIOrder.AppendOrder(vehicle, depot, AIOrder.OF_STOP_IN_DEPOT);

        /* We remove them from default group to avoid looping. */
        AIGroup.MoveVehicle(this._sell_group, vehicle);
    }
    
    return sold;
}

/* Replaces model with better model, if possible. */
function Maintenance::Upgrade() {   
    local sent_to_upgrade = 0;
    local min_balance = AICompany.GetAutoRenewMoney(AICompany.COMPANY_SELF);
    
    local cargos = AICargoList();
    local replacements = AIList();
    for(local cargo = cargos.Begin(); !cargos.IsEnd(); cargo = cargos.Next()) {
        /* Let's check what possible engines we have for this cargo. */
        if(!ship_model.ExistsForCargo(cargo))
            continue;
        
        /* Find the vehicles to be upgraded. */
        local vehicles = AIVehicleList_DefaultGroup(AIVehicle.VT_WATER);
        vehicles.Valuate(AIVehicle.GetCapacity, cargo);
        vehicles.KeepAboveValue(0);
        
        for(local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
            local current_model = AIVehicle.GetEngineType(vehicle);

            local better_model = -1;
            if(replacements.HasItem(current_model))
                better_model = replacements.GetValue(current_model);
            else {
                better_model = ship_model.GetReplacementModel(current_model, cargo, AIVehicle.GetCapacity(vehicle, cargo));
                replacements.AddItem(current_model, better_model);
            }
            
            if(better_model == -1)
                continue;
            
            local double_price = 2 * AIEngine.GetPrice(better_model);
            
            if( AICompany.GetBankBalance(AICompany.COMPANY_SELF) -
                AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, AICompany.CURRENT_QUARTER) < 
                double_price + min_balance)
                return sent_to_upgrade;
            
            AIGroup.SetAutoReplace(AIGroup.GROUP_DEFAULT, current_model, better_model);
            AILog.Info("Replacing " + AIEngine.GetName(current_model) + " with " + AIEngine.GetName(better_model));
            
            /* We need to send the vehicle to depot to be replaced but we should do this only when the vehicle is close to the depot (1st or last order). */
            local last_order = AIOrder.GetOrderCount(vehicle) - 1;
            local current_order = AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT);
            if(current_order == 0 || current_order == 1 || current_order == last_order) {
                if(!AIOrder.IsGotoDepotOrder(vehicle, AIOrder.ORDER_CURRENT)) {
                    if(AIVehicle.SendVehicleToDepotForServicing(vehicle))
                        sent_to_upgrade++;
                    else
                        AILog.Error("Failed to send the vehicle for servicing: " + AIError.GetLastErrorString());
                }
            }
        }
    }

    return sent_to_upgrade;
}

function Maintenance::Perform() {
    local unprofitable_sold = this.SellUnprofitable();
    local upgraded = this.Upgrade();
    if(unprofitable_sold > 0)
        AILog.Info("Unprofitable vehicles sold: " + unprofitable_sold);
    if(upgraded > 0)
        AILog.Info("Ships sent for upgrading: " + upgraded);
    this._maintenance_last_performed = AIDate.GetCurrentDate();
}

/* This is performed once per 6 months. */
function Maintenance::PerformIfNeeded() {
    if(AIDate.GetCurrentDate() - this._maintenance_last_performed < 180)
        return;
    
    Perform();
}
