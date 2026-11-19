@IsTest
private class DF360_AppointmentLifecycleAPITest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Photo Customer');
        insert acc;

        Work_Order__c wo = new Work_Order__c(
            Name = 'WO-TEST-001',
            Subject__c = 'Test Check-In Work Order',
            Status__c = 'Assigned',
            Account__c = acc.Id
        );
        insert wo;

        Service_Job__c sa = new Service_Job__c(
            Work_Order__c = wo.Id,
            Account__c = acc.Id,
            Status__c = 'Assigned',
            Priority__c = 'High',
            Job_Type__c = 'Diagnostic',
            Scheduled_Start_Time__c = DateTime.now().addHours(1),
            Scheduled_End_Time__c = DateTime.now().addHours(3)
        );
        insert sa;

        // Insert Work Order Line Item
        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Work_Order__c = wo.Id,
            Description__c = 'Test line item',
            Status__c = 'New'
        );
        insert woli;
    }

    @IsTest
    static void testCheckInSuccess() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/check-in';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'latitude' => 19.1196,
            'longitude' => 72.8823,
            'status' => 'In Progress'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, respMap.get('success'));

        Service_Job__c updatedSa = [SELECT Status__c, Check_In_Time__c, Check_In_GPS__Latitude__s FROM Service_Job__c WHERE Id = :sa.Id];
        System.assertEquals('In Progress', updatedSa.Status__c);
        System.assertNotEquals(null, updatedSa.Check_In_Time__c);
    }

    @IsTest
    static void testUploadBeforeAndAfterPhotos() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];
        Work_Order_Line_Item__c woli = [SELECT Id FROM Work_Order_Line_Item__c LIMIT 1];

        // 1. Upload Before Photo via Base64
        String mockBase64 = EncodingUtil.base64Encode(Blob.valueOf('Mock image content before overhaul'));
        RestRequest req1 = new RestRequest();
        RestResponse res1 = new RestResponse();
        req1.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/photos';
        req1.httpMethod = 'POST';
        req1.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'photoType' => 'Before',
            'imageBase64' => mockBase64,
            'fileName' => 'before_inspection.jpg',
            'notes' => 'Initial inspection photo',
            'lineItemId' => woli.Id
        }));
        RestContext.request = req1;
        RestContext.response = res1;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doPost();

        // 2. Upload After Photo via URL
        RestRequest req2 = new RestRequest();
        RestResponse res2 = new RestResponse();
        req2.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/photos';
        req2.httpMethod = 'POST';
        req2.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'photoType' => 'After',
            'photoUrl' => 'https://example.com/photos/after_overhaul.jpg',
            'notes' => 'Completed inspection photo',
            'lineItemId' => woli.Id
        }));
        RestContext.request = req2;
        RestContext.response = res2;
        DF360_AppointmentLifecycleAPI.doPost();

        // 3. GET /photos gallery
        RestRequest getReq = new RestRequest();
        RestResponse getRes = new RestResponse();
        getReq.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/photos';
        getReq.httpMethod = 'GET';
        RestContext.request = getReq;
        RestContext.response = getRes;
        DF360_AppointmentLifecycleAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res1.statusCode);
        System.assertEquals(200, res2.statusCode);
        System.assertEquals(200, getRes.statusCode);

        Service_Job__c updatedJob = [SELECT Before_Photo_URL__c, After_Photo_URL__c FROM Service_Job__c WHERE Id = :sa.Id];
        System.assertNotEquals(null, updatedJob.Before_Photo_URL__c);
        System.assertEquals('https://example.com/photos/after_overhaul.jpg', updatedJob.After_Photo_URL__c);

        Work_Order_Line_Item__c updatedWoli = [SELECT Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c FROM Work_Order_Line_Item__c WHERE Id = :woli.Id];
        System.assertNotEquals(null, updatedWoli.Pre_Service_Photo_URL__c);
        System.assertEquals('https://example.com/photos/after_overhaul.jpg', updatedWoli.Post_Service_Photo_URL__c);
    }

    @IsTest
    static void testGetAppointmentDetails360() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        RestRequest getReq = new RestRequest();
        RestResponse getRes = new RestResponse();
        getReq.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id;
        getReq.httpMethod = 'GET';
        RestContext.request = getReq;
        RestContext.response = getRes;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, getRes.statusCode, 'Expected 200 OK');
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(getRes.responseBody.toString());
        System.assertEquals(true, respMap.get('success'));

        Map<String, Object> apptMap = (Map<String, Object>) respMap.get('serviceAppointment');
        System.assertNotEquals(null, apptMap);
        System.assertEquals(sa.Id, apptMap.get('id'));
        System.assertNotEquals(null, apptMap.get('multiAssetLineItems'));
    }

    @IsTest
    static void testDirectMethodCall() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        Test.startTest();
        Map<String, Object> details = DF360_AppointmentLifecycleAPI.getServiceAppointmentDetails(sa.Name, null);
        Test.stopTest();

        System.assertEquals(true, details.get('success'));
    }

    @IsTest
    static void testNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/service-appointments/INVALID_ID/check-in';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doPost();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void testMarkIncompleteSuccess() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/incomplete';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'description' => 'Customer premises locked, unable to access equipment.',
            'reason' => 'Customer Unavailable',
            'notes' => 'Called site contact twice; no response.',
            'latitude' => 19.1136,
            'longitude' => 72.8697
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, respMap.get('success'));

        Service_Job__c updatedSa = [SELECT Status__c, Reason__c, Description__c, Notes__c, Work_Order__r.Status__c FROM Service_Job__c WHERE Id = :sa.Id];
        System.assertEquals('Incomplete', updatedSa.Status__c);
        System.assertEquals('Customer Unavailable', updatedSa.Reason__c);
        System.assert(updatedSa.Description__c.contains('Customer premises locked'));
        System.assertEquals('Temporarily Paused', updatedSa.Work_Order__r.Status__c);
    }

    @IsTest
    static void testMarkIncompleteMissingDescription() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/incomplete';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'reason' => 'Customer Unavailable'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_AppointmentLifecycleAPI.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected 400 Bad Request');
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, respMap.get('success'));
    }

    @IsTest
    static void testMarkIncompleteDirectMethodAndPatch() {
        Service_Job__c sa = [SELECT Id, Name FROM Service_Job__c LIMIT 1];

        Test.startTest();
        // Direct call
        Map<String, Object> resMap = DF360_AppointmentLifecycleAPI.executeMarkIncomplete(sa.Id, new Map<String, Object>{
            'description' => 'Spare parts exhausted on site.',
            'reason' => 'Required Parts Unavailable'
        });
        System.assertEquals(true, resMap.get('success'));

        // Test PATCH endpoint delegation
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/service-appointments/' + sa.Id + '/incomplete';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'description' => 'Patched incomplete description'
        }));
        RestContext.request = req;
        RestContext.response = res;
        DF360_AppointmentLifecycleAPI.doPatch();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }
}