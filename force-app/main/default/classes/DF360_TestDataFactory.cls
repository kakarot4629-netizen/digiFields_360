@isTest
public class DF360_TestDataFactory {

    public static Account createAccount(String name) {
        Account acc = new Account(
            Name = name,
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingCountry = 'India'
        );
        insert acc;
        return acc;
    }

    public static Service_Zone__c createZone(String name) {
        Service_Zone__c zone = new Service_Zone__c(
            Name = name,
            Is_Active__c = true,
            Pin_Codes__c = '400001, 400002, 400050, 411001'
        );
        insert zone;
        return zone;
    }

    public static Technician__c createTechnician(String name, Id zoneId, Id userId) {
        Technician__c tech = new Technician__c(
            Zone__c = zoneId,
            User__c = userId != null ? userId : UserInfo.getUserId(),
            Availability_Status__c = 'Available',
            CSAT_Avg_30d__c = 4.8,
            FTFR_Pct__c = 92.5,
            Active_Job_Count__c = 0,
            Employee_Code__c = 'EMP-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4),
            Current_GPS_Latitude__c = 19.0760,
            Current_GPS_Longitude__c = 72.8777,
            Is_Active__c = true
        );
        insert tech;
        return tech;
    }

    public static Skill__c createSkill(String name, String category) {
        Skill__c skill = new Skill__c(
            Name = name,
            Skill_Name__c = name,
            Category__c = category,
            Cert_Required__c = false,
            Description__c = 'Skill for ' + name
        );
        insert skill;
        return skill;
    }

    public static Technician_Skill__c assignSkill(Id technicianId, Id skillId, String proficiency) {
        Technician_Skill__c ts = new Technician_Skill__c(
            Technician__c = technicianId,
            Skill__c = skillId,
            Proficiency__c = proficiency,
            Is_Active__c = true,
            Cert_Expiry__c = Date.today().addDays(180)
        );
        insert ts;
        return ts;
    }

    public static Asset__c createAsset(Id accountId, String serialNo, String category) {
        Asset__c ast = new Asset__c(
            Name = 'Asset ' + serialNo,
            Account__c = accountId,
            Serial_Number__c = serialNo,
            Product_Name__c = 'Industrial Equipment Pro',
            Product_Category__c = category,
            Install_Date__c = Date.today().addMonths(-6),
            Warranty_Expiry__c = Date.today().addMonths(6),
            Is_Under_Warranty__c = true,
            Location_Address__c = 'Tech Park, Andheri East, Mumbai',
            GPS_Location__Latitude__s = 19.1136,
            GPS_Location__Longitude__s = 72.8697
        );
        insert ast;
        return ast;
    }

    public static SLA_Config__c createSLAConfig(String category, String priority, Integer ackMin, Decimal resHrs) {
        SLA_Config__c config = new SLA_Config__c(
            Name = category + ' ' + priority,
            Product_Category__c = category,
            Customer_Tier__c = 'All',
            Priority__c = priority,
            Ack_SLA_Mins__c = ackMin,
            Response_SLA_Hrs__c = 2,
            Resolution_SLA_Hrs__c = resHrs,
            Is_Active__c = true
        );
        insert config;
        return config;
    }

    public static Depot__c createDepot(String name, Id zoneId) {
        Depot__c depot = new Depot__c(
            Name = name,
            Zone__c = zoneId,
            Address__c = 'Central Depot Hub, Mumbai',
            Is_Active__c = true,
            GPS_Location__Latitude__s = 19.0760,
            GPS_Location__Longitude__s = 72.8777
        );
        insert depot;
        return depot;
    }

    public static Part__c createPart(String code, String name, Decimal cost, Boolean isWarranty) {
        Part__c part = new Part__c(
            Name = name,
            Part_Code__c = code,
            ERP_SKU__c = 'SKU-' + code,
            Category__c = 'Mechanical',
            Unit_Cost__c = cost,
            Is_Warranty_Item__c = isWarranty,
            Is_Active__c = true
        );
        insert part;
        return part;
    }

    public static Parts_Stock__c createStock(Id partId, Id depotId, Integer qty, Integer reorder) {
        Parts_Stock__c stock = new Parts_Stock__c(
            Part__c = partId,
            Depot__c = depotId,
            Quantity_Available__c = qty,
            Quantity_Reserved__c = 0,
            Reorder_Level__c = reorder,
            Last_Updated__c = DateTime.now()
        );
        insert stock;
        return stock;
    }

    public static Service_Job__c createServiceJob(Id accountId, Id assetId, Id technicianId, String jobType, String priority) {
        Service_Job__c job = new Service_Job__c(
            Account__c = accountId,
            Asset__c = assetId,
            Technician__c = technicianId,
            Job_Type__c = jobType,
            Priority__c = priority,
            Status__c = 'New',
            Notes__c = 'Standard service request description',
            Source__c = 'WhatsApp',
            SLA_Deadline__c = DateTime.now().addHours(4)
        );
        insert job;
        return job;
    }
}
