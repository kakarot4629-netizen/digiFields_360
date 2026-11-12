public with sharing class DF360_ServiceJobController {

    @AuraEnabled
    public static Id createJob(String customerIdStr, String assetIdStr, String jobType,
                               String priority, String notes, String productCategory) {
        Service_Job__c job = new Service_Job__c(
            Account__c = (Id) customerIdStr,
            Asset__c = String.isNotBlank(assetIdStr) ? (Id) assetIdStr : null,
            Job_Type__c = jobType,
            Priority__c = priority,
            Notes__c = notes,
            Product_Category__c = productCategory,
            Status__c = 'New',
            Source__c = 'Internal'
        );
        insert job;
        return job.Id;
    }

    @AuraEnabled
    public static void updateStatus(Id jobId, String newStatus) {
        Service_Job__c job = [SELECT Status__c, SLA_Deadline__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        job.Status__c = newStatus;
        if (newStatus == 'On Site') job.Check_In_Time__c = DateTime.now();
        if (newStatus == 'Completed') job.Completed_Time__c = DateTime.now();
        update job;
    }

    @AuraEnabled
    public static Map<String,Object> checkIn(Id jobId, Id technicianId, Decimal lat, Decimal lng) {
        Service_Job__c job = [SELECT SLA_Deadline__c, Status__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        Decimal remaining = 0;
        if (job.SLA_Deadline__c != null) {
            remaining = (Decimal.valueOf(job.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(2);
        }
        update new Service_Job__c(
            Id = jobId, Status__c = 'On Site',
            Check_In_Time__c = DateTime.now(),
            Check_In_GPS__Latitude__s = lat,
            Check_In_GPS__Longitude__s = lng
        );
        DF360_SLAController.createSLAEvent(jobId, 'On Site', remaining, 'Technician checked in at site');
        return new Map<String,Object>{'jobId'=>jobId,'slaRemainingHrs'=>remaining};
    }

    @AuraEnabled
    public static void completeJob(Id jobId, Boolean isFirstTimeFix, String signatureUrl) {
        Service_Job__c job = [SELECT Check_In_Time__c FROM Service_Job__c WHERE Id = :jobId FOR UPDATE];
        Integer durationMin = 0;
        if (job.Check_In_Time__c != null) {
            durationMin = Integer.valueOf((DateTime.now().getTime() - job.Check_In_Time__c.getTime()) / 60000);
        }
        update new Service_Job__c(
            Id = jobId,
            Status__c = 'Completed',
            Completed_Time__c = DateTime.now(),
            Resolution_Time_Min__c = durationMin,
            Is_First_Time_Fix__c = isFirstTimeFix == true,
            Customer_Signature_URL__c = signatureUrl
        );
        DF360_SLAController.createSLAEvent(jobId, 'Resolved', 0, 'Job completed');
    }

    @AuraEnabled(cacheable=true)
    public static Service_Job__c getJobDetail(Id jobId) {
        return [SELECT Id, Name, Status__c, Job_Type__c, Priority__c, SLA_Deadline__c, SLA_Status__c,
                       Account__c, Account__r.Name, Asset__c, Asset__r.Product_Name__c,
                       Technician__c, Technician__r.Name, Zone__c, Zone__r.Name,
                       Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                       Is_First_Time_Fix__c, Notes__c, Product_Category__c, CSAT_Sent__c,
                       Service_Contract__c, Source__c
                FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getDispatchBoard(String statusFilter, String zoneId) {
        String soql = 'SELECT Id, Name, Status__c, Priority__c, SLA_Deadline__c, SLA_Status__c, Job_Type__c, ' +
            'Account__r.Name, Technician__r.Name, Asset__r.Product_Name__c, CreatedDate ' +
            'FROM Service_Job__c WHERE Status__c != 'Cancelled' ';
        if (String.isNotBlank(statusFilter) && statusFilter != 'All')
            soql += ' AND Status__c = '' + String.escapeSingleQuotes(statusFilter) + ''';
        if (String.isNotBlank(zoneId)) soql += ' AND Zone__c = '' + String.escapeSingleQuotes(zoneId) + ''';
        soql += ' ORDER BY Priority__c ASC, SLA_Deadline__c ASC NULLS LAST LIMIT 500';
        List<Service_Job__c> jobs = Database.query(soql);
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Service_Job__c j : jobs) {
            Decimal remHrs = 0;
            if (j.SLA_Deadline__c != null)
                remHrs = (Decimal.valueOf(j.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(1);
            result.add(new Map<String,Object>{
                'id'=>j.Id,'name'=>j.Name,'status'=>j.Status__c,'priority'=>j.Priority__c,
                'slaDeadline'=>j.SLA_Deadline__c,'slaStatus'=>j.SLA_Status__c,
                'jobType'=>j.Job_Type__c,'customerName'=>j.Account__r.Name,
                'technicianName'=>j.Technician__r?.Name,'assetName'=>j.Asset__r?.Product_Name__c,
                'slaRemainingHrs'=>remHrs,'createdDate'=>j.CreatedDate
            });
        }
        return result;
    }
}
