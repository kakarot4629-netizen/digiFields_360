public with sharing class DF360_AssetController {

    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getAssetDetail(Id assetId) {
        Asset__c asset = [
            SELECT Id, Name, Serial_Number__c, Product_Name__c, Product_Category__c,
                   Install_Date__c, Warranty_Expiry__c, Last_Service_Date__c,
                   Is_Under_Warranty__c, Visit_Count_30d__c, Location_Address__c,
                   GPS_Location__Latitude__s, GPS_Location__Longitude__s,
                   Account__c, Account__r.Name, Zone__c, Zone__r.Name
            FROM Asset__c WHERE Id = :assetId LIMIT 1
        ];
        List<Service_Job__c> recentJobs = [
            SELECT Id, Name, Status__c, Job_Type__c, Completed_Time__c,
                   Is_First_Time_Fix__c, Technician__r.Name
            FROM Service_Job__c WHERE Asset__c = :assetId
            ORDER BY CreatedDate DESC LIMIT 20
        ];
        Boolean repeatVisitRisk = asset.Visit_Count_30d__c != null && asset.Visit_Count_30d__c >= 3;
        return new Map<String,Object>{
            'asset'=> asset, 'recentJobs'=> recentJobs, 'repeatVisitRisk'=> repeatVisitRisk
        };
    }

    public static Boolean checkWarrantyValid(Id assetId) {
        List<Asset__c> assets = [SELECT Warranty_Expiry__c FROM Asset__c WHERE Id = :assetId LIMIT 1];
        if (assets.isEmpty()) return false;
        return assets[0].Warranty_Expiry__c != null && assets[0].Warranty_Expiry__c >= Date.today();
    }
}
