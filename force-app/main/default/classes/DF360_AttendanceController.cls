/**
 * Controller for the df360Attendance Lightning component.
 * All rules live in DF360_AttendanceService, shared with the mobile REST API.
 * Method names and parameters are unchanged, so the component keeps working.
 */
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
        try {
            DF360_AttendanceService.checkIn(technicianId, lat, lng, isGeofenceValid, DateTime.now());
        } catch (DF360_AttendanceService.AttendanceException ex) {
            throw toAuraError(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void punchOut(Id technicianId, Decimal lat, Decimal lng) {
        try {
            DF360_AttendanceService.checkOut(technicianId, lat, lng, DateTime.now());
        } catch (DF360_AttendanceService.AttendanceException ex) {
            throw toAuraError(ex.getMessage());
        }
    }

    // Not cacheable: the component re-reads this right after a punch, and a
    // cached result would show the old state.
    @AuraEnabled
    public static Attendance__c getTodayAttendance(Id technicianId) {
        try {
            return DF360_AttendanceService.getToday(technicianId);
        } catch (DF360_AttendanceService.AttendanceException ex) {
            if (ex.code == 'TECHNICIAN_NOT_FOUND') return null;
            throw toAuraError(ex.getMessage());
        }
    }

    private static AuraHandledException toAuraError(String message) {
        AuraHandledException aura = new AuraHandledException(message);
        aura.setMessage(message);
        return aura;
    }
}