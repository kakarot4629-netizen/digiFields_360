@RestResource(urlMapping='/df360/mobile/*')
global with sharing class DF360_MobileAPIController {

    @HttpPost
    global static Map<String,Object> syncData() {
        RestRequest req = RestContext.request;
        String action = req.requestURI.substringAfterLast('/');
        Map<String,Object> body = (Map<String,Object>) JSON.deserializeUntyped(req.requestBody.toString());
        Map<String,Object> result = new Map<String,Object>();

        if (action == 'morning-payload') {
            Id techId = (Id) body.get('technicianId');
            result.put('jobs', DF360_TechnicianController.getTodaysJobs(techId));
            result.put('technicianId', techId);
        } else if (action == 'check-in') {
            Id jobId = (Id) body.get('jobId');
            Id techId = (Id) body.get('technicianId');
            Decimal lat = Decimal.valueOf(String.valueOf(body.get('latitude')));
            Decimal lng = Decimal.valueOf(String.valueOf(body.get('longitude')));
            result = DF360_ServiceJobController.checkIn(jobId, techId, lat, lng);
        } else if (action == 'complete-job') {
            Id jobId = (Id) body.get('jobId');
            Boolean isFTF = body.get('isFirstTimeFix') == true;
            String sigUrl = (String) body.get('signatureUrl');
            DF360_ServiceJobController.completeJob(jobId, isFTF, sigUrl);
            result.put('status', 'OK');
        } else if (action == 'log-activity') {
            Map<String,Object> activity = (Map<String,Object>) body.get('activity');
            insert new Job_Activity__c(
                Service_Job__c = (Id) activity.get('jobId'),
                Activity_Type__c = (String) activity.get('activityType'),
                Description__c = (String) activity.get('description'),
                Duration_Min__c = activity.get('durationMin') != null ? Integer.valueOf(String.valueOf(activity.get('durationMin'))) : null
            );
            result.put('status', 'OK');
        } else if (action == 'raise-parts') {
            Id partReqId = DF360_PartsController.raisePartsRequest(
                (Id) body.get('jobId'), (Id) body.get('partId'), Integer.valueOf(String.valueOf(body.get('quantity')))
            );
            result.put('partsRequestId', partReqId);
        } else {
            result.put('error', 'Unknown action: ' + action);
        }
        return result;
    }
}
