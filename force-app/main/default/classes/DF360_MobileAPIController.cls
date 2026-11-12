@RestResource(urlMapping='/df360/mobile/*')
global with sharing class DF360_MobileAPIController {

    @HttpPost
    global static String syncData() {
        RestRequest req = RestContext.request;
        String action = req.requestURI != null ? req.requestURI.substringAfterLast('/') : '';
        Map<String,Object> body = new Map<String,Object>();
        if (req.requestBody != null) {
            body = (Map<String,Object>) JSON.deserializeUntyped(req.requestBody.toString());
        }
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
        } else if (action == 'work-order-line-items') {
            Id woId = (Id) body.get('workOrderId');
            result.put('lineItems', [
                SELECT Id, Name, Asset__c, Asset__r.Name, Asset__r.Product_Name__c,
                       Sequence__c, Status__c, Description__c, Is_First_Time_Fix__c,
                       Parts_Used__c, Resolution_Notes__c
                FROM Work_Order_Line_Item__c
                WHERE Work_Order__c = :woId
                ORDER BY Sequence__c ASC NULLS LAST
            ]);
        } else if (action == 'update-line-item') {
            Id lineItemId = (Id) body.get('lineItemId');
            Work_Order_Line_Item__c item = new Work_Order_Line_Item__c(Id = lineItemId);
            if (body.containsKey('status')) item.Status__c = (String) body.get('status');
            if (body.containsKey('isFirstTimeFix')) item.Is_First_Time_Fix__c = (Boolean) body.get('isFirstTimeFix');
            if (body.containsKey('partsUsed')) item.Parts_Used__c = (String) body.get('partsUsed');
            if (body.containsKey('resolutionNotes')) item.Resolution_Notes__c = (String) body.get('resolutionNotes');
            update item;
            result.put('status', 'OK');
            result.put('lineItemId', lineItemId);
        } else {
            result.put('error', 'Unknown action: ' + action);
        }

        return JSON.serialize(result);
    }
}
