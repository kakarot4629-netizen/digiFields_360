// Script to seed comprehensive demo data for Work Order, Asset 360, Parts, and Paused Orders
System.debug('=== SEEDING ENHANCEMENT DEMO DATA ===');

// 1. Account
List<Account> existingAccs = [SELECT Id FROM Account LIMIT 1];
Account acc;
if (!existingAccs.isEmpty()) {
    acc = existingAccs[0];
} else {
    acc = new Account(
        Name = 'Serum BioTech LifeSciences Campus',
        BillingCity = 'Pune',
        BillingCountry = 'India'
    );
    insert acc;
}

// 2. Assets with rich specifications
Asset__c asset1 = new Asset__c(
    Product_Name__c = 'Cummins Diesel Generator 250kVA',
    Serial_Number__c = 'SN-CUM-8899',
    Model__c = 'QSK60-G4',
    Manufacturer__c = 'Cummins Power Systems',
    Product_Category__c = 'Generator',
    Account__c = acc.Id,
    Install_Date__c = Date.today().addYears(-1),
    Warranty_Expiry__c = Date.today().addYears(2),
    Status__c = 'Active',
    Location_Address__c = 'Building 4 Utility Basement, Serum BioTech Campus, Pune',
    Specifications__c = 'Rated Power: 250 kVA / 200 kW | Voltage: 415V 3-Phase | Engine: Cummins QSK60 16-Cylinder | Coolant Capacity: 45 Liters OAT | Oil Grade: 15W-40 CI-4 | Fuel Consumption: 52 L/hr at 100% Load',
    Last_Service_Date__c = Date.today().addDays(-45),
    Visit_Count_30d__c = 1
);

Asset__c asset2 = new Asset__c(
    Product_Name__c = 'Carrier Industrial Screw Chiller',
    Serial_Number__c = 'SN-CAR-4421',
    Model__c = '30XA-300',
    Manufacturer__c = 'Carrier Commercial HVAC',
    Product_Category__c = 'HVAC',
    Account__c = acc.Id,
    Install_Date__c = Date.today().addYears(-2),
    Warranty_Expiry__c = Date.today().addMonths(6),
    Status__c = 'Degraded',
    Location_Address__c = 'Rooftop Plant Room, Building 2, Serum BioTech Campus, Pune',
    Specifications__c = 'Cooling Capacity: 300 TR (1055 kW) | Refrigerant: R-134a (140 kg charge) | Compressor: Twin Screw Semi-Hermetic | Max Operating Pressure: 375 PSI | Power Supply: 400V 50Hz 3-Phase',
    Last_Service_Date__c = Date.today().addDays(-15),
    Visit_Count_30d__c = 2
);
insert new List<Asset__c>{ asset1, asset2 };

// 3. Historical Job History records for Asset 1
Job_History__c jh1 = new Job_History__c(
    Equipment_ID__c = 'SN-CUM-8899',
    Job_Date__c = Date.today().addDays(-45),
    Fault_Description__c = 'Coolant pump seal leakage and high temperature warning at 92C',
    Resolution__c = 'Replaced water pump assembly gasket, flushed cooling circuit, refilled 50/50 OAT coolant',
    Parts_Used__c = 'Coolant Pump Gasket Kit CV-KIT-01 (1x), Filter AF-500K (1x)',
    First_Time_Fix__c = true,
    Customer_Satisfaction__c = 5,
    Duration_Minutes__c = 110,
    Technician__c = null
);
insert jh1;

// 4. Compatible Parts in Catalog
Part__c p1 = new Part__c(
    Part_Code__c = 'CV-KIT-01',
    Category__c = 'Generator',
    Unit_Cost__c = 3500,
    Is_Warranty_Item__c = true,
    Is_Active__c = true,
    Compatible_Products__c = 'QSK60-G4, QSK60'
);
Part__c p2 = new Part__c(
    Part_Code__c = 'AF-500K',
    Category__c = 'Generator',
    Unit_Cost__c = 1250,
    Is_Warranty_Item__c = true,
    Is_Active__c = true,
    Compatible_Products__c = 'QSK60-G4'
);
Part__c p3 = new Part__c(
    Part_Code__c = 'RC-24V',
    Category__c = 'HVAC',
    Unit_Cost__c = 850,
    Is_Warranty_Item__c = true,
    Is_Active__c = true,
    Compatible_Products__c = '30XA-300, 30XA'
);
insert new List<Part__c>{ p1, p2, p3 };

