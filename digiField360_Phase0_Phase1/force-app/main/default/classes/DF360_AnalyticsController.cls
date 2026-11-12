public with sharing class DF360_AnalyticsController {

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getManagerDashboard(String zoneId) {
        Date today = Date.today();
        Date weekStart = today.toStartOfWeek();
        Id zId = String.isNotBlank(zoneId) ? (Id) zoneId : null;

        // Today jobs
        AggregateResult[] todayAgg = [SELECT COUNT(Id) total FROM Service_Job__c
            WHERE CreatedDate = TODAY AND (Zone__c = :zId OR :zId = null) AND Status__c != 'Cancelled'];
        Integer jobsToday = (Integer) todayAgg[0].get('total');

        // Open jobs with SLA status
        Integer slaGreen = [SELECT COUNT() FROM Service_Job__c
            WHERE SLA_Status__c = 'Green' AND Status__c NOT IN ('Completed','Cancelled')
              AND (Zone__c = :zId OR :zId = null)];
        Integer slaAmber = [SELECT COUNT() FROM Service_Job__c
            WHERE SLA_Status__c = 'Amber' AND Status__c NOT IN ('Completed','Cancelled')
              AND (Zone__c = :zId OR :zId = null)];
        Integer slaRed   = [SELECT COUNT() FROM Service_Job__c
            WHERE SLA_Status__c IN ('Red','Breached') AND Status__c NOT IN ('Completed','Cancelled')
              AND (Zone__c = :zId OR :zId = null)];

        // FTFR today
        AggregateResult[] ftfrAgg = [SELECT COUNT(Id) total, SUM(CASE WHEN Is_First_Time_Fix__c = true THEN 1 ELSE 0 END) fixed
            FROM Service_Job__c WHERE Completed_Time__c = TODAY AND (Zone__c = :zId OR :zId = null)];
        // SOQL CASE not supported — use two queries
        Integer completed  = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY AND (Zone__c = :zId OR :zId = null)];
        Integer ftfr       = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY AND Is_First_Time_Fix__c = true AND (Zone__c = :zId OR :zId = null)];
        Decimal ftfrPct    = completed > 0 ? ((Decimal)ftfr/completed*100).setScale(1) : 0;

        // CSAT 30 days
        AggregateResult[] csatAgg = [SELECT AVG(Rating__c) avg FROM CSAT__c
            WHERE Is_Responded__c = true AND Response_Date__c = LAST_N_DAYS:30
              AND Service_Job__r.Zone__c = :zId];
        Decimal csatAvg = csatAgg[0].get('avg') == null ? 0 : ((Decimal)csatAgg[0].get('avg')).setScale(2);

        // Parts pending
        Integer partsPending = [SELECT COUNT() FROM Parts_Request__c WHERE Status__c = 'Pending Approval'];

        return new Map<String,Object>{
            'jobsToday'=> jobsToday, 'slaGreen'=> slaGreen, 'slaAmber'=> slaAmber, 'slaRed'=> slaRed,
            'completed'=> completed, 'ftfr'=> ftfr, 'ftfrPct'=> ftfrPct,
            'csatAvg'=> csatAvg, 'partsPending'=> partsPending
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getSLACompliance(String zoneId, Integer days) {
        return DF360_SLAController.getSLAReport(zoneId, days);
    }
}
