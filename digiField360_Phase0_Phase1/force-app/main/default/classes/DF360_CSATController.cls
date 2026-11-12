public with sharing class DF360_CSATController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getTechnicianCSAT(Id technicianId, Integer days) {
        Date fromDate = Date.today().addDays(-(days == null ? 30 : days));
        Id techId = technicianId == null ? null : technicianId;
        List<CSAT__c> records = [
            SELECT Rating__c, Comment__c, Response_Date__c,
                   Service_Job__r.Name, Service_Job__r.Job_Type__c, Is_Responded__c
            FROM CSAT__c
            WHERE Service_Job__r.Technician__c = :techId
              AND Response_Date__c >= :fromDate AND Is_Responded__c = true
            ORDER BY Response_Date__c DESC LIMIT 100
        ];
        AggregateResult[] avgAgg = [SELECT AVG(Rating__c) avgRating FROM CSAT__c
            WHERE Service_Job__r.Technician__c = :techId AND Is_Responded__c = true
              AND Response_Date__c >= :fromDate];
        Decimal avg = avgAgg[0].get('avgRating') == null ? 0 : ((Decimal)avgAgg[0].get('avgRating')).setScale(2);
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (CSAT__c c : records) {
            result.add(new Map<String,Object>{ 'rating'=> c.Rating__c,
                'comment'=> c.Comment__c, 'date'=> c.Response_Date__c,
                'jobName'=> c.Service_Job__r.Name, 'jobType'=> c.Service_Job__r.Job_Type__c });
        }
        return new List<Map<String,Object>>{ new Map<String,Object>{ 'avg'=> avg, 'records'=> result } };
    }

    public static void sendCSATRequest(Id jobId, String customerMobile) {
        if (String.isBlank(customerMobile)) return;
        Service_Job__c job = [SELECT Name, Technician__r.Name FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        String paramsJson = JSON.serialize(new List<String>{ job.Name, job.Technician__r?.Name != null ? job.Technician__r.Name : 'our technician' });
        DF360_WhatsAppService.sendAsync(customerMobile, 'csat_request', paramsJson);
        update new Service_Job__c(Id = jobId, CSAT_Sent__c = true);
        insert new CSAT__c(
            Service_Job__c = jobId,
            Customer_Mobile__c = customerMobile,
            Via_WhatsApp__c = true,
            Is_Responded__c = false
        );
    }

    @AuraEnabled
    public static void recordCSATResponse(String jobName, Integer rating, String comment, String mobile) {
        List<CSAT__c> records = [SELECT Id FROM CSAT__c WHERE Customer_Mobile__c = :mobile
            AND Service_Job__r.Name = :jobName AND Is_Responded__c = false LIMIT 1];
        if (!records.isEmpty()) {
            update new CSAT__c(Id = records[0].Id, Rating__c = rating, Comment__c = comment,
                Is_Responded__c = true, Response_Date__c = DateTime.now());
        }
    }
}
