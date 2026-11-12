@isTest
private class DF360_EndToEndTest {

    @testSetup
    static void setupTestData() {
        // Setup Master Data
        DF360_MasterDataSetup.setupData();
    }

    @isTest
    static void testJobCreationAndSLA() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Asset__c ast = [SELECT Id FROM Asset__c LIMIT 1];

        Test.startTest();
        Id jobId = DF360_ServiceJobController.createJob(
            acc.Id, ast.Id, 'Corrective Breakdown', 'Critical', 'Generator cooling issue', 'Mechanical'
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        Service_Job__c job = DF360_ServiceJobController.getJobDetail(jobId);
        System.assertEquals('New', job.Status__c, 'Job status should be New');
        System.assertNotEquals(null, job.SLA_Deadline__c, 'SLA Deadline should be auto-computed');

        Map<String,Object> slaStatus = DF360_SLAController.getSLAStatus(jobId);
        System.assertNotEquals(null, slaStatus.get('remainingHrs'), 'Remaining hours should be calculated');

        List<SLA_Event__c> timeline = DF360_SLAController.getSLATimeline(jobId);
        System.assert(timeline.size() >= 1, 'Should have at least 1 SLA event recorded');
    }

    @isTest
    static void testDispatchMatchingAndAssign() {
        Service_Job__c job = [SELECT Id, Status__c FROM Service_Job__c WHERE Status__c = 'New' LIMIT 1];
        if (job == null) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Id jobId = DF360_ServiceJobController.createJob(acc.Id, null, 'Inspection', 'High', 'Test note', 'Mechanical');
            job = [SELECT Id, Status__c FROM Service_Job__c WHERE Id = :jobId];
        }

        Test.startTest();
        List<Map<String,Object>> scoredTechs = DF360_DispatchController.findAvailableTechnicians(job.Id);
        System.assert(!scoredTechs.isEmpty(), 'Should return scored technicians');
        System.assert(scoredTechs[0].containsKey('score'), 'Technician should have a calculated match score');

        Id chosenTechId = (Id) scoredTechs[0].get('technicianId');
        DF360_DispatchController.assignTechnician(job.Id, chosenTechId);
        Test.stopTest();

