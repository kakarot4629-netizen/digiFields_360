public with sharing class DF360_AnalyticsController {

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getManagerDashboard(String zoneId) {
        Id zId = String.isNotBlank(zoneId) ? (Id) zoneId : null;

        Integer jobsToday = 0;
        Integer slaGreen = 0;
        Integer slaAmber = 0;
        Integer slaRed = 0;
        Integer completed = 0;
        Integer ftfr = 0;
        Decimal csatAvg = 0;
        Integer partsPending = 0;

        if (zId != null) {
            jobsToday = [SELECT COUNT() FROM Service_Job__c WHERE CreatedDate = TODAY AND Zone__c = :zId AND Status__c != 'Cancelled'];
            slaGreen = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c = 'Green' AND Status__c NOT IN ('Completed','Cancelled') AND Zone__c = :zId];
            slaAmber = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c = 'Amber' AND Status__c NOT IN ('Completed','Cancelled') AND Zone__c = :zId];
            slaRed   = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c IN ('Red','Breached') AND Status__c NOT IN ('Completed','Cancelled') AND Zone__c = :zId];
            completed = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY AND Zone__c = :zId];
            ftfr = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY AND Is_First_Time_Fix__c = true AND Zone__c = :zId];
            
            AggregateResult[] csatAgg = [SELECT AVG(Rating__c) avgRating FROM CSAT__c WHERE Is_Responded__c = true AND Response_Date__c = LAST_N_DAYS:30 AND Service_Job__r.Zone__c = :zId];
            if (!csatAgg.isEmpty() && csatAgg[0].get('avgRating') != null) {
                csatAvg = ((Decimal)csatAgg[0].get('avgRating')).setScale(2);
            }
        } else {
            jobsToday = [SELECT COUNT() FROM Service_Job__c WHERE CreatedDate = TODAY AND Status__c != 'Cancelled'];
            slaGreen = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c = 'Green' AND Status__c NOT IN ('Completed','Cancelled')];
            slaAmber = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c = 'Amber' AND Status__c NOT IN ('Completed','Cancelled')];
            slaRed   = [SELECT COUNT() FROM Service_Job__c WHERE SLA_Status__c IN ('Red','Breached') AND Status__c NOT IN ('Completed','Cancelled')];
            completed = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY];
            ftfr = [SELECT COUNT() FROM Service_Job__c WHERE Completed_Time__c = TODAY AND Is_First_Time_Fix__c = true];

            AggregateResult[] csatAgg = [SELECT AVG(Rating__c) avgRating FROM CSAT__c WHERE Is_Responded__c = true AND Response_Date__c = LAST_N_DAYS:30];
            if (!csatAgg.isEmpty() && csatAgg[0].get('avgRating') != null) {
                csatAvg = ((Decimal)csatAgg[0].get('avgRating')).setScale(2);
            }
        }

        Decimal ftfrPct = completed > 0 ? ((Decimal)ftfr / completed * 100).setScale(1) : 0;
        partsPending = [SELECT COUNT() FROM Parts_Request__c WHERE Status__c = 'Pending Approval'];

        return new Map<String,Object>{
            'jobsToday' => jobsToday,
            'slaGreen' => slaGreen,
            'slaAmber' => slaAmber,
            'slaRed' => slaRed,
            'completed' => completed,
            'ftfr' => ftfr,
            'ftfrPct' => ftfrPct,
            'csatAvg' => csatAvg,
            'partsPending' => partsPending
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getSLACompliance(String zoneId, Integer days) {
        return DF360_SLAController.getSLAReport(zoneId, days);
    }
}
