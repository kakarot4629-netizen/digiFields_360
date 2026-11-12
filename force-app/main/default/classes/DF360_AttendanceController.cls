public with sharing class DF360_AttendanceController {

    @AuraEnabled
    public static void checkIn(Id technicianId, Decimal lat, Decimal lng) {
        punchIn(technicianId, lat, lng, true);
    }

    @AuraEnabled
    public static void checkOut(Id technicianId) {
        punchOut(technicianId, null, null);
    }

    @AuraEnabled
    public static void punchIn(Id technicianId, Decimal lat, Decimal lng, Boolean isGeofenceValid) {
        Id techId = technicianId;
        if (techId == null) {
            List<Technician__c> myTechs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
            if (!myTechs.isEmpty()) techId = myTechs[0].Id;
        }
        if (techId == null) return;

        Date today = Date.today();
        List<Attendance__c> existing = [
            SELECT Id FROM Attendance__c
            WHERE Technician__c = :techId AND Attendance_Date__c = :today 
            LIMIT 1
        ];
        if (!existing.isEmpty()) return;

        insert new Attendance__c(
            Technician__c = techId,
            Attendance_Date__c = today,
            Check_In_Time__c = DateTime.now(),
            Check_In_Latitude__c = lat,
            Check_In_Longitude__c = lng,
            Status__c = 'Present'
        );
        update new Technician__c(Id = techId, Availability_Status__c = 'Available');
    }

    @AuraEnabled
    public static void punchOut(Id technicianId, Decimal lat, Decimal lng) {
        Id techId = technicianId;
        if (techId == null) {
            List<Technician__c> myTechs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
            if (!myTechs.isEmpty()) techId = myTechs[0].Id;
        }
        if (techId == null) return;

        Date today = Date.today();
        List<Attendance__c> records = [
            SELECT Id, Check_In_Time__c 
            FROM Attendance__c
            WHERE Technician__c = :techId AND Attendance_Date__c = :today 
            LIMIT 1
        ];
        if (!records.isEmpty()) {
            Decimal hrs = 0;
            if (records[0].Check_In_Time__c != null) {
                hrs = (Decimal.valueOf(DateTime.now().getTime() - records[0].Check_In_Time__c.getTime()) / 3600000).setScale(1);
            }
            update new Attendance__c(
                Id = records[0].Id, 
                Check_Out_Time__c = DateTime.now(),
                Hours_Worked__c = hrs,
                Status__c = 'Present'
            );
        }
        update new Technician__c(Id = techId, Availability_Status__c = 'Off Shift');
    }

    @AuraEnabled(cacheable=true)
    public static Attendance__c getTodayAttendance(Id technicianId) {
        Id techId = technicianId;
        if (techId == null) {
            List<Technician__c> myTechs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
            if (!myTechs.isEmpty()) techId = myTechs[0].Id;
        }
        if (techId == null) return null;

        Date today = Date.today();
        List<Attendance__c> records = [
            SELECT Id, Status__c, Attendance_Date__c, Check_In_Time__c, Check_Out_Time__c, Hours_Worked__c
            FROM Attendance__c
            WHERE Technician__c = :techId AND Attendance_Date__c = :today
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }
}
