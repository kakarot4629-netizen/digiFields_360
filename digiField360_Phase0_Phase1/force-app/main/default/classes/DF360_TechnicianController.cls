public with sharing class DF360_TechnicianController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getTodaysJobs(Id technicianId) {
        Id techId = technicianId == null ?
            [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1].Id
            : technicianId;
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Priority__c, SLA_Deadline__c, SLA_Status__c,
                   Job_Type__c, Account__r.Name, Asset__r.Product_Name__c,
                   Asset__r.GPS_Location__Latitude__s, Asset__r.GPS_Location__Longitude__s,
                   Asset__r.Location_Address__c, Check_In_Time__c, Product_Category__c
            FROM Service_Job__c
            WHERE Technician__c = :techId AND Status__c NOT IN ('Completed','Cancelled')
            ORDER BY Priority__c ASC, SLA_Deadline__c ASC NULLS LAST LIMIT 50
        ];
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Service_Job__c j : jobs) {
            result.add(new Map<String,Object>{
                'id'=> j.Id, 'name'=> j.Name, 'status'=> j.Status__c,
                'priority'=> j.Priority__c, 'slaDeadline'=> j.SLA_Deadline__c,
                'slaStatus'=> j.SLA_Status__c, 'jobType'=> j.Job_Type__c,
                'customerName'=> j.Account__r.Name, 'assetName'=> j.Asset__r?.Product_Name__c,
                'lat'=> j.Asset__r?.GPS_Location__Latitude__s,
                'lng'=> j.Asset__r?.GPS_Location__Longitude__s,
                'address'=> j.Asset__r?.Location_Address__c,
                'productCategory'=> j.Product_Category__c
            });
        }
        return result;
    }

    @AuraEnabled
    public static void updateAvailability(Id technicianId, String status) {
        update new Technician__c(Id = technicianId, Availability_Status__c = status);
    }
}
