public with sharing class DF360_SLAController {

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getSLAStatus(Id jobId) {
        Service_Job__c job = [
            SELECT SLA_Deadline__c, SLA_Status__c, Status__c, Priority__c,
                   Service_Contract__c, Service_Contract__r.SLA_Resolution_Hrs__c
            FROM Service_Job__c WHERE Id = :jobId LIMIT 1
        ];
        Decimal remainingHrs = 0;
        String color = 'Green';
        if (job.SLA_Deadline__c != null) {
            Long diffMs = job.SLA_Deadline__c.getTime() - DateTime.now().getTime();
            remainingHrs = (Decimal.valueOf(diffMs) / 3600000).setScale(2);
            if (remainingHrs < 0) {
                color = 'Breached';
            } else if (remainingHrs < 1) {
                color = 'Red';
            } else if (remainingHrs < 2) {
                color = 'Amber';
            }
        }
        return new Map<String,Object>{
            'slaDeadline' => job.SLA_Deadline__c,
            'remainingHrs' => remainingHrs,
            'color' => color,
            'status' => job.SLA_Status__c
        };
    }

    public static DateTime computeSLADeadline(Service_Job__c job) {
        Decimal resHrs = 4; // default
        if (job.Service_Contract__c != null && job.Service_Contract__r != null
            && job.Service_Contract__r.SLA_Resolution_Hrs__c != null) {
            resHrs = job.Service_Contract__r.SLA_Resolution_Hrs__c;
        } else {
            List<SLA_Config__c> configs = [
                SELECT Resolution_SLA_Hrs__c
                FROM SLA_Config__c
                WHERE (Product_Category__c = :job.Product_Category__c OR Product_Category__c = 'All')
                  AND (Priority__c = :job.Priority__c OR Priority__c = 'All')
                  AND Is_Active__c = true
                ORDER BY Priority__c ASC, Product_Category__c ASC
                LIMIT 1
            ];
            if (!configs.isEmpty() && configs[0].Resolution_SLA_Hrs__c != null) {
                resHrs = configs[0].Resolution_SLA_Hrs__c;
            }
        }
        return DateTime.now().addHours(resHrs.intValue());
    }

    public static void createSLAEvent(Id jobId, String eventType, Decimal remainingHrs, String notes) {
        insert new SLA_Event__c(
            Service_Job__c = jobId,
            Event_Type__c = eventType,
            Event_Timestamp__c = DateTime.now(),
            SLA_Remaining_Hrs__c = remainingHrs,
            Notes__c = notes
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<SLA_Event__c> getSLATimeline(Id jobId) {
        return [SELECT Id, Event_Type__c, Event_Timestamp__c, SLA_Remaining_Hrs__c, Notes__c
                FROM SLA_Event__c WHERE Service_Job__c = :jobId ORDER BY Event_Timestamp__c ASC];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getSLAReport(String zoneId, Integer days) {
        Date fromDate = Date.today().addDays(-(days == null ? 30 : days));
        Id zId = String.isNotBlank(zoneId) ? (Id)zoneId : null;

        Integer total = 0;
        Integer breached = 0;

        if (zId != null) {
            AggregateResult[] totAgg = [SELECT COUNT(Id) total FROM Service_Job__c WHERE Completed_Time__c >= :fromDate AND Zone__c = :zId];
            if (!totAgg.isEmpty() && totAgg[0].get('total') != null) {
                total = (Integer) totAgg[0].get('total');
            }
            AggregateResult[] brAgg = [SELECT COUNT(Id) breached FROM Service_Job__c WHERE SLA_Status__c = 'Breached' AND Completed_Time__c >= :fromDate AND Zone__c = :zId];
            if (!brAgg.isEmpty() && brAgg[0].get('breached') != null) {
                breached = (Integer) brAgg[0].get('breached');
            }
        } else {
            AggregateResult[] totAgg = [SELECT COUNT(Id) total FROM Service_Job__c WHERE Completed_Time__c >= :fromDate];
            if (!totAgg.isEmpty() && totAgg[0].get('total') != null) {
                total = (Integer) totAgg[0].get('total');
            }
            AggregateResult[] brAgg = [SELECT COUNT(Id) breached FROM Service_Job__c WHERE SLA_Status__c = 'Breached' AND Completed_Time__c >= :fromDate];
            if (!brAgg.isEmpty() && brAgg[0].get('breached') != null) {
                breached = (Integer) brAgg[0].get('breached');
            }
        }

        Decimal compliance = total > 0 ? (((Decimal)(total - breached) / total) * 100).setScale(1) : 100;
        return new Map<String,Object>{
            'total' => total,
            'breached' => breached,
            'compliance' => compliance
        };
    }
}
