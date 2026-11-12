@isTest
private class DF360_AssignedResourceTriggerHandlerTest {

    @isTest
    static void testLeadTechnicianSync() {
        Account acc = new Account(Name = 'Test Crew Acc', BillingCity = 'Pune');
        insert acc;

        Service_Zone__c zone = new Service_Zone__c(Zone_Name__c = 'North Zone', Is_Active__c = true);
        insert zone;

        Technician__c tech = new Technician__c(Zone__c = zone.Id, User__c = UserInfo.getUserId(), Is_Active__c = true);
        insert tech;

        Work_Order__c wo = new Work_Order__c(Subject__c = 'HVAC Test WO', Account__c = acc.Id, Status__c = 'New');
        insert wo;

        Service_Job__c job = new Service_Job__c(
            Work_Order__c = wo.Id,
            Account__c = acc.Id,
            Status__c = 'New',
            Priority__c = 'High'
        );
        insert job;

        Test.startTest();
        Assigned_Resource__c ar = new Assigned_Resource__c(
            Service_Job__c = job.Id,
            Technician__c = tech.Id,
            Resource_Type__c = 'Technician',
            Role__c = 'Lead Technician',
            Is_Leader__c = true,
            Status__c = 'Assigned'
        );
        insert ar;
        Test.stopTest();

        Service_Job__c updatedJob = [SELECT Id, Technician__c FROM Service_Job__c WHERE Id = :job.Id];
        System.assertEquals(tech.Id, updatedJob.Technician__c, 'Technician should be synced to Service Job');
    }

    @isTest
    static void testCrewExplosion() {
        Account acc = new Account(Name = 'Test Crew Acc 2', BillingCity = 'Mumbai');
        insert acc;

        Service_Zone__c zone = new Service_Zone__c(Zone_Name__c = 'West Zone', Is_Active__c = true);
        insert zone;

        Technician__c tech1 = new Technician__c(Zone__c = zone.Id, User__c = UserInfo.getUserId(), Is_Active__c = true);
        Technician__c tech2 = new Technician__c(Zone__c = zone.Id, Is_Active__c = true);
        insert new List<Technician__c>{ tech1, tech2 };

        Service_Crew__c crew = new Service_Crew__c(Name = 'Substation Overhaul Alpha', Crew_Size__c = 2, Zone__c = zone.Id, Is_Active__c = true);
        insert crew;

        Service_Crew_Member__c m1 = new Service_Crew_Member__c(Service_Crew__c = crew.Id, Technician__c = tech1.Id, Is_Leader__c = true);
        Service_Crew_Member__c m2 = new Service_Crew_Member__c(Service_Crew__c = crew.Id, Technician__c = tech2.Id, Is_Leader__c = false);
        insert new List<Service_Crew_Member__c>{ m1, m2 };

        Work_Order__c wo = new Work_Order__c(Subject__c = 'Transformer Test WO', Account__c = acc.Id, Status__c = 'New');
        insert wo;

        Service_Job__c job = new Service_Job__c(Work_Order__c = wo.Id, Account__c = acc.Id, Status__c = 'New', Priority__c = 'Critical');
        insert job;

        Test.startTest();
        // Assign the crew as a unit
        Assigned_Resource__c arCrew = new Assigned_Resource__c(
            Service_Job__c = job.Id,
            Service_Crew__c = crew.Id,
            Resource_Type__c = 'Crew',
            Status__c = 'Assigned'
        );
        insert arCrew;
        Test.stopTest();

        List<Assigned_Resource__c> memberResources = [
            SELECT Id, Technician__c, Role__c, Is_Leader__c
            FROM Assigned_Resource__c
            WHERE Service_Job__c = :job.Id AND Resource_Type__c = 'Technician'
        ];
        System.assertEquals(2, memberResources.size(), 'Crew members should be automatically exploded into Assigned_Resource records');
    }
}
