public with sharing class DF360_AttendanceController {

    @AuraEnabled
    public static void checkIn(Id technicianId, Decimal lat, Decimal lng) {
        Date today = Date.today();
        List<Attendance__c> existing = [SELECT Id FROM Attendance__c
            WHERE Technician__c = :technicianId AND Attendance_Date__c = :today LIMIT 1];
        if (!existing.isEmpty()) return; // already checked in
        insert new Attendance__c(
            Technician__c = technicianId,
            Attendance_Date__c = today,
            Check_In_Time__c = DateTime.now(),
            Check_In_Latitude__c = lat,
            Check_In_Longitude__c = lng,
            Status__c = 'Present'
        );
        update new Technician__c(Id = technicianId, Availability_Status__c = 'Available');
    }

    @AuraEnabled
    public static void checkOut(Id technicianId) {
        Date today = Date.today();
        List<Attendance__c> records = [SELECT Id, Check_In_Time__c FROM Attendance__c
            WHERE Technician__c = :technicianId AND Attendance_Date__c = :today LIMIT 1];
        if (!records.isEmpty()) {
            Decimal hrs = 0;
            if (records[0].Check_In_Time__c != null)
                hrs = (Decimal.valueOf(DateTime.now().getTime() - records[0].Check_In_Time__c.getTime()) / 3600000).setScale(1);
            update new Attendance__c(Id = records[0].Id, Check_Out_Time__c = DateTime.now(), Hours_Worked__c = hrs);
        }
        update new Technician__c(Id = technicianId, Availability_Status__c = 'Off Shift');
    }
}
