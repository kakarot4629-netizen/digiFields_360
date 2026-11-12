public class DF360_CSATTriggerHelper {
    @future
    public static void sendLowCSATAlert(Id csatId, Id jobId, Integer rating) {
        update new CSAT__c(Id = csatId, Alert_Sent__c = true);
        insert new Task(Subject = 'Low CSAT Alert — Rating: ' + rating, Priority = 'High',
            Status = 'Open', ActivityDate = Date.today(),
            WhatId = jobId, Description = 'Customer rated this job ' + rating + '/5. Manager follow-up required within 24 hours.');
    }
}
