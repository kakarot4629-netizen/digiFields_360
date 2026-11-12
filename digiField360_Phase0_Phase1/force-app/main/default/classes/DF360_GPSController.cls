@RestResource(urlMapping='/df360/gps/*')
global with sharing class DF360_GPSController {

    @HttpPost
    global static String logGPS() {
        RestRequest req = RestContext.request;
        Map<String,Object> body = (Map<String,Object>) JSON.deserializeUntyped(req.requestBody.toString());
        Id techId = (Id) body.get('technicianId');
        Decimal lat  = Decimal.valueOf(String.valueOf(body.get('latitude')));
        Decimal lng  = Decimal.valueOf(String.valueOf(body.get('longitude')));
        Decimal acc  = body.get('accuracy') != null ? Decimal.valueOf(String.valueOf(body.get('accuracy'))) : null;
        Integer bat  = body.get('battery') != null ? Integer.valueOf(String.valueOf(body.get('battery'))) : null;
        Id jobId = body.get('jobId') != null ? (Id) body.get('jobId') : null;
        insert new GPS_Log__c(
            Technician__c = techId, Latitude__c = lat, Longitude__c = lng,
            Accuracy_M__c = acc, Battery_Pct__c = bat,
            Log_Timestamp__c = DateTime.now(), Active_Job__c = jobId
        );
        return 'OK';
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getTeamPositions(String zoneId) {
        Id zId = String.isNotBlank(zoneId) ? (Id) zoneId : null;
        List<Technician__c> techs = [
            SELECT Id, Name__c, Current_GPS_Latitude__c, Current_GPS_Longitude__c,
                   Availability_Status__c, Active_Job_Count__c
            FROM Technician__c
            WHERE (Zone__c = :zId OR :zId = null) AND Is_Active__c = true LIMIT 200
        ];
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Technician__c t : techs) {
            result.add(new Map<String,Object>{
                'id'=> t.Id, 'name'=> t.Name,
                'lat'=> t.Current_GPS_Latitude__c, 'lng'=> t.Current_GPS_Longitude__c,
                'status'=> t.Availability_Status__c, 'activeJobs'=> t.Active_Job_Count__c
            });
        }
        return result;
    }

    public static void sendJobPushNotification(Id technicianId, Id jobId) {
        List<Technician__c> techs = [SELECT FCM_Token__c FROM Technician__c WHERE Id = :technicianId LIMIT 1];
        if (techs.isEmpty() || String.isBlank(techs[0].FCM_Token__c)) return;
        sendFCMAsync(techs[0].FCM_Token__c, jobId);
    }

    @future(callout=true)
    private static void sendFCMAsync(String fcmToken, Id jobId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DF360_Firebase/fcm/send');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String,Object>{
                'to' => fcmToken,
                'notification' => new Map<String,String>{ 'title'=>'New Job Assigned', 'body'=>'Open digiField360 to view job details' },
                'data' => new Map<String,String>{ 'jobId' => jobId }
            }));
            new Http().send(req);
        } catch(Exception ex) { System.debug('FCM error: ' + ex.getMessage()); }
    }
}
