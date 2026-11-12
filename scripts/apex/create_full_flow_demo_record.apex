// Apex Script to create a complete End-to-End Field Service Record Flow
// Case -> Work Order (Multi-Asset WOLIs) -> Service Appointment -> Pause Log -> Parts Request -> Schedule -> History

Id accountId = '001g500000NAm6DAAT'; // Burlington Textiles Corp of America
Id techRecordId = 'a02g500000Bvf9mAAB'; // Piyush Channe (Technician__c)
Id primaryAssetId = 'a0Cg500000dWXaJEAW'; // Cummins QSK23 Generator
Id secondaryAssetId = 'a0Cg500000ins7yEAA'; // Carrier 30XA-300 Chiller
Id partId = 'a08g500000C6EHYAA3'; // PRT-00010 Control Valve Kit

// 1. Find or create Contact
Contact con;
List<Contact> cons = [SELECT Id FROM Contact WHERE AccountId = :accountId LIMIT 1];
if (!cons.isEmpty()) {
    con = cons[0];
} else {
    con = new Contact(
        FirstName = 'Rajesh',
        LastName = 'Sharma',
        Email = 'r.sharma@burlingtontextiles.com',
        Phone = '+91 98220 19844',
        Title = 'Chief Operations Engineer',
        AccountId = accountId
    );
    insert con;
}

// 2. Create Case (Originating Customer Issue)
Case cs = new Case(
    AccountId = accountId,
    ContactId = con.Id,
    Subject = 'Critical Overheat (104°C) & Excessive Vibration on Cummins 750kVA Backup Generator',
    Description = 'Customer reported high coolant temperature alarm (104°C) with excessive chassis vibration during peak textile plant production shift. Automatic emergency trip is imminent. Requires urgent emergency on-site diagnostic, cooling overhaul, and mount replacement.',
    Status = 'Working',
    Priority = 'High',
    Origin = 'WhatsApp'
);
insert cs;
cs = [SELECT Id, CaseNumber FROM Case WHERE Id = :cs.Id];
System.debug('>>> Created Case: ' + cs.CaseNumber + ' (Id: ' + cs.Id + ')');

// 3. Create Work Order (WHAT work needs to be done)
Work_Order__c wo = new Work_Order__c(
    Case__c = cs.Id,
    Account__c = accountId,
    Asset__c = primaryAssetId,
    Assigned_Technician__c = UserInfo.getUserId(),
    Subject__c = 'Emergency Thermal & Vibration Overhaul — Cummins 750kVA Generator',
    Description__c = 'Emergency diagnostic inspection, high-pressure radiator fin de-linting, heat exchanger flush, OEM thermostat valve replacement, and renewal of 4-point anti-vibration elastomer mounts across generator and chiller loop.',
    Status__c = 'Completed',
    Priority__c = 'Critical',
    Equipment_Type__c = 'Generator',
    Equipment_ID__c = 'CUM-750-MUM-001',
    Site_Address__c = 'Burlington Textiles Plant 4, Sector 7, Bhosari MIDC, Pune, Maharashtra 411026',
    Scheduled_Date__c = Date.today().addDays(-1),
    Completed_Date__c = Date.today(),
    Time_Logged_Minutes__c = 180,
    AI_Risk_Score__c = 92.5,
    AI_Assignment_Reason__c = 'Matched to Senior Field Engineer Piyush Channe: Level 4 Certified in Cummins PowerGen Heavy Diesel Systems, 98.4% First-Time-Fix Rate, and located within 4.2 km (Bhosari Zone).',
    Briefing_Generated__c = true,
    Report_Sent_To_Customer__c = true,
    Customer_Signature_URL__c = 'https://digifield360-signatures.s3.amazonaws.com/SIG-WO-BURLINGTON-750K.png',
    Total_Paused_Minutes__c = 45,
    Current_Pause_Reason__c = 'Waiting for Site Access',
    Current_Pause_Description__c = 'Awaiting site safety permit and electrical lockout-tagout (LOTO) clearance from Plant Operations Chief.',
    Current_Pause_Dependency__c = 'Plant Safety Manager signoff',
    Paused_Owner_Team__c = 'Operations',
    Paused_DateTime__c = Datetime.now().addHours(-4),
    Expected_Resume_Date__c = Date.today(),
    Last_Resume_DateTime__c = Datetime.now().addHours(-3).addMinutes(15),
    Last_Resume_Comments__c = 'Safety permit signed by Mr. Rajesh Sharma. Power safely isolated. Work resumed immediately.',
    Last_Synced__c = Datetime.now(),
    Offline_Queue_ID__c = 'SYNC-TX-90214-BURLINGTON',
    Technician_Notes__c = 'Inspected radiator intake; found heavy airborne textile lint clogging airflow. Flushed cooling core with solvent, replaced thermostat valve (PRT-00010), and replaced 4x heavy-duty elastomer vibration damper pads. Conducted 45-min full load bank test (600 kW): coolant stabilized at 82°C (nominal), vibration dropped from 8.2 mm/s to 0.6 mm/s. Generator certified 100% operational.',
    Parts_Used__c = 'PRT-00010 (Control Valve Kit 1x), DAMP-HEAVY-04 (Vibration Damper Kit 4x), CLNT-CONC-5L (Coolant 2x)'
);

