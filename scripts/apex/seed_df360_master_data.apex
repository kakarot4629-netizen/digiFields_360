// digiField360 — Master Seed Data Script
// Idempotent execution: Creates full realistic operational demonstration data

System.debug('=== STARTING DIGIFIELD360 MASTER SEED DATA SETUP ===');

// 1. Service Zones
Map<String, Service_Zone__c> zones = new Map<String, Service_Zone__c>();
List<String> zoneNames = new List<String>{ 'Mumbai West', 'Mumbai Central', 'Mumbai South', 'Navi Mumbai' };
List<Service_Zone__c> existingZones = [SELECT Id, Name FROM Service_Zone__c WHERE Name IN :zoneNames];
for (Service_Zone__c z : existingZones) zones.put(z.Name, z);

List<Service_Zone__c> zonesToInsert = new List<Service_Zone__c>();
if (!zones.containsKey('Mumbai West')) {
    zonesToInsert.add(new Service_Zone__c(Name = 'Mumbai West', Is_Active__c = true, Pin_Codes__c = '400050, 400051, 400053, 400058, 400069'));
}
if (!zones.containsKey('Mumbai Central')) {
    zonesToInsert.add(new Service_Zone__c(Name = 'Mumbai Central', Is_Active__c = true, Pin_Codes__c = '400012, 400013, 400014, 400015, 400016'));
}
if (!zones.containsKey('Mumbai South')) {
    zonesToInsert.add(new Service_Zone__c(Name = 'Mumbai South', Is_Active__c = true, Pin_Codes__c = '400001, 400002, 400003, 400004, 400005'));
}
if (!zones.containsKey('Navi Mumbai')) {
    zonesToInsert.add(new Service_Zone__c(Name = 'Navi Mumbai', Is_Active__c = true, Pin_Codes__c = '400703, 400705, 400706, 400708, 400709'));
}
if (!zonesToInsert.isEmpty()) {
    insert zonesToInsert;
    for (Service_Zone__c z : zonesToInsert) zones.put(z.Name, z);
}
System.debug('Service Zones ready: ' + zones.size());

// 2. Skills
List<Skill__c> skillsToInsert = new List<Skill__c>();
List<String> skillNames = new List<String>{ 'Industrial HVAC Maintenance', 'Diesel Generator Overhaul', 'High Voltage Transformer Diagnostics', 'Precision Pressure Calibration' };
Map<String, Skill__c> skillsMap = new Map<String, Skill__c>();
for (Skill__c s : [SELECT Id, Name, Skill_Name__c FROM Skill__c WHERE Skill_Name__c IN :skillNames]) {
    skillsMap.put(s.Skill_Name__c, s);
}

if (!skillsMap.containsKey('Industrial HVAC Maintenance')) {
    skillsToInsert.add(new Skill__c(Name = 'Industrial HVAC', Skill_Name__c = 'Industrial HVAC Maintenance', Category__c = 'HVAC', Cert_Required__c = true, Description__c = 'Commercial and industrial chillers and HVAC plants.'));
}
if (!skillsMap.containsKey('Diesel Generator Overhaul')) {
    skillsToInsert.add(new Skill__c(Name = 'DG Overhaul', Skill_Name__c = 'Diesel Generator Overhaul', Category__c = 'Mechanical', Cert_Required__c = false, Description__c = 'Heavy diesel generator 250kVA - 2000kVA engine servicing.'));
}
if (!skillsMap.containsKey('High Voltage Transformer Diagnostics')) {
    skillsToInsert.add(new Skill__c(Name = 'HV Transformer', Skill_Name__c = 'High Voltage Transformer Diagnostics', Category__c = 'Electrical', Cert_Required__c = true, Description__c = '11kV/33kV substation transformer oil and winding testing.'));
}
if (!skillsMap.containsKey('Precision Pressure Calibration')) {
    skillsToInsert.add(new Skill__c(Name = 'Pressure Calibration', Skill_Name__c = 'Precision Pressure Calibration', Category__c = 'Calibration', Cert_Required__c = true, Description__c = 'ISO 17025 compliant digital pressure transmitter calibration.'));
}
if (!skillsToInsert.isEmpty()) {
    insert skillsToInsert;
    for (Skill__c s : skillsToInsert) skillsMap.put(s.Skill_Name__c, s);
}
System.debug('Skills ready: ' + skillsMap.size());

