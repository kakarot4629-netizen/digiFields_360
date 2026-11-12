// Link existing live records in the Salesforce org
System.debug('=== UPDATING EXISTING LIVE RECORDS ===');

// 1. Update Asset profile with rich specifications
Asset__c ast = [SELECT Id FROM Asset__c LIMIT 1];
ast.Manufacturer__c = 'Cummins Power Systems';
ast.Model__c = 'QSK23';
ast.Product_Category__c = 'Generator';
ast.Status__c = 'Active';
ast.Install_Date__c = Date.today().addYears(-1);
ast.Warranty_Expiry__c = Date.today().addYears(1);
ast.Location_Address__c = 'Building 4 Utility Basement, Serum BioTech Campus, Pune';
ast.Specifications__c = 'Rated Power: 750 kVA / 600 kW | Voltage: 415V 3-Phase 50Hz | Engine: Cummins QSK23-G4 | Coolant Capacity: 65 Liters Ethylene Glycol | Oil Grade: 15W-40 CI-4 | Fuel: HSD High-Speed Diesel';
ast.Last_Service_Date__c = Date.today().addDays(-20);
ast.Visit_Count_30d__c = 2;
update ast;

// 2. Update Part compatibility
List<Part__c> parts = [SELECT Id, Part_Code__c FROM Part__c];
for (Part__c p : parts) {
    p.Compatible_Products__c = 'QSK23, QSK23-G4, QSK60';
}
update parts;

// 3. Link Asset to In Progress Work Order
List<Work_Order__c> wos = [SELECT Id, Status__c FROM Work_Order__c ORDER BY CreatedDate ASC LIMIT 5];
if (wos.size() >= 2) {
    // WO 1: In Progress linked to Asset
    wos[0].Asset__c = ast.Id;
    wos[0].Status__c = 'In Progress';
    wos[0].Equipment_ID__c = 'CUM-750-MUM-001';
    wos[0].Equipment_Type__c = 'Generator';
    wos[0].AI_Pre_Job_Briefing__c = 'SAFETY: Lockout 415V main busbar and disconnect negative battery terminal. Jacket water temperature must be below 40C before opening cooling lines. Tools required: digital manifold, 1/2" breaker bar, torque wrench.';

    // WO 2: Temporarily Paused linked to Asset
    wos[1].Asset__c = ast.Id;
    wos[1].Status__c = 'Temporarily Paused';
    wos[1].Current_Pause_Reason__c = 'Waiting for Part';
    wos[1].Current_Pause_Description__c = 'Awaiting replacement 24V Control Relay (RC-24V) from Pune Central Depot.';
    wos[1].Current_Pause_Dependency__c = 'PR-000492';
    wos[1].Paused_DateTime__c = DateTime.now().addHours(-5);
    wos[1].Expected_Resume_Date__c = DateTime.now().addHours(19);
    wos[1].Paused_Owner_Team__c = 'Procurement';
    wos[1].Total_Paused_Minutes__c = 300;
    
    update new List<Work_Order__c>{ wos[0], wos[1] };
}

System.debug('✅ Successfully updated live records in Salesforce org!');
