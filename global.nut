require("ship_model.nut");

/* This is global to save checking cost in every valuate call. */
areCanalsAllowed <- false;

function SetCanalsAllowedFlag() {    
    areCanalsAllowed =  AIController.GetSetting("build_canals") && 
                        (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 2 * AICompany.GetMaxLoanAmount());
}

/* This is global to have single vehicle capatcity cache. */
ship_model <- ShipModel();