// 3. SLA Configurations
List<SLA_Config__c> slaConfigs = new List<SLA_Config__c>();
List<SLA_Config__c> existingSLAs = [SELECT Id, Priority__c FROM SLA_Config__c];
if (existingSLAs.isEmpty()) {
    slaConfigs.add(new SLA_Config__c(Name = 'Critical SLA', Priority__c = 'Critical', Product_Category__c = 'All', Customer_Tier__c = 'All', Ack_SLA_Mins__c = 15, Response_SLA_Hrs__c = 1, Resolution_SLA_Hrs__c = 2, Is_Active__c = true));
    slaConfigs.add(new SLA_Config__c(Name = 'High SLA', Priority__c = 'High', Product_Category__c = 'All', Customer_Tier__c = 'All', Ack_SLA_Mins__c = 30, Response_SLA_Hrs__c = 2, Resolution_SLA_Hrs__c = 4, Is_Active__c = true));
    slaConfigs.add(new SLA_Config__c(Name = 'Medium SLA', Priority__c = 'Medium', Product_Category__c = 'All', Customer_Tier__c = 'All', Ack_SLA_Mins__c = 60, Response_SLA_Hrs__c = 4, Resolution_SLA_Hrs__c = 8, Is_Active__c = true));
    slaConfigs.add(new SLA_Config__c(Name = 'Low SLA', Priority__c = 'Low', Product_Category__c = 'All', Customer_Tier__c = 'All', Ack_SLA_Mins__c = 120, Response_SLA_Hrs__c = 8, Resolution_SLA_Hrs__c = 24, Is_Active__c = true));
    insert slaConfigs;
}
System.debug('SLA Configs ready');

// 4. Depots
Map<String, Depot__c> depotsMap = new Map<String, Depot__c>();
for (Depot__c d : [SELECT Id, Name FROM Depot__c]) depotsMap.put(d.Name, d);
List<Depot__c> depotsToInsert = new List<Depot__c>();
if (!depotsMap.containsKey('Central Spares Depot')) {
    depotsToInsert.add(new Depot__c(Name = 'Central Spares Depot', Zone__c = zones.get('Mumbai Central')?.Id, Address__c = 'Lower Parel Logistics Hub, Mumbai', GPS_Location__Latitude__s = 19.0016, GPS_Location__Longitude__s = 72.8302, Is_Active__c = true));
}
if (!depotsMap.containsKey('Western Transit Depot')) {
    depotsToInsert.add(new Depot__c(Name = 'Western Transit Depot', Zone__c = zones.get('Mumbai West')?.Id, Address__c = 'Andheri East Cargo Complex, Mumbai', GPS_Location__Latitude__s = 19.1136, GPS_Location__Longitude__s = 72.8697, Is_Active__c = true));
}
if (!depotsToInsert.isEmpty()) {
    insert depotsToInsert;
    for (Depot__c d : depotsToInsert) depotsMap.put(d.Name, d);
}
System.debug('Depots ready: ' + depotsMap.size());

// 5. Parts Catalog
Map<String, Part__c> partsMap = new Map<String, Part__c>();
for (Part__c p : [SELECT Id, Part_Code__c FROM Part__c]) partsMap.put(p.Part_Code__c, p);
List<Part__c> partsToInsert = new List<Part__c>();
if (!partsMap.containsKey('AF-500K')) {
    partsToInsert.add(new Part__c(Name = 'Air Filter Heavy Duty 500kVA', Part_Code__c = 'AF-500K', Category__c = 'Mechanical', Unit_Cost__c = 1250, Is_Warranty_Item__c = false, Is_Active__c = true));
}
if (!partsMap.containsKey('RC-24V')) {
    partsToInsert.add(new Part__c(Name = 'Heavy-Duty Relay Coil 24V', Part_Code__c = 'RC-24V', Category__c = 'Electrical', Unit_Cost__c = 850, Is_Warranty_Item__c = true, Is_Active__c = true));
}
if (!partsMap.containsKey('CV-KIT-01')) {
    partsToInsert.add(new Part__c(Name = 'Commercial Chiller Valve Kit', Part_Code__c = 'CV-KIT-01', Category__c = 'HVAC', Unit_Cost__c = 6800, Is_Warranty_Item__c = true, Is_Active__c = true));
}
if (!partsMap.containsKey('DFS-PRO')) {
    partsToInsert.add(new Part__c(Name = 'Digital Flow Sensor Pro 4-20mA', Part_Code__c = 'DFS-PRO', Category__c = 'Electronics', Unit_Cost__c = 14500, Is_Warranty_Item__c = true, Is_Active__c = true));
}
if (!partsToInsert.isEmpty()) {
    insert partsToInsert;
    for (Part__c p : partsToInsert) partsMap.put(p.Part_Code__c, p);
}
System.debug('Parts ready: ' + partsMap.size());

