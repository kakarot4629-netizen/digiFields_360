@isTest
private class DF360_WorkOrderEnhancementsTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Serum BioTech Campus', BillingCity = 'Pune');
        insert acc;

        Asset__c asset = new Asset__c(
            Product_Name__c = 'Cummins DG-250',
            Serial_Number__c = 'SN-CUM-8899',
            Model__c = 'QSK60-G4',
            Manufacturer__c = 'Cummins',
            Product_Category__c = 'Generator',
            Account__c = acc.Id,
            Install_Date__c = Date.today().addYears(-1),
            Warranty_Expiry__c = Date.today().addYears(2),
            Location_Address__c = 'Building 4, Serum BioTech Campus'
        );
        insert asset;

        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'Quarterly Maintenance and Vibration Check',
            Account__c = acc.Id,
            Priority__c = 'High',
            Status__c = 'In Progress',
            Equipment_Type__c = 'Generator',
            Equipment_ID__c = 'SN-CUM-8899',
            Asset__c = asset.Id
        );
        insert wo;

        Part__c p1 = new Part__c(
            Part_Code__c = 'CV-KIT-01',
            Category__c = 'Generator',
            Unit_Cost__c = 3500,
            Is_Warranty_Item__c = true,
            Is_Active__c = true,
            Compatible_Products__c = 'QSK60-G4, QSK60'
        );
        Part__c p2 = new Part__c(
            Part_Code__c = 'TURBO-900',
            Category__c = 'Generator',
            Unit_Cost__c = 15000,
            Is_Warranty_Item__c = false,
            Is_Active__c = true
        );
        insert new List<Part__c>{ p1, p2 };
    }

    @isTest
    static void testAssetAssociationAnd360Details() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        Asset__c asset = [SELECT Id FROM Asset__c LIMIT 1];

        Test.startTest();
        Map<String, Object> assocResult = DF360_WorkOrderAssetController.associateAsset(wo.Id, asset.Id);
        System.assertNotEquals(null, assocResult);
        System.assertEquals(true, assocResult.get('success'));

        Map<String, Object> details = DF360_WorkOrderAssetController.getAsset360Details(asset.Id, wo.Id);
        System.assertNotEquals(null, details.get('asset'));

        List<Asset__c> searchResults = DF360_WorkOrderAssetController.searchAssets('Cummins', null);
        System.assert(searchResults.size() > 0);
        Test.stopTest();
    }

    @isTest
    static void testPauseAndResumeWorkOrder() {
        Work_Order__c wo = [SELECT Id, Status__c FROM Work_Order__c LIMIT 1];

        Test.startTest();
        // 1. Pause
        Map<String, Object> pauseRes = DF360_WorkOrderPauseController.pauseWorkOrder(
            wo.Id,
            'Waiting for Part',
            'Awaiting CV-KIT-01 from depot',
            'PR-001',
            Datetime.now().addDays(1),
            'Procurement'
        );
        System.assertEquals(true, pauseRes.get('success'));

        Work_Order__c updatedWo = [SELECT Status__c, Current_Pause_Reason__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals('Temporarily Paused', updatedWo.Status__c);
        System.assertEquals('Waiting for Part', updatedWo.Current_Pause_Reason__c);

        // 2. Check Dashboard
        Map<String, Object> dashboard = DF360_WorkOrderPauseController.getPausedWorkOrdersDashboard();
        System.assert((Integer) dashboard.get('totalPaused') >= 1);

        // 3. Resume
        Map<String, Object> resumeRes = DF360_WorkOrderPauseController.resumeWorkOrder(
            wo.Id,
            'Part received on-site. Work resumed.'
        );
        System.assertEquals(true, resumeRes.get('success'));

        Work_Order__c resumedWo = [SELECT Status__c, Last_Resume_Comments__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals('In Progress', resumedWo.Status__c);
        System.assertEquals('Part received on-site. Work resumed.', resumedWo.Last_Resume_Comments__c);
        Test.stopTest();
    }

    @isTest
    static void testRelevantPartsAndFulfillment() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        Part__c autoPart = [SELECT Id FROM Part__c WHERE Part_Code__c = 'CV-KIT-01' LIMIT 1];
        Part__c approvalPart = [SELECT Id FROM Part__c WHERE Part_Code__c = 'TURBO-900' LIMIT 1];

        // Create Technician record for User and assign to Work Order
        Technician__c tech = new Technician__c(
            User__c = UserInfo.getUserId(),
            Employee_Code__c = 'EMP-999',
            Is_Active__c = true
        );
        insert tech;

        wo.Assigned_Technician__c = UserInfo.getUserId();
        update wo;

        Test.startTest();
        // 1. Get applicable parts filtered for Work Order
        Map<String, Object> applicable = DF360_PartsController.getApplicablePartsForWorkOrder(wo.Id, '');
        System.assertNotEquals(null, applicable.get('parts'));

        // 2. Auto-approved request with Assigned_Technician__c set to User
        Id reqId1 = DF360_PartsController.raisePartsRequestForWorkOrder(wo.Id, autoPart.Id, 1);
        Parts_Request__c pr1 = [SELECT Status__c, Technician__c FROM Parts_Request__c WHERE Id = :reqId1];
        System.assertEquals('Approved', pr1.Status__c);
        System.assertEquals(tech.Id, pr1.Technician__c, 'Technician__c custom object lookup must be resolved from User ID');

        // 3. High-value request needing approval
        Id reqId2 = DF360_PartsController.raisePartsRequestForWorkOrder(wo.Id, approvalPart.Id, 1);
        Parts_Request__c pr2 = [SELECT Status__c FROM Parts_Request__c WHERE Id = :reqId2];
        System.assertEquals('Pending Approval', pr2.Status__c);

        // 4. Issue and Consume
        DF360_PartsController.issuePart(reqId1);
        Parts_Request__c prIssued = [SELECT Status__c FROM Parts_Request__c WHERE Id = :reqId1];
        System.assertEquals('Part Issued', prIssued.Status__c);

        DF360_PartsController.consumePart(reqId1, wo.Id);
        Parts_Request__c prConsumed = [SELECT Status__c FROM Parts_Request__c WHERE Id = :reqId1];
        System.assertEquals('Consumed', prConsumed.Status__c);

        // 5. Test Return Part
        Id reqId3 = DF360_PartsController.raisePartsRequestForWorkOrder(wo.Id, autoPart.Id, 1);
        DF360_PartsController.issuePart(reqId3);
        DF360_PartsController.returnPart(reqId3, 'Unused item');
        Parts_Request__c prReturned = [SELECT Status__c FROM Parts_Request__c WHERE Id = :reqId3];
        System.assertEquals('Returned', prReturned.Status__c);

        // 6. Work Order Requests
        List<Map<String, Object>> woReqs = DF360_PartsController.getWorkOrderPartsRequests(wo.Id);
        System.assert(woReqs.size() > 0);
        Test.stopTest();
    }

    @isTest
    static void testGuruAIDynamicResponse() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        String jsonReply1 = DF360_GuruAIController.askGuruAI(null, wo.Id, 'Water pump leaking coolant');
        System.assert(jsonReply1.contains('actionableSteps'));
        System.assert(jsonReply1.contains('recommendedParts'));

        String jsonReply2 = DF360_GuruAIController.askGuruAI(null, wo.Id, 'Error E-401 chiller high pressure');
        System.assert(jsonReply2.contains('safetyPrecautions'));
        System.assert(jsonReply2.contains('actionableSteps'));
        Test.stopTest();
    }

    @isTest
    static void testAssetAwarePreJobBriefing() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        F360_PreJobBriefingAction.BriefingRequest req = new F360_PreJobBriefingAction.BriefingRequest();
        req.workOrderId = wo.Id;
        req.languageCode = 'en';

        List<F360_PreJobBriefingAction.BriefingResult> results = F360_PreJobBriefingAction.generateBriefing(
            new List<F360_PreJobBriefingAction.BriefingRequest>{ req }
        );
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assert(String.isNotBlank(results[0].briefingText));
        Test.stopTest();
    }

    @isTest
    static void testAssetHistoryInvocableAction() {
        Work_Order__c wo = [SELECT Id, Asset__c FROM Work_Order__c LIMIT 1];
        Asset__c ast = [SELECT Id, Serial_Number__c FROM Asset__c LIMIT 1];

        Test.startTest();
        DF360_AssetHistoryInvocableAction.AssetHistoryRequest req1 = new DF360_AssetHistoryInvocableAction.AssetHistoryRequest();
        req1.workOrderId = wo.Id;
        List<DF360_AssetHistoryInvocableAction.AssetHistoryResult> res1 = DF360_AssetHistoryInvocableAction.queryAssetHistory(
            new List<DF360_AssetHistoryInvocableAction.AssetHistoryRequest>{ req1 }
        );
        System.assertEquals(1, res1.size());
        System.assertEquals(true, res1[0].success);
        System.assertNotEquals(null, res1[0].assetSummary);

        DF360_AssetHistoryInvocableAction.AssetHistoryRequest req2 = new DF360_AssetHistoryInvocableAction.AssetHistoryRequest();
        req2.serialNumber = ast.Serial_Number__c;
        List<DF360_AssetHistoryInvocableAction.AssetHistoryResult> res2 = DF360_AssetHistoryInvocableAction.queryAssetHistory(
            new List<DF360_AssetHistoryInvocableAction.AssetHistoryRequest>{ req2 }
        );
        System.assertEquals(1, res2.size());
        System.assertEquals(true, res2[0].success);
        Test.stopTest();
    }

    @isTest
    static void testPauseInvocableAction() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        // 1. Pause action
        DF360_WorkOrderPauseInvocableAction.PauseRequest pReq = new DF360_WorkOrderPauseInvocableAction.PauseRequest();
        pReq.actionType = 'PAUSE';
        pReq.workOrderId = wo.Id;
        pReq.reason = 'Waiting for Part';
        pReq.description = 'Need replacement filter';
        pReq.dependency = 'PR-001';
        pReq.responsibleTeam = 'Procurement';

        List<DF360_WorkOrderPauseInvocableAction.PauseResult> pRes = DF360_WorkOrderPauseInvocableAction.managePause(
            new List<DF360_WorkOrderPauseInvocableAction.PauseRequest>{ pReq }
        );
        System.assertEquals(1, pRes.size());
        System.assertEquals(true, pRes[0].success);
        System.assertEquals(true, pRes[0].isPaused);

        // 2. Summary action
        DF360_WorkOrderPauseInvocableAction.PauseRequest sReq = new DF360_WorkOrderPauseInvocableAction.PauseRequest();
        sReq.actionType = 'GET_PAUSED_SUMMARY';
        List<DF360_WorkOrderPauseInvocableAction.PauseResult> sRes = DF360_WorkOrderPauseInvocableAction.managePause(
            new List<DF360_WorkOrderPauseInvocableAction.PauseRequest>{ sReq }
        );
        System.assertEquals(1, sRes.size());
        System.assertEquals(true, sRes[0].success);
        System.assert(sRes[0].totalPausedCount >= 1);

        // 3. Resume action
        DF360_WorkOrderPauseInvocableAction.PauseRequest rReq = new DF360_WorkOrderPauseInvocableAction.PauseRequest();
        rReq.actionType = 'RESUME';
        rReq.workOrderId = wo.Id;
        rReq.resumeComments = 'Part received from depot';

        List<DF360_WorkOrderPauseInvocableAction.PauseResult> rRes = DF360_WorkOrderPauseInvocableAction.managePause(
            new List<DF360_WorkOrderPauseInvocableAction.PauseRequest>{ rReq }
        );
        System.assertEquals(1, rRes.size());
        System.assertEquals(true, rRes[0].success);
        System.assertEquals(false, rRes[0].isPaused);
        Test.stopTest();
    }

    @isTest
    static void testMultiAssetLineItemsAndCaseIntegration() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Asset__c a1 = [SELECT Id FROM Asset__c LIMIT 1];
        
        // Create second asset
        Asset__c a2 = new Asset__c(
            Product_Name__c = 'Cummins DG-100 Backup',
            Serial_Number__c = 'SN-CUM-1002',
            Model__c = 'QSK38',
            Manufacturer__c = 'Cummins',
            Product_Category__c = 'Generator',
            Account__c = acc.Id
        );
        insert a2;

        // Create standard Case
        Case cs = new Case(
            Subject = 'Multiple generators vibrating during load spike',
            AccountId = acc.Id,
            Priority = 'High',
            Status = 'New'
        );
        insert cs;

        // Create Work Order linked to Case
        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'Site Generator Inspection & Servicing',
            Account__c = acc.Id,
            Case__c = cs.Id,
            Status__c = 'New',
            Priority__c = 'High'
        );
        insert wo;

        Test.startTest();
        // Add multiple assets as line items
        Work_Order_Line_Item__c item1 = DF360_WorkOrderAssetController.addLineItem(wo.Id, a1.Id, 'Check vibration dampers', 1);
        Work_Order_Line_Item__c item2 = DF360_WorkOrderAssetController.addLineItem(wo.Id, a2.Id, 'Inspect fuel injector pump', 2);
        System.assertNotEquals(null, item1.Id);
        System.assertNotEquals(null, item2.Id);

        // Fetch line items
        List<Work_Order_Line_Item__c> items = DF360_WorkOrderAssetController.getWorkOrderLineItems(wo.Id);
        System.assertEquals(2, items.size());

        // Update line item status
        DF360_WorkOrderAssetController.updateLineItemStatus(item1.Id, 'Completed', 'Replaced dampers', true, 'DAMP-KIT-01');

        // Create Service Job linked to Work Order and Case
        Id jobId = DF360_ServiceJobController.createJobWithParent(
            acc.Id, a1.Id, 'Repair', 'High', 'Vibration check', 'Generator', wo.Id, cs.Id
        );
        System.assertNotEquals(null, jobId);

        // Verify Job Detail
        Service_Job__c job = DF360_ServiceJobController.getJobDetail(jobId);
        System.assertEquals(wo.Id, job.Work_Order__c);
        System.assertEquals(cs.Id, job.Case__c);

        // Complete Job and verify parent cascade
        DF360_ServiceJobController.completeJob(jobId, true, 'https://test.signature.url/sig.png');
        Work_Order__c updatedWo = [SELECT Status__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals('Completed', updatedWo.Status__c);

        Case updatedCase = [SELECT Status FROM Case WHERE Id = :cs.Id];
        System.assertEquals('Closed', updatedCase.Status);
        Test.stopTest();
    }

    @isTest
    static void testCustomerAddressAndAssetAssessment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Asset__c a1 = [SELECT Id FROM Asset__c LIMIT 1];

        // 1. Create and test Customer Address
        Customer_Address__c custAddr = new Customer_Address__c(
            Account__c = acc.Id,
            Address_Type__c = 'Home',
            Street_Address__c = 'Flat 402, Greenfield Residences, MG Road',
            Landmark__c = 'Opposite Metro Pillar 114',
            City__c = 'Pune',
            State__c = 'Maharashtra',
            Postal_Code__c = '411001',
            Country__c = 'India',
            Contact_Person_Name__c = 'Dr. Rajesh Sharma',
            Contact_Phone__c = '9876543210',
            Is_Default__c = true
        );
        insert custAddr;
        System.assertNotEquals(null, custAddr.Id);

        // 2. Link Customer Address to Case
        Case cs = new Case(
            Subject = 'Refrigerator not cooling at Home',
            AccountId = acc.Id,
            Customer_Address__c = custAddr.Id,
            Priority = 'Medium',
            Status = 'New'
        );
        insert cs;

        Case queriedCase = [SELECT Id, Customer_Address__c, Customer_Address__r.Address_Type__c FROM Case WHERE Id = :cs.Id];
        System.assertEquals(custAddr.Id, queriedCase.Customer_Address__c);
        System.assertEquals('Home', queriedCase.Customer_Address__r.Address_Type__c);

        // 3. Create Work Order and Line Item
        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'Appliance Repair & Diagnosis',
            Account__c = acc.Id,
            Case__c = cs.Id,
            Status__c = 'In Progress'
        );
        insert wo;

        Work_Order_Line_Item__c item = DF360_WorkOrderAssetController.addLineItem(wo.Id, a1.Id, 'Check refrigerator compressor', 1);

        Test.startTest();
        // 4. Test Assessment Feedback
        DF360_WorkOrderAssetController.saveAssetAssessment(
            item.Id,
            'Not Working / Defective',
            'Fridge compressor is faulty and not cooling. Fan motor operational.',
            'Poor'
        );

        // 5. Test Photo URLs
        DF360_WorkOrderAssetController.saveAssetPhotos(
            item.Id,
            'https://example.com/photos/pre_service.jpg',
            'https://example.com/photos/post_service.jpg'
        );

        // 6. Test File Upload linking
        ContentVersion cv = new ContentVersion(
            Title = 'Pre-Service Diagnostic Photo',
            PathOnClient = 'pre_service.jpg',
            VersionData = Blob.valueOf('Dummy pre-service image content')
        );
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Map<String, Object> linkRes = DF360_WorkOrderAssetController.linkPhotoDocument(item.Id, contentDocId, 'PRE');
        System.assertEquals(true, linkRes.get('success'));

        // 7. Verify line item query returns assessment, warranty and photos
        List<Work_Order_Line_Item__c> items = DF360_WorkOrderAssetController.getWorkOrderLineItems(wo.Id);
        System.assertEquals(1, items.size());
        System.assertEquals('Not Working / Defective', items[0].Operational_Status__c);
        System.assertEquals('Poor', items[0].Asset_Condition__c);
        System.assert(items[0].Technician_Feedback__c.contains('Fridge compressor is faulty'));
        System.assertNotEquals(null, items[0].Pre_Service_Photo_Id__c);
        Test.stopTest();
    }

    @isTest
    static void testAssetFeedbackThreeWayAssociation() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Asset__c a1 = [SELECT Id FROM Asset__c LIMIT 1];

        // 1. Create Case
        Case cs = new Case(
            Subject = 'Turbine Vibration Alarm Triggered',
            AccountId = acc.Id,
            Priority = 'High',
            Status = 'New'
        );
        insert cs;

        // 2. Create Work Order linked to Case & Asset
        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'Emergency Inspection & Diagnosis',
            Account__c = acc.Id,
            Case__c = cs.Id,
            Asset__c = a1.Id,
            Status__c = 'In Progress'
        );
        insert wo;

        // 3. Add Work Order Line Item
        Work_Order_Line_Item__c item = DF360_WorkOrderAssetController.addLineItem(
            wo.Id, a1.Id, 'Inspect turbine rotor alignment and vibration damper', 1
        );

        Test.startTest();

        // 4. Test auto-sync via saveAssetAssessment
        DF360_WorkOrderAssetController.saveAssetAssessment(
            item.Id,
            'Operational with Degradation',
            'Slight bearing play detected; requires realignment.',
            'Fair'
        );

        // Verify Asset_Feedback__c was auto-created and linked 3-ways
        List<Asset_Feedback__c> autoFeedbacks = [
            SELECT Id, Asset__c, Case__c, Work_Order__c, Work_Order_Line_Item__c,
                   Operational_Status__c, Asset_Condition__c, Feedback_Notes__c
            FROM Asset_Feedback__c
            WHERE Work_Order_Line_Item__c = :item.Id
        ];
        System.assertEquals(1, autoFeedbacks.size(), 'Asset_Feedback__c record should be auto-created');
        System.assertEquals(a1.Id, autoFeedbacks[0].Asset__c, 'Feedback must link to Asset__c');
        System.assertEquals(wo.Id, autoFeedbacks[0].Work_Order__c, 'Feedback must link to Work_Order__c');
        System.assertEquals(cs.Id, autoFeedbacks[0].Case__c, 'Feedback must link to Case parent of Work Order');
        System.assertEquals('Operational with Degradation', autoFeedbacks[0].Operational_Status__c);

        // 5. Test explicit creation via saveAssetFeedback
        Asset_Feedback__c explicitFeedback = DF360_WorkOrderAssetController.saveAssetFeedback(
            a1.Id,
            wo.Id,
            item.Id,
            'Breakdown Inspection',
            'Non-Operational / Broken',
            'Poor',
            2,
            'Bearing seizure identified during high-RPM cycle test.',
            'Procure replacement rotor bearing kit and schedule overhaul.',
            'https://example.com/pre_damage.jpg',
            'https://example.com/post_replace.jpg'
        );
        System.assertNotEquals(null, explicitFeedback.Id);
        System.assertEquals(a1.Id, explicitFeedback.Asset__c);
        System.assertEquals(wo.Id, explicitFeedback.Work_Order__c);
        System.assertEquals(cs.Id, explicitFeedback.Case__c);
        System.assertEquals(2, explicitFeedback.Rating__c);

        // 6. Test querying feedbacks by Asset, Work Order, Case, and Line Item
        List<Asset_Feedback__c> byAsset = DF360_WorkOrderAssetController.getAssetFeedbacks(a1.Id);
        System.assert(byAsset.size() >= 2, 'Should find feedbacks by Asset ID');

        List<Asset_Feedback__c> byWO = DF360_WorkOrderAssetController.getAssetFeedbacks(wo.Id);
        System.assert(byWO.size() >= 2, 'Should find feedbacks by Work Order ID');

        List<Asset_Feedback__c> byCase = DF360_WorkOrderAssetController.getAssetFeedbacks(cs.Id);
        System.assert(byCase.size() >= 2, 'Should find feedbacks by Case ID');

        List<Asset_Feedback__c> byItem = DF360_WorkOrderAssetController.getAssetFeedbacks(item.Id);
        System.assert(byItem.size() >= 2, 'Should find feedbacks by Line Item ID');

        // 7. Verify feedbacks appear in getAsset360Details
        Map<String, Object> details = DF360_WorkOrderAssetController.getAsset360Details(a1.Id, wo.Id);
        System.assertEquals(true, details.get('success'));
        List<Asset_Feedback__c> feedbacksIn360 = (List<Asset_Feedback__c>) details.get('assetFeedbacks');
        System.assertNotEquals(null, feedbacksIn360);
        System.assert(feedbacksIn360.size() >= 2);

        Test.stopTest();
    }
}