// Formatted AI Pre-Job Briefing
wo.AI_Pre_Job_Briefing__c = 
    '==================================================\n' +
    'FIELD360 AI — PRE-JOB BRIEFING\n' +
    '==================================================\n' +
    'Customer        : Burlington Textiles Corp of America\n' +
    'Site Location   : Bhosari MIDC, Sector 7, Pune, MH 411026\n' +
    'Primary Asset   : Cummins QSK23 Diesel Generator (CUM-750-MUM-001)\n' +
    'Secondary Asset : Carrier 30XA-300 Auxiliary Chiller (SN-CAR-4421)\n' +
    'Reported Issue  : High coolant temperature (104°C) + severe mechanical vibration\n\n' +
    '1. SAFETY & HAZARD ALERTS:\n' +
    '• High thermal hazard: engine block and radiator fluid exceed 100°C.\n' +
    '• Mandatory electrical Lockout-Tagout (LOTO) permit required before opening grille.\n' +
    '• Required PPE: Heat-resistant gloves, ear protection (Class 3), safety goggles.\n\n' +
    '2. HISTORICAL CONTEXT:\n' +
    '• Asset last serviced 142 days ago (routine oil change).\n' +
    '• History of airborne textile lint fouling the air intake louvers.\n\n' +
    '3. RECOMMENDED ACTION PLAN:\n' +
    '• Verify electrical isolation with plant safety manager.\n' +
    '• Check coolant level and inspect thermostat valve seat for mineral scaling.\n' +
    '• Pneumatically clean radiator fins.\n' +
    '• Inspect 4-point engine isolation elastomer mounts for rubber shearing.\n\n' +
    '4. REQUIRED TOOLS & SPARES:\n' +
    '• Replacement Thermostat Valve (PRT-00010)\n' +
    '• Heavy-duty Damper Pad Kit (4x)\n' +
    '• Digital vibration meter & infrared thermal gun\n' +
    '==================================================';

insert wo;
wo = [SELECT Id, Name FROM Work_Order__c WHERE Id = :wo.Id];
System.debug('>>> Created Work Order: ' + wo.Name + ' (Id: ' + wo.Id + ')');