// 6. Parts Stock
List<Parts_Stock__c> stockList = [SELECT Id FROM Parts_Stock__c];
if (stockList.isEmpty()) {
    List<Parts_Stock__c> newStock = new List<Parts_Stock__c>();
    Id centralDepotId = depotsMap.values()[0].Id;
    for (Part__c p : partsMap.values()) {
        newStock.add(new Parts_Stock__c(
            Part__c = p.Id,
            Depot__c = centralDepotId,
            Quantity_Available__c = 50,
            Quantity_Reserved__c = 2,
            Reorder_Level__c = 10,
            Last_Updated__c = DateTime.now()
        ));
    }
    insert newStock;
}
System.debug('Parts Stock ready');

// 7. Technicians
Id myUserId = UserInfo.getUserId();
List<Technician__c> myTechList = [SELECT Id FROM Technician__c WHERE User__c = :myUserId LIMIT 1];
Technician__c primaryTech;
if (myTechList.isEmpty()) {
    primaryTech = new Technician__c(
        User__c = myUserId,
        Zone__c = zones.get('Mumbai West')?.Id,
        Availability_Status__c = 'Available',
        CSAT_Avg_30d__c = 4.9,
        FTFR_Pct__c = 95.0,
        Active_Job_Count__c = 1,
        Employee_Code__c = 'TECH-MUM-01',
        Current_GPS_Latitude__c = 19.0760,
        Current_GPS_Longitude__c = 72.8777,
        Is_Active__c = true
    );
    insert primaryTech;
} else {
    primaryTech = myTechList[0];
}

List<Technician__c> additionalTechs = [SELECT Id FROM Technician__c WHERE Employee_Code__c IN ('TECH-MUM-02', 'TECH-MUM-03')];
if (additionalTechs.isEmpty()) {
    insert new List<Technician__c>{
        new Technician__c(Zone__c = zones.get('Mumbai Central')?.Id, Availability_Status__c = 'Available', CSAT_Avg_30d__c = 4.8, FTFR_Pct__c = 92.0, Active_Job_Count__c = 0, Employee_Code__c = 'TECH-MUM-02', Current_GPS_Latitude__c = 19.0176, Current_GPS_Longitude__c = 72.8478, Is_Active__c = true),
        new Technician__c(Zone__c = zones.get('Mumbai South')?.Id, Availability_Status__c = 'Available', CSAT_Avg_30d__c = 4.7, FTFR_Pct__c = 89.5, Active_Job_Count__c = 2, Employee_Code__c = 'TECH-MUM-03', Current_GPS_Latitude__c = 18.9388, Current_GPS_Longitude__c = 72.8354, Is_Active__c = true)
    };
}
System.debug('Technicians ready');

// 8. Accounts & Service Contracts
List<Account> demoAccounts = [SELECT Id FROM Account WHERE Name = 'Tata Communications Data Center' LIMIT 1];
Account demoAccount;
if (demoAccounts.isEmpty()) {
    demoAccount = new Account(Name = 'Tata Communications Data Center', BillingCity = 'Mumbai', BillingState = 'Maharashtra', BillingCountry = 'India', Phone = '+919876543210');
    insert demoAccount;
} else {
    demoAccount = demoAccounts[0];
}

List<Service_Contract__c> contracts = [SELECT Id FROM Service_Contract__c WHERE Account__c = :demoAccount.Id LIMIT 1];
Service_Contract__c contract;
if (contracts.isEmpty()) {
    contract = new Service_Contract__c(
        Name = 'Platinum Critical AMC 24x7',
        Account__c = demoAccount.Id,
        Contract_Type__c = 'Comprehensive',
        Start_Date__c = Date.today().addMonths(-3),
        End_Date__c = Date.today().addMonths(9),
        SLA_Resolution_Hrs__c = 2,
        Is_Active__c = true
    );
    insert contract;
} else {
    contract = contracts[0];
}

