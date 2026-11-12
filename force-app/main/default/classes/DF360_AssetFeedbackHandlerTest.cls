@isTest
private class DF360_AssetFeedbackHandlerTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Multi-Asset Clinic');
        insert acc;

        Asset__c ast = new Asset__c(
            Product_Name__c = 'Test Generator Prime',
            Serial_Number__c = 'GEN-TEST-999',
            Account__c = acc.Id,
            Product_Category__c = 'Generators',
            Status__c = 'Active'
        );
        insert ast;

        Case c = new Case(
            Subject = 'Generator Routine Inspection',
            Status = 'New',
            AccountId = acc.Id
        );
        insert c;

        Work_Order__c wo = new Work_Order__c(
            Subject__c = 'Inspect Generator System',
            Status__c = 'New',
            Account__c = acc.Id,
            Case__c = c.Id,
            Asset__c = ast.Id
        );
        insert wo;

        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Work_Order__c = wo.Id,
            Asset__c = ast.Id,
            Description__c = 'Inspect Cummins Prime Generator',
            Sequence__c = 1,
            Status__c = 'New'
        );
        insert woli;
    }

    @isTest
    static void testCaseAssetAutoPopulatesActualAsset() {
        Work_Order_Line_Item__c woli = [
            SELECT Id, Asset__c, Work_Order__c, Work_Order__r.Case__c
            FROM Work_Order_Line_Item__c
            LIMIT 1
        ];

        Test.startTest();
        // Insert feedback with ONLY Case Asset (Work_Order_Line_Item__c)
        Asset_Feedback__c afb = new Asset_Feedback__c(
            Work_Order_Line_Item__c = woli.Id,
            Feedback_Type__c = 'Pre-Service Diagnostic',
            Operational_Status__c = 'Operational',
            Asset_Condition__c = 'Good',
            Rating__c = 5,
            Feedback_Notes__c = 'Generator running at full capacity and optimum temperature.'
        );
        insert afb;
        Test.stopTest();

        Asset_Feedback__c insertedAfb = [
            SELECT Id, Asset__c, Work_Order__c, Case__c, Work_Order_Line_Item__c
            FROM Asset_Feedback__c
            WHERE Id = :afb.Id
        ];

        System.assertEquals(woli.Asset__c, insertedAfb.Asset__c, 'Actual Asset should be auto-populated from Case Asset');
        System.assertEquals(woli.Work_Order__c, insertedAfb.Work_Order__c, 'Work Order should be auto-populated from Case Asset');
        System.assertEquals(woli.Work_Order__r.Case__c, insertedAfb.Case__c, 'Case should be auto-populated from Case Asset');
    }

    @isTest
    static void testWorkOrderAndActualAssetMatchesCaseAsset() {
        Work_Order__c wo = [SELECT Id, Case__c FROM Work_Order__c LIMIT 1];
        Asset__c ast = [SELECT Id FROM Asset__c LIMIT 1];
        Work_Order_Line_Item__c expectedWoli = [SELECT Id FROM Work_Order_Line_Item__c WHERE Work_Order__c = :wo.Id AND Asset__c = :ast.Id LIMIT 1];

        Test.startTest();
        // Insert feedback with Work Order and Actual Asset but without Case Asset
        Asset_Feedback__c afb = new Asset_Feedback__c(
            Work_Order__c = wo.Id,
            Asset__c = ast.Id,
            Feedback_Type__c = 'In-Service Inspection',
            Operational_Status__c = 'Operational',
            Asset_Condition__c = 'Excellent',
            Rating__c = 5,
            Feedback_Notes__c = 'Testing reverse line item lookup'
        );
        insert afb;
        Test.stopTest();

        Asset_Feedback__c insertedAfb = [
            SELECT Id, Work_Order_Line_Item__c
            FROM Asset_Feedback__c
            WHERE Id = :afb.Id
        ];

        System.assertEquals(expectedWoli.Id, insertedAfb.Work_Order_Line_Item__c, 'Case Asset should be auto-linked when Work Order and Actual Asset are specified');
    }

    @isTest
    static void testFeedbackUpdateSync() {
        Work_Order_Line_Item__c woli = [SELECT Id, Asset__c FROM Work_Order_Line_Item__c LIMIT 1];
        Asset_Feedback__c afb = new Asset_Feedback__c(
            Feedback_Type__c = 'Post-Service QA',
            Operational_Status__c = 'Operational',
            Asset_Condition__c = 'Good',
            Rating__c = 4
        );
        insert afb;

        Test.startTest();
        afb.Work_Order_Line_Item__c = woli.Id;
        update afb;
        Test.stopTest();

        Asset_Feedback__c updatedAfb = [
            SELECT Id, Asset__c, Work_Order__c
            FROM Asset_Feedback__c
            WHERE Id = :afb.Id
        ];
        System.assertEquals(woli.Asset__c, updatedAfb.Asset__c, 'Actual Asset should sync on update');
    }
}
