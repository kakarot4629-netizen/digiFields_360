@isTest
private class DF360_WorkOrderAppointmentsAPITest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'API Test Health Corp',
            BillingCity = 'Pune',
            BillingState = 'Maharashtra',
            BillingCountry = 'India'
        );
        insert acc;

        Service_Zone__c zone = new Service_Zone__c(
            Zone_Name__c = 'Pune Test Zone',
            Is_Active__c = true
        );
        insert zone;

        Technician__c tech = new Technician__c(
            Zone__c = zone.Id,
            User__c = UserInfo.getUserId(),
            Availability_Status__c = 'Available',
            Is_Active__c = true
        );
        insert tech;

        Asset__c ast = new Asset__c(
            Account__c = acc.Id,
            Serial_Number__c = 'SN-API-TEST-999',
            Product_Name__c = 'MRI Scanner Pro',
            Product_Category__c = 'Medical Diagnostic'
        );
        insert ast;

        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'MRI Scanner Magnet Quench Warning',
            Status__c = 'New',
            Priority__c = 'Critical',
            Account__c = acc.Id,
            Asset__c = ast.Id,
            Assigned_Technician__c = UserInfo.getUserId(),
            Site_Address__c = 'Building 5, Medical City, Pune',
            Description__c = 'Liquid helium pressure level alarm triggered.',
            Equipment_ID__c = 'MRI-MAG-01',
            Equipment_Type__c = 'Medical Diagnostic',
            Scheduled_Date__c = DateTime.now().addHours(2),
            Time_Logged_Minutes__c = 45,
            Technician_Notes__c = 'Pre-checks completed.'
        );
        insert wo;

        Service_Job__c job1 = new Service_Job__c(
            Work_Order__c = wo.Id,
            Account__c = acc.Id,
            Asset__c = ast.Id,
            Technician__c = tech.Id,
            Zone__c = zone.Id,
            Job_Type__c = 'Repair',
            Status__c = 'Scheduled',
            Priority__c = 'Critical',
            Notes__c = 'Inspect pressure relief valves',
            Customer_Notes__c = 'Hospital bio-med engineer will escort',
            SLA_Deadline__c = DateTime.now().addHours(4)
        );
        insert job1;

        Service_Job__c job2 = new Service_Job__c(
            Work_Order__c = wo.Id,
            Account__c = acc.Id,
            Asset__c = ast.Id,
            Technician__c = tech.Id,
            Zone__c = zone.Id,
            Job_Type__c = 'Preventive Maintenance',
            Status__c = 'New',
            Priority__c = 'Medium',
            Notes__c = 'Post-repair calibration',
            SLA_Deadline__c = DateTime.now().addHours(8)
        );
        insert job2;
    }

    @isTest
    static void testRestGetAppointmentsById() {
        Work_Order__c wo = [SELECT Id, Name FROM Work_Order__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders/' + wo.Id + '/service-appointments';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        String responseBody = res.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals(true, respMap.get('success'), 'Expected success: true');
        System.assertEquals(2, respMap.get('serviceAppointmentsCount'), 'Expected 2 service appointments');

        Map<String, Object> woData = (Map<String, Object>) respMap.get('workOrder');
        System.assertEquals(wo.Id, woData.get('id'), 'Work Order ID should match');
        System.assertEquals('MRI Scanner Magnet Quench Warning', woData.get('subject'), 'Subject should match');
    }

    @isTest
    static void testRestGetAppointmentsByName() {
        Work_Order__c wo = [SELECT Id, Name FROM Work_Order__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders/' + wo.Name + '/service-appointments';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        String responseBody = res.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals(true, respMap.get('success'), 'Expected success: true');
    }

    @isTest
    static void testRestGetAppointmentsByQueryParam() {
        Work_Order__c wo = [SELECT Id, Name FROM Work_Order__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders';
        req.params.put('workOrderId', wo.Id);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
    }

    @isTest
    static void testNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders/NON_EXISTENT_WO_999/service-appointments';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(404, res.statusCode, 'Expected 404 Not Found');
    }

    @isTest
    static void testRestGetMyWorkOrders() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders/my';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        String responseBody = res.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals(true, respMap.get('success'), 'Expected success: true');
        System.assertNotEquals(null, respMap.get('workOrders'), 'workOrders array should not be null');
    }

    @isTest
    static void testRestGetMyWorkOrdersWithStatusFilter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/work-orders/my';
        req.params.put('status', 'Assigned');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_WorkOrderAppointmentsAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        String responseBody = res.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals(true, respMap.get('success'), 'Expected success: true');
    }

    @isTest
    static void testDirectMethodCall() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        Map<String, Object> resSuccess = DF360_WorkOrderAppointmentsAPI.getWorkOrderWithAppointments(wo.Id, null);
        Map<String, Object> resBlank = DF360_WorkOrderAppointmentsAPI.getWorkOrderWithAppointments('', null);
        Map<String, Object> resMy = DF360_WorkOrderAppointmentsAPI.getMyWorkOrdersWithAppointments(null);
        Map<String, Object> resMyFiltered = DF360_WorkOrderAppointmentsAPI.getMyWorkOrdersWithAppointments('Assigned');
        Test.stopTest();

        System.assertEquals(true, resSuccess.get('success'), 'Expected success: true');
        System.assertEquals(false, resBlank.get('success'), 'Expected success: false for blank ID');
        System.assertEquals(true, resMy.get('success'), 'Expected success: true for my work orders');
        System.assertEquals(true, resMyFiltered.get('success'), 'Expected success: true for filtered work orders');
    }
}