// 9. Assets
List<Asset__c> assets = [SELECT Id FROM Asset__c WHERE Account__c = :demoAccount.Id LIMIT 1];
Asset__c demoAsset;
if (assets.isEmpty()) {
    demoAsset = new Asset__c(
        Name = 'Cummins 750kVA Heavy Generator #1',
        Account__c = demoAccount.Id,
        Serial_Number__c = 'CUM-750-MUM-001',
        Product_Name__c = 'Cummins QSK23 750kVA Generator',
        Product_Category__c = 'Mechanical',
        Install_Date__c = Date.today().addMonths(-12),
        Warranty_Expiry__c = Date.today().addMonths(12),
        Is_Under_Warranty__c = true,
        Location_Address__c = 'Tata Data Center, Vikhroli West, Mumbai',
        GPS_Location__Latitude__s = 19.1075,
        GPS_Location__Longitude__s = 72.9248
    );
    insert demoAsset;
} else {
    demoAsset = assets[0];
}

// 10. Service Jobs (Diverse operational sample)
List<Service_Job__c> sampleJobs = [SELECT Id FROM Service_Job__c LIMIT 5];
if (sampleJobs.isEmpty()) {
    List<Service_Job__c> newJobs = new List<Service_Job__c>{
        new Service_Job__c(
            Account__c = demoAccount.Id,
            Asset__c = demoAsset.Id,
            Technician__c = primaryTech.Id,
            Zone__c = zones.get('Mumbai West')?.Id,
            Service_Contract__c = contract.Id,
            Job_Type__c = 'Corrective Breakdown',
            Priority__c = 'Critical',
            Product_Category__c = 'Mechanical',
            Status__c = 'Assigned',
            Notes__c = 'Generator automatic transfer switch failing on load test. Customer requests urgent on-site diagnostic.',
            Source__c = 'WhatsApp',
            SLA_Deadline__c = DateTime.now().addHours(2),
            SLA_Status__c = 'Green'
        ),
        new Service_Job__c(
            Account__c = demoAccount.Id,
            Asset__c = demoAsset.Id,
            Technician__c = primaryTech.Id,
            Zone__c = zones.get('Mumbai West')?.Id,
            Service_Contract__c = contract.Id,
            Job_Type__c = 'Preventive Maintenance',
            Priority__c = 'High',
            Product_Category__c = 'HVAC',
            Status__c = 'On Site',
            Check_In_Time__c = DateTime.now().addMinutes(-45),
            Notes__c = 'Quarterly chiller vibration analysis and oil filter replacement.',
            Source__c = 'Portal',
            SLA_Deadline__c = DateTime.now().addHours(3),
            SLA_Status__c = 'Green'
        ),
        new Service_Job__c(
            Account__c = demoAccount.Id,
            Asset__c = demoAsset.Id,
            Zone__c = zones.get('Mumbai Central')?.Id,
            Job_Type__c = 'Corrective Breakdown',
            Priority__c = 'Critical',
            Product_Category__c = 'Electrical',
            Status__c = 'New',
            Notes__c = 'Substation relay trip on feeder line #2.',
            Source__c = 'Agentforce',
            SLA_Deadline__c = DateTime.now().addHours(1),
            SLA_Status__c = 'Amber'
        ),
        new Service_Job__c(
            Account__c = demoAccount.Id,
            Asset__c = demoAsset.Id,
            Technician__c = primaryTech.Id,
            Zone__c = zones.get('Mumbai West')?.Id,
            Job_Type__c = 'Inspection',
            Priority__c = 'Medium',
            Product_Category__c = 'Calibration',
            Status__c = 'Completed',
            Check_In_Time__c = DateTime.now().addHours(-4),
            Completed_Time__c = DateTime.now().addHours(-2),
            Resolution_Time_Min__c = 120,
            Is_First_Time_Fix__c = true,
            Notes__c = 'Calibration certificates issued and signed off by site manager.',
            Source__c = 'Internal',
            SLA_Deadline__c = DateTime.now().addHours(4),
            SLA_Status__c = 'Green'
        )
    };
    insert newJobs;
    
    // Add SLA Event and CSAT for completed job
    insert new SLA_Event__c(
        Service_Job__c = newJobs[3].Id,
        Event_Type__c = 'Resolved',
        Event_Timestamp__c = DateTime.now().addHours(-2),
        SLA_Remaining_Hrs__c = 2.5,
        Notes__c = 'Completed within SLA with FTFR'
    );
    insert new CSAT__c(
        Service_Job__c = newJobs[3].Id,
        Rating__c = 5,
        Comment__c = 'Excellent responsiveness and deep technical knowledge of Cummins systems.',
        Is_Responded__c = true,
        Response_Date__c = DateTime.now().addHours(-1),
        Customer_Mobile__c = '+919876543210'
    );
}
System.debug('Service Jobs ready');

System.debug('=== DIGIFIELD360 MASTER SEED DATA COMPLETE! ===');
