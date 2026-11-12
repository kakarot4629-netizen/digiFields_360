public with sharing class DF360_GuruAIController {

    @AuraEnabled
    public static String askGuruAI(Id technicianId, Id jobId, String message) {
        Service_Job__c job = [SELECT Job_Type__c, Product_Category__c, Notes__c,
                                     Asset__r.Product_Name__c
                              FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        Map<String,Object> context = new Map<String,Object>{
            'jobType'=> job.Job_Type__c,
            'productCategory'=> job.Product_Category__c,
            'productName'=> job.Asset__r?.Product_Name__c,
            'technicianMessage'=> message
        };
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:DF360_AIService/v1/guruai/field360');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String,Object>{
            'agentId'=> 'DF360-GuruAI',
            'message'=> message,
            'context'=> context
        }));
        req.setTimeout(20000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) return 'GuruAI is unavailable. Please check job notes or contact supervisor.';
        Map<String,Object> resp = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
        return (String) resp.get('reply');
    }
}