// 5. Work Order 1: In Progress with Linked Generator Asset
Work_Order__c wo1 = new Work_Order__c(
    Subject__c = 'Generator Coolant Line Inspection & Filter Servicing',
    Account__c = acc.Id,
    Asset__c = asset1.Id,
    Equipment_ID__c = 'SN-CUM-8899',
    Equipment_Type__c = 'Generator',
    Priority__c = 'High',
    Status__c = 'In Progress',
    Site_Address__c = 'Building 4 Utility Basement, Serum BioTech Campus, Pune',
    Scheduled_Date__c = DateTime.now().addHours(-3),
    Description__c = 'Routine quarterly inspection and coolant circuit pressure test on backup power generator.',
    AI_Pre_Job_Briefing__c = 'SAFETY: Lockout 415V main breaker and disconnect battery negative terminal. Engine jacket temperature must be below 40C before opening lines. Tooling required: 1/2" breaker bar, digital manifold, torque wrench.'
);

// 6. Work Order 2: Temporarily Paused (Waiting for Part) on Chiller Asset
Work_Order__c wo2 = new Work_Order__c(
    Subject__c = 'HVAC Chiller High Head Pressure Cutout (E-401)',
    Account__c = acc.Id,
    Asset__c = asset2.Id,
    Equipment_ID__c = 'SN-CAR-4421',
    Equipment_Type__c = 'HVAC',
    Priority__c = 'Critical',
    Status__c = 'Temporarily Paused',
    Current_Pause_Reason__c = 'Waiting for Part',
    Current_Pause_Description__c = 'High pressure switch tripped at 380 PSI. 24V control relay (RC-24V) contacts welded shut. Awaiting replacement relay from Pune Central Depot.',
    Current_Pause_Dependency__c = 'PR-000492',
    Paused_DateTime__c = DateTime.now().addHours(-6),
    Expected_Resume_Date__c = DateTime.now().addHours(18),
    Paused_Owner_Team__c = 'Procurement',
    Total_Paused_Minutes__c = 360,
    Site_Address__c = 'Rooftop Plant Room, Building 2, Serum BioTech Campus, Pune',
    Scheduled_Date__c = DateTime.now().addHours(-8),
    Description__c = 'Central chiller tripped with alarm E-401. Secondary chilled water loop temperature rising towards critical cleanroom threshold.',
    AI_Pre_Job_Briefing__c = 'CRITICAL: Cleanroom chiller down. High-pressure lines exceed 85C. Verify condenser fan 24V control relay before restarting.'
);
insert new List<Work_Order__c>{ wo1, wo2 };

// 7. Audit Pause Log on Work Order 2
Work_Order_Pause_Log__c pauseLog = new Work_Order_Pause_Log__c(
    Work_Order__c = wo2.Id,
    Pause_Reason__c = 'Waiting for Part',
    Description__c = 'Awaiting replacement 24V Control Relay (RC-24V) from depot dispatch.',
    Dependency__c = 'PR-000492',
    Paused_At__c = DateTime.now().addHours(-6),
    Expected_Resume_Date__c = DateTime.now().addHours(18),
    Responsible_Team__c = 'Procurement'
);
insert pauseLog;

// 8. Parts Requests lifecycle on Work Order 1
Parts_Request__c pr1 = new Parts_Request__c(
    Work_Order__c = wo1.Id,
    Part__c = p1.Id,
    Quantity__c = 1,
    Is_Warranty__c = true,
    Status__c = 'Part Issued'
);
Parts_Request__c pr2 = new Parts_Request__c(
    Work_Order__c = wo1.Id,
    Part__c = p2.Id,
    Quantity__c = 2,
    Is_Warranty__c = true,
    Status__c = 'Approved'
);
insert new List<Parts_Request__c>{ pr1, pr2 };

System.debug('✅ DEMO SEED COMPLETED SUCCESSFULLY!');
System.debug('Asset 1: ' + asset1.Id + ' | Asset 2: ' + asset2.Id);
System.debug('Work Order 1 (In Progress): ' + wo1.Id);
System.debug('Work Order 2 (Paused): ' + wo2.Id);
