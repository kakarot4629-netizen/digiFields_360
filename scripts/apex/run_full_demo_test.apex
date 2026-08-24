// Clean Start-to-Finish End-to-End Test Lifecycle Script
System.debug('=== STARTING FULL DIGIFIELD 360 DEMO TEST ===');

// 1. Create fresh Work Order (Status = New)
Work_Order__c wo = new Work_Order__c(
    Subject__c = 'Fresh Test: HVAC Cooling Outage - Bay 4',
    Equipment_ID__c = 'HVAC-100',
    Equipment_Type__c = 'HVAC',
    Status__c = 'New',
    Priority__c = 'High',
    Account__c = [SELECT Id FROM Account WHERE Name = 'Tata Motors Test' LIMIT 1].Id,
    Description__c = 'Blower fan error code E-42. High compressor head pressure.',
    Site_Address__c = 'Tata Motors Plant 2, Bhosari MIDC, Pune'
);
insert wo;
System.debug('STEP 1 COMPLETE: Work Order Created (ID: ' + wo.Id + ')');

// 2. Assign Technician & Set Status to Assigned (Triggers Pre-Job Briefing)
wo.Assigned_Technician__c = UserInfo.getUserId();
wo.Status__c = 'Assigned';
update wo;

F360_PreJobBriefingAction.BriefingRequest briefReq = new F360_PreJobBriefingAction.BriefingRequest();
briefReq.workOrderId = wo.Id;
briefReq.languageCode = 'hi';
F360_PreJobBriefingAction.generateBriefing(new List<F360_PreJobBriefingAction.BriefingRequest>{briefReq});

System.debug('STEP 2 COMPLETE: Pre-Job Briefing Generated for Work Order ' + wo.Id);

// 3. Log Repair & Set Status to Completed (Triggers Service Report & File Creation)
wo.Technician_Notes__c = 'Diagnosed E-42 fault. Cleared intake filter obstruction, replaced expansion valve EV-410, and recharged R-410A gas canister. System tested stable at 15°C output.';
wo.Parts_Used__c = 'Expansion Valve EV-410, R-410A Refrigerant 3kg';
wo.Time_Logged_Minutes__c = 75;
wo.Status__c = 'Completed';
update wo;

F360_ServiceReportAction.ReportRequest repReq = new F360_ServiceReportAction.ReportRequest();
repReq.workOrderId = wo.Id;
repReq.sendToCustomer = false;
F360_ServiceReportAction.generateReport(new List<F360_ServiceReportAction.ReportRequest>{repReq});

System.debug('STEP 3 COMPLETE: Service Report & Attachment Created for Work Order ' + wo.Id);

// 4. Run Predictive Maintenance Engine
F360_PredictiveMaintenanceAction.MaintenanceRequest pmReq = new F360_PredictiveMaintenanceAction.MaintenanceRequest();
pmReq.lookBackDays = 90;
pmReq.riskThreshold = 65;
F360_PredictiveMaintenanceAction.analyseEquipment(new List<F360_PredictiveMaintenanceAction.MaintenanceRequest>{pmReq});

System.debug('STEP 4 COMPLETE: Predictive Maintenance Analysis Executed.');
System.debug('=== ALL STEPS SUCCESSFUL! FRESH WORK ORDER ID: ' + wo.Id + ' ===');