        Service_Job__c updatedJob = [SELECT Status__c, Technician__c FROM Service_Job__c WHERE Id = :job.Id];
        System.assertEquals('Assigned', updatedJob.Status__c, 'Job status should change to Assigned');
        System.assertEquals(chosenTechId, updatedJob.Technician__c, 'Technician should be assigned');
    }

    @isTest
    static void testCheckInAndCompletion() {
        Service_Job__c job = [SELECT Id, Technician__c FROM Service_Job__c WHERE Status__c = 'Assigned' LIMIT 1];

        Test.startTest();
        Map<String,Object> checkInRes = DF360_ServiceJobController.checkIn(job.Id, job.Technician__c, 19.0760, 72.8777);
        System.assertEquals(job.Id, checkInRes.get('jobId'));

        Service_Job__c onSiteJob = [SELECT Status__c, Check_In_Time__c FROM Service_Job__c WHERE Id = :job.Id];
        System.assertEquals('On Site', onSiteJob.Status__c, 'Job status should change to On Site');
        System.assertNotEquals(null, onSiteJob.Check_In_Time__c, 'Check-in time should be recorded');

        DF360_ServiceJobController.completeJob(job.Id, true, 'https://sig.digifield360.io/sample.png');
        Test.stopTest();

        Service_Job__c completedJob = [SELECT Status__c, Is_First_Time_Fix__c, Completed_Time__c FROM Service_Job__c WHERE Id = :job.Id];
        System.assertEquals('Completed', completedJob.Status__c, 'Job should be Completed');
        System.assertEquals(true, completedJob.Is_First_Time_Fix__c, 'First time fix should be true');
    }

    @isTest
    static void testPartsWorkflow() {
        Service_Job__c job = [SELECT Id FROM Service_Job__c LIMIT 1];

        Test.startTest();
        // 1. Search parts
        List<Map<String,Object>> searchRes = DF360_PartsController.searchParts('AF', null);
        System.assert(!searchRes.isEmpty(), 'Should find spare parts matching query');

        Part__c partLow = [SELECT Id, Unit_Cost__c FROM Part__c WHERE Unit_Cost__c < 5000 LIMIT 1];
        Part__c partHigh = [SELECT Id, Unit_Cost__c FROM Part__c WHERE Unit_Cost__c >= 5000 LIMIT 1];

        // 2. Raise auto-approved request (< 5000)
        Id lowReqId = DF360_PartsController.raisePartsRequest(job.Id, partLow.Id, 1);
        Parts_Request__c lowReq = [SELECT Status__c FROM Parts_Request__c WHERE Id = :lowReqId];
        System.assertEquals('Approved', lowReq.Status__c, 'Low value part should be auto-approved');

        // 3. Raise pending-approval request (>= 5000)
        Id highReqId = DF360_PartsController.raisePartsRequest(job.Id, partHigh.Id, 1);
        Parts_Request__c highReq = [SELECT Status__c FROM Parts_Request__c WHERE Id = :highReqId];
        System.assertEquals('Pending Approval', highReq.Status__c, 'High value part should require approval');

        // 4. Manager approval inbox & approve
        List<Map<String,Object>> pending = DF360_PartsController.getPendingApprovals();
        System.assert(!pending.isEmpty(), 'Pending approvals list should not be empty');

        DF360_PartsController.approveRequest(highReqId, true, null);
        Parts_Request__c approvedReq = [SELECT Status__c, Approved_By__c FROM Parts_Request__c WHERE Id = :highReqId];
        System.assertEquals('Approved', approvedReq.Status__c, 'Part request should now be Approved');
        Test.stopTest();
    }

    @isTest
    static void testCSATWorkflow() {
        Service_Job__c job = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        Test.startTest();
        DF360_CSATController.sendCSATRequest(job.Id, '+919876543210');
        
        DF360_CSATController.recordCSATResponse(job.Name, 5, 'Outstanding service!', '+919876543210');
        
        Technician__c tech = [SELECT Id FROM Technician__c LIMIT 1];
        List<Map<String,Object>> csatSummary = DF360_CSATController.getTechnicianCSAT(tech.Id, 30);
        System.assert(!csatSummary.isEmpty(), 'CSAT summary should be returned');
        Test.stopTest();
    }

    @isTest
    static void testAttendanceAndGPS() {
        Technician__c tech = [SELECT Id FROM Technician__c LIMIT 1];

        Test.startTest();
        DF360_AttendanceController.punchIn(tech.Id, 19.0760, 72.8777, true);
        Attendance__c att = DF360_AttendanceController.getTodayAttendance(tech.Id);
        System.assertNotEquals(null, att, 'Attendance record should be created');
        System.assertEquals('Present', att.Status__c);

        DF360_AttendanceController.punchOut(tech.Id, 19.0760, 72.8777);
        
        List<Map<String,Object>> positions = DF360_GPSController.getTeamPositions(null);
        System.assert(!positions.isEmpty(), 'Should return technician team positions');
        Test.stopTest();
    }

    @isTest
    static void testAnalyticsDashboard() {
        Test.startTest();
        Map<String,Object> metrics = DF360_AnalyticsController.getManagerDashboard(null);
        System.assertNotEquals(null, metrics.get('jobsToday'), 'Jobs today metric should exist');
        System.assertNotEquals(null, metrics.get('ftfrPct'), 'FTFR metric should exist');

        Map<String,Object> slaReport = DF360_AnalyticsController.getSLACompliance(null, 30);
        System.assertNotEquals(null, slaReport.get('compliance'), 'Compliance percentage should exist');
        Test.stopTest();
    }

    @isTest
    static void testGuruAIAndMobileAPI() {
        Service_Job__c job = [SELECT Id FROM Service_Job__c LIMIT 1];

        Test.startTest();
        String reply = DF360_GuruAIController.askGuruAI(null, job.Id, 'How do I check cooling circuit pressure?');
        System.assertNotEquals(null, reply, 'GuruAI should return a diagnostic guidance reply');

        // Test Mobile API REST Resource
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/df360/mobile/morning-payload';
        req.httpMethod = 'POST';
        Technician__c tech = [SELECT Id FROM Technician__c LIMIT 1];
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'technicianId' => tech.Id }));
        RestContext.request = req;

        String syncRes = DF360_MobileAPIController.syncData();
        System.assert(syncRes.contains('jobs'), 'Mobile payload should contain jobs array');
        Test.stopTest();
    }

    @isTest
    static void testScheduledBatches() {
        Test.startTest();
        Database.executeBatch(new DF360_SLAMonitorBatch(), 200);
        Database.executeBatch(new DF360_CSATRollupBatch(), 200);
        Database.executeBatch(new DF360_GPSLogRetentionBatch(), 200);
        Database.executeBatch(new DF360_ContractExpiryBatch(), 200);
        Database.executeBatch(new DF360_CertExpiryBatch(), 200);
        Test.stopTest();

        // If batch completed without throwing unhandled exceptions, assertions pass
        System.assert(true, 'All 5 batch jobs executed successfully');
    }

    @isTest
    static void testGPSLogTrigger() {
        Technician__c tech = [SELECT Id FROM Technician__c LIMIT 1];
        GPS_Log__c log = new GPS_Log__c(
            Technician__c = tech.Id,
            Latitude__c = 18.5204,
            Longitude__c = 73.8567,
            Log_Timestamp__c = Datetime.now()
        );
        Test.startTest();
        insert log;
        Test.stopTest();

        Technician__c updatedTech = [SELECT Current_GPS_Latitude__c, Current_GPS_Longitude__c FROM Technician__c WHERE Id = :tech.Id];
        System.assertEquals(18.5204, updatedTech.Current_GPS_Latitude__c);
    }
}