// Now update with generated AI Service Report referencing real numbers
wo.AI_Service_Report__c = 
    '==================================================\n' +
    'DIGIFIELD 360 SERVICE REPORT — VERIFIED PASS\n' +
    '==================================================\n' +
    'Work Order Reference : ' + wo.Name + '\n' +
    'Related Case         : ' + cs.CaseNumber + '\n' +
    'Customer / Account   : Burlington Textiles Corp of America\n' +
    'Site Address         : Sector 7, Bhosari MIDC, Pune, MH 411026\n' +
    'Contact Person       : Mr. Rajesh Sharma (Chief Operations Engineer)\n' +
    'Primary Equipment    : Cummins QSK23 Generator (CUM-750-MUM-001)\n' +
    'Secondary Equipment  : Carrier 30XA-300 Chiller (SN-CAR-4421)\n' +
    'Assigned Specialist  : Piyush Channe (Senior Field Engineer)\n' +
    'Completion Date      : ' + String.valueOf(Date.today()) + '\n' +
    'Total Labor Time     : 180 Minutes (3.0 Hours)\n' +
    'Pause Duration       : 45 Minutes (Site Access & LOTO Permit)\n' +
    '--------------------------------------------------\n' +
    'DIAGNOSIS & ROOT CAUSE:\n' +
    'Airborne textile lint from weaving mill clogged radiator intake louvers, causing thermal heat soak. Engine reached 104°C under 70% load. Excessive vibration was caused by a ruptured rear elastomer mounting pad.\n\n' +
    'WORK PERFORMED & RESOLUTION:\n' +
    '1. Secured LOTO electrical isolation permit with plant management.\n' +
    '2. High-pressure pneumatic cleaning of radiator intake core and heat exchanger.\n' +
    '3. Installed new OEM thermostat valve kit (PRT-00010).\n' +
    '4. Replaced all 4 engine isolator mounts with heavy-duty vibration damper kit.\n' +
    '5. Re-torqued all mounting bolts to 320 Nm factory specification.\n' +
    '6. Executed 45-minute continuous 600 kW load test:\n' +
    '   - Coolant Temperature : 82°C (Optimal Specification: 80°C - 85°C)\n' +
    '   - Vibration Amplitude : 0.6 mm/s (Down from 8.2 mm/s — 92% Reduction)\n\n' +
    'PARTS & MATERIALS CONSUMED:\n' +
    '• PRT-00010 : Control Valve & Thermostat Kit (Qty: 1)\n' +
    '• DAMP-04   : Heavy-Duty Elastomer Damper Kit (Qty: 4)\n' +
    '• CLNT-5L   : Glycol Coolant Concentrate (Qty: 2)\n\n' +
    'FINAL STATUS: COMPLETED & OPERATIONAL (PASS)\n' +
    'Customer Sign-off: Rajesh Sharma (Plant Head)\n' +
    'Specialist Sign-off: Piyush Channe\n' +
    '==================================================';
update wo;

// 4. Create Multi-Asset Work Order Line Items (WOLIs)
Work_Order_Line_Item__c woli1 = new Work_Order_Line_Item__c(
    Work_Order__c = wo.Id,
    Asset__c = primaryAssetId,
    Sequence__c = 1,
    Status__c = 'Completed',
    Description__c = 'Primary Generator Scope: De-lint radiator core, flush coolant circuit, replace thermostat valve, and calibrate temperature probe.',
    Is_First_Time_Fix__c = true,
    Parts_Used__c = 'PRT-00010 (1x), CLNT-CONC-5L (2x)',
    Resolution_Notes__c = 'Thermostat replaced and thermal sensors recalibrated. Operating temperature steady at 82°C under full load.'
);
insert woli1;

Work_Order_Line_Item__c woli2 = new Work_Order_Line_Item__c(
    Work_Order__c = wo.Id,
    Asset__c = secondaryAssetId,
    Sequence__c = 2,
    Status__c = 'Completed',
    Description__c = 'Auxiliary Cooling Loop Scope: Inspect chiller circulation loop, replace worn isolator mounts, and balance vibration dampening.',
    Is_First_Time_Fix__c = true,
    Parts_Used__c = 'DAMP-HEAVY-04 (4x)',
    Resolution_Notes__c = 'All 4 isolator dampers replaced. Vibration amplitude reduced by 92% (0.6 mm/s).'
);
insert woli2;
System.debug('>>> Created 2 Work Order Line Items for Multi-Asset Scope.');

// 5. Create Service Appointment (Service_Job__c — WHEN, WHERE, WHO)
Service_Job__c sa = new Service_Job__c(
    Work_Order__c = wo.Id,
    Case__c = cs.Id,
    Account__c = accountId,
    Asset__c = primaryAssetId,
    Technician__c = techRecordId,
    Status__c = 'Completed',
    Job_Type__c = 'Emergency',
    Priority__c = 'Critical',
    Product_Category__c = 'Generator',
    Source__c = 'WhatsApp',
    SLA_Deadline__c = Datetime.now().addHours(2),
    SLA_Status__c = 'Green',
    Check_In_Time__c = Datetime.now().addHours(-3).addMinutes(15),
    Completed_Time__c = Datetime.now().addMinutes(-15),
    Resolution_Time_Min__c = 180,
    Check_In_GPS__Latitude__s = 18.6279,
    Check_In_GPS__Longitude__s = 73.8344,
    Customer_Signature_URL__c = 'https://digifield360-signatures.s3.amazonaws.com/SIG-SA-BURLINGTON.png',
    Is_First_Time_Fix__c = true,
    Notes__c = 'Emergency breakdown overhaul executed. Generator and chiller operating in perfect synchronization.',
    Customer_Notes__c = 'Outstanding response time and resolution. Avoided whole textile mill shutdown.',
    CSAT_Sent__c = true
);
insert sa;
sa = [SELECT Id, Name FROM Service_Job__c WHERE Id = :sa.Id];
System.debug('>>> Created Service Appointment: ' + sa.Name + ' (Id: ' + sa.Id + ')');

