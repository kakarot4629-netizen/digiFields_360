/**
 * Single place for technician attendance (shift check-in / check-out).
 * Used by the mobile REST API (DF360_AttendanceAPI) and the Lightning
 * component controller (DF360_AttendanceController), so both follow the same rules.
 *
 * Rules:
 *  - One attendance record per technician per day. The day is worked out in the
 *    technician's own time zone (their linked User), so a punch replayed later
 *    from the offline queue still lands on the right date.
 *  - The punch time is the time sent by the phone (offline punches keep their
 *    real time). Times more than 5 minutes in the future are rejected.
 *  - Check-out closes the latest open check-in, so a shift that runs past
 *    midnight still closes correctly.
 *  - Every refusal is an AttendanceException with a code and an HTTP status,
 *    instead of returning silently.
 */
public with sharing class DF360_AttendanceService {

    public class AttendanceException extends Exception {
        public String code;
        public Integer httpStatus;
    }

    private static final Integer MAX_CLOCK_SKEW_MINUTES = 5;

    private static AttendanceException fail(String code, Integer httpStatus, String message) {
        AttendanceException ex = new AttendanceException(message);
        ex.code = code;
        ex.httpStatus = httpStatus;
        return ex;
    }

    // ---------------------------------------------------------------- check-in

    public static Attendance__c checkIn(Id technicianId, Decimal lat, Decimal lng, Boolean isGeofenceValid, DateTime eventTime) {
        Technician__c tech = resolveTechnician(technicianId);
        DateTime punchTime = validatePunchTime(eventTime);
        Date shiftDate = localDate(tech, punchTime);

        List<Attendance__c> sameDay = findForDay(tech.Id, shiftDate);
        Attendance__c rec;
        if (!sameDay.isEmpty()) {
            rec = sameDay[0];
            if (rec.Check_In_Time__c != null) {
                throw fail('ALREADY_CHECKED_IN', 409,
                    'Technician already checked in on ' + String.valueOf(shiftDate) + ' at ' + rec.Check_In_Time__c.format() + '.');
            }
        } else {
            rec = new Attendance__c(Technician__c = tech.Id, Attendance_Date__c = shiftDate);
        }

        rec.Check_In_Time__c = punchTime;
        rec.Check_In_Latitude__c = lat;
        rec.Check_In_Longitude__c = lng;
        rec.Is_Geofence_Valid__c = (isGeofenceValid == true);
        rec.Status__c = 'Present';
        upsert rec;

        update new Technician__c(Id = tech.Id, Availability_Status__c = 'Available');
        return getById(rec.Id);
    }

    // --------------------------------------------------------------- check-out

    public static Attendance__c checkOut(Id technicianId, Decimal lat, Decimal lng, DateTime eventTime) {
        Technician__c tech = resolveTechnician(technicianId);
        DateTime punchTime = validatePunchTime(eventTime);

        List<Attendance__c> open = [
            SELECT Id, Attendance_Date__c, Check_In_Time__c, Check_Out_Time__c
            FROM Attendance__c
            WHERE Technician__c = :tech.Id
              AND Check_In_Time__c != null
              AND Check_Out_Time__c = null
            ORDER BY Check_In_Time__c DESC
            LIMIT 1
        ];

        if (open.isEmpty()) {
            List<Attendance__c> sameDay = findForDay(tech.Id, localDate(tech, punchTime));
            if (!sameDay.isEmpty() && sameDay[0].Check_Out_Time__c != null) {
                throw fail('ALREADY_CHECKED_OUT', 409,
                    'Technician already checked out at ' + sameDay[0].Check_Out_Time__c.format() + '.');
            }
            throw fail('NOT_CHECKED_IN', 409, 'No open check-in found for this technician.');
        }

        Attendance__c rec = open[0];
        if (punchTime < rec.Check_In_Time__c) {
            throw fail('INVALID_TIMESTAMP', 400, 'Check-out time is earlier than the check-in time.');
        }

        Decimal hours = (Decimal.valueOf(punchTime.getTime() - rec.Check_In_Time__c.getTime()) / 3600000).setScale(1);

        update new Attendance__c(
            Id = rec.Id,
            Check_Out_Time__c = punchTime,
            Check_Out_Latitude__c = lat,
            Check_Out_Longitude__c = lng,
            Hours_Worked__c = hours
        );

        update new Technician__c(Id = tech.Id, Availability_Status__c = 'Off Shift');
        return getById(rec.Id);
    }

    // ------------------------------------------------------------------- reads

    /** Today's record (in the technician's time zone), or null. */
    public static Attendance__c getToday(Id technicianId) {
        Technician__c tech = resolveTechnician(technicianId);
        List<Attendance__c> recs = findForDay(tech.Id, localDate(tech, DateTime.now()));
        return recs.isEmpty() ? null : recs[0];
    }

    public static Technician__c resolveTechnician(Id technicianId) {
        List<Technician__c> techs;
        if (technicianId != null) {
            techs = [SELECT Id, Name, User__c, User__r.TimeZoneSidKey FROM Technician__c WHERE Id = :technicianId LIMIT 1];
        } else {
            techs = [SELECT Id, Name, User__c, User__r.TimeZoneSidKey FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        }
        if (techs.isEmpty()) {
            throw fail('TECHNICIAN_NOT_FOUND', 404,
                technicianId != null
                    ? 'Technician not found: ' + technicianId
                    : 'The logged-in user is not linked to a technician record.');
        }
        return techs[0];
    }

    /** Shape returned to the mobile app. */
    public static Map<String, Object> toMap(Attendance__c rec) {
        if (rec == null) return null;
        return new Map<String, Object>{
            'id' => rec.Id,
            'name' => rec.Name,
            'technicianId' => rec.Technician__c,
            'attendanceDate' => rec.Attendance_Date__c,
            'status' => rec.Status__c,
            'checkInTime' => rec.Check_In_Time__c,
            'checkInLatitude' => rec.Check_In_Latitude__c,
            'checkInLongitude' => rec.Check_In_Longitude__c,
            'isGeofenceValid' => rec.Is_Geofence_Valid__c,
            'checkOutTime' => rec.Check_Out_Time__c,
            'checkOutLatitude' => rec.Check_Out_Latitude__c,
            'checkOutLongitude' => rec.Check_Out_Longitude__c,
            'hoursWorked' => rec.Hours_Worked__c,
            'shiftStatus' => rec.Check_Out_Time__c != null ? 'CHECKED_OUT'
                           : (rec.Check_In_Time__c != null ? 'CHECKED_IN' : 'NOT_CHECKED_IN')
        };
    }

    // ----------------------------------------------------------------- helpers

    private static DateTime validatePunchTime(DateTime eventTime) {
        DateTime nowTime = DateTime.now();
        if (eventTime == null) return nowTime;
        if (eventTime > nowTime.addMinutes(MAX_CLOCK_SKEW_MINUTES)) {
            throw fail('INVALID_TIMESTAMP', 400, 'Punch time is in the future. Check the phone clock.');
        }
        return eventTime;
    }

    @TestVisible
    private static Date localDate(Technician__c tech, DateTime moment) {
        String tz = (tech.User__c != null && String.isNotBlank(tech.User__r.TimeZoneSidKey))
            ? tech.User__r.TimeZoneSidKey
            : UserInfo.getTimeZone().getID();
        return Date.valueOf(moment.format('yyyy-MM-dd', tz));
    }

    private static List<Attendance__c> findForDay(Id techId, Date shiftDate) {
        return [
            SELECT Id, Name, Technician__c, Attendance_Date__c, Status__c,
                   Check_In_Time__c, Check_In_Latitude__c, Check_In_Longitude__c, Is_Geofence_Valid__c,
                   Check_Out_Time__c, Check_Out_Latitude__c, Check_Out_Longitude__c, Hours_Worked__c
            FROM Attendance__c
            WHERE Technician__c = :techId AND Attendance_Date__c = :shiftDate
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static Attendance__c getById(Id recId) {
        return [
            SELECT Id, Name, Technician__c, Attendance_Date__c, Status__c,
                   Check_In_Time__c, Check_In_Latitude__c, Check_In_Longitude__c, Is_Geofence_Valid__c,
                   Check_Out_Time__c, Check_Out_Latitude__c, Check_Out_Longitude__c, Hours_Worked__c
            FROM Attendance__c
            WHERE Id = :recId
        ];
    }
}