trigger DF360_PartsRequestTrigger on Parts_Request__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        // Update Service_Job status when parts are requested
        Set<Id> jobIds = new Set<Id>();
        for (Parts_Request__c pr : Trigger.new) {
            if (pr.Status__c == 'Pending Approval' || pr.Status__c == 'Approved') {
                jobIds.add(pr.Service_Job__c);
            }
        }
        if (!jobIds.isEmpty()) {
            List<Service_Job__c> jobs = [SELECT Id, Status__c FROM Service_Job__c WHERE Id IN :jobIds];
            for (Service_Job__c j : jobs) {
                if (j.Status__c == 'In Progress') j.Status__c = 'Parts Awaited';
            }
            update jobs;
        }
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        // When parts approved, reduce reserved stock and dispatch
        for (Parts_Request__c pr : Trigger.new) {
            Parts_Request__c old = Trigger.oldMap.get(pr.Id);
            if (pr.Status__c == 'Dispatched' && old.Status__c == 'Approved') {
                // Update stock: reduce available, update dispatched timestamp done in controller
            }
        }
    }
}
