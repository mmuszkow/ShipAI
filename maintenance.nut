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
        
        /* Create groups. */
        this._sell_group = AIGroup.CreateGroup(AIVehicle.VT_WATER);
        local i = 1;
        while(!AIGroup.SetName(this._sell_group, "Ships to sell #" + i)) {
            i = i + 1;
            if(i > 255) break;
        }
        if(!AIGroup.IsValidGroup(this._sell_group))
            AILog.Error("Cannot create a vehicles group");
    }
}

function Maintenance::SellUnprofitable() {
    local sold = 0;
    
    /* Sell unprofitable in depots. */
    local unprofitable = AIVehicleList_Group(this._sell_group);
    for(local vehicle = unprofitable.Begin(); unprofitable.HasNext(); vehicle = unprofitable.Next()) {
        if(AIVehicle.IsStoppedInDepot(vehicle))
            if(AIVehicle.SellVehicle(vehicle))
                sold++;
            else
                AILog.Error("Failed to sell unprofitable vehicle: " + AIError.GetLastErrorString());
    }

    /* Find unprofitable. */
    unprofitable = AIVehicleList_DefaultGroup(AIVehicle.VT_WATER);
    unprofitable.Valuate(AIVehicle.GetProfitLastYear);
    unprofitable.KeepBelowValue(0);
    unprofitable.Valuate(AIVehicle.GetProfitThisYear);
    unprofitable.KeepBelowValue(0);
    unprofitable.Valuate(AIVehicle.GetAge);
    unprofitable.KeepAboveValue(1095); /* 3 years old minimum */
    unprofitable.Valuate(AIVehicle.IsValidVehicle);
    unprofitable.KeepValue(1);
    for(local vehicle = unprofitable.Begin(); unprofitable.HasNext(); vehicle = unprofitable.Next()) {
        
        /* If 2 first orders are for servicing the vehicle in depot when it's age is above the max. 
           This method is better because vehicle won't get lost (especially ship).
         */
        if(AIOrder.IsConditionalOrder(vehicle, 0) && AIOrder.IsGotoDepotOrder(vehicle, 1)) {
            local depot = AIOrder.GetOrderDestination(vehicle, 1);
            /* UnshareOrders remove all orders from the list, we need to make a copy of the buoys location before. */
            local buoys = [];
            local ord_count = AIOrder.GetOrderCount(vehicle);
            for(local ord_pos = AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT); ord_pos < ord_count; ord_pos++) {
                if(AIOrder.IsGotoWaypointOrder(vehicle, ord_pos))
                    buoys.append(AIOrder.GetOrderDestination(vehicle, ord_pos));
            }
            
            AIOrder.UnshareOrders(vehicle);
            foreach(buoy in buoys)
                AIOrder.AppendOrder(vehicle, buoy, AIOrder.OF_NONE);
            AIOrder.AppendOrder(vehicle, depot, AIOrder.OF_STOP_IN_DEPOT);
                
        } else {
            AILog.Error("No max age send to depot order");
            continue;
        }
        
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
    for(local cargo = cargos.Begin(); cargos.HasNext(); cargo = cargos.Next()) {
        /* Let's check what possible engines we have for this cargo. */
        if(!ship_model.ExistsForCargo(cargo))
            continue;
        
        /* Find the vehicles to be upgraded. */
        local vehicles = AIVehicleList_DefaultGroup(AIVehicle.VT_WATER);
        vehicles.Valuate(AIVehicle.GetCapacity, cargo);
        vehicles.KeepAboveValue(0);
        
        for(local vehicle = vehicles.Begin(); vehicles.HasNext(); vehicle = vehicles.Next()) {
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
            
            /* The company needs to have more money than (autoreplace money limit) + 2 * (price for new vehicle). */
            if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < double_price + min_balance)
                return sent_to_upgrade;
            
            AIGroup.SetAutoReplace(AIGroup.GROUP_DEFAULT, current_model, better_model);
            
            /* We need to send the vehicle to depot to be replaced but we should do this only when the vehicle is close to the depot (1st or last order). */
            local last_order = AIOrder.GetOrderCount(vehicle) - 1;
            local current_order = AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT);
            if((current_order >= 0 && current_order <= 2) || current_order == last_order) {
                if(!AIOrder.IsGotoDepotOrder(vehicle, AIOrder.ORDER_CURRENT)) {
                    if(AIVehicle.SendVehicleToDepotForServicing(vehicle)) {
                        sent_to_upgrade++;
                    } else
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

/* This is performed once per year. */
function Maintenance::PerformIfNeeded() {
    if(AIDate.GetCurrentDate() - this._maintenance_last_performed < 365)
        return;
    
    Perform();
}
