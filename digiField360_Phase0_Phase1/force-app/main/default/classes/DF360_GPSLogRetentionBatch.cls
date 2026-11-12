public class DF360_GPSLogRetentionBatch implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) { Database.executeBatch(new DF360_GPSLogRetentionBatch(), 2000); }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoff = DateTime.now().addDays(-365);
        return Database.getQueryLocator([SELECT Id FROM GPS_Log__c WHERE Log_Timestamp__c < :cutoff]);
    }
    public void execute(Database.BatchableContext bc, List<GPS_Log__c> logs) { delete logs; }
    public void finish(Database.BatchableContext bc) { }
}
