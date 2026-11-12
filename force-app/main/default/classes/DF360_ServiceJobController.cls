public with sharing class DF360_ServiceJobController {

    @AuraEnabled
    public static Id createJob(Id customerId, Id assetId, String jobType,
                               String priority, String notes, String productCategory) {
        return createJobWithParent(customerId, assetId, jobType, priority, notes, productCategory, null, null);
    }

    @AuraEnabled
    public static Id createJobWithParent(Id customerId, Id assetId, String jobType,
                                         String priority, String notes, String productCategory,
                                         Id workOrderId, Id caseId) {
        Service_Job__c job = new Service_Job__c(
            Account__c = customerId,
            Asset__c = assetId,
            Job_Type__c = jobType,
            Priority__c = priority,
            Notes__c = notes,
            Product_Category__c = productCategory,
            Status__c = 'New',
            Source__c = 'Internal',
            Work_Order__c = workOrderId,
            Case__c = caseId
        );
        insert job;
        return job.Id;
    }

    @AuraEnabled
    public static void updateStatus(Id jobId, String newStatus) {
        try {
            Service_Job__c job = [SELECT Status__c, SLA_Deadline__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
            job.Status__c = newStatus;
            if (newStatus == 'On Site') job.Check_In_Time__c = DateTime.now();
            if (newStatus == 'Completed') job.Completed_Time__c = DateTime.now();
            update job;
        } catch (Exception e) {
            System.debug('UpdateStatus Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String,Object> checkIn(Id jobId, Id technicianId, Decimal lat, Decimal lng) {
        try {
            if (jobId == null) {
                throw new AuraHandledException('Service Appointment ID is required for Check-In.');
            }
            Service_Job__c job = [SELECT Id, SLA_Deadline__c, Status__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
            Decimal remaining = 0;
            if (job.SLA_Deadline__c != null) {
                remaining = (Decimal.valueOf(job.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(2);
            }
            Decimal finalLat = (lat != null) ? lat : 19.0760;
            Decimal finalLng = (lng != null) ? lng : 72.8777;

            update new Service_Job__c(
                Id = jobId, 
                Status__c = 'On Site',
                Check_In_Time__c = DateTime.now(),
                Check_In_GPS__Latitude__s = finalLat,
                Check_In_GPS__Longitude__s = finalLng
            );

            try {
                DF360_SLAController.createSLAEvent(jobId, 'On Site', remaining, 'Technician checked in at site');
            } catch (Exception slaEx) {
                System.debug('Warning: SLA Event could not be created during checkIn: ' + slaEx.getMessage());
            }

            return new Map<String,Object>{'jobId'=>jobId,'slaRemainingHrs'=>remaining};
        } catch (Exception e) {
            System.debug('CheckIn Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void completeJob(Id jobId, Boolean isFirstTimeFix, String signatureUrl) {
        try {
            if (jobId == null) {
                throw new AuraHandledException('Service Appointment ID is required for Completion.');
            }
            Service_Job__c job = [SELECT Id, Check_In_Time__c, Work_Order__c, Case__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1 FOR UPDATE];
            Integer durationMin = 0;
            if (job.Check_In_Time__c != null) {
                durationMin = Integer.valueOf((DateTime.now().getTime() - job.Check_In_Time__c.getTime()) / 60000);
            }
            String sig = String.isNotBlank(signatureUrl) ? signatureUrl : 'https://sig.digifield360.io/sig.png';

            update new Service_Job__c(
                Id = jobId,
                Status__c = 'Completed',
                Completed_Time__c = DateTime.now(),
                Resolution_Time_Min__c = durationMin,
                Is_First_Time_Fix__c = (isFirstTimeFix == true),
                Customer_Signature_URL__c = sig
            );

            try {
                DF360_SLAController.createSLAEvent(jobId, 'Resolved', 0, 'Job completed');
            } catch (Exception slaEx) {
                System.debug('Warning: SLA Event could not be created during completeJob: ' + slaEx.getMessage());
            }

            // Parent Work Order status synchronization
            if (job.Work_Order__c != null) {
                try {
                    update new Work_Order__c(
                        Id = job.Work_Order__c,
                        Status__c = 'Completed',
                        Completed_Date__c = Date.today()
                    );
                } catch (Exception ex) {
                    System.debug('Warning: Could not update parent Work Order: ' + ex.getMessage());
                }
            }

            // Parent Case status synchronization if all jobs are finished
            if (job.Case__c != null) {
                try {
                    Integer openJobsCount = [
                        SELECT COUNT() 
                        FROM Service_Job__c 
                        WHERE Case__c = :job.Case__c AND Id != :jobId AND Status__c != 'Completed' AND Status__c != 'Cancelled'
                    ];
                    if (openJobsCount == 0) {
                        update new Case(Id = job.Case__c, Status = 'Closed');
                    }
                } catch (Exception ex) {
                    System.debug('Warning: Could not update parent Case: ' + ex.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug('CompleteJob Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Service_Job__c getJobDetail(Id jobId) {
        return [SELECT Id, Name, Status__c, Job_Type__c, Priority__c, SLA_Deadline__c, SLA_Status__c,
                       Account__c, Account__r.Name, Asset__c, Asset__r.Product_Name__c,
                       Technician__c, Technician__r.Name, Zone__c, Zone__r.Name,
                       Work_Order__c, Work_Order__r.Name, Case__c, Case__r.CaseNumber,
                       Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                       Is_First_Time_Fix__c, Notes__c, Product_Category__c, CSAT_Sent__c,
                       Service_Contract__c, Source__c
                FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getDispatchBoard(String statusFilter, String zoneId) {
        String soql = 'SELECT Id, Name, Status__c, Priority__c, SLA_Deadline__c, SLA_Status__c, Job_Type__c, ' +
            'Account__r.Name, Technician__r.Name, Asset__r.Product_Name__c, CreatedDate ' +
            'FROM Service_Job__c WHERE Status__c != \'Cancelled\' ';
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            soql += ' AND Status__c = \'' + String.escapeSingleQuotes(statusFilter) + '\'';
        }
        if (String.isNotBlank(zoneId)) {
            soql += ' AND Zone__c = \'' + String.escapeSingleQuotes(zoneId) + '\'';
        }
        soql += ' ORDER BY Priority__c ASC, SLA_Deadline__c ASC NULLS LAST LIMIT 500';
        List<Service_Job__c> jobs = Database.query(soql);
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Service_Job__c j : jobs) {
            Decimal remHrs = 0;
            if (j.SLA_Deadline__c != null) {
                remHrs = (Decimal.valueOf(j.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(1);
            }
            result.add(new Map<String,Object>{
                'id'=>j.Id,'name'=>j.Name,'status'=>j.Status__c,'priority'=>j.Priority__c,
                'slaDeadline'=>j.SLA_Deadline__c,'slaStatus'=>j.SLA_Status__c,
                'jobType'=>j.Job_Type__c,'customerName'=>j.Account__r.Name,
                'technicianName'=>j.Technician__r != null ? j.Technician__r.Name : '',
                'assetName'=>j.Asset__r != null ? j.Asset__r.Product_Name__c : '',
                'slaRemainingHrs'=>remHrs,'createdDate'=>j.CreatedDate
            });
        }
        return result;
    }
}
