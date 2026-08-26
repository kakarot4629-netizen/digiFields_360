// Create & Run End-to-End Test Automation for Technician Piyush Channe
System.debug('=== STARTING DIGIFIELD 360 AUTOMATION FOR PIYUSH CHANNE ===');

// 1. Update User to Piyush Channe
User u = [
    SELECT Id, FirstName, LastName, Preferred_Language__c, Skills__c, First_Time_Fix_Rate__c, Is_Active__c 
    FROM User 
    WHERE Id = :UserInfo.getUserId() 
    LIMIT 1
];
u.FirstName = 'Piyush';
u.LastName = 'Channe';
u.Preferred_Language__c = 'en';
u.Skills__c = 'Generator, HVAC, Compressor';
u.First_Time_Fix_Rate__c = 95.0;
u.Is_Active__c = true;
update u;
System.debug('STEP 1 COMPLETE: User profile updated to Piyush Channe (ID: ' + u.Id + ')');

// Check/Insert Technician__c record
List<Technician__c> techs = [SELECT Id, Name FROM Technician__c WHERE User__c = :u.Id LIMIT 1];
if (techs.isEmpty()) {
    Technician__c t = new Technician__c(
        Name = 'Piyush Channe',
        User__c = u.Id,
        Skills__c = 'Generator, HVAC, Compressor',
        First_Time_Fix_Rate__c = 95.0,
        Available_For_Assignment__c = true,
        Is_Active__c = true,
        Device_ID__c = 'DEV-PIYUSH-001'
    );
    insert t;
} else {
    Technician__c t = techs[0];
    t.Name = 'Piyush Channe';
    t.Skills__c = 'Generator, HVAC, Compressor';
    t.First_Time_Fix_Rate__c = 95.0;
    t.Available_For_Assignment__c = true;
    t.Is_Active__c = true;
    update t;
}

// 2. Create Account: Serum BioTech Campus
Account acc;
List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Serum BioTech Campus' LIMIT 1];
if (accs.isEmpty()) {
    acc = new Account(
        Name = 'Serum BioTech Campus',
        Industry = 'Biotechnology',
        AnnualRevenue = 150000000,
        BillingCity = 'Pune'
    );
    insert acc;
} else {
    acc = accs[0];
}
System.debug('STEP 2 COMPLETE: Account Serum BioTech Campus (ID: ' + acc.Id + ')');

// 3. Create Equipment: HVAC-100
Equipment__c equip;
List<Equipment__c> equips = [SELECT Id FROM Equipment__c WHERE Name = 'HVAC-100' LIMIT 1];
if (equips.isEmpty()) {
    equip = new Equipment__c(Name = 'HVAC-100');
    insert equip;
} else {
    equip = equips[0];
}
System.debug('STEP 3 COMPLETE: Equipment HVAC-100 (ID: ' + equip.Id + ')');

// 4. Create Job History
List<Job_History__c> histories = new List<Job_History__c>();
histories.add(new Job_History__c(
    Equipment_ID__c = 'HVAC-100',
    Equipment_Type__c = 'HVAC',
    Fault_Description__c = 'Low cooling efficiency, compressor overheating during peak load.',
    Resolution__c = 'Replaced compressor expansion valve and refilled R-410A refrigerant.',
    Parts_Used__c = 'Compressor Expansion Valve (EV-410), Refrigerant Gas 5kg',
    Duration_Minutes__c = 180,
    First_Time_Fix__c = true,
    Technician__c = u.Id,
    Account__c = acc.Id
));
Database.insert(histories, false);

// 5. Create Work Order
Work_Order__c wo = new Work_Order__c(
    Subject__c = 'HVAC Unit Overheating & High Compressor Pressure',
    Equipment_ID__c = 'HVAC-100',
    Equipment_Type__c = 'HVAC',
    Status__c = 'New',
    Priority__c = 'High',
    Account__c = acc.Id,
    Description__c = 'Blower fan error code E-42. High compressor head pressure under load.',
    Site_Address__c = 'Bhosari MIDC, Pune'
);
insert wo;
System.debug('STEP 5 COMPLETE: Work Order Created for Piyush Channe (ID: ' + wo.Id + ')');

// 6. Run Smart Assignment Action
F360_SmartAssignmentAction.AssignmentRequest req = new F360_SmartAssignmentAction.AssignmentRequest();
req.workOrderId = wo.Id;
req.maxResults = 3;
List<F360_SmartAssignmentAction.AssignmentResult> assignResults = F360_SmartAssignmentAction.recommend(new List<F360_SmartAssignmentAction.AssignmentRequest>{req});

wo.Assigned_Technician__c = u.Id;
wo.Status__c = 'Assigned';
update wo;
System.debug('STEP 6 COMPLETE: Technician Piyush Channe Assigned!');

// 7. Generate Pre-Job Briefing
F360_PreJobBriefingAction.BriefingRequest briefReq = new F360_PreJobBriefingAction.BriefingRequest();
briefReq.workOrderId = wo.Id;
briefReq.languageCode = 'en';
F360_PreJobBriefingAction.generateBriefing(new List<F360_PreJobBriefingAction.BriefingRequest>{briefReq});
System.debug('STEP 7 COMPLETE: Pre-Job Briefing Generated!');

// 8. Update to Completed & Generate Service Report
wo.Status__c = 'In Progress';
update wo;

wo.Technician_Notes__c = 'Diagnosed E-42 fault. Cleared intake filter obstruction, replaced expansion valve EV-410, and recharged R-410A gas.';
wo.Parts_Used__c = 'Expansion Valve EV-410, R-410A Refrigerant 3kg';
wo.Time_Logged_Minutes__c = 75;
wo.Status__c = 'Completed';
update wo;

F360_ServiceReportAction.ReportRequest repReq = new F360_ServiceReportAction.ReportRequest();
repReq.workOrderId = wo.Id;
repReq.sendToCustomer = false;
F360_ServiceReportAction.generateReport(new List<F360_ServiceReportAction.ReportRequest>{repReq});
System.debug('STEP 8 COMPLETE: Service Report & PDF Attachment Generated!');

// 9. Run Predictive Maintenance Engine
F360_PredictiveMaintenanceAction.MaintenanceRequest pmReq = new F360_PredictiveMaintenanceAction.MaintenanceRequest();
pmReq.lookBackDays = 90;
pmReq.riskThreshold = 50;
F360_PredictiveMaintenanceAction.analyseEquipment(new List<F360_PredictiveMaintenanceAction.MaintenanceRequest>{pmReq});
System.debug('STEP 9 COMPLETE: Predictive Maintenance Scan Finished!');

System.debug('=== SUCCESS! ALL AUTOMATION STEPS EXECUTED FOR PIYUSH CHANNE ===');
