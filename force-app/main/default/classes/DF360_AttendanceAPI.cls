/**
 * Mobile attendance API.
 *
 *   POST /services/apexrest/df360/v1/attendance/check-in
 *        { "technicianId", "latitude", "longitude", "timestamp", "isGeofenceValid" }
 *   POST /services/apexrest/df360/v1/attendance/check-out
 *        { "technicianId", "latitude", "longitude", "timestamp" }
 *   GET  /services/apexrest/df360/v1/attendance/today?technicianId=...
 *
 * technicianId is optional when the calling Salesforce user is linked to a technician.
 * timestamp is the ISO time the technician pressed the button on the phone
 * (e.g. 2026-11-03T09:00:00.000Z); if left out, the server time is used.
 *
 * Responses: { "success": true, "data": {...} } or
 *            { "success": false, "errorCode": "...", "error": "..." } with HTTP 400 / 404 / 409 / 500.
 */
@RestResource(urlMapping='/df360/v1/attendance/*')
global with sharing class DF360_AttendanceAPI {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            String action = actionFromUri(req.requestURI);
            Map<String, Object> body = parseBody(req);

            Id techId = readId(body, 'technicianId');
            Decimal lat = readDecimal(body, new List<String>{ 'latitude', 'lat' });
            Decimal lng = readDecimal(body, new List<String>{ 'longitude', 'lng' });
            DateTime eventTime = readDateTime(body, new List<String>{ 'timestamp', 'checkInTime', 'checkOutTime' });

            Attendance__c rec;
            String message;
            if (action == 'check-in') {
                Boolean inGeofence = body.containsKey('isGeofenceValid') ? toBoolean(body.get('isGeofenceValid')) : false;
                rec = DF360_AttendanceService.checkIn(techId, lat, lng, inGeofence, eventTime);
                message = 'Shift check-in recorded.';
            } else if (action == 'check-out') {
                rec = DF360_AttendanceService.checkOut(techId, lat, lng, eventTime);
                message = 'Shift check-out recorded. Hours worked: ' + rec.Hours_Worked__c + '.';
            } else {
                respondError(res, 404, 'UNKNOWN_ROUTE', 'Use /attendance/check-in or /attendance/check-out.');
                return;
            }
            respond(res, 200, new Map<String, Object>{
                'success' => true,
                'message' => message,
                'data' => DF360_AttendanceService.toMap(rec)
            });
        } catch (DF360_AttendanceService.AttendanceException ex) {
            respondError(res, ex.httpStatus, ex.code, ex.getMessage());
        } catch (BadRequestException ex) {
            respondError(res, 400, 'BAD_REQUEST', ex.getMessage());
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'DF360_AttendanceAPI: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            respondError(res, 500, 'SERVER_ERROR', ex.getMessage());
        }
    }

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            String action = actionFromUri(req.requestURI);
            if (action != 'today') {
                respondError(res, 404, 'UNKNOWN_ROUTE', 'Use GET /attendance/today.');
                return;
            }
            Id techId = null;
            String techParam = req.params.get('technicianId');
            if (String.isNotBlank(techParam)) {
                techId = toId(techParam);
            }
            Attendance__c rec = DF360_AttendanceService.getToday(techId);
            respond(res, 200, new Map<String, Object>{
                'success' => true,
                'data' => DF360_AttendanceService.toMap(rec),
                'shiftStatus' => rec == null ? 'NOT_CHECKED_IN' : DF360_AttendanceService.toMap(rec).get('shiftStatus')
            });
        } catch (DF360_AttendanceService.AttendanceException ex) {
            respondError(res, ex.httpStatus, ex.code, ex.getMessage());
        } catch (BadRequestException ex) {
            respondError(res, 400, 'BAD_REQUEST', ex.getMessage());
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'DF360_AttendanceAPI: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            respondError(res, 500, 'SERVER_ERROR', ex.getMessage());
        }
    }

    // ----------------------------------------------------------------- helpers

    public class BadRequestException extends Exception {}

    private static String actionFromUri(String uri) {
        String sub = String.isBlank(uri) ? '' : uri.substringAfter('/df360/v1/attendance');
        return sub.removeStart('/').removeEnd('/').toLowerCase();
    }

    private static Map<String, Object> parseBody(RestRequest req) {
        if (req.requestBody == null || req.requestBody.size() == 0) return new Map<String, Object>();
        String raw = req.requestBody.toString().trim();
        if (String.isBlank(raw)) return new Map<String, Object>();
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(raw);
        } catch (Exception ex) {
            throw new BadRequestException('Request body is not valid JSON.');
        }
    }

    private static Id readId(Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v == null || String.isBlank(String.valueOf(v))) return null;
        return toId(String.valueOf(v));
    }

    private static Id toId(String value) {
        try {
            return Id.valueOf(value.trim());
        } catch (Exception ex) {
            throw new BadRequestException('Invalid technicianId: ' + value);
        }
    }

    private static Decimal readDecimal(Map<String, Object> body, List<String> keys) {
        for (String k : keys) {
            Object v = body.get(k);
            if (v == null || String.isBlank(String.valueOf(v))) continue;
            try {
                return Decimal.valueOf(String.valueOf(v));
            } catch (Exception ex) {
                throw new BadRequestException('Invalid number for ' + k + ': ' + v);
            }
        }
        return null;
    }

    private static DateTime readDateTime(Map<String, Object> body, List<String> keys) {
        for (String k : keys) {
            Object v = body.get(k);
            if (v == null || String.isBlank(String.valueOf(v))) continue;
            try {
                return (DateTime) JSON.deserialize('"' + String.valueOf(v).trim() + '"', DateTime.class);
            } catch (Exception ex) {
                throw new BadRequestException('Invalid ISO date-time for ' + k + ': ' + v);
            }
        }
        return null;
    }

    private static Boolean toBoolean(Object v) {
        if (v == null) return false;
        if (v instanceof Boolean) return (Boolean) v;
        return String.valueOf(v).trim().equalsIgnoreCase('true');
    }

    private static void respond(RestResponse res, Integer status, Map<String, Object> payload) {
        if (res == null) return;
        res.statusCode = status;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(payload));
    }

    private static void respondError(RestResponse res, Integer status, String code, String message) {
        respond(res, status, new Map<String, Object>{
            'success' => false,
            'errorCode' => code,
            'error' => message
        });
    }
}