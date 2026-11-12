trigger DF360_ServiceJobTrigger on Service_Job__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Service_Job__c job : Trigger.new) {
            // Compute SLA deadline on insert
            if (job.SLA_Deadline__c == null) {
                job.SLA_Deadline__c = DF360_SLAController.computeSLADeadline(job);
            }
            job.SLA_Status__c = 'Green';
        }
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        for (Service_Job__c job : Trigger.new) {
            // Auto-stamp Check-In Time (Actual Start) when technician arrives on site or starts work, if not explicitly provided
            if ((job.Status__c == 'On Site' || job.Status__c == 'In Progress') && job.Check_In_Time__c == null) {
                job.Check_In_Time__c = DateTime.now();
            }
            // Auto-stamp Completed Time (Actual End) when job is completed, if not explicitly provided
            if (job.Status__c == 'Completed' && job.Completed_Time__c == null) {
                job.Completed_Time__c = DateTime.now();
            }
            // Auto-calculate Resolution Time (min) if both actual timestamps exist and not already set
            if (job.Check_In_Time__c != null && job.Completed_Time__c != null && job.Resolution_Time_Min__c == null) {
                Long diffMs = job.Completed_Time__c.getTime() - job.Check_In_Time__c.getTime();
                job.Resolution_Time_Min__c = Integer.valueOf(diffMs / 60000);
            }
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
