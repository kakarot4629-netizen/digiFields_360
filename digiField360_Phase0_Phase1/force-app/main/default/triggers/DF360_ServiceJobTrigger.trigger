trigger DF360_ServiceJobTrigger on Service_Job__c (before insert, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Service_Job__c job : Trigger.new) {
            // Compute SLA deadline on insert
            if (job.SLA_Deadline__c == null) {
                job.SLA_Deadline__c = DF360_SLAController.computeSLADeadline(job);
            }
            job.SLA_Status__c = 'Green';
        }
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        for (Service_Job__c job : Trigger.new) {
            DF360_SLAController.createSLAEvent(job.Id, 'Created', 0, 'Job created');
        }
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        List<Id> completedJobs = new List<Id>();
        for (Service_Job__c job : Trigger.new) {
            Service_Job__c old = Trigger.oldMap.get(job.Id);
            // Fire CSAT when job completes
            if (job.Status__c == 'Completed' && old.Status__c != 'Completed' && !job.CSAT_Sent__c) {
                completedJobs.add(job.Id);
            }
        }
        if (!completedJobs.isEmpty()) {
            DF360_ServiceJobTriggerHelper.sendCSATAsync(completedJobs);
        }
    }
}
