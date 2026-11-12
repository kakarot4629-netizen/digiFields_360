public class DF360_CSATRollupBatch implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) { Database.executeBatch(new DF360_CSATRollupBatch(), 200); }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Technician__c WHERE Is_Active__c = true]);
    }
    public void execute(Database.BatchableContext bc, List<Technician__c> techs) {
        Set<Id> techIds = new Map<Id,Technician__c>(techs).keySet();
        Date fromDate = Date.today().addDays(-30);
        Map<Id,Decimal> csatMap = new Map<Id,Decimal>();
        for (AggregateResult ar : [SELECT Service_Job__r.Technician__c techId, AVG(Rating__c) avg
            FROM CSAT__c WHERE Service_Job__r.Technician__c IN :techIds AND Is_Responded__c = true
              AND Response_Date__c >= :fromDate GROUP BY Service_Job__r.Technician__c]) {
            csatMap.put((Id)ar.get('techId'), ((Decimal)ar.get('avg')).setScale(2));
        }
        Map<Id,Decimal> ftfrMap = new Map<Id,Decimal>();
        for (AggregateResult ar : [SELECT Technician__c, COUNT(Id) total FROM Service_Job__c
            WHERE Technician__c IN :techIds AND Completed_Time__c >= :fromDate GROUP BY Technician__c]) {
            ftfrMap.put((Id)ar.get('Technician__c'), Decimal.valueOf(String.valueOf(ar.get('total'))));
        }
        Map<Id,Decimal> ftfCountMap = new Map<Id,Decimal>();
        for (AggregateResult ar : [SELECT Technician__c, COUNT(Id) ftf FROM Service_Job__c
            WHERE Technician__c IN :techIds AND Is_First_Time_Fix__c = true AND Completed_Time__c >= :fromDate GROUP BY Technician__c]) {
            ftfCountMap.put((Id)ar.get('Technician__c'), Decimal.valueOf(String.valueOf(ar.get('ftf'))));
        }
        List<Technician__c> updates = new List<Technician__c>();
        for (Technician__c t : techs) {
            Decimal total = ftfrMap.containsKey(t.Id) ? ftfrMap.get(t.Id) : 0;
            Decimal ftfCount = ftfCountMap.containsKey(t.Id) ? ftfCountMap.get(t.Id) : 0;
            updates.add(new Technician__c(
                Id = t.Id,
                CSAT_Avg_30d__c = csatMap.containsKey(t.Id) ? csatMap.get(t.Id) : null,
                FTFR_Pct__c = total > 0 ? (ftfCount / total * 100).setScale(1) : null
            ));
        }
        if (!updates.isEmpty()) update updates;
    }
    public void finish(Database.BatchableContext bc) { }
}
