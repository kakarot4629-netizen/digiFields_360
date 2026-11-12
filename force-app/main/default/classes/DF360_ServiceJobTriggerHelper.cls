public class DF360_ServiceJobTriggerHelper {
    @future
    public static void sendCSATAsync(List<Id> jobIds) {
        for (Service_Job__c job : [SELECT Id, Account__r.Phone FROM Service_Job__c WHERE Id IN :jobIds]) {
            if (job.Account__r != null && String.isNotBlank(job.Account__r.Phone)) {
                DF360_CSATController.sendCSATRequest(job.Id, job.Account__r.Phone);
            }
        }
    }
}