// 6. Create Pause Log (Tracking Downtime & Reasons)
Work_Order_Pause_Log__c pauseLog = new Work_Order_Pause_Log__c(
    Work_Order__c = wo.Id,
    Pause_Reason__c = 'Waiting for Site Access',
    Description__c = 'Waiting for Plant Safety Chief to conduct electrical lockout-tagout (LOTO) audit and issue formal hot-work permit.',
    Dependency__c = 'Plant Safety Manager signoff',
    Responsible_Team__c = 'Operations',
    Paused_At__c = Datetime.now().addHours(-4),
    Resumed_At__c = Datetime.now().addHours(-3).addMinutes(15),
    Duration_Minutes__c = 45,
    Expected_Resume_Date__c = Date.today(),
    Resume_Comments__c = 'Permit issued by Mr. Rajesh Sharma. Lockout completed safely. Work resumed.'
);
insert pauseLog;

// 7. Create Parts Request (Inventory & Procurement Tracking)
Parts_Request__c pr = new Parts_Request__c(
    Work_Order__c = wo.Id,
    Service_Job__c = sa.Id,
    Part__c = partId,
    Technician__c = techRecordId,
    Quantity__c = 1,
    Status__c = 'Consumed',
    Is_Warranty__c = true,
    Approved_At__c = Datetime.now().addHours(-3),
    Dispatched_At__c = Datetime.now().addHours(-2).addMinutes(-45),
    Delivered_At__c = Datetime.now().addHours(-2).addMinutes(-30)
);
insert pr;

// 8. Create Job Schedule (Calendar & Dispatch Integration)
Job_Schedule__c sched = new Job_Schedule__c(
    Work_Order__c = wo.Id,
    Technician__c = UserInfo.getUserId(),
    Scheduled_Date__c = Date.today(),
    Start_Time__c = Time.newInstance(9, 0, 0, 0),
    End_Time__c = Time.newInstance(12, 0, 0, 0),
    Duration_Hours__c = 3,
    Status__c = 'Completed',
    Priority__c = 'Critical',
    Notes__c = 'Emergency Priority 1 Generator & Chiller Breakdown Visit.'
);
insert sched;

// 9. Create Job History (AI Analytics, Failure Patterns & Learning)
Job_History__c hist = new Job_History__c(
    Work_Order__c = wo.Id,
    Account__c = accountId,
    Technician__c = UserInfo.getUserId(),
    Equipment_ID__c = 'CUM-750-MUM-001',
    Equipment_Type__c = 'Diesel Generator 750kVA',
    Fault_Description__c = 'High engine temperature alarm (104°C) with severe vibration.',
    Root_Cause__c = 'Textile lint clogging radiator core combined with sheared elastomer motor mount.',
    Resolution__c = 'Radiator de-linting and flush, replacement of thermostat valve (PRT-00010), renewal of 4-point vibration dampener assembly.',
    First_Time_Fix__c = true,
    Duration_Minutes__c = 180,
    Customer_Satisfaction__c = 5,
    AI_Used__c = true,
    Parts_Used__c = 'PRT-00010 (1x), DAMP-HEAVY-04 (4x), CLNT-CONC-5L (2x)',
    Job_Date__c = Date.today()
);
insert hist;

System.debug('========================================================');
System.debug('FULL FLOW RECORD CREATED SUCCESSFULLY:');
System.debug('CASE ID                 : ' + cs.Id + ' (' + cs.CaseNumber + ')');
System.debug('WORK ORDER ID           : ' + wo.Id + ' (' + wo.Name + ')');
System.debug('SERVICE APPOINTMENT ID  : ' + sa.Id + ' (' + sa.Name + ')');
System.debug('========================================================');
